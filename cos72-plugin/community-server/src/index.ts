import { cors } from 'hono/cors'
import { Hono } from 'hono'
import { auth } from './auth'
import { serve } from '@hono/node-server'
import { prisma } from './prisma'
import { createHmac, randomUUID } from 'node:crypto'

const app = new Hono({
  strict: false,
})

app.use(
  '*',
  cors({
    origin: (process.env.TRUSTED_ORIGINS ?? 'http://localhost:5173')
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean),
    credentials: true,
  }),
)

app.get('/health', (c) => c.text('ok'))

app.on(['POST', 'GET'], '/api/auth/*', (c) => {
  return auth.handler(c.req.raw)
})

async function requireUserId(request: Request) {
  const session = await auth.api.getSession({
    headers: request.headers,
  })
  const userId = session?.user?.id
  if (!userId) {
    return null
  }
  return userId
}

function signPayload(payload: unknown) {
  const secret = process.env.MIGRATION_SECRET
  if (!secret) {
    throw new Error('MIGRATION_SECRET is required')
  }
  const json = JSON.stringify(payload)
  const signature = createHmac('sha256', secret).update(json).digest('base64url')
  return { json, signature }
}

app.get('/api/bind-relations', async (c) => {
  const userId = await requireUserId(c.req.raw)
  if (!userId) {
    return c.json({ error: 'unauthorized' }, 401)
  }
  const items = await prisma.bindRelation.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
    select: { id: true, kind: true, value: true, meta: true, createdAt: true },
  })
  return c.json({ items })
})

app.post('/api/bind-relations', async (c) => {
  const userId = await requireUserId(c.req.raw)
  if (!userId) {
    return c.json({ error: 'unauthorized' }, 401)
  }
  const body = await c.req.json().catch(() => null)
  const kind = typeof body?.kind === 'string' ? body.kind.trim() : ''
  const value = typeof body?.value === 'string' ? body.value.trim() : ''
  const meta = typeof body?.meta === 'string' ? body.meta : null
  if (!kind || !value) {
    return c.json({ error: 'invalid_input' }, 400)
  }
  const created = await prisma.bindRelation.create({
    data: { userId, kind, value, meta },
    select: { id: true, kind: true, value: true, meta: true, createdAt: true },
  })
  return c.json({ item: created })
})

app.delete('/api/bind-relations/:id', async (c) => {
  const userId = await requireUserId(c.req.raw)
  if (!userId) {
    return c.json({ error: 'unauthorized' }, 401)
  }
  const id = c.req.param('id')
  const existing = await prisma.bindRelation.findUnique({
    where: { id },
    select: { userId: true },
  })
  if (!existing) {
    return c.json({ error: 'not_found' }, 404)
  }
  if (existing.userId !== userId) {
    return c.json({ error: 'forbidden' }, 403)
  }
  await prisma.bindRelation.delete({ where: { id } })
  return c.json({ ok: true })
})

app.get('/api/bind-relations/export', async (c) => {
  const userId = await requireUserId(c.req.raw)
  if (!userId) {
    return c.json({ error: 'unauthorized' }, 401)
  }

  const [user, accounts, bindRelations] = await Promise.all([
    prisma.user.findUnique({
      where: { id: userId },
      select: { email: true, name: true, image: true },
    }),
    prisma.account.findMany({
      where: { userId },
      select: {
        providerId: true,
        accountId: true,
        password: true,
        scope: true,
      },
      orderBy: { createdAt: 'asc' },
    }),
    prisma.bindRelation.findMany({
      where: { userId },
      select: { kind: true, value: true, meta: true },
      orderBy: { createdAt: 'asc' },
    }),
  ])

  if (!user) {
    return c.json({ error: 'unauthorized' }, 401)
  }

  const payload = {
    version: 1,
    exportedAt: new Date().toISOString(),
    user,
    accounts: accounts.map((a) => ({
      providerId: a.providerId,
      accountId: a.accountId,
      password: a.password,
      scope: a.scope,
    })),
    bindRelations,
  }

  const { json, signature } = signPayload(payload)
  return c.json({ payload: json, signature })
})

app.post('/api/bind-relations/import', async (c) => {
  const userId = await requireUserId(c.req.raw)
  if (!userId) {
    return c.json({ error: 'unauthorized' }, 401)
  }

  const body = await c.req.json().catch(() => null)
  const payloadJson = typeof body?.payload === 'string' ? body.payload : ''
  const signature = typeof body?.signature === 'string' ? body.signature : ''
  if (!payloadJson || !signature) {
    return c.json({ error: 'invalid_input' }, 400)
  }

  const expected = createHmac('sha256', process.env.MIGRATION_SECRET ?? '')
    .update(payloadJson)
    .digest('base64url')
  if (!process.env.MIGRATION_SECRET || expected !== signature) {
    return c.json({ error: 'invalid_signature' }, 400)
  }

  const payload = JSON.parse(payloadJson) as {
    version: number
    accounts?: Array<{
      providerId: string
      accountId: string
      password?: string | null
      scope?: string | null
    }>
    bindRelations?: Array<{ kind: string; value: string; meta?: string | null }>
  }

  if (payload.version !== 1) {
    return c.json({ error: 'unsupported_version' }, 400)
  }

  const conflicts: Array<{ type: 'account' | 'bind'; key: string }> = []

  const accounts = Array.isArray(payload.accounts) ? payload.accounts : []
  for (const a of accounts) {
    if (!a?.providerId || !a?.accountId) continue
    const existing = await prisma.account.findUnique({
      where: { providerId_accountId: { providerId: a.providerId, accountId: a.accountId } },
      select: { userId: true },
    })
    if (existing && existing.userId !== userId) {
      conflicts.push({ type: 'account', key: `${a.providerId}:${a.accountId}` })
      continue
    }
    if (!existing) {
      await prisma.account.create({
        data: {
          id: randomUUID(),
          providerId: a.providerId,
          accountId: a.accountId,
          userId,
          password: a.password ?? null,
          scope: a.scope ?? null,
        },
      })
    }
  }

  const binds = Array.isArray(payload.bindRelations) ? payload.bindRelations : []
  for (const b of binds) {
    if (!b?.kind || !b?.value) continue
    const existing = await prisma.bindRelation.findUnique({
      where: { kind_value: { kind: b.kind, value: b.value } },
      select: { userId: true },
    })
    if (existing && existing.userId !== userId) {
      conflicts.push({ type: 'bind', key: `${b.kind}:${b.value}` })
      continue
    }
    if (!existing) {
      await prisma.bindRelation.create({
        data: {
          userId,
          kind: b.kind,
          value: b.value,
          meta: b.meta ?? null,
        },
      })
    }
  }

  return c.json({ ok: conflicts.length === 0, conflicts })
})

app.notFound((c) => c.json({ error: 'not found' }, 404))

export default app

const port = Number(process.env.PORT ?? '8787')

serve({
  fetch: app.fetch,
  port,
})
