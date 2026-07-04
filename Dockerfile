# syntax=docker/dockerfile:1

FROM golang:alpine AS builder

WORKDIR /build

COPY healthcheck/main.go .

RUN go build -ldflags="-s -w" -o healthcheck main.go

FROM alpine:edge

RUN <<EOF
  set -eu

  apk update
  apk upgrade
  apk --no-cache add \
    bash \
    ca-certificates \
    curl \
    lyrebird \
    nyx \
    su-exec \
    tini \
    tor

  rm -f /etc/tor/torrc
  rm -rf /tmp/* /var/cache/apk/*
EOF

COPY --chmod=755 entrypoint.sh /usr/local/bin/
COPY --chmod=755 healthcheck.sh /usr/local/bin/
COPY --chmod=755 --from=builder /build/healthcheck /usr/local/bin/healthcheck

ENV CHECK=false
ENV DEBUG=false
ENV SOCKS_PORT=9050
ENV CONTROL_PORT=9051
ENV PASSWORD=password

EXPOSE 9050

HEALTHCHECK --interval=600s --timeout=30s --start-period=60s --start-interval=60s \
  CMD ["/usr/local/bin/healthcheck.sh"]

VOLUME ["/var/lib/tor"]

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
