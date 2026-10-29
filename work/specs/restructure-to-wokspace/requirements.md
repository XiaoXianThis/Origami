# restructure to a wokspace

## Requirements

- Move the Swift package and the Astro site under `apps/`, one directory per app, without changing app source.
- Adopt the frozen wokspace skeleton at the root: `AGENTS.md`, `.gitignore`, `.gitattributes`, `apps/`, `build/`, `docs/`, `work/`.
- Keep the project home page in `docs/README.md` and its English twin in `docs/README.en.md`.
- Move final build output to `build/mac/`.
- Keep publishing a tag and deploying the site working, with updated paths.
- Track every move with `git mv` so history follows the files.
