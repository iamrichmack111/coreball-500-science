import { test, expect } from '@playwright/test';
import fs from 'fs';

test('capture game and science quiz screenshots', async ({ page }) => {
  fs.mkdirSync('media/screenshots', { recursive: true });

  await page.goto('/');
  await page.screenshot({
    path: 'media/screenshots/01-game.png',
    fullPage: true
  });

  await page.evaluate(() => window.__TEST__.forceCrash());
  await page.waitForTimeout(500);
  await expect(page.locator('#quizBack')).toHaveClass(/open/);
  await page.screenshot({
    path: 'media/screenshots/02-science-bonus.png',
    fullPage: true
  });
});
