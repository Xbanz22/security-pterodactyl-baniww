#!/bin/bash

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
  echo "❌ ERROR: File tidak ditemukan di $REMOTE_PATH"
  exit 1
fi

cp "$REMOTE_PATH" "$BACKUP_PATH"
echo "✅ Backup → $BACKUP_PATH"
echo "📋 Fungsi: $(grep -o 'public function [a-zA-Z]*' $REMOTE_PATH | head -20 | tr '\n' ', ')"

# ─── Cek fungsi updateBuild ada ───────────────────────────────
if ! grep -q "public function updateBuild" "$REMOTE_PATH"; then
  echo "❌ Fungsi updateBuild() tidak ditemukan!"
  exit 1
fi

echo "✅ Target: updateBuild()"

# ─── Tulis guard PHP ke file terpisah dulu ────────────────────
# Cara ini menghindari masalah escape di Python/bash
cat > /tmp/memlimit_guard.txt << 'GUARDEOF'

        // 🔒 BANIWW_MEMLIMIT: Blokir unlimited (0) dan nilai lebay
        $bm  = (int) $request->input('memory', 1);
        $bd  = (int) $request->input('disk', 1);
        $bc  = (int) $request->input('cpu', 1);
        $bb  = (int) $request->input('backup_limit', 0);
        $bdb = (int) $request->input('database_limit', 0);

        if ($bm <= 0)    { throw new \Pterodactyl\Exceptions\DisplayException('Memory tidak boleh unlimited (0). Wajib 128-16384 MB.'); }
        if ($bd <= 0)    { throw new \Pterodactyl\Exceptions\DisplayException('Disk tidak boleh unlimited (0). Wajib 512-102400 MB.'); }
        if ($bc <= 0)    { throw new \Pterodactyl\Exceptions\DisplayException('CPU tidak boleh unlimited (0). Wajib 10-400%.'); }
        if ($bm > 16384) { throw new \Pterodactyl\Exceptions\DisplayException('Memory terlalu besar. Maksimal 16384 MB (16 GB).'); }
        if ($bd > 102400){ throw new \Pterodactyl\Exceptions\DisplayException('Disk terlalu besar. Maksimal 102400 MB (100 GB).'); }
        if ($bc > 400)   { throw new \Pterodactyl\Exceptions\DisplayException('CPU terlalu besar. Maksimal 400%.'); }
        if ($bb > 10)    { throw new \Pterodactyl\Exceptions\DisplayException('Backup slot maks 10.'); }
        if ($bdb > 10)   { throw new \Pterodactyl\Exceptions\DisplayException('Database slot maks 10.'); }
GUARDEOF

# ─── Inject via Python — baca guard dari file, bukan dari string ──
python3 << PYEOF
import re, sys

filepath  = "$REMOTE_PATH"
guardfile = "/tmp/memlimit_guard.txt"

with open(filepath, 'r') as f:
    content = f.read()

with open(guardfile, 'r') as f:
    guard = f.read()

if 'BANIWW_MEMLIMIT' in content:
    print("✅ ALREADY_INSTALLED")
    sys.exit(0)

# Cari baris pembuka fungsi updateBuild
# Pakai split string biasa, lebih aman dari regex untuk kasus ini
marker = 'public function updateBuild('
idx = content.find(marker)
if idx == -1:
    print("❌ updateBuild() tidak ditemukan")
    sys.exit(1)

# Cari { pertama setelah fungsi
brace_idx = content.find('{', idx)
if brace_idx == -1:
    print("❌ Opening brace tidak ditemukan")
    sys.exit(1)

# Inject guard setelah {
new_content = content[:brace_idx+1] + guard + content[brace_idx+1:]

with open(filepath, 'w') as f:
    f.write(new_content)

print("✅ Inject berhasil!")
PYEOF

RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "❌ Gagal inject. Restore backup..."
  cp "$BACKUP_PATH" "$REMOTE_PATH"
  rm -f /tmp/memlimit_guard.txt
  exit 1
fi

rm -f /tmp/memlimit_guard.txt

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
echo "   ❌ Memory/Disk/CPU = 0 (unlimited) → DIBLOKIR"
echo "   🧠 Memory  : 128 - 16.384 MB"
echo "   💾 Disk    : 512 - 102.400 MB"
echo "   ⚙️ CPU     : 10 - 400%"
echo "   📦 Backup  : Maks 10 slot"
echo "   🗄️ Database: Maks 10 slot"
echo ""
echo "════════════════════════════════════════════"
