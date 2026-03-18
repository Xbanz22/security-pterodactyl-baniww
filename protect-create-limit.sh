#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/ServersController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_create_${TIMESTAMP}"
MARKER="BANIWW_CREATELIMIT"

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL CREATE LIMIT PROTECTION"
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

# Cek fungsi store() ada
if 'public function store(' not in content:
    print("❌ Fungsi store() tidak ditemukan.")
    exit(1)

guard = '''
        // 🔒 BANIWW_CREATELIMIT: Blokir unlimited (0) saat CREATE server
        \$cMemory = (int) \$request->input('memory', 1);
        \$cDisk   = (int) \$request->input('disk', 1);
        \$cCpu    = (int) \$request->input('cpu', 1);
        \$cBackup = (int) \$request->input('backup_limit', 0);
        \$cDb     = (int) \$request->input('database_limit', 0);

        // Blokir unlimited (0) untuk resource utama
        if (\$cMemory <= 0) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory tidak boleh unlimited (0). Wajib antara 128 - 16384 MB.');
        }
        if (\$cDisk <= 0) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk tidak boleh unlimited (0). Wajib antara 512 - 102400 MB.');
        }
        if (\$cCpu <= 0) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU tidak boleh unlimited (0). Wajib antara 10 - 400%.');
        }

        // Blokir nilai terlalu besar
        if (\$cMemory > 16384) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory terlalu besar. Maksimal 16384 MB (16 GB).');
        }
        if (\$cDisk > 102400) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk terlalu besar. Maksimal 102400 MB (100 GB).');
        }
        if (\$cCpu > 400) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU terlalu besar. Maksimal 400%.');
        }
        if (\$cBackup > 10) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Backup slot maks 10.');
        }
        if (\$cDb > 10) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Database slot maks 10.');
        }
'''

# Inject ke fungsi store()
pattern = r'(public function store\([^)]*\)[^{]*\{)'
new_content = re.sub(pattern, r'\1' + guard, content, count=1, flags=re.DOTALL)

if new_content == content:
    print("❌ Gagal inject store() — pattern tidak cocok.")
    exit(1)

with open(filepath, 'w') as f:
    f.write(new_content)

print("✅ Inject store() berhasil!")
PYEOF

RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "❌ Gagal inject. Restore backup..."
  cp "$BACKUP_PATH" "$REMOTE_PATH"
  echo "✅ Backup dikembalikan."
  exit 1
fi

# Patch juga API Application ServerController untuk blokir via API
API_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Application/Servers/ServerController.php"

if [ -f "$API_PATH" ] && ! grep -q "$MARKER" "$API_PATH" 2>/dev/null; then
  cp "$API_PATH" "${API_PATH}.bak_${TIMESTAMP}"
  echo "✅ Backup API Controller → ${API_PATH}.bak_${TIMESTAMP}"

  python3 << PYEOF2
import re

filepath = "$API_PATH"

with open(filepath, 'r') as f:
    content = f.read()

if 'public function store(' not in content:
    print("⚠️  store() tidak ditemukan di API Controller, skip.")
    exit(0)

guard = '''
        // 🔒 BANIWW_CREATELIMIT: Blokir unlimited via API
        \$apiMemory = (int) (\$request->input('limits.memory') ?? \$request->input('memory') ?? 1);
        \$apiDisk   = (int) (\$request->input('limits.disk')   ?? \$request->input('disk')   ?? 1);
        \$apiCpu    = (int) (\$request->input('limits.cpu')    ?? \$request->input('cpu')    ?? 1);

        if (\$apiMemory <= 0) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory tidak boleh unlimited (0).');
        }
        if (\$apiDisk <= 0) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk tidak boleh unlimited (0).');
        }
        if (\$apiCpu <= 0) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU tidak boleh unlimited (0).');
        }
        if (\$apiMemory > 16384) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory maks 16384 MB.');
        }
        if (\$apiDisk > 102400) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk maks 102400 MB.');
        }
        if (\$apiCpu > 400) {
            throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU maks 400%.');
        }
'''

pattern = r'(public function store\([^)]*\)[^{]*\{)'
new_content = re.sub(pattern, r'\1' + guard, content, count=1, flags=re.DOTALL)

if new_content == content:
    print("⚠️  Gagal inject API Controller — skip.")
    exit(0)

with open(filepath, 'w') as f:
    f.write(new_content)

print("✅ Inject API Controller berhasil!")
PYEOF2

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
echo "📂 API   : $API_PATH"
echo "🗂️ Backup: $BACKUP_PATH"
echo ""
echo "🔒 Aturan Create Server:"
echo "   ❌ Memory/Disk/CPU = 0 (unlimited) → DIBLOKIR"
echo "   ❌ Berlaku untuk panel admin DAN API (bot)"
echo "   🧠 Memory  : Wajib 128 - 16.384 MB"
echo "   💾 Disk    : Wajib 512 - 102.400 MB"
echo "   ⚙️ CPU     : Wajib 10 - 400%"
echo "   📦 Backup  : Maks 10 slot"
echo "   🗄️ Database: Maks 10 slot"
echo ""
echo "💡 Edit nilai maks langsung di script ini jika perlu."
echo ""
echo "════════════════════════════════════════════"
