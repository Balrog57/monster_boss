import { test, expect } from '@playwright/test';

test('local 1v1 AI game flows through setup, build, bait and adventure', async ({ page }) => {
  test.setTimeout(120000);
  page.on('console', msg => console.log('PAGE:', msg.type(), msg.text()));
  page.on('pageerror', err => console.log('PAGE ERR:', err.message));

  await page.goto('http://localhost:8000/');

  // Main menu: click logo
  await page.waitForSelector('button[aria-label="Démarrer le jeu"]', { timeout: 10000 });
  await page.click('button[aria-label="Démarrer le jeu"]');

  // Setup screen
  await page.waitForSelector('text=Choisissez le mode de jeu', { timeout: 10000 });
  await page.click('button:has-text("1 contre 1")');

  // Boss selection: click the first boss radio card
  await page.waitForSelector('text=Choisissez votre Boss', { timeout: 10000 });
  await page.locator('[role="radio"]').first().click();

  // SETUP phase: wait for "À votre tour" then build initial room
  await page.waitForSelector('text=SETUP', { timeout: 20000 });
  await page.waitForSelector('text=À votre tour', { timeout: 15000 });
  const handCards = page.locator('[aria-label="Votre main"] button[title]:not([disabled])');
  await handCards.first().click();

  // BUILD phase: wait for "À votre tour" (AI drives first, then it's our turn)
  await page.waitForSelector('text=BUILD', { timeout: 20000 });
  await page.waitForSelector('text=À votre tour', { timeout: 30000 });
  // Build a room then pass (building no longer auto-passes)
  await handCards.first().click();
  await page.click('button:has-text("Passer")');

  // BAIT is auto-advancing (no spells per official rules).
  // ADVENTURE may also flash by if no heroes are at entrances.
  // Wait for either ADVENTURE or next BUILD.
  await page.waitForSelector('text=ADVENTURE, text=BUILD', { timeout: 30000 }).catch(() => {});

  // If we caught ADVENTURE, try to resolve
  const adventureVisible = await page.locator('text=ADVENTURE').count();
  if (adventureVisible > 0) {
    await page.waitForSelector('text=À votre tour', { timeout: 15000 }).catch(() => {});
    const advBtn = page.locator('button:has-text("Résoudre")');
    if (await advBtn.count() > 0) await advBtn.first().click();
    const passAdv = page.locator('button:has-text("Passer")');
    if (await passAdv.count() > 0) await passAdv.first().click();
  }

  // Next turn: wait for BUILD (BEGINNING auto-advances to BUILD)
  await page.waitForSelector('text=BUILD', { timeout: 20000 });
});