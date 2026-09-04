// visual.spec.js - Dual-resolution screenshot checks (boot → menu → board).
import { test, expect } from '@playwright/test';
import { startSoloGame } from './helpers/play-until-game-over.js';

async function tapToMenu(page) {
  await page.goto('/');
  const startBtn = page.getByRole('button', { name: /tap to start/i });
  await expect(startBtn).toBeVisible({ timeout: 15000 });
  await startBtn.click();
  const skip = page.getByRole('button', { name: 'SKIP' });
  await skip.waitFor({ state: 'visible', timeout: 2000 }).catch(() => {});
  if (await skip.isVisible()) await skip.click();
  await expect(page.getByText('SINGLE PLAYER')).toBeVisible({ timeout: 10000 });
}

test.describe('Visual dual-resolution', () => {
  test('boot screen', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByRole('button', { name: /tap to start/i })).toBeVisible({ timeout: 15000 });
    await expect(page).toHaveScreenshot('boot.png', { animations: 'disabled' });
  });

  test('main menu', async ({ page }) => {
    await tapToMenu(page);
    await expect(page).toHaveScreenshot('menu.png', { animations: 'disabled' });
  });

  test('solo board after discard', async ({ page }) => {
    await startSoloGame(page);
    await expect(page.getByRole('log', { name: 'Game log' })).toBeVisible();
    // Mask dealt cards / town / log / stage content so random deals do not flake chrome.
    await expect(page).toHaveScreenshot('board.png', {
      animations: 'disabled',
      maxDiffPixelRatio: 0.03,
      mask: [
        page.getByRole('log', { name: 'Game log' }),
        page.locator('[aria-label="Hand"]'),
        page.getByLabel(/dungeon/i),
        page.getByLabel(/Heroes in town/i),
        page.getByLabel(/Heroes in Town/i),
        page.getByLabel(/Opponent dungeons/i),
        page.locator('[class*="GameStage"]'),
        page.locator('[class*="gameStage"]'),
        page.locator('main'),
      ],
    });
  });
});
