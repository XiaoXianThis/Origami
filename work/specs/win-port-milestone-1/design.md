# Windows port plan

## Scope of this slice

Milestone 1 ports the engine core, not the whole product:

- enumerate top-level app windows and keep a group per window
- one layered, non-activating tab bar per group, positioned above the active window
- click a tab to switch; the other windows of the group are hidden
- drag a tab onto another group's bar to merge
- two hide modes: minimize and move off screen
- event driven refresh through `SetWinEventHook`, plus a 1 Hz safety tick
- tray menu: enable, restore all, hide mode, exit

Not ported yet: settings window, global tab shortcut, transparent and virtual-desktop hide modes, off-screen recovery list, tab placement options, theme following, single-instance focus handoff beyond showing the tray.

## Layout

```
CMakeLists.txt        MSVC, C++20, static CRT, output to $WOK_OUT
src/main.cpp          WinMain, DPI awareness
src/app.*             message window, tray, hooks, refresh loop, switching
src/group_store.*     which windows belong to which group
src/window_enum.*     enumeration, visible frames, titles, theme
src/tab_bar.*         layout metrics and Direct2D painting
src/overlay_window.*  layered overlay window, hit testing, drag
src/settings.*        ini file in %APPDATA%
```

## Notes

- Coordinates are physical pixels everywhere; the app is per-monitor DPI aware v2, and bar metrics are scaled by `GetDpiForWindow`.
- Titles come from `WM_GETTEXT` through `SendMessageTimeoutW` with a 40 ms budget, so a hung app cannot stall the refresh.
- The overlay is `WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE`; alpha-zero pixels are click-through, and the bar is inserted directly above its target window with `SetWindowPos(hwnd, target, ...)`.
- Moving windows off screen is reversible: the original rect is remembered per window and restored before activation or on exit.

## Rendering

Each bar is painted into a premultiplied 32-bit DIB with Direct2D and presented with `UpdateLayeredWindow`. Painting and presenting are separate steps: a model change (active tab, titles, theme) repaints and re-presents even when the bar did not move, while a z-order-only update skips both. Tab labels are centered in the tab, clipped to it, and end with an ellipsis when the title does not fit.

## Drag behavior

- Pressing a tab starts a drag after a four-pixel threshold. A click without movement switches windows.
- While dragging, a ghost (single-tab bar) follows the cursor and a translucent frame marks the window the tab would merge into. Both are `WS_EX_TRANSPARENT | WS_EX_TOPMOST` layered windows, created lazily and released when the drag ends.
- The drop target is resolved from `WindowFromPoint` promoted to its top-level window: another group's bar or window body merges, the same group's window cancels, empty desktop detaches into a separate group.
- Dropping never loses a window: a merged window becomes the target group's active window, and a detached one is restored and focused.

## Frame matching

Switching a group onto another window, or merging a window into a group, moves the incoming window into the outgoing one's frame: same visible bounds, same position. Both windows keep their own invisible resize border, so the copy works on DWM extended frames and adjusts the target's window rect by its own insets; copying `GetWindowRect` directly leaves a visible offset. A maximized outgoing window maximizes the incoming one instead of copying a screen-sized rect. The behavior is on by default and can be turned off from the tray menu (`match_window_frame` in the ini).

## Test

`tests/drag-ui.ps1` creates three throwaway windows, starts the app, and drives the bars. It uses real mouse input when it can take the foreground; when an elevated window owns it, synthetic input is blocked by UIPI, so the same gestures are posted as window messages. Checks: bar per window, click switch, ghost and frame visible, merge on a window body, cancel when dropped back on its own bar, three-window group, switching inside it, and every window restored on quit. Both hide modes are covered (`-HideMode minimize`).

## Measured on Windows 11 23H2

With seven managed windows:

| metric | value |
|---|---|
| exe | 167 KB, static CRT, no VC++ redistributable |
| private working set | 11 MB |
| working set (with shared DLL pages) | 38 MB |
| idle CPU | below one 15.6 ms timer tick over 15 s |
| threads / handles | 32 / ~360, constant over 40 s |

The thread count comes from the D3D11 device that Direct2D creates; it does not grow with the number of overlays. Presenting a bar is skipped when neither its content nor its position changed, which is what brought idle CPU down to the measurement above.
