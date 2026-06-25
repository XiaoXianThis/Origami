# Origami Web

Origami 产品介绍静态站点，基于 [Astro](https://astro.build) + [Tailwind CSS](https://tailwindcss.com) 构建，可部署到 [Cloudflare Pages](https://pages.cloudflare.com)。

本目录为 [Origami](https://github.com/XiaoXianThis/Origami)  monorepo 的 `web/` 子项目。

## 本地开发

```bash
cd web
npm install
npm run dev
```

浏览器访问 `http://localhost:4321`。

## 构建

```bash
npm run build
npm run preview
```

构建产物输出到 `dist/` 目录。

## 部署到 Cloudflare Pages

### 方式一：Git 连接（推荐）

1. 连接 GitHub 仓库 [XiaoXianThis/Origami](https://github.com/XiaoXianThis/Origami)
2. 配置构建设置：

| 配置项 | 值 |
| --- | --- |
| Root directory | `web` |
| Framework preset | Astro |
| Build command | `npm run build` |
| Build output directory | `dist` |
| Node.js version | `22`（或 ≥ 22.12） |

3. 保存并部署

### 方式二：Wrangler CLI 直接上传

```bash
npm run build
npx wrangler pages deploy dist --project-name origami
```

首次使用需登录 Cloudflare 账号：

```bash
npx wrangler login
```

## 项目结构

```
web/
├── src/
│   ├── components/     # 页面区块组件
│   ├── layouts/        # 页面布局
│   ├── pages/          # 路由页面
│   └── styles/         # 全局样式
└── public/             # 静态资源
```

## 相关链接

- 产品源码：仓库根目录 `Sources/Origami/`
