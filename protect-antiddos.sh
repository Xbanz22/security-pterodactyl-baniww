#!/bin/bash

MARKER_FILE="/etc/pterodactyl-antiddos.conf"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL ANTI DDOS PROTECTION"
echo "  Handle semua metode DDoS + Permanent Ban"
echo "  by @baniwwwXD | baniwwDeveloper"
echo "════════════════════════════════════════════"
echo ""

if [ "$EUID" -ne 0 ]; then
  echo "❌ Jalankan script ini sebagai root!"
  exit 1
fi

if [ -f "$MARKER_FILE" ]; then
  echo "✅ ALREADY_INSTALLED — Anti DDoS sudah terpasang!"
  exit 0
fi

echo "🔄 Menginstall dependency..."
apt-get update -qq > /dev/null 2>&1
apt-get install -y fail2ban iptables-persistent netfilter-persistent \
  ipset curl geoip-bin geoip-database > /dev/null 2>&1
echo "✅ Dependency terinstall"

# Buat ipset untuk permanent ban
ipset create ptero-banned hash:ip timeout 0 2>/dev/null || true
echo "✅ IPSet permanent ban dibuat"

# ════════════════════════════════════════════════════════════
# LAYER 1: IPTABLES
# ════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [LAYER 1] IPTABLES — 18 Metode DDoS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Drop IP dari permanent ban list
iptables -I INPUT 1 -m set --match-set ptero-banned src -j DROP

# 1. SYN Flood
iptables -A INPUT -p tcp --syn -m limit --limit 2/s --limit-burst 6 -j ACCEPT
iptables -A INPUT -p tcp --syn -j DROP
echo "✅ SYN Flood"

# 2. SYN-ACK Flood
iptables -A INPUT -p tcp --tcp-flags SYN,ACK SYN,ACK -m state --state NEW -j DROP
echo "✅ SYN-ACK Flood"

# 3. UDP Flood
iptables -A INPUT -p udp -m limit --limit 10/s --limit-burst 20 -j ACCEPT
iptables -A INPUT -p udp -j DROP
echo "✅ UDP Flood"

# 4. ICMP Flood
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 3 -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
echo "✅ ICMP/Ping Flood"

# 5. NULL Packet
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
echo "✅ NULL Packet"

# 6. XMAS Packet
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
echo "✅ XMAS Packet"

# 7. FIN Flood
iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN -j DROP
echo "✅ FIN Flood"

# 8. RST Flood
iptables -A INPUT -p tcp --tcp-flags RST RST -m limit --limit 2/s --limit-burst 6 -j ACCEPT
iptables -A INPUT -p tcp --tcp-flags RST RST -j DROP
echo "✅ RST Flood"

# 9. Teardrop (fragmented)
iptables -A INPUT -f -j DROP
echo "✅ Teardrop/Fragmented Packet"

# 10. Smurf Attack
iptables -A INPUT -p icmp --icmp-type echo-request -m pkttype --pkt-type broadcast -j DROP
iptables -A INPUT -p icmp --icmp-type echo-request -m pkttype --pkt-type multicast -j DROP
echo "✅ Smurf Attack"

# 11. Slowloris
iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 30 -j DROP
iptables -A INPUT -p tcp --dport 443 -m connlimit --connlimit-above 30 -j DROP
echo "✅ Slowloris (max 30 conn/IP)"

# 12. HTTP Flood
iptables -A INPUT -p tcp -m multiport --dports 80,443 -m state --state NEW \
  -m recent --set --name HTTP_FLOOD
iptables -A INPUT -p tcp -m multiport --dports 80,443 -m state --state NEW \
  -m recent --update --seconds 10 --hitcount 50 --name HTTP_FLOOD -j DROP
echo "✅ HTTP Flood (max 50 conn/10s per IP)"

# 13. Port Scan
iptables -A INPUT -p tcp --tcp-flags SYN,ACK,FIN,RST RST \
  -m limit --limit 1/s --limit-burst 2 -j ACCEPT
echo "✅ Port Scan"

# 14. DNS Amplification
iptables -A INPUT -p udp --dport 53 -m recent --set --name DNS_AMP
iptables -A INPUT -p udp --dport 53 -m recent --update --seconds 5 \
  --hitcount 20 --name DNS_AMP -j DROP
echo "✅ DNS Amplification"

# 15. NTP Amplification
iptables -A INPUT -p udp --dport 123 -m recent --set --name NTP_AMP
iptables -A INPUT -p udp --dport 123 -m recent --update --seconds 5 \
  --hitcount 10 --name NTP_AMP -j DROP
echo "✅ NTP Amplification"

