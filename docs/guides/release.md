# Release

Cut a new version, publish the macOS build, and deploy the site. Single-app commands are in `apps/mac/AGENTS.md` and `apps/web/AGENTS.md`; this guide covers the order across both.

The reusable procedure lives in `work/agent/skills/release.md`.

## 1. Bump the version

Pick `X.Y.Z`. With no explicit version, raise the patch number of the newest tag:

```sh
git tag --sort=-v:refname | head -n 1
```

Update the two constants in the site, which drive the download buttons:

- `apps/web/src/components/GettingStarted.astro` → `releaseVersion`
- `apps/web/src/components/ProductShowcase.astro` → `releaseVersion`

Leave `apps/mac/Resources/Info.plist` alone: it keeps `VERSION_PLACEHOLDER`, and `scripts/package.sh` injects the version while packaging. The version shown inside the app reads from the bundle, so it follows the package automatically.

## 2. Commit and push

```sh
git add -A
git commit -m "chore: release vX.Y.Z"
git push origin HEAD
```

## 3. Publish the build

Pushing a tag runs `.github/workflows/release.yml` on `macos-14`, which calls `apps/mac/scripts/package.sh` and uploads the assets from `build/mac/`:

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
```

To check locally first (macOS only):

```sh
cd apps/mac
./scripts/package.sh X.Y.Z
```

The packaged bundle lands in `build/mac/Origami.app`, next to `Origami-vX.Y.Z-macos-universal.zip` and `.dmg`.

## 4. Deploy the site

```sh
cd apps/web
npm run build
npx wrangler pages deploy dist --project-name origami
```

`npx wrangler login` is needed the first time, or when the token expires.

## Done when

- [ ] GitHub Releases shows `vX.Y.Z` with the universal ZIP and DMG
- [ ] Cloudflare Pages deployed the new build
- [ ] Both download buttons on the site point at the new version
