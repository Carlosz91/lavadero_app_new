// @ts-check
const { test, expect } = require('@playwright/test');

test.describe('Admin panel - Login', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/admin/');
  });

  test('inicia sesión con credenciales válidas', async ({ page }) => {
    await page.screenshot({ path: 'screenshots/01-login-form.png', fullPage: true });
    await page.fill('#loginEmail', 'admin@correo.com');
    await page.fill('#loginPassword', 'Admin@123');
    await page.click('button:has-text("Ingresar")');

    await expect(page.locator('#app')).toHaveClass(/show/);
    await expect(page.locator('#sidebarEmail')).toContainText('admin@correo.com');
    await page.screenshot({ path: 'screenshots/02-login-exito.png', fullPage: true });
  });

  test('muestra error con credenciales inválidas', async ({ page }) => {
    await page.fill('#loginEmail', 'admin@correo.com');
    await page.fill('#loginPassword', 'PasswordIncorrecta');
    await page.click('button:has-text("Ingresar")');

    await expect(page.locator('#loginError')).toBeVisible();
    await expect(page.locator('#loginScreen')).not.toHaveClass(/hidden/);
    await page.screenshot({ path: 'screenshots/03-login-error.png', fullPage: true });
  });

  test('muestra error si faltan campos', async ({ page }) => {
    await page.click('button:has-text("Ingresar")');

    await expect(page.locator('#loginError')).toHaveText('Ingrese correo y contraseña');
  });
});
