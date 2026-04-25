#!/usr/bin/with-contenv bash
# linuxserver/qbittorrent custom-cont-init.d hook.
#
# Forces libtorrent to bind to Gluetun's WireGuard interface (tun0) and
# auto-discovers the current tun0 IPv4 at startup. This stops libtorrent
# from attempting AAAA/IPv6 sends to trackers (which return EPERM in
# Gluetun's namespace and surface as "Operation not permitted" in the
# Trackers tab) and acts as a kill switch when the VPN drops.

set -eu

CONF=/config/qBittorrent/qBittorrent.conf
[ -f "$CONF" ] || { echo "[qb-bind] no config yet; will apply on next start"; exit 0; }

TUN_ADDR=$(ip -4 -o addr show tun0 2>/dev/null | awk 'NR==1 {split($4,a,"/"); print a[1]}')

awk -v addr="$TUN_ADDR" '
  function emit() {
    print "Session\\Interface=tun0"
    print "Session\\InterfaceName=tun0"
    print "Session\\InterfaceAddress=" addr
  }
  /^\[BitTorrent\]/ { print; emit(); in_bt=1; injected=1; next }
  /^\[/             { in_bt=0 }
  in_bt && /^Session\\(Interface|InterfaceName|InterfaceAddress)=/ { next }
                    { print }
  END { if (!injected) { print ""; print "[BitTorrent]"; emit() } }
' "$CONF" > "$CONF.tmp"

mode=$(stat -c '%a' "$CONF")
own=$(stat -c '%u:%g' "$CONF")
mv "$CONF.tmp" "$CONF"
chmod "$mode" "$CONF"
chown "$own"  "$CONF"

echo "[qb-bind] bound libtorrent to tun0 (addr=${TUN_ADDR:-<pending>})"
