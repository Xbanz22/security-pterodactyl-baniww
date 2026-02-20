#!/bin/bash

# Full API Key Protection Script
# By @baniwwwXD
# GitHub: github.com/Xbanz22
# Repo: security-pterodactyl-baniww

# This script applies BOTH protections:
# 1. Restrict API key creation to super admin only
# 2. Hide API key menu from UI

clear
echo "════════════════════════════════════════════"
echo "  🔐 FULL API KEY PROTECTION"
echo "  👑 By @baniwwwXD"
echo "  🌐 github.com/Xbanz22"
echo "════════════════════════════════════════════"
echo ""
echo "This script will apply TWO protections:"
echo ""
echo "1️⃣  Block API key creation (super admin only)"
echo "2️⃣  Hide API key menu from UI"
echo ""
echo "⚠️  WARNING: This is the STRONGEST protection!"
echo "    Regular users will NOT see or access API keys."
echo ""
read -p "Continue with FULL protection? (y/n): " confirm

if [ "$confirm" != "y" ]; then
    echo "❌ Installation cancelled."
    exit 1
fi

echo ""
echo "════════════════════════════════════════════"
echo "  STEP 1/2: API Key Creation Protection"
echo "════════════════════════════════════════════"
echo ""

CONTROLLER_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Account/ClientApiController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_CONTROLLER="${CONTROLLER_PATH}.bak_${TIMESTAMP}"

echo "📦 Backing up controller..."
cp "$CONTROLLER_PATH" "$BACKUP_CONTROLLER"
echo "✅ Backup: $(basename $BACKUP_CONTROLLER)"

echo ""
echo "🔧 Applying backend protection..."

cat > "$CONTROLLER_PATH" << 'EOFCONTROLLER'
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
 * API Key Controller - Full Protection by @baniwwwXD
 * Only super admin (ID 1) can create API keys
 */
class ClientApiController extends Controller
{
    public function index(Request $request): array
    {
        // Check if user is super admin
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            // Return empty array for non-super admins
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
                '🔒 ACCESS DENIED! API key creation is restricted to super administrators only. ' .
                'This security measure prevents unauthorized API access and potential exploits. ' .
                'Contact your system administrator if you require API access. [Protected by @baniwwwXD]'
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
        // Only super admin can delete API keys
        $user = Auth::user();
        if (!$user || $user->id !== 1) {
            throw new DisplayException('🔒 ACCESS DENIED! Only super administrator can delete API keys.');
        }

        $request->user()->apiKeys()
            ->where('key_type', ApiKey::TYPE_ACCOUNT)
            ->where('identifier', $identifier)
            ->delete();

        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }
}
EOFCONTROLLER

chmod 644 "$CONTROLLER_PATH"
echo "✅ Backend protection applied!"

echo ""
echo "════════════════════════════════════════════"
echo "  STEP 2/2: Hide API Key Menu from UI"
echo "════════════════════════════════════════════"
echo ""

UI_PATH="/var/www/pterodactyl/resources/scripts/components/dashboard/AccountOverviewContainer.tsx"
BACKUP_UI="${UI_PATH}.bak_${TIMESTAMP}"

echo "📦 Backing up UI file..."
cp "$UI_PATH" "$BACKUP_UI"
echo "✅ Backup: $(basename $BACKUP_UI)"

echo ""
echo "🔧 Modifying UI..."

# Comment out API Key nav link
sed -i 's|<NavLink to="/account/api">|{/* <NavLink to="/account/api">|g' "$UI_PATH"
sed -i 's|</NavLink>|</NavLink> */}|g' "$UI_PATH"

# Or completely remove it
sed -i '/API Keys/d' "$UI_PATH"
sed -i '/\/account\/api/d' "$UI_PATH"

echo "✅ UI modified!"

echo ""
echo "🔨 Building production assets..."
cd /var/www/pterodactyl

# Check for yarn or npm
if command -v yarn &> /dev/null; then
    echo "📦 Using Yarn..."
    yarn install
    yarn build:production
else
    echo "📦 Using NPM..."
    npm install
    npm run build:production
fi

echo "✅ Build complete!"

echo ""
echo "🔄 Clearing caches..."
php artisan config:clear > /dev/null 2>&1
php artisan cache:clear > /dev/null 2>&1
php artisan view:clear > /dev/null 2>&1
php artisan route:clear > /dev/null 2>&1

echo "✅ Caches cleared!"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ FULL API KEY PROTECTION INSTALLED!"
echo "════════════════════════════════════════════"
echo ""
echo "🔒 Protection Summary:"
echo ""
echo "✅ Backend Protection:"
echo "   • Only user ID 1 can create API keys"
echo "   • Only user ID 1 can view existing keys"
echo "   • Only user ID 1 can delete keys"
echo "   • Non-super admins see: ACCESS DENIED"
echo ""
echo "✅ Frontend Protection:"
echo "   • API Key menu hidden from UI"
echo "   • Navigation link removed"
echo "   • Regular users cannot access"
echo ""
echo "💡 Super Admin Access:"
echo "   • Direct URL: /account/api (if needed)"
echo "   • Only works for user ID 1"
echo ""
echo "📁 Backups Created:"
echo "   • Controller: $(basename $BACKUP_CONTROLLER)"
echo "   • UI: $(basename $BACKUP_UI)"
echo ""
echo "🔓 To Restore Original:"
echo "   mv $BACKUP_CONTROLLER $CONTROLLER_PATH"
echo "   mv $BACKUP_UI $UI_PATH"
echo "   cd /var/www/pterodactyl"
echo "   npm run build:production"
echo "   php artisan cache:clear"
echo ""
echo "🎯 Security Level: MAXIMUM 🔥"
echo ""
echo "🗿 By @baniwwwXD"
echo "════════════════════════════════════════════"
