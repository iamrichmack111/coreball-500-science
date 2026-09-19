import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const mediaDir = path.resolve('media');
const videoDir = path.join(mediaDir, 'raw-video');
fs.mkdirSync(mediaDir, { recursive: true });
fs.mkdirSync(videoDir, { recursive: true });

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({
  viewport: { width: 1280, height: 900 },
  recordVideo: {
    dir: videoDir,
    size: { width: 1280, height: 900 }
  }
});
const page = await context.newPage();

await page.goto('http://127.0.0.1:4173');
await page.waitForTimeout(1000);

// Opening view.
await page.screenshot({ path: path.join(mediaDir, 'demo-cover.png'), fullPage: true });
await page.waitForTimeout(900);

// Demonstrate several successful timed shots by using the game's validated helper.
for (let i = 0; i < 3; i++) {
  await page.evaluate(() => window.__TEST__.safeShot());
  await page.waitForTimeout(500);
}

// Demonstrate slow motion.
await page.locator('#slow').click();
await page.waitForTimeout(1400);

// Force a collision to show the science save.
await page.evaluate(() => window.__TEST__.forceCrash());
await page.waitForTimeout(600);

// Answer correctly and continue.
await page.evaluate(() => window.__TEST__.answerCorrect());
await page.waitForTimeout(1000);
await page.locator('#continueBtn').click();
await page.waitForTimeout(1000);

// Show a clean level again.
for (let i = 0; i < 2; i++) {
  await page.evaluate(() => window.__TEST__.safeShot());
  await page.waitForTimeout(450);
}

const video = page.video();
await context.close();
const rawPath = await video.path();
await browser.close();

fs.copyFileSync(rawPath, path.join(mediaDir, 'coreball-demo.webm'));
console.log('Created media/coreball-demo.webm');
