#!/bin/bash

API_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Application/Servers/ServerController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
MARKER="BANIWW_CREATELIMIT"

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL CREATE LIMIT PROTECTION"
echo "  by @baniwwwXD | baniwwDeveloper"
echo "════════════════════════════════════════════"
echo ""

if grep -q "$MARKER" "$API_PATH" 2>/dev/null; then
  echo "✅ ALREADY_INSTALLED — Proteksi sudah terpasang!"
  exit 0
fi

if [ ! -f "$API_PATH" ]; then
  echo "❌ File tidak ditemukan: $API_PATH"
  echo "   Cari manual: find /var/www/pterodactyl -name 'ServerController.php'"
  exit 1
fi

cp "$API_PATH" "${API_PATH}.bak_${TIMESTAMP}"
echo "✅ Backup → ${API_PATH}.bak_${TIMESTAMP}"

FUNCS=$(grep -o 'public function [a-zA-Z]*' "$API_PATH" | tr '\n' ', ')
echo "📋 Fungsi: $FUNCS"

# ─── Tulis guard PHP ke file terpisah ────────────────────────
cat > /tmp/createlimit_guard.txt << 'GUARDEOF'

        // 🔒 BANIWW_CREATELIMIT: Blokir unlimited (0) saat create server via API
        $cm = (int) ($request->input('limits.memory') ?? $request->input('memory') ?? 1);
        $cd = (int) ($request->input('limits.disk')   ?? $request->input('disk')   ?? 1);
        $cc = (int) ($request->input('limits.cpu')    ?? $request->input('cpu')    ?? 1);

        if ($cm <= 0)    { throw new \Pterodactyl\Exceptions\DisplayException('Memory tidak boleh unlimited (0). Wajib 128-16384 MB.'); }
        if ($cd <= 0)    { throw new \Pterodactyl\Exceptions\DisplayException('Disk tidak boleh unlimited (0). Wajib 512-102400 MB.'); }
        if ($cc <= 0)    { throw new \Pterodactyl\Exceptions\DisplayException('CPU tidak boleh unlimited (0). Wajib 10-400%.'); }
        if ($cm > 16384) { throw new \Pterodactyl\Exceptions\DisplayException('Memory terlalu besar. Maksimal 16384 MB.'); }
        if ($cd > 102400){ throw new \Pterodactyl\Exceptions\DisplayException('Disk terlalu besar. Maksimal 102400 MB.'); }
        if ($cc > 400)   { throw new \Pterodactyl\Exceptions\DisplayException('CPU terlalu besar. Maksimal 400%.'); }
GUARDEOF

# ─── Inject via Python — baca guard dari file ─────────────────
python3 << PYEOF
import re, sys

filepath  = "$API_PATH"
guardfile = "/tmp/createlimit_guard.txt"

with open(filepath, 'r') as f:
    content = f.read()

with open(guardfile, 'r') as f:
    guard = f.read()

if 'BANIWW_CREATELIMIT' in content:
    print("✅ ALREADY_INSTALLED")
    sys.exit(0)

# Deteksi fungsi target
funcs = re.findall(r'public function (\w+)\(', content)
print("📋 Fungsi: " + ", ".join(funcs))

target = None
for fn in ['store', 'create']:
    if fn in funcs:
        target = fn
        break

if not target:
    print("❌ Fungsi store/create tidak ditemukan. Tersedia: " + ", ".join(funcs))
    sys.exit(1)

print(f"✅ Target: {target}()")

# Cari posisi fungsi target pakai string find, bukan regex
marker_str = f'public function {target}('
idx = content.find(marker_str)
if idx == -1:
    print(f"❌ {target}() tidak ditemukan dalam file")
    sys.exit(1)

# Cari { pertama setelah deklarasi fungsi
brace_idx = content.find('{', idx)
if brace_idx == -1:
    print("❌ Opening brace tidak ditemukan")
    sys.exit(1)

# Inject guard setelah {
new_content = content[:brace_idx+1] + guard + content[brace_idx+1:]

with open(filepath, 'w') as f:
    f.write(new_content)

print(f"✅ Inject ke {target}() berhasil!")
PYEOF

RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "❌ Gagal inject. Restore backup..."
  cp "${API_PATH}.bak_${TIMESTAMP}" "$API_PATH"
  rm -f /tmp/createlimit_guard.txt
  exit 1
fi

rm -f /tmp/createlimit_guard.txt

echo ""
echo "🔄 Clear cache Laravel..."
cd /var/www/pterodactyl && php artisan optimize:clear > /dev/null 2>&1
echo "✅ Cache cleared."
chmod 644 "$API_PATH"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ PROTEKSI BERHASIL DIPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "🔒 Aturan Create Server (via API):"
echo "   ❌ Memory/Disk/CPU = 0 (unlimited) → DIBLOKIR"
echo "   🧠 Memory  : 128 - 16.384 MB"
echo "   💾 Disk    : 512 - 102.400 MB"
echo "   ⚙️ CPU     : 10 - 400%"
echo ""
echo "════════════════════════════════════════════"
