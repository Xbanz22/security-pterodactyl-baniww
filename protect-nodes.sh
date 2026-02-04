#!/bin/bash
REMOTE_PATH="/var/www/pterodactyl/app/Http/Controllers/Admin/Nodes/NodeController.php"
TIMESTAMP=$(date -u +"%Y-%m-%d-%H-%M-%S")
BACKUP_PATH="${REMOTE_PATH}.bak_${TIMESTAMP}"
clear
echo "════════════════════════════════════════════"
echo "  🛡️  PTERODACTYL NODE PROTECTION"
echo "════════════════════════════════════════════"
echo ""
if [ -f "$REMOTE_PATH" ]; then mv "$REMOTE_PATH" "$BACKUP_PATH"; echo "✅ Backup → $BACKUP_PATH"; fi
mkdir -p "$(dirname "$REMOTE_PATH")" && chmod 755 "$(dirname "$REMOTE_PATH")"
cat > "$REMOTE_PATH" << 'PHPEOF'
<?php
namespace Pterodactyl\Http\Controllers\Admin\Nodes;
use Illuminate\View\View;
use Illuminate\Http\Request;
use Pterodactyl\Models\Node;
use Spatie\QueryBuilder\QueryBuilder;
use Pterodactyl\Http\Controllers\Controller;
use Illuminate\Contracts\View\Factory as ViewFactory;
use Illuminate\Support\Facades\Auth;
class NodeController extends Controller {
    public function __construct(private ViewFactory $view) {}
    public function index(Request $request): View {
        $user = Auth::user();
        if (!$user || $user->id !== 1) { abort(403, '🔒 GA USAH RUSUH DISINI TOLOL PROTECT BY @baniwwwXD'); }
        $nodes = QueryBuilder::for(Node::query()->with('location')->withCount('servers'))->allowedFilters(['uuid', 'name'])->allowedSorts(['id'])->paginate(25);
        return $this->view->make('admin.nodes.index', ['nodes' => $nodes]);
    }
}
PHPEOF
chmod 644 "$REMOTE_PATH"
echo -e "\n✅ Node Protection installed!\n"
