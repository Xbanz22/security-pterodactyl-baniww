#!/bin/bash

# Full API Key Protection Script
# By @baniwwwXD
# GitHub: github.com/Xbanz22
# Repo: security-pterodactyl-baniww

# ── Non-interactive mode (support curl | bash) ───────────────
# Kalau dijalanin via pipe, auto-confirm y
if [ ! -t 0 ]; then
    AUTOCONFIRM="y"
else
    AUTOCONFIRM=""
fi

CONTROLLER_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Account/ClientApiController.php"
UI_PATH="/var/www/pterodactyl/resources/scripts/components/dashboard/AccountOverviewContainer.tsx"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_CONTROLLER="${CONTROLLER_PATH}.bak_${TIMESTAMP}"
BACKUP_UI="${UI_PATH}.bak_${TIMESTAMP}"

clear 2>/dev/null || true
echo "════════════════════════════════════════════"
echo "  🔐 FULL API KEY PROTECTION"
echo "  👑 By @baniwwwXD"
echo "  🌐 github.com/Xbanz22"
echo "════════════════════════════════════════════"
echo ""

# ── Cek root ─────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    echo "❌ Script harus dijalankan sebagai root!"
    exit 1
fi

# ── Cek file exist ────────────────────────────────────────────
if [ ! -f "$CONTROLLER_PATH" ]; then
    echo "❌ Controller tidak ditemukan: $CONTROLLER_PATH"
    exit 1
fi
if [ ! -f "$UI_PATH" ]; then
    echo "❌ UI file tidak ditemukan: $UI_PATH"
    exit 1
fi

# ── Cek sudah terpasang ───────────────────────────────────────
if grep -q "BANIWW_APIKEY_FULL" "$CONTROLLER_PATH" 2>/dev/null; then
    echo "⚠️  Proteksi sudah terpasang sebelumnya!"
    echo "ALREADY_INSTALLED"
    exit 0
fi

echo "Proteksi yang akan dipasang:"
echo "1️⃣  Block API key creation (super admin only)"
echo "2️⃣  Hide API key menu dari UI"
echo ""

# ── Konfirmasi ────────────────────────────────────────────────
if [ -z "$AUTOCONFIRM" ]; then
    read -p "Continue with FULL protection? (y/n): " confirm
else
    confirm="y"
    echo "Auto-confirm: y (non-interactive mode)"
fi

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "❌ Installation cancelled."
    exit 1
fi

echo ""
echo "════ STEP 1/2: Backend Protection ════"

# ── Backup controller ─────────────────────────────────────────
cp "$CONTROLLER_PATH" "$BACKUP_CONTROLLER"
echo "✅ Backup controller: $(basename $BACKUP_CONTROLLER)"

# ── Tulis controller baru ─────────────────────────────────────
cat > "$CONTROLLER_PATH" << 'PHPEOF'
<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Account;

use Illuminate\Support\Facades\Auth;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Models\ApiKey;
use Illuminate\Http\Request;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController as Controller;
use Pterodactyl\Http\Requests\Api\Client\Account\StoreApiKeyRequest;
use Pterodactyl\Transformers\Api\Client\ApiKeyTransformer;

/**
 * API Key Controller - Full Protection
 * BANIWW_APIKEY_FULL: Protected by @baniwwwXD
 */
class ClientApiController extends Controller
{
    public function index(Request $request): array
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            return ['data' => []];
        }

        return $this->fractal->collection($request->user()->apiKeys)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->toArray();
    }

    public function store(StoreApiKeyRequest $request): array
    {
        $user = Auth::user();

        if (!$user || $user->id !== 1) {
            throw new DisplayException(
                'ACCESS DENIED! API key creation is restricted to super administrators only. ' .
                'Contact your system administrator if you require API access. ' .
                '[Protected by @baniwwwXD]'
            );
        }

        if ($request->user()->apiKeys()->count() >= 5) {
            throw new DisplayException('Maximum API key limit (5) reached.');
        }

        $token = $request->user()->createToken(
            $request->input('description'),
            $request->input('allowed_ips')
        );

        return $this->fractal->item($token->accessToken)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->addMeta(['secret_token' => $token->plainTextToken])
            ->toArray();
    }

    public function delete(Request $request, string $identifier): JsonResponse
    {
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            throw new DisplayException('ACCESS DENIED! Only super administrator can delete API keys.');
        }

        $request->user()->apiKeys()
            ->where('key_type', ApiKey::TYPE_ACCOUNT)
            ->where('identifier', $identifier)
            ->delete();

        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }
}
PHPEOF

