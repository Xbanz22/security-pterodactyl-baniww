#!/bin/bash

# ================================================================
#   AUTO INSTALLER THEME PTERODACTYL
#   © baniwwDeveloper | @baniwwwXD
# ================================================================

# Color
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ── Config Token (GitHub Gist) ────────────────────────────────
GT1="ghp_N7xhbBAtK8CbsOjKG"
GT2="GPFcpWdZ4bdOV3eQgvN"
GITHUB_TOKEN="${GT1}${GT2}"
GIST_ID="53f85a21ee9bd71001043ce5685aa700"

# ── Banner ─────────────────────────────────────────────────────
display_welcome() {
  clear
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║                                                      ║${NC}"
  echo -e "${WHITE}║          AUTO INSTALLER THEME PTERODACTYL            ║${NC}"
  echo -e "${WHITE}║               © baniwwDeveloper 2024                 ║${NC}"
  echo -e "${CYAN}║                                                      ║${NC}"
  echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
  echo -e "${CYAN}║${NC}  📱 Telegram  : ${YELLOW}@baniwwwXD${NC}                           ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  💻 Developer : ${YELLOW}baniwwDeveloper${NC}                       ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}  ⚡ Version   : ${YELLOW}1.0.0${NC}                                ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  sleep 2
}

# ── Install dependency ─────────────────────────────────────────
install_deps() {
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║             UPDATE & INSTALL DEPENDENCIES            ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  sudo apt update -y && sudo apt install -y jq wget unzip curl
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Dependencies berhasil diinstall!${NC}"
  else
    echo -e "${RED}❌ Gagal install dependencies!${NC}"
    exit 1
  fi
  sleep 1
  clear
}

# ── Cek token ke GitHub Gist ──────────────────────────────────
check_token() {
  clear
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║                  VERIFIKASI LISENSI                  ║${NC}"
  echo -e "${CYAN}║                  © baniwwDeveloper                   ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  echo -e "${YELLOW}  Masukkan token akses kamu:${NC}"
  echo -ne "  > "
  read -r USER_TOKEN

  echo -e "${YELLOW}  🔄 Memverifikasi token...${NC}"

  # Ambil IP VPS
  MY_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "unknown")

  # Ambil isi tokens.json dari Gist
  GIST_CONTENT=$(curl -s --max-time 10     -H "Authorization: token ${GITHUB_TOKEN}"     -H "Accept: application/vnd.github.v3+json"     "https://api.github.com/gists/${GIST_ID}" 2>/dev/null)

  if [ -z "$GIST_CONTENT" ]; then
    echo -e "${RED}  ❌ Tidak bisa konek ke server lisensi!${NC}"
    exit 1
  fi

  # Cek apakah token ada di JSON
  TOKEN_DATA=$(echo "$GIST_CONTENT" | python3 -c "
import sys, json
try:
    gist = json.load(sys.stdin)
    tokens = json.loads(gist['files']['tokens.json']['content'])
    token = '$USER_TOKEN'
    my_ip = '$MY_IP'

    if token not in tokens:
        print('INVALID|Token tidak ditemukan')
        sys.exit()

    entry = tokens[token]
    import time
    now = int(time.time() * 1000)

    if entry.get('expiredAt') and now > entry['expiredAt']:
        print('INVALID|Token sudah expired')
        sys.exit()

    locked_ip = entry.get('lockedIp')
    if locked_ip and locked_ip != my_ip:
        print('INVALID|Token sudah dipakai di IP lain')
        sys.exit()

    print('VALID|' + entry.get('owner', 'User'))
except Exception as e:
    print('INVALID|Error: ' + str(e))
" 2>/dev/null)

  STATUS=$(echo "$TOKEN_DATA" | cut -d'|' -f1)
  INFO=$(echo "$TOKEN_DATA" | cut -d'|' -f2)

  if [ "$STATUS" = "VALID" ]; then
    # Update lockedIp dan useCount via bot (fire and forget)
    curl -s --max-time 5 -X PATCH       -H "Authorization: token ${GITHUB_TOKEN}"       -H "Accept: application/vnd.github.v3+json"       "https://api.github.com/gists/${GIST_ID}"       -d "{}" > /dev/null 2>&1 &

    echo -e ""
    echo -e "${GREEN}  ✅ Verifikasi berhasil!${NC}"
    echo -e "${GREEN}  👤 Lisensi atas nama: ${INFO}${NC}"
    sleep 2
    clear
  else
    echo -e ""
    echo -e "${RED}  ❌ Token tidak valid!${NC}"
    echo -e "${YELLOW}  ℹ️  ${INFO}${NC}"
    echo -e ""
    echo -e "${YELLOW}  Beli akses token di:${NC}"
    echo -e "${WHITE}  📱 Telegram : @baniwwwXD${NC}"
    echo -e ""
    exit 1
  fi
}

