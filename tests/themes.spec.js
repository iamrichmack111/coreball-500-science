import { test, expect } from '@playwright/test';

test('contains exactly 74 themes and persists selection per player', async ({ page }) => {
  await page.goto('/');
  const count=await page.evaluate(()=>window.__TEST__.THEMES.length);
  expect(count).toBe(74);

  await page.locator('#signupTab').click();
  await page.locator('#signupName').fill('Theme Player');
  await page.locator('#signupEmail').fill('themes@example.com');
  await page.locator('#signupPassword').fill('science123');
  await page.locator('#signupForm .authSubmit').click();
  await expect(page.locator('#authOverlay')).not.toHaveClass(/open/);

  await page.locator('#themeBtn').click();
  await expect(page.locator('#themeGrid .themeCard')).toHaveCount(74);
  await page.locator('[data-theme="matrix-green"]').click();
  const saved=await page.evaluate(()=>window.__TEST__.accounts()['themes@example.com'].progress.theme);
  expect(saved).toBe('matrix-green');
});
