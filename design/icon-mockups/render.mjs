import { writeFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
import { all } from './concepts.mjs';

// Renders each concept to svg/<name>.svg and a 1024px png/<name>.png with headless Chromium.
// Usage: node render.mjs [concept]
let pw;
try { pw = await import('playwright'); } catch { pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright'); }
const { chromium } = pw;

mkdirSync('svg', { recursive: true }); mkdirSync('png', { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
for (const [name, fn] of Object.entries(all)) {
  if (process.argv[2] && process.argv[2] !== name) continue;
  const svg = fn();
  writeFileSync(`svg/${name}.svg`, svg);
  await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
  await page.screenshot({ path: `png/${name}.png`, omitBackground: true, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  console.log('rendered', name);
}
await browser.close();