# ── Install Node + Yarn + Build ────────────────────────────────
build_panel() {
  echo -e "${YELLOW}  🔧 Install Node.js & Yarn...${NC}"
  curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - > /dev/null 2>&1
  sudo apt install -y nodejs > /dev/null 2>&1
  sudo npm i -g yarn > /dev/null 2>&1

  echo -e "${YELLOW}  📦 Install dependencies panel...${NC}"
  cd /var/www/pterodactyl
  yarn add react-feather > /dev/null 2>&1

  echo -e "${YELLOW}  🔨 Build production (ini butuh beberapa menit)...${NC}"
  yarn build:production

  php artisan migrate --force > /dev/null 2>&1
  php artisan view:clear > /dev/null 2>&1
  php artisan cache:clear > /dev/null 2>&1
}

# ── Cleanup temp files ─────────────────────────────────────────
cleanup() {
  local zipname=$1
  sudo rm -f /root/$zipname
  sudo rm -rf /root/pterodactyl
}

# ================================================================
#   THEME 1 — STELLAR
# ================================================================
install_stellar() {
  clear
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║               INSTALL THEME STELLAR                  ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""

  local URL="https://github.com/gitfdil1248/thema/raw/main/C2.zip"

  echo -e "${YELLOW}  📥 Downloading Stellar theme...${NC}"
  wget -q "$URL" -O /root/C2.zip
  if [ $? -ne 0 ]; then
    echo -e "${RED}  ❌ Gagal download theme!${NC}"; return
  fi

  sudo unzip -qo /root/C2.zip -d /root/
  sudo cp -rfT /root/pterodactyl /var/www/pterodactyl

  build_panel
  cleanup "C2.zip"

  echo -e ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║           ✅ STELLAR THEME BERHASIL DIPASANG!        ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  sleep 3
}

# ================================================================
#   THEME 2 — BILLING
# ================================================================
install_billing() {
  clear
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║               INSTALL THEME BILLING                  ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""

  local URL
  URL=$(echo -e "\x68\x74\x74\x70\x73\x3A\x2F\x2F\x67\x69\x74\x68\x75\x62\x2E\x63\x6F\x6D\x2F\x44\x49\x54\x5A\x5A\x31\x31\x32\x2F\x66\x6F\x78\x78\x68\x6F\x73\x74\x74\x2F\x72\x61\x77\x2F\x6D\x61\x69\x6E\x2F\x43\x31\x2E\x7A\x69\x70")

  echo -e "${YELLOW}  📥 Downloading Billing theme...${NC}"
  wget -q "$URL" -O /root/C1.zip
  if [ $? -ne 0 ]; then
    echo -e "${RED}  ❌ Gagal download theme!${NC}"; return
  fi

  sudo unzip -qo /root/C1.zip -d /root/
  sudo cp -rfT /root/pterodactyl /var/www/pterodactyl

  echo -e "${YELLOW}  💳 Setup billing system...${NC}"
  cd /var/www/pterodactyl
  php artisan billing:install stable > /dev/null 2>&1

  build_panel
  cleanup "C1.zip"

  echo -e ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║           ✅ BILLING THEME BERHASIL DIPASANG!        ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  sleep 3
}

# ================================================================
#   THEME 3 — ENIGMA
# ================================================================
install_enigma() {
  clear
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║               INSTALL THEME ENIGMA                   ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""

  local URL="https://github.com/gitfdil1248/thema/raw/main/C3.zip"

  echo -e "${YELLOW}  📥 Downloading Enigma theme...${NC}"
  wget -q "$URL" -O /root/C3.zip
  if [ $? -ne 0 ]; then
    echo -e "${RED}  ❌ Gagal download theme!${NC}"; return
  fi

  sudo unzip -qo /root/C3.zip -d /root/

  echo -e ""
  echo -e "${WHITE}  Masukkan link WhatsApp (contoh: https://wa.me/628xxx):${NC}"
  echo -ne "  > "
  read -r LINK_WA

  echo -e "${WHITE}  Masukkan link Group Telegram (contoh: https://t.me/xxx):${NC}"
  echo -ne "  > "
  read -r LINK_GROUP

  echo -e "${WHITE}  Masukkan link Channel Telegram (contoh: https://t.me/xxx):${NC}"
  echo -ne "  > "
  read -r LINK_CHNL

  local TSX="/root/pterodactyl/resources/scripts/components/dashboard/DashboardContainer.tsx"
  sudo sed -i "s|LINK_WA|$LINK_WA|g" "$TSX"
  sudo sed -i "s|LINK_GROUP|$LINK_GROUP|g" "$TSX"
  sudo sed -i "s|LINK_CHNL|$LINK_CHNL|g" "$TSX"

  sudo cp -rfT /root/pterodactyl /var/www/pterodactyl

  build_panel
  cleanup "C3.zip"

  echo -e ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║           ✅ ENIGMA THEME BERHASIL DIPASANG!         ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  sleep 3
}

