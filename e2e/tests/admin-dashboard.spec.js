// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Admin panel - Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/admin/');
    await page.fill('#loginEmail', 'admin@correo.com');
    await page.fill('#loginPassword', 'Admin@123');
    await page.click('button:has-text("Ingresar")');
    await expect(page.locator('#app')).toHaveClass(/show/);
  });

  test('carga las tarjetas de estadísticas', async ({ page }) => {
    await expect(page.locator('.stat-card').first()).toBeVisible({ timeout: 10000 });
    await expect(page.locator('.stat-card .label', { hasText: 'Total Vehículos' })).toBeVisible();
  });

  test('muestra la tabla de actividad reciente', async ({ page }) => {
    await expect(page.locator('#recentTable')).toBeVisible();
    await expect(page.locator('th', { hasText: 'Cliente' })).toBeVisible();
  });
});