# 16. SSDP Amplification
iptables -A INPUT -p udp --dport 1900 -j DROP
echo "✅ SSDP Amplification"

# 17. Memcached Amplification
iptables -A INPUT -p udp --dport 11211 -j DROP
iptables -A INPUT -p tcp --dport 11211 -j DROP
echo "✅ Memcached Amplification"

# 18. Global rate limit
iptables -A INPUT -p tcp -m state --state NEW \
  -m recent --set --name GLOBAL_RATE
iptables -A INPUT -p tcp -m state --state NEW \
  -m recent --update --seconds 60 --hitcount 100 --name GLOBAL_RATE -j DROP
echo "✅ Global Rate Limit (max 100 new conn/min per IP)"

netfilter-persistent save > /dev/null 2>&1
echo ""
echo "✅ [LAYER 1] Selesai — 18 metode dihandle!"

# ════════════════════════════════════════════════════════════
# LAYER 2: FAIL2BAN — Permanent ban
# ════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [LAYER 2] FAIL2BAN — Permanent Ban"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ -f /etc/fail2ban/jail.local ] && cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak_${TIMESTAMP}

cat > /etc/fail2ban/action.d/ptero-permanent-ban.conf << 'ACTEOF'
[Definition]
actionstart =
actionstop  =
actioncheck =
actionban   = ipset add ptero-banned <ip> timeout 0 2>/dev/null || true
              echo "$(date '+%%Y-%%m-%%d %%H:%%M:%%S') BANNED <ip> [<name>]" >> /var/log/ptero-banned.log
actionunban = ipset del ptero-banned <ip> 2>/dev/null || true
ACTEOF

cat > /etc/fail2ban/jail.local << 'F2BEOF'
[DEFAULT]
bantime  = -1
findtime = 300
maxretry = 3
banaction = ptero-permanent-ban
backend  = auto

[nginx-limit-req]
enabled  = true
filter   = nginx-limit-req
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 10
findtime = 60

[nginx-botsearch]
enabled  = true
filter   = nginx-botsearch
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 5
findtime = 120

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
maxretry = 3
findtime = 300

[pterodactyl-auth]
enabled  = true
filter   = pterodactyl-auth
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 5
findtime = 300

[http-flood]
enabled  = true
filter   = http-flood
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 200
findtime = 60

[nginx-conn-limit]
enabled  = true
filter   = nginx-conn-limit
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 5
findtime = 60

[port-scan]
enabled  = true
filter   = port-scan
logpath  = /var/log/syslog
maxretry = 2
findtime = 60
F2BEOF

cat > /etc/fail2ban/filter.d/pterodactyl-auth.conf << 'EOF'
[Definition]
failregex = ^<HOST> .* "POST /auth/login HTTP.*" 4[0-9][0-9]
            ^<HOST> .* "POST /api/client/account/two-factor HTTP.*" 4[0-9][0-9]
            ^<HOST> .* "POST /api/application/.* HTTP.*" 4[0-9][0-9]
ignoreregex =
EOF

cat > /etc/fail2ban/filter.d/http-flood.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD|PUT|DELETE) .* HTTP.*"
ignoreregex =
EOF

cat > /etc/fail2ban/filter.d/nginx-conn-limit.conf << 'EOF'
[Definition]
failregex = limiting connections by zone.*client: <HOST>
ignoreregex =
EOF

cat > /etc/fail2ban/filter.d/port-scan.conf << 'EOF'
[Definition]
failregex = kernel:.* SRC=<HOST> .* PROTO=TCP .* SYN
ignoreregex =
EOF

systemctl enable fail2ban > /dev/null 2>&1
systemctl restart fail2ban
sleep 2
systemctl is-active --quiet fail2ban && echo "✅ Fail2ban aktif — ban PERMANEN" || echo "⚠️ Fail2ban gagal start"
echo ""
echo "✅ [LAYER 2] Selesai!"

# ════════════════════════════════════════════════════════════
# LAYER 3: NGINX
# ════════════════════════════════════════════════════════════
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [LAYER 3] NGINX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PTERO_CONF=""
for f in /etc/nginx/sites-enabled/pterodactyl.conf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/conf.d/pterodactyl.conf; do
  [ -f "$f" ] && PTERO_CONF="$f" && break
done

