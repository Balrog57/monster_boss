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

  test('player can toggle expansion packs in solo setup before launching game', async ({ page }) => {
    await tapToStart(page);
    await page.getByText(/single player|solo/i).first().click();
    await expect(page.getByText('HOW MANY PLAYERS?')).toBeVisible();

    // Expansion packs section is visible
    await expect(page.getByText('EXTENSIONS DISPONIBLES')).toBeVisible();

    // Toggle The Next Level pack
    const tnlPack = page.getByRole('button', { name: /THE NEXT LEVEL/i });
    await expect(tnlPack).toBeVisible();
    await tnlPack.click();
    await expect(tnlPack.getByText('✓ ACTIF')).toBeVisible();

    // Start game
    await page.locator('.ok, button[aria-label="OK"]').first().click();
    await expect(page.getByText(/PLAY BOSS|boss/i).first()).toBeVisible({ timeout: 15000 });
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

    // 3. Select buildable room card via its keyboard badge
    const buildableCard = page.locator('[aria-label="Hand"] [draggable="true"]').first();
    await buildableCard.waitFor({ state: 'visible', timeout: 10000 });
    const keyText = (await buildableCard.locator('[class*="keyBadge"]').innerText()).trim();
    await page.keyboard.press(keyText);
    const previewBadge = page.locator('[class*="previewBadge"]').first();
    await expect(previewBadge).toBeVisible({ timeout: 5000 });

    // 4. Cancel selection via Escape
    await page.keyboard.press('Escape');
    await expect(previewBadge).not.toBeVisible();
  });

  test('comprehensive card gallery almanac: tabs, search, treasure filter and inspect', async ({ page }) => {
    await tapToStart(page);

    // Open Options -> Card Gallery
    const optionsBtn = page.getByRole('button', { name: 'OPTIONS' });
    await expect(optionsBtn).toBeVisible({ timeout: 10000 });
    await optionsBtn.click();

    const galleryBtn = page.getByRole('button', { name: 'CARD GALLERY' });
    await expect(galleryBtn).toBeVisible({ timeout: 5000 });
    await galleryBtn.click();

    // Verify dialog and title
    const galleryDialog = page.locator('[role="dialog"][aria-label="Almanach et galerie de cartes"]');
    await expect(galleryDialog).toBeVisible({ timeout: 5000 });
    await expect(page.getByText('ALMANACH & GALERIE DES CARTES')).toBeVisible();

    // Verify tabs
    await expect(page.getByRole('tab', { name: /BOSSES/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /SALLES/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /SORTS/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /HÉROS/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /MINIBOSS/i })).toBeVisible();
    await expect(page.getByRole('tab', { name: /OBJETS/i })).toBeVisible();

    // Switch to Salles (rooms)
    await page.getByRole('tab', { name: /SALLES/i }).click();

    // Search for a specific room: "Bottomless Pit"
    const searchInput = page.getByPlaceholder('Rechercher par nom, effet, sous-type, id...');
    await expect(searchInput).toBeVisible();
    await searchInput.fill('Bottomless');

    // Should find Bottomless Pit
    const cardTile = galleryDialog.getByRole('button', { name: /Bottomless Pit/i });
    await expect(cardTile).toBeVisible();

    // Click card to inspect
    await cardTile.click();

    // DetailPanel inspect dialog should be visible
    const detailPanel = page.getByRole('dialog', { name: 'Bottomless Pit' });
    await expect(detailPanel).toBeVisible({ timeout: 5000 });

    // Press Escape to close detail inspection
    await page.keyboard.press('Escape');
    await expect(detailPanel).not.toBeVisible();

    // Filter by treasure "OR"
    await searchInput.fill('');
    const treasureGoldBtn = galleryDialog.getByRole('button', { name: 'OR', exact: true });
    await treasureGoldBtn.click();
    await page.waitForTimeout(300);

    // Verify badge shows filtered count
    await expect(galleryDialog.locator('[class*="countBadge"]')).toContainText('carte(s)');

    // Close gallery via Escape
    await page.keyboard.press('Escape');
    await expect(galleryDialog).not.toBeVisible();
  });

  test('audio settings and in-game options: volume sliders, track selector and sound test', async ({ page }) => {
    await tapToStart(page);

    // 1. Check MainMenu settings: Track selector
    const optionsBtn = page.getByRole('button', { name: 'OPTIONS' });
    await expect(optionsBtn).toBeVisible({ timeout: 10000 });
    await optionsBtn.click();

    const settingsBtn = page.getByRole('button', { name: 'SETTINGS' });
    await expect(settingsBtn).toBeVisible({ timeout: 5000 });
    await settingsBtn.click();

    // Verify TRACK buttons
    const dungeonTrack = page.getByRole('button', { name: 'DUNGEON' });
    const tavernTrack = page.getByRole('button', { name: 'TAVERN' });
    await expect(dungeonTrack).toBeVisible();
    await expect(tavernTrack).toBeVisible();
    await dungeonTrack.click();
    await expect(dungeonTrack).toHaveClass(/choiceOn/);

    // Go back to main menu
    const backBtn = page.locator('button[class*="back"]').first();
    await backBtn.click();
    await page.waitForTimeout(200);
    const backRoot = page.locator('button[class*="back"]').first();
    await backRoot.click();

    // 2. Start Solo game
    await page.getByText(/single player|solo/i).first().click();
    await page.locator('.ok, button[aria-label="OK"]').first().click();

    // Pick boss
    const playBoss = page.getByRole('button', { name: /PLAY /i });
    await playBoss.waitFor({ state: 'visible', timeout: 15000 });
    await playBoss.click();

    // Opening discard overlay: discard last 2 cards
    const overlay = page.locator('[role="dialog"][aria-label*="Select 2 cards to discard"]');
    await overlay.waitFor({ state: 'visible', timeout: 15000 });
    const slots = overlay.locator('[role="button"]');
    const count = await slots.count();
    await slots.nth(count - 1).click();
    await slots.nth(count - 2).click();
    const cont = overlay.locator('button[aria-label="Continue"]');
    await cont.click();
    await overlay.waitFor({ state: 'detached', timeout: 10000 });

    // Open in-game options overlay via HUD options button
    const hudOptions = page.getByRole('button', { name: /Open options/i });
    await expect(hudOptions).toBeVisible({ timeout: 5000 });
    await hudOptions.click();

    const optionsDialog = page.locator('[role="dialog"][aria-label="Options"]');
    await expect(optionsDialog).toBeVisible({ timeout: 5000 });
    await expect(page.getByText('OPTIONS AUDIO & JEU')).toBeVisible();

    // Verify sliders exist
    await expect(optionsDialog.locator('input[aria-label="Master volume"]')).toBeVisible();
    await expect(optionsDialog.locator('input[aria-label="Music volume"]')).toBeVisible();
    await expect(optionsDialog.locator('input[aria-label="SFX volume"]')).toBeVisible();

    // Test sound button
    const testSfxBtn = optionsDialog.getByRole('button', { name: /TESTER LE SON/i });
    await expect(testSfxBtn).toBeVisible();
    await testSfxBtn.click();

    // Switch music track in options
    const optTavern = optionsDialog.getByRole('button', { name: /Taverne & Menu/i });
    await expect(optTavern).toBeVisible();
    await optTavern.click();
    await expect(optTavern).toHaveClass(/trackBtnOn/);

    // Close Options via OK button
    const okBtn = optionsDialog.getByRole('button', { name: 'OK' });
    await okBtn.click();
    await expect(optionsDialog).not.toBeVisible();
  });
});


