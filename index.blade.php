{{-- resources/views/admin/protect-manager/index.blade.php --}}
{{-- BANIWW_PROTECT_MANAGER --}}
@extends('layouts.admin')

@section('title', 'Protect Manager')

@section('content-header')
<div class="row">
  <div class="col-sm-8">
    <h1 style="font-size:22px; font-weight:700; margin:0;">🛡️ Protect Manager</h1>
    <ol class="breadcrumb" style="margin:4px 0 0; background:none; padding:0; font-size:12px;">
      <li><a href="{{ route('admin.index') }}">Admin</a></li>
      <li class="active">Protect Manager</li>
    </ol>
  </div>
</div>
@endsection

@section('content')

<style>
  .pm-wrap { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
  .pm-tabs { display:flex; gap:6px; margin-bottom:18px; }
  .pm-tab  { padding:8px 22px; border-radius:6px; font-size:13px; font-weight:600; text-decoration:none; border:none; cursor:pointer; transition:all .15s; }
  .pm-tab.active { background:#3c8dbc; color:#fff; }
  .pm-tab.inactive { background:#f0f0f0; color:#666; border:1px solid #ddd; }
  .pm-tab.inactive:hover { background:#e0e0e0; color:#444; }

  .pm-card { background:#fff; border-radius:10px; box-shadow:0 1px 4px rgba(0,0,0,.07); margin-bottom:16px; overflow:hidden; border:1px solid #eaeaea; }
  .pm-card-header { padding:13px 18px; background:#f7f8fa; border-bottom:1px solid #eaeaea; display:flex; align-items:center; gap:8px; }
  .pm-card-header h4 { margin:0; font-size:13px; font-weight:700; color:#333; }
  .pm-cat-badge { font-size:10px; padding:2px 8px; border-radius:10px; background:#e8f0fe; color:#1a73e8; font-weight:600; margin-left:auto; }

  .pm-item { display:flex; align-items:center; gap:14px; padding:13px 18px; border-bottom:1px solid #f4f4f4; transition:background .12s; }
  .pm-item:last-child { border-bottom:none; }
  .pm-item:hover { background:#f9fbff; }

  .pm-dot { width:9px; height:9px; border-radius:50%; flex-shrink:0; transition:all .2s; }
  .pm-dot.on  { background:#00c48c; box-shadow:0 0 7px #00c48c77; }
  .pm-dot.off { background:#d0d0d0; }

  .pm-info { flex:1; min-width:0; }
  .pm-name { font-weight:600; font-size:13px; color:#222; }
  .pm-desc { font-size:11px; color:#999; margin-top:2px; }

  .pm-badge { display:inline-block; font-size:10px; padding:2px 8px; border-radius:10px; font-weight:600; margin-left:6px; vertical-align:middle; }
  .pm-badge.on  { background:#e6f9f2; color:#00a36c; }
  .pm-badge.off { background:#f0f0f0; color:#aaa; }
  .pm-badge.custom { background:#fff8e1; color:#f59e0b; }

  .pm-actions { display:flex; gap:5px; flex-shrink:0; }
  .pm-btn { border:none; border-radius:6px; padding:5px 10px; font-size:12px; cursor:pointer; font-weight:600; transition:all .15s; }
  .pm-btn:disabled { opacity:.5; cursor:not-allowed; }
  .pm-btn.install   { background:#e6f9f2; color:#00a36c; }
  .pm-btn.install:hover:not(:disabled) { background:#00c48c; color:#fff; }
  .pm-btn.uninstall { background:#fff0f0; color:#e55; }
  .pm-btn.uninstall:hover:not(:disabled) { background:#e55; color:#fff; }
  .pm-btn.edit      { background:#f0f0f0; color:#666; }
  .pm-btn.edit:hover:not(:disabled) { background:#e0e0e0; color:#333; }

  .pm-header-card { background:linear-gradient(135deg, #1e3a5f 0%, #2c5282 100%); border-radius:10px; padding:22px 24px; margin-bottom:18px; color:#fff; }
  .pm-stat-num { font-size:28px; font-weight:800; }
  .pm-stat-label { font-size:11px; opacity:.7; text-transform:uppercase; letter-spacing:.5px; }
  .pm-progress { background:rgba(255,255,255,.2); border-radius:4px; height:5px; margin-top:14px; }
  .pm-progress-fill { background:#00c48c; height:5px; border-radius:4px; transition:width .4s; }

  .pm-toolbar { display:flex; gap:8px; margin-bottom:16px; flex-wrap:wrap; align-items:center; }
  .pm-toolbar-btn { padding:7px 16px; border-radius:6px; font-size:12px; font-weight:600; border:1px solid #ddd; background:#fff; cursor:pointer; transition:all .12s; color:#555; }
  .pm-toolbar-btn:hover { background:#f0f4ff; border-color:#3c8dbc; color:#3c8dbc; }
  .pm-toolbar-btn.primary { background:#3c8dbc; color:#fff; border-color:#3c8dbc; }
  .pm-toolbar-btn.primary:hover { background:#2d6e99; }

  .pm-alert { padding:11px 16px; border-radius:7px; font-size:13px; margin-bottom:14px; display:none; }
  .pm-alert.success { background:#e6f9f2; color:#00704a; border:1px solid #b2ecd8; }
  .pm-alert.danger  { background:#fff0f0; color:#cc3333; border:1px solid #f5c6cb; }
  .pm-alert.warning { background:#fffbea; color:#92600a; border:1px solid #fde68a; }
  .pm-alert.info    { background:#eff6ff; color:#1d4ed8; border:1px solid #bfdbfe; }

  /* Modal */
  .pm-modal-bg { display:none; position:fixed; inset:0; background:rgba(0,0,0,.55); z-index:9999; align-items:center; justify-content:center; }
  .pm-modal-bg.open { display:flex; }
  .pm-modal { background:#fff; border-radius:12px; padding:24px; width:90%; box-shadow:0 10px 40px rgba(0,0,0,.2); }
  .pm-modal-title { font-size:15px; font-weight:700; margin:0 0 16px; }
  .pm-modal pre { background:#111827; color:#a3e635; padding:14px 16px; border-radius:8px; font-size:11.5px; white-space:pre-wrap; max-height:380px; overflow-y:auto; line-height:1.6; }
  .pm-modal-footer { display:flex; justify-content:flex-end; margin-top:16px; gap:8px; }

  .pm-selected-count { margin-left:auto; font-size:12px; color:#999; }
  .pm-spinner { display:inline-block; width:12px; height:12px; border:2px solid #ccc; border-top-color:#3c8dbc; border-radius:50%; animation:spin .6s linear infinite; vertical-align:middle; }
  @keyframes spin { to { transform:rotate(360deg); } }

  input[type=checkbox].pm-checkbox { width:15px; height:15px; cursor:pointer; accent-color:#3c8dbc; }
</style>

<div class="pm-wrap">

  {{-- Header stats card --}}
  <div class="pm-header-card">
    <div style="display:flex; align-items:center; gap:20px;">
      <div>
        <div class="pm-stat-num" id="stat-active">{{ $active }}</div>
        <div class="pm-stat-label">dari {{ $total }} proteksi aktif</div>
      </div>
      <div style="margin-left:auto; text-align:right; opacity:.85; font-size:12px; line-height:1.8;">
        <div>🔒 Panel Protection: {{ count(array_filter(['p1','p2','p3','p4','p5','p6','p7','p8','p9','p10','p11'], fn($id) => $statuses[$id] ?? false)) }}/11</div>
        <div>🎨 UI Protection: {{ count(array_filter(['p12','p13','p14'], fn($id) => $statuses[$id] ?? false)) }}/3</div>
        <div>💾 Resource: {{ count(array_filter(['p15','p16','p17'], fn($id) => $statuses[$id] ?? false)) }}/3</div>
        <div>🛡️ DDoS: {{ count(array_filter(['p18','p19'], fn($id) => $statuses[$id] ?? false)) }}/2</div>
      </div>
    </div>
    <div class="pm-progress">
      <div class="pm-progress-fill" id="stat-bar" style="width:{{ $total > 0 ? round(($active/$total)*100) : 0 }}%;"></div>
    </div>
  </div>

  {{-- Tabs --}}
  <div class="pm-tabs">
    <a href="{{ route('admin.protect-manager.index') }}" class="pm-tab active">🔒 Proteksi</a>
    <a href="{{ route('admin.protect-manager.config') }}" class="pm-tab inactive">⚙️ Konfigurasi</a>
  </div>

  {{-- Alert --}}
  <div id="pm-alert" class="pm-alert"></div>

  {{-- Toolbar --}}
  <div class="pm-toolbar">
    <button onclick="applySelected()" class="pm-toolbar-btn primary">⚡ Terapkan Pilihan</button>
    <button onclick="selectAll(true)"  class="pm-toolbar-btn">☑️ Pilih Semua</button>
    <button onclick="selectAll(false)" class="pm-toolbar-btn">⬜ Batal Pilih</button>
    <button onclick="refreshStatus()"  class="pm-toolbar-btn" id="btn-refresh">🔄 Refresh Status</button>
    <span class="pm-selected-count" id="selected-count">0 dipilih</span>
  </div>

  {{-- Proteksi list --}}
  @php
    $categories = [
      '🔒 Panel Protection'    => ['p1','p2','p3','p4','p5','p6','p7','p8','p9','p10','p11'],
      '🎨 UI Protection'       => ['p12','p13','p14'],
      '💾 Resource Protection' => ['p15','p16','p17'],
      '🛡️ DDoS Protection'    => ['p18','p19'],
      '🔧 Custom Scripts'      => [],
    ];
    foreach ($config['protections'] as $p) {
      if (str_starts_with($p['id'], 'c')) $categories['🔧 Custom Scripts'][] = $p['id'];
    }
    $protMap = collect($config['protections'])->keyBy('id');
  @endphp

  @foreach($categories as $catLabel => $catIds)
    @php $catProts = array_filter($catIds, fn($id) => $protMap->has($id)); @endphp
    @if(count($catProts) > 0)
    <div class="pm-card">
      <div class="pm-card-header">
        <h4>{{ $catLabel }}</h4>
        <span class="pm-cat-badge">{{ count(array_filter($catProts, fn($id) => $statuses[$id] ?? false)) }}/{{ count($catProts) }}</span>
      </div>
      @foreach($catProts as $id)
        @php $p = $protMap->get($id); $installed = $statuses[$id] ?? false; @endphp
        <div class="pm-item" id="item-{{ $id }}">
          <input type="checkbox" class="pm-checkbox prot-checkbox" data-id="{{ $id }}" onchange="updateSelectedCount()">
          <span class="pm-dot {{ $installed ? 'on' : 'off' }}" id="dot-{{ $id }}"></span>
          <div class="pm-info">
            <span class="pm-name" id="name-{{ $id }}">{{ $p['name'] }}</span>
            <span class="pm-badge {{ $installed ? 'on' : 'off' }}" id="badge-{{ $id }}">{{ $installed ? '● Active' : '○ Inactive' }}</span>
            @if(!empty($p['isCustom']))<span class="pm-badge custom">Custom</span>@endif
            <div class="pm-desc" id="desc-{{ $id }}">{{ $p['desc'] }}</div>
          </div>
          <div class="pm-actions">
            @if($installed)
              <button class="pm-btn uninstall" id="btn-{{ $id }}" onclick="uninstallOne('{{ $id }}')">🗑️ Uninstall</button>
            @else
              <button class="pm-btn install" id="btn-{{ $id }}" onclick="installOne('{{ $id }}')">⚡ Install</button>
            @endif
            <button class="pm-btn edit" onclick="editProt('{{ $id }}', '{{ addslashes($p['name']) }}', '{{ addslashes($p['desc']) }}')">✏️</button>
          </div>
        </div>
      @endforeach
    </div>
    @endif
  @endforeach

</div>

{{-- Modal: Output --}}
<div id="modal-output" class="pm-modal-bg">
  <div class="pm-modal" style="max-width:600px; max-height:85vh; overflow-y:auto;">
    <div class="pm-modal-title" id="modal-title">Output</div>
    <pre id="modal-body"></pre>
    <div class="pm-modal-footer">
      <button onclick="closeModal('modal-output')" class="pm-btn edit" style="padding:7px 18px;">✕ Tutup</button>
    </div>
  </div>
</div>

{{-- Modal: Edit --}}
<div id="modal-edit" class="pm-modal-bg">
  <div class="pm-modal" style="max-width:440px;">
    <div class="pm-modal-title">✏️ Edit Proteksi</div>
    <input type="hidden" id="edit-id">
    <div style="margin-bottom:12px;">
      <label style="font-size:12px; font-weight:600; color:#555; display:block; margin-bottom:4px;">Nama</label>
      <input type="text" id="edit-name" style="width:100%; padding:8px 10px; border:1px solid #ddd; border-radius:6px; font-size:13px;" maxlength="50">
    </div>
    <div style="margin-bottom:4px;">
      <label style="font-size:12px; font-weight:600; color:#555; display:block; margin-bottom:4px;">Deskripsi</label>
      <input type="text" id="edit-desc" style="width:100%; padding:8px 10px; border:1px solid #ddd; border-radius:6px; font-size:13px;" maxlength="150">
    </div>
    <div class="pm-modal-footer">
      <button onclick="closeModal('modal-edit')" class="pm-btn edit" style="padding:7px 18px;">Batal</button>
      <button onclick="saveEdit()" class="pm-btn install" style="padding:7px 18px;">💾 Simpan</button>
    </div>
  </div>
</div>

<script>
const CSRF = '{{ csrf_token() }}';

function showAlert(msg, type='success') {
  const el = document.getElementById('pm-alert');
  el.className = 'pm-alert ' + type;
  el.textContent = msg;
  el.style.display = 'block';
  clearTimeout(el._t);
  el._t = setTimeout(() => el.style.display = 'none', 5000);
}

function closeModal(id) { document.getElementById(id).classList.remove('open'); }
function openModal(id)  { document.getElementById(id).classList.add('open'); }

function updateSelectedCount() {
  const n = document.querySelectorAll('.prot-checkbox:checked').length;
  document.getElementById('selected-count').textContent = n + ' dipilih';
}

function selectAll(val) {
  document.querySelectorAll('.prot-checkbox').forEach(cb => cb.checked = val);
  updateSelectedCount();
}

function setStatus(id, installed) {
  const dot   = document.getElementById('dot-' + id);
  const badge = document.getElementById('badge-' + id);
  const btn   = document.getElementById('btn-' + id);
  if (dot) { dot.className = 'pm-dot ' + (installed ? 'on' : 'off'); }
  if (badge) {
    badge.className = 'pm-badge ' + (installed ? 'on' : 'off');
    badge.textContent = installed ? '● Active' : '○ Inactive';
  }
  if (btn) {
    if (installed) {
      btn.className = 'pm-btn uninstall';
      btn.textContent = '🗑️ Uninstall';
      btn.setAttribute('onclick', `uninstallOne('${id}')`);
    } else {
      btn.className = 'pm-btn install';
      btn.textContent = '⚡ Install';
      btn.setAttribute('onclick', `installOne('${id}')`);
    }
    btn.disabled = false;
  }
}

function showOutput(title, output) {
  document.getElementById('modal-title').textContent = title;
  document.getElementById('modal-body').textContent  = output || '(tidak ada output)';
  openModal('modal-output');
}

function updateHeaderStats() {
  const dots  = document.querySelectorAll('.pm-dot.on').length;
  const total = document.querySelectorAll('.pm-dot').length;
  const el = document.getElementById('stat-active');
  const bar = document.getElementById('stat-bar');
  if (el) el.textContent = dots;
  if (bar) bar.style.width = (total > 0 ? Math.round((dots/total)*100) : 0) + '%';
}

async function installOne(id) {
  const btn = document.getElementById('btn-' + id);
  if (btn) { btn.disabled = true; btn.innerHTML = '<span class="pm-spinner"></span>'; }

  try {
    const res  = await fetch('{{ route("admin.protect-manager.install") }}', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': CSRF },
      body: JSON.stringify({ id })
    });
    const data = await res.json();
    showAlert(data.message, data.ok ? 'success' : 'warning');
    setStatus(id, data.installed ?? data.ok);
    updateHeaderStats();
    if (data.output) showOutput((data.ok ? '✅ ' : '⚠️ ') + 'Output Install', data.output);
  } catch(e) {
    showAlert('❌ Gagal terhubung ke server.', 'danger');
    if (btn) { btn.disabled = false; btn.textContent = '⚡ Install'; }
  }
}

async function uninstallOne(id) {
  if (!confirm('Yakin mau uninstall proteksi ini?')) return;
  const btn = document.getElementById('btn-' + id);
  if (btn) { btn.disabled = true; btn.innerHTML = '<span class="pm-spinner"></span>'; }

  try {
    const res  = await fetch('{{ route("admin.protect-manager.uninstall") }}', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': CSRF },
      body: JSON.stringify({ id })
    });
    const data = await res.json();
    showAlert(data.message, data.ok ? 'success' : 'danger');
    if (data.ok) { setStatus(id, false); updateHeaderStats(); }
    else if (btn) { btn.disabled = false; btn.textContent = '🗑️ Uninstall'; }
    if (data.output) showOutput((data.ok ? '✅ ' : '❌ ') + 'Output Uninstall', data.output);
  } catch(e) {
    showAlert('❌ Gagal terhubung ke server.', 'danger');
    if (btn) { btn.disabled = false; btn.textContent = '🗑️ Uninstall'; }
  }
}

async function applySelected() {
  const ids = [...document.querySelectorAll('.prot-checkbox:checked')].map(cb => cb.dataset.id);
  if (ids.length === 0) { showAlert('⚠️ Pilih minimal 1 proteksi dulu!', 'warning'); return; }
  if (!confirm(`Install ${ids.length} proteksi yang dipilih? Proses ini memakan beberapa menit.`)) return;

  showAlert(`⏳ Menginstall ${ids.length} proteksi... Mohon tunggu.`, 'info');
  document.querySelectorAll('.pm-toolbar-btn, .pm-btn').forEach(b => b.disabled = true);

  try {
    const res  = await fetch('{{ route("admin.protect-manager.install-batch") }}', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': CSRF },
      body: JSON.stringify({ ids })
    });
    const data = await res.json();
    showAlert(data.message, 'success');
    (data.results || []).forEach(r => { setStatus(r.id, r.ok); });
    updateHeaderStats();
    const outputText = (data.results || [])
      .map(r => `[${r.ok ? '✅' : '⚠️'}] ${r.name}\n${r.output || '(no output)'}`)
      .join('\n\n─────────────────────\n\n');
    if (outputText.trim()) showOutput('📋 Output Batch Install', outputText);
  } catch(e) {
    showAlert('❌ Gagal: ' + e.message, 'danger');
  }

  document.querySelectorAll('.pm-toolbar-btn, .pm-btn').forEach(b => b.disabled = false);
  selectAll(false);
}

async function refreshStatus() {
  const btn = document.getElementById('btn-refresh');
  btn.innerHTML = '<span class="pm-spinner"></span> Mengecek...';
  btn.disabled = true;

  try {
    const res  = await fetch('{{ route("admin.protect-manager.status") }}');
    const data = await res.json();
    Object.entries(data.statuses || {}).forEach(([id, installed]) => setStatus(id, installed));
    updateHeaderStats();
    showAlert('✅ Status diperbarui!', 'success');
  } catch(e) {
    showAlert('❌ Gagal refresh status.', 'danger');
  }

  btn.textContent = '🔄 Refresh Status'; btn.disabled = false;
}

function editProt(id, name, desc) {
  document.getElementById('edit-id').value   = id;
  document.getElementById('edit-name').value = name;
  document.getElementById('edit-desc').value = desc;
  openModal('modal-edit');
}

async function saveEdit() {
  const id   = document.getElementById('edit-id').value;
  const name = document.getElementById('edit-name').value.trim();
  const desc = document.getElementById('edit-desc').value.trim();
  if (!name) { alert('Nama tidak boleh kosong!'); return; }

  try {
    const res  = await fetch('{{ route("admin.protect-manager.edit-protection") }}', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': CSRF },
      body: JSON.stringify({ id, name, desc })
    });
    const data = await res.json();
    if (data.ok) {
      const nameEl = document.getElementById('name-' + id);
      const descEl = document.getElementById('desc-' + id);
      if (nameEl) nameEl.textContent = name;
      if (descEl) descEl.textContent = desc;
      closeModal('modal-edit');
      showAlert(data.message, 'success');
    } else {
      showAlert(data.message, 'danger');
    }
  } catch(e) {
    showAlert('❌ Gagal menyimpan.', 'danger');
  }
}

// Tutup modal kalau klik background
document.querySelectorAll('.pm-modal-bg').forEach(bg => {
  bg.addEventListener('click', e => { if (e.target === bg) bg.classList.remove('open'); });
});
</script>
@endsection
