#!/usr/bin/env bash
set -Eeuo pipefail

# Set defaults
CONTROL_PORT=9051
CONFIG="/etc/tor/torrc"
DEFAULT_CONFIG="/tmp/torrc-defaults"

# Get control password from environment (default: "password")
PASSWORD="${PASSWORD:-password}"

# Fix directory permissions
chown -R tor:tor /etc/tor || echo "Warning: failed to chown /etc/tor" >&2
chmod 0755 /etc/tor || echo "Warning: failed to chmod /etc/tor" >&2

chown -R tor:tor /var/lib/tor || echo "Warning: failed to chown /var/lib/tor" >&2
chmod 0700 /var/lib/tor || echo "Warning: failed to chmod /var/lib/tor" >&2

# Generate hashed password using Tor
# tor --hash-password outputs the hash on the last line
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
  if grep -Eiq '^[[:space:]]*SocksPort[[:space:]]+([^[:space:]]*:)?9051([[:space:]]|$)' "$CONFIG"; then
    CONTROL_PORT=9951
  fi
fi

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

  if grep -Eq '^[[:space:]]*ControlPort[[:space:]]+' "$CONFIG"; then
    line=$(grep -E '^[[:space:]]*ControlPort[[:space:]]+' "$CONFIG" | head -n 1)
    CONTROL_PORT=$(echo "$line" | sed -E 's/^[[:space:]]*ControlPort[[:space:]]+//; s/[[:space:]].*$//')

    CONTROL=""

    if ! grep -Eq '^[[:space:]]*(HashedControlPassword|CookieAuthentication)[[:space:]]+' "$CONFIG"; then
      CONTROL="HashedControlPassword $HASHED_PASSWORD"
    fi
  fi

fi

ADDR="127.0.0.1:$CONTROL_PORT"
export ADDR
export CONTROL_PORT

# Create defaults file with Docker-safe settings.
# When a user torrc exists, these are only defaults and can be overridden.
# When no user torrc exists, this file is used as the main config.
cat > "$DEFAULT_CONFIG" <<EOF
# Default settings for Tor container

RunAsDaemon 0
Log notice stdout
DataDirectory /var/lib/tor

# SOCKS proxy
SocksPort 0.0.0.0:9050

$CONTROL
EOF

chown tor:tor "$DEFAULT_CONFIG" || echo "Warning: failed to chown $DEFAULT_CONFIG" >&2
chmod 0644 "$DEFAULT_CONFIG" || echo "Warning: failed to chmod $DEFAULT_CONFIG" >&2

# If the user supplied a torrc, load our file as defaults so their config wins.
# If no torrc exists, use our file as the main config to avoid relying on Tor's
# compiled or distro-specific defaults.
if [ -s "$CONFIG" ]; then
  exec su-exec tor tor --defaults-torrc "$DEFAULT_CONFIG" "$@"
else
  exec su-exec tor tor -f "$DEFAULT_CONFIG" "$@"
fi
