#!/bin/bash

# Dynamic Sidebar Protection - Per User ID
# By @baniwwwXD
# ID 1 = Full menu | Selain ID 1 = Overview, Servers, Users only

if [ ! -t 0 ]; then AUTOCONFIRM="y"; else AUTOCONFIRM=""; fi

REMOTE_PATH="/var/www/pterodactyl/resources/views/layouts/admin.blade.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

clear 2>/dev/null || true
echo "════════════════════════════════════════════"
echo "  👑 DYNAMIC SIDEBAR PROTECTION"
echo "  By @baniwwwXD"
echo "════════════════════════════════════════════"

if [ "$EUID" -ne 0 ]; then echo "❌ Harus root!"; exit 1; fi
if [ ! -f "$REMOTE_PATH" ]; then echo "❌ File tidak ditemukan!"; exit 1; fi
if grep -q "BANIWW_DYNAMIC_SIDEBAR" "$REMOTE_PATH" 2>/dev/null; then
  echo "⚠️  Sudah terpasang!"; echo "ALREADY_INSTALLED"; exit 0
fi

if [ -z "$AUTOCONFIRM" ]; then read -p "Continue? (y/n): " confirm
else confirm="y"; echo "Auto-confirm: y"; fi
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { echo "❌ Cancelled."; exit 1; }

cp "$REMOTE_PATH" "$BACKUP_PATH"
echo "✅ Backup → $(basename $BACKUP_PATH)"

python3 << 'PYEOF'
path = "/var/www/pterodactyl/resources/views/layouts/admin.blade.php"

with open(path, "r") as f:
    content = f.read()

# Menu yang HANYA untuk super admin (ID 1)
SUPERADMIN_ONLY_ROUTES = [
    "admin.settings",
    "admin.api",
    "admin.databases",
    "admin.locations",
    "admin.nodes",
    "admin.mounts",
    "admin.nests",
]

SUPERADMIN_ONLY_LABELS = [
    "Application API",
    "MANAGEMENT",
    "SERVICE MANAGEMENT",
    "BASIC ADMINISTRATION",
]

# Parse baris per baris, wrap menu tertentu dengan kondisi Blade
lines = content.split("\n")
output = []
i = 0

while i < len(lines):
    line = lines[i]
    
    # Cek apakah baris ini route super admin only
    is_superadmin = False
    for route in SUPERADMIN_ONLY_ROUTES:
        if route in line:
            is_superadmin = True
            break
    for label in SUPERADMIN_ONLY_LABELS:
        if f">{label}<" in line:
            is_superadmin = True
            break

    if is_superadmin:
        # Kumpulkan semua baris dari <li> ini sampai </li> penutup
        block_lines = [line]
        open_li  = line.count("<li")
        close_li = line.count("</li>")
        depth    = open_li - close_li
        i += 1

        while depth > 0 and i < len(lines):
            block_lines.append(lines[i])
            open_li  = lines[i].count("<li")
            close_li = lines[i].count("</li>")
            depth   += open_li - close_li
            i       += 1

        # Wrap dengan kondisi Blade — hanya tampil kalau Auth user ID = 1
        indent = "                "
        output.append(f"{indent}@if(Auth::user()->id === 1) {{-- BANIWW_DYNAMIC_SIDEBAR --}}")
        output.extend(block_lines)
        output.append(f"{indent}@endif")
        continue

    output.append(line)
    i += 1

result = "\n".join(output)

# Verifikasi
assert "admin.servers" in result, "Servers hilang!"
assert "admin.users"   in result, "Users hilang!"
assert "BANIWW_DYNAMIC_SIDEBAR" in result, "Marker tidak ada!"

with open(path, "w") as f:
    f.write(result)

print("VERIFY_OK")
PYEOF

PYEXIT=$?
if [ $PYEXIT -ne 0 ]; then
  echo "❌ Gagal! Mengembalikan backup..."
  cp "$BACKUP_PATH" "$REMOTE_PATH"
  exit 1
fi

echo "✅ Sidebar berhasil dimodifikasi!"

# Clear Laravel view cache
cd /var/www/pterodactyl
php artisan view:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
echo "✅ Cache cleared!"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ DYNAMIC SIDEBAR TERPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "👑 User ID 1 → Full menu (semua tampil)"
echo "👤 User lain → Hanya Overview, Servers, Users"
echo ""
echo "🗂️  Backup : $(basename $BACKUP_PATH)"
echo "🔓 Restore : cp $BACKUP_PATH $REMOTE_PATH"
echo "             cd /var/www/pterodactyl && php artisan view:clear"
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
