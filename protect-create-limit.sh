#!/bin/bash

# Versi Pterodactyl ini punya fungsi create server di:
# - Api/Application/Servers/ServerController.php (via API)
# - ServersController.php tidak punya store(), pakai route lain
# Jadi kita patch API Application Controller saja

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
  echo "❌ ERROR: File tidak ditemukan di $API_PATH"
  echo "   Coba cari manual:"
  echo "   find /var/www/pterodactyl -name 'ServerController.php' | head -5"
  exit 1
fi

cp "$API_PATH" "${API_PATH}.bak_${TIMESTAMP}"
echo "✅ Backup → ${API_PATH}.bak_${TIMESTAMP}"

# ─── Deteksi dan inject ───────────────────────────────────────
python3 << PYEOF
import re, sys

filepath = "$API_PATH"

with open(filepath, 'r') as f:
    content = f.read()

# Tampil semua fungsi dulu untuk debug
funcs = re.findall(r'public function (\w+)\(', content)
print("📋 Fungsi: " + ", ".join(funcs))

# Cari fungsi store atau create
target = None
for fn in ['store', 'create', 'index']:
    if fn in funcs and fn != 'index':
        target = fn
        break

if not target:
    # Kalau tidak ada, coba cari fungsi pertama setelah __construct
    for fn in funcs:
        if fn != '__construct':
            target = fn
            break

if not target:
    print("❌ Tidak ada fungsi yang bisa di-inject.")
    sys.exit(1)

print(f"✅ Target fungsi: {target}()")

guard = r"""
        // 🔒 BANIWW_CREATELIMIT: Blokir unlimited (0) saat create server via API
        $_m = (int) (data_get($this->request->input(), 'limits.memory') ?? $this->request->input('memory') ?? $request->input('limits.memory') ?? $request->input('memory') ?? 1);
        $_d = (int) (data_get($this->request->input(), 'limits.disk')   ?? $this->request->input('disk')   ?? $request->input('limits.disk')   ?? $request->input('disk')   ?? 1);
        $_c = (int) (data_get($this->request->input(), 'limits.cpu')    ?? $this->request->input('cpu')    ?? $request->input('limits.cpu')    ?? $request->input('cpu')    ?? 1);
        if ($_m <= 0)    throw new \Pterodactyl\Exceptions\DisplayException('🔒 Memory tidak boleh unlimited (0). Wajib antara 128-16384 MB.');
        if ($_d <= 0)    throw new \Pterodactyl\Exceptions\DisplayException('🔒 Disk tidak boleh unlimited (0). Wajib antara 512-102400 MB.');
        if ($_c <= 0)    throw new \Pterodactyl\Exceptions\DisplayException('🔒 CPU tidak boleh unlimited (0). Wajib antara 10-400%.');
        if ($_m > 16384) throw new \Pterodactyl\Exceptions\DisplayException('🔒 Memory terlalu besar. Maksimal 16384 MB.');
        if ($_d > 102400)throw new \Pterodactyl\Exceptions\DisplayException('🔒 Disk terlalu besar. Maksimal 102400 MB.');
        if ($_c > 400)   throw new \Pterodactyl\Exceptions\DisplayException('🔒 CPU terlalu besar. Maksimal 400%.');
"""

pattern = rf'(public function {target}\([^)]*\)[^{{]*\{{)'
new_content = re.sub(pattern, r'\1' + guard, content, count=1, flags=re.DOTALL)

if new_content == content:
    print(f"❌ Gagal inject ke {target}()")
    sys.exit(1)

with open(filepath, 'w') as f:
    f.write(new_content)

print(f"✅ Inject ke {target}() berhasil!")
PYEOF

RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "❌ Gagal inject. Restore backup..."
  cp "${API_PATH}.bak_${TIMESTAMP}" "$API_PATH"
  echo "✅ Backup dikembalikan."
  exit 1
fi

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
echo "📂 File  : $API_PATH"
echo "🗂️ Backup: ${API_PATH}.bak_${TIMESTAMP}"
echo ""
echo "🔒 Aturan:"
echo "   ❌ Memory/Disk/CPU = 0 (unlimited) → DIBLOKIR via API"
echo "   🧠 Memory  : 128 - 16.384 MB"
echo "   💾 Disk    : 512 - 102.400 MB"
echo "   ⚙️ CPU     : 10 - 400%"
echo ""
echo "════════════════════════════════════════════"
