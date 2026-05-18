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
    tor \
    bash \
    nyx \
    tini \
    curl \
    lyrebird && \
    rm -rf /tmp/* /var/cache/apk/*

COPY --chmod=755 entrypoint.sh /usr/local/bin/
COPY --chmod=755 healthcheck.sh /usr/local/bin/
COPY --chmod=755 --from=builder /build/healthcheck /usr/local/bin/healthcheck

RUN chmod ugo+rwx /etc/tor

ENV CHECK=false
ENV DEBUG=false
ENV ADDR=127.0.0.1:9051
ENV PASSWORD=password

EXPOSE 9050 9051

HEALTHCHECK --interval=600s --timeout=30s --start-period=60s --start-interval=60s \
    CMD ["/usr/local/bin/healthcheck.sh"]

VOLUME ["/etc/tor"]
VOLUME ["/var/lib/tor"]

USER tor
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/entrypoint.sh"]
