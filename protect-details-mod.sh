#!/bin/bash
REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/DetailsModificationService.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"
clear
echo "════════════════════════════════════════════"
echo "  🛡️  DETAILS MODIFICATION PROTECTION"
echo "════════════════════════════════════════════"
if [ -f "$REMOTE_PATH" ]; then mv "$REMOTE_PATH" "$BACKUP_PATH"; echo "✅ Backup → $BACKUP_PATH"; fi
mkdir -p "$(dirname "$REMOTE_PATH")" && chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" << 'PHPEOF'
<?php
namespace Pterodactyl\Services\Servers;
use Illuminate\Support\Arr;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Auth;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Traits\Services\ReturnsUpdatedModels;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;
class DetailsModificationService {
    use ReturnsUpdatedModels;
    public function __construct(private ConnectionInterface $connection, private DaemonServerRepository $serverRepository) {}
    public function handle(Server $server, array $data): Server {
        $user = Auth::user();
        if (!$user || $user->id !== 1) { abort(403, '🔒 PUNYA GITU LOH KONTOL JANGAN DIUBAH UBAH PROTECT BY @baniwwwXD'); }
        return $this->connection->transaction(function () use ($data, $server) {
            $owner = $server->owner_id;
            $server->forceFill(['external_id' => Arr::get($data, 'external_id'), 'owner_id' => Arr::get($data, 'owner_id'), 'name' => Arr::get($data, 'name'), 'description' => Arr::get($data, 'description') ?? ''])->saveOrFail();
            if ($server->owner_id !== $owner) { try { $this->serverRepository->setServer($server)->revokeUserJTI($owner); } catch (DaemonConnectionException $exception) {} }
            return $server;
        });
    }
}
PHPEOF
chmod 644 "$REMOTE_PATH"
echo -e "\n✅ Details Modification Protection installed!\n"
