# Install

For people installing the released apps. Neither build is code signed yet, so the first launch needs one extra step on each platform.

## Requirements

- macOS 13 Ventura or later, Apple Silicon or Intel Mac
- Windows 10 or Windows 11, x64

## macOS

1. Download the DMG (recommended) or the ZIP from [the latest release](https://github.com/XiaoXianThis/Origami/releases/latest).
2. Open the DMG and drag `Origami` into Applications. For the ZIP, unzip it and move `Origami.app` into Applications.
3. Right-click `Origami.app`, choose **Open**, then **Open** again. macOS blocks a plain double-click the first time because the app is ad-hoc signed.
4. Open **System Settings → Privacy & Security → Accessibility** and turn on Origami. Without this the app can see no windows.
5. If you use the global tab-switch shortcut, also turn on Origami under **Privacy & Security → Input Monitoring**.

The menu bar icon opens the settings window. If the settings page reports that Accessibility is not granted even though the switch is on, the entry belongs to an older copy of the app: remove every Origami entry, add `build/mac/Origami.app` or `/Applications/Origami.app` again, quit from the menu bar, and relaunch.

## Windows

1. Download `Origami-v<version>-windows-x64.zip` from [the latest release](https://github.com/XiaoXianThis/Origami/releases/latest).
2. Unzip it into any folder, for example `%LOCALAPPDATA%\Origami`, and run `origami.exe`. There is no installer and no runtime to install.
3. SmartScreen warns the first time because the build is not code signed: choose **More info → Run anyway**.
4. The app lives in the notification area. Left-click opens nothing yet; right-click gives **启用 Origami**, **复原全部窗口**, **隐藏方式**, **切换时匹配窗口大小**, and **退出**.

The Windows build asks for no permission. UIPI still blocks it from touching windows owned by an elevated process, such as Task Manager started as administrator.

## Uninstall

- macOS: quit from the menu bar, then move `Origami.app` to the Trash. Settings live in the app's `UserDefaults` domain and stay behind; `defaults delete com.xiaoxianthis.origami` removes them.
- Windows: quit from the tray menu, delete the folder, and remove `%APPDATA%\Origami` to drop the settings.
