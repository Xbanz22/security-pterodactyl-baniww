#!/bin/bash
# fix-ddos-monitor.sh
# by @baniwwwXD | baniwwDeveloper
# DDoS Monitor — nginx + iptables + fail2ban (3-layer)

set -euo pipefail

CONF="/etc/pterodactyl-ddos-monitor.conf"
MONITOR_SCRIPT="/usr/local/bin/ptero-ddos-monitor.sh"
SERVICE_FILE="/etc/systemd/system/ptero-ddos-monitor.service"
STATE_DIR="/tmp/ptero-ddos-state"
LOG_FILE="/var/log/ptero-ddos-monitor.log"

# ── Warna ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

print_banner() {
  echo -e "${CYAN}"
  echo "════════════════════════════════════════════"
  echo "  📡  PTERODACTYL DDOS MONITOR"
  echo "  🛡️  3-Layer: nginx + iptables + fail2ban"
  echo "  📦  by @baniwwwXD | baniwwDeveloper"
  echo "════════════════════════════════════════════"
  echo -e "${NC}"
}

fail() { echo -e "${RED}❌ ERROR: $1${NC}" >&2; exit 1; }
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

print_banner

# ── Baca config ────────────────────────────────────────────────
[ -f "$CONF" ] || fail "Config tidak ditemukan di $CONF — jalankan setup wizard dulu!"
source "$CONF"

: "${BOT_TOKEN:?}" "${CHAT_ID:?}" "${THRESHOLD:?}" "${INTERVAL:?}"
: "${REQ_PER_SEC:=75}"
: "${BAN_DURATION:=3600}"
: "${WHITELIST_IPS:=}"

ok "Config loaded — threshold ${THRESHOLD} conn, ${REQ_PER_SEC} req/s, interval ${INTERVAL}s"

# ── Cek dependency ─────────────────────────────────────────────
info "Mengecek dependency..."
apt-get install -y -qq iptables ipset fail2ban jq curl \
  2>/dev/null | grep -v "^$" || true

command -v fail2ban-client &>/dev/null || fail "fail2ban tidak bisa diinstall"
command -v ipset          &>/dev/null || fail "ipset tidak bisa diinstall"
ok "Semua dependency tersedia"

# ── Setup ipset untuk banned IPs ───────────────────────────────
info "Setup ipset ptero-banned..."
ipset list ptero-banned &>/dev/null || ipset create ptero-banned hash:ip timeout "$BAN_DURATION" 2>/dev/null || true
# iptables rule agar ipset dipakai
iptables -C INPUT -m set --match-set ptero-banned src -j DROP 2>/dev/null || \
  iptables -I INPUT 1 -m set --match-set ptero-banned src -j DROP
ok "ipset ptero-banned siap"

# ── Setup fail2ban jail ────────────────────────────────────────
info "Setup fail2ban jail ptero-ddos..."
cat > /etc/fail2ban/jail.d/ptero-ddos.conf << 'F2BEOF'
[ptero-nginx-ddos]
enabled   = true
filter    = ptero-nginx-ddos
logpath   = /var/log/nginx/access.log
maxretry  = 5
findtime  = 10
bantime   = 3600
action    = iptables-allports[name=ptero-ddos, protocol=all]
EOF_INNER
F2BEOF

# Filter fail2ban
cat > /etc/fail2ban/filter.d/ptero-nginx-ddos.conf << 'FILTEREOF'
[Definition]
failregex = ^<HOST> .* "(GET|POST|HEAD|PUT|DELETE|PATCH|OPTIONS) .* HTTP/.*" (4\d\d|5\d\d) .*$
            ^<HOST> .* "(GET|POST|HEAD|PUT|DELETE|PATCH|OPTIONS) .* HTTP/.*" \d+ .*$
ignoreregex =
FILTEREOF

systemctl restart fail2ban 2>/dev/null || warn "fail2ban restart gagal, lanjut..."
ok "fail2ban jail ptero-nginx-ddos aktif"

# ── Setup nginx rate limiting ───────────────────────────────────
info "Setup nginx rate limit..."
NGINX_CONF_DIR="/etc/nginx/conf.d"
mkdir -p "$NGINX_CONF_DIR"

cat > "${NGINX_CONF_DIR}/ptero-ddos-ratelimit.conf" << NGINXEOF
# ptero-ddos-ratelimit — by baniwwDeveloper
limit_req_zone \$binary_remote_addr zone=ptero_ddos:16m rate=${REQ_PER_SEC}r/s;
limit_conn_zone \$binary_remote_addr zone=ptero_conn:16m;
NGINXEOF

# Inject ke nginx virtual host pterodactyl kalau belum ada
PTERO_NGINX="/etc/nginx/sites-enabled/pterodactyl.conf"
if [ -f "$PTERO_NGINX" ] && ! grep -q "ptero_ddos" "$PTERO_NGINX"; then
  # Inject di dalam server block setelah location pertama
  sed -i '/location \/ {/a\        limit_req zone=ptero_ddos burst=150 nodelay;\n        limit_conn ptero_conn 25;' "$PTERO_NGINX" 2>/dev/null || true
  ok "Nginx rate limit diinjeksi ke pterodactyl.conf"
