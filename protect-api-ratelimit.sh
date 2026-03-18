#!/bin/bash

MARKER_FILE="/etc/nginx/pterodactyl-ratelimit.conf"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL API RATE LIMIT PROTECTION"
echo "  by @baniwwwXD | baniwwDeveloper"
echo "════════════════════════════════════════════"
echo ""

if [ "$EUID" -ne 0 ]; then
  echo "❌ Jalankan script ini sebagai root!"
  exit 1
fi

if [ -f "$MARKER_FILE" ]; then
  echo "✅ ALREADY_INSTALLED — Rate limit sudah terpasang!"
  exit 0
fi

# ─── Deteksi config Pterodactyl ───────────────────────────────
PTERO_CONF=""
for f in \
  /etc/nginx/sites-enabled/pterodactyl.conf \
  /etc/nginx/sites-available/pterodactyl.conf \
  /etc/nginx/conf.d/pterodactyl.conf \
  /etc/nginx/conf.d/default.conf \
  /etc/nginx/sites-enabled/default; do
  if [ -f "$f" ]; then
    PTERO_CONF="$f"
    break
  fi
done

if [ -z "$PTERO_CONF" ]; then
  echo "❌ Config nginx Pterodactyl tidak ditemukan!"
  exit 1
fi

echo "✅ Config ditemukan: $PTERO_CONF"

# ─── Pindahkan backup lama dari sites-enabled ke /tmp ────────
# Nginx membaca SEMUA file di sites-enabled termasuk .bak → duplicate listen
SITES_DIR=$(dirname "$PTERO_CONF")
BAK_COUNT=$(ls "${SITES_DIR}"/*.bak_* 2>/dev/null | wc -l)
if [ "$BAK_COUNT" -gt 0 ]; then
  mkdir -p /tmp/nginx-bak-old
  mv "${SITES_DIR}"/*.bak_* /tmp/nginx-bak-old/ 2>/dev/null
  echo "✅ $BAK_COUNT file backup lama dipindah ke /tmp/nginx-bak-old/"
fi

# ─── Backup config aktif ──────────────────────────────────────
# Simpan ke /tmp bukan ke sites-enabled supaya tidak terbaca nginx
BACKUP_SAFE="/tmp/pterodactyl.conf.bak_${TIMESTAMP}"
cp "$PTERO_CONF" "$BACKUP_SAFE"
echo "✅ Backup → $BACKUP_SAFE"

# ─── Buat file zone ───────────────────────────────────────────
cat > "$MARKER_FILE" << 'NGINXEOF'
# 🛡️ PTERODACTYL API RATE LIMIT — by @baniwwwXD baniwwDeveloper
# pterodactyl-ratelimit
limit_req_zone $binary_remote_addr zone=ptero_login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=ptero_client:10m rate=30r/m;
limit_req_zone $binary_remote_addr zone=ptero_app:10m rate=60r/m;
limit_req_status 429;
NGINXEOF

echo "✅ Rate limit zones dibuat → $MARKER_FILE"

# ─── Inject limit_req ke location / block di pterodactyl.conf ─
python3 << PYEOF
import re, sys

filepath = "$PTERO_CONF"

with open(filepath, 'r') as f:
    content = f.read()

if 'ptero_client' in content:
    print("⚠️ limit_req sudah ada, skip.")
    sys.exit(0)

if re.search(r'location\s+/\s*\{', content):
    content = re.sub(
        r'(location\s+/\s*\{)',
        r'\1\n        limit_req zone=ptero_client burst=20 nodelay;',
        content, count=1
    )
    print("✅ limit_req ditambahkan ke location / block")
else:
    content = re.sub(
        r'(server_name\s+[^;]+;)',
        r'\1\n    limit_req zone=ptero_client burst=20 nodelay;',
        content, count=1
    )
    print("✅ limit_req ditambahkan setelah server_name")

with open(filepath, 'w') as f:
    f.write(content)
PYEOF

# ─── Inject include ke http block nginx.conf ──────────────────
NGINX_MAIN="/etc/nginx/nginx.conf"
if ! grep -q "pterodactyl-ratelimit.conf" "$NGINX_MAIN" 2>/dev/null; then
  sed -i '/^http {/a\    include /etc/nginx/pterodactyl-ratelimit.conf;' "$NGINX_MAIN"
  echo "✅ Include ditambahkan ke $NGINX_MAIN"
else
  echo "⚠️ Include sudah ada di nginx.conf, skip."
fi

# ─── Test nginx ───────────────────────────────────────────────
echo ""
echo "🔄 Testing nginx..."
nginx -t 2>&1

if [ $? -ne 0 ]; then
  echo "❌ Nginx error! Rollback..."
  cp "$BACKUP_SAFE" "$PTERO_CONF"
  sed -i '/pterodactyl-ratelimit.conf/d' "$NGINX_MAIN" 2>/dev/null
  rm -f "$MARKER_FILE"
  # Kembalikan backup lama kalau ada
  [ -d /tmp/nginx-bak-old ] && mv /tmp/nginx-bak-old/*.bak_* "$SITES_DIR/" 2>/dev/null
  echo "✅ Rollback berhasil."
  exit 1
fi

systemctl reload nginx
echo "✅ Nginx reloaded."

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ RATE LIMIT BERHASIL DIPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "🔒 Rate Limit:"
echo "   🔑 Login      : 5 req/menit  (anti bruteforce)"
echo "   👤 Client API : 30 req/menit (anti flood)"
echo "   🔧 App API    : 60 req/menit (bot/admin)"
echo ""
echo "💡 Backup lama nginx ada di /tmp/nginx-bak-old/"
echo ""
echo "════════════════════════════════════════════"
