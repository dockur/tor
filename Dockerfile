FROM alpine:edge

ENV TOR_NICKNAME="tor-relay1337"
#ENV TOR_USER=tor

# Install Tor
RUN apk add --no-cache tor && \
    mkdir -p /etc/tor #/var/lib/tor
    #chown -R tor:tor /etc/tor /var/lib/tor

# Copy torrc config file into image
COPY torrc /etc/tor/torrc
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
CMD ["tor", "-f", "/etc/tor/torrc"]
