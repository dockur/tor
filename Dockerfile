# syntax=docker/dockerfile:1

FROM golang:alpine AS builder

WORKDIR /build
COPY healthcheck/main.go .
RUN go build -ldflags="-s -w" -o healthcheck main.go

FROM alpine:edge

RUN apk add --no-cache tor bash nyx lyrebird && rm -rf /var/cache/apk/* && \
    sed "1s/^/SocksPort 0.0.0.0:9050\n/" /etc/tor/torrc.sample > /etc/tor/torrc
RUN apk add --no-cache tor bash nyx lyrebird && rm -rf /var/cache/apk/*

COPY --from=builder /build/healthcheck /usr/local/bin/healthcheck
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Fallbacks
ENV TOR_CONTROL_ADDR=127.0.0.1:9051
ENV TOR_CONTROL_PASSWORD=password

EXPOSE 9050 9051

HEALTHCHECK --interval=600s --timeout=30s --start-period=60s --start-interval=60s \
    CMD ["/usr/local/bin/healthcheck"]

VOLUME ["/etc/tor"]
VOLUME ["/var/lib/tor"]

USER tor
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD []
