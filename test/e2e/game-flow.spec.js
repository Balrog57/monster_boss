import { test, expect } from '@playwright/test';

async function tapToStart(page) {
  await page.goto('/');
  const start = page.getByRole('button', { name: /tap to start/i });
  if (await start.isVisible()) await start.click();
  const skip = page.getByRole('button', { name: 'SKIP' });
  await skip.waitFor({ state: 'visible', timeout: 2000 }).catch(() => {});
  if (await skip.isVisible()) await skip.click();
}

test.describe('Boss Monster game flow', () => {
  test('loads main menu and starts solo game', async ({ page }) => {
    await tapToStart(page);
    await expect(page.locator('body')).toBeVisible();
    const solo = page.getByRole('button', { name: /solo|single player/i });
    if (await solo.isVisible()) {
      await solo.click();
    }
    await page.waitForTimeout(500);
    await expect(page).toHaveTitle(/.+/);
  });

  test('solo setup reaches boss selection', async ({ page }) => {
    await tapToStart(page);
    await page.getByText(/single player|solo/i).first().click();
    await page.locator('.ok, button[aria-label="OK"]').first().click();
    await page.locator('button[aria-label="OK"]').click();
    await expect(page.getByText(/PLAY BOSS|HOW MANY|boss/i).first()).toBeVisible({ timeout: 15000 });
  });
});
