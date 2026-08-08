import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import preact from '@astrojs/preact';
import tailwindcss from '@tailwindcss/vite';
import rehypeExternalLinks from 'rehype-external-links';

export default defineConfig({
  site: 'https://vicharashalamaps.pages.dev',
  output: 'static',
  integrations: [sitemap(), preact()],
  vite: {
    plugins: [tailwindcss()],
  },
  // §5.3 "External link safety": blog markdown's external links open in a new tab, safely.
  markdown: {
    rehypePlugins: [[rehypeExternalLinks, { target: '_blank', rel: ['noopener', 'noreferrer'] }]],
  },
});
