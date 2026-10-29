# memory

Lessons learned by agents: pitfalls and proven approaches. Skim this before a larger task.

## Rules

- Write an entry only when the same problem comes up a second time, or when the user asks you to remember something.
- Record only what cannot be seen directly in the code and docs. Lessons about one app go to that app's `AGENTS.md`.
- Entry format: `- YYYY-MM-DD Symptom: ... Cause: ... Fix: ...`
- Delete entries that are no longer true. Past 50 entries, move coherent groups into `rules/` or `skills/` (with user approval).

## Entries

- 2026-10-30 Symptom: Swift builds succeed but the packaged app never gets window access. Cause: ad-hoc re-signing changes the CDHash, so the Accessibility grant made for the previous build no longer matches. Fix: remove the stale entry in System Settings → Privacy & Security → Accessibility, re-add the current `build/mac/Origami.app`, then relaunch; `PermissionProbe` prints the CDHash to confirm.
- 2026-10-30 Symptom: on Windows, every switch or merge silently dissolved the group back into single-window groups. Cause: hidden windows were dropped from the enumeration because a minimized window reports an icon-sized frame and the size filter rejected it. Fix: keep minimized windows, mark them, and only use on-screen windows as bar anchors.
- 2026-10-30 Symptom: a UI test that injects the mouse with `mouse_event`/`SendInput` does nothing at random. Cause: injected input is blocked while an elevated window (Task Manager) owns the foreground, and a DPI-unaware test process sends virtualized coordinates. Fix: call `SetProcessDpiAwarenessContext(PER_MONITOR_AWARE_V2)` first, and fall back to posted `WM_LBUTTONDOWN`/`WM_MOUSEMOVE` messages when the foreground cannot be taken.
- 2026-10-30 Symptom: after copying a window rect onto another window, the two are visibly offset by a few pixels. Cause: `GetWindowRect` includes the invisible resize border, which differs per app, while `DwmGetWindowAttribute(DWMWA_EXTENDED_FRAME_BOUNDS)` is what the user sees. Fix: match visible bounds and re-apply the target's own insets when calling `SetWindowPos`.
