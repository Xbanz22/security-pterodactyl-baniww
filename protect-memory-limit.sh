#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/ServersController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"
MARKER="BANIWW_MEMLIMIT"

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL MEMORY LIMIT PROTECTION"
echo "  📦 by @baniwwwXD | baniwwDeveloper"
echo "════════════════════════════════════════════"
echo ""

if grep -q "$MARKER" "$REMOTE_PATH" 2>/dev/null; then
  echo "✅ ALREADY_INSTALLED — Proteksi sudah terpasang!"
  exit 0
fi

if [ ! -f "$REMOTE_PATH" ]; then
  echo "❌ ERROR: File tidak ditemukan di $REMOTE_PATH"
  exit 1
fi

cp "$REMOTE_PATH" "$BACKUP_PATH"
echo "✅ Backup → $BACKUP_PATH"

python3 << PYEOF
import re

filepath = "$REMOTE_PATH"

with open(filepath, 'r') as f:
    content = f.read()

if 'updateBuild' not in content:
    print("❌ Fungsi updateBuild tidak ditemukan.")
    exit(1)

guard = '''
        // 🔒 BANIWW_MEMLIMIT: Blokir unlimited (0) dan nilai terlalu besar
        \$reqMemory = (int) \$request->input('memory', 1);
        \$reqDisk   = (int) \$request->input('disk', 1);
        \$reqCpu    = (int) \$request->input('cpu', 1);
        \$reqBackup = (int) \$request->input('backup_limit', 0);
        \$reqDb     = (int) \$request->input('database_limit', 0);

        if (\$reqMemory <= 0) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory tidak boleh unlimited (0). Wajib antara 128 - 16384 MB.');
        }
        if (\$reqDisk <= 0) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk tidak boleh unlimited (0). Wajib antara 512 - 102400 MB.');
        }
        if (\$reqCpu <= 0) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU tidak boleh unlimited (0). Wajib antara 10 - 400%.');
        }
        if (\$reqMemory > 16384) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory terlalu besar. Maksimal 16384 MB (16 GB).');
        }
        if (\$reqDisk > 102400) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk terlalu besar. Maksimal 102400 MB (100 GB).');
        }
        if (\$reqCpu > 400) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU terlalu besar. Maksimal 400%.');
        }
        if (\$reqBackup > 10) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Backup slot maks 10.');
        }
        if (\$reqDb > 10) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Database slot maks 10.');
        }
'''

pattern = r'(public function updateBuild\([^)]*\)[^{]*\{)'
new_content = re.sub(pattern, r'\1' + guard, content, count=1, flags=re.DOTALL)

if new_content == content:
    print("❌ Gagal inject — pattern tidak cocok.")
    exit(1)

with open(filepath, 'w') as f:
    f.write(new_content)

print("✅ Inject berhasil!")
PYEOF

RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "❌ Gagal inject. Restore backup..."
  cp "$BACKUP_PATH" "$REMOTE_PATH"
  echo "✅ Backup dikembalikan."
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
echo "📂 File  : $REMOTE_PATH"
echo "🗂️ Backup: $BACKUP_PATH"
echo ""
echo "🔒 Aturan Proteksi:"
echo "   ❌ Unlimited (0) diblokir untuk Memory, Disk, CPU"
echo "   🧠 Memory  : Wajib 128 - 16.384 MB"
echo "   💾 Disk    : Wajib 512 - 102.400 MB"
echo "   ⚙️ CPU     : Wajib 10 - 400%"
echo "   📦 Backup  : Maks 10 slot"
echo "   🗄️ Database: Maks 10 slot"
echo ""
echo "════════════════════════════════════════════"
