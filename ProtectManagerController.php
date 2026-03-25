<?php
// BANIWW_PROTECT_MANAGER
// app/Http/Controllers/Admin/ProtectManagerController.php
// by @baniwwwXD | baniwwDeveloper

namespace Pterodactyl\Http\Controllers\Admin;

use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\View\View;
use Pterodactyl\Http\Controllers\Controller;

class ProtectManagerController extends Controller
{
    // ── Config paths ────────────────────────────────────────────
    const CONFIG_PATH   = '/etc/pterodactyl-protect-manager.json';
    const SCRIPTS_PATH  = '/var/www/pterodactyl/storage/protect-scripts';
    const BASE_URL      = 'https://raw.githubusercontent.com/Xbanz22/security-pterodactyl-baniww/main';
    const STATE_PATH    = '/etc/pterodactyl-protect-state.json';

    // ── Daftar proteksi default ──────────────────────────────────
    const DEFAULT_PROTECTIONS = [
        ['id' => 'p1',  'name' => 'Anti-Intip File',      'desc' => 'Mencegah admin lain melihat isi file server',             'file' => 'protect.sh',                  'marker' => 'BANIWW_ANTI_INTIP',     'controller' => '/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/FileController.php',         'isFile' => false],
        ['id' => 'p2',  'name' => 'Anti-Delete Server',   'desc' => 'Mencegah admin lain menghapus server',                    'file' => 'protect-delete.sh',            'marker' => 'BANIWW_DELETE',          'controller' => '/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/ServerController.php',       'isFile' => false],
        ['id' => 'p3',  'name' => 'User Management',      'desc' => 'Hanya Super Admin yang bisa kelola user',                 'file' => 'protect-user.sh',              'marker' => 'BANIWW_USER',            'controller' => '/var/www/pterodactyl/app/Http/Controllers/Admin/UserController.php',                     'isFile' => false],
        ['id' => 'p4',  'name' => 'Location Protection',  'desc' => 'Mencegah admin lain mengubah location',                  'file' => 'protect-location.sh',          'marker' => 'BANIWW_LOCATION',        'controller' => '/var/www/pterodactyl/app/Http/Controllers/Admin/LocationController.php',                  'isFile' => false],
        ['id' => 'p5',  'name' => 'Nest Protection',      'desc' => 'Mencegah admin lain mengubah nest/egg',                  'file' => 'protect-nest.sh',              'marker' => 'BANIWW_NEST',            'controller' => '/var/www/pterodactyl/app/Http/Controllers/Admin/NestController.php',                      'isFile' => false],
        ['id' => 'p6',  'name' => 'Node Protection',      'desc' => 'Mencegah admin lain mengubah node',                      'file' => 'protect-nodes.sh',             'marker' => 'BANIWW_NODES',           'controller' => '/var/www/pterodactyl/app/Http/Controllers/Admin/NodeController.php',                      'isFile' => false],
        ['id' => 'p7',  'name' => 'Settings Protection',  'desc' => 'Mencegah admin lain mengubah settings panel',            'file' => 'protect-settings.sh',          'marker' => 'BANIWW_SETTINGS',        'controller' => '/var/www/pterodactyl/app/Http/Controllers/Admin/SettingsController.php',                  'isFile' => false],
        ['id' => 'p8',  'name' => 'Server Controller',    'desc' => 'Proteksi controller server admin',                       'file' => 'protect-server-controller.sh', 'marker' => 'BANIWW_SERVER_CTRL',     'controller' => '/var/www/pterodactyl/app/Http/Controllers/Admin/ServersController.php',                   'isFile' => false],
        ['id' => 'p9',  'name' => 'Details Mod',          'desc' => 'Proteksi detail server dari modifikasi',                 'file' => 'protect-details-mod.sh',       'marker' => 'BANIWW_DETAILS',         'controller' => '/var/www/pterodactyl/app/Http/Controllers/Api/Client/Servers/DetailsController.php',      'isFile' => false],
        ['id' => 'p10', 'name' => 'Client API Key',       'desc' => 'Proteksi API key client',                                'file' => 'protect-apikey-full.sh',       'marker' => 'BANIWW_APIKEY_FULL',     'controller' => '/var/www/pterodactyl/app/Http/Controllers/Api/Client/ApiKeyController.php',               'isFile' => false],
        ['id' => 'p11', 'name' => 'Admin API Key',        'desc' => 'Proteksi API key admin',                                 'file' => 'protect-admin-apikey.sh',      'marker' => 'BANIWW_ADMIN_APIKEY',    'controller' => '/var/www/pterodactyl/app/Http/Controllers/Admin/ApiController.php',                      'isFile' => false],
        ['id' => 'p12', 'name' => 'Hide Sidebar',         'desc' => 'Sembunyikan item sidebar dari admin lain',               'file' => 'protect-sidebar.sh',           'marker' => 'BANIWW_SIDEBAR',         'controller' => '/var/www/pterodactyl/resources/views/layouts/admin.blade.php',                           'isFile' => false],
        ['id' => 'p13', 'name' => 'Dynamic Sidebar',      'desc' => 'Sidebar dinamis berdasarkan level admin',                'file' => 'protect-sidebar-dynamic.sh',   'marker' => 'BANIWW_DYNAMIC_SIDEBAR', 'controller' => '/var/www/pterodactyl/resources/views/layouts/admin.blade.php',                           'isFile' => false],
        ['id' => 'p14', 'name' => 'Custom 403 Page',      'desc' => 'Halaman 403 custom dengan branding sendiri',             'file' => 'protect-403-custom.sh',        'marker' => 'BANIWW_403',             'controller' => '/var/www/pterodactyl/app/Http/Middleware/SuperAdminOnly.php',                            'isFile' => false],
        ['id' => 'p15', 'name' => 'Memory/Disk Limit',    'desc' => 'Batasi alokasi memory & disk oleh admin lain',           'file' => 'protect-memory-limit.sh',      'marker' => 'BANIWW_MEMLIMIT',        'controller' => '/var/www/pterodactyl/app/Http/Controllers/Admin/ServersController.php',                   'isFile' => false],
        ['id' => 'p16', 'name' => 'API Rate Limit',       'desc' => 'Batasi rate limit API via nginx',                        'file' => 'protect-api-ratelimit.sh',     'marker' => 'pterodactyl-ratelimit',  'controller' => '/etc/nginx/pterodactyl-ratelimit.conf',                                                  'isFile' => true],
        ['id' => 'p17', 'name' => 'Anti Kill Panel',      'desc' => 'Cegah panel mati karena terlalu banyak server',          'file' => 'protect-create-limit.sh',      'marker' => 'BANIWW_CREATELIMIT',     'controller' => '/var/www/pterodactyl/app/Http/Controllers/Api/Application/Servers/ServerController.php', 'isFile' => false],
        ['id' => 'p18', 'name' => 'Anti DDoS 3 Layer',   'desc' => 'Proteksi DDoS 3 lapis: nginx + iptables + fail2ban',     'file' => 'protect-antiddos.sh',          'marker' => 'INSTALLED=',             'controller' => '/etc/pterodactyl-antiddos.conf',                                                         'isFile' => true],
        ['id' => 'p19', 'name' => 'DDoS Monitor',         'desc' => 'Monitor & auto-blokir IP yang melakukan DDoS',           'file' => 'fix-ddos-monitor.sh',          'marker' => 'INSTALLED=',             'controller' => '/etc/pterodactyl-ddos-monitor.conf',                                                     'isFile' => true],
    ];

