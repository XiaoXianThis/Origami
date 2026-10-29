# Overview

Origami is a macOS menu bar app that folds several app windows into one group and draws a tab bar above them. This repository holds the app and its product site, side by side, with no shared source.

```mermaid
flowchart LR
  subgraph repo[repository]
    mac[apps/mac<br/>Swift package]
    win[apps/win<br/>C++ Win32]
    web[apps/web<br/>Astro site]
  end
  mac -- tag vX.Y.Z --> ci[.github/workflows/release.yml]
  ci -- DMG + ZIP --> rel[GitHub Releases]
  web -- download links --> rel
  web -- npm run build --> cf[Cloudflare Pages]
```

The only dependency between the apps is a naming convention: the site's download URLs must match the asset names that `apps/mac/scripts/package.sh` produces. Changing one means changing the other. `apps/win` is a separate implementation of the same product and shares no source with `apps/mac`.

## apps/mac

A Swift Package Manager executable, macOS 13 or later, no third-party dependencies. It runs as an accessory app (`LSUIElement`), so it has a menu bar item and no Dock icon.

| file | responsibility |
|---|---|
| `Sources/Origami/main.swift` | creates `NSApplication` in accessory mode, installs `AppDelegate`, runs the loop |
| `AppDelegate.swift` | status bar item, the settings window (`MainView`), starts and stops the engine |
| `WindowOverlayManager.swift` | the engine: a timer-driven loop that watches windows, keeps overlays aligned, and switches groups |
| `GroupStore.swift` | which windows belong to which group, and which one is active |
| `TabBarView.swift` | the overlay tab bar, drawn by hand in an `NSView` |
| `AppSettings.swift` | every setting, stored in `UserDefaults` |
| `PermissionProbe.swift` | reads Accessibility and Input Monitoring state, with fix steps shown in settings |
| `MainView.swift`, `OverlayLabelView.swift`, `ShortcutRecorderView.swift`, `AutoGroupAppListEditor.swift` | SwiftUI settings UI |

How the loop works:

1. Every tick (60 Hz by default, adaptive down to 1 Hz when idle) it lists all windows with `CGWindowListCopyWindowInfo`, and keeps layer-0 windows that are on screen, large enough, not minimized, and not one of its own.
2. New windows are registered in `GroupStore`; windows that disappear are removed; optionally, a new window of an app that already has a group joins that group.
3. For each group it positions one borderless `NSPanel` at a computed offset from the active window's frame, and stacks it directly above that window with `order(.above, relativeTo:)`.
4. Switching tabs moves keyboard focus to the target window and hides the others using the configured hide mode.

Hide modes, and what each one needs:

| mode | mechanism |
|---|---|
| minimize | `kAXMinimizedAttribute` through the Accessibility API |
| transparent | private SkyLight `SLSSetWindowAlpha` / `CGSSetWindowAlpha` |
| move off screen | Accessibility position, outside every display |
| move to another Space | private SkyLight `SLSMoveWindowsToManagedSpace` |
| shrink | Accessibility size, restored on switch |

Three symbols are private and are resolved at runtime with `dlopen` and `dlsym`, so the app degrades instead of crashing when a macOS release removes them: `_AXUIElementGetWindow` (AX element to window number) and the SkyLight alpha, transform, and Spaces functions. Accessibility and Input Monitoring permission are requested from the settings window, not at launch.

Groups live only in memory. On launch and on quit the app restores every window it hid, and it can pull fully off-screen windows back with one click.

`scripts/package.sh <version>` builds a universal binary, assembles `Origami.app`, injects the version into `Resources/Info.plist`, generates the icon from `icon.png`, ad-hoc signs the bundle, and writes a `.zip` and a `.dmg` to `build/mac/` (`$WOK_OUT`). `Resources/Info.plist` keeps `VERSION_PLACEHOLDER` on purpose.

## apps/win

