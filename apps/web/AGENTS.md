# web

- Purpose: the product site at GitHub Releases and Cloudflare Pages. It presents the app, hosts the interactive tab bar demo, and serves the download links.
- Stack: Astro 7, Tailwind CSS 4, TypeScript, plain CSS. Node.js 22.12 or later.
- Depends on: mac, only through the release asset names documented in `docs/api/mac-release-assets.md`.

## Tasks

Commands run in `apps/web/`. `build` doubles as the check; there is no test suite.

| task | command | windows |
|---|---|---|
| install | npm ci | |
| dev | npm run dev | |
| test | npm run build -- --outDir "$WOK_OUT" | |
| build | npm run build -- --outDir "$WOK_OUT" | |

Without wok, `npm run build` writes to `apps/web/dist`. The Pages deployment reads `dist`, so keep that command unchanged for deploys.

## Layout

```
src/pages/index.astro       Chinese page, the default language
src/pages/en/index.astro    English page
src/components/             page sections; demo/ holds the interactive tab bar demo
src/i18n/                   all copy, zh.ts and en.ts
src/layouts/                shared layout, theme and locale switches
src/styles/global.css       Tailwind entry and global styles
public/                     static assets, favicon, preview video, demo audio
```

## Conventions

- **Chinese is the default language.** Keep `i18n/zh.ts` and `i18n/en.ts` in step; every string exists in both.
- **The released version is a literal in two components.** `GettingStarted.astro` and `ProductShowcase.astro` hold `releaseVersion` and build the download URLs from it. Bump both in the same change as the tag; `docs/guides/release.md` lists the steps.
- **The demo is a re-creation.** `components/demo/` imitates the tab bar in vanilla JavaScript; it does not run the app and must be updated by hand when behavior visible to users changes.
- **Static output only.** No server code, no client-side routing. The site is deployed as static files.
- Do not commit `node_modules/`, `dist/`, or `.astro/`.

## Development

When starting the dev server, use background mode:

```
astro dev --background
```

Manage the background server with `astro dev stop`, `astro dev status`, and `astro dev logs`.

## Documentation

Full documentation: https://docs.astro.build

Consult these guides before working on related tasks:

- [Adding pages, dynamic routes, or middleware](https://docs.astro.build/en/guides/routing/)
- [Working with Astro components](https://docs.astro.build/en/basics/astro-components/)
- [Using React, Vue, Svelte, or other framework components](https://docs.astro.build/en/guides/framework-components/)
- [Adding or managing content](https://docs.astro.build/en/guides/content-collections/)
- [Adding styles or using Tailwind](https://docs.astro.build/en/guides/styling/)
- [Supporting multiple languages](https://docs.astro.build/en/guides/internationalization/)
