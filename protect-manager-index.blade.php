{{-- resources/views/admin/protect-manager/index.blade.php --}}
{{-- BANIWW_PROTECT_MANAGER --}}
@extends('layouts.admin')

@section('title', 'Protect Manager')

@section('content-header')
<div class="row">
  <div class="col-sm-6">
    <h1>🛡️ Protect Manager</h1>
    <ol class="breadcrumb">
      <li><a href="{{ route('admin.index') }}">Admin</a></li>
      <li class="active">Protect Manager</li>
    </ol>
  </div>
</div>
@endsection

@section('content')
<div class="row">
  <div class="col-xs-12">

    {{-- Header card --}}
    <div class="box box-primary" style="border-radius:8px; border-top:3px solid #3c8dbc;">
      <div class="box-body" style="padding:20px 24px;">
        <div style="display:flex; align-items:center; gap:14px;">
          <span style="font-size:36px;">🛡️</span>
          <div>
            <h3 style="margin:0; font-weight:700; color:#222;">Protect Manager</h3>
            <p style="margin:4px 0 0; color:#666; font-size:13px;">
              Kelola semua proteksi panel dari sini. Centang proteksi yang ingin diinstall, lalu klik <b>"Terapkan"</b>.
            </p>
          </div>
          <div style="margin-left:auto; text-align:right;">
            <div style="font-size:22px; font-weight:700; color:#3c8dbc;">{{ $active }}<span style="color:#aaa; font-size:14px;">/{{ $total }}</span></div>
            <div style="font-size:11px; color:#888;">Aktif</div>
          </div>
        </div>
        {{-- Progress bar --}}
        <div style="margin-top:14px; background:#eee; border-radius:4px; height:6px;">
          <div style="background:#3c8dbc; width:{{ $total > 0 ? round(($active/$total)*100) : 0 }}%; height:6px; border-radius:4px; transition:width 0.4s;"></div>
        </div>
      </div>
    </div>

    {{-- Tabs --}}
    <div style="display:flex; gap:8px; margin-bottom:16px;">
      <a href="{{ route('admin.protect-manager.index') }}"
         style="padding:8px 20px; border-radius:6px; background:#3c8dbc; color:#fff; font-weight:600; text-decoration:none; font-size:13px;">
        🔒 Proteksi
      </a>
      <a href="{{ route('admin.protect-manager.config') }}"
         style="padding:8px 20px; border-radius:6px; background:#f4f4f4; color:#555; font-weight:600; text-decoration:none; font-size:13px; border:1px solid #ddd;">
        ⚙️ Konfigurasi
      </a>
    </div>

    {{-- Alert area --}}
    <div id="pm-alert" style="display:none; margin-bottom:14px;"></div>

    {{-- Action bar --}}
    <div style="display:flex; gap:8px; margin-bottom:16px; flex-wrap:wrap; align-items:center;">
      <button onclick="applySelected()" class="btn btn-primary btn-sm" style="font-weight:600;">
        ⚡ Terapkan Pilihan
      </button>
      <button onclick="selectAll(true)" class="btn btn-default btn-sm">☑️ Pilih Semua</button>
      <button onclick="selectAll(false)" class="btn btn-default btn-sm">⬜ Batal Pilih</button>
      <button onclick="refreshStatus()" class="btn btn-default btn-sm" id="btn-refresh">
        🔄 Refresh Status
      </button>
      <span style="margin-left:auto; font-size:12px; color:#888;" id="selected-count">0 dipilih</span>
    </div>

    {{-- Proteksi list --}}
    @php
      $categories = [
        '🔒 Panel Protection'    => ['p1','p2','p3','p4','p5','p6','p7','p8','p9','p10','p11'],
        '🎨 UI Protection'       => ['p12','p13','p14'],
        '💾 Resource Protection' => ['p15','p16','p17'],
        '🛡️ DDoS Protection'    => ['p18','p19'],
        '🔧 Custom Scripts'      => [], // diisi dinamis
      ];
      // Isi custom scripts
      foreach ($config['protections'] as $p) {
        if (str_starts_with($p['id'], 'c')) {
          $categories['🔧 Custom Scripts'][] = $p['id'];
        }
      }
      $protMap = collect($config['protections'])->keyBy('id');
    @endphp

    @foreach($categories as $catLabel => $catIds)
      @php
        $catProts = array_filter($catIds, fn($id) => $protMap->has($id));
      @endphp
      @if(count($catProts) > 0)
      <div class="box box-default" style="border-radius:8px; margin-bottom:16px;">
        <div class="box-header" style="padding:12px 18px; background:#f8f8f8; border-radius:8px 8px 0 0; border-bottom:1px solid #eee;">
          <h4 style="margin:0; font-size:14px; font-weight:700; color:#444;">{{ $catLabel }}</h4>
        </div>
        <div class="box-body" style="padding:0;">
          @foreach($catProts as $id)
            @php $p = $protMap->get($id); $isInstalled = $statuses[$id] ?? false; @endphp
            <div class="pm-item" data-id="{{ $id }}"
                 style="display:flex; align-items:center; gap:14px; padding:14px 18px; border-bottom:1px solid #f0f0f0; transition:background 0.15s;"
                 onmouseover="this.style.background='#fafcff'" onmouseout="this.style.background=''">

              {{-- Checkbox --}}
              <input type="checkbox" class="prot-checkbox" data-id="{{ $id }}"
                     onchange="updateSelectedCount()"
                     style="width:17px; height:17px; cursor:pointer; margin:0;">

              {{-- Status dot --}}
              <span class="status-dot" data-id="{{ $id }}"
                    style="width:10px; height:10px; border-radius:50%; flex-shrink:0; background:{{ $isInstalled ? '#00b894' : '#b2bec3' }}; box-shadow:{{ $isInstalled ? '0 0 6px #00b89477' : 'none' }};"></span>

              {{-- Info --}}
              <div style="flex:1; min-width:0;">
                <div style="display:flex; align-items:center; gap:8px; flex-wrap:wrap;">
                  <span class="prot-name" data-id="{{ $id }}" style="font-weight:600; font-size:13px; color:#333;">{{ $p['name'] }}</span>
                  <span class="prot-badge" data-id="{{ $id }}"
                        style="font-size:10px; padding:2px 8px; border-radius:10px; font-weight:600;
                               background:{{ $isInstalled ? '#d4edda' : '#f0f0f0' }};
                               color:{{ $isInstalled ? '#155724' : '#888' }};">
                    {{ $isInstalled ? '● Terinstall' : '○ Belum Install' }}
                  </span>
                  @if(!empty($p['isCustom']))
                    <span style="font-size:10px; padding:2px 8px; border-radius:10px; background:#fff3cd; color:#856404; font-weight:600;">Custom</span>
                  @endif
                </div>
                <div class="prot-desc" data-id="{{ $id }}" style="font-size:12px; color:#888; margin-top:2px;">{{ $p['desc'] }}</div>
              </div>

              {{-- Actions --}}
              <div style="display:flex; gap:6px; flex-shrink:0;">
                @if($isInstalled)
                  <button onclick="uninstallOne('{{ $id }}')" class="btn btn-xs btn-danger" title="Uninstall">
                    🗑️
                  </button>
                @else
                  <button onclick="installOne('{{ $id }}')" class="btn btn-xs btn-success" title="Install">
                    ⚡
                  </button>
                @endif
                <button onclick="editProt('{{ $id }}', '{{ addslashes($p['name']) }}', '{{ addslashes($p['desc']) }}')"
                        class="btn btn-xs btn-default" title="Edit nama & deskripsi">
                  ✏️
                </button>
              </div>
            </div>
          @endforeach
        </div>
      </div>
      @endif
    @endforeach

  </div>
