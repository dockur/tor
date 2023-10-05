FROM alpine:edge

RUN apk add --update --no-cache curl tor && rm -rf /var/cache/apk/* && \
    sed "1s/^/SocksPort 0.0.0.0:9050\n/" /etc/tor/torrc.sample > /etc/tor/torrc

# Container version
ARG DATE_ARG=""
ARG BUILD_ARG=0
ARG VERSION_ARG="0.0"
ENV VERSION=$VERSION_ARG

LABEL org.opencontainers.image.created=${DATE_ARG}
LABEL org.opencontainers.image.revision=${BUILD_ARG}
LABEL org.opencontainers.image.version=${VERSION_ARG}
LABEL org.opencontainers.image.url=https://hub.docker.com/r/dockurr/tor/
LABEL org.opencontainers.image.source=https://github.com/dockur/tor/

EXPOSE 9050
EXPOSE 9051

HEALTHCHECK --interval=60s --timeout=15s --start-period=20s \
    CMD curl -x socks5h://127.0.0.1:9050 'https://check.torproject.org/api/ip' | grep -qm1 -E '"IsTor"\s*:\s*true'

VOLUME ["/var/lib/tor"]

USER tor

CMD ["tor"]
