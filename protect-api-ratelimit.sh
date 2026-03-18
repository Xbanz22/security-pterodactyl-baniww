#!/bin/bash

MARKER_FILE="/etc/nginx/pterodactyl-ratelimit.conf"
NGINX_MAIN="/etc/nginx/nginx.conf"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL API RATE LIMIT PROTECTION"
echo "  📦 by @baniwwwXD | baniwwDeveloper"
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

# ─── Backup nginx.conf utama ──────────────────────────────────
cp "$NGINX_MAIN" "${NGINX_MAIN}.bak_${TIMESTAMP}"
echo "✅ Backup nginx.conf → ${NGINX_MAIN}.bak_${TIMESTAMP}"

# ─── Buat file zone terpisah ──────────────────────────────────
cat > "$MARKER_FILE" << 'NGINXEOF'
# 🛡️ PTERODACTYL API RATE LIMIT — by @baniwwwXD baniwwDeveloper
# pterodactyl-ratelimit

# Login — anti bruteforce (5 req/menit)
limit_req_zone $binary_remote_addr zone=ptero_login:10m rate=5r/m;

# Client API — anti flood (30 req/menit)
limit_req_zone $binary_remote_addr zone=ptero_client:10m rate=30r/m;

# Application API — bot/admin (60 req/menit)
limit_req_zone $binary_remote_addr zone=ptero_app:10m rate=60r/m;

limit_req_status 429;
NGINXEOF

echo "✅ Rate limit zones dibuat → $MARKER_FILE"

# ─── Inject include ke dalam http { } block di nginx.conf ─────
# Ini cara yang benar — inject di dalam http block, bukan di baris pertama
python3 << 'PYEOF'
import re, sys

filepath = "/etc/nginx/nginx.conf"

with open(filepath, 'r') as f:
    content = f.read()

# Cek sudah ada
if 'pterodactyl-ratelimit.conf' in content:
    print("⚠️ Include sudah ada, skip.")
    sys.exit(0)

# Inject setelah baris pembuka http {
pattern = r'(http\s*\{)'
replacement = r'\1\n    include /etc/nginx/pterodactyl-ratelimit.conf;'

new_content = re.sub(pattern, replacement, content, count=1)

if new_content == content:
    print("❌ Gagal inject ke http block.")
    sys.exit(1)

with open(filepath, 'w') as f:
    f.write(new_content)

print("✅ Include berhasil ditambahkan ke http { } block nginx.conf")
PYEOF

RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "❌ Gagal inject. Rollback..."
  cp "${NGINX_MAIN}.bak_${TIMESTAMP}" "$NGINX_MAIN"
  rm -f "$MARKER_FILE"
  exit 1
fi

# ─── Deteksi config Pterodactyl dan inject limit_req ─────────
PTERO_CONF=""
for f in \
  /etc/nginx/sites-enabled/pterodactyl.conf \
  /etc/nginx/sites-available/pterodactyl.conf \
  /etc/nginx/conf.d/pterodactyl.conf; do
  if [ -f "$f" ]; then
    PTERO_CONF="$f"
    break
  fi
done

if [ -n "$PTERO_CONF" ]; then
  echo "✅ Config Pterodactyl ditemukan: $PTERO_CONF"
  cp "$PTERO_CONF" "${PTERO_CONF}.bak_${TIMESTAMP}"

  python3 << PYEOF2
import re

filepath = "$PTERO_CONF"

with open(filepath, 'r') as f:
    content = f.read()

changes = 0

# Inject ke location / (main)
if 'ptero_client' not in content:
    content = re.sub(
        r'(location\s+/\s*\{)',
        r'\1\n        limit_req zone=ptero_client burst=20 nodelay;',
        content, count=1
    )
    changes += 1

with open(filepath, 'w') as f:
    f.write(content)

print(f"✅ {changes} location block diupdate di {filepath}")
PYEOF2

fi

# ─── Test & reload nginx ──────────────────────────────────────
echo ""
echo "🔄 Testing konfigurasi nginx..."
nginx -t 2>&1

if [ $? -ne 0 ]; then
  echo "❌ Nginx config error! Rollback..."
  cp "${NGINX_MAIN}.bak_${TIMESTAMP}" "$NGINX_MAIN"
  [ -n "$PTERO_CONF" ] && cp "${PTERO_CONF}.bak_${TIMESTAMP}" "$PTERO_CONF"
  rm -f "$MARKER_FILE"
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
echo "📂 Zone file : $MARKER_FILE"
echo "📂 nginx.conf: $NGINX_MAIN"
echo ""
echo "🔒 Rate Limit:"
echo "   🔑 Login      : 5 req/menit  (anti bruteforce)"
echo "   👤 Client API : 30 req/menit (anti flood)"
echo "   🔧 App API    : 60 req/menit (bot/admin)"
echo ""
echo "════════════════════════════════════════════"
