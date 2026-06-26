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


| 模式         | 说明                       |
| ---------- | ------------------------ |
| 最小化        | 兼容性最好，切换时会有最小化 / 恢复痕迹    |
| 透明隐藏       | 更无痕，不进入 Dock 最小化区        |
| 底层跟随       | 非当前窗口缩小并叠在当前窗口底层         |
| 移动到屏外【默认】  | 非当前窗口临时移到屏幕外             |
| 移动到其他桌面    | 临时移到另一个 Space（需至少两个普通桌面） |
| 缩到极小       | 非当前窗口缩到极小尺寸，切换时再恢复       |


## 系统要求

- macOS 13 Ventura 或更高版本
- Apple Silicon 或 Intel Mac

## 下载安装

[Latest release](https://github.com/XiaoXianThis/Origami/releases/latest)

1. 从 [GitHub Releases](https://github.com/XiaoXianThis/Origami/releases/latest) 下载 DMG（推荐）或 ZIP
2. **DMG**：打开镜像，将 Origami 拖入「应用程序」；**ZIP**：解压后将 `Origami.app` 拖入「应用程序」
3. **首次打开**：右键 `Origami.app` → **打开** → 再点「打开」（未公证应用需此步骤）
4. 在 **系统设置 → 隐私与安全性 → 辅助功能** 中勾选 Origami
5. 若使用全局快捷键，还需在 **输入监控** 中勾选 Origami

> 预构建包使用 ad-hoc 签名，无需 Apple 开发者账号。首次打开时 macOS 可能提示「无法验证开发者」，按上述步骤即可。

## 项目结构

```
Origami/
├── Sources/Origami/     # macOS 应用源码
├── Resources/           # Info.plist 等资源
├── scripts/             # 打包脚本
├── Package.swift
├── web/                 # 产品介绍静态站点（Astro + Tailwind CSS）
└── README.md
```

## macOS 应用

### 从源码构建

```bash
git clone https://github.com/XiaoXianThis/Origami.git
cd Origami
./scripts/package.sh 0.1.0
open dist/Origami.app
```

调试构建：

```bash
swift build
.build/debug/Origami
```

### 发布新版本

```bash
git tag v0.1.0
git push origin v0.1.0
```

推送 tag 后，GitHub Actions 会自动构建 Universal 包并发布到 Releases。

### 使用

1. 启动 Origami 后，它会常驻菜单栏
2. 点击菜单栏图标 → **显示窗口** 打开设置
3. 将窗口拖入同一组，或通过标签栏操作合并 / 切换
4. 在设置中按需选择隐藏方式、标签位置等

## 产品介绍站点

静态站点位于 `web/` 目录，可部署到 Cloudflare Pages。支持**中文（默认）**与**英文**（`/en/`）切换，以及浅色 / 深色主题。

```bash
cd web
npm install
npm run dev      # 本地预览 http://localhost:4321
npm run build    # 构建产物输出到 web/dist/
```

Cloudflare Pages 构建设置：


| 配置项                    | 值               |
| ---------------------- | --------------- |
| Root directory         | `web`           |
| Build command          | `npm run build` |
| Build output directory | `dist`          |
| Node.js version        | `22`            |


详见 `[web/README.md](web/README.md)`。

## 许可证

MIT