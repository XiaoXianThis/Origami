# mac release assets

How the mac app is published, and what the site may rely on.

## Provider

`apps/mac/scripts/package.sh <version>` writes to `build/mac/`, and `.github/workflows/release.yml` uploads the same files to the GitHub release named `v<version>`.

## Asset names

| asset | name |
|---|---|
| zip | `Origami-v<version>-macos-universal.zip` |
| dmg | `Origami-v<version>-macos-universal.dmg` |

Both are universal binaries (arm64 and x86_64) inside an ad-hoc signed `Origami.app`.

## Consumers

`apps/web/src/components/ProductShowcase.astro` builds these URLs from `releaseVersion`:

```
https://github.com/XiaoXianThis/Origami/releases/download/v<version>/Origami-v<version>-macos-universal.dmg
https://github.com/XiaoXianThis/Origami/releases/download/v<version>/Origami-v<version>-macos-universal.zip
```

The Windows build is published by the same workflow from `apps/win`; see [win-release-assets.md](win-release-assets.md).

## Changing the contract

Renaming an asset or changing the tag format breaks every download button on the site, including those on already-published pages. Change `package.sh`, the workflow, and both web components in one task, and note it in `docs/decisions/`.