</div>

{{-- Modal: Output install --}}
<div id="modal-output" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.5); z-index:9999; align-items:center; justify-content:center;">
  <div style="background:#fff; border-radius:10px; padding:24px; width:90%; max-width:560px; max-height:80vh; overflow-y:auto;">
    <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:14px;">
      <h4 style="margin:0;" id="modal-title">Output</h4>
      <button onclick="document.getElementById('modal-output').style.display='none'" class="btn btn-xs btn-default">✕ Tutup</button>
    </div>
    <pre id="modal-body" style="background:#1e1e1e; color:#00ff88; padding:14px; border-radius:6px; font-size:12px; white-space:pre-wrap; max-height:400px; overflow-y:auto;"></pre>
  </div>
</div>

{{-- Modal: Edit proteksi --}}
<div id="modal-edit" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.5); z-index:9999; align-items:center; justify-content:center;">
  <div style="background:#fff; border-radius:10px; padding:24px; width:90%; max-width:440px;">
    <h4 style="margin:0 0 16px;">✏️ Edit Proteksi</h4>
    <input type="hidden" id="edit-id">
    <div class="form-group">
      <label style="font-size:12px; font-weight:600; color:#666;">Nama</label>
      <input type="text" id="edit-name" class="form-control" maxlength="50">
    </div>
    <div class="form-group">
      <label style="font-size:12px; font-weight:600; color:#666;">Deskripsi</label>
      <input type="text" id="edit-desc" class="form-control" maxlength="150">
    </div>
    <div style="display:flex; gap:8px; justify-content:flex-end; margin-top:16px;">
      <button onclick="document.getElementById('modal-edit').style.display='none'" class="btn btn-default btn-sm">Batal</button>
      <button onclick="saveEdit()" class="btn btn-primary btn-sm">💾 Simpan</button>
    </div>
  </div>
