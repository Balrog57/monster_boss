import { test, expect } from '@playwright/test';
import path from 'path';
import fs from 'fs';

test.describe('Complete Playthrough and UI Verification', () => {
  test('plays through setup, discard, build, bait, adventure and verifies UI', async ({ page }) => {
    test.setTimeout(180000);

    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', (err) => {
      consoleErrors.push(err.message);
    });

    const out = path.resolve('docs/reference');
    fs.mkdirSync(out, { recursive: true });
    const shot = async (name) => {
      await page.screenshot({ path: path.join(out, name), fullPage: false });
    };

    // 1. Intro Screen
    await page.goto('/');
    const startBtn = page.getByRole('button', { name: /tap to start/i });
    await expect(startBtn).toBeVisible({ timeout: 15000 });
    await shot('play_00_boot.png');

    // Tap to start
    await startBtn.click();

    // If tutorial appears, skip it
    const skipTut = page.getByRole('button', { name: 'SKIP' });
    try {
      await skipTut.waitFor({ state: 'visible', timeout: 2000 });
      await skipTut.click();
    } catch {
      /* tutorial already seen */
    }

    // 2. Main Menu
    await expect(page.getByText('SINGLE PLAYER')).toBeVisible({ timeout: 10000 });
    await shot('play_01_menu.png');

    // 3. Test Options -> Rules & Card Gallery from Main Menu
    await page.getByRole('button', { name: 'OPTIONS' }).click();
    await expect(page.getByRole('button', { name: 'CARD GALLERY' })).toBeVisible();

    // Open Card Gallery
    await page.getByRole('button', { name: 'CARD GALLERY' }).click();
    const gallery = page.getByRole('dialog', { name: 'Card gallery' });
    await expect(gallery).toBeVisible();
    await expect(page.getByRole('tab', { name: 'BOSSES' })).toBeVisible();
    await page.getByRole('tab', { name: 'ROOMS' }).click();
    // Close Card Gallery
    await page.getByRole('button', { name: 'Close' }).click();
    await expect(gallery).toBeHidden();

    // Back to Home Menu
    await page.locator('button[aria-label="Back"]').click();
    await expect(page.getByText('SINGLE PLAYER')).toBeVisible();

    // Open Rules from Home Menu
    await page.getByRole('button', { name: 'RULES' }).click();
    const rules = page.getByRole('dialog', { name: 'Rules' });
    await expect(rules).toBeVisible();
    await expect(rules.getByRole('heading', { name: 'Base Set' })).toBeVisible();
    await shot('play_rules_base.png');
    // Test tab navigation
    await page.getByRole('tab', { name: 'Advanced FAQ' }).click();
    await expect(rules.getByRole('heading', { name: 'Advanced FAQ' })).toBeVisible();
    await shot('play_rules_faq.png');
    await page.getByRole('button', { name: 'Close' }).click();
    await expect(rules).toBeHidden();

    // 4. Enter Solo Setup
    await page.getByText('SINGLE PLAYER').click();
    await expect(page.getByText('HOW MANY PLAYERS?')).toBeVisible();
    await shot('play_02_setup.png');

    // Confirm 2 players (OK)
    await page.locator('button[aria-label="OK"]').click();

    // 5. In-Board Boss Selection
    const bossSelect = page.getByRole('dialog', { name: 'Choose your boss' });
    await expect(bossSelect).toBeVisible({ timeout: 15000 });
    await shot('play_07_boss.png');

    // Click "PLAY BOSS MONSTER!"
    const playBoss = page.getByRole('button', { name: /PLAY /i });
    await expect(playBoss).toBeVisible();
    await playBoss.click();

    // 6. Opening Discard Overlay
    const discardOverlay = page.getByRole('dialog', { name: 'Select 2 cards to discard' });
    await expect(discardOverlay).toBeVisible({ timeout: 15000 });
    await shot('play_01_discard_sel.png');

    // Pick 2 cards
    const discardCards = discardOverlay.getByRole('button', { name: /^Select /i });
    await discardCards.nth(0).click();
    await discardCards.nth(1).click();
    const continueBtn = discardOverlay.getByRole('button', { name: 'Continue' });
    await expect(continueBtn).toBeEnabled();
    await continueBtn.click();
    await expect(discardOverlay).toBeHidden({ timeout: 10000 });

    // 7. Board is active and discard overlay is gone!
    await expect(page.getByRole('log', { name: 'Game log' })).toBeVisible({ timeout: 15000 });
    await page.waitForTimeout(500);
    await shot('play_10_board.png');

    // 8. SETUP or BUILD phase: place a room
    const isYourTurn = async () => {
      const txt = await page.locator('[class*="phaseBadge"]').textContent().catch(() => '');
      return txt.includes('YOUR TURN');
    };

    const waitMyTurn = async (maxMs = 30000) => {
      const start = Date.now();
      while (Date.now() - start < maxMs) {
        if (await isYourTurn()) return true;
        const advPass = page.locator('button:has-text("PASS")').filter({ hasNotText: 'PASS TURN' });
        if (await advPass.count() > 0 && await advPass.first().isVisible()) {
          await advPass.first().click().catch(() => {});
        }
        await page.waitForTimeout(400);
      }
      return false;
    };

    await waitMyTurn(30000);

    // Click a room card in hand
    const handCard = page.locator('[aria-label="Hand"] button[title]:not([disabled])').first();
    if (await handCard.isVisible()) {
      await handCard.click();
      await page.waitForTimeout(300);

      const emptySlot = page.locator('button[aria-label="Build new room here"]').first();
      if (await emptySlot.isVisible()) {
        await emptySlot.click();
        await page.waitForTimeout(500);
        await shot('play_04_placed.png');
      }
    }

    const passBtn = page.locator('button[aria-label="Pass turn"]');
    if (await passBtn.isVisible()) {
      await passBtn.click();
      await page.waitForTimeout(500);
    }

    // 9. Advance through phases (Wait for BAIT, ADVENTURE, and next BUILD)
    for (let loop = 0; loop < 15; loop++) {
      await page.waitForTimeout(500);

      const resolveBtn = page.locator('button[aria-label="Continue adventure"]');
      if (await resolveBtn.isVisible()) {
        await resolveBtn.click();
        await page.waitForTimeout(400);
      }

      const advPausePass = page.locator('[class*="pauseBanner"] button, [class*="banner"] button').filter({ hasText: /pass/i });
      if (await advPausePass.count() > 0 && await advPausePass.first().isVisible()) {
        await advPausePass.first().click().catch(() => {});
        await page.waitForTimeout(300);
      }

      const phaseTxt = await page.locator('[class*="hud"]').textContent().catch(() => '');
      if (phaseTxt.includes('YOUR TURN')) {
        const cardToBuild = page.locator('[aria-label="Hand"] button[title]:not([disabled])').first();
        if (await cardToBuild.isVisible()) {
          await cardToBuild.click().catch(() => {});
          await page.waitForTimeout(300);
          const emptySlot = page.locator('button[aria-label="Build new room here"]').first();
          if (await emptySlot.isVisible()) {
            await emptySlot.click().catch(() => {});
            await page.waitForTimeout(400);
          }
        }
        const pass = page.locator('button[aria-label="Pass turn"]');
        if (await pass.isVisible()) {
          await pass.click().catch(() => {});
          await page.waitForTimeout(500);
        }
      }

      const gameOver = page.getByText(/VICTORY|DEFEAT/i);
      if (await gameOver.isVisible()) {
        break;
      }
    }

    // 10. Verify Options Overlay In-Game
    const optionsGear = page.locator('button[aria-label="Open options"]');
    if (await optionsGear.isVisible()) {
      await optionsGear.click();
      const optDialog = page.getByRole('dialog', { name: 'Options' });
      await expect(optDialog).toBeVisible();
      await shot('play_options_ingame.png');
      await page.getByRole('button', { name: 'OK' }).click();
      await expect(optDialog).toBeHidden();
    }

    const fatalErrors = consoleErrors.filter((e) => !e.includes('favicon') && !e.includes('ECONNABORTED'));
    expect(fatalErrors).toEqual([]);
  });
});
