!/usr/bin/env bash
set -Eeuo pipefail

: "${CHECK:="N"}"

if [[ "$CHECK" != [Yy1]* ]]; then
  echo "Healthcheck disabled, set the CHECK=Y variable to enable."
  exit 0
fi

{ /usr/local/bin/healthcheck; rc=$?; } || :
(( rc != 0 )) && exit $rc

resp=$(curl -x socks5h://127.0.0.1:9050 'https://check.torproject.org/api/ip')

if ! grep -qm1 -E '"IsTor"\s*:\s*true' <<< "$resp"; then
  echo "$resp" && exit 1
fi

echo "Healthcheck OK"
exit 0
