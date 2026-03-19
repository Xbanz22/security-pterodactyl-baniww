#!/bin/bash

MONITOR_SCRIPT="/usr/local/bin/ptero-ddos-monitor.sh"
SERVICE_FILE="/etc/systemd/system/ptero-ddos-monitor.service"
CONFIG_FILE="/etc/pterodactyl-ddos-monitor.conf"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

clear
echo "════════════════════════════════════════════"
echo "  📡  PTERODACTYL DDOS MONITOR"
echo "  Real-time notif Telegram + Permanent Ban"
echo "  by @baniwwwXD | baniwwDeveloper"
echo "════════════════════════════════════════════"
echo ""

if [ "$EUID" -ne 0 ]; then
  echo "❌ Jalankan script ini sebagai root!"
  exit 1
fi

if [ -f "$CONFIG_FILE" ]; then
  echo "✅ ALREADY_INSTALLED — DDoS Monitor sudah terpasang!"
  echo ""
  echo "Kelola: systemctl [status|restart|stop] ptero-ddos-monitor"
  exit 0
fi

echo "📋 Masukkan konfigurasi:"
echo ""
read -p "🤖 Bot Token: " BOT_TOKEN
[ -z "$BOT_TOKEN" ] && echo "❌ Token kosong!" && exit 1

read -p "💬 Chat ID owner: " CHAT_ID
[ -z "$CHAT_ID" ] && echo "❌ Chat ID kosong!" && exit 1

read -p "⚙️  Threshold koneksi sebelum alert (default: 100): " THRESHOLD
THRESHOLD=${THRESHOLD:-100}

read -p "⏱️  Interval cek detik (default: 30): " INTERVAL
INTERVAL=${INTERVAL:-30}

echo ""
cat > "$CONFIG_FILE" << CONFEOF
BOT_TOKEN=${BOT_TOKEN}
CHAT_ID=${CHAT_ID}
THRESHOLD=${THRESHOLD}
INTERVAL=${INTERVAL}
INSTALLED=${TIMESTAMP}
CONFEOF
chmod 600 "$CONFIG_FILE"
echo "✅ Konfigurasi disimpan"

apt-get install -y curl geoip-bin geoip-database iproute2 net-tools > /dev/null 2>&1
echo "✅ Dependency terinstall"

cat > "$MONITOR_SCRIPT" << 'MONEOF'
#!/bin/bash

source /etc/pterodactyl-ddos-monitor.conf

STATE_DIR="/tmp/ptero-ddos-state"
mkdir -p "$STATE_DIR"
ALERT_COOLDOWN=300

tg() {
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "parse_mode=HTML" \
    -d "text=$1" > /dev/null 2>&1
}

ip_info() {
  local ip="$1"
  local result="Unknown|||Unknown|||No rDNS"
  local api=$(curl -s --max-time 3 "http://ip-api.com/json/${ip}?fields=country,regionName,city,isp,org" 2>/dev/null)
  if [ -n "$api" ]; then
    local loc=$(echo "$api" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"{d.get('city','?')}, {d.get('regionName','?')}, {d.get('country','?')}\")" 2>/dev/null)
    local org=$(echo "$api" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('org', d.get('isp','Unknown')))" 2>/dev/null)
    local rdns=$(host "$ip" 2>/dev/null | grep -oP 'pointer \K\S+' | sed 's/\.$//' | head -1)
    result="${loc:-Unknown}|||${org:-Unknown}|||${rdns:-No rDNS}"
  fi
  echo "$result"
}

on_cooldown() {
  local f="${STATE_DIR}/$(echo "$1" | tr '/:.' '_')"
  if [ -f "$f" ]; then
    local last=$(cat "$f"); local now=$(date +%s)
    [ $((now - last)) -lt $ALERT_COOLDOWN ] && return 0
  fi
  return 1
}

set_cooldown() {
  date +%s > "${STATE_DIR}/$(echo "$1" | tr '/:.' '_')"
}

perm_ban() {
  ipset add ptero-banned "$1" timeout 0 2>/dev/null || true
  echo "$(date '+%Y-%m-%d %H:%M:%S') AUTO_BAN $1 [$2]" >> /var/log/ptero-banned.log
}

is_private() {
  [[ "$1" =~ ^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]] && return 0
  return 1
}

