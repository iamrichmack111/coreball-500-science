import { test, expect } from '@playwright/test';

async function signup(page, suffix='smoke') {
  await page.goto('/');
  await page.locator('#signupTab').click();
  await page.locator('#signupName').fill('Test Player');
  await page.locator('#signupEmail').fill(`${suffix}@example.com`);
  await page.locator('#signupPassword').fill('science123');
  await page.locator('#signupForm .authSubmit').click();
  await expect(page.locator('#authOverlay')).not.toHaveClass(/open/);
}

test('signup enters the game and profile appears', async ({ page }) => {
  await signup(page, 'signup-test');
  await expect(page.locator('#playerName')).toHaveText('Test Player');
  await expect(page.locator('#level')).toHaveText('1');
  await expect(page.locator('#fire')).toBeVisible();
  await expect(page.locator('#game')).toBeVisible();
});

test('science bonus quiz opens after a forced collision', async ({ page }) => {
  await signup(page, 'science-test');
  await page.evaluate(() => window.__TEST__.forceCrash());
  await page.waitForTimeout(500);
  await expect(page.locator('#quizBack')).toHaveClass(/open/);
  await expect(page.locator('#question')).not.toHaveText('');
});

test('correct science answer restores a heart', async ({ page }) => {
  await signup(page, 'heart-test');
  await page.evaluate(() => window.__TEST__.forceCrash());
  await page.waitForTimeout(500);
  const before = await page.evaluate(() => window.__TEST__.state.lives);
  await page.evaluate(() => window.__TEST__.answerCorrect());
  const after = await page.evaluate(() => window.__TEST__.state.lives);
  expect(after).toBeGreaterThan(before);
});

test('logout returns to login screen', async ({ page }) => {
  await signup(page, 'logout-test');
  await page.locator('#logoutBtn').click();
  await expect(page.locator('#authOverlay')).toHaveClass(/open/);
});
