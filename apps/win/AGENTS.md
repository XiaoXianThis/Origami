# win

- Purpose: the Windows port of Origami. Groups top-level app windows and draws a tab bar above the active window of each group.
- Stack: C++20, Win32, Direct2D and DirectWrite, CMake with MSVC. Static CRT, so the exe needs no VC++ redistributable.
- Depends on: none. It is a separate implementation of the same product; no source is shared with `apps/mac`.

## Tasks

Commands run in `apps/win/`. This app builds on Windows only, so the commands live in the `windows` column.

| task | command | windows |
|---|---|---|
| install | | |
| dev | | cmake -S . -B build -G "Visual Studio 17 2022" -A x64 && cmake --build build --config Debug |
| test | | cmake -S . -B build -G "Visual Studio 17 2022" -A x64 && cmake --build build --config Release |
| build | | cmake -S . -B build -G "Visual Studio 17 2022" -A x64 && cmake --build build --config Release |
| ui | | powershell -NoProfile -ExecutionPolicy Bypass -File tests\drag-ui.ps1 |

`build` writes `origami.exe` to `$WOK_OUT` (`build/win/`) when the environment variable is set, otherwise to `build/bin/`.

`test` is the compile check. `ui` is the end-to-end drag test: it opens three throwaway windows, clicks and drags real tab bars, and checks merging, switching, and restoring on quit. It controls the mouse for a few seconds and edits `settings.ini` (restored afterwards), so run it on an idle desktop. `-HideMode minimize` covers the other hide mode.

## Layout

```
src/main.cpp              WinMain, per-monitor DPI awareness
src/app.h, app.cpp        message window, tray, event hooks, refresh loop, switching, merge
src/group_store.h/.cpp    group membership, merge, detach, pruning
src/window_enum.h/.cpp    window enumeration, visible frames, cached titles, theme detection
src/tab_bar.h/.cpp        bar metrics, Direct2D painting, drop highlight
src/overlay_window.*      layered overlay window, hit testing, tab drag
src/drag_visuals.*        drag ghost and drop frame, both click-through
src/settings.h/.cpp       settings in %APPDATA%\Origami\settings.ini
src/log.h/.cpp            optional diagnostic log, enabled with ORIGAMI_WIN_LOG=<path>
tests/drag-ui.ps1         end-to-end drag test
```

`work/specs/win-port-milestone-1/` records what the first slice covers and what is still missing.

## Conventions

- **Event driven, not polling.** Window moves, title changes, creation, destruction, and foreground changes arrive through `SetWinEventHook`; the refresh is coalesced with a one-shot timer. A 1 Hz timer exists only to heal missed events.
- **Never block on another process.** Titles go through `SendMessageTimeoutW` with a short budget; anything else uses cached values.
- **Physical pixels only.** The process is per-monitor DPI aware v2. Bar metrics are scaled by `GetDpiForWindow` of the target window, and client coordinates are already physical.
- **One overlay per group.** Overlays are created lazily, destroyed with their group, and always inserted directly above their target window; never use `HWND_TOPMOST` for ordering relative to an app window.
- **Hiding must be reversible.** Every hidden window keeps its original rect in `App::saved_rects_` and is restored before activation, on tray "restore all", and on exit. Add restore paths together with hide paths.
- **A hidden window never leaves its group.** A minimized window reports an icon-sized frame, so the enumeration marks it `minimized` instead of dropping it by size; otherwise every switch would dissolve groups.
- **Drop targets resolve to top-level windows.** `WindowFromPoint` returns whatever child window is under the cursor, so `GetAncestor(..., GA_ROOT)` decides the group. Dropping on a window body merges; dropping on empty desktop pulls the tab out.
- **Drag feedback is click-through.** The ghost and the drop frame use `WS_EX_TRANSPARENT`; they must never take part in hit testing, or the drag they illustrate would break.
- **Activate after hiding.** `SwitchTo` hides the other windows first and takes the foreground last, then re-asserts it on a short timer: minimizing the previously active window hands the foreground to an arbitrary neighbour.
- **Match the incoming window's frame.** Switching, and merging, copies the outgoing window's visible bounds onto the incoming one (`match_window_frame`, default on). Compare DWM extended frames, not window rects: each app's window rect includes its own invisible resize border, so copying a `GetWindowRect` result leaves the two windows visibly offset.
- **Repaint and present are separate.** `SetModel` marks a bar dirty when titles, the active tab, the theme, or the scale change; `MoveTo` must call `UpdateLayeredWindow` after a repaint even when the bar did not move, or the window keeps showing the previous bitmap.
- **No per-refresh allocation on the hot path** beyond the enumeration vector; bitmaps are rebuilt only when the bar size changes, and the D2D brush is reused.
- Set `ORIGAMI_WIN_LOG=<path>` to trace groups, drags, and drops when diagnosing behavior.
- Do not commit `build/`, `.vs/`, or `*.user`.
