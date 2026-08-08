import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import preact from '@astrojs/preact';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://vicharashalamaps.pages.dev',
  output: 'static',
  integrations: [sitemap(), preact()],
  vite: {
    plugins: [tailwindcss()],
  },
});
