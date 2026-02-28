#!/bin/bash

# Full API Key Protection Script
# By @baniwwwXD
# GitHub: github.com/Xbanz22

# ── Non-interactive mode ──────────────────────────────────────
if [ ! -t 0 ]; then AUTOCONFIRM="y"; else AUTOCONFIRM=""; fi

CONTROLLER_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/ApiKeyController.php"
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

# ── Cek root ──────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo "❌ Harus dijalankan sebagai root!"
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

echo "✅ Controller : $CONTROLLER_PATH"
echo "✅ UI file    : $UI_PATH"
echo ""

# ── Cek sudah terpasang ───────────────────────────────────────
if grep -q "BANIWW_APIKEY_FULL" "$CONTROLLER_PATH" 2>/dev/null; then
  echo "⚠️  Proteksi sudah terpasang sebelumnya!"
  echo "ALREADY_INSTALLED"
  exit 0
fi

# ── Konfirmasi ────────────────────────────────────────────────
if [ -z "$AUTOCONFIRM" ]; then
  read -p "Continue with FULL protection? (y/n): " confirm
else
  confirm="y"
  echo "Auto-confirm: y (non-interactive)"
fi
[ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { echo "❌ Cancelled."; exit 1; }

# ═══════════════════════════════════════════════════════════════
# STEP 1: Backend Protection
# ═══════════════════════════════════════════════════════════════
echo ""
echo "════ STEP 1/2: Backend Protection ════"

cp "$CONTROLLER_PATH" "$BACKUP_CONTROLLER"
echo "✅ Backup: $(basename $BACKUP_CONTROLLER)"

# Tulis controller — struktur SAMA PERSIS dengan asli, tambah proteksi
cat > "$CONTROLLER_PATH" << 'PHPEOF'
<?php

// BANIWW_APIKEY_FULL: Protected by @baniwwwXD

namespace Pterodactyl\Http\Controllers\Api\Client;

use Pterodactyl\Models\ApiKey;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Requests\Api\Client\ClientApiRequest;
use Pterodactyl\Transformers\Api\Client\ApiKeyTransformer;
use Pterodactyl\Http\Requests\Api\Client\Account\StoreApiKeyRequest;

class ApiKeyController extends ClientApiController
{
    /**
     * Returns all the API keys that exist for the given client.
     * PROTECTED: Only super admin (ID 1) can see keys.
     */
    public function index(ClientApiRequest $request): array
    {
        // Block non-super-admin
        if ($request->user()->id !== 1) {
            return $this->fractal->collection(ApiKey::query()->whereRaw('1 = 0')->get())
                ->transformWith($this->getTransformer(ApiKeyTransformer::class))
                ->toArray();
        }

        return $this->fractal->collection($request->user()->apiKeys)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->toArray();
    }

    /**
     * Store a new API key for a user's account.
     * PROTECTED: Only super admin (ID 1) can create keys.
     *
     * @throws DisplayException
     */
    public function store(StoreApiKeyRequest $request): array
    {
        // Block non-super-admin
        if ($request->user()->id !== 1) {
            throw new DisplayException(
                'ACCESS DENIED! API key creation is restricted to super administrators only. [Protected by @baniwwwXD]'
            );
        }

        if ($request->user()->apiKeys->count() >= 25) {
            throw new DisplayException('You have reached the account limit for number of API keys.');
        }

        $token = $request->user()->createToken(
            $request->input('description'),
            $request->input('allowed_ips')
        );

        Activity::event('user:api-key.create')
            ->subject($token->accessToken)
            ->property('identifier', $token->accessToken->identifier)
            ->log();

        return $this->fractal->item($token->accessToken)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->addMeta(['secret_token' => $token->plainTextToken])
            ->toArray();
    }

    /**
     * Deletes a given API key.
     * PROTECTED: Only super admin (ID 1) can delete keys.
     */
    public function delete(ClientApiRequest $request, string $identifier): JsonResponse
    {
        // Block non-super-admin
        if ($request->user()->id !== 1) {
            throw new DisplayException(
                'ACCESS DENIED! Only super administrator can delete API keys. [Protected by @baniwwwXD]'
            );
        }

        /** @var ApiKey $key */
        $key = $request->user()->apiKeys()
            ->where('key_type', ApiKey::TYPE_ACCOUNT)
            ->where('identifier', $identifier)
            ->firstOrFail();

        Activity::event('user:api-key.delete')
            ->property('identifier', $key->identifier)
            ->log();

        $key->delete();

        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }
}
PHPEOF

chmod 644 "$CONTROLLER_PATH"

# Verifikasi
if grep -q "BANIWW_APIKEY_FULL" "$CONTROLLER_PATH"; then
  echo "✅ Backend protection applied!"
else
  echo "❌ Gagal menulis controller! Mengembalikan backup..."
  cp "$BACKUP_CONTROLLER" "$CONTROLLER_PATH"
  exit 1
fi

# ═══════════════════════════════════════════════════════════════
# STEP 2: UI Protection
# ═══════════════════════════════════════════════════════════════
echo ""
echo "════ STEP 2/2: UI Protection ════"

cp "$UI_PATH" "$BACKUP_UI"
echo "✅ Backup UI: $(basename $BACKUP_UI)"

if grep -q "BANIWW_HIDDEN" "$UI_PATH" 2>/dev/null; then
  echo "⚠️  UI sudah dimodifikasi, skip."
else
  sed -i '/API Keys/d' "$UI_PATH"
  sed -i '/\/account\/api/d' "$UI_PATH"
  sed -i '1s|^|// BANIWW_HIDDEN: API Key menu hidden by @baniwwwXD\n|' "$UI_PATH"

  if grep -q "API Keys" "$UI_PATH"; then
    echo "⚠️  Warning: Masih ada referensi API Keys."
  else
    echo "✅ UI modified!"
  fi
fi

# ═══════════════════════════════════════════════════════════════
# STEP 3: Build Production
# ═══════════════════════════════════════════════════════════════
echo ""
echo "🔨 Building production assets (3-7 menit)..."
cd /var/www/pterodactyl || { echo "❌ Gagal masuk direktori"; exit 1; }

if [ ! -d "node_modules" ]; then
  echo "📦 Installing dependencies..."
  npm install --silent 2>/dev/null || yarn install --silent 2>/dev/null
fi

if command -v yarn &>/dev/null; then
  yarn build:production 2>&1
else
  npm run build:production 2>&1
fi

BUILD_EXIT=$?
if [ $BUILD_EXIT -ne 0 ]; then
  echo "❌ Build gagal! Mengembalikan semua backup..."
  cp "$BACKUP_CONTROLLER" "$CONTROLLER_PATH"
  cp "$BACKUP_UI" "$UI_PATH"
  echo "✅ Backup dikembalikan."
  exit 1
fi

echo "✅ Build complete!"

# ── Clear cache ───────────────────────────────────────────────
echo ""
echo "🔄 Clearing cache..."
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
echo "✅ Backend : Hanya user ID 1 bisa buat/lihat/hapus API key"
echo "✅ Frontend: Menu API Keys disembunyikan dari UI"
echo ""
echo "📁 Backup:"
echo "   Controller : $(basename $BACKUP_CONTROLLER)"
echo "   UI         : $(basename $BACKUP_UI)"
echo ""
echo "🔓 Untuk restore:"
echo "   cp $BACKUP_CONTROLLER $CONTROLLER_PATH"
echo "   cp $BACKUP_UI $UI_PATH"
echo "   cd /var/www/pterodactyl && npm run build:production"
echo ""
echo "🎯 Security Level: MAXIMUM 🔥"
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
