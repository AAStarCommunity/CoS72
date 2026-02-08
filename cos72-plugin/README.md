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

