#!/usr/bin/env bash
set -Eeuo pipefail

: "${CHECK:="false"}"
: "${SOCKS_PORT:="9050"}"
: "${HEALTHCHECK_ENV:="/run/tor/healthcheck.env"}"

# Load the SOCKS port resolved by the entrypoint.
# Do not source this file, because it may contain unescaped values like PASSWORD.
if [ -f "$HEALTHCHECK_ENV" ]; then
  while IFS="=" read -r key value; do
    case "$key" in
      SOCKS_PORT)
        SOCKS_PORT="$value"
        ;;
    esac
  done < "$HEALTHCHECK_ENV"
fi

# Always run the local control-port healthcheck.
{ /usr/local/bin/healthcheck; rc=$?; } || :
(( rc != 0 )) && exit "$rc"

# Only run the external Tor exit check when CHECK is explicitly enabled.
if [[ "${CHECK,,}" != "true" && "$CHECK" != [Yy1]* ]]; then
  echo "Local healthcheck OK, external check disabled."
  exit 0
fi

if [ -z "$SOCKS_PORT" ]; then
  echo "Healthcheck failed: SOCKS_PORT is empty or unsupported by this healthcheck."
  exit 1
fi

resp=$(
  curl \
    --silent \
    --show-error \
    --fail \
    --max-time 15 \
    -x "socks5h://127.0.0.1:$SOCKS_PORT" \
    "https://check.torproject.org/api/ip"
)

if ! grep -qm1 -E '"IsTor"\s*:\s*true' <<< "$resp"; then
  echo "$resp"
  exit 1
fi

echo "Healthcheck OK"
exit 0
