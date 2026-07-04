#!/usr/bin/env bash
set -Eeuo pipefail

# Set defaults
CONFIG="/etc/tor/torrc"
PASSWORD="${PASSWORD:-password}"
SOCKS_PORT="${SOCKS_PORT:-9050}"
CONTROL_PORT="${CONTROL_PORT:-9051}"
DEFAULT_CONFIG="/run/tor/torrc-defaults"
HEALTHCHECK_ENV="/run/tor/healthcheck.env"

# Fix directory permissions
chown -R tor:tor /var/lib/tor
chmod 0700 /var/lib/tor

mkdir -p /run/tor
chown tor:tor /run/tor
chmod 0755 /run/tor

if [ -w /etc/tor ]; then
  chown -R tor:tor /etc/tor || echo "Warning: failed to chown /etc/tor" >&2
  chmod 0755 /etc/tor || echo "Warning: failed to chmod /etc/tor" >&2
  find /etc/tor -type f -exec chmod 0644 {} + || echo "Warning: failed to chmod files in /etc/tor" >&2
else
  echo "Warning: /etc/tor is not writable, leaving permissions unchanged" >&2
fi

# Generate hashed password
if ! HASHED_PASSWORD=$(tor --hash-password "$PASSWORD" | tail -n 1); then
  echo "ERROR: Failed to generate password hash" >&2
  exit 1
fi

if [ -z "$HASHED_PASSWORD" ]; then
  echo "ERROR: Generated password hash is empty" >&2
  exit 1
fi

# Prevent port conflict with an existing SOCKS port in the user's torrc
if [ -s "$CONFIG" ]; then
  if grep -Eiq "^[[:space:]]*SocksPort[[:space:]]+([^[:space:]]*:)?${CONTROL_PORT}([[:space:]]|$)" "$CONFIG"; then
    CONTROL_PORT=9951
  fi
fi

ADDR="127.0.0.1:$CONTROL_PORT"

# Docker healthcheck defaults
CONTROL=$(cat <<EOF
# Control port for healthcheck
ControlPort 0.0.0.0:$CONTROL_PORT

# Control port password, generated from PASSWORD environment variable
HashedControlPassword $HASHED_PASSWORD
EOF
)

# Let the user's torrc override the control port, but still keep authentication
# unless they already configured control authentication themselves.
if [ -s "$CONFIG" ]; then

  control_value=""

  # Prefer the first usable TCP ControlPort when multiple are configured.
  while IFS= read -r line; do

    value=$(echo "$line" | sed -E 's/^[[:space:]]*ControlPort[[:space:]]+//; s/[[:space:]].*$//')

    case "$value" in
      ""|0|auto|unix:*)
        [ -z "$control_value" ] && control_value="$value"
        ;;
      *:*)
        control_value="$value"
        break
        ;;
      *)
        control_value="$value"
        break
        ;;
    esac

  done < <(grep -E '^[[:space:]]*ControlPort[[:space:]]+' "$CONFIG" || :)

  if [ -n "$control_value" ]; then

    CONTROL=""

    case "$control_value" in
      0|auto|unix:*)
        ADDR=""
        CONTROL_PORT=""
        ;;
      *:*)
        ADDR="$control_value"
        CONTROL_PORT="${control_value##*:}"
        ;;
      *)
        CONTROL_PORT="$control_value"
        ADDR="127.0.0.1:$CONTROL_PORT"
        ;;
    esac

    if ! grep -Eq '^[[:space:]]*(HashedControlPassword|CookieAuthentication)[[:space:]]+' "$CONFIG"; then
      CONTROL="HashedControlPassword $HASHED_PASSWORD"
    fi

  fi

fi

# Create defaults file with Docker-safe settings.
# When no user torrc exists, this file is used as the main config.
# When a user torrc exists, these are only defaults and can be overridden.
cat > "$DEFAULT_CONFIG" <<EOF
# Default settings for Tor container

RunAsDaemon 0
Log notice stdout
DataDirectory /var/lib/tor

# SOCKS proxy
SocksPort 0.0.0.0:$SOCKS_PORT

$CONTROL
EOF

chown tor:tor "$DEFAULT_CONFIG"
chmod 0644 "$DEFAULT_CONFIG"

# Write resolved healthcheck configuration.
# Docker HEALTHCHECK processes do not inherit variables exported by this script,
# so the healthcheck binary reads this file instead.
cat > "$HEALTHCHECK_ENV" <<EOF
ADDR=$ADDR
PASSWORD=$PASSWORD
SOCKS_PORT=$SOCKS_PORT
CONTROL_PORT=$CONTROL_PORT
EOF

chown tor:tor "$HEALTHCHECK_ENV"
chmod 0600 "$HEALTHCHECK_ENV"

# If the user supplied a torrc, load our file as defaults so their config wins.
# If no torrc exists, use our file as the main config to avoid relying on Tor's.
if [ -s "$CONFIG" ]; then
  exec su-exec tor tor --defaults-torrc "$DEFAULT_CONFIG" "$@"
else
  exec su-exec tor tor -f "$DEFAULT_CONFIG" "$@"
fi