fi

nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || warn "Nginx reload gagal — cek config manual"
ok "Nginx rate limit aktif (${REQ_PER_SEC} req/s per IP)"

# ── Tulis monitor script utama ─────────────────────────────────
info "Menulis monitor script ke $MONITOR_SCRIPT..."
mkdir -p "$STATE_DIR"

cat > "$MONITOR_SCRIPT" << 'MONEOF'
#!/bin/bash
# ptero-ddos-monitor.sh — Core Monitor
# by @baniwwwXD | baniwwDeveloper

CONF="/etc/pterodactyl-ddos-monitor.conf"
STATE_DIR="/tmp/ptero-ddos-state"
LOG_FILE="/var/log/ptero-ddos-monitor.log"

source "$CONF" 2>/dev/null || exit 1
mkdir -p "$STATE_DIR"

# ── Helper: kirim Telegram ─────────────────────────────────────
tg_send() {
  local msg="$1"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="HTML" \
    -d text="$msg" \
    --max-time 10 \
    -o /dev/null 2>/dev/null || true
}

# ── Helper: log ───────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

# ── Helper: cek whitelist ─────────────────────────────────────
is_whitelisted() {
  local ip="$1"
  if [ -n "${WHITELIST_IPS:-}" ]; then
    for w in $(echo "$WHITELIST_IPS" | tr ',' ' '); do
      [ "$ip" = "$w" ] && return 0
    done
  fi
  return 1
}

# ── Helper: blokir IP ─────────────────────────────────────────
ban_ip() {
  local ip="$1" reason="$2"
  is_whitelisted "$ip" && return 0

  # Cek sudah pernah di-ban dalam sesi ini
  local ban_file="$STATE_DIR/banned_${ip}"
  [ -f "$ban_file" ] && return 0

  # Blokir via iptables + ipset
  ipset add ptero-banned "$ip" timeout "${BAN_DURATION:-3600}" 2>/dev/null || \
    iptables -I INPUT 1 -s "$ip" -j DROP 2>/dev/null || true

  touch "$ban_file"
  log "BANNED $ip — $reason"

  local hostname
  hostname=$(host "$ip" 2>/dev/null | awk '/domain name pointer/ {print $NF}' | head -1 | sed 's/\.$//') || hostname="unknown"

  tg_send "🚨 <b>DDoS BLOCKED!</b>

🔴 <b>IP   :</b> <code>${ip}</code>
🌐 <b>Host :</b> <code>${hostname:-unknown}</code>
📌 <b>Alasan:</b> ${reason}
⏰ <b>Waktu :</b> $(date '+%Y-%m-%d %H:%M:%S WIB')
🔒 <b>Aksi  :</b> Diblokir ${BAN_DURATION:-3600}s via iptables+ipset

🛡️ <i>Pterodactyl DDoS Monitor</i>"
}

# ── Cek 1: Nginx access log — req per detik per IP ────────────
check_nginx_rps() {
  local log_file="/var/log/nginx/access.log"
  [ -f "$log_file" ] || return 0

  local last_line_file="$STATE_DIR/nginx_last_line"
  local last_line=0
  [ -f "$last_line_file" ] && last_line=$(cat "$last_line_file" 2>/dev/null || echo 0)
  local total_lines
  total_lines=$(wc -l < "$log_file" 2>/dev/null || echo 0)

  # Kalau log di-rotate
  if [ "$total_lines" -lt "$last_line" ]; then
    echo 0 > "$last_line_file"
    last_line=0
  fi

  echo "$total_lines" > "$last_line_file"
  local new_lines=$(( total_lines - last_line ))
  [ "$new_lines" -le 0 ] && return 0

  # Ambil baris baru saja, hitung req per IP
  local suspect_ips
  suspect_ips=$(tail -n "$new_lines" "$log_file" 2>/dev/null \
    | awk '{print $1}' \
    | sort | uniq -c | sort -rn \
    | awk -v thr="${REQ_PER_SEC:-75}" -v interval="${INTERVAL:-30}" \
      'BEGIN{thresh=thr*interval} $1 > thresh {print $2, $1}')

  while IFS=' ' read -r ip count; do
    [ -z "$ip" ] && continue
    ban_ip "$ip" "⚡ Nginx: ${count} req dalam ${INTERVAL}s (limit: ${REQ_PER_SEC}/s)"
  done <<< "$suspect_ips"
}

# ── Cek 2: Koneksi aktif per IP (SYN/ESTABLISHED) ────────────
check_connections() {
  local threshold="${THRESHOLD:-100}"

  # Hitung koneksi ESTABLISHED + SYN_RECV per IP
  local suspect_ips
  suspect_ips=$(ss -tn state established state syn-recv 2>/dev/null \
    | awk 'NR>1 {split($5,a,":"); if(length(a)>1) print a[1]}' \
    | sort | uniq -c | sort -rn \
    | awk -v thr="$threshold" '$1 > thr {print $2, $1}')

  while IFS=' ' read -r ip count; do
    [ -z "$ip" ] && continue
    [ "$ip" = "0.0.0.0" ] && continue
    ban_ip "$ip" "🔌 Koneksi aktif: ${count} (limit: ${threshold})"
  done <<< "$suspect_ips"
}

