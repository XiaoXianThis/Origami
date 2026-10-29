# win port, milestone 1

## Requirements

- A Windows app in `apps/win` that groups windows and draws a tab bar above the active window.
- No installer and no runtime dependency: one static-linked exe.
- Idle CPU near zero: refresh on window events, not on a frame timer.
- No Accessibility-style permission prompts; only the UIPI limits of the process apply.
- Tray menu to enable, restore all windows, choose the hide mode, and quit.
- Windows are never left hidden: every hidden window is restored before activation, on demand, and on exit.