# Monitor 1: Koneksi aktif flood
check_connections() {
  local now=$(date '+%d/%m/%Y %H:%M:%S')
  ss -tn state established 2>/dev/null | awk 'NR>1{print $5}' | \
    grep -oP '^\d+\.\d+\.\d+\.\d+' | sort | uniq -c | sort -rn | \
    while read count ip; do
      is_private "$ip" && continue
      if [ "$count" -gt "$THRESHOLD" ]; then
        on_cooldown "conn_${ip}" && continue
        set_cooldown "conn_${ip}"
        local info=$(ip_info "$ip")
        local loc=$(echo "$info" | cut -d'|||' -f1)
        local org=$(echo "$info" | cut -d'|||' -f2)
        local rdns=$(echo "$info" | cut -d'|||' -f3)
        local auto_ban=""
        if [ "$count" -gt $((THRESHOLD * 3)) ]; then
          perm_ban "$ip" "conn_flood_${count}"
          auto_ban="
🔒 <b>AUTO PERMANENT BAN!</b>"
        fi
        tg "🚨 <b>CONNECTION FLOOD!</b>

🌐 <b>IP:</b> <code>${ip}</code>
📊 <b>Koneksi:</b> <b>${count}</b>
🌍 <b>Lokasi:</b> ${loc}
🏢 <b>ISP/Org:</b> ${org}
🔍 <b>rDNS:</b> ${rdns}
🕐 <b>Waktu:</b> ${now}${auto_ban}"
      fi
    done
}

# Monitor 2: HTTP request flood
check_nginx_flood() {
  local access_log="/var/log/nginx/access.log"
  [ ! -f "$access_log" ] && return
  local now=$(date '+%d/%m/%Y %H:%M:%S')
  tail -5000 "$access_log" 2>/dev/null | awk '{print $1}' | \
    sort | uniq -c | sort -rn | head -20 | \
    while read count ip; do
      is_private "$ip" && continue
      if [ "$count" -gt $((THRESHOLD / 2)) ]; then
        on_cooldown "nginx_${ip}" && continue
        set_cooldown "nginx_${ip}"
        local info=$(ip_info "$ip")
        local loc=$(echo "$info" | cut -d'|||' -f1)
        local org=$(echo "$info" | cut -d'|||' -f2)
        local rdns=$(echo "$info" | cut -d'|||' -f3)
        local top_urls=$(grep "^${ip} " "$access_log" | tail -500 | awk '{print $7}' | sort | uniq -c | sort -rn | head -3 | awk '{printf "• %s (%s)\n", $2, $1}')
        local statuses=$(grep "^${ip} " "$access_log" | tail -500 | awk '{print $9}' | sort | uniq -c | sort -rn | awk '{printf "%s:%s ", $2, $1}')
        local auto_ban=""
        if [ "$count" -gt $((THRESHOLD * 2)) ]; then
          perm_ban "$ip" "http_flood_${count}"
          auto_ban="
🔒 <b>AUTO PERMANENT BAN!</b>"
        fi
        tg "⚠️ <b>HTTP FLOOD!</b>

🌐 <b>IP:</b> <code>${ip}</code>
📊 <b>Request:</b> <b>${count}</b>
🌍 <b>Lokasi:</b> ${loc}
🏢 <b>ISP/Org:</b> ${org}
🔍 <b>rDNS:</b> ${rdns}
🕐 <b>Waktu:</b> ${now}
🎯 <b>URL Target:</b>
${top_urls}
📈 <b>Status:</b> ${statuses}${auto_ban}"
      fi
    done
}

# Monitor 3: Fail2ban ban baru
check_new_bans() {
  local f2b_log="/var/log/fail2ban.log"
  [ ! -f "$f2b_log" ] && return
  local now=$(date '+%d/%m/%Y %H:%M:%S')
  local sf="${STATE_DIR}/f2b_last"
  local last=0; [ -f "$sf" ] && last=$(cat "$sf")
  local cur=$(wc -l < "$f2b_log"); echo "$cur" > "$sf"
  [ "$cur" -le "$last" ] && return
  tail -$((cur - last + 1)) "$f2b_log" 2>/dev/null | grep " Ban " | \
    grep -oP 'Ban \K[\d.]+' | sort -u | \
    while read ip; do
      on_cooldown "f2b_${ip}" && continue
      set_cooldown "f2b_${ip}"
      local info=$(ip_info "$ip")
      local loc=$(echo "$info" | cut -d'|||' -f1)
      local org=$(echo "$info" | cut -d'|||' -f2)
      local rdns=$(echo "$info" | cut -d'|||' -f3)
      local jail=$(tail -$((cur - last + 1)) "$f2b_log" | grep "Ban ${ip}" | grep -oP '\[\K[^\]]+' | head -1)
      local total=$(ipset list ptero-banned 2>/dev/null | grep -c "^[0-9]" || echo "?")
      tg "🔒 <b>IP PERMANENT BANNED!</b>

🌐 <b>IP:</b> <code>${ip}</code>
🌍 <b>Lokasi:</b> ${loc}
🏢 <b>ISP/Org:</b> ${org}
🔍 <b>rDNS:</b> ${rdns}
🏷️ <b>Trigger:</b> ${jail}
🕐 <b>Waktu:</b> ${now}
📊 <b>Total Banned:</b> ${total} IP

💡 <code>ptero-ban del ${ip}</code>"
    done
}

