# win release assets

How the Windows app is published, and what the site may rely on.

## Provider

`.github/workflows/release.yml` configures `apps/win` with CMake, builds it with MSVC in Release mode, and packs `build/win/origami.exe` into a zip.

## Asset names

| asset | name |
|---|---|
| zip | `Origami-v<version>-windows-x64.zip` |

The zip contains a single `origami.exe`: x64, static CRT, no installer and no runtime to install. The build is unsigned, so SmartScreen warns on first launch.

## Consumers

`apps/web/src/components/ProductShowcase.astro` builds the URL from `releaseVersion`:

```
https://github.com/XiaoXianThis/Origami/releases/download/v<version>/Origami-v<version>-windows-x64.zip
```

## Changing the contract

Renaming the asset or changing the tag format breaks every download button on the site, including those on already-published pages. Change the workflow and the web component in one task, and note it in `docs/decisions/`.