# ── Cek 3: fail2ban bans baru ─────────────────────────────────
check_fail2ban() {
  local f2b_log="/var/log/fail2ban.log"
  [ -f "$f2b_log" ] || return 0

  local last_file="$STATE_DIR/f2b_last_line"
  local last_line=0
  [ -f "$last_file" ] && last_line=$(cat "$last_file" 2>/dev/null || echo 0)
  local total
  total=$(wc -l < "$f2b_log" 2>/dev/null || echo 0)
  [ "$total" -lt "$last_line" ] && last_line=0
  echo "$total" > "$last_file"
  local new=$(( total - last_line ))
  [ "$new" -le 0 ] && return 0

  local banned_ips
  banned_ips=$(tail -n "$new" "$f2b_log" 2>/dev/null \
    | grep " Ban " \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
    | sort -u)

  while read -r ip; do
    [ -z "$ip" ] && continue
    ban_ip "$ip" "🚫 fail2ban: terdeteksi serangan berulang"
  done <<< "$banned_ips"
}

# ── Bersihkan state ban lama (>BAN_DURATION) ──────────────────
cleanup_ban_state() {
  local max_age="${BAN_DURATION:-3600}"
  find "$STATE_DIR" -name "banned_*" -mmin "+$(( max_age / 60 ))" -delete 2>/dev/null || true
}

# ── Main loop ─────────────────────────────────────────────────
log "=== Monitor dimulai (threshold: ${THRESHOLD} conn, ${REQ_PER_SEC} req/s, interval: ${INTERVAL}s) ==="

# Notif startup
tg_send "✅ <b>DDoS Monitor AKTIF</b>

🖥️ <b>VPS    :</b> <code>$(hostname -I | awk '{print $1}')</code>
⚡ <b>Limit  :</b> ${REQ_PER_SEC} req/s per IP
🔌 <b>Conn   :</b> ${THRESHOLD} koneksi per IP
⏱️ <b>Interval:</b> ${INTERVAL}s
🛡️ <b>Layer  :</b> nginx + iptables + fail2ban

🟢 <i>Monitor berjalan — $(date '+%Y-%m-%d %H:%M:%S')</i>"

while true; do
  check_nginx_rps
  check_connections
  check_fail2ban
  cleanup_ban_state
  sleep "${INTERVAL:-30}"
done
MONEOF

chmod +x "$MONITOR_SCRIPT"
ok "Monitor script ditulis ke $MONITOR_SCRIPT"

# ── Init state (hindari baca log lama) ─────────────────────────
info "Init state file..."
mkdir -p "$STATE_DIR"
wc -l < /var/log/nginx/access.log > "$STATE_DIR/nginx_last_line" 2>/dev/null || echo 0 > "$STATE_DIR/nginx_last_line"
wc -l < /var/log/fail2ban.log      > "$STATE_DIR/f2b_last_line"  2>/dev/null || echo 0 > "$STATE_DIR/f2b_last_line"
ok "State diinisialisasi — log lama diabaikan"

# ── Buat systemd service ────────────────────────────────────────
info "Membuat systemd service..."
cat > "$SERVICE_FILE" << SVCEOF
[Unit]
Description=Pterodactyl DDoS Monitor — by baniwwDeveloper
After=network.target fail2ban.service nginx.service
Wants=fail2ban.service

[Service]
Type=simple
ExecStart=/bin/bash $MONITOR_SCRIPT
Restart=always
RestartSec=10
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
EnvironmentFile=-$CONF

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable ptero-ddos-monitor --now

sleep 2
if systemctl is-active --quiet ptero-ddos-monitor; then
  ok "Service ptero-ddos-monitor berjalan!"
else
  warn "Service tidak aktif, coba manual: systemctl start ptero-ddos-monitor"
fi

# ── Tandai config sebagai installed ───────────────────────────
grep -q "^INSTALLED=" "$CONF" 2>/dev/null && \
  sed -i "s/^INSTALLED=.*/INSTALLED=$(date -u +\"%Y-%m-%d-%H-%M-%S\")/" "$CONF" || \
  echo "INSTALLED=$(date -u +\"%Y-%m-%d-%H-%M-%S\")" >> "$CONF"

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ DDOS MONITOR BERHASIL DIPASANG!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  📡 Layer 1 : nginx rate limit (${REQ_PER_SEC} req/s per IP)"
echo -e "  🔒 Layer 2 : iptables + ipset (auto-ban)"
echo -e "  🚫 Layer 3 : fail2ban (ptero-nginx-ddos jail)"
echo -e "  📬 Notif   : Telegram Bot"
echo -e "  ⏱️  Interval: ${INTERVAL}s"
echo ""
echo -e "  📋 Log     : tail -f $LOG_FILE"
echo -e "  🔍 Status  : systemctl status ptero-ddos-monitor"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
