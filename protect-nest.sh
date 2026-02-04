#!/bin/bash
REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Nests/NestController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"
clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL NEST PROTECTION"
echo "════════════════════════════════════════════"
echo ""
echo "📦 Script by: @baniwwwXD"
echo "🌐 GitHub: github.com/Xbanzz22"
echo ""
if [ -f "$REMOTE_PATH" ]; then mv "$REMOTE_PATH" "$BACKUP_PATH"; echo "✅ Backup → $BACKUP_PATH"; fi
mkdir -p "$(dirname "$REMOTE_PATH")" && chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" << 'PHPEOF'
<?php
namespace Pterodactyl\Http\Controllers\Admin\Nests;
use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Nests\NestUpdateService;
use Pterodactyl\Services\Nests\NestCreationService;
use Pterodactyl\Services\Nests\NestDeletionService;
use Pterodactyl\Contracts\Repository\NestRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Nest\StoreNestFormRequest;
use Illuminate\Support\Facades\Auth;
class NestController extends Controller {
    public function __construct(protected AlertsMessageBag $alert, protected NestCreationService $nestCreationService, protected NestDeletionService $nestDeletionService, protected NestRepositoryInterface $repository, protected NestUpdateService $nestUpdateService, protected ViewFactory $view) {}
    public function index(): View {
        $user = Auth::user();
        if (!$user || $user->id !== 1) { abort(403, '🔒 BOCAH TOLOL MAU NGAPAIN DISINI PROTECT BY @baniwwwXD'); }
        return $this->view->make('admin.nests.index', ['nests' => $this->repository->getWithCounts()]);
    }
    public function create(): View { return $this->view->make('admin.nests.new'); }
    public function store(StoreNestFormRequest $request): RedirectResponse {
        $nest = $this->nestCreationService->handle($request->normalize());
        $this->alert->success(trans('admin/nests.notices.created', ['name' => htmlspecialchars($nest->name)]))->flash();
        return redirect()->route('admin.nests.view', $nest->id);
    }
    public function view(int $nest): View { return $this->view->make('admin.nests.view', ['nest' => $this->repository->getWithEggServers($nest)]); }
    public function update(StoreNestFormRequest $request, int $nest): RedirectResponse {
        $this->nestUpdateService->handle($nest, $request->normalize());
        $this->alert->success(trans('admin/nests.notices.updated'))->flash();
        return redirect()->route('admin.nests.view', $nest);
    }
    public function destroy(int $nest): RedirectResponse {
        $this->nestDeletionService->handle($nest);
        $this->alert->success(trans('admin/nests.notices.deleted'))->flash();
        return redirect()->route('admin.nests');
    }
}
PHPEOF
chmod 644 "$REMOTE_PATH"
echo -e "\n✅ Nest Protection installed!\n📂 $REMOTE_PATH\n🗂️ $BACKUP_PATH\n"
