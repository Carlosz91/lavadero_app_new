// @ts-check
const { test, expect } = require('@playwright/test');

const ADMIN_EMAIL = 'admin@correo.com';
const ADMIN_PASS = 'Admin@123';

// Acepta los confirm() nativos del panel (Mover a En Progreso / Cerrar Pedido)
/**
 * @param {import('@playwright/test').Page} page
 */
const aceptarConfirm = (page) => page.once('dialog', (d) => d.accept());

test.describe('Admin panel - Flujo completo de un lavado', () => {
  test('registra via API y completa el pedido por UI', async ({ page, request }) => {
    const placa = `E2E-${Date.now() % 100000}`;

    // 1) Preparación por API: login admin
    const login = await request.post('/api/auth/login', {
      data: { email: ADMIN_EMAIL, password: ADMIN_PASS },
    });
    expect(login.ok()).toBeTruthy();
    const { token } = await login.json();
    const auth = { Authorization: `Bearer ${token}` };

    // 1b) Cancelar pagos pendientes del admin, porque la regla de negocio
    //     bloquea registrar un auto si existe deuda pendiente
    const pendientes = await request.get('/api/payments', { headers: auth });
    const pagos = (await pendientes.json()).data ?? [];
    for (const p of pagos) {
      if (p.status === 'Pendiente') {
        await request.put(`/api/payments/${p._id}`, {
          headers: auth,
          data: { status: 'Cancelado' },
        });
      }
    }

    // 1c) Registrar un pedido Pendiente
    const car = await request.post('/api/cars/registercar', {
      headers: { ...auth, 'Idempotency-Key': `e2e-${Date.now()}` },
      data: { plate: placa, brand: 'Toyota', model: 'Corolla', washType: 'Básico' },
    });
    expect(car.ok()).toBeTruthy();

    // 2) Login en el panel
    await page.goto('/admin/');
    await page.fill('#loginEmail', ADMIN_EMAIL);
    await page.fill('#loginPassword', ADMIN_PASS);
    await page.click('button:has-text("Ingresar")');
    await expect(page.locator('#app')).toHaveClass(/show/);

    // 3) Ir a Usuarios y buscar al admin
    await page.click('#sidebar a[onclick="navigate(\'users\')"]');
    await page.fill('#userEmail', ADMIN_EMAIL);
    await page.click('button:has-text("Buscar")');

    // 4) Esperar que aparezca la card con nuestra placa
    const card = page.locator('.pedido-card', { hasText: placa });
    await expect(card).toBeVisible();
    await card.screenshot({ path: 'screenshots/06-pedido-pendiente.png' });

    // 5) Mover a En Progreso (aceptando el confirm)
    const progresoResp = page.waitForResponse(
      (r) => r.url().includes('/api/cars/update-status/') && r.request().method() === 'PUT'
    );
    aceptarConfirm(page);
    await card.locator('button:has-text("Mover a En Progreso")').click();
    expect((await progresoResp).ok()).toBeTruthy();
    await expect(card.locator('.badge')).toHaveText('En Progreso');
    await card.screenshot({ path: 'screenshots/07-pedido-en-progreso.png' });

    // 6) Cerrar pedido como Completado (genera el pago pendiente)
    const cerrarResp = page.waitForResponse(
      (r) => r.url().includes('/api/cars/close-car/') && r.request().method() === 'PUT'
    );
    aceptarConfirm(page);
    await card.locator('button:has-text("Cerrar Pedido")').click();
    expect((await cerrarResp).ok()).toBeTruthy();

    // 7) Verificar el estado final en la card
    await expect(card.locator('.completed-msg')).toHaveText('Pedido completado');
    await expect(card.locator('.badge')).toHaveText('Completado');
    await card.screenshot({ path: 'screenshots/08-pedido-completado.png' });
  });
});