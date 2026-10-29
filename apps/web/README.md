# Origami Web

Origami 产品介绍静态站点，基于 [Astro](https://astro.build) + [Tailwind CSS](https://tailwindcss.com) 构建，部署在 [Cloudflare Pages](https://pages.cloudflare.com)。

本目录是 Origami 仓库 `apps/` 下的 `web` app；源码结构与命令见 [AGENTS.md](AGENTS.md)。

## 本地开发

```sh
cd apps/web
npm install
npm run dev
```

浏览器访问 `http://localhost:4321`。

## 构建

```sh
npm run build
npm run preview
```

构建产物输出到 `apps/web/dist`。在工作区根目录用 `wok build web` 构建时，产物会写到 `build/web`。

## 部署到 Cloudflare Pages

### 方式一：Git 连接

1. 连接 GitHub 仓库 [XiaoXianThis/Origami](https://github.com/XiaoXianThis/Origami)
2. 配置构建设置：

| 配置项 | 值 |
| --- | --- |
| Root directory | `apps/web` |
| Framework preset | Astro |
| Build command | `npm run build` |
| Build output directory | `dist` |
| Node.js version | `22`（或 ≥ 22.12） |

3. 保存并部署

### 方式二：Wrangler CLI 直接上传

```sh
npm run build
npx wrangler pages deploy dist --project-name origami
```

首次使用需登录 Cloudflare 账号：

```sh
npx wrangler login
```

完整的发版流程见 [docs/guides/release.md](../../docs/guides/release.md)。