chmod 644 "$CONTROLLER_PATH"
echo "✅ Backend protection applied!"

echo ""
echo "════ STEP 2/2: UI Protection ════"

# ── Backup UI ─────────────────────────────────────────────────
cp "$UI_PATH" "$BACKUP_UI"
echo "✅ Backup UI: $(basename $BACKUP_UI)"

# ── Cek sudah dimodifikasi ────────────────────────────────────
if grep -q "BANIWW_HIDDEN" "$UI_PATH" 2>/dev/null; then
    echo "⚠️  UI sudah dimodifikasi sebelumnya, skip UI modification."
else
    # FIX: Hapus hanya baris yang spesifik mengandung api-keys / API Keys
    # Tidak pakai comment sed karena bisa corrupt JSX
    sed -i '/API Keys/d' "$UI_PATH"
    sed -i '/\/account\/api/d' "$UI_PATH"
    # Tandai sudah dimodifikasi
    sed -i '1s|^|// BANIWW_HIDDEN: API Key menu hidden by @baniwwwXD\n|' "$UI_PATH"
    echo "✅ UI modified!"

    # Verifikasi
    if grep -q "API Keys" "$UI_PATH"; then
        echo "⚠️  Warning: Masih ada referensi API Keys, cek manual."
    else
        echo "✅ Verifikasi UI: OK"
    fi
fi

# ── Build production ──────────────────────────────────────────
echo ""
echo "🔨 Building production assets (3-7 menit)..."
cd /var/www/pterodactyl || { echo "❌ Gagal masuk direktori pterodactyl"; exit 1; }

if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    if command -v yarn &> /dev/null; then
        yarn install --silent
    else
        npm install --silent
    fi
fi

if command -v yarn &> /dev/null; then
    yarn build:production
else
    npm run build:production
fi

BUILD_EXIT=$?
if [ $BUILD_EXIT -ne 0 ]; then
    echo "❌ Build gagal! Mengembalikan backup..."
    cp "$BACKUP_UI" "$UI_PATH"
    cp "$BACKUP_CONTROLLER" "$CONTROLLER_PATH"
    echo "✅ Backup dikembalikan. Tidak ada perubahan."
    exit 1
fi

echo "✅ Build complete!"

# ── Clear cache ───────────────────────────────────────────────
echo ""
echo "🔄 Clearing caches..."
php artisan config:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
php artisan view:clear > /dev/null 2>&1
php artisan route:clear > /dev/null 2>&1
php artisan queue:restart > /dev/null 2>&1
echo "✅ Cache cleared!"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ FULL API KEY PROTECTION INSTALLED!"
echo "════════════════════════════════════════════"
echo ""
echo "✅ Backend: Hanya user ID 1 bisa buat/lihat/hapus API key"
echo "✅ Frontend: Menu API Keys disembunyikan dari UI"
echo ""
echo "📁 Backup:"
echo "   Controller : $(basename $BACKUP_CONTROLLER)"
echo "   UI         : $(basename $BACKUP_UI)"
echo ""
echo "🔓 Restore:"
echo "   cp $BACKUP_CONTROLLER $CONTROLLER_PATH"
echo "   cp $BACKUP_UI $UI_PATH"
echo "   cd /var/www/pterodactyl && npm run build:production"
echo ""
echo "🎯 Security Level: MAXIMUM 🔥"
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
