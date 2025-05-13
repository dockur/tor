FROM alpine:edge

# Install Tor
RUN apk add --no-cache tor curl && \
    mkdir -p /etc/tor #/var/lib/tor

# Copy torrc config file into image
COPY torrc /etc/tor/torrc
RUN chown tor:tor /etc/tor/torrc && chmod u+w /etc/tor/torrc
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

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
