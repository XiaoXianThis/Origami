# Install

For people installing the released app. The macOS build is not notarized, so the first launch needs one extra step.

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

## Steps

1. Download the DMG (recommended) or the ZIP from [the latest release](https://github.com/XiaoXianThis/Origami/releases/latest).
2. Open the DMG and drag `Origami` into Applications. For the ZIP, unzip it and move `Origami.app` into Applications.
3. Right-click `Origami.app`, choose **Open**, then **Open** again. macOS blocks a plain double-click the first time because the app is ad-hoc signed.
4. Open **System Settings → Privacy & Security → Accessibility** and turn on Origami. Without this the app can see no windows.
5. If you use the global tab-switch shortcut, also turn on Origami under **Privacy & Security → Input Monitoring**.

The menu bar icon opens the settings window. If the settings page reports that Accessibility is not granted even though the switch is on, the entry belongs to an older copy of the app: remove every Origami entry, add `build/mac/Origami.app` or `/Applications/Origami.app` again, quit from the menu bar, and relaunch.

## Uninstall

Quit from the menu bar, then move `Origami.app` to the Trash. Settings live in the app's `UserDefaults` domain and stay behind; `defaults delete com.xiaoxianthis.origami` removes them.
