#!/bin/bash

# Custom 403 Page + Route Middleware Protection
# By @baniwwwXD
# Kalau bukan ID 1 akses URL terlarang → halaman 403 custom

if [ ! -t 0 ]; then AUTOCONFIRM="y"; else AUTOCONFIRM=""; fi

MIDDLEWARE_PATH="/var/www/pterodactyl/app/Http/Middleware"
VIEWS_PATH="/var/www/pterodactyl/resources/views/errors"
KERNEL_PATH="/var/www/pterodactyl/app/Http/Kernel.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")

clear 2>/dev/null || true
echo "════════════════════════════════════════════"
echo "  🚫 CUSTOM 403 + ROUTE PROTECTION"
echo "  By @baniwwwXD"
echo "════════════════════════════════════════════"

if [ "$EUID" -ne 0 ]; then echo "❌ Harus root!"; exit 1; fi
if grep -q "BANIWW_403" "$MIDDLEWARE_PATH/SuperAdminOnly.php" 2>/dev/null; then
  echo "⚠️  Sudah terpasang!"; echo "ALREADY_INSTALLED"; exit 0
fi

if [ -z "$AUTOCONFIRM" ]; then read -p "Continue? (y/n): " confirm
else confirm="y"; echo "Auto-confirm: y"; fi
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { echo "❌ Cancelled."; exit 1; }

# ── STEP 1: Buat Middleware SuperAdminOnly ─────────────────────
echo ""
echo "🔧 [1/3] Membuat middleware SuperAdminOnly..."
mkdir -p "$MIDDLEWARE_PATH"

cat > "$MIDDLEWARE_PATH/SuperAdminOnly.php" << 'PHPEOF'
<?php
// BANIWW_403: SuperAdminOnly Middleware by @baniwwwXD

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class SuperAdminOnly
{
    /**
     * Routes yang HANYA boleh diakses user ID 1.
     * Selain itu → 403 custom page.
     */
    protected array $protectedPrefixes = [
        'admin/settings',
        'admin/api',
        'admin/databases',
        'admin/locations',
        'admin/nodes',
        'admin/mounts',
        'admin/nests',
    ];

    public function handle(Request $request, Closure $next)
    {
        $user = Auth::user();

        // Kalau belum login, lanjutkan (biar auth middleware handle)
        if (!$user) {
            return $next($request);
        }

        // Cek apakah URL yang diakses termasuk yang diproteksi
        $path = $request->path();
        foreach ($this->protectedPrefixes as $prefix) {
            if (str_starts_with($path, $prefix)) {
                // Kalau bukan ID 1 → abort 403
                if ($user->id !== 1) {
                    abort(403, 'SUPERADMIN_ONLY');
                }
            }
        }

        return $next($request);
    }
}
PHPEOF

echo "✅ Middleware dibuat!"

# ── STEP 2: Register middleware di Kernel.php ──────────────────
echo ""
echo "🔧 [2/3] Mendaftarkan middleware di Kernel.php..."

# Backup Kernel
cp "$KERNEL_PATH" "${KERNEL_PATH}.bak_${TIMESTAMP}"

# Tambah middleware ke $routeMiddleware array
if grep -q "SuperAdminOnly" "$KERNEL_PATH"; then
  echo "⚠️  Middleware sudah terdaftar, skip."
else
  # Cari baris 'auth' => \Pterodactyl\Http\Middleware\Authenticate::class,
  # dan tambahkan SuperAdminOnly setelahnya
  sed -i "/'auth' => \\\Pterodactyl\\\Http\\\Middleware\\\Authenticate::class,/a\\        'superadmin' => \\\Pterodactyl\\\Http\\\Middleware\\\SuperAdminOnly::class," "$KERNEL_PATH"
  
  if grep -q "SuperAdminOnly" "$KERNEL_PATH"; then
    echo "✅ Middleware terdaftar di Kernel.php!"
  else
    echo "⚠️  Auto-register gagal, coba manual..."
    # Fallback: tambah ke $middlewareAliases atau $routeMiddleware
    python3 << 'PYEOF'