    // ────────────────────────────────────────────────────────────
    // Helpers
    // ────────────────────────────────────────────────────────────

    private function loadConfig(): array
    {
        if (!file_exists(self::CONFIG_PATH)) {
            return [
                'brand_name'      => 'My Panel',
                'protect_text'    => 'Protected',
                'telegram'        => '@admin',
                'bot_link'        => '@mybot',
                'banner_title'    => 'Welcome!',
                'banner_message'  => 'Selamat datang di panel ini.',
                'protections'     => self::DEFAULT_PROTECTIONS,
            ];
        }
        $data = json_decode(file_get_contents(self::CONFIG_PATH), true) ?? [];
        // Merge protections — selalu pakai default sebagai base, override name/desc dari config
        $saved = collect($data['protections'] ?? []);
        $merged = array_map(function ($def) use ($saved) {
            $override = $saved->firstWhere('id', $def['id']);
            if ($override) {
                $def['name'] = $override['name'] ?? $def['name'];
                $def['desc'] = $override['desc'] ?? $def['desc'];
            }
            return $def;
        }, self::DEFAULT_PROTECTIONS);
        // Tambahkan script custom (id = 'c*')
        $custom = $saved->filter(fn($p) => str_starts_with($p['id'] ?? '', 'c'))->values()->toArray();
        $data['protections'] = array_merge($merged, $custom);
        return $data;
    }

