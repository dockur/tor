#!/bin/sh

: "${IPV4_ONLY:=1}"
: "${OR_PORT:=9001}"
: "${DIR_PORT:=9030}"
: "${RELAY_BANDWIDTH_RATE:=400 KBytes}"
: "${RELAY_BANDWIDTH_BURST:=800 KBytes}"
: "${ACCOUNTING_MAX:=300 GBytes}"
: "${ACCOUNTING_START:=month 1 00:00}"
: "${NICKNAME:=MyDockerRelay}"
: "${CONTACT_INFO:=myemail@example.com}"

if [ "$IPV4_ONLY" = "1" ]; then
    echo "ORPort $OR_PORT IPv4Only" >> /etc/tor/torrc
    echo "DirPort $DIR_PORT IPv4Only" >> /etc/tor/torrc
else
    echo "ORPort $OR_PORT" >> /etc/tor/torrc
    echo "DirPort $DIR_PORT" >> /etc/tor/torrc
fi
echo "RelayBandwidthBurst $RELAY_BANDWIDTH_BURST" >> /etc/tor/torrc
echo "AccountingMax $ACCOUNTING_MAX" >> /etc/tor/torrc
echo "AccountingStart $ACCOUNTING_START" >> /etc/tor/torrc
echo "Nickname $NICKNAME" >> /etc/tor/torrc
echo "ContactInfo $CONTACT_INFO" >> /etc/tor/torrc

PUBLIC_IP=$(curl -s https://api.ipify.org)
echo "Address $PUBLIC_IP" >> /etc/tor/torrc

#cat /etc/tor/torcc

exec tor -f /etc/tor/torrc
