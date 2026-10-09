import { test, expect } from '@playwright/test';
import { playUntilGameOver } from './helpers/play-until-game-over.js';

async function enterMultiplayer(page) {
  await page.goto('/');
  await page.getByRole('button', { name: /tap to start/i }).click();
  const skip = page.getByRole('button', { name: 'SKIP' });
  await skip.waitFor({ state: 'visible', timeout: 2000 }).catch(() => {});
  if (await skip.isVisible()) await skip.click();
  await page.getByRole('button', { name: /multiplayer/i }).click();
}

test.describe('Online multiplayer', () => {
  test('two browsers create, reconnect and finish a synchronized game', async ({ browser }, testInfo) => {
    test.setTimeout(180000);
    const host = await browser.newPage();
    const guest = await browser.newPage();
    const errors = [];
    const states = new Map();
    for (const page of [host, guest]) {
      page.on('pageerror', e => errors.push(e.message));
      page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
      page.on('websocket', socket => socket.on('framereceived', ({ payload }) => {
        if (typeof payload !== 'string' || !payload.startsWith('42[')) return;
        const [event, data] = JSON.parse(payload.slice(2));
        if (event === 'match:state') states.set(page, data);
        if (event === 'match:error') errors.push(data.message);
      }));
    }

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

    await host.getByRole('button', { name: /^Play / }).click();
    await expect(host.getByText('YOUR BOSS', { exact: true })).toBeVisible();
    await guest.getByRole('button', { name: /^Play / }).click();
    for (const page of [host, guest]) {
      const discard = page.getByRole('dialog', { name: 'Select 2 cards to discard' });
      await expect(discard).toBeVisible();
      await discard.getByRole('button', { name: /^Select / }).nth(0).click();
      await discard.getByRole('button', { name: /^Select / }).nth(1).click();
      await discard.getByRole('button', { name: 'Continue' }).click();
      await expect(discard).toBeHidden();
    }
    // Hard reconnect: reload restores the seat from localStorage and re-joins.
    const previousState = states.get(guest);
    expect(previousState).toBeTruthy();
    await guest.reload();
    await expect(guest.getByRole('log', { name: 'Game log' })).toBeVisible({ timeout: 20000 });
    await expect.poll(() => states.get(guest) !== previousState, { timeout: 15000 }).toBe(true);
    const outcome = await playUntilGameOver(host, { peers: [guest], screenshotPath: testInfo.outputPath('online-host.png') });
    await expect(guest.getByRole('heading', { name: outcome === 'victory' ? 'DEFEAT' : 'VICTORY', exact: true })).toBeVisible();
    await guest.screenshot({ path: testInfo.outputPath('online-guest.png') });
    const publicState = page => {
      const { G, ctx } = states.get(page);
      return { ctx, turn: G.turn, winner: G.winner, gameOver: G.gameOver,
        players: Object.values(G.players).map(({ boss, dungeon, souls, wounds }) => ({ boss, dungeon, souls, wounds })) };
    };
    expect(publicState(host)).toEqual(publicState(guest));
    expect(publicState(host).gameOver).toBe(true);
    expect(errors).toEqual([]);

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

  test('host can add an AI bot to start and play online match against AI', async ({ page }) => {
    test.setTimeout(60000);
    await enterMultiplayer(page);
    await page.locator('#lobby-name').fill('SoloOnline');
    await page.getByRole('button', { name: /create room/i }).click();
    await expect(page.getByText(/SEARCHING/i)).toBeVisible({ timeout: 10000 });

    const addBotBtn = page.getByRole('button', { name: /AJOUTER UN BOT IA/i });
    await expect(addBotBtn).toBeVisible({ timeout: 10000 });
    await addBotBtn.click();

    // Match immediately starts with 1 human + 1 AI bot!
    await expect(page.getByText(/Preparing game|PLAY BOSS|boss/i).first()).toBeVisible({ timeout: 30000 });
    await page.getByRole('button', { name: /^Play / }).click();

    // Opening discard overlay
    const discard = page.getByRole('dialog', { name: 'Select 2 cards to discard' });
    await expect(discard).toBeVisible({ timeout: 15000 });
    const count = await discard.getByRole('button', { name: /^Select / }).count();
    await discard.getByRole('button', { name: /^Select / }).nth(count - 1).click();
    await discard.getByRole('button', { name: /^Select / }).nth(count - 2).click();
    await discard.getByRole('button', { name: 'Continue' }).click();
    await expect(discard).toBeHidden({ timeout: 10000 });

    // In-game board appears with AI opponent listed
    await expect(page.locator('[aria-label="Hand"]')).toBeVisible({ timeout: 15000 });
    await expect(page.getByRole('status', { name: /Phase /i })).toBeVisible({ timeout: 10000 });
  });

  test('host can toggle expansion packs and copy invite share link in waiting room', async ({ browser }) => {
    const context = await browser.newContext();
    await context.grantPermissions(['clipboard-read', 'clipboard-write']);
    const page = await context.newPage();

    await enterMultiplayer(page);
    await page.locator('#lobby-name').fill('PackHost');

    // Toggle The Next Level pack
    const tnlChip = page.getByRole('button', { name: /THE NEXT LEVEL/i });
    await expect(tnlChip).toBeVisible();
    await tnlChip.click();

    // Create room
    await page.getByRole('button', { name: /create room/i }).click();
    await expect(page.locator('[class*="codeBox"]')).toBeVisible({ timeout: 10000 });

    // Verify packs displayed in waiting room
    await expect(page.getByText(/THE NEXT LEVEL/i)).toBeVisible();

    // Copy share link button exists and triggers feedback
    const copyBtn = page.getByRole('button', { name: /COPIER LE LIEN D'INVITATION/i });
    await expect(copyBtn).toBeVisible();
    await copyBtn.click();
    await expect(page.getByText(/LIEN COPIÉ/i)).toBeVisible();

    await context.close();
  });

  test('direct invite link url query ?join=CODE pre-fills code and allows quick join', async ({ page }) => {
    await page.goto('/?join=TEST99');
    // Opens directly on multiplayer lobby screen with CODE pre-filled
    await expect(page.locator('#lobby-code')).toHaveValue('TEST99', { timeout: 10000 });
  });

  test('public matches list displays open lobbies with 1-click join', async ({ browser }) => {
    const host = await browser.newPage();
    const guest = await browser.newPage();

    await enterMultiplayer(host);
    await host.locator('#lobby-name').fill('PublicHost');
    await host.getByRole('button', { name: /create room/i }).click();
    await expect(host.locator('[class*="codeBox"]')).toBeVisible({ timeout: 10000 });
    const code = (await host.locator('[class*="codeBox"]').textContent())?.trim();

    await enterMultiplayer(guest);
    await guest.locator('#lobby-name').fill('PublicGuest');

    // The public room should appear in the public list on the right
    await expect(guest.getByText(code)).toBeVisible({ timeout: 10000 });
    await expect(guest.getByText(/PublicHost/i)).toBeVisible();

    // Click quick join on the public lobby item
    const publicItem = guest.locator('[class*="publicItem"]', { hasText: code });
    await publicItem.getByRole('button', { name: /REJOINDRE/i }).click();

    // Both players enter the match
    await expect(host.getByText(/Preparing game|PLAY BOSS|boss/i).first()).toBeVisible({ timeout: 30000 });
    await expect(guest.getByText(/Preparing game|PLAY BOSS|boss/i).first()).toBeVisible({ timeout: 30000 });

    await host.close();
    await guest.close();
  });

  test('players can trigger retro emotes and display 8-bit speech bubbles', async ({ browser }) => {
    const host = await browser.newPage();
    const guest = await browser.newPage();

    await enterMultiplayer(host);
    await host.locator('#lobby-name').fill('EmoteHost');
    await host.getByRole('button', { name: /create room/i }).click();
    await expect(host.locator('[class*="codeBox"]')).toBeVisible({ timeout: 10000 });
    const code = (await host.locator('[class*="codeBox"]').textContent())?.trim();

    await enterMultiplayer(guest);
    await guest.locator('#lobby-name').fill('EmoteGuest');
    await guest.locator('#lobby-code').fill(code);
    await guest.getByRole('button', { name: /^join$/i }).click();

    // Both select bosses
    await expect(host.getByText(/Preparing game|PLAY BOSS|boss/i).first()).toBeVisible({ timeout: 30000 });
    await expect(guest.getByText(/Preparing game|PLAY BOSS|boss/i).first()).toBeVisible({ timeout: 30000 });
    await host.getByRole('button', { name: /^Play / }).click();
    await guest.getByRole('button', { name: /^Play / }).click();

    // Discard
    for (const page of [host, guest]) {
      const discard = page.getByRole('dialog', { name: 'Select 2 cards to discard' });
      await expect(discard).toBeVisible({ timeout: 15000 });
      await discard.getByRole('button', { name: /^Select / }).nth(0).click();
      await discard.getByRole('button', { name: /^Select / }).nth(1).click();
      await discard.getByRole('button', { name: 'Continue' }).click();
      await expect(discard).toBeHidden({ timeout: 10000 });
    }

    // Host clicks Emotes button
    const emoteBtn = host.getByRole('button', { name: /Émotes/i });
    await expect(emoteBtn).toBeVisible({ timeout: 10000 });
    await emoteBtn.click();

    // Emote bar appears with retro buttons
    const ggBtn = host.getByRole('button', { name: 'GG !' });
    await expect(ggBtn).toBeVisible({ timeout: 5000 });
    await ggBtn.click();

    // Speech bubble appears on host's boss for both host and guest!
    await expect(host.locator('[class*="speechBubble"]').filter({ hasText: 'GG !' })).toBeVisible({ timeout: 5000 });
    await expect(guest.locator('[class*="speechBubble"]').filter({ hasText: 'GG !' })).toBeVisible({ timeout: 5000 });

    await host.close();
    await guest.close();
  });
});


