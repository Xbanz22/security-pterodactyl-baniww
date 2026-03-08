#!/bin/bash

REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"
MARKER="BANIWW_USER"

clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL USER PROTECTION"
echo "  📦 by @baniwwwXD | baniwwDeveloper"
echo "════════════════════════════════════════════"
echo ""

# Cek sudah terpasang
if grep -q "$MARKER" "$REMOTE_PATH" 2>/dev/null; then
  echo "✅ ALREADY_INSTALLED — Proteksi sudah terpasang!"
  exit 0
fi

# Backup
if [ -f "$REMOTE_PATH" ]; then
  cp "$REMOTE_PATH" "$BACKUP_PATH"
  echo "✅ Backup → $BACKUP_PATH"
fi

mkdir -p "$(dirname "$REMOTE_PATH")"

cat > "$REMOTE_PATH" << 'PHPEOF'
<?php
// BANIWW_USER

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\User;
use Pterodactyl\Models\Model;
use Illuminate\Support\Collection;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Spatie\QueryBuilder\QueryBuilder;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Exceptions\DisplayException;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\Translation\Translator;
use Pterodactyl\Services\Users\UserUpdateService;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Users\UserCreationService;
use Pterodactyl\Services\Users\UserDeletionService;
use Pterodactyl\Http\Requests\Admin\UserFormRequest;
use Pterodactyl\Http\Requests\Admin\NewUserFormRequest;
use Pterodactyl\Contracts\Repository\UserRepositoryInterface;

class UserController extends Controller
{
    use AvailableLanguages;

    public function __construct(
        protected AlertsMessageBag $alert,
        protected UserCreationService $creationService,
        protected UserDeletionService $deletionService,
        protected Translator $translator,
        protected UserUpdateService $updateService,
        protected UserRepositoryInterface $repository,
        protected ViewFactory $view
    ) {}

    public function index(Request $request): View
    {
        $users = QueryBuilder::for(
            User::query()->select('users.*')
                ->selectRaw('COUNT(DISTINCT(subusers.id)) as subuser_of_count')
                ->selectRaw('COUNT(DISTINCT(servers.id)) as servers_count')
                ->leftJoin('subusers', 'subusers.user_id', '=', 'users.id')
                ->leftJoin('servers', 'servers.owner_id', '=', 'users.id')
                ->groupBy('users.id')
        )
            ->allowedFilters(['username', 'email', 'uuid'])
            ->allowedSorts(['id', 'uuid'])
            ->paginate(50);

        return $this->view->make('admin.users.index', ['users' => $users]);
    }

    public function create(): View
    {
        return $this->view->make('admin.users.new', [
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    public function view(User $user): View
    {
        return $this->view->make('admin.users.view', [
            'user' => $user,
            'languages' => $this->getAvailableLanguages(true),
        ]);
    }

    public function delete(Request $request, User $user): RedirectResponse
    {
        // 🔒 BANIWW: Only ID 1 can delete users
        if ($request->user()->id !== 1) {
            throw new DisplayException('🔒 Akses ditolak! Hanya Super Admin yang bisa menghapus user.');
        }

        if ($request->user()->id === $user->id) {
            throw new DisplayException($this->translator->get('admin/user.exceptions.user_has_servers'));
        }

        $this->deletionService->handle($user);
        return redirect()->route('admin.users');
    }

    public function store(NewUserFormRequest $request): RedirectResponse
    {
        // 🔒 BANIWW: Only ID 1 can create admin users
        $data = $request->normalize();

        if ($request->user()->id !== 1) {
            // Force root_admin = false untuk selain ID 1
            $data['root_admin'] = false;
        }

        // 🔒 BANIWW: Blokir total kalau selain ID 1 coba buat admin
        if (isset($data['root_admin']) && $data['root_admin'] && $request->user()->id !== 1) {
            throw new DisplayException('🔒 Akses ditolak! Hanya Super Admin yang bisa membuat akun Admin.');
        }

        $user = $this->creationService->handle($data);
        $this->alert->success($this->translator->get('admin/user.notices.account_created'))->flash();

        return redirect()->route('admin.users.view', $user->id);
    }

    public function update(UserFormRequest $request, User $user): RedirectResponse
    {
        $data = $request->normalize();

        // 🔒 BANIWW: Blokir promote admin selain ID 1
        if ($request->user()->id !== 1) {
            // Tidak boleh promote jadi admin
            if (!empty($data['root_admin'])) {
                throw new DisplayException('🔒 Akses ditolak! Hanya Super Admin yang bisa mengubah status Admin.');
            }

            // Tidak boleh edit field sensitif user lain
            $restrictedFields = ['email', 'password', 'root_admin'];
            foreach ($restrictedFields as $field) {
                if ($request->filled($field) && $user->id !== $request->user()->id) {
                    throw new DisplayException('🔒 Akses ditolak! Kamu tidak bisa mengubah data user lain.');
                }
            }

            // Tidak boleh edit user yang sudah admin
            if ($user->root_admin) {
                throw new DisplayException('🔒 Akses ditolak! Kamu tidak bisa mengedit akun Admin.');
            }

            // Paksa root_admin tetap false
            $data['root_admin'] = false;
        }

        $this->updateService
            ->setUserLevel(User::USER_LEVEL_ADMIN)
            ->handle($user, $data);

        $this->alert->success(trans('admin/user.notices.account_updated'))->flash();
        return redirect()->route('admin.users.view', $user->id);
    }

    public function json(Request $request): Model|Collection
    {
        $users = QueryBuilder::for(User::query())->allowedFilters(['email'])->paginate(25);

        if ($request->query('user_id')) {
            $user = User::query()->findOrFail($request->input('user_id'));
            $user->md5 = md5(strtolower($user->email));
            return $user;
        }

        return $users->map(function ($item) {
            $item->md5 = md5(strtolower($item->email));
            return $item;
        });
    }
}
PHPEOF

chmod 644 "$REMOTE_PATH"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ PROTEKSI BERHASIL DIPASANG!"
echo "════════════════════════════════════════════"
echo ""
echo "📂 File : $REMOTE_PATH"
echo "🗂️ Backup: $BACKUP_PATH"
echo ""
echo "🔒 Aturan Proteksi:"
echo "   ✅ ID 1  → Full control"
echo "   ❌ Admin lain → Tidak bisa:"
echo "      • Buat/promote user jadi Admin"
echo "      • Edit/hapus user lain"
echo "      • Ubah password/email user lain"
echo ""
echo "════════════════════════════════════════════"
