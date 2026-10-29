# Origami

[English](README.en.md) | 中文

Origami （/ˌɔːrɪˈɡɑːmi/）是一款 macOS 菜单栏工具，把多个应用窗口像浏览器标签页一样折叠成组，并在窗口上方叠加标签栏，实现快速、无痕的窗口切换。开发者：[大不6仙](https://space.bilibili.com/12724008)

> 像折纸一样，把散落的窗口叠成一组，需要时再展开。

## 功能

- **窗口分组与标签栏** — 将多个窗口合并为一组，在窗口顶部显示可点击的标签栏
- **无痕切换** — 多种隐藏策略，切换组内窗口时尽量不留最小化痕迹
- **拖拽分组** — 拖动标签合并窗口组；支持拖出窗口后自动移出当前组
- **标签位置自定义** — 水平 / 垂直锚点、内外位置、偏移与最大宽度均可调节
- **屏外窗口恢复** — 检测完全位于屏幕外的窗口，一键移回屏幕内
- **主题** — 浅色 / 深色 / 跟随系统，标签栏与设置窗口同步切换

### 隐藏方式

| 模式 | 说明 |
| --- | --- |
| 最小化 | 兼容性最好，切换时会有最小化 / 恢复痕迹 |
| 透明隐藏 | 更无痕，不进入 Dock 最小化区 |
| 移动到屏外【默认】 | 非当前窗口临时移到屏幕外 |
| 移动到其他桌面 | 临时移到另一个 Space（需至少两个普通桌面） |
| 缩到极小 | 非当前窗口缩到极小尺寸，切换时再恢复 |

## 系统要求

- macOS 13 Ventura 或更高版本，Apple Silicon 或 Intel Mac
- Windows 10 或 Windows 11，x64

## 下载安装

[Latest release](https://github.com/XiaoXianThis/Origami/releases/latest)

**macOS**

1. 从 GitHub Releases 下载 DMG（推荐）或 ZIP
2. **DMG**：打开镜像，将 Origami 拖入「应用程序」；**ZIP**：解压后将 `Origami.app` 拖入「应用程序」
3. **首次打开**：右键 `Origami.app` → **打开** → 再点「打开」（未公证应用需此步骤）
4. 在 **系统设置 → 隐私与安全性 → 辅助功能** 中勾选 Origami
5. 若使用全局快捷键，还需在 **输入监控** 中勾选 Origami

> 预构建包使用 ad-hoc 签名，无需 Apple 开发者账号。首次打开时 macOS 可能提示「无法验证开发者」，按上述步骤即可。

**Windows**

1. 下载 `Origami-v{版本}-windows-x64.zip`
2. 解压到任意目录，双击 `origami.exe` 即可，没有安装程序，也不需要额外运行时
3. 首次运行若出现「Windows 已保护你的电脑」，点「更多信息 → 仍要运行」（尚未代码签名）
4. 程序常驻托盘，右键托盘图标可切换隐藏方式、复原窗口或退出

> Windows 版不需要辅助功能一类的授权；受 UIPI 限制，无法接管以管理员权限运行的窗口。

细节与排错见 [docs/guides/install.md](guides/install.md)。

## 使用

1. 启动 Origami 后，它会常驻菜单栏（Windows 版常驻托盘）
2. 点击菜单栏图标 → **显示窗口** 打开设置
3. 将窗口拖入同一组，或通过标签栏操作合并 / 切换
4. 在设置中按需选择隐藏方式、标签位置等

## 项目结构

顶层是工作区，不是某个语言的工程。规则见 [AGENTS.md](../AGENTS.md)。

```
Origami/
├── apps/
│   ├── mac/              # macOS 菜单栏应用（Swift Package）
│   ├── win/              # Windows 版（C++20 / Win32 / Direct2D）
│   └── web/              # 产品介绍站点（Astro + Tailwind CSS）
├── build/                # 构建产物，仅提交 README
├── docs/                 # 本页、架构说明、决策记录、指南、接口契约
└── work/                 # spec、Agent 资料、脚本、测试、素材、基础设施
```

## 从源码构建

macOS 应用（需要 Xcode 或 Swift 5.10 工具链）：

```sh
cd apps/mac
./scripts/package.sh 0.1.0
open ../../build/mac/Origami.app
```

调试构建：

```sh
cd apps/mac
swift build
.build/debug/Origami
```

产品站点：

```sh
cd apps/web
npm install
npm run dev      # 本地预览 http://localhost:4321
npm run build    # 构建产物输出到 apps/web/dist
```

Windows 版（需要 Visual Studio 2022 的 C++ 工具链和 Windows SDK）：

```sh
cd apps/win
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
build\bin\origami.exe
```

各 app 的完整命令见 [apps/mac/AGENTS.md](../apps/mac/AGENTS.md)、[apps/win/AGENTS.md](../apps/win/AGENTS.md) 和 [apps/web/AGENTS.md](../apps/web/AGENTS.md)；架构说明见 [docs/architecture/overview.md](architecture/overview.md)。

## Windows 版

Windows 版是独立实现，不复用 macOS 源码。已支持：窗口分组与叠加标签栏、点击切换（切换和合并时会把目标窗口放到上一个窗口的位置和大小）、拖拽合并与拖出拆分、标签文字省略号截断，以及「最小化」「移动到屏外」两种隐藏方式。它不需要辅助功能一类的授权，但受 UIPI 限制，无法接管以管理员权限运行的窗口。

尚未实现：设置窗口（目前用托盘菜单）、全局快捷键、透明隐藏与虚拟桌面隐藏、屏外窗口恢复列表、应用图标与代码签名。工程说明见 [apps/win/AGENTS.md](../apps/win/AGENTS.md)。

## 发布与部署

打 tag 触发 GitHub Actions 构建 Universal 包并发布到 Releases；站点通过 Wrangler 部署到 Cloudflare Pages。完整步骤见 [docs/guides/release.md](guides/release.md)。

Cloudflare Pages 构建设置：

| 配置项 | 值 |
| --- | --- |
| Root directory | `apps/web` |
| Build command | `npm run build` |
| Build output directory | `dist` |
| Node.js version | `22` |

## 许可证

MIT
