import { test } from '@playwright/test';
import fs from 'fs';
import path from 'path';

test.use({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 1,
  baseURL: 'http://localhost:3000',
});

test('capture HTML screens at 1920x1080', async ({ page }) => {
  test.setTimeout(180000);
  const out = path.resolve('docs/reference');
  fs.mkdirSync(out, { recursive: true });

  const flags = { bossAppeared: false, boardAppeared: false };
  const shot = async (name) => {
    const p = path.join(out, name);
    await page.screenshot({ path: p, fullPage: false });
    console.log('WROTE', name, fs.statSync(p).size);
  };

  page.on('pageerror', (err) => console.log('PAGE ERR:', err.message));

  await page.goto('http://localhost:3000/', { waitUntil: 'networkidle' });
  await page.keyboard.press('Escape');
  await page.locator('button[aria-label="Tap to start"]').waitFor({ timeout: 20000 });
  await page.waitForTimeout(500);
  await shot('html_10_intro.png');

  await page.locator('button[aria-label="Tap to start"]').click();
  await page.getByText('SINGLE PLAYER', { exact: true }).waitFor({ timeout: 15000 });
  await page.waitForTimeout(400);
  await shot('html_11_menu.png');

  await page.getByRole('button', { name: 'OPTIONS' }).click();
  await page.getByRole('button', { name: 'SETTINGS' }).waitFor({ timeout: 10000 });
  await page.waitForTimeout(400);
  await shot('html_11b_options.png');

  await page.getByRole('button', { name: 'SETTINGS' }).click();
  await page.getByText('MUSIC', { exact: true }).waitFor({ timeout: 10000 });
  await page.waitForTimeout(400);
  await shot('html_11c_settings.png');

  await page.locator('button[aria-label="Back"]').click();
  await page.getByRole('button', { name: 'SETTINGS' }).waitFor({ timeout: 10000 });
  await page.locator('button[aria-label="Back"]').click();
  await page.getByText('SINGLE PLAYER', { exact: true }).waitFor({ timeout: 10000 });

  await page.getByRole('button', { name: 'MULTIPLAYER' }).click();
  await page.locator('#lobby-name').waitFor({ timeout: 15000 });
  await page.waitForTimeout(400);
  await shot('html_11d_lobby.png');

  await page.locator('button[aria-label="Back"]').click();
  const tap = page.locator('button[aria-label="Tap to start"]');
  try {
    await tap.waitFor({ timeout: 3000 });
    if (await tap.isVisible()) await tap.click();
  } catch { /* already on menu */ }
  await page.getByText('SINGLE PLAYER', { exact: true }).waitFor({ timeout: 10000 });
  await page.getByRole('button', { name: 'SINGLE PLAYER' }).click();
  await page.getByText('HOW MANY PLAYERS?').waitFor({ timeout: 15000 });
  await page.waitForTimeout(400);
  await shot('html_12_setup.png');

  await page.locator('button[aria-label="OK"]').click();
  await page.getByText('SELECT EXPANSIONS').waitFor({ timeout: 15000 });
  await page.getByText('Base set only').waitFor({ timeout: 10000 });
  await page.waitForTimeout(400);
  await shot('html_12b_expansions.png');

  await page.locator('button[aria-label="OK"]').click();
  await page.getByText('CHOOSE YOUR BOSS').waitFor({ timeout: 30000 });
  flags.bossAppeared = true;
  await page.waitForTimeout(600);
  await shot('html_13_boss.png');

  const bossBtn = page.locator('[aria-label="Boss choice"] button:enabled').first();
  await bossBtn.waitFor({ timeout: 10000 });
  await bossBtn.click();

  await page.getByText('CHOOSE YOUR BOSS').waitFor({ state: 'hidden', timeout: 45000 });
  await page.getByText('HOW MANY PLAYERS?').waitFor({ state: 'hidden', timeout: 5000 }).catch(() => {});
  await page.locator('img[alt="Heroes in Town"], [aria-label^="Phase"]').first().waitFor({ timeout: 45000 });
  flags.boardAppeared = true;
  await page.waitForTimeout(800);
  await shot('html_16_board.png');

  console.log('FLAGS', JSON.stringify(flags));
});
