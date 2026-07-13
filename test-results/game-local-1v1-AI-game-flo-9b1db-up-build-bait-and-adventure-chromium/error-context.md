# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: game.spec.js >> local 1v1 AI game flows through setup, build, bait and adventure
- Location: test\game.spec.js:3:1

# Error details

```
TimeoutError: page.waitForSelector: Timeout 20000ms exceeded.
Call log:
  - waiting for locator('text=SETUP') to be visible

```

# Test source

```ts
  1  | import { test, expect } from '@playwright/test';
  2  | 
  3  | test('local 1v1 AI game flows through setup, build, bait and adventure', async ({ page }) => {
  4  |   test.setTimeout(90000);
  5  |   page.on('console', msg => console.log('PAGE:', msg.type(), msg.text()));
  6  |   page.on('pageerror', err => console.log('PAGE ERR:', err.message));
  7  | 
  8  |   await page.goto('http://localhost:8000/');
  9  | 
  10 |   // Main menu: click logo
  11 |   await page.waitForSelector('button[aria-label="Démarrer le jeu"]', { timeout: 10000 });
  12 |   await page.click('button[aria-label="Démarrer le jeu"]');
  13 | 
  14 |   // Setup screen
  15 |   await page.waitForSelector('text=Choisissez le mode de jeu', { timeout: 10000 });
  16 |   await page.click('button:has-text("1 contre 1")');
  17 | 
  18 |   // Boss selection
  19 |   await page.waitForSelector('text=Choisir votre Boss', { timeout: 10000 });
  20 |   // Boss cards are rendered as buttons with a Card image. Click the first one.
  21 |   const bossButton = page.locator('button').filter({ has: page.locator('img') }).filter({ hasText: 'XP' }).first();
  22 |   await bossButton.click();
  23 | 
  24 |   // Setup phase
> 25 |   await page.waitForSelector('text=SETUP', { timeout: 20000 });
     |              ^ TimeoutError: page.waitForSelector: Timeout 20000ms exceeded.
  26 |   // Build initial room - first card in hand
  27 |   const handCard = page.locator('button[title]').first();
  28 |   await handCard.click();
  29 | 
  30 |   // Build phase
  31 |   await page.waitForSelector('text=BUILD', { timeout: 20000 });
  32 |   // The first hand card is buildable
  33 |   const buildCard = page.locator('button[title]').first();
  34 |   await buildCard.click();
  35 |   // Pass
  36 |   await page.waitForSelector('button:has-text("Passer")');
  37 |   await page.click('button:has-text("Passer")');
  38 | 
  39 |   // Bait phase
  40 |   await page.waitForSelector('text=BAIT', { timeout: 20000 });
  41 |   await page.click('button:has-text("Confirmer Bait")');
  42 | 
  43 |   // Adventure phase
  44 |   await page.waitForSelector('text=ADVENTURE', { timeout: 20000 });
  45 |   // Resolve hero (button only shown if entrance has heroes)
  46 |   const advBtn = page.locator('button:has-text("Résoudre")');
  47 |   if (await advBtn.count() > 0) await advBtn.first().click();
  48 |   // If no heroes, just pass to advance
  49 |   const passAdv = page.locator('button:has-text("Passer")');
  50 |   if (await passAdv.count() > 0) await passAdv.first().click();
  51 | 
  52 |   // Next turn
  53 |   await page.waitForSelector('text=BEGINNING', { timeout: 20000 });
  54 | });
  55 | 
```