#!/bin/bash
# Fix v2: perbaiki \n newline di Telegram + ip_info timeout + state init

CONFIG_FILE="/etc/pterodactyl-ddos-monitor.conf"
MONITOR_SCRIPT="/usr/local/bin/ptero-ddos-monitor.sh"
SERVICE_FILE="/etc/systemd/system/ptero-ddos-monitor.service"

echo "════════════════════════════════════════════"
echo "  🔧 FIX DDOS MONITOR v2"
echo "  Fix: newline + ip_info + state init"
echo "  by @baniwwwXD | baniwwDeveloper"
echo "════════════════════════════════════════════"
echo ""

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Config tidak ditemukan: $CONFIG_FILE"
  exit 1
fi

source "$CONFIG_FILE"
echo "✅ Config: BOT_TOKEN=${BOT_TOKEN:0:10}... CHAT_ID=$CHAT_ID"

apt-get install -y curl geoip-bin geoip-database iproute2 net-tools > /dev/null 2>&1
echo "✅ Dependency OK"

systemctl stop ptero-ddos-monitor 2>/dev/null

# Init state supaya tidak baca log lama
mkdir -p /tmp/ptero-ddos-state
wc -l < /var/log/syslog > /tmp/ptero-ddos-state/syslog_last 2>/dev/null || echo 0 > /tmp/ptero-ddos-state/syslog_last
wc -l < /var/log/fail2ban.log > /tmp/ptero-ddos-state/f2b_last 2>/dev/null || echo 0 > /tmp/ptero-ddos-state/f2b_last
echo "✅ State diinit (tidak baca log lama)"

cat > "$MONITOR_SCRIPT" << 'MONEOF'
#!/bin/bash

source /etc/pterodactyl-ddos-monitor.conf

STATE_DIR="/tmp/ptero-ddos-state"
mkdir -p "$STATE_DIR"
ALERT_COOLDOWN=300

# ─── Kirim Telegram — pakai printf supaya \n jadi newline beneran ───
tg() {
  local text
  # printf expand \n jadi newline beneran
  text=$(printf '%b' "$1")
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "parse_mode=HTML" \
    --data-urlencode "text=${text}" > /dev/null 2>&1
}

# ─── Info IP detail — timeout lebih panjang, fallback geoiplookup ───
ip_info() {
  local ip="$1"
  local loc="Unknown" org="Unknown" rdns="No rDNS"

  # Coba ip-api.com
  local api
  api=$(curl -s --max-time 5 "http://ip-api.com/json/${ip}?fields=country,regionName,city,isp,org,status" 2>/dev/null)

  if echo "$api" | grep -q '"status":"success"'; then
    loc=$(echo "$api" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f\"{d.get('city','?')}, {d.get('regionName','?')}, {d.get('country','?')}\")" 2>/dev/null || echo "Unknown")
    org=$(echo "$api" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('org', d.get('isp','Unknown')))" 2>/dev/null || echo "Unknown")
  elif command -v geoiplookup &>/dev/null; then
    loc=$(geoiplookup "$ip" 2>/dev/null | grep "Country" | grep -oP ': \K.*' | head -1 || echo "Unknown")
  fi

  # Reverse DNS
  rdns=$(host "$ip" 2>/dev/null | grep -oP 'pointer \K\S+' | sed 's/\.$//' | head -1 || echo "No rDNS")

  echo "${loc}|||${org}|||${rdns}"
}

