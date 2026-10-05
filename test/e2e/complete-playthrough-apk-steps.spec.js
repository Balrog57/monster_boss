import { test, expect } from '@playwright/test';
import path from 'path';
import fs from 'fs';

test.describe('Complete Playthrough APK Steps Verification', () => {
  test('executes every game stage from boot to game-over matching APK 2.2.6 & 10th Anniversary rules', async ({ page }, testInfo) => {
    test.setTimeout(240000);

    const consoleLogs = [];
    const consoleErrors = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
      else consoleLogs.push(msg.text());
    });
    page.on('pageerror', (err) => {
      consoleErrors.push(err.message);
    });

    const outDir = testInfo.outputPath('apk_steps_screenshots');
    fs.mkdirSync(outDir, { recursive: true });
    const shot = async (name) => {
      await page.screenshot({ path: path.join(outDir, name), fullPage: false });
    };

    // =========================================================================
    // ÉTAPE 0 : DÉMARRAGE ET MENU PRINCIPAL (APK 2.2.6)
    // =========================================================================
    console.log('[STAGE 0] Boot & Main Menu');
    await page.goto('/');

    const startBtn = page.getByRole('button', { name: /tap to start/i });
    await expect(startBtn).toBeVisible({ timeout: 15000 });
    await shot('00_boot_title.png');
    await startBtn.click();

    // Skip tutoriel s'il s'affiche
    const skipTut = page.getByRole('button', { name: 'SKIP' });
    try {
      await skipTut.waitFor({ state: 'visible', timeout: 2000 });
      await skipTut.click();
    } catch {
      // Tutoriel déjà vu ou non affiché
    }

    await expect(page.getByText('SINGLE PLAYER')).toBeVisible({ timeout: 10000 });
    await shot('01_main_menu.png');

    // Clic sur SINGLE PLAYER
    await page.getByText('SINGLE PLAYER').click();
    await expect(page.getByText('HOW MANY PLAYERS?')).toBeVisible();
    await shot('02_player_count_select.png');

    // Confirmer 2 Joueurs (Bouton OK)
    const okBtn = page.locator('button[aria-label="OK"]');
    await expect(okBtn).toBeVisible();
    await okBtn.click();

    // =========================================================================
    // ÉTAPE 1 : SÉLECTION DU BOSS (2 distribués, 1 choisi)
    // =========================================================================
    console.log('[STAGE 1] Boss Selection');
    const bossSelect = page.getByRole('dialog', { name: 'Choose your boss' });
    await expect(bossSelect).toBeVisible({ timeout: 15000 });
    await shot('03_boss_select_dialog.png');

    // Vérifier le bouton PLAY BOSS MONSTER et le cliquer
    const playBossBtn = page.getByRole('button', { name: /PLAY /i });
    await expect(playBossBtn).toBeVisible();
    await playBossBtn.click();

    // =========================================================================
    // ÉTAPE 2 : DISTRIBUTION D'OUVERTURE ET DÉFAUSSE (5 Salles + 2 Sorts -> Défausse 2)
    // =========================================================================
    console.log('[STAGE 2] Opening Deal & Discard (7 cards -> discard 2)');
    const discardOverlay = page.getByRole('dialog', { name: 'Select 2 cards to discard' });
    await expect(discardOverlay).toBeVisible({ timeout: 15000 });

    const continueBtn = discardOverlay.getByRole('button', { name: 'Continue' });
    await expect(continueBtn).toBeVisible();
    // Le bouton doit être désactivé tant que 2 cartes ne sont pas sélectionnées
    await expect(continueBtn).toBeDisabled();

    // Sélectionner la 1ère carte
    const discardCards = discardOverlay.getByRole('button', { name: /^Select /i });
    expect(await discardCards.count()).toBeGreaterThanOrEqual(2);
    await discardCards.nth(0).click();
    await expect(continueBtn).toBeDisabled();

    // Sélectionner la 2ème carte
    await discardCards.nth(1).click();
    await expect(continueBtn).toBeEnabled();
    await shot('04_discard_selected_ready.png');

    // Confirmer la défausse
    await continueBtn.click();
    await expect(discardOverlay).toBeHidden({ timeout: 10000 });

    // =========================================================================
    // ÉTAPE 3 : PHASE DE SETUP — CONSTRUCTION DE LA SALLE INITIALE
    // =========================================================================
    console.log('[STAGE 3] Setup Phase - Initial Room Build');
    const gameLog = page.getByRole('log', { name: 'Game log' });
    await expect(gameLog).toBeVisible({ timeout: 15000 });

    // Vérifier les composants authentiques : plaque de phase supérieure, badge de dégâts, XP du boss
    const hud = page.getByRole('status').filter({ has: page.locator('[class*="phaseBadge"]') });
    await expect(hud).toBeVisible();
    const phaseImg = hud.locator('img[class*="phaseImg"]');
    await expect(phaseImg).toBeVisible();

    const damageBadge = page.locator('[class*="metaItem"]').first();
    await expect(damageBadge).toBeVisible();

    const xpBadge = page.locator('[class*="metaXp"]').first();
    await expect(xpBadge).toBeVisible();
    await shot('05_setup_phase_board.png');

    // Attendre que la main soit visible après fermeture de la défausse
    const hand = page.locator('[aria-label="Hand"]');
    await expect(hand).toBeVisible({ timeout: 15000 });

    const isYourTurn = async () => {
      const txt = await hud.textContent().catch(() => '');
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
        await page.waitForTimeout(300);
      }
      return false;
    };

    await waitMyTurn(30000);

    // Poser la 1ère salle (SETUP)
    const handRoomsTab = page.getByRole('button', { name: 'Rooms', exact: true });
    if (await handRoomsTab.isVisible()) {
      await handRoomsTab.click({ force: true });
    }

    const handCards = page.locator('[aria-label="Hand"] > div:nth-child(2) [role="button"]');
    await expect(handCards.first()).toBeVisible({ timeout: 10000 });
    const handCount = await handCards.count();
    expect(handCount).toBeGreaterThan(0);

    // Cliquer sur une salle pour la poser dans le slot 0
    let builtSetup = false;
    for (let i = 0; i < handCount; i++) {
      const card = handCards.nth(i);
      await card.click({ force: true });
      const emptySlot = page.locator('button[aria-label="Build new room here"]');
      if (await emptySlot.count() > 0 && await emptySlot.first().isVisible()) {
        await emptySlot.first().click({ force: true });
        builtSetup = true;
        break;
      }
    }
    await page.waitForTimeout(600);
    await shot('06_after_setup_build.png');

    // =========================================================================
    // ÉTAPE 4 À 8 : CYCLES DE TOURS COMPLETS (BEGINNING, BUILD, BAIT, ADVENTURE, END)
    // =========================================================================
    console.log('[STAGES 4-8] Turn loop progression until Game Over');
    const terminal = page.getByRole('heading', { name: /VICTORY|DEFEAT/i });

    let turnSteps = 0;
    let seenAdventure = false;
    let seenBait = false;
    let lastLog = '';
    let lastProgressTime = Date.now();

    while (!(await terminal.isVisible())) {
      turnSteps++;
      const currentLog = await gameLog.textContent().catch(() => '');
      if (currentLog !== lastLog) {
        lastLog = currentLog;
        lastProgressTime = Date.now();
      }

      if (Date.now() - lastProgressTime > 35000) {
        throw new Error(`Timeout: Pas de progression depuis 35 secondes à l'étape ${turnSteps}. Dernier log: ${lastLog.slice(-200)}`);
      }

      // 1. Pile de sorts active (Spell stack response)
      const stackRegion = page.getByRole('region', { name: 'Spell Stack Active' });
      if (await stackRegion.isVisible()) {
        const passStackBtn = stackRegion.getByRole('button', { name: 'PASS (NO RESPONSE)' });
        if (await passStackBtn.isVisible()) {
          await passStackBtn.click();
          await page.waitForTimeout(200);
          continue;
        }
      }

      // 2. Choix de Level Up (Boss atteint 5 salles)
      const levelUpDialog = page.getByRole('dialog', { name: 'Level up choice' });
      if (await levelUpDialog.isVisible()) {
        const choiceBtn = levelUpDialog.getByRole('button').first();
        if (await choiceBtn.isVisible()) {
          await choiceBtn.click({ force: true });
          await page.waitForTimeout(200);
          continue;
        }
      }

      // 3. Pause d'aventure (Fenêtre de réaction pré/post dégâts)
      const advPauseBtn = page.getByRole('button', { name: 'PASS / CONTINUE', exact: true });
      if (await advPauseBtn.isVisible()) {
        await advPauseBtn.click();
        await page.waitForTimeout(200);
        continue;
      }

      // 4. Avancée d'aventure (Bouton GO du héros)
      const advContinueBtn = page.getByRole('button', { name: 'Continue adventure', exact: true });
      if (await advContinueBtn.isVisible() && await advContinueBtn.isEnabled()) {
        if (!seenAdventure) {
          seenAdventure = true;
          await shot('07_adventure_phase_active.png');
        }
        await advContinueBtn.click({ force: true });
        await page.waitForTimeout(250);
        continue;
      }

      // 5. Statut et tour actif
      const statusText = await hud.textContent().catch(() => '');
      const isMyTurn = statusText.includes('YOUR TURN');
      const phaseAttr = (await hud.getAttribute('aria-label').catch(() => '')) || '';

      if (phaseAttr.toLowerCase().includes('bait') && !seenBait) {
        seenBait = true;
        await shot('08_bait_phase_active.png');
      }

      if (isMyTurn) {
        if (/setup|build/i.test(phaseAttr)) {
          // Tenter de construire une salle si disponible
          if (await handRoomsTab.isVisible()) {
            await handRoomsTab.click({ force: true }).catch(() => {});
          }
          const availableHand = page.locator('[aria-label="Hand"] > div:nth-child(2) > div > [role="button"]');
          let placedRoom = false;
          const count = await availableHand.count();
          for (let i = 0; i < count; i++) {
            await availableHand.nth(i).click({ force: true }).catch(() => {});
            const target = page.locator('button[aria-label="Build new room here"], [class*="mine"] [class*="target"] [role="button"]').first();
            if (await target.isVisible()) {
              await target.click({ force: true }).catch(() => {});
              placedRoom = true;
              break;
            }
          }
          if (!placedRoom) {
            // Passer le tour de construction si aucune pose n'est possible ou désirée
            const passBtn = page.getByRole('button', { name: 'Pass turn', exact: true });
            if (await passBtn.isVisible()) {
              await passBtn.click({ force: true });
            }
          }
        } else {
          // Autres phases où le bouton pass est disponible
          const passBtn = page.getByRole('button', { name: 'Pass turn', exact: true });
          if (await passBtn.isVisible()) {
            await passBtn.click({ force: true });
          }
        }
      }

      await page.waitForTimeout(150);
    }

    // =========================================================================
    // ÉTAPE 9 : ÉCRAN TERMINAL (VICTOIRE OU DÉFAITE) & REJOUER
    // =========================================================================
    console.log('[STAGE 9] Terminal Screen (Victory or Defeat)');
    await expect(terminal).toBeVisible();
    const finalOutcome = (await terminal.textContent()).trim();
    console.log(`[OUTCOME] Game finished with result: ${finalOutcome}`);
    await shot('09_game_over_result.png');

    // Tester l'onglet Bilan Statistique
    const statsTab = page.getByRole('tab', { name: /BILAN STATISTIQUE/i });
    if (await statsTab.isVisible()) {
      await statsTab.click();
      await expect(page.getByText('DÉTAIL DES CONQUÊTES')).toBeVisible({ timeout: 5000 });
      await shot('09b_detailed_stats_tab.png');
    }

    // Vérifier la présence du bouton PLAY AGAIN pour un redémarrage propre
    const playAgainBtn = page.getByRole('button', { name: /play again/i });
    await expect(playAgainBtn).toBeVisible();
    await playAgainBtn.click({ force: true });

    // Vérifier le redémarrage vers l'écran de sélection de partie solo
    await expect(page.getByText('HOW MANY PLAYERS?')).toBeVisible({ timeout: 15000 });
    await shot('10_play_again_setup.png');

    const fatalErrors = consoleErrors.filter((e) => !e.includes('favicon') && !e.includes('ECONNABORTED'));
    expect(fatalErrors).toEqual([]);
    console.log('[SUCCESS] All game stages completed and verified successfully!');
  });
});