</div>

<script>
const CSRF = '{{ csrf_token() }}';

function showAlert(msg, type='success') {
  const el = document.getElementById('pm-alert');
  const colors = { success: '#d4edda:#155724:#c3e6cb', danger: '#f8d7da:#721c24:#f5c6cb', warning: '#fff3cd:#856404:#ffeeba', info: '#d1ecf1:#0c5460:#bee5eb' };
  const [bg, color, border] = (colors[type] || colors.info).split(':');
  el.innerHTML = `<div style="padding:12px 16px; background:${bg}; color:${color}; border:1px solid ${border}; border-radius:6px; font-size:13px;">${msg}</div>`;
  el.style.display = 'block';
  setTimeout(() => el.style.display = 'none', 5000);
}

function updateSelectedCount() {
  const n = document.querySelectorAll('.prot-checkbox:checked').length;
  document.getElementById('selected-count').textContent = n + ' dipilih';
}

function selectAll(val) {
  document.querySelectorAll('.prot-checkbox').forEach(cb => cb.checked = val);
  updateSelectedCount();
}

function setStatus(id, installed) {
  const dot   = document.querySelector(`.status-dot[data-id="${id}"]`);
  const badge = document.querySelector(`.prot-badge[data-id="${id}"]`);
  if (dot) {
    dot.style.background  = installed ? '#00b894' : '#b2bec3';
    dot.style.boxShadow   = installed ? '0 0 6px #00b89477' : 'none';
  }
  if (badge) {
    badge.textContent     = installed ? '● Terinstall' : '○ Belum Install';
    badge.style.background = installed ? '#d4edda' : '#f0f0f0';
    badge.style.color      = installed ? '#155724' : '#888';
  }
}

function showOutput(title, output) {
  document.getElementById('modal-title').textContent = title;
  document.getElementById('modal-body').textContent  = output || '(tidak ada output)';
  document.getElementById('modal-output').style.display = 'flex';
}

