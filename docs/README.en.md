# Origami

English | [中文](README.md)

Origami (/ˌɔːrɪˈɡɑːmi/) is a macOS menu bar app that groups multiple app windows like browser tabs, with an overlay tab bar for fast, seamless window switching. Developer: [大不6仙](https://space.bilibili.com/12724008)

> Like origami — fold scattered windows into a group, then unfold when you need them.

## Features

- **Window grouping & tab bar** — Merge multiple windows into one group with a clickable tab bar on top
- **Seamless switching** — Multiple hide strategies to switch between grouped windows with minimal minimize traces
- **Drag to group** — Drag tabs to merge window groups; drag out to automatically leave the current group
- **Custom tab placement** — Adjust horizontal / vertical anchor, inside/outside position, offset, and max width
- **Off-screen recovery** — Detect windows fully off-screen and move them back with one click
- **Themes** — Light / dark / follow system — tab bar and settings window stay in sync

### Hide Modes

| Mode | Description |
| --- | --- |
| Minimize | Best compatibility; switching leaves minimize / restore traces |
| Transparent hide | More seamless; does not enter the Dock minimize area |
| Move off-screen **[default]** | Temporarily moves non-active windows off-screen |
| Move to another Space | Temporarily moves to another Space (requires at least two regular desktops) |
| Shrink tiny | Non-active windows shrink to a tiny size and restore on switch |

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel Mac

## Download & Install

[Latest release](https://github.com/XiaoXianThis/Origami/releases/latest)

1. Download the DMG (recommended) or ZIP from GitHub Releases
2. **DMG**: Open the image and drag Origami into Applications; **ZIP**: Unzip and drag `Origami.app` into Applications
3. **First launch**: Right-click `Origami.app` → **Open** → Open again (required for unsigned apps)
4. Enable Origami under **System Settings → Privacy & Security → Accessibility**
5. For global shortcuts, also enable Origami under **Input Monitoring**

> Pre-built packages use ad-hoc signing — no Apple Developer account needed. macOS may warn that the developer cannot be verified on first launch; follow the steps above.

Details and troubleshooting: [docs/guides/install.md](guides/install.md).

## Usage

1. After launching, Origami lives in the menu bar
2. Click the menu bar icon → **Show Window** to open settings
3. Drag windows into a group, or merge / switch via the tab bar
4. Choose hide mode, tab placement, and other preferences in settings

## Project Structure

The top level is a workspace, not a project in one language. The rules are in [AGENTS.md](../AGENTS.md).

```
Origami/
├── apps/
│   ├── mac/              # the macOS menu bar app (Swift package)
│   ├── win/              # the Windows port (C++20 / Win32 / Direct2D, in progress)
│   └── web/              # the product site (Astro + Tailwind CSS)
├── build/                # build output; only its README is committed
├── docs/                 # this page, architecture, decision records, guides, contracts
└── work/                 # specs, agent material, scripts, tests, assets, infrastructure
```

## Build from Source

macOS app (needs Xcode or a Swift 5.10 toolchain):

```sh
cd apps/mac
./scripts/package.sh 0.1.0
open ../../build/mac/Origami.app
```

Debug build:

```sh
cd apps/mac
swift build
.build/debug/Origami
```

Product site:

```sh
cd apps/web
npm install
npm run dev      # preview at http://localhost:4321
npm run build    # output goes to apps/web/dist
```

Windows port (needs the C++ toolchain and Windows SDK from Visual Studio 2022):

```sh
cd apps/win
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
build\bin\origami.exe
```

Full commands per app live in [apps/mac/AGENTS.md](../apps/mac/AGENTS.md), [apps/win/AGENTS.md](../apps/win/AGENTS.md), and [apps/web/AGENTS.md](../apps/web/AGENTS.md). How the pieces fit: [docs/architecture/overview.md](architecture/overview.md).

## Windows Port

The Windows app is an independent implementation that shares no source with the macOS app, and it is still in progress. Working today: window grouping, the overlay tab bar, click to switch (switching and merging move the incoming window into the outgoing window's position and size), drag to merge, and the minimize and move-off-screen hide modes. It needs no Accessibility-style permission, but UIPI keeps it away from windows owned by elevated processes. The settings window, the global shortcut, and the remaining hide modes are not there yet.

## Release and Deploy

Pushing a tag makes GitHub Actions build the universal package and publish it to Releases; the site is deployed to Cloudflare Pages with Wrangler. Steps: [docs/guides/release.md](guides/release.md).

Cloudflare Pages build settings:

| Setting | Value |
| --- | --- |
| Root directory | `apps/web` |
| Build command | `npm run build` |
| Build output directory | `dist` |
| Node.js version | `22` |

## License

MIT