A C++20 Win32 app built with CMake and MSVC, static CRT, so the exe needs no VC++ redistributable. It is an independent implementation of the same product: no source is shared with `apps/mac`. Milestone 1 covers the engine and a tray menu; see `work/specs/win-port-milestone-1/` for what is still missing.

| file | responsibility |
|---|---|
| `src/main.cpp` | `wWinMain`, per-monitor DPI awareness |
| `src/app.*` | message window, tray, event hooks, refresh loop, switching, merge |
| `src/group_store.*` | group membership, merge, detach, pruning |
| `src/window_enum.*` | managed window enumeration, visible frames, cached titles, theme |
| `src/tab_bar.*` | bar metrics, Direct2D/DirectWrite painting, drop frame |
| `src/overlay_window.*` | layered overlay window, per-tab hit testing, tab drag |
| `src/drag_visuals.*` | drag ghost and drop frame |
| `src/settings.*` | `%APPDATA%\Origami\settings.ini` |

Where it deliberately differs from the macOS engine:

- **Event driven instead of a 60 Hz poll.** `SetWinEventHook` reports location, title, create, destroy, show, hide, cloak, and foreground changes; refreshes are coalesced into one 30 ms timer, and a 2 s timer only heals missed events.
- **No permission prompt.** `EnumWindows`, `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS)`, and `SetWindowPos` need no authorization. The limit is UIPI: windows owned by an elevated process are out of reach.
- **Titles are cached.** `GetWindowText` is a cross-process message, so it goes through `SendMessageTimeoutW` with a 40 ms budget and is only re-read when a rename event arrives.
- **Overlay windows** are `WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE`, painted into a premultiplied DIB with Direct2D and presented with `UpdateLayeredWindow`; alpha-zero pixels are click-through, and the window is inserted directly above its target with `SetWindowPos(hwnd, target, ...)`.
- **Two hide modes today:** minimize and move off screen. Moving off screen remembers the original rect per window and restores it before activation or on exit. A minimized window stays in its group even though its frame collapses to an icon-sized rect.
- **Dragging** shows a click-through ghost and a frame over the merge target; dropping on a window body merges, dropping on the desktop detaches.
- **Switching and merging move the incoming window into the outgoing window's frame** (visible bounds, same position), which is what makes a group feel like one window with tabs. A maximized outgoing window maximizes the incoming one. Turn it off with `match_window_frame=0` or the tray menu.

Measured on Windows 11 23H2 with seven managed windows: 167 KB exe, 11 MB private working set, 38 MB working set including shared DLL pages, and idle CPU below one 15.6 ms timer tick over 15 s.

## apps/web

A static Astro site with Tailwind CSS, deployed to Cloudflare Pages. Chinese is the default language; `src/pages/en/index.astro` is the English page. All copy lives in `src/i18n/zh.ts` and `src/i18n/en.ts`, and both must stay in step.

Two components hold the released version as a literal: `GettingStarted.astro` and `ProductShowcase.astro` (`releaseVersion`). They build the DMG, ZIP, and release-page URLs from it, so they must be bumped together with a new tag. `MacOSDemo.astro` is a JavaScript re-creation of the tab bar, used as an interactive demo; it is independent of the app's code.

## Release pipeline

```mermaid
sequenceDiagram
  participant dev
  participant gh as GitHub
  participant ci as Actions (macos-14)
  participant rel as Releases
  participant cf as Cloudflare Pages
  dev->>gh: push tag vX.Y.Z
  gh->>ci: run release.yml
  ci->>ci: apps/mac/scripts/package.sh X.Y.Z
  ci->>rel: build/mac/*.zip, *.dmg
  dev->>cf: npm run build, wrangler pages deploy
```

The workflow only publishes the macOS build. The site is deployed separately with Wrangler; its build settings are Root directory `apps/web`, build command `npm run build`, output `dist`. Steps for both are in `docs/guides/release.md`.