on_cooldown() {
  local f="${STATE_DIR}/$(echo "$1" | tr '/:.' '_')"
  if [ -f "$f" ]; then
    local last now
    last=$(cat "$f"); now=$(date +%s)
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

# ─── Monitor 1: Koneksi aktif flood ──────────────────────────
check_connections() {
  local now; now=$(date '+%d/%m/%Y %H:%M:%S')
  ss -tn state established 2>/dev/null | awk 'NR>1{print $5}' | \
    grep -oP '^\d+\.\d+\.\d+\.\d+' | sort | uniq -c | sort -rn | \
    while read -r count ip; do
      is_private "$ip" && continue
      [ "$count" -le "$THRESHOLD" ] && continue
      on_cooldown "conn_${ip}" && continue
      set_cooldown "conn_${ip}"

      local info loc org rdns auto_ban=""
      info=$(ip_info "$ip")
      loc=$(echo "$info" | cut -d'|||' -f1)
      org=$(echo "$info" | cut -d'|||' -f2)
      rdns=$(echo "$info" | cut -d'|||' -f3)

      if [ "$count" -gt $((THRESHOLD * 3)) ]; then
        perm_ban "$ip" "conn_flood_${count}"
        auto_ban="\n🔒 <b>AUTO PERMANENT BAN!</b>"
      fi

      tg "🚨 <b>CONNECTION FLOOD!</b>\n\n🌐 <b>IP:</b> <code>${ip}</code>\n📊 <b>Koneksi:</b> <b>${count}</b>\n🌍 <b>Lokasi:</b> ${loc}\n🏢 <b>ISP/Org:</b> ${org}\n🔍 <b>rDNS:</b> ${rdns}\n🕐 <b>Waktu:</b> ${now}${auto_ban}"
    done
}

# ─── Monitor 2: HTTP flood dari nginx log ────────────────────
check_nginx_flood() {
  local access_log="/var/log/nginx/access.log"
  [ ! -f "$access_log" ] && return
  local now; now=$(date '+%d/%m/%Y %H:%M:%S')
  local half_threshold=$(( THRESHOLD / 2 ))

  tail -5000 "$access_log" 2>/dev/null | awk '{print $1}' | \
    sort | uniq -c | sort -rn | head -20 | \
    while read -r count ip; do
      is_private "$ip" && continue
      [ "$count" -le "$half_threshold" ] && continue
      on_cooldown "nginx_${ip}" && continue
      set_cooldown "nginx_${ip}"

      local info loc org rdns auto_ban=""
      info=$(ip_info "$ip")
      loc=$(echo "$info" | cut -d'|||' -f1)
      org=$(echo "$info" | cut -d'|||' -f2)
      rdns=$(echo "$info" | cut -d'|||' -f3)

      local top_urls
      top_urls=$(grep "^${ip} " "$access_log" 2>/dev/null | tail -500 | \
        awk '{print $7}' | sort | uniq -c | sort -rn | head -3 | \
        awk '{printf "• %s (%s req)\n", $2, $1}')

      local statuses
      statuses=$(grep "^${ip} " "$access_log" 2>/dev/null | tail -500 | \
        awk '{print $9}' | sort | uniq -c | sort -rn | \
        awk '{printf "%s:%s ", $2, $1}')

      if [ "$count" -gt $((THRESHOLD * 2)) ]; then
        perm_ban "$ip" "http_flood_${count}"
        auto_ban="\n🔒 <b>AUTO PERMANENT BAN!</b>"
      fi

      tg "⚠️ <b>HTTP FLOOD!</b>\n\n🌐 <b>IP:</b> <code>${ip}</code>\n📊 <b>Request:</b> <b>${count}</b>\n🌍 <b>Lokasi:</b> ${loc}\n🏢 <b>ISP/Org:</b> ${org}\n🔍 <b>rDNS:</b> ${rdns}\n🕐 <b>Waktu:</b> ${now}\n\n🎯 <b>URL Target:</b>\n${top_urls}\n📈 <b>Status:</b> ${statuses}${auto_ban}"
    done
}

# ─── Monitor 3: Fail2ban ban baru ────────────────────────────
check_new_bans() {
  local f2b_log="/var/log/fail2ban.log"
  [ ! -f "$f2b_log" ] && return
  local now; now=$(date '+%d/%m/%Y %H:%M:%S')

  local sf="${STATE_DIR}/f2b_last"
  local last=0 cur
  [ -f "$sf" ] && last=$(cat "$sf")
  cur=$(wc -l < "$f2b_log")
  echo "$cur" > "$sf"
  [ "$cur" -le "$last" ] && return

  tail -$((cur - last + 1)) "$f2b_log" 2>/dev/null | grep " Ban " | \
    grep -oP 'Ban \K[\d.]+' | sort -u | \
    while read -r ip; do
      on_cooldown "f2b_${ip}" && continue
      set_cooldown "f2b_${ip}"

      local info loc org rdns
      info=$(ip_info "$ip")
      loc=$(echo "$info" | cut -d'|||' -f1)
      org=$(echo "$info" | cut -d'|||' -f2)
      rdns=$(echo "$info" | cut -d'|||' -f3)

      local jail
      jail=$(tail -$((cur - last + 1)) "$f2b_log" 2>/dev/null | \
        grep "Ban ${ip}" | grep -oP '\[\K[^\]]+' | head -1)

      local total
      total=$(ipset list ptero-banned 2>/dev/null | grep -c "^[0-9]" || echo "?")

      tg "🔒 <b>IP PERMANENT BANNED!</b>\n\n🌐 <b>IP:</b> <code>${ip}</code>\n🌍 <b>Lokasi:</b> ${loc}\n🏢 <b>ISP/Org:</b> ${org}\n🔍 <b>rDNS:</b> ${rdns}\n🏷️ <b>Trigger:</b> ${jail:-unknown}\n🕐 <b>Waktu:</b> ${now}\n📊 <b>Total Banned:</b> ${total} IP\n\n💡 Unban: <code>ptero-ban del ${ip}</code>"
    done
}

# ─── Monitor 4: VPS overload ─────────────────────────────────
check_vps_resources() {
  local now; now=$(date '+%d/%m/%Y %H:%M:%S')
  local cpu ram_total ram_used ram_pct=0 disk_pct

  cpu=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d'.' -f1 | tr -d '%,')
  ram_total=$(free -m | awk 'NR==2{print $2}')
  ram_used=$(free -m | awk 'NR==2{print $3}')
  [ "${ram_total:-0}" -gt 0 ] && ram_pct=$((ram_used * 100 / ram_total))
  disk_pct=$(df / | awk 'NR==2{print $5}' | tr -d '%')

  if [ "${cpu:-0}" -gt 90 ] || [ "$ram_pct" -gt 95 ] || [ "${disk_pct:-0}" -gt 95 ]; then
    on_cooldown "vps_overload" && return
    set_cooldown "vps_overload"

    local top_procs
    top_procs=$(ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1&&NR<=6{printf "• %s %.1f%%\n",$11,$3}')

    tg "🔥 <b>VPS OVERLOAD!</b>\n\n⚙️ <b>CPU:</b> ${cpu}%\n🧠 <b>RAM:</b> ${ram_used}/${ram_total}MB (${ram_pct}%)\n💾 <b>Disk:</b> ${disk_pct}%\n🕐 <b>Waktu:</b> ${now}\n\n🔝 <b>Top Proses:</b>\n${top_procs}\n\n⚠️ <i>Kemungkinan sedang di-DDoS!</i>"
  fi
}

# ─── Monitor 5: SYN flood dari kernel log ────────────────────
check_syn_flood() {
  local syslog="/var/log/syslog"
  [ ! -f "$syslog" ] && return
  local now; now=$(date '+%d/%m/%Y %H:%M:%S')

  local sf="${STATE_DIR}/syslog_last"
  local last=0 cur
  [ -f "$sf" ] && last=$(cat "$sf")
  cur=$(wc -l < "$syslog")
  echo "$cur" > "$sf"
  [ "$cur" -le "$last" ] && return

  tail -$((cur - last + 1)) "$syslog" 2>/dev/null | grep "SRC=" | \
    grep -oP 'SRC=\K[\d.]+' | sort | uniq -c | sort -rn | awk '$1>5{print $2}' | \
    while read -r ip; do
      is_private "$ip" && continue
      on_cooldown "syn_${ip}" && continue
      set_cooldown "syn_${ip}"

      local info loc org
      info=$(ip_info "$ip")
      loc=$(echo "$info" | cut -d'|||' -f1)
      org=$(echo "$info" | cut -d'|||' -f2)

      perm_ban "$ip" "syn_flood"
      tg "🔴 <b>SYN FLOOD DETECTED!</b>\n\n🌐 <b>IP:</b> <code>${ip}</code>\n🌍 <b>Lokasi:</b> ${loc}\n🏢 <b>ISP/Org:</b> ${org}\n🕐 <b>Waktu:</b> ${now}\n🔒 <b>AUTO PERMANENT BAN!</b>"
    done
}

# ─── Notif startup ────────────────────────────────────────────
tg "✅ <b>DDoS Monitor Aktif!</b>\n\n🖥️ <b>VPS:</b> <code>$(hostname -I | awk '{print $1}')</code>\n⚙️ <b>Threshold:</b> ${THRESHOLD}\n⏱️ <b>Interval:</b> ${INTERVAL}s\n🕐 <b>Start:</b> $(date '+%d/%m/%Y %H:%M:%S')\n\n📡 <b>Monitor aktif:</b>\n• Connection flood\n• HTTP request flood\n• Fail2ban auto ban\n• VPS overload\n• SYN flood\n\n🔒 Semua IP terdeteksi → <b>PERMANENT BAN</b>"

echo "DDoS Monitor started — threshold: ${THRESHOLD}, interval: ${INTERVAL}s"
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
echo "✅ Monitor script diupdate"

# Pastikan service file ada
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
systemctl restart ptero-ddos-monitor
sleep 3

if systemctl is-active --quiet ptero-ddos-monitor; then
  echo ""
  echo "════════════════════════════════════════════"
  echo "  ✅ DDOS MONITOR BERHASIL DIUPDATE!"
  echo "════════════════════════════════════════════"
  echo ""
  echo "✅ Fix yang diterapkan:"
  echo "   • \\n sekarang jadi newline beneran di Telegram"
  echo "   • ip_info timeout diperpanjang + fallback geoip"
  echo "   • State diinit, tidak baca log lama lagi"
  echo ""
  echo "📲 Notif startup akan masuk ke Telegram sekarang"
else
  echo "❌ Service gagal start!"
  journalctl -u ptero-ddos-monitor -n 15 --no-pager
fi
