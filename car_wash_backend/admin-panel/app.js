let authToken = localStorage.getItem('adminToken') || '';
let userEmail = localStorage.getItem('adminEmail') || '';
let pedidos = [];
let refreshTimer = null;
let dashboardData = null;
const API_BASE =
  window.location.origin && window.location.origin !== 'null'
    ? window.location.origin
    : 'http://localhost:5000';
const SIDEBAR = document.getElementById('sidebar');

SIDEBAR.querySelectorAll('a').forEach((a) => {
  a.addEventListener('click', () => {
    SIDEBAR.classList.remove('open');
    document.getElementById('sidebarOverlay').style.display = 'none';
  });
});

function decodeToken(token) {
  try {
    return JSON.parse(atob(token.split('.')[1]));
  } catch {
    return null;
  }
}
function getTokenExpiry(token) {
  const d = decodeToken(token);
  return d ? d.exp * 1000 : 0;
}
function isTokenExpired(token) {
  return Date.now() >= getTokenExpiry(token);
}
function getTimeUntilExpiry(token) {
  return Math.max(0, getTokenExpiry(token) - Date.now());
}

async function refreshToken() {
  try {
    const res = await fetch(`${API_BASE}/api/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: authToken }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'No se pudo renovar');
    authToken = data.token;
    localStorage.setItem('adminToken', authToken);
    scheduleRefresh();
  } catch {
    alert('Sesi\u00f3n expirada. Vuelva a iniciar sesi\u00f3n.');
    logout();
  }
}

function scheduleRefresh() {
  if (refreshTimer) clearTimeout(refreshTimer);
  const timeLeft = getTimeUntilExpiry(authToken);
  if (timeLeft <= 0) {
    logout();
    return;
  }
  refreshTimer = setTimeout(refreshToken, Math.max(60000, timeLeft - 30000));
}

async function login() {
  const email = document.getElementById('loginEmail').value.trim();
  const password = document.getElementById('loginPassword').value;
  const errorEl = document.getElementById('loginError');

  if (!email || !password) {
    errorEl.textContent = 'Ingrese correo y contrase\u00f1a';
    errorEl.style.display = 'block';
    return;
  }

  errorEl.style.display = 'none';

  try {
    const res = await fetch(`${API_BASE}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const text = await res.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      throw new Error(text || 'Credenciales inv\u00e1lidas');
    }
    if (!res.ok) throw new Error(data.error || data.message || 'Credenciales inv\u00e1lidas');

    authToken = data.token;
    userEmail = email;
    localStorage.setItem('adminToken', authToken);
    localStorage.setItem('adminEmail', email);

    document.getElementById('loginScreen').classList.add('hidden');
    document.getElementById('app').classList.add('show');
    document.getElementById('sidebarEmail').textContent = email;

    scheduleRefresh();
    navigate('dashboard');

    document.getElementById('loginEmail').value = '';
    document.getElementById('loginPassword').value = '';
  } catch (err) {
    errorEl.textContent = err.message;
    errorEl.style.display = 'block';
  }
}

function logout() {
  if (refreshTimer) clearTimeout(refreshTimer);
  authToken = '';
  userEmail = '';
  localStorage.removeItem('adminToken');
  localStorage.removeItem('adminEmail');
  document.getElementById('app').classList.remove('show');
  document.getElementById('loginScreen').classList.remove('hidden');
  document.getElementById('loginPassword').value = '';
}

function getHeaders() {
  const h = { 'Content-Type': 'application/json' };
  if (authToken) h['Authorization'] = 'Bearer ' + authToken;
  return h;
}

async function apiFetch(url, options = {}) {
  if (isTokenExpired(authToken)) await refreshToken();
  const res = await fetch(url, { ...options, headers: { ...getHeaders(), ...options.headers } });
  if (res.status === 401) {
    alert('Sesi\u00f3n expirada. Vuelva a iniciar sesi\u00f3n.');
    logout();
    throw new Error('No autorizado');
  }
  return res;
}

