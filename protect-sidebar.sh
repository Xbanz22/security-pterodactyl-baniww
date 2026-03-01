#!/bin/bash

# Protect Sidebar - Hide Admin Menu Items
# By @baniwwwXD
# Sisakan: Overview, Servers, Users

if [ ! -t 0 ]; then AUTOCONFIRM="y"; else AUTOCONFIRM=""; fi

REMOTE_PATH="/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

clear 2>/dev/null || true
echo "════════════════════════════════════════════"
echo "  🎨 PROTECT SIDEBAR - HIDE ADMIN MENU"
echo "  👑 By @baniwwwXD"
echo "════════════════════════════════════════════"
echo ""

if [ "$EUID" -ne 0 ]; then echo "❌ Harus root!"; exit 1; fi
if [ ! -f "$REMOTE_PATH" ]; then echo "❌ File tidak ditemukan!"; exit 1; fi

if grep -q "BANIWW_SIDEBAR" "$REMOTE_PATH" 2>/dev/null; then
  echo "⚠️  Sudah terpasang!"
  echo "ALREADY_INSTALLED"
  exit 0
fi

if [ -z "$AUTOCONFIRM" ]; then
  read -p "Continue? (y/n): " confirm
else
  confirm="y"
  echo "Auto-confirm: y"
fi
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { echo "❌ Cancelled."; exit 1; }

cp "$REMOTE_PATH" "$BACKUP_PATH"
echo "✅ Backup → $(basename $BACKUP_PATH)"

echo "🔧 Modifying sidebar..."

# Pakai python3 - baca file, hapus bagian yang tidak diinginkan, tulis ulang
python3 << 'PYEOF'
import re, sys

path = "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"

with open(path, "r") as f:
    lines = f.readlines()

output = []
skip = False
skip_count = 0

# Keyword route yang mau DIHAPUS
remove_routes = [
    "admin.settings",
    "admin.api",
    "admin.databases",
    "admin.locations",
    "admin.nodes'",   # pakai quote biar tidak match admin.nodes.* yang lain
    "admin.mounts",
    "admin.nests",
]

# Label teks yang mau dihapus
remove_labels = [
    ">MANAGEMENT<",
    ">SERVICE MANAGEMENT<",
    ">BASIC ADMINISTRATION<",
    "Application API",
]

i = 0
while i < len(lines):
    line = lines[i]
    
    # Cek apakah baris ini mengandung route yang mau dihapus
    should_remove = False
    
    for route in remove_routes:
        if route in line:
            should_remove = True
            break
    
    for label in remove_labels:
        if label in line:
            should_remove = True
            break

    if should_remove:
        # Kalau ini adalah <li> yang membuka, skip sampai </li> penutup
        # Hitung kedalaman tag
        open_li = line.count('<li')
        close_li = line.count('</li>')
        depth = open_li - close_li
        
        # Skip baris ini
        i += 1
        
        # Kalau masih ada tag yang belum ditutup, skip terus
        while depth > 0 and i < len(lines):
            open_li = lines[i].count('<li')
            close_li = lines[i].count('</li>')
            depth += open_li - close_li
            i += 1
        
        continue
    
    output.append(line)
    i += 1

# Tambah marker di baris pertama
output.insert(0, "{{-- BANIWW_SIDEBAR: Protected by @baniwwwXD --}}\n")

with open(path, "w") as f:
    f.writelines(output)

# Verifikasi
result = "".join(output)
servers_ok = "admin.servers" in result
users_ok = "admin.users" in result
settings_gone = "admin.settings" not in result
api_gone = "admin.api'" not in result

print(f"✅ Servers: {'ada' if servers_ok else '❌ HILANG'}")
print(f"✅ Users: {'ada' if users_ok else '❌ HILANG'}")
print(f"✅ Settings dihapus: {settings_gone}")
print(f"✅ API dihapus: {api_gone}")

if not servers_ok or not users_ok:
    print("VERIFY_FAILED")
    sys.exit(1)
else:
    print("VERIFY_OK")
    sys.exit(0)
PYEOF

PYEXIT=$?

if [ $PYEXIT -ne 0 ]; then
  echo "❌ Verifikasi gagal! Mengembalikan backup..."
  cp "$BACKUP_PATH" "$REMOTE_PATH"
  exit 1
fi

# Clear cache
cd /var/www/pterodactyl
php artisan config:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
php artisan view:clear > /dev/null 2>&1
echo "✅ Cache cleared!"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ SIDEBAR BERHASIL DIMODIFIKASI!"
echo "════════════════════════════════════════════"
echo ""
echo "✅ Tersisa       : Overview, Servers, Users"
echo "❌ Disembunyikan : Settings, Application API"
echo "                   Databases, Locations, Nodes"
echo "                   Mounts, Nests"
echo ""
echo "🗂️  Backup : $(basename $BACKUP_PATH)"
echo "🔓 Restore :"
echo "   cp $BACKUP_PATH $REMOTE_PATH"
echo "   cd /var/www/pterodactyl && php artisan view:clear"
echo ""
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
