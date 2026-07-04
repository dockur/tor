#!/usr/bin/env bash
set -Eeuo pipefail

# Fix directory permissions
chown -R tor:tor /etc/tor || :
chmod ugo+rwx /etc/tor || :
chown -R tor:tor /var/lib/tor || :
chmod g-rwx,o-rwx /var/lib/tor || :

# Set defaults
CONTROL_PORT=9051
CONFIG="/etc/tor/torrc"

# Get control password from environment (default: "password")
PASSWORD="${PASSWORD:-password}"

# Generate hashed password using Tor
# tor --hash-password outputs the hash on the last line
if ! HASHED_PASSWORD=$(tor --hash-password "$PASSWORD" | tail -n 1); then
  echo "ERROR: Failed to generate password hash" >&2
  exit 1
fi

if [ -z "$HASHED_PASSWORD" ]; then
    echo "ERROR: Failed to generate password hash" >&2
    exit 1
fi

if [ -s "$CONFIG" ]; then

  # Prevent port conflict
  if grep -iwq "SOCKSPort $CONTROL_PORT" "$CONFIG" || \
     grep -iwq "SOCKSPort 0.0.0.0:$CONTROL_PORT" "$CONFIG" || \
     grep -iwq "SOCKSPort 127.0.0.1:$CONTROL_PORT" "$CONFIG" || \
     grep -iwq "SOCKSPort localhost:$CONTROL_PORT" "$CONFIG"; then
     CONTROL_PORT=9951
  fi

fi

CONTROL=$(cat <<EOF
# Control port (required for healthcheck)
# Binds to 127.0.0.1, accessible only within container
ControlPort $CONTROL_PORT

# Control port password (generated from PASSWORD environment variable)
HashedControlPassword $HASHED_PASSWORD
EOF
)

if [ -s "$CONFIG" ] && [ -n "$CONTROL" ]; then

  if grep -wq "ControlPort" "$CONFIG"; then

    line=$(grep -E '^[[:space:]]*#?[[:space:]]*ControlPort[[:space:]]+' "$CONFIG" | head -n1)

    if [[ ! "$line" =~ ^[[:space:]]*# ]]; then
      CONTROL=""
      CONTROL_PORT=$(echo "$line" | sed -E 's/^[[:space:]]*#?[[:space:]]*ControlPort[[:space:]]+//')
    fi

  fi

fi

ADDR="127.0.0.1:$CONTROL_PORT"

# Create defaults file with default settings for Docker healthcheck
# These can be overridden by user's /etc/tor/torrc
cat > /tmp/torrc-defaults <<EOF
# Default settings for Tor container
# User's /etc/tor/torrc can override any of these settings

$CONTROL
EOF

chown -R tor:tor /tmp/torrc-defaults || :

# Start Tor with defaults that can be overridden by /etc/tor/torrc
# The --defaults-torrc file has lowest priority, user's torrc takes precedence
exec su-exec tor tor --defaults-torrc /tmp/torrc-defaults "$@"
