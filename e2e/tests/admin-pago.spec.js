// @ts-check
const { test, expect } = require('@playwright/test');

const ADMIN_EMAIL = 'admin@correo.com';
const ADMIN_PASS = 'Admin@123';
const MONTO_BASICO = 50000;

/**
 * Acepta el siguiente confirm() nativo del panel.
 * @param {import('@playwright/test').Page} page
 */
const aceptarConfirm = (page) => page.once('dialog', (d) => d.accept());

// Prepara el escenario: un pedido Pendiente del admin ya cerrado, lo que genera el pago pendiente
async function prepararPedidoCerrado({ page, request }) {
  const placa = `PAG-${Date.now() % 100000}`;

  const login = await request.post('/api/auth/login', {
    data: { email: ADMIN_EMAIL, password: ADMIN_PASS },
  });
  expect(login.ok()).toBeTruthy();
  const { token } = await login.json();
  const auth = { Authorization: `Bearer ${token}` };

  const pendientes = await request.get('/api/payments', { headers: auth });
  const pagosPrevios = JSON.parse(await pendientes.text()).data ?? [];
  for (const p of pagosPrevios) {
    if (p.status === 'Pendiente') {
      await request.put(`/api/payments/${p._id}`, { headers: auth, data: { status: 'Cancelado' } });
    }
  }

  const reg = await request.post('/api/cars/registercar', {
    headers: { ...auth, 'Idempotency-Key': `pago-${Date.now()}` },
    data: { plate: placa, brand: 'Toyota', model: 'Corolla', washType: 'Básico' },
  });
  expect(reg.ok()).toBeTruthy();

  // UI: buscar, mover a En Progreso y cerrar (genera el pago pendiente)
  await page.goto('/admin/');
  await page.fill('#loginEmail', ADMIN_EMAIL);
  await page.fill('#loginPassword', ADMIN_PASS);
  await page.click('button:has-text("Ingresar")');
  await expect(page.locator('#app')).toHaveClass(/show/);

  await page.click('#sidebar a[onclick="navigate(\'users\')"]');
  await page.fill('#userEmail', ADMIN_EMAIL);
  await page.click('button:has-text("Buscar")');

  const card = page.locator('.pedido-card', { hasText: placa });
  await expect(card).toBeVisible();

  const pResp = page.waitForResponse((r) => r.url().includes('/api/cars/update-status/' ) && r.request().method() === 'PUT');
  aceptarConfirm(page);
  await card.locator('button:has-text("Mover a En Progreso")').click();
  expect((await pResp).ok()).toBeTruthy();

  const cResp = page.waitForResponse((r) => r.url().includes('/api/cars/close-car/') && r.request().method() === 'PUT');
  aceptarConfirm(page);
  await card.locator('button:has-text("Cerrar Pedido")').click();
  expect((await cResp).ok()).toBeTruthy();
  await expect(card.locator('.completed-msg')).toBeVisible();

  return { placa, auth };
}

async function obtenerPago(request, auth, placa) {
  const res = await request.get('/api/payments', { headers: auth });
  const pagos = JSON.parse(await res.text()).data ?? [];
  return pagos.find((p) => p.plate === placa);
}

test.describe.configure({ mode: 'serial' });

test.describe('Admin panel - Flujo de pago', () => {
  test('al cerrar el pedido se genera el pago pendiente con el precio del catálogo', async ({ page, request }) => {
    const { placa, auth } = await prepararPedidoCerrado({ page, request });

    const pago = await obtenerPago(request, auth, placa);
    expect(pago).toBeTruthy();
    expect(pago.status).toBe('Pendiente');
    expect(pago.amount).toBe(MONTO_BASICO);

    // El panel muestra el Resumen de Pagos con la tarjeta de pendientes
    await page.click('#sidebar a[onclick="navigate(\'reports\')"]');
    await expect(page.locator('#reportStats .stat-card').filter({ has: page.locator('.label', { hasText: /^Pendiente de Cobro$/ }) })).toBeVisible();
    await page.screenshot({ path: 'screenshots/09-reportes-pendiente.png', fullPage: true });
  });

  test('marca el pago como Pagado (efectivo) y lo ve en Reportes', async ({ page, request }) => {
    const { placa, auth } = await prepararPedidoCerrado({ page, request });
    const pago = await obtenerPago(request, auth, placa);

    // El cliente paga en efectivo: la app marca el pago como Pagado
    const put = await request.put(`/api/payments/${pago._id}`, {
      headers: auth,
      data: { status: 'Pagado', method: 'Efectivo' },
    });
    expect(put.ok()).toBeTruthy();

    const pagado = await obtenerPago(request, auth, placa);
    expect(pagado.status).toBe('Pagado');
    expect(pagado.method).toBe('Efectivo');

    // Reportes del panel refleja el ingreso cobrado
    await page.click('#sidebar a[onclick="navigate(\'reports\')"]');
    const cobrados = page.locator('#reportStats .stat-card').filter({ has: page.locator('.label', { hasText: /^Ingresos Cobrados$/ }) });
    await expect(cobrados).toBeVisible();
    await expect(cobrados).toContainText('Gs. ');
    await page.screenshot({ path: 'screenshots/10-reportes-cobrado.png', fullPage: true });
  });

  test('paga un pedido con Stripe Checkout (modo test)', async ({ page, request }) => {
    const { placa, auth } = await prepararPedidoCerrado({ page, request });
    const pago = await obtenerPago(request, auth, placa);

    // Crear sesión de checkout con el paymentId existente
    const sesion = await request.post('/api/stripe/create-checkout-session', {
      headers: { ...auth, 'Idempotency-Key': `stripe-${Date.now()}` },
      data: { paymentId: pago._id, plate: placa },
    });
    expect(sesion.ok()).toBeTruthy();
    const { url } = await sesion.json();
    expect(url).toContain('checkout.stripe.com');

    // Ir al checkout de Stripe (test mode)
    await page.goto(url);
    await page.screenshot({ path: 'screenshots/11-stripe-checkout.png', fullPage: true });

    // El checkout redirige al success handler apenas se completa el pago:
    // interceptamos esa peticion para capturar el session_id
    const redirect = page.waitForRequest((r) => r.url().includes('/api/stripe/success'));
    await page.fill('input[name="email"]', 'cliente@test.com');
    await page.fill('input[name="cardNumber"]', '4242424242424242');
    await page.fill('input[name="cardExpiry"]', '12/34');
    await page.fill('input[name="cardCvc"]', '123');
    await page.fill('input[name="billingName"]', 'Cliente Test');
    await page.getByTestId('hosted-payment-submit-button').click();

    const successReq = await redirect;
    const sessionId = new URL(successReq.url()).searchParams.get('session_id');
    expect(sessionId).toBeTruthy();
    await page.screenshot({ path: 'screenshots/12-stripe-pagado.png', fullPage: true });

    // El success handler verifica la sesión con Stripe y marca el pago como Pagado
    await request.get(`/api/stripe/success?session_id=${sessionId}`);

    const pagado = await obtenerPago(request, auth, placa);
    expect(pagado.status).toBe('Pagado');
    expect(pagado.method).toBe('Stripe');
  });
});