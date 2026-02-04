#!/bin/bash
REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Settings/IndexController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"
clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL SETTINGS PROTECTION"
echo "════════════════════════════════════════════"
if [ -f "$REMOTE_PATH" ]; then mv "$REMOTE_PATH" "$BACKUP_PATH"; echo "✅ Backup → $BACKUP_PATH"; fi
mkdir -p "$(dirname "$REMOTE_PATH")" && chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" << 'PHPEOF'
<?php
namespace Pterodactyl\Http\Controllers\Admin\Settings;
use Illuminate\View\View;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Prologue\Alerts\AlertsMessageBag;
use Illuminate\Contracts\Console\Kernel;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Traits\Helpers\AvailableLanguages;
use Pterodactyl\Services\Helpers\SoftwareVersionService;
use Pterodactyl\Contracts\Repository\SettingsRepositoryInterface;
use Pterodactyl\Http\Requests\Admin\Settings\BaseSettingsFormRequest;
class IndexController extends Controller {
    use AvailableLanguages;
    public function __construct(private AlertsMessageBag $alert, private Kernel $kernel, private SettingsRepositoryInterface $settings, private SoftwareVersionService $versionService, private ViewFactory $view) {}
    public function index(): View {
        $user = Auth::user();
        if (!$user || $user->id !== 1) { abort(403, '🔒 GA USAH RUSUH DISINI TOLOL PROTECT BY @baniwwwXD'); }
        return $this->view->make('admin.settings.index', ['version' => $this->versionService, 'languages' => $this->getAvailableLanguages(true)]);
    }
    public function update(BaseSettingsFormRequest $request): RedirectResponse {
        $user = Auth::user();
        if (!$user || $user->id !== 1) { abort(403, '🔒 GA USAH RUSUH DISINI TOLOL PROTECT BY @baniwwwXD'); }
        foreach ($request->normalize() as $key => $value) { $this->settings->set('settings::' . $key, $value); }
        $this->kernel->call('queue:restart');
        $this->alert->success('Panel settings updated and queue restarted.')->flash();
        return redirect()->route('admin.settings');
    }
}
PHPEOF
chmod 644 "$REMOTE_PATH"
echo -e "\n✅ Settings Protection installed!\n"
