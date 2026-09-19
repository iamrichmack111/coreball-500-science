import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';

const mediaDir=path.resolve('media');
const videoDir=path.join(mediaDir,'raw-video');
fs.mkdirSync(mediaDir,{recursive:true});
fs.mkdirSync(videoDir,{recursive:true});

const browser=await chromium.launch({headless:true});
const context=await browser.newContext({
  viewport:{width:1280,height:900},
  recordVideo:{dir:videoDir,size:{width:1280,height:900}}
});
const page=await context.newPage();

await page.goto('http://127.0.0.1:4173');
await page.waitForTimeout(900);

// Show polished login and signup.
await page.locator('#signupTab').click();
await page.locator('#signupName').fill('Demo Player');
await page.locator('#signupEmail').fill('demo@example.com');
await page.locator('#signupPassword').fill('science123');
await page.waitForTimeout(800);
await page.locator('#signupForm .authSubmit').click();
await page.waitForTimeout(1100);

await page.screenshot({path:path.join(mediaDir,'demo-cover.png'),fullPage:true});

// Gameplay.
for(let i=0;i<3;i++){
  await page.evaluate(()=>window.__TEST__.safeShot());
  await page.waitForTimeout(520);
}

await page.locator('#slow').click();
await page.waitForTimeout(1100);

await page.evaluate(()=>window.__TEST__.forceCrash());
await page.waitForTimeout(700);
await page.evaluate(()=>window.__TEST__.answerCorrect());
await page.waitForTimeout(900);
await page.locator('#continueBtn').click();
await page.waitForTimeout(900);

const video=page.video();
await context.close();
const raw=await video.path();
await browser.close();

fs.copyFileSync(raw,path.join(mediaDir,'coreball-demo.webm'));
console.log('Created media/coreball-demo.webm');
