#!/bin/sh


TORRC_FILE=/etc/tor/torrc
cp /etc/tor/torrc.base "$TORRC_FILE"

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
    echo "ORPort $OR_PORT IPv4Only" >> "$TORRC_FILE"
    echo "DirPort $DIR_PORT IPv4Only" >> "$TORRC_FILE"
else
    echo "ORPort $OR_PORT" >> "$TORRC_FILE"
    echo "DirPort $DIR_PORT" >> "$TORRC_FILE"
fi
echo "RelayBandwidthBurst $RELAY_BANDWIDTH_BURST" >> "$TORRC_FILE"
echo "AccountingMax $ACCOUNTING_MAX" >> "$TORRC_FILE"
echo "AccountingStart $ACCOUNTING_START" >> "$TORRC_FILE"
echo "Nickname $NICKNAME" >> "$TORRC_FILE"
echo "ContactInfo $CONTACT_INFO" >> "$TORRC_FILE"

PUBLIC_IP=$(curl -s https://api.ipify.org)
echo "Address $PUBLIC_IP" >> "$TORRC_FILE"

cat "$TORRC_FILE"

exec tor -f "$TORRC_FILE"
