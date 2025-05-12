#!/bin/sh

: "${RELAY_BANDWIDTH_RATE:=400 KB}"
: "${RELAY_BANDWIDTH_BURST:=800 KB}"
: "${ACCOUNTING_MAX:=300 GB}"
: "${ACCOUNTING_START:=month 1 00:00}"
: "${NICKNAME:=MyDockerRelay}"
: "${CONTACT_INFO:=myemail@example.com}"
: "${IPV4_ONLY:=1}"

echo "Bandwidth Rate: $RELAY_BANDWIDTH_RATE" >> /etc/tor/torrc
echo "Bandwidth Burst: $RELAY_BANDWIDTH_BURST" >> /etc/tor/torrc
echo "Accounting Max: $ACCOUNTING_MAX" >> /etc/tor/torrc
echo "Accounting Start: $ACCOUNTING_START" >> /etc/tor/torrc
echo "Nickname: $NICKNAME" >> /etc/tor/torrc
echo "Contact Info: $CONTACT_INFO" >> /etc/tor/torrc
if [ "$IPV4_ONLY" = "1" ]; then
    echo "IPv4Only 1" >> /etc/tor/torrc
fi

PUBLIC_IP=$(curl -s https://api.ipify.org)
echo "Address $PUBLIC_IP" >> /etc/tor/torrc
exec tor -f /etc/tor/torrc
