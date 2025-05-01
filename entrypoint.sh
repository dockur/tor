#!/bin/sh
PUBLIC_IP=$(curl -s https://api.ipify.org)
echo "Address $PUBLIC_IP" >> /etc/tor/torrc.base
exec tor -f /etc/tor/torrc.base
