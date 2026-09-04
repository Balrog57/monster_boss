import { expect } from '@playwright/test';

export async function playStep(page) {
  const stack = page.getByRole('region', { name: 'Spell Stack Active' });
  if (await stack.isVisible()) {
    const pass = stack.getByRole('button', { name: 'PASS (NO RESPONSE)' });
    if (await pass.isVisible()) await pass.click();
    return;
  }
  const choice = page.getByRole('dialog', { name: 'Level up choice' });
  if (await choice.isVisible()) {
    await choice.getByRole('button').first().click();
    return;
  }
  const pause = page.getByRole('button', { name: 'PASS / CONTINUE', exact: true });
  if (await pause.isVisible()) { await pause.click(); return; }
  const next = page.getByRole('button', { name: 'Continue adventure', exact: true });
  if (await next.isVisible() && await next.isEnabled()) { await next.click(); return; }
  const status = page.getByRole('status').filter({ has: page.locator('[class*="phaseBadge"]') });
  if (!(await status.textContent()).includes('YOUR TURN')) return;
  const phase = await status.getAttribute('aria-label');
  if (/setup|build/i.test(phase)) {
    await page.getByRole('button', { name: 'Rooms', exact: true }).click();
    const cards = page.locator('[aria-label="Hand"] > div:nth-child(2) [role="button"]');
    for (let i = 0; i < await cards.count(); i++) {
      await cards.nth(i).click();
      if (/setup/i.test(phase)) return;
      const target = page.locator('button[aria-label="Build new room here"], [class*="mine"] [class*="target"] [role="button"]').first();
      if (await target.isVisible()) { await target.click(); return; }
    }
  }
  const pass = page.getByRole('button', { name: 'Pass turn', exact: true });
  if (await pass.isVisible()) await pass.click();
}

export async function playUntilGameOver(page, { peers = [], screenshotPath } = {}) {
  const terminal = page.getByRole('heading', { name: /^(VICTORY|DEFEAT)$/ });
  let previous = '';
  let changedAt = Date.now();
  while (!(await terminal.isVisible())) {
    for (const p of [page, ...peers]) {
      if (!(await p.getByRole('heading', { name: /^(VICTORY|DEFEAT)$/ }).isVisible())) await playStep(p);
    }
    const snapshot = await page.getByRole('log', { name: 'Game log' }).textContent();
    if (snapshot !== previous) { previous = snapshot; changedAt = Date.now(); }
    if (Date.now() - changedAt > 15000) throw new Error('No game progress for 15 seconds: ' + snapshot);
    await page.waitForTimeout(100);
  }
  if (screenshotPath) await page.screenshot({ path: screenshotPath });
  await expect(terminal).toBeVisible();
  return (await terminal.textContent()).trim().toLowerCase();
}

export async function startSoloGame(page) {
  await page.goto('/');
  const startBtn = page.getByRole('button', { name: /tap to start/i });
  await startBtn.waitFor({ state: 'visible', timeout: 15000 });
  await startBtn.click();

  const skipTut = page.getByRole('button', { name: 'SKIP' });
  await skipTut.waitFor({ state: 'visible', timeout: 2000 }).catch(() => {});
  if (await skipTut.isVisible()) await skipTut.click();

  await page.getByText('SINGLE PLAYER').click();
  await page.locator('button[aria-label="OK"]').click();

  const bossSelect = page.getByRole('dialog', { name: 'Choose your boss' });
  await bossSelect.waitFor({ state: 'visible', timeout: 15000 });
  await page.getByRole('button', { name: /Play /i }).click();

  const discardOverlay = page.getByRole('dialog', { name: 'Select 2 cards to discard' });
  await discardOverlay.waitFor({ state: 'visible', timeout: 15000 });
  const discardCards = discardOverlay.getByRole('button', { name: /^Select /i });
  await discardCards.nth(0).click();
  await discardCards.nth(1).click();
  await discardOverlay.getByRole('button', { name: 'Continue' }).click();
  await discardOverlay.waitFor({ state: 'hidden', timeout: 10000 });

  await page.getByRole('log', { name: 'Game log' }).waitFor({ state: 'visible', timeout: 15000 });
}
