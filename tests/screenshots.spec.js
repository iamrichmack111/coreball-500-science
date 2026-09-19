import { test, expect } from '@playwright/test';
import fs from 'fs';

const shots = 'media/screenshots';

async function freshSignup(page) {
  await page.goto('/');
  await page.locator('#signupTab').click();
  await page.locator('#signupName').fill('Science Player');
  await page.locator('#signupEmail').fill('screenshots@example.com');
  await page.locator('#signupPassword').fill('science123');
  await page.locator('#signupForm .authSubmit').click();
  await expect(page.locator('#authOverlay')).not.toHaveClass(/open/);
  await page.waitForTimeout(350);
}

async function chooseTheme(page, id) {
  await page.locator('#themeBtn').click();
  await expect(page.locator('#themeOverlay')).toHaveClass(/open/);
  await page.locator(`[data-theme="${id}"]`).click();
  await page.waitForTimeout(180);
  await page.locator('#themeClose').click();
  await expect(page.locator('#themeOverlay')).not.toHaveClass(/open/);
  await page.waitForTimeout(250);
}

async function snap(page, name) {
  await page.screenshot({ path: `${shots}/${name}`, fullPage: true });
}

test('retake complete V20 screenshot gallery', async ({ page }) => {
  fs.rmSync(shots, { recursive: true, force: true });
  fs.mkdirSync(shots, { recursive: true });

  await page.goto('/');
  await page.waitForTimeout(300);
  await snap(page, '01-login.png');

  await page.locator('#signupTab').click();
  await snap(page, '02-signup.png');

  await page.locator('#signupName').fill('Science Player');
  await page.locator('#signupEmail').fill('screenshots@example.com');
  await page.locator('#signupPassword').fill('science123');
  await page.locator('#signupForm .authSubmit').click();
  await expect(page.locator('#authOverlay')).not.toHaveClass(/open/);
  await page.waitForTimeout(400);
  await snap(page, '03-classic-home.png');

  await page.evaluate(() => window.__TEST__.safeShot());
  await page.waitForTimeout(320);
  await page.evaluate(() => window.__TEST__.safeShot());
  await page.waitForTimeout(320);
  await snap(page, '04-gameplay.png');

  await page.locator('#themeBtn').click();
  await expect(page.locator('#themeGrid .themeCard')).toHaveCount(74);
  await snap(page, '05-theme-picker-74.png');
  await page.locator('#themeClose').click();

  const previews = [
    ['matrix-green','06-theme-matrix-green.png'],
    ['electric-blue','07-theme-electric-blue.png'],
    ['synthwave','08-theme-synthwave.png'],
    ['royal-gold','09-theme-royal-gold.png'],
    ['fire-ice','10-theme-fire-and-ice.png'],
    ['science-lab','11-theme-science-lab.png'],
    ['vaporwave','12-theme-vaporwave.png'],
    ['atlantis','13-theme-atlantis.png']
  ];

  for (const [id, file] of previews) {
    await chooseTheme(page, id);
    await snap(page, file);
  }

  await chooseTheme(page, 'neon-purple');
  await page.evaluate(() => window.__TEST__.forceCrash());
  await page.waitForTimeout(520);
  await expect(page.locator('#quizBack')).toHaveClass(/open/);
  await snap(page, '14-science-question.png');

  await page.evaluate(() => window.__TEST__.answerCorrect());
  await page.waitForTimeout(250);
  await snap(page, '15-science-correct.png');

  await page.locator('#continueBtn').click();
  await page.waitForTimeout(300);
  await page.locator('#lifeBtn').click();
  await page.locator('#lifeBtn').click();
  await page.waitForTimeout(200);
  await snap(page, '16-seven-heart-mode.png');
});
