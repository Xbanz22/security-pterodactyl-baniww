#!/bin/bash
# protect-manager-install.sh
# by @baniwwwXD | baniwwDeveloper
# Install Protect Manager ke panel Pterodactyl

set -uo pipefail
# Note: sengaja tidak pakai -e agar error handling manual lebih aman

PANEL_DIR="/var/www/pterodactyl"
CONTROLLER_SRC="https://raw.githubusercontent.com/Xbanz22/security-pterodactyl-baniww/main/ProtectManagerController.php"
CONTROLLER_DST="${PANEL_DIR}/app/Http/Controllers/Admin/ProtectManagerController.php"
VIEWS_DIR="${PANEL_DIR}/resources/views/admin/protect-manager"
SCRIPTS_STORE="${PANEL_DIR}/storage/protect-scripts"
MARKER="BANIWW_PROTECT_MANAGER"

# ── Auto-detect routes file ────────────────────────────────────
if   [ -f "${PANEL_DIR}/routes/admin.php" ];  then ROUTES_FILE="${PANEL_DIR}/routes/admin.php"
elif [ -f "${PANEL_DIR}/routes/web.php" ];    then ROUTES_FILE="${PANEL_DIR}/routes/web.php"
elif [ -f "${PANEL_DIR}/routes/base.php" ];   then ROUTES_FILE="${PANEL_DIR}/routes/base.php"
else ROUTES_FILE="${PANEL_DIR}/routes/admin.php"; fi

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; exit 1; }

echo -e "${CYAN}"
echo "════════════════════════════════════════════"
echo "  🛡️  PROTECT MANAGER INSTALLER"
echo "  📦  by @baniwwwXD | baniwwDeveloper"
echo "════════════════════════════════════════════"
echo -e "${NC}"

# ── Cek sudah terinstall ───────────────────────────────────────
if grep -q "$MARKER" "$CONTROLLER_DST" 2>/dev/null; then
  echo -e "${GREEN}✅ ALREADY_INSTALLED — Protect Manager sudah terpasang!${NC}"
  exit 0
fi

# ── Cek panel dir ──────────────────────────────────────────────
[ -d "$PANEL_DIR" ] || fail "Direktori panel tidak ditemukan di $PANEL_DIR"
[ -f "$ROUTES_FILE" ] || fail "Routes file tidak ditemukan! Cek isi folder: ls ${PANEL_DIR}/routes/"
info "Routes file: $ROUTES_FILE"

# ── Install controller ─────────────────────────────────────────
info "Install controller..."
if curl -fsSL "$CONTROLLER_SRC" -o "$CONTROLLER_DST"; then
  chmod 644 "$CONTROLLER_DST"
  ok "Controller downloaded: $CONTROLLER_DST"
else
  # FIX: kalau download gagal, jangan lanjut kalau file tidak ada
  if [ ! -f "$CONTROLLER_DST" ]; then
    fail "Gagal download controller dan file tidak ada. Cek koneksi atau URL: $CONTROLLER_SRC"
  else
    warn "Gagal re-download controller, menggunakan file yang sudah ada."
  fi
fi

# ── Buat direktori views ───────────────────────────────────────
info "Membuat direktori views..."
mkdir -p "$VIEWS_DIR"

# ── Download views ─────────────────────────────────────────────
BASE_URL="https://raw.githubusercontent.com/Xbanz22/security-pterodactyl-baniww/main"

info "Download index.blade.php..."
if curl -fsSL "${BASE_URL}/protect-manager-index.blade.php" -o "${VIEWS_DIR}/index.blade.php"; then
  chmod 644 "${VIEWS_DIR}/index.blade.php"
  ok "View index siap"
else
  fail "Gagal download index.blade.php"
fi

info "Download config.blade.php..."
if curl -fsSL "${BASE_URL}/protect-manager-config.blade.php" -o "${VIEWS_DIR}/config.blade.php"; then
  chmod 644 "${VIEWS_DIR}/config.blade.php"
  ok "View config siap"
else
  fail "Gagal download config.blade.php"
fi

# ── Buat storage untuk custom scripts ──────────────────────────
info "Setup storage custom scripts..."
mkdir -p "$SCRIPTS_STORE"
chown www-data:www-data "$SCRIPTS_STORE" 2>/dev/null || true
chmod 750 "$SCRIPTS_STORE"
ok "Storage: $SCRIPTS_STORE"

# ── Inject routes ──────────────────────────────────────────────
info "Inject routes..."

if grep -q "protect-manager" "$ROUTES_FILE" 2>/dev/null; then
  warn "Routes sudah ada, skip."
else
  # Backup routes dulu
  cp "$ROUTES_FILE" "${ROUTES_FILE}.bak_$(date +%Y%m%d%H%M%S)"

  # FIX: inject use statement hanya sekali, pakai python agar aman
  # FIX: variable expansion — heredoc tanpa quote agar $ROUTES_FILE di-expand
  python3 - << PYEOF
import re

routes_file = "$ROUTES_FILE"

with open(routes_file, 'r') as f:
    content = f.read()

use_statement = "use Pterodactyl\\\\Http\\\\Controllers\\\\Admin\\\\ProtectManagerController;"

