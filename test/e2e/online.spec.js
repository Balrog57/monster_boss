import { test, expect } from '@playwright/test';

async function enterMultiplayer(page) {
  await page.goto('/');
  await page.getByRole('button', { name: /tap to start/i }).click();
  const skip = page.getByRole('button', { name: 'SKIP' });
  await skip.waitFor({ state: 'visible', timeout: 2000 }).catch(() => {});
  if (await skip.isVisible()) await skip.click();
  await page.getByRole('button', { name: /multiplayer/i }).click();
}

test.describe('Online multiplayer', () => {
  test('two browsers create and join a room', async ({ browser }) => {
    const host = await browser.newPage();
    const guest = await browser.newPage();

    await enterMultiplayer(host);
    await host.locator('#lobby-name').fill('Host');
    await host.getByRole('button', { name: /create room/i }).click();
    await expect(host.getByText(/SEARCHING/i)).toBeVisible({ timeout: 10000 });
    const code = (await host.locator('[class*="codeBox"]').textContent())?.trim();
    expect(code?.length).toBeGreaterThanOrEqual(4);

    await enterMultiplayer(guest);
    await guest.locator('#lobby-name').fill('Guest');
    await guest.locator('#lobby-code').fill(code || '');
    await guest.getByRole('button', { name: /^join$/i }).click();

    await expect(host.getByText(/Preparing game|PLAY BOSS|boss/i).first()).toBeVisible({ timeout: 30000 });
    await expect(guest.getByText(/Preparing game|PLAY BOSS|boss/i).first()).toBeVisible({ timeout: 30000 });

    await host.close();
    await guest.close();
  });

  test('host refresh restores session from localStorage', async ({ page }) => {
    await enterMultiplayer(page);
    await page.locator('#lobby-name').fill('Reconn');
    await page.getByRole('button', { name: /create room/i }).click();
    await expect(page.getByText(/SEARCHING/i)).toBeVisible({ timeout: 10000 });

    const session = await page.evaluate(() => localStorage.getItem('bm_online_session'));
    expect(session).toBeTruthy();

    await page.reload();
    await expect(page.getByText(/Preparing game|SEARCHING|PLAY BOSS/i).first()).toBeVisible({ timeout: 20000 });
  });
});
