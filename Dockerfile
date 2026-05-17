# syntax=docker/dockerfile:1

FROM golang:alpine AS builder

WORKDIR /build
COPY healthcheck/main.go .
RUN go build -ldflags="-s -w" -o healthcheck main.go

FROM alpine:edge

RUN set -eu && \
    apk update && \
    apk upgrade && \
    apk --no-cache add \
    curl \
    tor \
    bash \
    nyx \
    lyrebird && \
    rm -rf /tmp/* /var/cache/apk/* && \
    sed "1s/^/SocksPort 0.0.0.0:9050\n/" /etc/tor/torrc.sample > /etc/tor/torrc

COPY --from=builder /build/healthcheck /usr/local/bin/healthcheck
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Fallbacks
ENV TOR_CONTROL_ADDR=127.0.0.1:9051
ENV TOR_CONTROL_PASSWORD=password

EXPOSE 9050 9051

HEALTHCHECK --interval=600s --timeout=30s --start-period=60s --start-interval=60s \
    CMD ["/usr/local/bin/healthcheck"]

VOLUME ["/etc/tor"]
VOLUME ["/var/lib/tor"]

USER tor
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
