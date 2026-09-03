// smoke.spec.js - Playwright smoke: menu loads and solo setup reachable.
import { test, expect } from '@playwright/test';

async function tapToStart(page) {
  await page.goto('/');
  await page.getByRole('button', { name: 'Tap to start' }).click();
  const skip = page.getByRole('button', { name: 'SKIP' });
  await skip.waitFor({ state: 'visible', timeout: 2000 }).catch(() => {});
  if (await skip.isVisible()) await skip.click();
}

test('main menu tap to start shows single player', async ({ page }) => {
  await tapToStart(page);
  await expect(page.getByText('SINGLE PLAYER')).toBeVisible();
});

test('solo flow reaches boss selection overlay', async ({ page }) => {
  await tapToStart(page);
  await page.getByText('SINGLE PLAYER').click();
  await page.getByRole('button', { name: 'OK' }).click();
  await expect(page.getByRole('dialog', { name: 'Choose your boss' })).toBeVisible({ timeout: 15000 });
});

test('main menu rules opens a scrollable page with a close button', async ({ page }) => {
  await tapToStart(page);
  await page.getByRole('button', { name: 'Rules' }).click();
  const dialog = page.getByRole('dialog', { name: 'Rules' });
  await expect(dialog).toBeVisible();
  await expect(dialog.getByRole('heading', { name: 'RULES', exact: true })).toBeVisible();
  await expect(dialog.locator('h2').first()).toBeVisible();
  await page.getByRole('button', { name: 'Close' }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByText('SINGLE PLAYER')).toBeVisible();
});

test('options opens card gallery', async ({ page }) => {
  await tapToStart(page);
  await page.getByText('OPTIONS').click();
  await page.getByText('CARD GALLERY').click();
  await expect(page.getByRole('dialog', { name: 'Card gallery' })).toBeVisible();
  await expect(page.getByRole('tab', { name: 'BOSSES' })).toBeVisible();
  await page.getByRole('tab', { name: 'ROOMS' }).click();
  await expect(page.getByRole('button', { name: 'Goblin Armory' })).toBeVisible();
});

test('solo game shows the log after discard', async ({ page }) => {
  await tapToStart(page);
  await page.getByText('SINGLE PLAYER').click();
  await page.getByRole('button', { name: 'OK' }).click();
  await expect(page.getByRole('dialog', { name: 'Choose your boss' })).toBeVisible({ timeout: 15000 });
  await page.getByRole('button', { name: /Play / }).click();
  await expect(page.getByText('SELECT 2 CARDS TO DISCARD')).toBeVisible({ timeout: 15000 });
  const slots = page.locator('.overlay button, [class*="slot"]').filter({ has: page.locator('img') });
  await slots.nth(0).click();
  await slots.nth(1).click();
  await page.getByRole('button', { name: 'Continue' }).click();
  await expect(page.getByRole('log', { name: 'Game log' })).toBeVisible({ timeout: 15000 });
});
