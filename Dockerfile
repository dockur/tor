FROM alpine:edge

RUN apk add --no-cache curl tor && rm -rf /var/cache/apk/* && \
    sed "1s/^/SocksPort 0.0.0.0:9050\n/" /etc/tor/torrc.sample > /etc/tor/torrc

RUN sed -i '/tor:x:/d' /etc/passwd && sed -i 's/65533:tor/65533:/' /etc/group && \
    addgroup -g 101 -S toranon && adduser -S -D -H -u 100 -s /sbin/nologin -G toranon -g toranon toranon

EXPOSE 9050 9051

HEALTHCHECK --interval=300s --timeout=15s --start-period=60s --start-interval=10s \
    CMD curl -x socks5h://127.0.0.1:9050 'https://check.torproject.org/api/ip' | grep -qm1 -E '"IsTor"\s*:\s*true'

VOLUME ["/var/lib/tor"]

USER toranon
CMD ["tor"]
