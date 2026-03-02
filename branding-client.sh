#!/bin/bash

# Client Panel Branding Script
# By @baniwwwXD
# Args: $1=panel_name, $2=login_title, $3=tagline, $4=logo_url

if [ ! -t 0 ]; then AUTOCONFIRM="y"; else AUTOCONFIRM=""; fi

PANEL_NAME="${1:-Private Panel}"
LOGIN_TITLE="${2:-Login to Continue}"
TAGLINE="${3:-Game Server Panel}"
LOGO_URL="${4:-}"

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
echo "Logo URL    : ${LOGO_URL:-(tidak ada, pakai teks)}"
echo ""

if [ "$EUID" -ne 0 ]; then echo "❌ Harus root!"; exit 1; fi
if [ ! -f "$LOGIN_FORM" ]; then echo "❌ File tidak ditemukan: $LOGIN_FORM"; exit 1; fi

# Hapus marker lama biar bisa diupdate ulang
sed -i '/BANIWW_BRANDING/d' "$LOGIN_FORM" 2>/dev/null
sed -i '/BANIWW_BRANDING_FORM/d' "$LOGIN_CONTAINER" 2>/dev/null

if [ -z "$AUTOCONFIRM" ]; then read -p "Continue? (y/n): " confirm
else confirm="y"; echo "Auto-confirm: y"; fi
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { echo "❌ Cancelled."; exit 1; }

# Backup original pertama kali
if [ ! -f "${LOGIN_FORM}.bak_baniww_orig" ]; then
  cp "$LOGIN_FORM" "${LOGIN_FORM}.bak_baniww_orig"
  cp "$LOGIN_CONTAINER" "${LOGIN_CONTAINER}.bak_baniww_orig"
  echo "✅ Backup original dibuat"
else
  cp "${LOGIN_FORM}.bak_baniww_orig" "$LOGIN_FORM"
  cp "${LOGIN_CONTAINER}.bak_baniww_orig" "$LOGIN_CONTAINER"
  echo "✅ Restored dari backup original"
fi

cp "$LOGIN_FORM" "${LOGIN_FORM}.bak_${TIMESTAMP}"
cp "$LOGIN_CONTAINER" "${LOGIN_CONTAINER}.bak_${TIMESTAMP}"

# ── STEP 1: Ubah title di LoginContainer.tsx ──────────────────
echo ""
echo "🔧 [1/3] Mengubah login title..."
sed -i "s/title={'Login to Continue'}/title={'${LOGIN_TITLE}'}/" "$LOGIN_FORM"
sed -i "s/title={\"Login to Continue\"}/title={\"${LOGIN_TITLE}\"}/" "$LOGIN_FORM"
sed -i '1s|^|// BANIWW_BRANDING: Custom branding by @baniwwwXD\n|' "$LOGIN_FORM"
echo "✅ Login title: $LOGIN_TITLE"

# ── STEP 2: Ubah logo + copyright ─────────────────────────────
echo ""
echo "🔧 [2/3] Mengubah logo dan copyright..."

LOGO_LINE=$(grep -n "pterodactyl.svg" "$LOGIN_CONTAINER" | head -1 | cut -d: -f1)

if [ -n "$LOGO_LINE" ]; then
  if [ -n "$LOGO_URL" ]; then
    sed -i "${LOGO_LINE}s|.*|                    <img src={'${LOGO_URL}'} css={tw\`block w-48 md:w-32 mx-auto\`} />|" "$LOGIN_CONTAINER"
    echo "✅ Logo diganti URL: $LOGO_URL"
  else
    sed -i "${LOGO_LINE}s|.*|                    <span style={{fontSize:'26px',fontWeight:'800',color:'#fff'}}>${PANEL_NAME}</span>|" "$LOGIN_CONTAINER"
    echo "✅ Logo diganti teks: $PANEL_NAME"
  fi
else
  echo "⚠️  Baris logo tidak ditemukan, skip"
fi

sed -i 's/Pterodactyl Software/Protected by @baniwwwXD/g' "$LOGIN_CONTAINER"
sed -i '1s|^|// BANIWW_BRANDING_FORM: Custom by @baniwwwXD\n|' "$LOGIN_CONTAINER"
echo "✅ Copyright diubah!"

# ── STEP 3: Build production ──────────────────────────────────
echo ""
echo "🔨 [3/3] Building production (5-10 menit)..."
cd /var/www/pterodactyl

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
export PATH="$PATH:/usr/local/bin:/usr/bin"

YARN_BIN=$(which yarn 2>/dev/null)
NPM_BIN=$(which npm 2>/dev/null)

if [ -n "$YARN_BIN" ]; then
  echo "📦 Menggunakan yarn: $YARN_BIN"
  $YARN_BIN build:production 2>&1
elif [ -n "$NPM_BIN" ]; then
  echo "📦 Menggunakan npm: $NPM_BIN"
  $NPM_BIN run build:production 2>&1
else
  echo "❌ yarn/npm tidak ditemukan! Jalankan: npm install -g yarn"
  exit 1
fi

BUILD_EXIT=$?
if [ $BUILD_EXIT -ne 0 ]; then
  echo "❌ Build gagal! Mengembalikan backup..."
  cp "${LOGIN_FORM}.bak_baniww_orig" "$LOGIN_FORM"
  cp "${LOGIN_CONTAINER}.bak_baniww_orig" "$LOGIN_CONTAINER"
  exit 1
fi

php artisan view:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
echo "✅ Cache cleared!"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ CLIENT BRANDING TERPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "✅ Login title : $LOGIN_TITLE"
echo "✅ Panel name  : $PANEL_NAME"
[ -n "$LOGO_URL" ] && echo "✅ Logo URL    : $LOGO_URL"
echo "✅ Copyright   : Protected by @baniwwwXD"
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
