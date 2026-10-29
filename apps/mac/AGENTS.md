# mac

- Purpose: the macOS menu bar app. It groups app windows, draws a tab bar above each group, and switches between grouped windows with configurable hide modes.
- Stack: Swift 5.10 and Swift Package Manager, macOS 13 or later, AppKit and SwiftUI. No third-party dependencies.
- Depends on: none. `apps/web` reads only the release asset names this app publishes.

## Tasks

Commands run in `apps/mac/`. The app builds on macOS only; Swift's AppKit and the Accessibility API have no Windows counterpart, so the `windows` column stays empty on purpose.

| task | command | windows |
|---|---|---|
| install | swift package resolve | |
| dev | swift build && .build/debug/Origami | |
| test | swift build | |
| build | ./scripts/package.sh | |

`build` writes `Origami.app`, a `.zip`, and a `.dmg` to `$WOK_OUT` (`build/mac/`), and defaults to version `0.0.0-dev`. The release workflow passes the tag: `./scripts/package.sh 0.1.0`.

There is no test target. `swift build` is the compile check, and behavior is verified by running the app.

## Layout

```
Package.swift            executable target Origami, platform macOS 13
Sources/Origami/         sources; see docs/architecture/overview.md for the module map
Resources/Info.plist     bundle template; keeps VERSION_PLACEHOLDER, filled in while packaging
Resources/AppIcon.icns   icon, generated from icon.png
icon.png                 icon source, used by scripts/generate-app-icon.sh
scripts/package.sh       builds the universal binary and assembles the .app, .zip, and .dmg
scripts/generate-app-icon.sh  icon.png to AppIcon.icns, needs sips and iconutil
```

## Conventions

- **Keep the engine in one place.** `WindowOverlayManager.swift` owns the tick loop and all window state. Settings, storage, and pure group membership stay out of it.
- **Private APIs go behind a controller.** `_AXUIElementGetWindow` and the SkyLight symbols are resolved with `dlopen` and `dlsym` so a macOS update degrades the feature instead of crashing. Any new private symbol belongs in a controller class that fails closed.
- **Two coordinate systems.** Quartz window frames have a top-left origin, AppKit and Accessibility have a bottom-left one. Convert through `cgFrame` / `axFrame` and their `*StyleFrame` helpers; never mix them.
- **The tick loop is the hot path.** Cache the window list, window PIDs, titles, and minimized state; only call the Accessibility API when a cached value expires. A new per-tick query needs a cache and a reason.
- **Hiding is a state machine.** Every window this app hides is tracked in `hiddenWindowIDs` plus the original frame or Space, and must be restorable on quit, on launch, and after a crash-free switch. Add restore paths together with hide paths.
- **Settings live in `AppSettings`.** New settings need a key, a default, clamping, and a control in `MainView`; legacy migrations go in `migrateLegacySettingsIfNeeded`.
- **The version comes from the bundle.** Read it through `AppInfo`, never hard-code it, and leave `Info.plist` as a placeholder.
- **Ad-hoc signing changes the CDHash.** After packaging, macOS treats the app as new and the Accessibility grant is stale; remove and re-add the entry in System Settings.
- Do not commit `.build/` or packaged output.
