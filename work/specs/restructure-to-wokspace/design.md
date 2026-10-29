# Design

## Path mapping

| before | after |
|---|---|
| `Package.swift` | `apps/mac/Package.swift` |
| `Sources/Origami/` | `apps/mac/Sources/Origami/` |
| `Resources/` | `apps/mac/Resources/` |
| `scripts/` | `apps/mac/scripts/` |
| `icon.png` | `apps/mac/icon.png` |
| `web/` | `apps/web/` |
| `README.md` | `docs/README.md` |
| `README.en.md` | `docs/README.en.md` |
| `dist/` (build output) | `build/mac/` |
| `.cursor/rules/yitiaolong-release.mdc` | `work/agent/configs/cursor/rules/release.mdc` and `work/agent/skills/release.md` |

No Swift source, Astro component, or asset changed content. Only scripts, workflows, docs, and paths did.

## Decisions

- **App names `mac` and `web`.** They say what each app targets, and both are valid kebab-case.
- **Keep SwiftPM at `apps/mac`.** The package root is the app root, so `swift build` works without a workspace wrapper.
- **Package output through `$WOK_OUT`.** `apps/mac/scripts/package.sh` prefers `$WOK_OUT` and falls back to `<repo>/build/mac`, which keeps `wok build mac` and a manual run identical.
- **The site keeps building to `apps/web/dist`.** Cloudflare Pages and Wrangler both expect a directory relative to the app, so only the Root directory setting changes to `apps/web`.
- **The release rule stops being a committed Cursor file.** Agent tool directories are ignored by the layout, so the procedure lives in `work/agent/` and each person copies the Cursor variant locally.

## Risks

- The Cloudflare Pages project setting still points at the old root until it is changed in the dashboard.
- Ad-hoc signing means the packaged app's Accessibility grant is invalidated by the move; the tester has to re-add the app once.
- Swift cannot be compiled on Windows, so the move is verified by path checks only on that machine.
