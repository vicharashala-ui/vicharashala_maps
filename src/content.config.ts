// Astro 6 removed the legacy Content Collections API — glob() loader + astro/zod (Astro 6 runs Zod 4).
import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    keywords: z.array(z.string()),
    category: z.enum(['rivers', 'protected-areas', 'cross-category']),
  }),
});

export const collections = { blog };
