#!/bin/bash
REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"
clear
echo "════════════════════════════════════════════"
echo "  🛡️  SERVER CONTROLLER PROTECTION"
echo "════════════════════════════════════════════"
if [ -f "$REMOTE_PATH" ]; then mv "$REMOTE_PATH" "$BACKUP_PATH"; echo "✅ Backup → $BACKUP_PATH"; fi
mkdir -p "$(dirname "$REMOTE_PATH")" && chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" << 'PHPEOF'
<?php
namespace Pterodactyl\Http\Controllers\Api\Client\Servers;
use Illuminate\Support\Facades\Auth;
use Pterodactyl\Models\Server;
use Pterodactyl\Transformers\Api\Client\ServerTransformer;
use Pterodactyl\Services\Servers\GetUserPermissionsService;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Pterodactyl\Http\Requests\Api\Client\Servers\GetServerRequest;
class ServerController extends ClientApiController {
    public function __construct(private GetUserPermissionsService $permissionsService) { parent::__construct(); }
    public function index(GetServerRequest $request, Server $server): array {
        $authUser = Auth::user();
        if ($authUser->id !== 1 && (int) $server->owner_id !== (int) $authUser->id) {
            abort(403, '🔒 PUSING ANJING JANGAN INTIP SERVER ORANG PROTECT BY @baniwwwXD');
        }
        return $this->fractal->item($server)->transformWith($this->getTransformer(ServerTransformer::class))->addMeta(['is_server_owner' => $request->user()->id === $server->owner_id, 'user_permissions' => $this->permissionsService->handle($server, $request->user())])->toArray();
    }
}
PHPEOF
chmod 644 "$REMOTE_PATH"
echo -e "\n✅ Server Controller Protection installed!\n"