    private function saveConfig(array $data): void
    {
        file_put_contents(self::CONFIG_PATH, json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE));
        @chmod(self::CONFIG_PATH, 0600);
    }

    private function loadState(): array
    {
        if (!file_exists(self::STATE_PATH)) return [];
        return json_decode(file_get_contents(self::STATE_PATH), true) ?? [];
    }

    private function saveState(array $state): void
    {
        file_put_contents(self::STATE_PATH, json_encode($state, JSON_PRETTY_PRINT));
        @chmod(self::STATE_PATH, 0600);
    }

    private function checkInstalled(array $protection): bool
    {
        $ctrl   = $protection['controller'];
        $marker = $protection['marker'];
        $isFile = $protection['isFile'] ?? false;

        if ($isFile) {
            return file_exists($ctrl);
        }
        if (!file_exists($ctrl)) return false;
        return str_contains(file_get_contents($ctrl), $marker);
    }

    private function getStatuses(array $protections): array
    {
        $statuses = [];
        foreach ($protections as $p) {
            $statuses[$p['id']] = $this->checkInstalled($p);
        }
        return $statuses;
    }

    private function runScript(string $file, bool $isCustom = false): array
    {
        if ($isCustom) {
            $scriptPath = self::SCRIPTS_PATH . '/' . basename($file);
            if (!file_exists($scriptPath)) {
                return ['ok' => false, 'output' => 'Script tidak ditemukan di server.'];
            }
            $cmd = 'bash ' . escapeshellarg($scriptPath) . ' 2>&1';
        } else {
            $url = self::BASE_URL . '/' . $file;
            $cmd = 'curl -fsSL ' . escapeshellarg($url) . ' | bash 2>&1';
        }

        $output   = [];
        $exitCode = 0;
        exec($cmd, $output, $exitCode);
        $outputStr = implode("\n", array_slice($output, -30)); // Ambil 30 baris terakhir

        $ok = $exitCode === 0 || $this->isSuccessOutput($outputStr);
        return ['ok' => $ok, 'output' => $outputStr, 'code' => $exitCode];
    }

    private function isSuccessOutput(string $output): bool
    {
        $keywords = [
            'BERHASIL', 'ALREADY_INSTALLED', 'VERIFY_OK', 'TERPASANG',
            'PROTEKSI BERHASIL', 'BERHASIL DIPASANG', 'BERHASIL DIUPDATE',
            'Inject berhasil', 'berhasil!', 'ANTI DDOS BERHASIL',
            'DDOS MONITOR BERHASIL', 'iptables rules disimpan',
        ];
        foreach ($keywords as $kw) {
            if (str_contains($output, $kw)) return true;
        }
        return false;
    }

    // ────────────────────────────────────────────────────────────
    // Views
    // ────────────────────────────────────────────────────────────

    public function index(Request $request): View
    {
        $config    = $this->loadConfig();
        $statuses  = $this->getStatuses($config['protections']);
        $active    = count(array_filter($statuses));
        $total     = count($statuses);

        return view('admin.protect-manager.index', compact('config', 'statuses', 'active', 'total'));
    }

    public function config(Request $request): View
    {
        $config = $this->loadConfig();
        return view('admin.protect-manager.config', compact('config'));
    }

    // ────────────────────────────────────────────────────────────
    // Actions
    // ────────────────────────────────────────────────────────────

    // Install satu proteksi
    public function install(Request $request): JsonResponse
    {
        $id     = $request->input('id');
        $config = $this->loadConfig();
        $prot   = collect($config['protections'])->firstWhere('id', $id);

        if (!$prot) {
            return response()->json(['ok' => false, 'message' => 'Proteksi tidak ditemukan.'], 404);
        }

        $isCustom = str_starts_with($id, 'c');
        $result   = $this->runScript($prot['file'], $isCustom);

        // Update state
        $state        = $this->loadState();
        $state[$id]   = $result['ok'];
        $this->saveState($state);

        return response()->json([
            'ok'       => $result['ok'],
            'message'  => $result['ok'] ? "✅ {$prot['name']} berhasil dipasang!" : "⚠️ Warning saat install {$prot['name']}",
            'output'   => $result['output'],
            'installed' => $this->checkInstalled($prot),
        ]);
    }

    // Uninstall satu proteksi (restore backup)
    public function uninstall(Request $request): JsonResponse
    {
        $id     = $request->input('id');
        $config = $this->loadConfig();
        $prot   = collect($config['protections'])->firstWhere('id', $id);

        if (!$prot) {
            return response()->json(['ok' => false, 'message' => 'Proteksi tidak ditemukan.'], 404);
        }

        $ctrl   = $prot['controller'];
        $isFile = $prot['isFile'] ?? false;
        $output = '';
        $ok     = false;

        if ($isFile) {
            // Untuk isFile: hapus saja file config-nya
            if (file_exists($ctrl)) {
                unlink($ctrl);
            }
            $ok = true;
            $output = 'File config dihapus.';
        } else {
            // Cari backup terbaru
            $dir    = dirname($ctrl);
            $base   = basename($ctrl);
            $backups = glob("{$dir}/{$base}.bak_*");
            if (empty($backups)) {
                return response()->json(['ok' => false, 'message' => "Backup tidak ditemukan untuk {$prot['name']}!"]);
            }
            rsort($backups); // terbaru di depan
            $backup = $backups[0];

            $cmd    = "cp " . escapeshellarg($backup) . " " . escapeshellarg($ctrl);
            $isBlade = str_ends_with($ctrl, '.blade.php');
            $extra  = $isBlade
                ? " && cd /var/www/pterodactyl && php artisan view:clear > /dev/null 2>&1"
                : " && chmod 644 " . escapeshellarg($ctrl) . " && cd /var/www/pterodactyl && php artisan optimize:clear > /dev/null 2>&1";

            exec($cmd . $extra . ' 2>&1', $out, $code);
            $ok     = ($code === 0);
            $output = implode("\n", $out);
        }

        // Update state
        $state      = $this->loadState();
        $state[$id] = false;
        $this->saveState($state);

        return response()->json([
            'ok'      => $ok,
            'message' => $ok ? "✅ {$prot['name']} berhasil diuninstall!" : "❌ Gagal uninstall {$prot['name']}",
            'output'  => $output,
        ]);
    }

    // Install semua yang di-centang
    public function installBatch(Request $request): JsonResponse
    {
        $ids    = $request->input('ids', []);
        $config = $this->loadConfig();
        $results = [];

        foreach ($ids as $id) {
            $prot = collect($config['protections'])->firstWhere('id', $id);
            if (!$prot) {
                $results[] = ['id' => $id, 'ok' => false, 'name' => $id, 'message' => 'Tidak ditemukan'];
                continue;
            }
            $isCustom = str_starts_with($id, 'c');
            $result   = $this->runScript($prot['file'], $isCustom);

            $state      = $this->loadState();
            $state[$id] = $result['ok'];
            $this->saveState($state);

            $results[] = [
                'id'      => $id,
                'ok'      => $result['ok'],
                'name'    => $prot['name'],
                'message' => $result['ok'] ? 'Berhasil' : 'Warning',
                'output'  => $result['output'],
            ];
        }

        $successCount = count(array_filter($results, fn($r) => $r['ok']));
        return response()->json([
            'ok'      => true,
            'message' => "Selesai: {$successCount}/" . count($ids) . " berhasil dipasang.",
            'results' => $results,
        ]);
    }

    // Simpan konfigurasi brand & banner
    public function saveConfig(Request $request): JsonResponse
    {
        $config = $this->loadConfig();

        $config['brand_name']     = $request->input('brand_name', $config['brand_name']);
        $config['protect_text']   = $request->input('protect_text', $config['protect_text']);
        $config['telegram']       = $request->input('telegram', $config['telegram']);
        $config['bot_link']       = $request->input('bot_link', $config['bot_link']);
        $config['banner_title']   = $request->input('banner_title', $config['banner_title']);
        $config['banner_message'] = $request->input('banner_message', $config['banner_message']);

        $this->saveConfig($config);
        return response()->json(['ok' => true, 'message' => '✅ Konfigurasi disimpan!']);
    }

    // Edit nama & deskripsi satu proteksi
    public function editProtection(Request $request): JsonResponse
    {
        $id     = $request->input('id');
        $config = $this->loadConfig();

        $found = false;
        foreach ($config['protections'] as &$prot) {
            if ($prot['id'] === $id) {
                $prot['name'] = $request->input('name', $prot['name']);
                $prot['desc'] = $request->input('desc', $prot['desc']);
                $found = true;
                break;
            }
        }

        if (!$found) {
            return response()->json(['ok' => false, 'message' => 'Proteksi tidak ditemukan.']);
        }

        $this->saveConfig($config);
        return response()->json(['ok' => true, 'message' => '✅ Proteksi diperbarui!']);
    }

    // Upload script custom
    public function uploadScript(Request $request): JsonResponse
    {
        $request->validate([
            'script'   => 'required|file|mimes:sh,txt|max:512',
            'name'     => 'required|string|max:50',
            'desc'     => 'nullable|string|max:150',
        ]);

        $file     = $request->file('script');
        $safeName = preg_replace('/[^a-zA-Z0-9_\-]/', '', pathinfo($file->getClientOriginalName(), PATHINFO_FILENAME));
        $fileName = $safeName . '_' . time() . '.sh';

        if (!is_dir(self::SCRIPTS_PATH)) {
            mkdir(self::SCRIPTS_PATH, 0750, true);
        }

        $file->move(self::SCRIPTS_PATH, $fileName);
        @chmod(self::SCRIPTS_PATH . '/' . $fileName, 0750);

        // Tambah ke config
        $config   = $this->loadConfig();
        $customId = 'c' . (time() % 100000);
        $config['protections'][] = [
            'id'         => $customId,
            'name'       => $request->input('name'),
            'desc'       => $request->input('desc', 'Custom script'),
            'file'       => $fileName,
            'marker'     => 'CUSTOM_INSTALLED_' . $customId,
            'controller' => '/tmp/custom_placeholder_' . $customId,
            'isFile'     => false,
            'isCustom'   => true,
        ];
        $this->saveConfig($config);

        return response()->json(['ok' => true, 'message' => "✅ Script '{$request->input('name')}' berhasil diupload!"]);
    }

    // Cek status semua (AJAX refresh)
    public function statusAll(): JsonResponse
    {
        $config   = $this->loadConfig();
        $statuses = $this->getStatuses($config['protections']);
        return response()->json(['ok' => true, 'statuses' => $statuses]);
    }
}
