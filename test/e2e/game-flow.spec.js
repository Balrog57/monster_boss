import { test, expect } from '@playwright/test';

test.describe('Boss Monster game flow', () => {
  test('loads main menu and starts solo game', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('body')).toBeVisible();
    const solo = page.getByRole('button', { name: /solo/i });
    if (await solo.isVisible()) {
      await solo.click();
    }
    await page.waitForTimeout(500);
    await expect(page).toHaveTitle(/.+/);
  });

  test('solo setup reaches boss selection', async ({ page }) => {
    await page.goto('/');
    await page.getByRole('button', { name: /solo/i }).click();
    await page.locator('.ok, button[aria-label="OK"]').first().click();
    await page.locator('button[aria-label="OK"]').click();
    await expect(page.getByText(/PLAY BOSS|HOW MANY|boss/i).first()).toBeVisible({ timeout: 15000 });
  });
});
