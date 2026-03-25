{{-- resources/views/admin/protect-manager/config.blade.php --}}
{{-- BANIWW_PROTECT_MANAGER --}}
@extends('layouts.admin')

@section('title', 'Protect Manager — Konfigurasi')

@section('content-header')
<div class="row">
  <div class="col-sm-6">
    <h1>🛡️ Protect Manager</h1>
    <ol class="breadcrumb">
      <li><a href="{{ route('admin.index') }}">Admin</a></li>
      <li><a href="{{ route('admin.protect-manager.index') }}">Protect Manager</a></li>
      <li class="active">Konfigurasi</li>
    </ol>
  </div>
</div>
@endsection

@section('content')
<div class="row">
  <div class="col-xs-12">

    {{-- Tabs --}}
    <div style="display:flex; gap:8px; margin-bottom:16px;">
      <a href="{{ route('admin.protect-manager.index') }}"
         style="padding:8px 20px; border-radius:6px; background:#f4f4f4; color:#555; font-weight:600; text-decoration:none; font-size:13px; border:1px solid #ddd;">
        🔒 Proteksi
      </a>
      <a href="{{ route('admin.protect-manager.config') }}"
         style="padding:8px 20px; border-radius:6px; background:#3c8dbc; color:#fff; font-weight:600; text-decoration:none; font-size:13px;">
        ⚙️ Konfigurasi
      </a>
    </div>

    {{-- Alert --}}
    <div id="cfg-alert" style="display:none; margin-bottom:14px;"></div>

    {{-- Pengaturan Brand --}}
    <div class="box box-primary" style="border-radius:8px;">
      <div class="box-header with-border" style="padding:14px 20px;">
        <h3 class="box-title" style="font-weight:700;">🏷️ Pengaturan Brand</h3>
      </div>
      <div class="box-body" style="padding:20px;">
        <div class="row">
          <div class="col-sm-6">
            <div class="form-group">
              <label style="font-size:12px; font-weight:600; color:#555;">Nama Brand</label>
              <input type="text" id="brand_name" class="form-control" value="{{ $config['brand_name'] ?? '' }}" maxlength="50" placeholder="Contoh: Jhonaley Store">
              <p class="help-block" style="font-size:11px;">Tampil di footer panel.</p>
            </div>
          </div>
          <div class="col-sm-6">
            <div class="form-group">
              <label style="font-size:12px; font-weight:600; color:#555;">Teks Proteksi</label>
              <input type="text" id="protect_text" class="form-control" value="{{ $config['protect_text'] ?? '' }}" maxlength="40" placeholder="Contoh: Protected">
              <p class="help-block" style="font-size:11px;">Label badge "PROTECTED" di footer.</p>
            </div>
          </div>
          <div class="col-sm-6">
            <div class="form-group">
              <label style="font-size:12px; font-weight:600; color:#555;">Kontak Telegram</label>
              <input type="text" id="telegram" class="form-control" value="{{ $config['telegram'] ?? '' }}" maxlength="50" placeholder="@username">
            </div>
          </div>
          <div class="col-sm-6">
            <div class="form-group">
              <label style="font-size:12px; font-weight:600; color:#555;">Link Bot</label>
              <input type="text" id="bot_link" class="form-control" value="{{ $config['bot_link'] ?? '' }}" maxlength="50" placeholder="@mybot">
            </div>
          </div>
        </div>
      </div>
    </div>

    {{-- Welcome Banner --}}
    <div class="box box-success" style="border-radius:8px;">
      <div class="box-header with-border" style="padding:14px 20px;">
        <h3 class="box-title" style="font-weight:700;">📋 Pengaturan Welcome Banner</h3>
      </div>
      <div class="box-body" style="padding:20px;">
        <div class="form-group">
          <label style="font-size:12px; font-weight:600; color:#555;">Judul Welcome Banner</label>
          <input type="text" id="banner_title" class="form-control" value="{{ $config['banner_title'] ?? '' }}" maxlength="100" placeholder="Welcome To Server ...">
        </div>
        <div class="form-group">
          <label style="font-size:12px; font-weight:600; color:#555;">Pesan Welcome Banner</label>
          <textarea id="banner_message" class="form-control" rows="4" maxlength="500" placeholder="Pesan yang tampil di bawah panel...">{{ $config['banner_message'] ?? '' }}</textarea>
          <p class="help-block" style="font-size:11px;">Mendukung tag HTML sederhana seperti &lt;a href="..."&gt;, &lt;b&gt;, &lt;i&gt;.</p>
        </div>

        {{-- Preview --}}
        <div style="background:#1a2332; border-radius:8px; padding:16px 20px; margin-top:8px;">
          <div style="font-size:11px; color:#888; margin-bottom:8px; text-transform:uppercase; letter-spacing:1px;">Preview Footer</div>
          <div style="display:flex; align-items:center; gap:10px; flex-wrap:wrap;">
            <span id="prev-badge" style="background:#3c8dbc; color:#fff; padding:3px 12px; border-radius:12px; font-size:11px; font-weight:700; letter-spacing:1px;">
              {{ strtoupper($config['protect_text'] ?? 'PROTECTED') }}
            </span>
            <span style="color:#aaa; font-size:12px;">Panel by</span>
            <span id="prev-brand" style="color:#3c8dbc; font-weight:600; font-size:13px;">{{ $config['brand_name'] ?? 'My Panel' }}</span>
            <span style="color:#555;">•</span>
            <span style="background:#1e88e5; color:#fff; padding:2px 10px; border-radius:10px; font-size:11px;">
              🔵 <span id="prev-tg">{{ $config['telegram'] ?? '@admin' }}</span>
            </span>
          </div>
          <div id="prev-banner" style="margin-top:8px; font-size:12px; color:#aaa;">{{ $config['banner_message'] ?? '' }}</div>
        </div>
      </div>
    </div>

    {{-- Tombol simpan --}}
    <div style="margin-bottom:16px;">
      <button onclick="saveConfig()" class="btn btn-primary" style="font-weight:600; padding:9px 24px;">
        💾 Simpan Konfigurasi
      </button>
    </div>

    {{-- Upload Script Custom --}}
    <div class="box box-warning" style="border-radius:8px;">
      <div class="box-header with-border" style="padding:14px 20px;">
        <h3 class="box-title" style="font-weight:700;">🚀 Upload Script Custom</h3>
      </div>
      <div class="box-body" style="padding:20px;">
        <p style="font-size:13px; color:#666; margin-bottom:16px;">
          Upload script <code>.sh</code> kamu sendiri. Script akan muncul di tab Proteksi sebagai "Custom Script" dan bisa diinstall dari panel.
        </p>
        <div class="row">
          <div class="col-sm-5">
            <div class="form-group">
              <label style="font-size:12px; font-weight:600; color:#555;">Nama Proteksi</label>
              <input type="text" id="upload-name" class="form-control" maxlength="50" placeholder="Nama proteksi custom">
            </div>
          </div>
          <div class="col-sm-7">
            <div class="form-group">
              <label style="font-size:12px; font-weight:600; color:#555;">Deskripsi (opsional)</label>
              <input type="text" id="upload-desc" class="form-control" maxlength="150" placeholder="Penjelasan singkat">
            </div>
          </div>
          <div class="col-sm-12">
            <div class="form-group">
              <label style="font-size:12px; font-weight:600; color:#555;">File Script (.sh)</label>
              <input type="file" id="upload-file" accept=".sh,.txt" style="display:block; margin-top:4px;">
              <p class="help-block" style="font-size:11px;">Maks 512KB. Hanya file <code>.sh</code>.</p>
            </div>
          </div>
        </div>
        <button onclick="uploadScript()" class="btn btn-warning btn-sm" style="font-weight:600;">
          📤 Upload & Tambahkan
        </button>
      </div>
    </div>

  </div>
