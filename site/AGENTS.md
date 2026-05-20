# FLARE Site Agent Guide

This directory hosts the FLARE paper landing page, an Astro 5 + MDX site
with optional React "islands," Tailwind CSS v4, KaTeX math, and a small
PDF→image pipeline. It renders a single-page research project site from
[`src/paper.mdx`](src/paper.mdx) using [`src/pages/index.astro`](src/pages/index.astro)
as the layout and a curated set of components. Deployed to GitHub Pages
(https://flare.henryrobbins.com/) on pushes to the `site` branch by
[`.github/workflows/deploy-site.yml`](../.github/workflows/deploy-site.yml).

The site is based on Roman Hauksson's [Academic project page
template](https://github.com/RomanHauksson/academic-project-astro-template).

## Architecture and key files

- **Astro + MDX content**
  - Entry content: `src/paper.mdx` (MDX with YAML frontmatter). Frontmatter
    keys: `title`, `authors`, `conference`, `notes`, `links`, `description`,
    `favicon`, `thumbnail`, `theme`.
  - Layout: `src/pages/index.astro` imports the content and frontmatter from
    `src/paper.mdx` via `import { Content, frontmatter } from "../paper.mdx"`,
    sets `<html data-theme>`, OpenGraph tags, favicon, and uses
    `import.meta.env.BASE_URL` to prefix public assets for GitHub Pages.
- **Components** (under `src/components/`)
  - `Figure.astro` — consistent figure/caption pattern via named slots
    `figure` and `caption`.
  - `Picture.astro` — wraps `astro:assets` with PDF support via
    `src/lib/render-pdf.ts`. `src` accepts either an `ImageMetadata`
    import or a string path ending with `.pdf` (resolved relative to
    `./src/pages/`). Use `<Picture invertInDarkMode />` to invert images
    in dark mode.
  - `Video.astro`, `YouTubeVideo.astro`, `ModelViewer.astro`
    (`<model-viewer>`), `Carousel.astro`/`CarouselSlide.astro`,
    `Comparison.tsx` (React compare slider).
  - React components require a `client:*` hydration directive when used
    inside MDX/`.astro` (e.g., `<Comparison client:idle>`).
  - Math is rendered with `remark-math` + `rehype-katex` — just write
    inline `$...$` or block `$$...$$` inside MDX, no component needed.
- **Styling**
  - Tailwind v4 via `@tailwindcss/vite`; global styles in
    `src/styles/global.css` with a custom `dark` variant keyed off
    `data-theme`.
  - Code blocks themed with `astro-expressive-code` (see
    `astro.config.ts` `styleOverrides` and theme selector). Don't
    manually theme them.
- **TypeScript & paths**
  - TS strict config with JSX set to React; alias `@/*` → `./src/*` in
    `tsconfig.json`.

## Developer workflows

Node 24+ is recommended locally; CI uses Node 20 (see
`.github/workflows/deploy-site.yml`). If you adopt Node 24-only features,
update the workflow accordingly.

```bash
npm install
npm run dev       # http://localhost:4321
npm run build     # astro check (typecheck) then astro build
npm run preview   # serve the built site
```

Lint and format are configured but have no npm scripts:

```bash
npx eslint .      # ESLint over JS/TS/TSX, Astro, JSON, Markdown, CSS
npx prettier -w . # Prettier (prettier-plugin-astro + tailwindcss)
```

## Project-specific conventions

- Content lives in `src/paper.mdx`; import components at the top and
  optionally map MD elements (e.g.,
  `export const components = { table: Table }`).
- Wrap visuals in `<Figure>` with slots `<slot name="figure"/>` and
  `<slot name="caption"/>`.
- Prefer `<Picture>` for images. It accepts either imported images
  (Astro's `ImageMetadata`) or a relative PDF path like
  `"../assets/plot.pdf"` (auto-renders page 1 to PNG at 4× during
  build/dev).
- `Carousel` expects `CarouselSlide` children; place any markup inside
  each slide and the component handles pagination buttons, swipe, and
  keyboard focus.
- For React, import the component and add a `client:*` directive at the
  usage site.

### Theme handling

Set `theme` in frontmatter to `device | light | dark`. The layout writes
`data-theme` and Tailwind's custom `dark` variant reads it. Use
`dark:*` utilities as needed.

### Assets & paths

Public assets in `public/` are served at the base URL. When constructing
absolute URLs in the layout or components, prefix with
`import.meta.env.BASE_URL` (the layout already exposes `prefix`). PDF
conversion reads from `./src/pages/<path>` and writes to
`dist/_astro/<name>.png`. In dev, `Picture.astro` points to
`../dist/_astro/...`; in prod it points to `_astro/...`.

## Videos

The `Video` component defaults to muted, autoplaying playback. For
videos with audio:

```mdx
<Video src={...} muted={false} autoplay={false} playsinline={false} />
```

To make a video behave like a GIF (do this instead of using an actual
GIF — much more performant):

```mdx
<Video src={...} controls={false} />
```

For longer videos, use a hosted service:

```mdx
<YouTubeVideo videoId="..." />
```

## Fonts

The default font is [Noto Sans](https://fonts.google.com/noto/specimen/Noto+Sans)
(variable font, broad glyph coverage), loaded via Astro's experimental
Fonts API. To swap fonts, update `experimental.fonts` in
`astro.config.ts` and the `<Font>` usage in `src/pages/index.astro`.
Only the Latin/normal subset is preloaded by default — change `preload`
in `<Font>` for non-Latin alphabets or italic-heavy headers to avoid
initial-load font flashes.

## Icons

Icons come from [Astro Icon](https://www.astroicon.dev/) using Iconify
sets (e.g., `@iconify-json/academicons`, `@iconify-json/ri`). To add a
custom icon:

1. Find it on [Iconify](https://icon-sets.iconify.design/) (e.g.,
   `simple-icons:huggingface`).
2. Install the set: `npm install @iconify-json/simple-icons`.
3. Reference it in frontmatter `links` items as `icon: simple-icons:huggingface`,
   or inside a component:

   ```mdx
   import { Icon } from "astro-icon/components";

   <Icon name="simple-icons:huggingface" />
   ```

## MCP

`.mcp.json` in this directory registers the Astro docs MCP server
(`https://mcp.docs.astro.build/mcp`) for Claude Code. Use it to look up
Astro APIs and component patterns rather than guessing.
