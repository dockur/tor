#!/usr/bin/env bash
set -Eeuo pipefail

# Set defaults

CONFIG="/etc/tor/torrc"
PASSWORD="${PASSWORD:-password}"
SOCKS_PORT="${SOCKS_PORT:-9050}"
CONTROL_PORT="${CONTROL_PORT:-9051}"
DEFAULT_CONFIG="/run/tor/torrc-defaults"
HEALTHCHECK_ENV="/run/tor/healthcheck.env"
HTTPS_PROXY_PORT="${HTTPS_PROXY_PORT:-8118}"

has_relay_identity() {

  local data_dir="$1"

  [ -s "$data_dir/keys/secret_id_key" ] || \
    [ -s "$data_dir/keys/ed25519_master_id_secret_key" ]

}

migrate_data_directory() {

  local data_dir="/var/lib/tor"
  local legacy_dir="$data_dir/.tor"
  local backup_dir="$data_dir/.generated-identity"
  local item
  local items=()

  # Older releases relied on Tor's default DataDirectory, which resolved to
  # /var/lib/tor/.tor. Always prefer that identity when it still exists.
  [ -d "$legacy_dir" ] || return 0
  has_relay_identity "$legacy_dir" || return 0

  echo "Restoring legacy Tor identity from \"$legacy_dir\"..."

  # A newer image may already have generated another identity directly in
  # /var/lib/tor. Preserve that state before restoring the original identity.
  if has_relay_identity "$data_dir"; then
    echo "Preserving the newer Tor identity in \"$backup_dir\"..."

    rm -rf "$backup_dir"
    mkdir -p "$backup_dir"

    shopt -s dotglob nullglob
    items=( "$data_dir"/* )
    shopt -u dotglob nullglob

    for item in "${items[@]}"; do
      case "$item" in
        "$legacy_dir"|"$backup_dir")
          continue
          ;;
      esac

      mv -- "$item" "$backup_dir/"
    done
  fi

  cp -a "$legacy_dir"/. "$data_dir"/
  rm -rf "$legacy_dir"

  return 0
}

fix_permissions() {

  # Fix directory permissions

  install -d -o tor -g tor -m 0700 /var/lib/tor
  chown -R tor:tor /var/lib/tor
  find /var/lib/tor -type d -exec chmod 0700 {} +
  find /var/lib/tor -type f -exec chmod 0600 {} +

  mkdir -p /run/tor
  chown tor:tor /run/tor
  chmod 0755 /run/tor

  if [ -w /etc/tor ]; then
    chown -R tor:tor /etc/tor || echo "Warning: failed to chown /etc/tor" >&2
    chmod 0755 /etc/tor || echo "Warning: failed to chmod /etc/tor" >&2
  else
    echo "Warning: /etc/tor is not writable, leaving permissions unchanged" >&2
  fi

  return 0
}

hash_password() {

  # Generate hashed password

  if ! HASHED_PASSWORD=$(tor --hash-password "$PASSWORD" | tail -n 1); then
    echo "ERROR: Failed to generate password hash" >&2
    exit 1
  fi

  if [ -z "$HASHED_PASSWORD" ]; then
    echo "ERROR: Generated password hash is empty" >&2
    exit 1
  fi

  return 0
}

avoid_port_conflict() {

  # Prevent port conflict with an existing SOCKS port in the user's torrc

  if [ -s "$CONFIG" ]; then
    if grep -Eiq "^[[:space:]]*SocksPort[[:space:]]+([^[:space:]]*:)?${CONTROL_PORT}([[:space:]]|$)" "$CONFIG"; then
      CONTROL_PORT=9951
    fi
  fi

  return 0
}

first_torrc_value() {

  local directive="$1"
  local line value result=""

  [ -s "$CONFIG" ] || return 1

  while IFS= read -r line; do

    value=$(echo "$line" | sed -E 's/^[[:space:]]*[^[:space:]]+[[:space:]]+//; s/[[:space:]].*$//')

    case "$value" in
      ""|0|auto|unix:*)
        [ -z "$result" ] && result="$value"
        ;;
      *:*)
        result="$value"
        break
        ;;
      *)
        result="$value"
        break
        ;;
    esac

  done < <(grep -Ei "^[[:space:]]*${directive}[[:space:]]+" "$CONFIG" || :)

  [ -n "$result" ] || return 1
  printf '%s\n' "$result"

}

configure_defaults() {

  ADDR="127.0.0.1:$CONTROL_PORT"
  HEALTHCHECK_SOCKS_PORT="$SOCKS_PORT"
  SOCKS_CONFIG="SocksPort 0.0.0.0:$SOCKS_PORT"
  HTTPS_PROXY_CONFIG="HTTPTunnelPort 0.0.0.0:$HTTPS_PROXY_PORT"

  # Docker healthcheck defaults

  CONTROL=$(cat <<EOF
# Control port for healthcheck
ControlPort 127.0.0.1:$CONTROL_PORT

# Control port password, generated from PASSWORD environment variable
HashedControlPassword $HASHED_PASSWORD
EOF
)

  return 0
}

apply_socks_override() {

  local socks_value

  # Let the user's torrc override the SOCKS port used by the healthcheck.
  # If the user supplied any SocksPort, do not also add our default SocksPort.

  if ! socks_value=$(first_torrc_value "SocksPort"); then
    return 0
  fi

  SOCKS_CONFIG=""

  case "$socks_value" in
    0|auto|unix:*)
      HEALTHCHECK_SOCKS_PORT=""
      ;;
    *:*)
      HEALTHCHECK_SOCKS_PORT="${socks_value##*:}"
      ;;
    *)
      HEALTHCHECK_SOCKS_PORT="$socks_value"
      ;;
  esac

  return 0
}

apply_https_proxy_override() {

  # If the user supplied any HTTPTunnelPort, do not also add our default HTTPS proxy.

  if ! first_torrc_value "HTTPTunnelPort" >/dev/null; then
    return 0
  fi

  HTTPS_PROXY_CONFIG=""

  return 0
}

apply_control_override() {

  local control_value

  # Let the user's torrc override the control port, but still keep authentication
  # unless they already configured password authentication themselves.

  if ! control_value=$(first_torrc_value "ControlPort"); then
    return 0
  fi

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

  if grep -Eiq '^[[:space:]]*CookieAuthentication[[:space:]]+1([[:space:]]|$)' "$CONFIG"; then
    echo "Warning: CookieAuthentication is enabled; Docker healthcheck uses password authentication." >&2
  fi

  if ! grep -Eiq '^[[:space:]]*HashedControlPassword[[:space:]]+' "$CONFIG"; then
    CONTROL="HashedControlPassword $HASHED_PASSWORD"
  fi

  return 0
}

write_default_config() {

  # Create defaults file with Docker-safe settings.
  # When no user torrc exists, this file is used as the main config.
  # When a user torrc exists, these are only defaults and can be overridden.

  cat > "$DEFAULT_CONFIG" <<EOF
# Default settings for Tor container

RunAsDaemon 0
Log notice stdout
DataDirectory /var/lib/tor

# SOCKS proxy
$SOCKS_CONFIG

# HTTPS proxy
$HTTPS_PROXY_CONFIG

$CONTROL
EOF

  chown tor:tor "$DEFAULT_CONFIG"
  chmod 0644 "$DEFAULT_CONFIG"

  return 0
}

write_healthcheck_env() {

  # Write resolved healthcheck configuration.
  # Docker HEALTHCHECK processes do not inherit variables exported by this script,
  # so the healthcheck binary reads this file instead.

  cat > "$HEALTHCHECK_ENV" <<EOF
ADDR=$ADDR
PASSWORD=$PASSWORD
CHECK=${CHECK:-false}
CONTROL_PORT=$CONTROL_PORT
SOCKS_PORT=$HEALTHCHECK_SOCKS_PORT
HTTPS_PROXY_PORT=$HTTPS_PROXY_PORT
EOF

  chown tor:tor "$HEALTHCHECK_ENV"
  chmod 0600 "$HEALTHCHECK_ENV"

  return 0
}

start_tor() {

  # If the user supplied a torrc, load our file as defaults so their config wins.
  # If no torrc exists, use our file as the main config to avoid relying on Tor's defaults.

  if [ -s "$CONFIG" ]; then
    exec su-exec tor tor \
      --defaults-torrc "$DEFAULT_CONFIG" \
      -f "$CONFIG"
  else
    exec su-exec tor tor -f "$DEFAULT_CONFIG"
  fi

}

migrate_data_directory
fix_permissions
hash_password
avoid_port_conflict
configure_defaults
apply_socks_override
apply_https_proxy_override
apply_control_override
write_default_config
write_healthcheck_env

start_tor
