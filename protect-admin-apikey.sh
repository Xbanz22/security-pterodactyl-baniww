#!/bin/bash

# Admin API Key Protection Script
# By @baniwwwXD
# GitHub: github.com/Xbanz22

# ── Non-interactive mode ──────────────────────────────────────
if [ ! -t 0 ]; then AUTOCONFIRM="y"; else AUTOCONFIRM=""; fi

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/ApiController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"

clear 2>/dev/null || true
echo "════════════════════════════════════════════"
echo "  🔐 PTERODACTYL ADMIN API KEY PROTECTION"
echo "  👑 By @baniwwwXD"
echo "  🌐 github.com/Xbanz22"
echo "════════════════════════════════════════════"
echo ""
echo "🚀 Memasang proteksi Admin API Key..."
echo ""

# ── Cek root ──────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
  echo "❌ Harus dijalankan sebagai root!"
  exit 1
fi

# ── Cek sudah terpasang ───────────────────────────────────────
if grep -q "BANIWW_ADMIN_APIKEY" "$REMOTE_PATH" 2>/dev/null; then
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

// BANIWW_ADMIN_APIKEY: Protected by @baniwwwXD

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Pterodactyl\Models\ApiKey;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Pterodactyl\Services\Acl\Api\AdminAcl;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Api\KeyCreationService;
use Pterodactyl\Http\Requests\Admin\Api\StoreApplicationApiKeyRequest;

class ApiController extends Controller
{
    /**
     * ApiController constructor.
     */
    public function __construct(
        private AlertsMessageBag $alert,
        private KeyCreationService $keyCreationService,
    ) {
    }

    /**
     * 🔒 Admin API Key Protection by @baniwwwXD
     * Hanya super admin (ID 1) yang bisa akses
     */
    private function checkAdminApiAccess(Request $request): void
    {
        // Admin (user id = 1) bebas akses
        if ($request->user()->id === 1) {
            return;
        }

        // Blokir semua user selain ID 1
        abort(403, '🔒 Access Denied - Admin API Key Protection By @baniwwwXD');
    }

    /**
     * Render view showing all of a user's application API keys.
     */
    public function index(Request $request): View
    {
        $this->checkAdminApiAccess($request);

        return view('admin.api.index', [
            'keys' => ApiKey::query()->where('key_type', ApiKey::TYPE_APPLICATION)->get(),
        ]);
    }

    /**
     * Render view allowing an admin to create a new application API key.
     *
     * @throws \ReflectionException
     */
    public function create(): View
    {
        $this->checkAdminApiAccess(request());

        $resources = AdminAcl::getResourceList();
        sort($resources);

        return view('admin.api.new', [
            'resources' => $resources,
            'permissions' => [
                'r' => AdminAcl::READ,
                'rw' => AdminAcl::READ | AdminAcl::WRITE,
                'n' => AdminAcl::NONE,
            ],
        ]);
    }

    /**
     * Store the new key and redirect the user back to the application key listing.
     *
     * @throws \Pterodactyl\Exceptions\Model\DataValidationException
     */
    public function store(StoreApplicationApiKeyRequest $request): RedirectResponse
    {
        $this->checkAdminApiAccess($request);

        $this->keyCreationService->setKeyType(ApiKey::TYPE_APPLICATION)->handle([
            'memo' => $request->input('memo'),
            'user_id' => $request->user()->id,
        ], $request->getKeyPermissions());

        $this->alert->success('A new application API key has been generated for your account.')->flash();

        return redirect()->route('admin.api.index');
    }

    /**
     * Delete an application API key from the database.
     */
    public function delete(Request $request, string $identifier): Response
    {
        $this->checkAdminApiAccess($request);

        ApiKey::query()
            ->where('key_type', ApiKey::TYPE_APPLICATION)
            ->where('identifier', $identifier)
            ->delete();

        return response('', 204);
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
echo "   • Admin (ID 1) → Full Access ke Application API"
echo "   • User biasa   → 403 Access Denied"
echo ""
echo "💡 Untuk uninstall, restore dari backup:"
echo "   mv $BACKUP_PATH $REMOTE_PATH"
echo ""
echo "🔥 By @baniwwwXD"
echo "════════════════════════════════════════════"