# Inject use statement hanya kalau belum ada
if "ProtectManagerController" not in content:
    # Cari use statement terakhir yang ada di file
    use_matches = list(re.finditer(r'^use .+;$', content, re.MULTILINE))
    if use_matches:
        # Inject setelah use statement terakhir (bukan setiap baris)
        last_use = use_matches[-1]
        insert_pos = last_use.end()
        content = content[:insert_pos] + "\n" + use_statement + content[insert_pos:]
    else:
        # Tidak ada use statement, inject setelah <?php
        content = re.sub(r'(<\?php\s*\n)', r'\1' + use_statement + "\n", content, count=1)

route_block = """
    // ── Protect Manager (by @baniwwwXD) ──────────────────────
    Route::prefix('/protect-manager')->name('admin.protect-manager.')->group(function () {
        Route::get('/',                [ProtectManagerController::class, 'index'])->name('index');
        Route::get('/config',          [ProtectManagerController::class, 'config'])->name('config');
        Route::get('/status',          [ProtectManagerController::class, 'statusAll'])->name('status');
        Route::post('/install',        [ProtectManagerController::class, 'install'])->name('install');
        Route::post('/uninstall',      [ProtectManagerController::class, 'uninstall'])->name('uninstall');
        Route::post('/install-batch',  [ProtectManagerController::class, 'installBatch'])->name('install-batch');
        Route::post('/save-config',    [ProtectManagerController::class, 'saveConfig'])->name('save-config');
        Route::post('/edit-protection',[ProtectManagerController::class, 'editProtection'])->name('edit-protection');
        Route::post('/upload-script',  [ProtectManagerController::class, 'uploadScript'])->name('upload-script');
    });
"""

lines = content.split('\n')

# FIX: scan SEMUA baris, ambil index TERAKHIR yang mengandung '});'
# (bukan break di pertama yang match)
last_close = -1
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('});'):
        last_close = i

if last_close == -1:
    # Fallback: inject di akhir file
    content += route_block
    print("Warning: closing }); tidak ditemukan, route diinject di akhir file")
else:
    lines.insert(last_close, route_block)
    content = '\n'.join(lines)
    print(f"Routes injected sebelum baris {last_close}: {lines[last_close + 1].strip()!r}")

with open(routes_file, 'w') as f:
    f.write(content)
print('Routes injected successfully')
PYEOF

  if [ $? -eq 0 ]; then
    ok "Routes berhasil diinject"
  else
    fail "Gagal inject routes"
  fi
fi

# ── Inject Protect Manager ke sidebar ─────────────────────────
info "Tambahkan menu ke sidebar admin..."
SIDEBAR_FILE="${PANEL_DIR}/resources/views/layouts/admin.blade.php"
SIDEBAR_MARKER="BANIWW_PM_SIDEBAR"

if grep -q "$SIDEBAR_MARKER" "$SIDEBAR_FILE" 2>/dev/null; then
  warn "Sidebar sudah ada, skip."
else
  if [ -f "$SIDEBAR_FILE" ]; then
    cp "$SIDEBAR_FILE" "${SIDEBAR_FILE}.bak_$(date +%Y%m%d%H%M%S)"

    # FIX: variable expansion — heredoc tanpa quote
    python3 - << PYEOF2
import re

sidebar_file = "$SIDEBAR_FILE"

with open(sidebar_file, 'r') as f:
    content = f.read()

sidebar_item = """
                {{-- BANIWW_PM_SIDEBAR --}}
                <li class="{{ Route::currentRouteNamed('admin.protect-manager.*') ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager.index') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>"""

# FIX: regex yang benar — inject setelah </li> pertama yang mengandung admin.settings
# Cari pola <li>...</li> yang berisi admin.settings
pattern = r"(admin\.settings[^<]*(?:<[^>]+>)*\s*</li>)"
match = re.search(pattern, content, re.DOTALL)

if match:
    insert_pos = match.end()
    content = content[:insert_pos] + sidebar_item + content[insert_pos:]
    print("Sidebar item injected setelah menu Settings")
else:
    # Fallback: coba inject sebelum </ul> pertama dalam sidebar
    content = re.sub(
        r'(</ul>\s*</div>\s*<!-- sidebar -->)',
        sidebar_item + r'\1',
        content,
        count=1,
        flags=re.DOTALL | re.IGNORECASE
    )
    print("Warning: Settings menu tidak ditemukan, inject menggunakan fallback")

with open(sidebar_file, 'w') as f:
    f.write(content)
print("Sidebar updated")
PYEOF2

    if [ $? -eq 0 ]; then
      ok "Menu Protect Manager ditambahkan ke sidebar"
    else
      warn "Gagal inject sidebar, lanjut tanpa sidebar menu"
    fi
  else
    warn "Sidebar file tidak ditemukan, skip."
  fi
fi

# ── Clear cache ────────────────────────────────────────────────
info "Clear cache Laravel..."
cd "$PANEL_DIR"
php artisan optimize:clear > /dev/null 2>&1 || true
php artisan view:clear     > /dev/null 2>&1 || true
php artisan route:clear    > /dev/null 2>&1 || true
ok "Cache cleared"

# ── Set permission ─────────────────────────────────────────────
chown -R www-data:www-data "${VIEWS_DIR}" 2>/dev/null || true
chown www-data:www-data "$CONTROLLER_DST" 2>/dev/null || true

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ PROTECT MANAGER BERHASIL DIPASANG!${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""
echo -e "  🌐 Akses: <domain_panel>/admin/protect-manager"
echo -e "  📋 Views : ${VIEWS_DIR}/"
echo -e "  🔧 Ctrl  : ${CONTROLLER_DST}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
