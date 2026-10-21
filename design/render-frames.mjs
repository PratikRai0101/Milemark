// Renders the app's screenshots inside a device frame, for the readme.
//
// The frame is a thin bezel drawn tight to the screen, the way a screenshot
// of a phone is presented: a narrow black edge, the screen's own corner
// radius, and a hairline for the metal. There is no caption in the image —
// the readme writes the caption underneath it, and having both means saying
// the same thing twice.
//
// Usage: node design/render-frames.mjs
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire('/Users/pratikrai/.pi/agent/skills/app-designer/package.json');
const { chromium } = require('playwright-core');

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
// The raw captures are an intermediate step and are not published. Only the
// framed renders are.
const shots = path.join(root, '.captures');
const out = path.join(root, 'Screenshots', 'frames');
fs.mkdirSync(out, { recursive: true });

const frames = [
  { file: '01-archive.png' },
  { file: '02-receipt-route.png' },
  { file: '03-receipt-ascii.png' },
  { file: '04-receipt-pace.png' },
  { file: '08-photo.png' },
  { file: '05-share.png' },
  { file: '07-tracking.png' },
  { file: '06-kept.png' },
  { file: '09-receipt-large-text.png' },
  { file: '10-settings.png' },
  { file: '11-import.png' },
];

// The device, in the page's own units. The screenshot is 900 px wide, so the
// bezel is a thin edge rather than a slab of black.
const BEZEL = 9;
const RADIUS_OUTER = 20;
const RADIUS_SCREEN = 15;

const html = `<!doctype html>
<html><head><meta charset="utf-8"><style>
  * { box-sizing: border-box; }
  body { margin: 0; background: #0d1117; }
  .device {
    display: inline-block;
    padding: ${BEZEL}px;
    background: #05060a;
    border-radius: ${RADIUS_OUTER}px;
    /* The hairline is the metal edge of the phone. It is a border rather
       than a shadow, because a shadow on a dark page is just a black blob,
       and because a border is inside the element's box, so it survives the
       capture. */
    border: 2px solid #4a4f58;
  }
  .device img {
    display: block;
    width: 300px;
    border-radius: ${RADIUS_SCREEN}px;
  }
</style></head>
<body>
${frames.map((f, i) => `<div class="device" id="f${i}"><img src="file://${path.join(shots, f.file)}"></div>`).join('\n')}
</body></html>`;

const missing = frames.filter((frame) => !fs.existsSync(path.join(shots, frame.file)));
if (missing.length) {
  console.error('These captures are missing, so the frames would be broken:');
  for (const frame of missing) console.error('  ' + frame.file);
  console.error('Run design/capture-screenshots.sh first.');
  process.exit(1);
}

const htmlPath = path.join(out, '_frames.html');
fs.writeFileSync(htmlPath, html);

const browser = await chromium.launch({
  headless: true,
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
});
const page = await browser.newPage({ viewport: { width: 1200, height: 1200 }, deviceScaleFactor: 3 });
await page.goto(`file://${htmlPath}`);
await page.waitForTimeout(500);

for (const [index, frame] of frames.entries()) {
  // The frame keeps the name of the capture it came from, so the two are
  // obviously the same screen.
  const target = path.join(out, frame.file);
  // The element's own box is captured, so every frame is exactly the same
  // size whatever the page is doing.
  await page.locator(`#f${index}`).screenshot({ path: target });
  console.log('  ' + path.relative(root, target));
}

fs.unlinkSync(htmlPath);
await browser.close();

// The frames are mostly flat greys, so a small palette is indistinguishable
// from the original and a third of the size.
console.log('  shrinking the frames');
const { execFileSync } = await import('node:child_process');
execFileSync('python3', [path.join(root, 'design', 'optimise-frames.py')], {
  stdio: 'inherit',
});
