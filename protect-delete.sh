#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Services/Servers/ServerDeletionService.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL ANTI-DELETE PROTECTION"
echo "════════════════════════════════════════════"
echo ""
echo "📦 Script by: @baniwwwXD"
echo "🌐 GitHub: github.com/Xbanzz22"
echo ""
echo "🚀 Memasang proteksi Anti Delete Server..."
echo ""

if [ -f "$REMOTE_PATH" ]; then
  mv "$REMOTE_PATH" "$BACKUP_PATH"
  echo "✅ Backup file lama → $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"
chmod 755 "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'EOF'
<?php

namespace Pterodactyl\Services\Servers;

use Illuminate\Support\Facades\Auth;
use Pterodactyl\Exceptions\DisplayException;
use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Illuminate\Support\Facades\Log;
use Illuminate\Database\ConnectionInterface;
use Pterodactyl\Repositories\Wings\DaemonServerRepository;
use Pterodactyl\Services\Databases\DatabaseManagementService;
use Pterodactyl\Exceptions\Http\Connection\DaemonConnectionException;

class ServerDeletionService
{
    protected bool $force = false;

    /**
     * ServerDeletionService constructor.
     */
    public function __construct(
        private ConnectionInterface $connection,
        private DaemonServerRepository $daemonServerRepository,
        private DatabaseManagementService $databaseManagementService
    ) {
    }

    /**
     * Set if the server should be forcibly deleted from the panel (ignoring daemon errors) or not.
     */
    public function withForce(bool $bool = true): self
    {
        $this->force = $bool;
        return $this;
    }

    /**
     * Delete a server from the panel and remove any associated databases from hosts.
     *
     * @throws \Throwable
     * @throws \Pterodactyl\Exceptions\DisplayException
     */
    public function handle(Server $server): void
    {
        $user = Auth::user();

        // 🔒 Anti-Delete Protection
        // Hanya admin (ID 1) yang bisa delete server siapa saja
        // User biasa hanya bisa delete server miliknya sendiri
        if ($user) {
            if ($user->id !== 1) {
                // Deteksi owner dengan fallback
                $ownerId = $server->owner_id
                    ?? $server->user_id
                    ?? ($server->owner?->id ?? null)
                    ?? ($server->user?->id ?? null);

                if ($ownerId === null) {
                    throw new DisplayException('🔒 Access Denied - Server owner information unavailable');
                }

                if ($ownerId !== $user->id) {
                    throw new DisplayException('🔒 Access Denied - Lu Mau Ngapain Kntol, Balik Sana Protect By @baniwwwXD');
                }
            }
        }

        try {
            $this->daemonServerRepository->setServer($server)->delete();
        } catch (DaemonConnectionException $exception) {
            if (!$this->force && $exception->getStatusCode() !== Response::HTTP_NOT_FOUND) {
                throw $exception;
            }

            Log::warning($exception);
        }

        $this->connection->transaction(function () use ($server) {
            foreach ($server->databases as $database) {
                try {
                    $this->databaseManagementService->delete($database);
                } catch (\Exception $exception) {
                    if (!$this->force) {
                        throw $exception;
                    }

                    $database->delete();
                    Log::warning($exception);
                }
            }

            $server->delete();
        });
    }
}
EOF

chmod 644 "$REMOTE_PATH"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ PROTEKSI BERHASIL DIPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "📂 Lokasi: $REMOTE_PATH"
echo "🗂️ Backup: $BACKUP_PATH"
echo ""
echo "🔒 Aturan Akses:"
echo "   • Admin (ID 1) → Bisa delete semua server"
echo "   • User biasa → Hanya bisa delete server sendiri"
echo ""
echo "💡 Untuk uninstall, restore dari backup:"
echo "   mv $BACKUP_PATH $REMOTE_PATH"
echo ""
echo "════════════════════════════════════════════"
