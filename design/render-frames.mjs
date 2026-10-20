// Renders the app's screenshots inside a device frame with a caption, for the
// readme.
//
// The app's own captures are raw simulator screens. A frame and a caption make
// them read as a set, and it is the same presentation the design prototype
// used.
//
// Usage: node design/render-frames.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire('/Users/pratikrai/.pi/agent/skills/app-designer/package.json');
const { chromium } = require('playwright-core');

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const shots = path.join(root, 'Screenshots');
const out = path.join(shots, 'frames');
fs.mkdirSync(out, { recursive: true });

const frames = [
  { file: '01-archive.png', caption: 'RUNS — EVERY ROUTE AS ITS OWN SHAPE' },
  { file: '02-receipt-route.png', caption: 'THE RECEIPT — PRINTED FROM A TRAY' },
  { file: '03-receipt-ascii.png', caption: 'ASCII — THE SAME ROUTE, PRINTED' },
  { file: '04-receipt-pace.png', caption: 'PACE — INSPECTABLE PER KILOMETRE' },
  { file: '08-photo.png', caption: 'PHOTO — PRINTED THREE WAYS' },
  { file: '05-share.png', caption: 'SHARE — WITH THE ROUTE ENDS TRIMMED' },
  { file: '07-tracking.png', caption: 'RECORDING — A QUIET MAP, A VIVID TRACK' },
  { file: '06-kept.png', caption: 'KEPT — THE RECEIPTS YOU KEPT' }
];

const html = `<!doctype html>
<html><head><meta charset="utf-8"><style>
  body { margin: 0; background: #E9E9E6; font-family: -apple-system, "SF Pro Text", sans-serif; }
  .frame { display: inline-block; margin: 40px; text-align: center; }
  .device {
    display: inline-block; padding: 10px; border-radius: 54px;
    background: #1B1D21; box-shadow: 0 22px 44px rgba(0,0,0,.20);
  }
  .device img { display: block; width: 300px; border-radius: 44px; }
  .caption {
    margin-top: 24px; width: 320px; font-size: 11px; line-height: 1.7;
    letter-spacing: .22em; font-weight: 500; color: #6E716B; text-transform: uppercase;
  }
</style></head>
<body>
${frames.map((f, i) => `<div class="frame" id="f${i}">
  <div class="device"><img src="file://${path.join(shots, f.file)}"></div>
  <div class="caption">${f.caption}</div>
</div>`).join('\n')}
</body></html>`;

const htmlPath = path.join(out, '_frames.html');
fs.writeFileSync(htmlPath, html);

const browser = await chromium.launch({
  headless: true,
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
});
const page = await browser.newPage({ viewport: { width: 1200, height: 1200 }, deviceScaleFactor: 2 });
await page.goto(`file://${htmlPath}`);
await page.waitForTimeout(500);

for (const [index, frame] of frames.entries()) {
  const target = path.join(out, `${String(index + 1).padStart(2, '0')}-${frame.file}`);
  await page.locator(`#f${index}`).screenshot({ path: target, omitBackground: false });
  console.log('  ' + path.relative(root, target));
}

fs.unlinkSync(htmlPath);
await browser.close();
