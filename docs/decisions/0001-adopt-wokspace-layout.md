# 0001 Adopt the wokspace layout

- Status: Accepted
- Date: 2026-10-30

## Context

The repository started as a single Swift package with the Astro site in a `web/` subdirectory next to `Sources/`, `Resources/`, and `scripts/`. The root mixed a language project with an unrelated project and shared scripts, and the README documented paths that existed for historical reasons only.

Adding more surfaces (a Windows build, a second site) would have made the root grow further: more configs, more scripts, more notes. Agents working across the repository had no rule for where a new file belongs.

## Decision

Adopt the wokspace layout described by the root `AGENTS.md`:

- The root is a frozen workspace: `AGENTS.md`, `.gitignore`, `.gitattributes`, plus `apps/`, `build/`, `docs/`, `work/`, and the optional `.github/`.
- `apps/mac` holds the Swift package exactly as SwiftPM expects it; `apps/web` holds the Astro site.
- `build/mac` receives the packaged `.app`, `.zip`, and `.dmg`; nothing there is committed.
- `docs/` holds the project home page (`docs/README.md`), the architecture note, decision records, and guides. GitHub shows `docs/README.md` on the repository page, so the root needs no README.
- `work/` holds specs, agent material, cross-app scripts, tests, assets, and infrastructure.
- The version-bump and deploy procedure moved from a local Cursor rule to `work/agent/skills/release.md`, with a Cursor copy in `work/agent/configs/cursor/`.

## Alternatives

- **Keep the Swift package at the root and only rename `web/` to `apps/web`.** Rejected: the root would still be a Swift project with a second project inside it, and the site's build output would still land inside the app tree.
- **Keep `web/` and `Sources/` side by side with a root README.** Rejected: GitHub finds a `docs/README.md`, and every new file would still need a judgement call.
- **Move the Swift sources under `apps/mac/Origami/` with a workspace-level `Package.swift`.** Rejected: an extra level of nesting buys nothing; `swift build` and Xcode both work with the package at `apps/mac`.

## Consequences

- Every path changed once: build commands, CI, Cloudflare Pages settings, download links in the site, and the release procedure. All were updated in the same change.
- `swift build` and `swift run` must run inside `apps/mac`; at the root only git, read-only, and `wok` commands are allowed.
- The site's version literals now live in `apps/web/src/components/`.
- The pre-existing `.cursor/rules/yitiaolong-release.mdc` is no longer committed (agent tool directories are ignored). Its content lives in `work/agent/` and is copied locally.
