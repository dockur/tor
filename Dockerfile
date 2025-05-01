FROM alpine:edge

ENV TOR_NICKNAME="tor-relay1337"
#ENV TOR_USER=tor

# Install Tor
RUN apk add --no-cache tor && \
    mkdir -p /etc/tor #/var/lib/tor


# Copy torrc config file into image
COPY torrc /etc/tor/torrc
COPY torrc /etc/tor/torrc.base
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN chown tor:tor /etc/tor/torrc

# Expose relay ports
EXPOSE 9001 9030

# Volume for relay identity/state
VOLUME ["/var/lib/tor"]

# Run as the unprivileged tor user
#RUN adduser -D tor
USER tor
RUN chown tor /var/lib/tor

# Start Tor in the foreground
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
