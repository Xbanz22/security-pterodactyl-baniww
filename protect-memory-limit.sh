#!/bin/bash

# Target: inject ke updateBuild() di ServersController.php
# Marker unik supaya tidak clash dengan protect-server-controller.sh (p8)

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/ServersController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_memlimit_${TIMESTAMP}"
MARKER="BANIWW_MEMLIMIT"

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL MEMORY LIMIT PROTECTION"
echo "  by @baniwwwXD | baniwwDeveloper"
echo "════════════════════════════════════════════"
echo ""

if grep -q "$MARKER" "$REMOTE_PATH" 2>/dev/null; then
  echo "✅ ALREADY_INSTALLED — Proteksi sudah terpasang!"
  exit 0
fi

if [ ! -f "$REMOTE_PATH" ]; then
  echo "❌ ERROR: File tidak ditemukan."
  exit 1
fi

cp "$REMOTE_PATH" "$BACKUP_PATH"
echo "✅ Backup → $BACKUP_PATH"

python3 << PYEOF
import re, sys

filepath = "$REMOTE_PATH"

with open(filepath, 'r') as f:
    content = f.read()

funcs = re.findall(r'public function (\w+)\(', content)
print("📋 Fungsi: " + ", ".join(funcs))

if 'updateBuild' not in funcs:
    print("❌ Fungsi updateBuild() tidak ditemukan!")
    sys.exit(1)

print("✅ Target: updateBuild()")

guard = r"""
        // 🔒 BANIWW_MEMLIMIT: Blokir unlimited (0) dan nilai lebay saat update build
        \$_bm = (int) \$request->input('memory', 1);
        \$_bd = (int) \$request->input('disk', 1);
        \$_bc = (int) \$request->input('cpu', 1);
        \$_bb = (int) \$request->input('backup_limit', 0);
        \$_bdb= (int) \$request->input('database_limit', 0);

        if (\$_bm <= 0)    throw new \Pterodactyl\Exceptions\DisplayException('🔒 Memory tidak boleh unlimited (0). Wajib 128-16384 MB.');
        if (\$_bd <= 0)    throw new \Pterodactyl\Exceptions\DisplayException('🔒 Disk tidak boleh unlimited (0). Wajib 512-102400 MB.');
        if (\$_bc <= 0)    throw new \Pterodactyl\Exceptions\DisplayException('🔒 CPU tidak boleh unlimited (0). Wajib 10-400%.');
        if (\$_bm > 16384) throw new \Pterodactyl\Exceptions\DisplayException('🔒 Memory terlalu besar. Maksimal 16384 MB (16 GB).');
        if (\$_bd > 102400)throw new \Pterodactyl\Exceptions\DisplayException('🔒 Disk terlalu besar. Maksimal 102400 MB (100 GB).');
        if (\$_bc > 400)   throw new \Pterodactyl\Exceptions\DisplayException('🔒 CPU terlalu besar. Maksimal 400%.');
        if (\$_bb > 10)    throw new \Pterodactyl\Exceptions\DisplayException('🔒 Backup slot maks 10.');
        if (\$_bdb > 10)   throw new \Pterodactyl\Exceptions\DisplayException('🔒 Database slot maks 10.');
"""

pattern = r'(public function updateBuild\([^)]*\)[^{]*\{)'
new_content = re.sub(pattern, r'\1' + guard, content, count=1, flags=re.DOTALL)

if new_content == content:
    print("❌ Gagal inject ke updateBuild()")
    sys.exit(1)

with open(filepath, 'w') as f:
    f.write(new_content)

print("✅ Inject berhasil!")
PYEOF

RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "❌ Gagal. Restore backup..."
  cp "$BACKUP_PATH" "$REMOTE_PATH"
  exit 1
fi

echo ""
echo "🔄 Clear cache Laravel..."
cd /var/www/pterodactyl && php artisan optimize:clear > /dev/null 2>&1
echo "✅ Cache cleared."
chmod 644 "$REMOTE_PATH"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ PROTEKSI BERHASIL DIPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "🔒 Aturan Update Build:"
echo "   ❌ Memory/Disk/CPU = 0 → DIBLOKIR"
echo "   🧠 Memory  : 128 - 16.384 MB"
echo "   💾 Disk    : 512 - 102.400 MB"
echo "   ⚙️ CPU     : 10 - 400%"
echo "   📦 Backup  : Maks 10 slot"
echo "   🗄️ Database: Maks 10 slot"
echo ""
echo "════════════════════════════════════════════"