# Monitor 4: VPS overload
check_vps_resources() {
  local now=$(date '+%d/%m/%Y %H:%M:%S')
  local cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d'.' -f1 | tr -d '%,')
  local ram_total=$(free -m | awk 'NR==2{print $2}')
  local ram_used=$(free -m | awk 'NR==2{print $3}')
  local ram_pct=0; [ "${ram_total:-0}" -gt 0 ] && ram_pct=$((ram_used * 100 / ram_total))
  local disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')
  if [ "${cpu:-0}" -gt 90 ] || [ "$ram_pct" -gt 95 ] || [ "${disk_pct:-0}" -gt 95 ]; then
    on_cooldown "vps_overload" && return
    set_cooldown "vps_overload"
    local top_procs=$(ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1&&NR<=6{printf "• %s %.1f%%\n",$11,$3}')
    tg "🔥 <b>VPS OVERLOAD!</b>

⚙️ <b>CPU:</b> ${cpu}%
🧠 <b>RAM:</b> ${ram_used}/${ram_total}MB (${ram_pct}%)
💾 <b>Disk:</b> ${disk_pct}%
🕐 <b>Waktu:</b> ${now}

🔝 <b>Top Proses:</b>
${top_procs}

⚠️ <i>Kemungkinan sedang di-DDoS!</i>"
  fi
}

# Monitor 5: SYN flood dari kernel log
check_syn_flood() {
  local syslog="/var/log/syslog"
  [ ! -f "$syslog" ] && return
  local now=$(date '+%d/%m/%Y %H:%M:%S')
  local sf="${STATE_DIR}/syslog_last"; local last=0
  [ -f "$sf" ] && last=$(cat "$sf")
  local cur=$(wc -l < "$syslog"); echo "$cur" > "$sf"
  [ "$cur" -le "$last" ] && return
  tail -$((cur - last + 1)) "$syslog" 2>/dev/null | grep "SRC=" | \
    grep -oP 'SRC=\K[\d.]+' | sort | uniq -c | sort -rn | awk '$1>5{print $2}' | \
    while read ip; do
      is_private "$ip" && continue
      on_cooldown "syn_${ip}" && continue
      set_cooldown "syn_${ip}"
      local info=$(ip_info "$ip")
      local loc=$(echo "$info" | cut -d'|||' -f1)
      local org=$(echo "$info" | cut -d'|||' -f2)
      perm_ban "$ip" "syn_flood"
      tg "🔴 <b>SYN FLOOD DETECTED!</b>

🌐 <b>IP:</b> <code>${ip}</code>
🌍 <b>Lokasi:</b> ${loc}
🏢 <b>ISP/Org:</b> ${org}
🕐 <b>Waktu:</b> ${now}
🔒 <b>AUTO PERMANENT BAN!</b>"
    done
}

# Notif startup
tg "✅ <b>DDoS Monitor Aktif!</b>

🖥️ <b>VPS:</b> <code>$(hostname -I | awk '{print $1}')</code>
⚙️ <b>Threshold:</b> ${THRESHOLD}
⏱️ <b>Interval:</b> ${INTERVAL}s
🕐 <b>Start:</b> $(date '+%d/%m/%Y %H:%M:%S')

📡 Monitor: Connection flood, HTTP flood, Fail2ban ban, VPS overload, SYN flood
🔒 Semua terdeteksi → <b>PERMANENT BAN</b>"

echo "DDoS Monitor started"
while true; do
  check_connections
  check_nginx_flood
  check_new_bans
  check_vps_resources
  check_syn_flood
  sleep "$INTERVAL"
done
MONEOF

chmod +x "$MONITOR_SCRIPT"

cat > "$SERVICE_FILE" << SVCEOF
[Unit]
Description=Pterodactyl DDoS Monitor by baniwwDeveloper
After=network.target nginx.service fail2ban.service

[Service]
Type=simple
ExecStart=$MONITOR_SCRIPT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable ptero-ddos-monitor > /dev/null 2>&1
systemctl start ptero-ddos-monitor
sleep 2

systemctl is-active --quiet ptero-ddos-monitor && \
  echo "✅ DDoS Monitor aktif" || \
  echo "⚠️ Gagal start: journalctl -u ptero-ddos-monitor -n 20"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ DDOS MONITOR BERHASIL DIPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "📲 Notif ke Chat ID: ${CHAT_ID}"
echo ""
echo "📋 Notif yang dikirim:"
echo "   🚨 Connection flood (IP+lokasi+ISP+rDNS)"
echo "   ⚠️  HTTP flood (URL target+HTTP status)"
echo "   🔒 IP permanent banned (detail+total)"
echo "   🔥 VPS overload (CPU/RAM/Disk+proses)"
echo "   🔴 SYN flood (auto ban)"
echo ""
echo "📋 Kelola:"
echo "   systemctl status ptero-ddos-monitor"
echo "   journalctl -u ptero-ddos-monitor -f"
echo ""
echo "════════════════════════════════════════════"
