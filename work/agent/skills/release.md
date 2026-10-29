# Release

Cut a version, publish the macOS build, and deploy the site. Use when the user says the release should be done end to end (the Chinese trigger is 「一条龙服务」), or asks to ship a version.

Prerequisites: push access to the repository, the newest tag fetched locally (`git fetch --tags`), Node.js 22.12 or later, and a valid Wrangler session for the Cloudflare step.

## 1. Pick the version

Ask for `X.Y.Z` if it is unclear. With no explicit version, raise the patch number of the newest tag:

```sh
git tag --sort=-v:refname | head -n 1
```

## 2. Bump the version in the site

Both components build the download URLs from `releaseVersion`, so they must match the new tag:

- `apps/web/src/components/GettingStarted.astro`
- `apps/web/src/components/ProductShowcase.astro`

Do not touch `apps/mac/Resources/Info.plist`: it keeps `VERSION_PLACEHOLDER` and `apps/mac/scripts/package.sh` injects the version. The version shown inside the app comes from the bundle, so it follows the packaged build.

## 3. Commit and push

```sh
git add -A
git commit -m "chore: release vX.Y.Z"
git push origin HEAD
```

Match the existing commit style. Amend only when the user asks.

## 4. Publish the build

The tag runs `.github/workflows/release.yml` on `macos-14`. It calls `apps/mac/scripts/package.sh` and uploads `build/mac/*.zip` and `*.dmg` to the release:

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
```

Optional local check before or after, on macOS:

```sh
cd apps/mac
./scripts/package.sh X.Y.Z
```

## 5. Deploy the site

```sh
cd apps/web
npm run build
npx wrangler pages deploy dist --project-name origami
```

Run `npx wrangler login` when the token is missing or expired.

## Done when

- [ ] The GitHub release `vX.Y.Z` exists with the universal ZIP and DMG
- [ ] Cloudflare Pages deployed the new build without errors
- [ ] Both download buttons on the site point at the new version
- [ ] `work/tmp/` holds nothing from this task
