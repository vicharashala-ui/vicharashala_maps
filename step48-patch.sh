#!/usr/bin/env bash
# Step 48 — public/_headers (spec §11.2: security + caching headers for Cloudflare Pages)
# Idempotent: full overwrite of a single new file.
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f package.json ] || [ ! -d src ]; then
  echo "Run this from the project root (package.json + src/ not found here)." >&2
  exit 1
fi

# Verify the CSP hash still matches the current themeInit.raw.ts — the spec requires this be
# recomputed by hand if that script's source ever changes (§11.2's exact stated procedure).
EXPECTED_HASH="sha256-aLKjMg9sIpm0IVB1dEa3SEuQnrZOcHuC0iiQiVDITAA="
ACTUAL_HASH=$(node -e "console.log('sha256-' + require('crypto').createHash('sha256').update(require('fs').readFileSync('src/scripts/themeInit.raw.ts','utf8').trim()).digest('base64'))")
if [ "$ACTUAL_HASH" != "$EXPECTED_HASH" ]; then
  echo "themeInit.raw.ts has changed since this hash was computed." >&2
  echo "Expected: $EXPECTED_HASH" >&2
  echo "Actual:   $ACTUAL_HASH" >&2
  echo "Update the hash in this script and in public/_headers before proceeding." >&2
  exit 1
fi

cat > public/_headers << 'HEADERSEOF'
/*
  Cache-Control: no-cache
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Content-Security-Policy: default-src 'self'; script-src 'self' 'sha256-aLKjMg9sIpm0IVB1dEa3SEuQnrZOcHuC0iiQiVDITAA=' https://static.cloudflareinsights.com; worker-src 'self' blob:; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; connect-src 'self' https://cloudflareinsights.com

/tiles/*
  Cache-Control: public, max-age=604800, stale-while-revalidate=86400

/geojson/*
  Cache-Control: public, max-age=604800, stale-while-revalidate=86400

/data/*
  Cache-Control: public, max-age=86400, stale-while-revalidate=3600

/_astro/*
  Cache-Control: public, max-age=31536000, immutable
HEADERSEOF

echo "public/_headers written."

pnpm install
pnpm build

echo "Step 48 complete: public/_headers in place, pnpm build verified clean."
