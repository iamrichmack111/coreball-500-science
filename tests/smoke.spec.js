import { test, expect } from '@playwright/test';

test('game loads and core UI is present', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('#level')).toHaveText('1');
  await expect(page.locator('#fire')).toBeVisible();
  await expect(page.locator('#slow')).toBeVisible();
  await expect(page.locator('#lifeBtn')).toBeVisible();
  await expect(page.locator('#game')).toBeVisible();
});

test('science bonus quiz opens after a forced collision', async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => window.__TEST__.forceCrash());
  await page.waitForTimeout(500);
  await expect(page.locator('#quizBack')).toHaveClass(/open/);
  await expect(page.locator('#question')).not.toHaveText('');
});

test('correct science answer restores a heart', async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => window.__TEST__.forceCrash());
  await page.waitForTimeout(500);
  const before = await page.evaluate(() => window.__TEST__.state.lives);
  await page.evaluate(() => window.__TEST__.answerCorrect());
  const after = await page.evaluate(() => window.__TEST__.state.lives);
  expect(after).toBeGreaterThan(before);
});
