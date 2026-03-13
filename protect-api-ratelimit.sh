#!/bin/bash

MARKER_FILE="/etc/nginx/pterodactyl-ratelimit.conf"
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

# Deteksi config nginx Pterodactyl
NGINX_CONF=""
for f in \
  /etc/nginx/sites-enabled/pterodactyl.conf \
  /etc/nginx/sites-enabled/default \
  /etc/nginx/conf.d/pterodactyl.conf \
  /etc/nginx/conf.d/default.conf; do
  if [ -f "$f" ]; then
    NGINX_CONF="$f"
    break
  fi
done

if [ -z "$NGINX_CONF" ]; then
  echo "❌ Config nginx Pterodactyl tidak ditemukan!"
  echo "   Cek manual: ls /etc/nginx/sites-enabled/"
  exit 1
fi

echo "✅ Config nginx: $NGINX_CONF"

NGINX_BACKUP="${NGINX_CONF}.bak_${TIMESTAMP}"
cp "$NGINX_CONF" "$NGINX_BACKUP"
echo "✅ Backup nginx → $NGINX_BACKUP"

# Buat file rate limit zones
cat > "$MARKER_FILE" << 'NGINXEOF'
# ════════════════════════════════════════════════════════
# 🛡️ PTERODACTYL API RATE LIMIT — by @baniwwwXD
# ════════════════════════════════════════════════════════

# Login endpoint — anti bruteforce (5 req/menit per IP)
limit_req_zone $binary_remote_addr zone=ptero_login:10m rate=5r/m;

# Client API — anti flood user (30 req/menit per IP)
limit_req_zone $binary_remote_addr zone=ptero_client:10m rate=30r/m;

# Application API — untuk bot/admin (60 req/menit per IP)
limit_req_zone $binary_remote_addr zone=ptero_app:10m rate=60r/m;

# Return 429 kalau kena limit
limit_req_status 429;
NGINXEOF

echo "✅ Rate limit zones dibuat → $MARKER_FILE"

# Inject include ke nginx config kalau belum ada
if grep -q "pterodactyl-ratelimit.conf" "$NGINX_CONF"; then
  echo "⚠️  Include sudah ada di nginx config, skip."
else
  sed -i "1s|^|include /etc/nginx/pterodactyl-ratelimit.conf;\n|" "$NGINX_CONF"
  echo "✅ Include ditambahkan ke $NGINX_CONF"
fi

# Inject limit_req ke location blocks via Python
python3 << PYEOF
import re

filepath = "$NGINX_CONF"

with open(filepath, 'r') as f:
    content = f.read()

changes = 0

# 1. Login
if re.search(r'location\s+[~*]*\s*/auth', content) and 'ptero_login' not in content:
    content = re.sub(
        r'(location\s+[~*]*\s*/auth[^{]*\{)',
        r'\1\n        limit_req zone=ptero_login burst=3 nodelay;',
        content, count=1
    )
    changes += 1

# 2. Client API
if re.search(r'location\s+[~*]*\s*/api/client', content) and 'ptero_client' not in content:
    content = re.sub(
        r'(location\s+[~*]*\s*/api/client[^{]*\{)',
        r'\1\n        limit_req zone=ptero_client burst=10 nodelay;',
        content, count=1
    )
    changes += 1

# 3. Application API
if re.search(r'location\s+[~*]*\s*/api/application', content) and 'ptero_app' not in content:
    content = re.sub(
        r'(location\s+[~*]*\s*/api/application[^{]*\{)',
        r'\1\n        limit_req zone=ptero_app burst=20 nodelay;',
        content, count=1
    )
    changes += 1

# Fallback: inject ke location / kalau tidak ada location spesifik
if changes == 0 and 'ptero_client' not in content:
    content = re.sub(
        r'(location\s+/\s*\{)',
        r'\1\n        limit_req zone=ptero_client burst=20 nodelay;',
        content, count=1
    )
    changes += 1

with open(filepath, 'w') as f:
    f.write(content)

print(f"✅ {changes} location block diupdate.")
PYEOF

# Test nginx
echo ""
echo "🔄 Testing konfigurasi nginx..."
nginx -t 2>&1

if [ $? -ne 0 ]; then
  echo ""
  echo "❌ Konfigurasi nginx error! Rollback..."
  cp "$NGINX_BACKUP" "$NGINX_CONF"
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
echo "📂 Config : $MARKER_FILE"
echo "📂 Nginx  : $NGINX_CONF"
echo "🗂️ Backup : $NGINX_BACKUP"
echo ""
echo "🔒 Rate Limit:"
echo "   🔑 Login      : 5 req/menit  (anti bruteforce)"
echo "   👤 Client API : 30 req/menit (anti flood)"
echo "   🔧 App API    : 60 req/menit (bot/admin)"
echo ""
echo "⚠️  Kalau bot kamu kena 429, naikkan rate di:"
echo "   $MARKER_FILE"
echo ""
echo "════════════════════════════════════════════"
