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
echo "Logo URL    : ${LOGO_URL:-'(tidak ada, pakai teks)'}"
echo ""

if [ "$EUID" -ne 0 ]; then echo "❌ Harus root!"; exit 1; fi
if [ ! -f "$LOGIN_FORM" ]; then echo "❌ File tidak ditemukan: $LOGIN_FORM"; exit 1; fi

if grep -q "BANIWW_BRANDING" "$LOGIN_FORM" 2>/dev/null; then
  echo "⚠️  Branding sudah terpasang, update ulang..."
  # Hapus marker dulu biar bisa diinstall ulang
  sed -i '/BANIWW_BRANDING/d' "$LOGIN_FORM"
  sed -i '/BANIWW_BRANDING_FORM/d' "$LOGIN_CONTAINER"
fi

if [ -z "$AUTOCONFIRM" ]; then read -p "Continue? (y/n): " confirm
else confirm="y"; echo "Auto-confirm: y"; fi
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { echo "❌ Cancelled."; exit 1; }

# Restore dari backup asli kalau ada (biar clean setiap update)
if [ -f "${LOGIN_FORM}.bak_baniww_orig" ]; then
  cp "${LOGIN_FORM}.bak_baniww_orig" "$LOGIN_FORM"
  cp "${LOGIN_CONTAINER}.bak_baniww_orig" "$LOGIN_CONTAINER"
  echo "✅ Restored dari backup original"
else
  # Backup pertama kali
  cp "$LOGIN_FORM" "${LOGIN_FORM}.bak_baniww_orig"
  cp "$LOGIN_CONTAINER" "${LOGIN_CONTAINER}.bak_baniww_orig"
  echo "✅ Backup original dibuat"
fi

# Backup timestamp
cp "$LOGIN_FORM" "${LOGIN_FORM}.bak_${TIMESTAMP}"
cp "$LOGIN_CONTAINER" "${LOGIN_CONTAINER}.bak_${TIMESTAMP}"

# ── STEP 1: Ubah title di LoginContainer.tsx ──────────────────
echo ""
echo "🔧 [1/3] Mengubah login title..."

sed -i "s/title={'Login to Continue'}/title={'${LOGIN_TITLE}'}/" "$LOGIN_FORM"
sed -i "s/title={\"Login to Continue\"}/title={\"${LOGIN_TITLE}\"}/" "$LOGIN_FORM"
sed -i '1s|^|// BANIWW_BRANDING: Custom branding by @baniwwwXD\n|' "$LOGIN_FORM"

echo "✅ Login title: $LOGIN_TITLE"

# ── STEP 2: Ubah LoginFormContainer.tsx ───────────────────────
echo ""
echo "🔧 [2/3] Mengubah logo dan copyright..."

python3 << PYEOF
import re, sys

path = "$LOGIN_CONTAINER"
panel_name = "$PANEL_NAME"
tagline    = "$TAGLINE"
logo_url   = "$LOGO_URL"

with open(path, "r") as f:
    content = f.read()

# ── Ganti logo/img area ──────────────────────────────────────
# Cari: <img src={'/assets/svgs/pterodactyl.svg'} ... />
logo_pattern = r"<img\s+src=\{'/assets/svgs/pterodactyl\.svg'\}[^/]*/>"

if logo_url:
    # Pakai gambar dari URL
    new_logo = f"""<img
                      src={{'{logo_url}'}}
                      css={{tw'w-48 h-20 mx-auto object-contain'}}
                      alt='{panel_name}'
                    />
                    <div css={{tw'mt-2 text-sm text-neutral-400 tracking-widest uppercase'}}>
                      {tagline}
                    </div>"""
else:
    # Pakai teks nama panel
    new_logo = f"""<div style={{{{
                      fontSize: '26px',
                      fontWeight: '800',
                      color: '#fff',
                      letterSpacing: '-0.5px',
                      textShadow: '0 2px 10px rgba(0,0,0,0.3)'
                    }}}}>
                      {panel_name}
                    </div>
                    <div css={{tw'mt-1 text-xs text-neutral-400 tracking-widest uppercase'}}>
                      {tagline}
                    </div>"""

result = re.sub(logo_pattern, new_logo, content, flags=re.DOTALL)

# ── Ganti copyright ──────────────────────────────────────────
result = result.replace("Pterodactyl Software", "Protected by @baniwwwXD")

# ── Tambah marker ────────────────────────────────────────────
result = "// BANIWW_BRANDING_FORM: Custom by @baniwwwXD\n" + result

with open(path, "w") as f:
    f.write(result)

# Verifikasi logo berhasil diganti
if "BANIWW_BRANDING_FORM" in result:
    replaced = logo_url in result if logo_url else panel_name in result
    if replaced:
        print("VERIFY_OK - Logo/nama berhasil diganti")
    else:
        print("VERIFY_PARTIAL - Logo regex tidak match, cek manual")
else:
    print("VERIFY_FAILED")
    sys.exit(1)
PYEOF

PYEXIT=$?
if [ $PYEXIT -ne 0 ]; then
  echo "❌ Python gagal! Pakai fallback..."
  # Minimal ganti copyright saja
  sed -i "s|Pterodactyl Software|Protected by @baniwwwXD|g" "$LOGIN_CONTAINER"
  sed -i '1s|^|// BANIWW_BRANDING_FORM: Custom by @baniwwwXD\n|' "$LOGIN_CONTAINER"
fi

echo "✅ Logo dan copyright diubah!"

# ── STEP 3: Build production ──────────────────────────────────
echo ""
echo "🔨 [3/3] Building production (5-10 menit)..."
cd /var/www/pterodactyl

# Load nvm/node path
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
export PATH="$PATH:/usr/local/bin:/usr/bin:/root/.nvm/versions/node/$(ls /root/.nvm/versions/node 2>/dev/null | tail -1)/bin"

# Cari yarn/npm
YARN_BIN=$(which yarn 2>/dev/null || ls /root/.nvm/versions/node/*/bin/yarn 2>/dev/null | tail -1)
NPM_BIN=$(which npm 2>/dev/null || ls /root/.nvm/versions/node/*/bin/npm 2>/dev/null | tail -1)

if [ -n "$YARN_BIN" ]; then
  echo "📦 Menggunakan yarn: $YARN_BIN"
  $YARN_BIN build:production 2>&1
elif [ -n "$NPM_BIN" ]; then
  echo "📦 Menggunakan npm: $NPM_BIN"
  $NPM_BIN run build:production 2>&1
else
  echo "❌ yarn/npm tidak ditemukan!"
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
echo "✅ Tagline     : $TAGLINE"
[ -n "$LOGO_URL" ] && echo "✅ Logo        : $LOGO_URL"
echo "✅ Copyright   : Protected by @baniwwwXD"
echo ""
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
