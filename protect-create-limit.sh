#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/ServersController.php"
API_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Application/Servers/ServerController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_create_${TIMESTAMP}"
MARKER="BANIWW_CREATELIMIT"

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL CREATE LIMIT PROTECTION"
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

# ─── Deteksi nama fungsi yang tersedia ────────────────────────
python3 << PYEOF
import re, sys

filepath = "$REMOTE_PATH"

with open(filepath, 'r') as f:
    content = f.read()

# Cari semua fungsi public yang ada
funcs = re.findall(r'public function (\w+)\(', content)
print("📋 Fungsi yang ditemukan: " + ", ".join(funcs))

# Coba berbagai kemungkinan nama fungsi create di Pterodactyl
target_funcs = ['store', 'create', 'processCreate', 'postBasic']
found = None
for fn in target_funcs:
    if fn in funcs:
        found = fn
        print(f"✅ Target fungsi ditemukan: {fn}()")
        break

if not found:
    print(f"❌ Tidak ada fungsi create yang dikenal. Fungsi tersedia: {', '.join(funcs)}")
    sys.exit(1)

guard = f'''
        // 🔒 BANIWW_CREATELIMIT: Blokir unlimited (0) saat CREATE server
        $_mem  = (int) ($request->input('memory') ?? $request->input('limits.memory') ?? 1);
        $_disk = (int) ($request->input('disk')   ?? $request->input('limits.disk')   ?? 1);
        $_cpu  = (int) ($request->input('cpu')    ?? $request->input('limits.cpu')    ?? 1);
        $_bak  = (int) ($request->input('backup_limit', 0));
        $_db   = (int) ($request->input('database_limit', 0));

        if ($_mem <= 0)   throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory tidak boleh unlimited (0). Wajib antara 128 - 16384 MB.');
        if ($_disk <= 0)  throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk tidak boleh unlimited (0). Wajib antara 512 - 102400 MB.');
        if ($_cpu <= 0)   throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU tidak boleh unlimited (0). Wajib antara 10 - 400%.');
        if ($_mem > 16384)  throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory terlalu besar. Maksimal 16384 MB.');
        if ($_disk > 102400) throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk terlalu besar. Maksimal 102400 MB.');
        if ($_cpu > 400)  throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU terlalu besar. Maksimal 400%.');
        if ($_bak > 10)   throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Backup slot maks 10.');
        if ($_db > 10)    throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Database slot maks 10.');
'''

pattern = rf'(public function {found}\([^)]*\)[^{{]*\{{)'
new_content = re.sub(pattern, r'\\1' + guard, content, count=1, flags=re.DOTALL)

if new_content == content:
    print(f"❌ Gagal inject ke fungsi {found}()")
    sys.exit(1)

with open(filepath, 'w') as f:
    f.write(new_content)

print(f"✅ Inject ke fungsi {found}() berhasil!")
PYEOF

RESULT=$?
if [ $RESULT -ne 0 ]; then
  echo "❌ Gagal inject. Restore backup..."
  cp "$BACKUP_PATH" "$REMOTE_PATH"
  echo "✅ Backup dikembalikan."
  exit 1
fi

# ─── Patch API Controller juga ────────────────────────────────
if [ -f "$API_PATH" ] && ! grep -q "$MARKER" "$API_PATH" 2>/dev/null; then
  cp "$API_PATH" "${API_PATH}.bak_${TIMESTAMP}"
  echo "✅ Backup API Controller → ${API_PATH}.bak_${TIMESTAMP}"

  python3 << PYEOF2
import re, sys

filepath = "$API_PATH"

with open(filepath, 'r') as f:
    content = f.read()

funcs = re.findall(r'public function (\w+)\(', content)
target_funcs = ['store', 'create', 'processCreate']
found = None
for fn in target_funcs:
    if fn in funcs:
        found = fn
        break

if not found:
    print(f"⚠️  Fungsi create tidak ditemukan di API Controller, skip.")
    sys.exit(0)

guard = '''
        // 🔒 BANIWW_CREATELIMIT
        \$_am = (int) (\$request->input('limits.memory') ?? \$request->input('memory') ?? 1);
        \$_ad = (int) (\$request->input('limits.disk')   ?? \$request->input('disk')   ?? 1);
        \$_ac = (int) (\$request->input('limits.cpu')    ?? \$request->input('cpu')    ?? 1);
        if (\$_am <= 0)  throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory tidak boleh unlimited.');
        if (\$_ad <= 0)  throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk tidak boleh unlimited.');
        if (\$_ac <= 0)  throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU tidak boleh unlimited.');
        if (\$_am > 16384)  throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Memory maks 16384 MB.');
        if (\$_ad > 102400) throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 Disk maks 102400 MB.');
        if (\$_ac > 400)    throw new \\Pterodactyl\\Exceptions\\DisplayException('🔒 CPU maks 400%.');
'''

pattern = rf'(public function {found}\([^)]*\)[^{{]*\{{)'
new_content = re.sub(pattern, r'\\1' + guard, content, count=1, flags=re.DOTALL)

if new_content == content:
    print(f"⚠️  Gagal inject API Controller, skip.")
    sys.exit(0)

with open(filepath, 'w') as f:
    f.write(new_content)

print(f"✅ Inject API Controller ke {found}() berhasil!")
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
echo "🗂️ Backup: $BACKUP_PATH"
echo ""
echo "🔒 Aturan Create Server:"
echo "   ❌ Memory/Disk/CPU = 0 (unlimited) → DIBLOKIR"
echo "   ❌ Berlaku via panel admin DAN API (bot)"
echo "   🧠 Memory  : 128 - 16.384 MB"
echo "   💾 Disk    : 512 - 102.400 MB"
echo "   ⚙️ CPU     : 10 - 400%"
echo ""
echo "════════════════════════════════════════════"
