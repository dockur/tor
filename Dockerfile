FROM alpine:edge

# Install Tor (no curl or SOCKS proxy needed for a relay)
RUN apk add --no-cache tor && \
    rm -rf /var/cache/apk/* && \
    mkdir -p /etc/tor && \
    mkdir -p /var/lib/tor && \
    chown tor:tor /var/lib/tor && \
    echo -e "\
RunAsDaemon 1\n\
ORPort 9001\n\
DirPort 9030\n\
Nickname MyDockerRelay\n\
ContactInfo myemail@example.com\n\
ExitRelay 0\n\
SocksPort 0\n\
Log notice stdout\n\
" > /etc/tor/torrc

# Expose relay ports
EXPOSE 9001 9030

# Volume for persistent relay identity and state
VOLUME ["/var/lib/tor"]

# Use the tor user (default in Alpine)
USER tor

# Run Tor in the foreground (as required by Docker)
CMD ["tor", "-f", "/etc/tor/torrc"]
