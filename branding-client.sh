#!/bin/bash

# Client Panel Branding Script
# By @baniwwwXD
# Edit: login page title, logo, copyright, dashboard name

if [ ! -t 0 ]; then AUTOCONFIRM="y"; else AUTOCONFIRM=""; fi

PANEL_NAME="${1:-Private Panel}"
LOGIN_TITLE="${2:-Login to Continue}"
TAGLINE="${3:-Game Server Panel}"

LOGIN_FORM="/var/www/pterodactyl/resources/scripts/components/auth/LoginContainer.tsx"
LOGIN_CONTAINER="/var/www/pterodactyl/resources/scripts/components/auth/LoginFormContainer.tsx"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

clear 2>/dev/null || true
echo "════════════════════════════════════════════"
echo "  🎨 CLIENT PANEL BRANDING"
echo "  By @baniwwwXD"
echo "════════════════════════════════════════════"
echo ""
echo "Panel Name  : $PANEL_NAME"
echo "Login Title : $LOGIN_TITLE"
echo "Tagline     : $TAGLINE"
echo ""

if [ "$EUID" -ne 0 ]; then echo "❌ Harus root!"; exit 1; fi
if [ ! -f "$LOGIN_FORM" ]; then echo "❌ File tidak ditemukan: $LOGIN_FORM"; exit 1; fi

if grep -q "BANIWW_BRANDING" "$LOGIN_FORM" 2>/dev/null; then
  echo "⚠️  Branding sudah terpasang!"
  echo "ALREADY_INSTALLED"
  exit 0
fi

if [ -z "$AUTOCONFIRM" ]; then read -p "Continue? (y/n): " confirm
else confirm="y"; echo "Auto-confirm: y"; fi
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { echo "❌ Cancelled."; exit 1; }

# Backup
cp "$LOGIN_FORM" "${LOGIN_FORM}.bak_${TIMESTAMP}"
cp "$LOGIN_CONTAINER" "${LOGIN_CONTAINER}.bak_${TIMESTAMP}"
echo "✅ Backup dibuat"

# ── STEP 1: Ubah title "Login to Continue" di LoginContainer.tsx ──
echo ""
echo "🔧 [1/3] Mengubah login title..."

# Cari dan ganti title yang di-pass ke LoginFormContainer
sed -i "s/title={'Login to Continue'}/title={'${LOGIN_TITLE}'}/" "$LOGIN_FORM"
sed -i 's/title={"Login to Continue"}/title={"'"${LOGIN_TITLE}"'"}/' "$LOGIN_FORM"

# Tambah marker
sed -i '1s|^|// BANIWW_BRANDING: Custom branding by @baniwwwXD\n|' "$LOGIN_FORM"

echo "✅ Login title diubah!"

# ── STEP 2: Ubah LoginFormContainer.tsx ───────────────────────
echo ""
echo "🔧 [2/3] Mengubah login form container..."

python3 << PYEOF
import re

path = "$LOGIN_CONTAINER"
with open(path, "r") as f:
    content = f.read()

# 1. Ganti logo pterodactyl SVG dengan teks nama panel
# Cari: <img src={'/assets/svgs/pterodactyl.svg'} ... />
old_logo = r"<img src=\{'/assets/svgs/pterodactyl\.svg'\}[^/]*/>"
new_logo = f"""<div style={{{{
  fontSize: '28px',
  fontWeight: '800',
  color: '#fff',
  letterSpacing: '-0.5px',
  marginBottom: '4px',
  textShadow: '0 2px 10px rgba(0,0,0,0.3)'
}}}}>
  {PANEL_NAME}
</div>
<div style={{{{
  fontSize: '12px',
  color: 'rgba(255,255,255,0.6)',
  textTransform: 'uppercase',
  letterSpacing: '2px'
}}}}>
  {TAGLINE}
</div>""".replace("{PANEL_NAME}", "$PANEL_NAME").replace("{TAGLINE}", "$TAGLINE")

content_new = re.sub(old_logo, new_logo, content, flags=re.DOTALL)

# 2. Ganti copyright "Pterodactyl Software" 
content_new = content_new.replace(
    "Pterodactyl Software",
    "Protected by @baniwwwXD"
)

# 3. Tambah marker
content_new = "// BANIWW_BRANDING_FORM: Custom by @baniwwwXD\n" + content_new

# Simpan
with open(path, "w") as f:
    f.write(content_new)

# Verifikasi
if "$PANEL_NAME" in content_new or "BANIWW_BRANDING_FORM" in content_new:
    print("VERIFY_OK")
else:
    print("VERIFY_PARTIAL - logo regex tidak match, coba fallback")
PYEOF

PYEXIT=$?

# Fallback kalau regex tidak match — langsung sed
if [ $PYEXIT -ne 0 ]; then
  echo "⚠️  Python gagal, pakai sed fallback..."
  sed -i "s|Pterodactyl Software|Protected by @baniwwwXD|g" "$LOGIN_CONTAINER"
fi

echo "✅ Login form container diubah!"

# ── STEP 3: Build production ──────────────────────────────────
echo ""
echo "🔨 [3/3] Building (3-7 menit)..."
cd /var/www/pterodactyl

if command -v yarn &>/dev/null; then
  yarn build:production 2>&1
else
  npm run build:production 2>&1
fi

BUILD_EXIT=$?
if [ $BUILD_EXIT -ne 0 ]; then
  echo "❌ Build gagal! Mengembalikan backup..."
  cp "${LOGIN_FORM}.bak_${TIMESTAMP}" "$LOGIN_FORM"
  cp "${LOGIN_CONTAINER}.bak_${TIMESTAMP}" "$LOGIN_CONTAINER"
  exit 1
fi

# Clear cache
php artisan view:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
echo "✅ Cache cleared!"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ CLIENT BRANDING TERPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "✅ Login title  : $LOGIN_TITLE"
echo "✅ Panel name   : $PANEL_NAME"
echo "✅ Tagline      : $TAGLINE"
echo "✅ Copyright    : Protected by @baniwwwXD"
echo ""
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
