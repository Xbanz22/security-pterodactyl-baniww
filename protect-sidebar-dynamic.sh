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

# ── Cek apakah p12 (protect-sidebar.sh) sudah terpasang ───────
# Kalau iya, restore dulu dari backup original sebelum apply dynamic
WORKING_FILE="$REMOTE_PATH"

if grep -q "BANIWW_SIDEBAR" "$REMOTE_PATH" 2>/dev/null; then
  echo "⚠️  Terdeteksi protect-sidebar.sh (p12) sudah terpasang."
  echo "🔄 Mencari backup original untuk di-restore dulu..."

  DIR=$(dirname "$REMOTE_PATH")
  BASE=$(basename "$REMOTE_PATH")

  # Cari backup SEBELUM BANIWW_SIDEBAR — yang tidak mengandung marker apapun
  CLEAN_BACKUP=""
  for f in $(ls -t ${DIR}/${BASE}.bak_* 2>/dev/null); do
    if ! grep -q "BANIWW_SIDEBAR\|BANIWW_DYNAMIC_SIDEBAR" "$f" 2>/dev/null; then
      CLEAN_BACKUP="$f"
      break
    fi
  done

  if [ -n "$CLEAN_BACKUP" ]; then
    echo "✅ Backup bersih ditemukan: $(basename $CLEAN_BACKUP)"
    # Gunakan backup bersih sebagai working file (tidak overwrite dulu)
    WORKING_FILE="/tmp/admin_blade_work_${TIMESTAMP}.php"
    cp "$CLEAN_BACKUP" "$WORKING_FILE"
    echo "✅ Menggunakan backup bersih sebagai base..."
  else
    echo "⚠️  Backup bersih tidak ditemukan, pakai file saat ini."
    echo "   Menu yang sudah dihapus p12 tidak bisa dikembalikan di file."
    echo "   Lanjut dengan menambah @if pada sisa menu yang ada..."
  fi
fi

# Backup file saat ini sebelum modifikasi
cp "$REMOTE_PATH" "$BACKUP_PATH"
echo "✅ Backup current → $(basename $BACKUP_PATH)"

# ── Python: wrap menu dengan @if(Auth::user()->id === 1) ───────
python3 << PYEOF
import sys

working = "$WORKING_FILE"
output_path = "$REMOTE_PATH"

with open(working, "r") as f:
    content = f.read()

# Bersihkan marker lama kalau ada
content = content.replace("{{-- BANIWW_SIDEBAR: Protected by @baniwwwXD --}}\n", "")
content = content.replace("// BANIWW_HIDDEN: API Key menu hidden by @baniwwwXD\n", "")

SUPERADMIN_ROUTES = [
    "admin.settings",
    "admin.api",
    "admin.databases",
    "admin.locations",
    "admin.nodes",
    "admin.mounts",
    "admin.nests",
]

SUPERADMIN_LABELS = [
    ">MANAGEMENT<",
    ">SERVICE MANAGEMENT<",
    ">BASIC ADMINISTRATION<",
    "Application API",
]

lines  = content.split("\n")
output = []
i      = 0

while i < len(lines):
    line = lines[i]

    is_superadmin = False
    for route in SUPERADMIN_ROUTES:
        if route in line:
            is_superadmin = True
            break
    if not is_superadmin:
        for label in SUPERADMIN_LABELS:
            if label in line:
                is_superadmin = True
                break

    if is_superadmin:
        # Kumpulkan block <li>...</li>
        block = [line]
        open_li  = line.count("<li")
        close_li = line.count("</li>")
        depth    = open_li - close_li
        i += 1

        while depth > 0 and i < len(lines):
            block.append(lines[i])
            open_li  = lines[i].count("<li")
            close_li = lines[i].count("</li>")
            depth   += open_li - close_li
            i       += 1

        # Deteksi indentasi dari baris pertama block
        indent = len(block[0]) - len(block[0].lstrip())
        pad    = " " * indent

        output.append(f"{pad}@if(Auth::user()->id === 1) {{-- BANIWW_DYNAMIC_SIDEBAR --}}")
        output.extend(block)
        output.append(f"{pad}@endif")
        continue

    output.append(line)
    i += 1

result = "\n".join(output)

# Validasi
ok_servers  = "admin.servers" in result
ok_users    = "admin.users"   in result
ok_marker   = "BANIWW_DYNAMIC_SIDEBAR" in result
ok_wrapped  = "@if(Auth::user()->id === 1)" in result

print(f"Servers  : {'OK' if ok_servers else 'MISSING'}")
print(f"Users    : {'OK' if ok_users else 'MISSING'}")
print(f"Marker   : {'OK' if ok_marker else 'MISSING'}")
print(f"Wrapped  : {'OK' if ok_wrapped else 'MISSING'}")

if not (ok_servers and ok_users and ok_marker):
    print("VERIFY_FAILED")
    sys.exit(1)

with open(output_path, "w") as f:
    f.write(result)

print("VERIFY_OK")
sys.exit(0)
PYEOF

PYEXIT=$?

# Hapus working file temp kalau ada
[ -f "/tmp/admin_blade_work_${TIMESTAMP}.php" ] && rm -f "/tmp/admin_blade_work_${TIMESTAMP}.php"

if [ $PYEXIT -ne 0 ]; then
  echo "❌ Gagal! Mengembalikan backup..."
  cp "$BACKUP_PATH" "$REMOTE_PATH"
  exit 1
fi

# Clear cache
cd /var/www/pterodactyl
php artisan view:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
echo "✅ Cache cleared!"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ DYNAMIC SIDEBAR TERPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "👑 User ID 1   → Semua menu tampil"
echo "👤 User lain   → Hanya Overview, Servers, Users"
echo "🔒 Tidak bisa di-bypass (server-side Blade)"
echo ""
echo "🗂️  Backup : $(basename $BACKUP_PATH)"
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