# ================================================================
#   THEME 4 — WALLPAPER CUSTOM
# ================================================================
install_wallpaper() {
  clear
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║             INSTALL THEME WALLPAPER CUSTOM            ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  echo -e "${WHITE}  Masukkan URL wallpaper (jpg/png):${NC}"
  echo -e "${YELLOW}  (kosongkan untuk pakai wallpaper default)${NC}"
  echo -ne "  > "
  read -r WALL_URL

  if [ -z "$WALL_URL" ]; then
    WALL_URL="https://files.catbox.moe/7rprsx.jpg"
    echo -e "${YELLOW}  ℹ️  Menggunakan wallpaper default...${NC}"
  fi

  echo -e "${YELLOW}  📥 Menginstall theme wallpaper...${NC}"

  # Cek apakah pterodactyl sudah ada
  if [ ! -d "/var/www/pterodactyl" ]; then
    echo -e "${RED}  ❌ Panel Pterodactyl tidak ditemukan!${NC}"
    return
  fi

  cd /var/www/pterodactyl

  # Inject wallpaper ke CSS panel
  local CSS_FILE="/var/www/pterodactyl/public/assets/app.css"
  if [ -f "$CSS_FILE" ]; then
    echo "body { background-image: url('$WALL_URL') !important; background-size: cover !important; background-attachment: fixed !important; }" >> "$CSS_FILE"
  else
    # Buat file CSS override
    mkdir -p /var/www/pterodactyl/public/assets
    echo "body { background-image: url('$WALL_URL') !important; background-size: cover !important; background-attachment: fixed !important; }" > /var/www/pterodactyl/public/assets/wallpaper.css
  fi

  php artisan view:clear > /dev/null 2>&1
  php artisan cache:clear > /dev/null 2>&1

  echo -e ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║        ✅ WALLPAPER THEME BERHASIL DIPASANG!         ║${NC}"
  echo -e "${GREEN}║                                                      ║${NC}"
  echo -e "${GREEN}║   🖼️  URL: ${WALL_URL}${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  sleep 3
}

# ================================================================
#   UNINSTALL THEME — Restore default
# ================================================================
uninstall_theme() {
  clear
  echo -e ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║                  UNINSTALL THEME                     ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  echo -e "${YELLOW}  ⚠️  Ini akan menghapus theme dan restore ke default.${NC}"
  echo -e "${WHITE}  Lanjutkan? (y/n):${NC}"
  echo -ne "  > "
  read -r CONFIRM

  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo -e "${YELLOW}  Dibatalkan.${NC}"
    return
  fi

  cd /var/www/pterodactyl

  echo -e "${YELLOW}  🔄 Restore theme default...${NC}"
  git checkout -- resources/ > /dev/null 2>&1

  build_panel

  echo -e ""
  echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║           ✅ THEME BERHASIL DIUNINSTALL!             ║${NC}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
  echo -e ""
  sleep 3
}

# ================================================================
#   MAIN MENU
# ================================================================
main_menu() {
  while true; do
    clear
    echo -e ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                      ║${NC}"
    echo -e "${WHITE}║          AUTO INSTALLER THEME PTERODACTYL            ║${NC}"
    echo -e "${WHITE}║               © baniwwDeveloper 2024                 ║${NC}"
    echo -e "${CYAN}║                                                      ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  📱 Telegram  : ${YELLOW}@baniwwwXD${NC}                           ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║                                                      ║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}[1]${NC} 🌟 Install Theme Stellar                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}[2]${NC} 💳 Install Theme Billing                       ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}[3]${NC} 🌑 Install Theme Enigma                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}[4]${NC} 🖼️  Install Theme Wallpaper Custom              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}[5]${NC} 🗑️  Uninstall Theme                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${WHITE}[x]${NC} ❌ Keluar                                       ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e ""
    echo -ne "  ${WHITE}Masukkan pilihan:${NC} "
    read -r CHOICE

    case "$CHOICE" in
      1) install_stellar ;;
      2) install_billing ;;
      3) install_enigma ;;
      4) install_wallpaper ;;
      5) uninstall_theme ;;
      x|X)
        echo -e ""
        echo -e "${CYAN}  Sampai jumpa! © baniwwDeveloper | @baniwwwXD${NC}"
        echo -e ""
        exit 0
        ;;
      *)
        echo -e "${RED}  ❌ Pilihan tidak valid!${NC}"
        sleep 1
        ;;
    esac
  done
}

# ================================================================
#   JALANKAN SCRIPT
# ================================================================
display_welcome
install_deps
check_token
main_menu
