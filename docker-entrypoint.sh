#!/bin/sh
set -e

# Get control password from environment (default: "password")
TOR_CONTROL_PASSWORD="${TOR_CONTROL_PASSWORD:-password}"

echo "Generating Tor control port password hash..."

# Generate hashed password using Tor
# tor --hash-password outputs the hash on the last line
HASHED_PASSWORD=$(tor --hash-password "$TOR_CONTROL_PASSWORD" | tail -n 1)

if [ -z "$HASHED_PASSWORD" ]; then
    echo "ERROR: Failed to generate password hash" >&2
    exit 1
fi

echo "Hash generated successfully"

# Create defaults file with default settings for Docker healthcheck
# These can be overridden by user's /etc/tor/torrc
cat > /tmp/torrc-defaults <<EOF
# Default settings required for Docker healthcheck
# User's /etc/tor/torrc can override any of these settings

# Control port (required for healthcheck)
# Binds to 127.0.0.1, accessible only within container
ControlPort 9051

# Control port password (generated from TOR_CONTROL_PASSWORD environment variable)
HashedControlPassword $HASHED_PASSWORD
EOF

# Check if user provided custom torrc
if [ ! -f /etc/tor/torrc ]; then
    echo "WARNING: No custom torrc found at /etc/tor/torrc"
    echo "WARNING: Using default configuration for Healthcheck!"
fi

# Start Tor with defaults that can be overridden by /etc/tor/torrc
# The --defaults-torrc file has lowest priority, user's torrc takes precedence
exec tor --defaults-torrc /tmp/torrc-defaults "$@"
