# Cos72 Chrome Plugin (Vite + React)

This folder contains:

- `cos72-plugin/`: the Chrome extension (popup + background service worker)
- `cos72-plugin/community-server/`: a simple community server + database (Better Auth + Prisma) that stores sessions and bind relations

## Requirements

- Node.js
- pnpm
- PostgreSQL running on `localhost:5432`

## Install

From repo root:

```bash
pnpm -C cos72-plugin install
pnpm -C cos72-plugin/community-server install
```

## Community Server

### 1) Configure env

```bash
cp cos72-plugin/community-server/.env.example cos72-plugin/community-server/.env
```

Edit `cos72-plugin/community-server/.env`:

- `BETTER_AUTH_SECRET`: required, used to sign/verify auth state (sessions/tokens/cookies)
- `MIGRATION_SECRET`: required if you use export/import for bind relations (HMAC signing)
- `DATABASE_URL`: PostgreSQL connection string
- Optional for social login:
  - `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
  - `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`

Default local Postgres example:

```env
DATABASE_URL=postgresql://nicolasshuaishuai@localhost:5432/cos72_community?schema=public
```

### 2) Run migrations

```bash
pnpm -C cos72-plugin/community-server prisma:migrate
```

### 3) Start server

```bash
pnpm -C cos72-plugin/community-server dev
```

Server listens on `http://localhost:8787` by default.

Auth base URL is `http://localhost:8787/api/auth`.

## Extension (Plugin)

### Dev (UI)

```bash
pnpm -C cos72-plugin dev
```

This runs the Vite dev server for the popup UI (default `http://localhost:5173`).

In the popup UI, set:

- `Community server Origin`: `http://localhost:8787`

### Build (unpacked extension)

```bash
pnpm -C cos72-plugin build
```

Build output goes to:

- `cos72-plugin/dist/`

### Load into Chrome

1. Open `chrome://extensions`
2. Enable **Developer mode**
3. Click **Load unpacked**
4. Select the folder `cos72-plugin/dist`

## Useful scripts

- Plugin
  - `pnpm -C cos72-plugin lint`
  - `pnpm -C cos72-plugin build`
- Community server
  - `pnpm -C cos72-plugin/community-server build`
  - `pnpm -C cos72-plugin/community-server prisma:generate`
  - `pnpm -C cos72-plugin/community-server prisma:migrate`

---

## 中文说明

本目录包含：

- `cos72-plugin/`：Chrome 扩展（popup UI + background service worker）
- `cos72-plugin/community-server/`：社区服务端 + 数据库（Better Auth + Prisma），用于存储会话与 bind relation

## 环境要求

- Node.js
- pnpm
- PostgreSQL（运行在 `localhost:5432`）

## 安装

在仓库根目录执行：

```bash
pnpm -C cos72-plugin install
pnpm -C cos72-plugin/community-server install
```

## 社区服务端

### 1) 配置 env

```bash
cp cos72-plugin/community-server/.env.example cos72-plugin/community-server/.env
```

编辑 `cos72-plugin/community-server/.env`：

- `BETTER_AUTH_SECRET`：必填，用于签名/校验登录态（sessions/tokens/cookies）
- `MIGRATION_SECRET`：如需导出/导入 bind relation 则必填（HMAC 签名）
- `DATABASE_URL`：PostgreSQL 连接串
- 社交登录（可选）：
  - `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`
  - `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`

本地 Postgres 示例：

```env
DATABASE_URL=postgresql://nicolasshuaishuai@localhost:5432/cos72_community?schema=public
```

### 2) 运行迁移

```bash
pnpm -C cos72-plugin/community-server prisma:migrate
```

### 3) 启动服务

```bash
pnpm -C cos72-plugin/community-server dev
```

默认监听 `http://localhost:8787`。

Auth base URL 为 `http://localhost:8787/api/auth`。

## 扩展（插件）

### 开发（UI）

```bash
pnpm -C cos72-plugin dev
```

这会启动 popup UI 的 Vite 开发服务器（默认 `http://localhost:5173`）。

在 popup UI 中设置：

- `Community server Origin`：`http://localhost:8787`

### 构建（解压加载）

```bash
pnpm -C cos72-plugin build
```

构建产物输出到：

- `cos72-plugin/dist/`

### 在 Chrome 中加载

1. 打开 `chrome://extensions`
2. 开启 **开发者模式**
3. 点击 **加载已解压的扩展程序**
4. 选择目录 `cos72-plugin/dist`

## 常用脚本

- 插件
  - `pnpm -C cos72-plugin lint`
  - `pnpm -C cos72-plugin build`
- 社区服务端
  - `pnpm -C cos72-plugin/community-server build`
  - `pnpm -C cos72-plugin/community-server prisma:generate`
  - `pnpm -C cos72-plugin/community-server prisma:migrate`
