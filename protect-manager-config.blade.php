{{-- resources/views/admin/protect-manager/config.blade.php --}}
{{-- BANIWW_PROTECT_MANAGER --}}
@extends('layouts.admin')

@section('title', 'Protect Manager — Konfigurasi')

@section('content-header')
<div class="row">
  <div class="col-sm-8">
    <h1 style="font-size:22px; font-weight:700; margin:0;">🛡️ Protect Manager</h1>
    <ol class="breadcrumb" style="margin:4px 0 0; background:none; padding:0; font-size:12px;">
      <li><a href="{{ route('admin.index') }}">Admin</a></li>
      <li><a href="{{ route('admin.protect-manager.index') }}">Protect Manager</a></li>
      <li class="active">Konfigurasi</li>
    </ol>
  </div>
</div>
@endsection

@section('content')

<style>
  .pm-wrap { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
  .pm-tabs { display:flex; gap:6px; margin-bottom:18px; }
  .pm-tab  { padding:8px 22px; border-radius:6px; font-size:13px; font-weight:600; text-decoration:none; border:none; cursor:pointer; transition:all .15s; }
  .pm-tab.active   { background:#3c8dbc; color:#fff; }
  .pm-tab.inactive { background:#f0f0f0; color:#666; border:1px solid #ddd; }
  .pm-tab.inactive:hover { background:#e0e0e0; color:#444; }

  .pm-card { background:#fff; border-radius:10px; box-shadow:0 1px 4px rgba(0,0,0,.07); margin-bottom:16px; overflow:hidden; border:1px solid #eaeaea; }
  .pm-card-header { padding:13px 18px; background:#f7f8fa; border-bottom:1px solid #eaeaea; }
  .pm-card-header h3 { margin:0; font-size:14px; font-weight:700; color:#333; }
  .pm-card-body { padding:20px 22px; }

  .pm-field { margin-bottom:16px; }
  .pm-field label { display:block; font-size:12px; font-weight:600; color:#555; margin-bottom:5px; }
  .pm-field input, .pm-field textarea {
    width:100%; padding:9px 11px; border:1px solid #ddd; border-radius:7px;
    font-size:13px; color:#333; transition:border .15s; box-sizing:border-box;
  }
  .pm-field input:focus, .pm-field textarea:focus { border-color:#3c8dbc; outline:none; box-shadow:0 0 0 3px rgba(60,141,188,.1); }
  .pm-field .hint { font-size:11px; color:#aaa; margin-top:4px; }

  .pm-preview { background:#111827; border-radius:9px; padding:16px 18px; margin-top:4px; }
  .pm-preview-label { font-size:10px; color:#666; text-transform:uppercase; letter-spacing:.8px; margin-bottom:10px; }
  .pm-preview-row { display:flex; align-items:center; gap:10px; flex-wrap:wrap; }

  .pm-alert { padding:11px 16px; border-radius:7px; font-size:13px; margin-bottom:14px; display:none; }
  .pm-alert.success { background:#e6f9f2; color:#00704a; border:1px solid #b2ecd8; }
  .pm-alert.danger  { background:#fff0f0; color:#cc3333; border:1px solid #f5c6cb; }
  .pm-alert.warning { background:#fffbea; color:#92600a; border:1px solid #fde68a; }
  .pm-alert.info    { background:#eff6ff; color:#1d4ed8; border:1px solid #bfdbfe; }

  .pm-btn-primary { background:#3c8dbc; color:#fff; border:none; border-radius:7px; padding:9px 24px; font-size:13px; font-weight:600; cursor:pointer; transition:background .15s; }
  .pm-btn-primary:hover { background:#2d6e99; }
  .pm-btn-primary:disabled { opacity:.6; cursor:not-allowed; }
  .pm-btn-warn { background:#f59e0b; color:#fff; border:none; border-radius:7px; padding:8px 20px; font-size:13px; font-weight:600; cursor:pointer; transition:background .15s; }
  .pm-btn-warn:hover { background:#d97706; }
  .pm-btn-warn:disabled { opacity:.6; cursor:not-allowed; }

  .pm-spinner { display:inline-block; width:12px; height:12px; border:2px solid #ccc; border-top-color:#fff; border-radius:50%; animation:spin .6s linear infinite; vertical-align:middle; }
  @keyframes spin { to { transform:rotate(360deg); } }

  .row-2 { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
  @media(max-width:600px) { .row-2 { grid-template-columns:1fr; } }
</style>

<div class="pm-wrap">

  {{-- Tabs --}}
  <div class="pm-tabs">
    <a href="{{ route('admin.protect-manager.index') }}" class="pm-tab inactive">🔒 Proteksi</a>
    <a href="{{ route('admin.protect-manager.config') }}" class="pm-tab active">⚙️ Konfigurasi</a>
  </div>

  {{-- Alert --}}
  <div id="cfg-alert" class="pm-alert"></div>

  {{-- Brand --}}
  <div class="pm-card">
    <div class="pm-card-header"><h3>🏷️ Pengaturan Brand</h3></div>
    <div class="pm-card-body">
      <div class="row-2">
        <div class="pm-field">
          <label>Nama Brand</label>
          <input type="text" id="brand_name" value="{{ $config['brand_name'] ?? '' }}" maxlength="50" placeholder="Contoh: Jhonaley Store">
          <div class="hint">Tampil di footer panel.</div>
        </div>
        <div class="pm-field">
          <label>Teks Proteksi</label>
          <input type="text" id="protect_text" value="{{ $config['protect_text'] ?? '' }}" maxlength="40" placeholder="Contoh: Protected">
          <div class="hint">Label badge di footer.</div>
        </div>
        <div class="pm-field">
          <label>Kontak Telegram</label>
          <input type="text" id="telegram" value="{{ $config['telegram'] ?? '' }}" maxlength="50" placeholder="@username">
        </div>
        <div class="pm-field">
          <label>Link Bot</label>
          <input type="text" id="bot_link" value="{{ $config['bot_link'] ?? '' }}" maxlength="50" placeholder="@mybot">
        </div>
      </div>
    </div>
  </div>

  {{-- Banner --}}
  <div class="pm-card">
    <div class="pm-card-header"><h3>📋 Welcome Banner</h3></div>
    <div class="pm-card-body">
      <div class="pm-field">
        <label>Judul Banner</label>
        <input type="text" id="banner_title" value="{{ $config['banner_title'] ?? '' }}" maxlength="100" placeholder="Welcome To Server...">
      </div>
      <div class="pm-field">
        <label>Pesan Banner</label>
        <textarea id="banner_message" rows="3" maxlength="500" placeholder="Pesan yang tampil di panel...">{{ $config['banner_message'] ?? '' }}</textarea>
        <div class="hint">Mendukung tag HTML sederhana seperti &lt;b&gt;, &lt;i&gt;, &lt;a&gt;.</div>
      </div>

      {{-- Preview --}}
      <div class="pm-preview">
        <div class="pm-preview-label">Preview Footer</div>
        <div class="pm-preview-row">
          <span id="prev-badge" style="background:#3c8dbc; color:#fff; padding:3px 12px; border-radius:12px; font-size:11px; font-weight:700; letter-spacing:1px;">
            {{ strtoupper($config['protect_text'] ?? 'PROTECTED') }}
          </span>
          <span style="color:#888; font-size:12px;">Panel by</span>
          <span id="prev-brand" style="color:#3c8dbc; font-weight:600; font-size:13px;">{{ $config['brand_name'] ?? 'My Panel' }}</span>
          <span style="color:#444;">•</span>
          <span style="background:#1e88e5; color:#fff; padding:2px 10px; border-radius:10px; font-size:11px;">
            🔵 <span id="prev-tg">{{ $config['telegram'] ?? '@admin' }}</span>
          </span>
        </div>
        <div id="prev-banner" style="margin-top:8px; font-size:12px; color:#888;">{{ $config['banner_message'] ?? '' }}</div>
      </div>
    </div>
  </div>

  {{-- Simpan --}}
  <div style="margin-bottom:20px;">
    <button onclick="saveConfig(this)" class="pm-btn-primary">💾 Simpan Konfigurasi</button>
  </div>

  {{-- Upload custom script --}}
  <div class="pm-card">
    <div class="pm-card-header"><h3>🚀 Upload Script Custom</h3></div>
    <div class="pm-card-body">
      <p style="font-size:13px; color:#777; margin:0 0 16px;">Upload script <code>.sh</code> kamu sendiri. Akan muncul di tab Proteksi dan bisa diinstall dari panel.</p>
      <div class="row-2">
        <div class="pm-field">
          <label>Nama Proteksi</label>
          <input type="text" id="upload-name" maxlength="50" placeholder="Nama proteksi custom">
        </div>
        <div class="pm-field">
          <label>Deskripsi <span style="font-weight:400; color:#aaa;">(opsional)</span></label>
          <input type="text" id="upload-desc" maxlength="150" placeholder="Penjelasan singkat">
        </div>
      </div>
      <div class="pm-field">
        <label>File Script (.sh)</label>
        <input type="file" id="upload-file" accept=".sh,.txt" style="padding:6px;">
        <div class="hint">Maks 512KB. Hanya file <code>.sh</code>.</div>
      </div>
      <button onclick="uploadScript(this)" class="pm-btn-warn">📤 Upload & Tambahkan</button>
    </div>
  </div>

</div>

<script>
const CSRF = '{{ csrf_token() }}';

function showAlert(msg, type='success') {
  const el = document.getElementById('cfg-alert');
  el.className = 'pm-alert ' + type;
  el.textContent = msg;
  el.style.display = 'block';
  clearTimeout(el._t);
  el._t = setTimeout(() => el.style.display = 'none', 5000);
}

// Live preview
[
  ['brand_name',     el => document.getElementById('prev-brand').textContent = el.value || 'My Panel'],
  ['protect_text',   el => document.getElementById('prev-badge').textContent = (el.value || 'PROTECTED').toUpperCase()],
  ['telegram',       el => document.getElementById('prev-tg').textContent    = el.value || '@admin'],
  ['banner_message', el => document.getElementById('prev-banner').textContent = el.value],
].forEach(([id, fn]) => {
  const el = document.getElementById(id);
  if (el) el.addEventListener('input', () => fn(el));
});

async function saveConfig(btn) {
  btn.disabled = true;
  btn.innerHTML = '<span class="pm-spinner"></span> Menyimpan...';

  try {
    const res  = await fetch('{{ route("admin.protect-manager.save-config") }}', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-TOKEN': CSRF },
      body: JSON.stringify({
        brand_name:     document.getElementById('brand_name').value,
        protect_text:   document.getElementById('protect_text').value,
        telegram:       document.getElementById('telegram').value,
        bot_link:       document.getElementById('bot_link').value,
        banner_title:   document.getElementById('banner_title').value,
        banner_message: document.getElementById('banner_message').value,
      })
    });
    const data = await res.json();
    showAlert(data.message, data.ok ? 'success' : 'danger');
  } catch(e) {
    showAlert('❌ Gagal menyimpan konfigurasi.', 'danger');
  }

  btn.disabled = false;
  btn.textContent = '💾 Simpan Konfigurasi';
}

async function uploadScript(btn) {
  const name = document.getElementById('upload-name').value.trim();
  const desc = document.getElementById('upload-desc').value.trim();
  const file = document.getElementById('upload-file').files[0];

  if (!name) { showAlert('⚠️ Nama proteksi wajib diisi!', 'warning'); return; }
  if (!file)  { showAlert('⚠️ Pilih file script dulu!', 'warning'); return; }
  if (!file.name.endsWith('.sh') && !file.name.endsWith('.txt')) {
    showAlert('⚠️ Hanya file .sh yang diizinkan!', 'warning'); return;
  }

  btn.disabled = true;
  btn.innerHTML = '<span class="pm-spinner"></span> Mengupload...';

  const form = new FormData();
  form.append('_token', CSRF);
  form.append('name', name);
  form.append('desc', desc);
  form.append('script', file);

  try {
    const res  = await fetch('{{ route("admin.protect-manager.upload-script") }}', { method: 'POST', body: form });
    const data = await res.json();
    showAlert(data.message, data.ok ? 'success' : 'danger');
    if (data.ok) {
      document.getElementById('upload-name').value = '';
      document.getElementById('upload-desc').value = '';
      document.getElementById('upload-file').value = '';
      setTimeout(() => location.reload(), 1500);
    }
  } catch(e) {
    showAlert('❌ Gagal upload script.', 'danger');
  }

  btn.disabled = false;
  btn.textContent = '📤 Upload & Tambahkan';
}
</script>
@endsection