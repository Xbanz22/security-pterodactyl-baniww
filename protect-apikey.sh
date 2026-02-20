#!/bin/bash

# Protection Script: API Key Creation Protection
# By @baniwwwXD
# GitHub: github.com/Xbanz22
# Repo: security-pterodactyl-baniww

# This script protects API key creation - only super admin (ID 1) can create API keys

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Account/ClientApiController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

clear
echo "════════════════════════════════════════════"
echo "  🔐 API KEY CREATION PROTECTION"
echo "  👑 By @baniwwwXD"
echo "  🌐 github.com/Xbanz22"
echo "════════════════════════════════════════════"
echo ""
echo "This protection blocks non-super admins from"
echo "creating API keys to prevent bypass exploits."
echo ""
echo "⚠️  WARNING: This will restrict API key creation"
echo "    to super admin (ID 1) ONLY!"
echo ""
read -p "Continue? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "❌ Installation cancelled."
    exit 1
fi

echo ""
echo "📦 Backing up original file..."
if [ -f "$REMOTE_PATH" ]; then
    cp "$REMOTE_PATH" "$BACKUP_PATH"
    echo "✅ Backup created: $(basename $BACKUP_PATH)"
else
    echo "❌ Error: File not found at $REMOTE_PATH"
    exit 1
fi

echo ""
echo "🔧 Applying protection..."

cat > "$REMOTE_PATH" << 'EOF'
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
 * API Key Controller - Protected by @baniwwwXD
 * Only super admin (ID 1) can create API keys
 */
class ClientApiController extends Controller
{
    /**
     * Return all of the API keys that exist for the given client.
     */
    public function index(Request $request): array
    {
        return $this->fractal->collection($request->user()->apiKeys)
            ->transformWith($this->getTransformer(ApiKeyTransformer::class))
            ->toArray();
    }

    /**
     * Store a new API key for a user's account.
     * 
     * 🔒 PROTECTION: Only super admin (ID 1) can create API keys
     * This prevents API exploitation and bypass attacks
     */
    public function store(StoreApiKeyRequest $request): array
    {
        // 🛡️ SUPER ADMIN CHECK - By @baniwwwXD
        $user = Auth::user();
        
        if (!$user || $user->id !== 1) {
            throw new DisplayException(
                '🔒 API KEY CREATION RESTRICTED! ' .
                'Only super administrator can create API keys. ' .
                'Contact your system administrator for API access. ' .
                '[@baniwwwXD Protection]'
            );
        }

        if ($request->user()->apiKeys()->count() >= 5) {
            throw new DisplayException('You have reached the account limit for number of API keys.');
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

    /**
     * Deletes a given API key.
     */
    public function delete(Request $request, string $identifier): JsonResponse
    {
        $request->user()->apiKeys()
            ->where('key_type', ApiKey::TYPE_ACCOUNT)
            ->where('identifier', $identifier)
            ->delete();

        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }
}
EOF

chmod 644 "$REMOTE_PATH"

echo "✅ Protection applied successfully!"
echo ""
echo "🔄 Clearing Laravel cache..."
cd /var/www/pterodactyl
php artisan config:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
php artisan view:clear > /dev/null 2>&1

echo "✅ Cache cleared!"
echo ""
echo "════════════════════════════════════════════"
echo "  ✅ API KEY PROTECTION INSTALLED"
echo "════════════════════════════════════════════"
echo ""
echo "📊 Protection Details:"
echo "  • Only user ID 1 can create API keys"
echo "  • Non-super admins will see error message"
echo "  • Prevents API exploitation attacks"
echo ""
echo "💾 Backup saved at:"
echo "  $(basename $BACKUP_PATH)"
echo ""
echo "🔓 To restore original file:"
echo "  mv $BACKUP_PATH $REMOTE_PATH"
echo "  cd /var/www/pterodactyl && php artisan cache:clear"
echo ""
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
EOF

chmod +x protect-apikey.sh

echo "✅ protect-apikey.sh created successfully!"