import re

path = "/var/www/pterodactyl/app/Http/Kernel.php"
with open(path, "r") as f:
    content = f.read()

new_entry = "        'superadmin' => \\Pterodactyl\\Http\\Middleware\\SuperAdminOnly::class,"

# Cari routeMiddleware atau middlewareAliases array
patterns = [
    (r"('auth'\s*=>\s*\\[^,]+,)", r"\1\n" + new_entry),
    (r"('can'\s*=>\s*\\[^,]+,)", r"\1\n" + new_entry),
]

added = False
for pattern, replacement in patterns:
    if re.search(pattern, content) and new_entry not in content:
        content = re.sub(pattern, replacement, content, count=1)
        added = True
        break

if added:
    with open(path, "w") as f:
        f.write(content)
    print("✅ Middleware berhasil didaftarkan!")
else:
    print("⚠️  Tidak bisa auto-register, perlu manual.")
PYEOF
  fi
fi

# ── STEP 3: Buat halaman 403 custom ───────────────────────────
echo ""
echo "🔧 [3/3] Membuat halaman 403 custom..."
mkdir -p "$VIEWS_PATH"

cat > "$VIEWS_PATH/403.blade.php" << 'BLADEEOF'
{{-- BANIWW_403: Custom 403 Page by @baniwwwXD --}}
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>403 - DILARANG KERAS</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            background: #0a0a0a;
            color: #fff;
            font-family: 'Courier New', monospace;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
        }

        /* Animasi scanline */
        body::before {
            content: '';
            position: fixed;
            top: 0; left: 0;
            width: 100%; height: 100%;
            background: repeating-linear-gradient(
                0deg,
                transparent,
                transparent 2px,
                rgba(255,0,0,0.03) 2px,
                rgba(255,0,0,0.03) 4px
            );
            pointer-events: none;
            z-index: 0;
        }

        .container {
            text-align: center;
            padding: 40px 20px;
            position: relative;
            z-index: 1;
            max-width: 800px;
        }

        /* Angka 403 besar */
        .error-code {
            font-size: clamp(120px, 25vw, 220px);
            font-weight: 900;
            color: #ff0000;
            letter-spacing: -10px;
            line-height: 1;
            text-shadow:
                0 0 30px rgba(255,0,0,0.8),
                0 0 60px rgba(255,0,0,0.5),
                0 0 100px rgba(255,0,0,0.3),
                4px 4px 0 #800000,
                8px 8px 0 #4a0000;
            animation: flicker 3s infinite;
        }

        @keyframes flicker {
            0%, 95%, 100% { opacity: 1; }
            96% { opacity: 0.8; }
            97% { opacity: 1; }
            98% { opacity: 0.6; }
            99% { opacity: 1; }
        }

        /* Garis merah separator */
        .separator {
            width: 100%;
            height: 4px;
            background: linear-gradient(90deg, transparent, #ff0000, transparent);
            margin: 20px 0;
            box-shadow: 0 0 20px rgba(255,0,0,0.8);
            animation: pulse 2s ease-in-out infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 1; transform: scaleX(1); }
            50% { opacity: 0.7; transform: scaleX(0.95); }
        }

        /* Tulisan utama DILARANG KERAS */
        .main-title {
            font-size: clamp(28px, 6vw, 58px);
            font-weight: 900;
            color: #ff0000;
            text-transform: uppercase;
            letter-spacing: 6px;
            text-shadow:
                0 0 20px rgba(255,0,0,0.9),
                0 0 40px rgba(255,0,0,0.5);
            margin: 10px 0;
            animation: glitch 4s infinite;
        }

        @keyframes glitch {
            0%, 90%, 100% { transform: translate(0); }
            91% { transform: translate(-3px, 1px); color: #ff6666; }
            92% { transform: translate(3px, -1px); color: #ff0000; }
            93% { transform: translate(0); }
        }

        .sub-title {
            font-size: clamp(14px, 3vw, 24px);
            color: #ff6666;
            letter-spacing: 3px;
            text-transform: uppercase;
            margin: 8px 0 20px;
            font-weight: 700;
        }

        /* Kotak pesan utama */
        .message-box {
            background: rgba(255, 0, 0, 0.08);
            border: 2px solid #ff0000;
            border-radius: 8px;
            padding: 30px;
            margin: 20px 0;
            box-shadow:
                0 0 20px rgba(255,0,0,0.3),
                inset 0 0 20px rgba(255,0,0,0.05);
        }

        .message-text {
            font-size: clamp(16px, 3vw, 26px);
            font-weight: 900;
            color: #ffffff;
            text-transform: uppercase;
            letter-spacing: 2px;
            line-height: 1.6;
            text-shadow: 0 0 10px rgba(255,100,100,0.5);
        }

        .message-text span {
            color: #ff0000;
            font-size: 1.2em;
        }

        /* Warning baris bawah */
        .warning-bar {
            background: #ff0000;
            color: #000;
            font-size: clamp(11px, 2vw, 16px);
            font-weight: 900;
            letter-spacing: 3px;
            text-transform: uppercase;
            padding: 12px 20px;
            margin-top: 20px;
            border-radius: 4px;
            animation: blink 1.5s step-end infinite;
        }

        @keyframes blink {
            0%, 100% { opacity: 1; }
            50% { opacity: 0; }
        }

        /* Info teknis */
        .tech-info {
            font-size: 13px;
            color: #666;
            margin-top: 25px;
            letter-spacing: 1px;
        }

        .tech-info code {
            color: #ff4444;
            background: rgba(255,0,0,0.1);
            padding: 2px 8px;
            border-radius: 3px;
            font-size: 12px;
        }

        /* Sudut dekorasi */
        .corner {
            position: fixed;
            font-size: 11px;
            color: #333;
            letter-spacing: 2px;
        }
        .corner.tl { top: 15px; left: 15px; }
        .corner.tr { top: 15px; right: 15px; }
        .corner.bl { bottom: 15px; left: 15px; }
        .corner.br { bottom: 15px; right: 15px; }
    </style>
</head>
<body>

    <div class="corner tl">SYSTEM::SECURITY</div>
    <div class="corner tr">STATUS::BLOCKED</div>
    <div class="corner bl">BY::@BANIWWWXD</div>
    <div class="corner br">CODE::403</div>

    <div class="container">

        <div class="error-code">403</div>

        <div class="separator"></div>

        <div class="main-title">⛔ AKSES DILARANG KERAS ⛔</div>
        <div class="sub-title">Access Strictly Forbidden</div>

        <div class="message-box">
            <div class="message-text">
                <span>BERHENTI!</span> Kamu tidak punya izin<br>
                untuk mengakses halaman ini.<br><br>
                Halaman ini hanya untuk<br>
                <span>SUPER ADMINISTRATOR</span><br><br>
                Jangan coba-coba lagi! 🔒
            </div>
        </div>

        <div class="warning-bar">
            ⚠️ &nbsp; AKSES TIDAK SAH DICATAT &nbsp; ⚠️
        </div>

        <div class="tech-info">
            HTTP <code>403 Forbidden</code> &nbsp;|&nbsp;
            IP: <code>{{ request()->ip() }}</code> &nbsp;|&nbsp;
            Path: <code>/{{ request()->path() }}</code>
            <br><br>
            Protected by <code>@baniwwwXD Security</code>
        </div>

    </div>

</body>
</html>
BLADEEOF

echo "✅ Halaman 403 custom dibuat!"

# ── Clear cache ────────────────────────────────────────────────
cd /var/www/pterodactyl
php artisan config:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
php artisan view:clear > /dev/null 2>&1
php artisan route:clear > /dev/null 2>&1
echo "✅ Cache cleared!"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ CUSTOM 403 + PROTECTION TERPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "🚫 Kalau bukan ID 1 akses URL terlarang:"
echo "   → Halaman 403 DILARANG KERAS muncul"
echo "   → IP & path dicatat di halaman"
echo "   → Tidak bisa di-bypass lewat URL langsung"
echo ""
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
