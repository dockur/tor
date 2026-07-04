#!/usr/bin/env bash
set -Eeuo pipefail

: "${CHECK:="false"}"
: "${SOCKS_PORT:="9050"}"
: "${HEALTHCHECK_ENV:="/run/tor/healthcheck.env"}"

if [[ "${CHECK,,}" != "true" && "$CHECK" != [Yy1]* ]]; then
  echo "Healthcheck disabled, set the CHECK=true variable to enable."
  exit 0
fi

# Load runtime values resolved by the entrypoint.
# This keeps the shell healthcheck in sync with the generated Tor config.
if [ -f "$HEALTHCHECK_ENV" ]; then
  set -a
  # shellcheck disable=SC1090
  source "$HEALTHCHECK_ENV"
  set +a
fi

{ /usr/local/bin/healthcheck; rc=$?; } || :
(( rc != 0 )) && exit "$rc"

resp=$(
  curl \
    --silent \
    --show-error \
    --fail \
    --max-time 15 \
    -x "socks5h://127.0.0.1:$SOCKS_PORT" \
    'https://check.torproject.org/api/ip'
)

if ! grep -qm1 -E '"IsTor"\s*:\s*true' <<< "$resp"; then
  echo "$resp"
  exit 1
fi

echo "Healthcheck OK"
exit 0
