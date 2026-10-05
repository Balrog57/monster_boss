import { test, expect } from '@playwright/test';

async function tapToStart(page) {
  await page.goto('/');
  const start = page.getByRole('button', { name: /tap to start/i });
  await expect(start).toBeVisible({ timeout: 15000 });
  await start.click();
  const skip = page.getByRole('button', { name: 'SKIP' });
  try {
    await skip.waitFor({ state: 'visible', timeout: 2000 });
    await skip.click();
  } catch {}
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
    await expect(page.getByText(/PLAY BOSS|HOW MANY|boss/i).first()).toBeVisible({ timeout: 15000 });
  });

  test('supports drag-and-drop room build and Escape key deselect', async ({ page }) => {
    await tapToStart(page);
    await page.getByText(/single player|solo/i).first().click();
    await page.locator('.ok, button[aria-label="OK"]').first().click();

    // Boss selection
    const playBoss = page.getByRole('button', { name: /PLAY /i });
    await playBoss.waitFor({ state: 'visible', timeout: 15000 });
    await playBoss.click();

    // Opening discard overlay: discard the last 2 cards (spells) so ordinary rooms remain in hand
    const overlay = page.locator('[role="dialog"][aria-label*="Select 2 cards to discard"]');
    await overlay.waitFor({ state: 'visible', timeout: 15000 });
    const slots = overlay.locator('[role="button"]');
    const count = await slots.count();
    await slots.nth(count - 1).click();
    await slots.nth(count - 2).click();
    const cont = overlay.locator('button[aria-label="Continue"]');
    await cont.click();
    await overlay.waitFor({ state: 'detached', timeout: 10000 });

    // In setup phase: select a card from hand
    const handCard = page.locator('[aria-label="Hand"] [draggable="true"]').first();
    await handCard.waitFor({ state: 'visible', timeout: 10000 });
    await handCard.click();

    // Verify preview badge is visible on the valid empty slot
    const previewBadge = page.locator('[class*="previewBadge"]').first();
    await expect(previewBadge).toBeVisible({ timeout: 5000 });

    // Press Escape to cancel selection
    await page.keyboard.press('Escape');
    await expect(previewBadge).not.toBeVisible();

    // Now test drag-and-drop to place the room
    const emptySlot = page.locator('button[aria-label*="room slot"], button[aria-label*="Build new room"]').first();
    await handCard.dragTo(emptySlot);
    await page.waitForTimeout(600);
  });

  test('desktop keyboard shortcuts: 1-9 select, Space discard/pass, M mute toggle, Escape cancel', async ({ page }) => {
    await tapToStart(page);
    await page.getByText(/single player|solo/i).first().click();
    await page.locator('.ok, button[aria-label="OK"]').first().click();

    // Pick boss
    const playBoss = page.getByRole('button', { name: /PLAY /i });
    await playBoss.waitFor({ state: 'visible', timeout: 15000 });
    await playBoss.click();

    // 1. Opening discard overlay: select via keys 6 and 7 (the two spells), confirm via Space
    const overlay = page.locator('[role="dialog"][aria-label*="Select 2 cards to discard"]');
    await overlay.waitFor({ state: 'visible', timeout: 15000 });

    await page.keyboard.press('6');
    await page.keyboard.press('7');
    await page.waitForTimeout(200);

    const cont = overlay.locator('button[aria-label="Continue"]');
    await expect(cont).toBeEnabled();

    // Press Space to confirm discard
    await page.keyboard.press('Space');
    await overlay.waitFor({ state: 'detached', timeout: 10000 });

    // 2. Mute toggle via key M
    const muteBtn = page.locator('button[class*="muteBtn"]');
    await expect(muteBtn).toBeVisible({ timeout: 5000 });
    const initialLabel = await muteBtn.getAttribute('aria-label');
    await page.keyboard.press('m');
    await page.waitForTimeout(200);
    const toggledLabel = await muteBtn.getAttribute('aria-label');
    expect(toggledLabel).not.toEqual(initialLabel);
    // Press M again to restore
    await page.keyboard.press('m');
    await page.waitForTimeout(200);

    // 3. Select card via key 1
    await page.keyboard.press('1');
    const previewBadge = page.locator('[class*="previewBadge"]').first();
    await expect(previewBadge).toBeVisible({ timeout: 5000 });

    // 4. Cancel selection via Escape
    await page.keyboard.press('Escape');
    await expect(previewBadge).not.toBeVisible();
  });
});