if (authToken && !isTokenExpired(authToken)) {
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('app').classList.add('show');
  document.getElementById('sidebarEmail').textContent = userEmail;
  scheduleRefresh();
  navigate('dashboard');
} else if (authToken) {
  localStorage.removeItem('adminToken');
  localStorage.removeItem('adminEmail');
}

// --- SANITIZACIÓN HTML (protege contra XSS si la API devuelve contenido con marcado) ---
function esc(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// --- NAVIGATION ---
function navigate(page) {
  document.querySelectorAll('.page').forEach((p) => p.classList.remove('active'));
  document.querySelectorAll('.sidebar-nav a').forEach((a) => a.classList.remove('active'));
  document.getElementById('page-' + page).classList.add('active');
  document.querySelectorAll('.sidebar-nav a').forEach((a) => {
    if (a.getAttribute('onclick') && a.getAttribute('onclick').includes(page))
      a.classList.add('active');
  });

  const titles = { dashboard: 'Dashboard', users: 'Usuarios', reports: 'Reportes' };
  document.getElementById('pageTitle').textContent = titles[page] || 'Dashboard';

  if (page === 'dashboard') loadDashboard();
  if (page === 'reports') loadReports();
}

// --- DASHBOARD ---
async function loadDashboard() {
  const grid = document.getElementById('statsGrid');
  const tbody = document.getElementById('recentTable');
  try {
    const res = await apiFetch(`${API_BASE}/api/admin/dashboard`);
    if (!res.ok) {
      let msg = 'Error al cargar dashboard';
      try {
        const e = await res.json();
        msg = e.error || msg;
      } catch {}
      throw new Error(msg);
    }
    dashboardData = await res.json();
  } catch (err) {
    grid.innerHTML = `<div class="empty-state"><i class="fas fa-circle-exclamation"></i>${esc(err.message)}</div>`;
    tbody.innerHTML = '<tr><td colspan="6" class="empty-state">No disponible</td></tr>';
    return;
  }

  const d = dashboardData;
  const cars = d.cars || {};
  const t = d.today || {};

  grid.innerHTML = `
    <div class="stat-card">
      <div class="icon blue"><i class="fas fa-car-side"></i></div>
      <div class="info">
        <div class="label">Autos Hoy</div>
        <div class="value">${t.cars ?? 0}</div>
        <div class="sub">total hist&oacute;rico: ${cars.total ?? 0}</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="icon yellow"><i class="fas fa-hourglass-half"></i></div>
      <div class="info">
        <div class="label">En Progreso (ahora)</div>
        <div class="value">${cars['En Progreso'] ?? 0}</div>
        <div class="sub">esperando inicio: ${cars.Pendiente ?? 0}</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="icon green"><i class="fas fa-circle-check"></i></div>
      <div class="info">
        <div class="label">Completados Hoy</div>
        <div class="value">${t.completed ?? 0}</div>
        <div class="sub">hist&oacute;rico: ${cars.Completado ?? 0}</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="icon teal"><i class="fas fa-circle-dollar"></i></div>
      <div class="info">
        <div class="label">Cobrado Hoy</div>
        <div class="value">Gs. ${(t.collected?.total ?? 0).toLocaleString()}</div>
        <div class="sub">${t.collected?.count ?? 0} pagos hoy</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="icon purple"><i class="fas fa-users"></i></div>
      <div class="info">
        <div class="label">Usuarios Registrados</div>
        <div class="value">${d.users ?? 0}</div>
        <div class="sub">nuevos hoy: ${t.newUsers ?? 0}</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="icon orange"><i class="fas fa-credit-card"></i></div>
      <div class="info">
        <div class="label">Pendiente de Cobro</div>
        <div class="value">Gs. ${(d.payments?.pending?.total ?? 0).toLocaleString()}</div>
        <div class="sub">${d.payments?.pending?.count ?? 0} pagos</div>
      </div>
    </div>
  `;

  if (d.recentCars && d.recentCars.length) {
    tbody.innerHTML = d.recentCars
      .map((c) => {
        const st = (c.status || '').toLowerCase().replace(/\s+/g, '-');
        return `<tr>
        <td><strong>${esc(c.plate || 'N/D')}</strong></td>
        <td>${esc(c.brand || '')} ${esc(c.model || '')}</td>
        <td><span class="badge badge-${st}">${esc(c.status || 'N/D')}</span></td>
        <td>Gs. ${(c.amount || 0).toLocaleString()}</td>
        <td>${esc(c.userId?.email || 'N/D')}</td>
        <td>${new Date(c.createdAt).toLocaleString()}</td>
      </tr>`;
      })
      .join('');
  } else {
    tbody.innerHTML = '<tr><td colspan="6" class="empty-state">Sin actividad reciente</td></tr>';
  }

  document.getElementById('lastUpdate').textContent =
    'Actualizado ' + new Date().toLocaleTimeString();
}

// --- USERS ---
async function buscarUsuario() {
  const email = document.getElementById('userEmail').value.trim();
  const notFound = document.getElementById('userNotFound');
  notFound.style.display = 'none';
  const pedidosContainer = document.getElementById('pedidosContainer');
  const userStats = document.getElementById('userStats');
  userStats.style.display = 'none';
  pedidosContainer.innerHTML = '';
  pedidos = [];

  if (!email) {
    notFound.textContent = 'Ingrese un email';
    notFound.style.display = 'block';
    return;
  }

  try {
    const res = await apiFetch(
      `${API_BASE}/api/admin/users/search?email=${encodeURIComponent(email)}`
    );
    if (!res.ok) {
      let msg = 'Usuario no encontrado';
      try {
        const e = await res.json();
        msg = e.error || msg;
      } catch {}
      throw new Error(msg);
    }
    const user = await res.json();
    document.getElementById('userEmail').dataset.userId = user._id;
    await cargarPedidos(user._id);
  } catch (err) {
    notFound.textContent = err.message;
    notFound.style.display = 'block';
  }
}

async function cargarPedidos(userId) {
  userId = userId || document.getElementById('userEmail').dataset.userId;
  const container = document.getElementById('pedidosContainer');
  const userStats = document.getElementById('userStats');

  container.innerHTML =
    '<div class="loading"><i class="fas fa-spinner fa-spin" style="margin-right:8px;"></i>Cargando pedidos...</div>';
  userStats.style.display = 'none';

  if (!userId) {
    container.innerHTML =
      '<div class="empty-state"><i class="fas fa-user-xmark"></i>Seleccione un usuario v\u00e1lido</div>';
    return;
  }

  try {
    const res = await apiFetch(`${API_BASE}/api/cars/status/${userId}`);
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Error al obtener pedidos');

    pedidos = data.data || data.cars || [];

    const pendientes = pedidos.filter((p) => p.status === 'Pendiente').length;
    const enProgreso = pedidos.filter((p) => p.status === 'En Progreso').length;
    const completados = pedidos.filter((p) => p.status === 'Completado').length;

    userStats.style.display = 'grid';
    userStats.innerHTML = `
      <div class="stat-card">
        <div class="icon yellow"><i class="fas fa-hourglass-half"></i></div>
        <div class="info"><div class="label">Pendientes</div><div class="value">${pendientes}</div></div>
      </div>
      <div class="stat-card">
        <div class="icon blue"><i class="fas fa-spinner"></i></div>
        <div class="info"><div class="label">En Progreso</div><div class="value">${enProgreso}</div></div>
      </div>
      <div class="stat-card">
        <div class="icon green"><i class="fas fa-circle-check"></i></div>
        <div class="info"><div class="label">Completados</div><div class="value">${completados}</div></div>
      </div>
    `;

    if (pedidos.length === 0) {
      container.innerHTML =
        '<div class="empty-state"><i class="fas fa-car"></i>No se encontraron pedidos para este usuario.</div>';
      return;
    }

    renderizarPedidos();
  } catch (err) {
    if (err.message !== 'No autorizado') {
      container.innerHTML =
        '<div class="empty-state"><i class="fas fa-circle-exclamation"></i>' +
        esc(err.message) +
        '</div>';
    }
  }
}

function renderizarPedidos() {
  const container = document.getElementById('pedidosContainer');
  container.innerHTML = pedidos
    .map((car) => {
      const statusRaw = String(car.status || 'N/D');
      const statusClass = statusRaw.toLowerCase().replace(' ', '-');
      const statusBadge = 'badge-' + statusClass;
      return `
      <div class="pedido-card">
        <div class="head">
          <h4><i class="fas fa-car" style="margin-right:8px;color:var(--gray-400);"></i>${esc(car.plate || 'N/D')}</h4>
          <span class="badge ${statusBadge}">${esc(statusRaw)}</span>
        </div>
        <div class="body">
          <div class="field"><label>Modelo</label><span>${esc(car.model || 'N/D')}</span></div>
          <div class="field"><label>Marca</label><span>${esc(car.brand || 'N/D')}</span></div>
          <div class="field"><label>Tipo de lavado</label><span>${esc(car.washType || 'N/D')}</span></div>
          <div class="field"><label>Monto</label><span>Gs. ${(car.amount || 0).toLocaleString()}</span></div>
          <div class="field"><label>Registrado</label><span>${new Date(car.createdAt).toLocaleDateString()}</span></div>
          ${car.scheduledDate ? `<div class="field"><label>Agendado</label><span>${new Date(car.scheduledDate).toLocaleDateString()} ${esc(car.scheduledTime || '')}</span></div>` : ''}
        </div>
        <div class="foot">
          ${car.status === 'Pendiente' ? `<button class="btn-progreso" data-action="mover-progreso" data-arg="${car._id}"><i class="fas fa-play" style="margin-right:4px;"></i>Mover a En Progreso</button>` : ''}
          ${car.status === 'En Progreso' ? `<button class="btn-completar" data-action="cerrar-pedido" data-arg="${car._id}"><i class="fas fa-check" style="margin-right:4px;"></i>Cerrar Pedido</button>` : ''}
          ${car.status === 'Completado' ? `<span class="completed-msg"><i class="fas fa-circle-check" style="margin-right:4px;"></i>Pedido completado</span>` : ''}
        </div>
      </div>
    `;
    })
    .join('');
}

async function moverAProgreso(carId) {
  if (!confirm('Mover este pedido a "En Progreso"?')) return;
  try {
    const res = await apiFetch(`${API_BASE}/api/cars/update-status/${carId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'En Progreso' }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Error al actualizar');
    const pedido = pedidos.find((p) => p._id === carId);
    if (pedido) pedido.status = 'En Progreso';
    renderizarPedidos();
    document.getElementById('userStats').innerHTML = '';
    const pendientes = pedidos.filter((p) => p.status === 'Pendiente').length;
    const enProgreso = pedidos.filter((p) => p.status === 'En Progreso').length;
    const completados = pedidos.filter((p) => p.status === 'Completado').length;
    document.getElementById('userStats').innerHTML = `
      <div class="stat-card"><div class="icon yellow"><i class="fas fa-hourglass-half"></i></div><div class="info"><div class="label">Pendientes</div><div class="value">${pendientes}</div></div></div>
      <div class="stat-card"><div class="icon blue"><i class="fas fa-spinner"></i></div><div class="info"><div class="label">En Progreso</div><div class="value">${enProgreso}</div></div></div>
      <div class="stat-card"><div class="icon green"><i class="fas fa-circle-check"></i></div><div class="info"><div class="label">Completados</div><div class="value">${completados}</div></div></div>
    `;
    loadDashboard();
  } catch (err) {
    if (err.message !== 'No autorizado') alert('Error: ' + err.message);
  }
}

async function cerrarPedido(carId) {
  if (!confirm('Cerrar este pedido como completado?')) return;
  try {
    const res = await apiFetch(`${API_BASE}/api/cars/close-car/${carId}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'Completado' }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Error al cerrar');
    const pedido = pedidos.find((p) => p._id === carId);
    if (pedido) pedido.status = 'Completado';
    await cargarPedidos();
    loadDashboard();
  } catch (err) {
    if (err.message !== 'No autorizado') alert('Error: ' + err.message);
  }
}

// --- REPORTS ---
let reportsData = null;

const fmtDate = (d) => {
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
};

function repSetRange(preset) {
  const now = new Date();
  const from = document.getElementById('repFrom');
  const to = document.getElementById('repTo');
  if (preset === 'hoy') {
    from.value = fmtDate(now);
    to.value = fmtDate(now);
  } else if (preset === '7d') {
    const s = new Date();
    s.setDate(s.getDate() - 6);
    from.value = fmtDate(s);
    to.value = fmtDate(now);
  } else if (preset === '30d') {
    const s = new Date();
    s.setDate(s.getDate() - 29);
    from.value = fmtDate(s);
    to.value = fmtDate(now);
  } else if (preset === 'mes') {
    from.value = fmtDate(new Date(now.getFullYear(), now.getMonth(), 1));
    to.value = fmtDate(now);
  } else if (preset === 'mesPasado') {
    from.value = fmtDate(new Date(now.getFullYear(), now.getMonth() - 1, 1));
    to.value = fmtDate(new Date(now.getFullYear(), now.getMonth(), 0));
  }
  loadReports();
}

function repInitPresets() {
  const container = document.getElementById('repPresets');
  if (!container || container.childElementCount) return;
  [
    ['hoy', 'Hoy'],
    ['7d', 'Últimos 7 días'],
    ['30d', 'Últimos 30 días'],
    ['mes', 'Este mes'],
    ['mesPasado', 'Mes pasado'],
  ].forEach(([id, label]) => {
    const b = document.createElement('button');
    b.textContent = label;
    b.onclick = () => repSetRange(id);
    b.style.cssText =
      'padding:6px 14px;border-radius:999px;border:1px solid var(--gray-300,#cbd5e1);background:#fff;color:#334155;cursor:pointer;font-size:12px;';
    container.appendChild(b);
  });
}

async function loadReports() {
  repInitPresets();
  const reportStats = document.getElementById('reportStats');
  const paymentSummary = document.getElementById('paymentSummary');
  const fromEl = document.getElementById('repFrom');
  const toEl = document.getElementById('repTo');
  // Primer arranque: mes en curso por defecto.
  if (!fromEl.value || !toEl.value) {
    const now = new Date();
    fromEl.value = fmtDate(new Date(now.getFullYear(), now.getMonth(), 1));
    toEl.value = fmtDate(now);
  }
  try {
    const params = new URLSearchParams({ from: fromEl.value, to: toEl.value });
    const res = await apiFetch(`${API_BASE}/api/admin/reports?${params}`);
    if (!res.ok) {
      let msg = 'Error al cargar reportes';
      try {
        const e = await res.json();
        msg = e.error || msg;
      } catch {}
      throw new Error(msg);
    }
    reportsData = await res.json();
  } catch (err) {
    reportStats.innerHTML = `<div class="empty-state"><i class="fas fa-circle-exclamation"></i>${esc(err.message)}</div>`;
    paymentSummary.innerHTML = '';
    document.getElementById('dailyChart').innerHTML = '';
    document.getElementById('movementsTable').innerHTML =
      '<tr><td colspan="6" class="empty-state">No disponible</td></tr>';
    return;
  }
  renderReports(reportsData);
  document.getElementById('lastUpdate').textContent =
    'Actualizado ' + new Date().toLocaleTimeString();
}

function renderReports(d) {
  const s = d.summary || {};
  const p = s.payments || {};
  const pagado = p.Pagado || { count: 0, total: 0 };
  const pendiente = p.Pendiente || { count: 0, total: 0 };
  const cancelado = p.Cancelado || { count: 0, total: 0 };
  const reembolsado = p.Reembolsado || { count: 0, total: 0 };
  const totalTx = pagado.count + pendiente.count + cancelado.count + reembolsado.count;
  const autos = s.cars || 0;
  const completados = s.completados || 0;

  document.getElementById('reportStats').innerHTML = `
    <div class="stat-card">
      <div class="icon green"><i class="fas fa-sack-dollar"></i></div>
      <div class="info">
        <div class="label">Ingresos Cobrados</div>
        <div class="value">Gs. ${pagado.total.toLocaleString()}</div>
        <div class="sub">${pagado.count} pagos del rango</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="icon yellow"><i class="fas fa-clock"></i></div>
      <div class="info">
        <div class="label">Pendiente de Cobro</div>
        <div class="value">Gs. ${pendiente.total.toLocaleString()}</div>
        <div class="sub">${pendiente.count} pagos del rango</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="icon purple"><i class="fas fa-rotate"></i></div>
      <div class="info">
        <div class="label">Autos del Per&iacute;odo</div>
        <div class="value">${autos}</div>
        <div class="sub">${completados} completados</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="icon teal"><i class="fas fa-users-gear"></i></div>
      <div class="info">
        <div class="label">Eficiencia</div>
        <div class="value">${autos > 0 ? Math.round((completados / autos) * 100) : 0}%</div>
        <div class="sub">tasa de finalizaci&oacute;n</div>
      </div>
    </div>
    <div class="stat-card">
      <div class="icon blue"><i class="fas fa-user-plus"></i></div>
      <div class="info">
        <div class="label">Usuarios Nuevos</div>
        <div class="value">${s.newUsers || 0}</div>
        <div class="sub">registrados en el rango</div>
      </div>
    </div>
  `;

  renderDaily(d.daily || []);
  renderMovements(d.movements || []);

  document.getElementById('paymentSummary').innerHTML = `
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;">
      <div style="background:#f0fdf4;border-radius:10px;padding:16px;border:1px solid #bbf7d0;">
        <div style="font-size:13px;color:#15803d;font-weight:600;margin-bottom:4px;">Pagados</div>
        <div style="font-size:22px;font-weight:700;color:#16a34a;">${pagado.count}</div>
        <div style="font-size:13px;color:#15803d;">Gs. ${pagado.total.toLocaleString()}</div>
      </div>
      <div style="background:#fefce8;border-radius:10px;padding:16px;border:1px solid #fde68a;">
        <div style="font-size:13px;color:#a16207;font-weight:600;margin-bottom:4px;">Pendientes</div>
        <div style="font-size:22px;font-weight:700;color:#ca8a04;">${pendiente.count}</div>
        <div style="font-size:13px;color:#a16207;">Gs. ${pendiente.total.toLocaleString()}</div>
      </div>
      <div style="background:#f8fafc;border-radius:10px;padding:16px;border:1px solid #cbd5e1;">
        <div style="font-size:13px;color:#475569;font-weight:600;margin-bottom:4px;">Cancelados / Reembolsados</div>
        <div style="font-size:22px;font-weight:700;color:#1e293b;">${cancelado.count + reembolsado.count}</div>
        <div style="font-size:13px;color:#64748b;">del rango</div>
      </div>
      <div style="background:#eff6ff;border-radius:10px;padding:16px;border:1px solid #bfdbfe;">
        <div style="font-size:13px;color:#1d4ed8;font-weight:600;margin-bottom:4px;">Total Transacciones</div>
        <div style="font-size:22px;font-weight:700;color:#1d4ed8;">${totalTx}</div>
        <div style="font-size:13px;color:#1d4ed8;">del rango</div>
      </div>
    </div>
  `;
}

function renderDaily(daily) {
  const el = document.getElementById('dailyChart');
  if (!daily.length) {
    el.innerHTML =
      '<div class="empty-state"><i class="fas fa-chart-column"></i>Sin movimientos en este rango</div>';
    return;
  }
  const shown = daily.length > 30 ? daily.slice(-30) : daily;
  const max = Math.max(1, ...shown.map((x) => x.collected));
  const bars = shown
    .map((x) => {
      const h = Math.max(6, Math.round((x.collected / max) * 88));
      return `<div style="flex:1;min-width:10px;display:flex;flex-direction:column;justify-content:flex-end;height:100%;" title="${x.day}: Gs. ${x.collected.toLocaleString()} cobrados · ${x.payments} pago(s) · ${x.cars} auto(s) registrado(s)">
      <div style="width:100%;max-width:30px;margin:0 auto;height:${h}%;background:linear-gradient(180deg,#14b8a6,#0891b2);border-radius:6px 6px 0 0;opacity:.9;"></div>
    </div>`;
    })
    .join('');
  const nota =
    daily.length > 30
      ? '<div style="font-size:11px;color:var(--gray-500,#64748b);margin-top:8px;">Mostrando los últimos 30 días del rango</div>'
      : '';
  el.innerHTML = `
    <div style="display:flex;align-items:flex-end;gap:4px;height:110px;">${bars}</div>
    <div style="font-size:11px;color:var(--gray-500,#64748b);margin-top:8px;">Altura = cobrado del d&iacute;a (Gs.). Pas&aacute; el mouse por cada barra para el detalle (fecha, cobrado, pagos, autos).</div>
    ${nota}
  `;
}

function renderMovements(movs) {
  const el = document.getElementById('movementsTable');
  if (!movs.length) {
    el.innerHTML =
      '<tr><td colspan="6" class="empty-state">Sin movimientos en este rango</td></tr>';
    return;
  }
  el.innerHTML = movs
    .map((m) => {
      const st = (m.status || '').toLowerCase().replace(/\s+/g, '-');
      return `<tr>
      <td>${new Date(m.date).toLocaleString()}</td>
      <td><strong>${esc(m.plate || 'N/D')}</strong></td>
      <td>${esc(m.userId?.email || 'N/D')}</td>
      <td>${esc(m.method || 'N/D')}</td>
      <td><span class="badge badge-${st}">${esc(m.status || 'N/D')}</span></td>
      <td>Gs. ${(m.amount || 0).toLocaleString()}</td>
    </tr>`;
    })
    .join('');
}

function exportarCSV() {
  const movs = reportsData?.movements || [];
  if (!movs.length) {
    alert('No hay movimientos en el rango seleccionado');
    return;
  }
  const from = document.getElementById('repFrom').value || 'inicio';
  const to = document.getElementById('repTo').value || 'fin';
  const rows = [['Fecha', 'Patente', 'Cliente', 'Método', 'Estado', 'Monto (Gs)']];
  movs.forEach((m) =>
    rows.push([
      new Date(m.date).toLocaleString(),
      m.plate || '',
      m.userId?.email || '',
      m.method || '',
      m.status || '',
      m.amount ?? 0,
    ])
  );
  const csv =
    '\uFEFF' +
    rows.map((r) => r.map((v) => `"${String(v).replaceAll('"', '""')}"`).join(';')).join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `movimientos_${from}_a_${to}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
}

// --- ENTER key on login ---
document.getElementById('loginPassword').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') login();
});
document.getElementById('loginEmail').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') document.getElementById('loginPassword').focus();
});
document.getElementById('userEmail').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') buscarUsuario();
});

// ---- Delegación de eventos (sin handlers inline: la CSP no permite scripts en línea) ----
document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-action]');
  if (!el) return;
  const arg = el.dataset.arg;
  switch (el.dataset.action) {
    case 'login':
      return login();
    case 'logout':
      return logout();
    case 'navigate':
      return navigate(arg);
    case 'buscar-usuario':
      return buscarUsuario();
    case 'load-reports':
      return loadReports();
    case 'export-csv':
      return exportarCSV();
    case 'mover-progreso':
      return moverAProgreso(arg);
    case 'cerrar-pedido':
      return cerrarPedido(arg);
    case 'toggle-sidebar':
      return document.getElementById('sidebar').classList.toggle('open');
    case 'close-sidebar':
      document.getElementById('sidebar').classList.remove('open');
      el.style.display = 'none';
      return undefined;
    default:
      return undefined;
  }
});
