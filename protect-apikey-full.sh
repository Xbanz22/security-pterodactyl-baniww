#!/bin/bash

# Full API Key Protection Script
# By @baniwwwXD
# GitHub: github.com/Xbanz22

# ── Non-interactive mode ──────────────────────────────────────
if [ ! -t 0 ]; then AUTOCONFIRM="y"; else AUTOCONFIRM=""; fi

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/ApiKeyController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

clear 2>/dev/null || true
echo "════════════════════════════════════════════"
echo "  🔐 PTERODACTYL API KEY PROTECTION"
echo "  👑 By @baniwwwXD"
echo "  🌐 github.com/Xbanz22"
echo "════════════════════════════════════════════"
echo ""
echo "🚀 Memasang proteksi API Key..."
echo ""

# ── Cek root ──────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo "❌ Harus dijalankan sebagai root!"
  exit 1
fi

# ── Cek sudah terpasang ───────────────────────────────────────
if grep -q "BANIWW_APIKEY_FULL" "$REMOTE_PATH" 2>/dev/null; then
  echo "⚠️  Proteksi sudah terpasang sebelumnya!"
  echo "ALREADY_INSTALLED"
  exit 0
fi

# ── Backup ────────────────────────────────────────────────────
if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "✅ Backup file lama → $(basename $BACKUP_PATH)"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

# ── Tulis controller baru ─────────────────────────────────────
cat > "$REMOTE_PATH" << 'EOF'
<?php

// BANIWW_APIKEY_FULL: Protected by @baniwwwXD

namespace Pterodactyl\Http\Controllers\Api\Client;

use Pterodactyl\Models\ApiKey;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Http\Requests\Api\Client\ClientApiRequest;
use Pterodactyl\Transformers\Api\Client\ApiKeyTransformer;
use Pterodactyl\Http\Requests\Api\Client\Account\StoreApiKeyRequest;

class ApiKeyController extends ClientApiController
{
    /**
     * 🔒 API Key Protection by @baniwwwXD
     * Hanya super admin (ID 1) yang bisa akses API key
     */
    private function checkApiKeyAccess($request): void
    {
        $user = $request->user();

        // Admin (user id = 1) bebas akses
        if ($user->id === 1) {
            return;
        }

        // Blokir semua user selain ID 1
        abort(403, '🔒 Access Denied - API Key Protection By @baniwwwXD');
    }

    /**
     * Returns all the API keys that exist for the given client.
     */
    public function index(ClientApiRequest $request): array
    {
        $this->checkApiKeyAccess($request);

        return $this->fractal->collection($request->user()->apiKeys)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->toArray();
    }

    /**
     * Store a new API key for a user's account.
     *
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function store(StoreApiKeyRequest $request): array
    {
        $this->checkApiKeyAccess($request);

        if ($request->user()->apiKeys->count() >= 25) {
            throw new \Pterodactyl\Exceptions\DisplayException(
                'You have reached the account limit for number of API keys.'
            );
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
     */
    public function delete(ClientApiRequest $request, string $identifier): JsonResponse
    {
        $this->checkApiKeyAccess($request);

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
EOF

chmod 644 "$REMOTE_PATH"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ PROTEKSI BERHASIL DIPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "📂 Lokasi : $REMOTE_PATH"
echo "🗂️  Backup : $(basename $BACKUP_PATH)"
echo ""
echo "🔒 Aturan Akses:"
echo "   • Admin (ID 1) → Full Access ke API Key"
echo "   • User biasa   → 403 Access Denied"
echo ""
echo "💡 Untuk uninstall, restore dari backup:"
echo "   mv $BACKUP_PATH $REMOTE_PATH"
echo ""
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
