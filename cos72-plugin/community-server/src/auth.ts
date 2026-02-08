import { passkey } from '@better-auth/passkey'
import { prismaAdapter } from 'better-auth/adapters/prisma'
import { bearer, jwt } from 'better-auth/plugins'
import { betterAuth } from 'better-auth'
import { prisma } from './prisma'

const trustedOrigins = (process.env.TRUSTED_ORIGINS ?? 'http://localhost:5173')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean)

export const auth = betterAuth({
  baseURL:
    process.env.BETTER_AUTH_BASE_URL ??
    `http://localhost:${process.env.PORT ?? '8787'}/api/auth`,
  database: prismaAdapter(prisma, {
    provider: 'postgresql',
  }),
  trustedOrigins,
  emailAndPassword: {
    enabled: true,
  },
  socialProviders: {
    ...(process.env.GITHUB_CLIENT_ID && process.env.GITHUB_CLIENT_SECRET
      ? {
          github: {
            clientId: process.env.GITHUB_CLIENT_ID,
            clientSecret: process.env.GITHUB_CLIENT_SECRET,
          },
        }
      : {}),
    ...(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET
      ? {
          google: {
            clientId: process.env.GOOGLE_CLIENT_ID,
            clientSecret: process.env.GOOGLE_CLIENT_SECRET,
          },
        }
      : {}),
  },
  plugins: [
    bearer(),
    jwt(),
    passkey({
      rpID: process.env.PASSKEY_RP_ID ?? 'localhost',
      rpName: 'Cos72 Community',
    }),
  ],
})
