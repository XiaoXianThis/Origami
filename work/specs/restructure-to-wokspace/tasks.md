# Tasks

- [x] Move the Swift package to `apps/mac` with `git mv`
- [x] Move the site to `apps/web` with `git mv`
- [x] Move the READMEs to `docs/` and rewrite paths
- [x] Add the root `AGENTS.md`, `.gitignore` whitelist, and `.gitattributes`
- [x] Add the skeleton directories with their READMEs
- [x] Write `apps/README.md`, `apps/mac/AGENTS.md`, `apps/web/AGENTS.md`
- [x] Write `docs/architecture/overview.md`, the first decision record, the install and release guides, and the release-asset contract
- [x] Point `apps/mac/scripts/package.sh` at `$WOK_OUT` / `build/mac`
- [x] Update `.github/workflows/release.yml` for the new paths
- [x] Move the release rule into `work/agent/` and keep a local Cursor copy
- [x] Remove stale path references from app docs and the site README
- [x] Verify the site still builds and the repository has no stray root entries