if [ -n "$PTERO_CONF" ]; then
  SITES_DIR=$(dirname "$PTERO_CONF")
  mv "${SITES_DIR}"/*.bak_* /tmp/ 2>/dev/null
  cp "$PTERO_CONF" "/tmp/pterodactyl.conf.bak_ddos_${TIMESTAMP}"

  NGINX_MAIN="/etc/nginx/nginx.conf"
  if ! grep -q "ptero_conn" "$NGINX_MAIN" 2>/dev/null; then
    sed -i '/^http {/a\    limit_conn_zone $binary_remote_addr zone=ptero_conn:10m;\n    limit_conn_status 429;\n    client_body_timeout 10s;\n    client_header_timeout 10s;\n    keepalive_timeout 30s;\n    send_timeout 10s;' "$NGINX_MAIN"
    echo "✅ Anti-slowloris nginx config ditambahkan"
  fi

  python3 << PYEOF
import re
filepath = "$PTERO_CONF"
with open(filepath, 'r') as f:
    content = f.read()
changes = []
if 'ptero_conn' not in content:
    content = re.sub(r'(location\s+/\s*\{)', r'\1\n        limit_conn ptero_conn 20;', content, count=1)
    changes.append("limit_conn")
if 'X-Frame-Options' not in content:
    h = '\n    add_header X-Frame-Options "SAMEORIGIN" always;\n    add_header X-XSS-Protection "1; mode=block" always;\n    add_header X-Content-Type-Options "nosniff" always;\n    add_header X-Robots-Tag "noindex, nofollow" always;\n'
    content = re.sub(r'(server_name\s+[^;]+;)', r'\1' + h, content, count=1)
    changes.append("security headers")
with open(filepath, 'w') as f:
    f.write(content)
print("✅ Nginx: " + ", ".join(changes))
PYEOF

  nginx -t 2>&1
  if [ $? -eq 0 ]; then
    systemctl reload nginx && echo "✅ Nginx reloaded"
  else
    echo "❌ Nginx error, rollback layer 3..."
    cp "/tmp/pterodactyl.conf.bak_ddos_${TIMESTAMP}" "$PTERO_CONF"
  fi
fi

echo ""
echo "✅ [LAYER 3] Selesai!"

# ─── Helper script ptero-ban ──────────────────────────────────
cat > /usr/local/bin/ptero-ban << 'BANEOF'
#!/bin/bash
case "$1" in
  list)
    echo "═══════════════════════════════════════"
    echo "  📋 PERMANENT BAN LIST"
    echo "═══════════════════════════════════════"
    COUNT=$(ipset list ptero-banned 2>/dev/null | grep -c "^[0-9]" || echo 0)
    echo "  Total: $COUNT IP"
    echo "═══════════════════════════════════════"
    ipset list ptero-banned 2>/dev/null | grep "^[0-9]"
    ;;
  add)
    [ -z "$2" ] && echo "Usage: ptero-ban add [ip]" && exit 1
    ipset add ptero-banned "$2" timeout 0 2>/dev/null && \
      echo "$(date '+%Y-%m-%d %H:%M:%S') MANUAL_BAN $2" >> /var/log/ptero-banned.log && \
      echo "✅ $2 di-ban permanen" || echo "⚠️ IP mungkin sudah di-ban"
    ;;
  del)
    [ -z "$2" ] && echo "Usage: ptero-ban del [ip]" && exit 1
    ipset del ptero-banned "$2" 2>/dev/null && \
      echo "$(date '+%Y-%m-%d %H:%M:%S') UNBAN $2" >> /var/log/ptero-banned.log && \
      echo "✅ $2 di-unban" || echo "⚠️ IP tidak ditemukan"
    ;;
  count)
    ipset list ptero-banned 2>/dev/null | grep -c "^[0-9]" || echo 0
    ;;
  log)
    cat /var/log/ptero-banned.log 2>/dev/null || echo "Log kosong"
    ;;
  *)
    echo "Usage: ptero-ban [list|add [ip]|del [ip]|count|log]"
    ;;
esac
BANEOF

chmod +x /usr/local/bin/ptero-ban
echo "✅ Helper ptero-ban dibuat"

# Simpan marker
echo "INSTALLED=${TIMESTAMP}" > "$MARKER_FILE"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ ANTI DDOS BERHASIL DIPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "🛡️  18 Metode DDoS dihandle:"
echo "   SYN Flood, SYN-ACK, UDP, ICMP, NULL, XMAS"
echo "   FIN, RST, Teardrop, Smurf, Slowloris"
echo "   HTTP Flood, Port Scan, DNS/NTP/SSDP/Memcached Amp"
echo "   Global Rate Limit"
echo ""
echo "🔒 Semua ban PERMANEN (tidak expire)"
echo ""
echo "📋 Manage ban:"
echo "   ptero-ban list       → semua IP banned"
echo "   ptero-ban add [ip]   → ban manual"
echo "   ptero-ban del [ip]   → unban"
echo "   ptero-ban log        → lihat log ban"
echo ""
echo "════════════════════════════════════════════"
