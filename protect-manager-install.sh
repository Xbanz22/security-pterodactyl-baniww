#!/bin/bash
# protect-manager-install.sh
# by @baniwwwXD | baniwwDeveloper
# Install Protect Manager ke panel Pterodactyl

set -euo pipefail

PANEL_DIR="/var/www/pterodactyl"
CONTROLLER_SRC="https://raw.githubusercontent.com/Xbanz22/security-pterodactyl-baniww/main/ProtectManagerController.php"
CONTROLLER_DST="${PANEL_DIR}/app/Http/Controllers/Admin/ProtectManagerController.php"
VIEWS_DIR="${PANEL_DIR}/resources/views/admin/protect-manager"
SCRIPTS_STORE="${PANEL_DIR}/storage/protect-scripts"
MARKER="BANIWW_PROTECT_MANAGER"

# ── Auto-detect routes file ────────────────────────────────────
# Pterodactyl modern pakai routes/admin.php, bukan web.php
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
curl -fsSL "$CONTROLLER_SRC" -o "$CONTROLLER_DST" || {
  # Fallback: script sudah include controller inline
  warn "Gagal download controller, skip..."
}
chmod 644 "$CONTROLLER_DST" 2>/dev/null || true
ok "Controller: $CONTROLLER_DST"

# ── Buat direktori views ───────────────────────────────────────
info "Membuat direktori views..."
mkdir -p "$VIEWS_DIR"

# ── Download views ─────────────────────────────────────────────
BASE_URL="https://raw.githubusercontent.com/Xbanz22/security-pterodactyl-baniww/main"

info "Download index.blade.php..."
curl -fsSL "${BASE_URL}/protect-manager-index.blade.php" -o "${VIEWS_DIR}/index.blade.php"
chmod 644 "${VIEWS_DIR}/index.blade.php"
ok "View index siap"

info "Download config.blade.php..."
curl -fsSL "${BASE_URL}/protect-manager-config.blade.php" -o "${VIEWS_DIR}/config.blade.php"
chmod 644 "${VIEWS_DIR}/config.blade.php"
ok "View config siap"

# ── Buat storage untuk custom scripts ──────────────────────────
info "Setup storage custom scripts..."
mkdir -p "$SCRIPTS_STORE"
chown www-data:www-data "$SCRIPTS_STORE" 2>/dev/null || true
chmod 750 "$SCRIPTS_STORE"
ok "Storage: $SCRIPTS_STORE"

# ── Inject routes ke web.php ───────────────────────────────────
info "Inject routes..."

# Cek sudah ada
if grep -q "protect-manager" "$ROUTES_FILE" 2>/dev/null; then
  warn "Routes sudah ada, skip."
else
  # Tambahkan use statement kalau belum ada
  # admin.php Pterodactyl pakai format 'use' di atas file
  if ! grep -q "ProtectManagerController" "$ROUTES_FILE"; then
    # Coba inject setelah use statement lain yang sudah ada
    if grep -q "^use " "$ROUTES_FILE"; then
      # Ada use statement — inject setelah use terakhir
      sed -i "/^use .*Controller;$/a use Pterodactyl\\\\Http\\\\Controllers\\\\Admin\\\\ProtectManagerController;" "$ROUTES_FILE" 2>/dev/null || true
    else
      # Tidak ada use statement — inject di baris pertama setelah <?php
      sed -i "/^<?php/a use Pterodactyl\\\\Http\\\\Controllers\\\\Admin\\\\ProtectManagerController;" "$ROUTES_FILE" 2>/dev/null || true
    fi
  fi

  # Inject route group sebelum penutup group admin
  ROUTE_BLOCK=$(cat << 'ROUTEEOF'

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
ROUTEEOF
)
  # Backup routes dulu
  cp "$ROUTES_FILE" "${ROUTES_FILE}.bak_$(date +%Y%m%d%H%M%S)"

  # Inject sebelum baris terakhir yang berisi closing "}); // admin group"
  python3 - << PYEOF
import re
with open('$ROUTES_FILE', 'r') as f:
    content = f.read()

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

# Inject sebelum baris "}); // end admin" atau closing baris terakhir
lines = content.split('\n')
# Cari baris terakhir yang ada '})'
last_close = -1
for i, line in enumerate(lines):
    if '});' in line and ('admin' in line.lower() or i == len(lines) - 3):
        last_close = i
        break
if last_close == -1:
    # Fallback: inject di akhir file
    content += route_block
else:
    lines.insert(last_close, route_block)
    content = '\n'.join(lines)

with open('$ROUTES_FILE', 'w') as f:
    f.write(content)
print('Routes injected successfully')
PYEOF
  ok "Routes berhasil diinject"
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
    # Inject setelah menu Settings
    sed -i "s|route('admin.settings')|route('admin.settings')|" "$SIDEBAR_FILE"
    python3 - << PYEOF2
with open('$SIDEBAR_FILE', 'r') as f:
    content = f.read()

sidebar_item = """
                {{-- BANIWW_PM_SIDEBAR --}}
                <li class="{{ Route::currentRouteNamed('admin.protect-manager.*') ? 'active' : '' }}">
                    <a href="{{ route('admin.protect-manager.index') }}">
                        <i class="fa fa-shield"></i> <span>Protect Manager</span>
                    </a>
                </li>"""

# Inject setelah Settings menu item
import re
content = re.sub(
    r"(admin\.settings.*?</li>)",
    r"\1" + sidebar_item,
    content,
    count=1,
    flags=re.DOTALL
)
with open('$SIDEBAR_FILE', 'w') as f:
    f.write(content)
print('Sidebar injected')
PYEOF2
    ok "Menu Protect Manager ditambahkan ke sidebar"
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