async function installOne(id) {
  const btn = document.querySelector(`[data-id="${id}"] .btn-success`);
  if (btn) { btn.disabled = true; btn.textContent = '⏳'; }

  try {
    const res  = await fetch('{{ route("admin.protect-manager.install") }}', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': CSRF },
      body: JSON.stringify({ id })
    });
    const data = await res.json();
    showAlert(data.message, data.ok ? 'success' : 'warning');
    setStatus(id, data.installed);
    if (data.output) showOutput((data.ok ? '✅ ' : '⚠️ ') + 'Output Install', data.output);
  } catch(e) {
    showAlert('❌ Gagal terhubung ke server.', 'danger');
  }

  if (btn) { btn.disabled = false; btn.textContent = '⚡'; }
  setTimeout(() => location.reload(), 1500);
}

async function uninstallOne(id) {
  if (!confirm('Yakin mau uninstall proteksi ini?')) return;
  const btn = document.querySelector(`[data-id="${id}"] .btn-danger`);
  if (btn) { btn.disabled = true; btn.textContent = '⏳'; }

  try {
    const res  = await fetch('{{ route("admin.protect-manager.uninstall") }}', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': CSRF },
      body: JSON.stringify({ id })
    });
    const data = await res.json();
    showAlert(data.message, data.ok ? 'success' : 'danger');
    if (data.ok) setStatus(id, false);
  } catch(e) {
    showAlert('❌ Gagal terhubung ke server.', 'danger');
  }

  if (btn) { btn.disabled = false; btn.textContent = '🗑️'; }
  setTimeout(() => location.reload(), 1500);
}

async function applySelected() {
  const ids = [...document.querySelectorAll('.prot-checkbox:checked')].map(cb => cb.dataset.id);
  if (ids.length === 0) { showAlert('⚠️ Pilih minimal 1 proteksi dulu!', 'warning'); return; }

  if (!confirm(`Install ${ids.length} proteksi yang dipilih?`)) return;

  showAlert(`⏳ Menginstall ${ids.length} proteksi... Mohon tunggu, proses ini memakan waktu.`, 'info');
  document.querySelectorAll('.btn').forEach(b => b.disabled = true);

  try {
    const res  = await fetch('{{ route("admin.protect-manager.install-batch") }}', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': CSRF },
      body: JSON.stringify({ ids })
    });
    const data = await res.json();
    showAlert(data.message, 'success');
    // Update status semua
    (data.results || []).forEach(r => setStatus(r.id, r.ok));
    // Tampilkan output gabungan
    const outputText = (data.results || []).map(r => `[${r.ok ? '✅' : '⚠️'}] ${r.name}\n${r.output || ''}`).join('\n\n---\n\n');
    if (outputText.trim()) showOutput('📋 Output Batch Install', outputText);
  } catch(e) {
    showAlert('❌ Gagal: ' + e.message, 'danger');
  }

  document.querySelectorAll('.btn').forEach(b => b.disabled = false);
  setTimeout(() => location.reload(), 2000);
}

async function refreshStatus() {
  const btn = document.getElementById('btn-refresh');
  btn.textContent = '⏳'; btn.disabled = true;

  try {
    const res     = await fetch('{{ route("admin.protect-manager.status") }}');
    const data    = await res.json();
    const statuses = data.statuses || {};
    Object.entries(statuses).forEach(([id, installed]) => setStatus(id, installed));
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
  document.getElementById('modal-edit').style.display = 'flex';
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
      document.querySelector(`.prot-name[data-id="${id}"]`).textContent = name;
      document.querySelector(`.prot-desc[data-id="${id}"]`).textContent = desc;
      document.getElementById('modal-edit').style.display = 'none';
      showAlert(data.message, 'success');
    } else {
      showAlert(data.message, 'danger');
    }
  } catch(e) {
    showAlert('❌ Gagal menyimpan.', 'danger');
  }
}
</script>
@endsection
