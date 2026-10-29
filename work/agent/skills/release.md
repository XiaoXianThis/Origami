# Release

Cut a version, publish the macOS and Windows builds, and deploy the site. Use when the user says the release should be done end to end (the Chinese trigger is 「一条龙服务」), or asks to ship a version.

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

Do not touch `apps/mac/Resources/Info.plist`: it keeps `VERSION_PLACEHOLDER` and `apps/mac/scripts/package.sh` injects the version. The version shown inside the app comes from the bundle, so it follows the packaged build. The Windows app has no embedded version; the exe is published under the tag.

## 3. Commit and push

```sh
git add -A
git commit -m "chore: release vX.Y.Z"
git push origin HEAD
```

Match the existing commit style. Amend only when the user asks.

## 4. Publish the builds

The tag runs `.github/workflows/release.yml`. The `mac` job calls `apps/mac/scripts/package.sh` on `macos-14` and uploads `build/mac/*.zip` and `*.dmg`; the `win` job then builds `apps/win` on `windows-latest` and uploads `Origami-vX.Y.Z-windows-x64.zip`.

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
```

Optional local check before or after, on macOS:

```sh
cd apps/mac
./scripts/package.sh X.Y.Z
```

On Windows, the equivalent check is the `build` task plus a zip of `build/win/origami.exe`; `docs/guides/release.md` has the commands.

## 5. Deploy the site

```sh
cd apps/web
npm run build
npx wrangler pages deploy dist --project-name origami
```

Run `npx wrangler login` when the token is missing or expired.

## Done when

- [ ] The GitHub release `vX.Y.Z` exists with the mac ZIP and DMG and the Windows ZIP
- [ ] Cloudflare Pages deployed the new build without errors
- [ ] All download buttons on the site point at the new version
- [ ] `work/tmp/` holds nothing from this task
