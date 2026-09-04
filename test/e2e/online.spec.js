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
});