</div>

<script>
const CSRF = '{{ csrf_token() }}';

function showAlert(msg, type='success') {
  const el = document.getElementById('cfg-alert');
  const colors = { success:'#d4edda:#155724:#c3e6cb', danger:'#f8d7da:#721c24:#f5c6cb', warning:'#fff3cd:#856404:#ffeeba', info:'#d1ecf1:#0c5460:#bee5eb' };
  const [bg, color, border] = (colors[type]||colors.info).split(':');
  el.innerHTML = `<div style="padding:12px 16px;background:${bg};color:${color};border:1px solid ${border};border-radius:6px;font-size:13px;">${msg}</div>`;
  el.style.display = 'block';
  setTimeout(() => el.style.display = 'none', 5000);
}

// Live preview
['brand_name','protect_text','telegram','banner_message'].forEach(id => {
  const el = document.getElementById(id);
  if (!el) return;
  el.addEventListener('input', () => {
    if (id === 'brand_name')     document.getElementById('prev-brand').textContent   = el.value || 'My Panel';
    if (id === 'protect_text')   document.getElementById('prev-badge').textContent   = (el.value || 'PROTECTED').toUpperCase();
    if (id === 'telegram')       document.getElementById('prev-tg').textContent      = el.value || '@admin';
    if (id === 'banner_message') document.getElementById('prev-banner').textContent  = el.value;
  });
});

async function saveConfig() {
  const btn = event.target;
  btn.disabled = true; btn.textContent = '⏳ Menyimpan...';

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

  btn.disabled = false; btn.textContent = '💾 Simpan Konfigurasi';
}

async function uploadScript() {
  const name = document.getElementById('upload-name').value.trim();
  const desc = document.getElementById('upload-desc').value.trim();
  const file = document.getElementById('upload-file').files[0];

  if (!name) { showAlert('⚠️ Nama proteksi wajib diisi!', 'warning'); return; }
  if (!file)  { showAlert('⚠️ Pilih file script dulu!', 'warning'); return; }
  if (!file.name.endsWith('.sh') && !file.name.endsWith('.txt')) {
    showAlert('⚠️ Hanya file .sh yang diizinkan!', 'warning'); return;
  }

  const btn = event.target;
  btn.disabled = true; btn.textContent = '⏳ Mengupload...';

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

  btn.disabled = false; btn.textContent = '📤 Upload & Tambahkan';
}
</script>
@endsection
