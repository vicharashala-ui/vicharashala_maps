// Step 49 (§11.3): adds preload for the two above-the-fold font weights (Sora 600, Inter 400)
// + preconnect for Cloudflare Web Analytics to every page's <head>.
//
// Imports the exact woff2 files via Vite's `?url` suffix rather than hardcoding a fingerprinted
// dist path — Vite resolves + fingerprints the URL at build time, same pattern already used for
// `themeInit.raw.ts?raw` elsewhere in this codebase, so the preload href can never drift out of
// sync with the actual built asset (no hash to manually recompute, unlike the CSP hash in
// public/_headers).
//
// Marker-guarded: re-running on an already-patched file is a no-op.
import { readFileSync, writeFileSync } from 'node:fs';

const PAGES = [
  { path: 'src/pages/404.astro', depth: 1 },
  { path: 'src/pages/about.astro', depth: 1 },
  { path: 'src/pages/compare.astro', depth: 1 },
  { path: 'src/pages/index.astro', depth: 1 },
  { path: 'src/pages/privacy-policy.astro', depth: 1 },
  { path: 'src/pages/terms.astro', depth: 1 },
  { path: 'src/pages/blog/index.astro', depth: 2 },
  { path: 'src/pages/blog/[slug].astro', depth: 2 },
  { path: 'src/pages/river/[id].astro', depth: 2 },
  { path: 'src/pages/state/[id].astro', depth: 2 },
  { path: 'src/pages/basin/[id].astro', depth: 2 },
];

const MARKER = 'soraLatin600';

for (const { path, depth } of PAGES) {
  const src = readFileSync(path, 'utf-8');

  if (src.includes(MARKER)) {
    console.log(`skip (already patched): ${path}`);
    continue;
  }

  const up = '../'.repeat(depth);
  const importLine = `import themeInit from '${up}scripts/themeInit.raw.ts?raw';`;
  if (!src.includes(importLine)) {
    throw new Error(`${path}: expected themeInit import line not found — anchor point changed, update this script.`);
  }

  const fontImports =
    `${importLine}\n` +
    `import soraLatin600 from '@fontsource/sora/files/sora-latin-600-normal.woff2?url';\n` +
    `import interLatin400 from '@fontsource/inter/files/inter-latin-400-normal.woff2?url';`;
  let next = src.replace(importLine, fontImports);

  const faviconLine = '<link rel="icon" href="/favicon.svg" type="image/svg+xml" />';
  if (!next.includes(faviconLine)) {
    throw new Error(`${path}: expected favicon link line not found — anchor point changed, update this script.`);
  }

  const preloadLinks =
    `${faviconLine}\n` +
    `    <link rel="preload" href={soraLatin600} as="font" type="font/woff2" crossorigin />\n` +
    `    <link rel="preload" href={interLatin400} as="font" type="font/woff2" crossorigin />\n` +
    `    <link rel="preconnect" href="https://static.cloudflareinsights.com" />`;
  next = next.replace(faviconLine, preloadLinks);

  writeFileSync(path, next);
  console.log(`patched: ${path}`);
}
