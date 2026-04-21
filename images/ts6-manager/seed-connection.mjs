#!/usr/bin/env node
// Seed the default TsServerConfig row in the TS6 Manager database from env vars.
//
// Runs on every container start. It is a no-op unless BOTH conditions hold:
//   1. TS_API_KEY is set (signals the operator wants auto-seeded config)
//   2. No TsServerConfig row exists yet (idempotent — never clobbers user edits)
//
// The API key and SSH password are encrypted the same way the backend encrypts
// them (AES-256-GCM with scrypt-derived key from ENCRYPTION_KEY or JWT_SECRET).
// The format matches `packages/backend/src/utils/crypto.ts` exactly so the
// backend's `decrypt()` can read them back.

import { PrismaClient } from '/app/packages/backend/generated/prisma/index.js';
import { createCipheriv, randomBytes, scryptSync } from 'node:crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;
const SALT = 'ts6-webui-enc-v1';

function deriveKey() {
  const source = process.env.ENCRYPTION_KEY || process.env.JWT_SECRET;
  if (!source) {
    throw new Error('Neither ENCRYPTION_KEY nor JWT_SECRET set; cannot encrypt seed values');
  }
  return scryptSync(source, SALT, 32);
}

function encrypt(plaintext) {
  const key = deriveKey();
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv(ALGORITHM, key, iv);
  let encrypted = cipher.update(plaintext, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  const tag = cipher.getAuthTag();
  return `enc:${iv.toString('hex')}:${tag.toString('hex')}:${encrypted}`;
}

async function main() {
  const apiKey = (process.env.TS_API_KEY || '').trim();
  if (!apiKey) {
    console.log('[seed] TS_API_KEY not set - skipping connection seeding.');
    return;
  }

  const prisma = new PrismaClient();
  try {
    const count = await prisma.tsServerConfig.count();
    if (count > 0) {
      console.log(`[seed] ${count} server connection(s) already present - skipping seed.`);
      return;
    }

    const host = (process.env.TS_HOST || '').trim() || '127.0.0.1';
    const name = (process.env.TS_NAME || '').trim() || `TeamSpeak @ ${host}`;
    const webqueryPort = parseInt(process.env.TS_WEBQUERY_PORT || '10080', 10);
    const useHttps = String(process.env.TS_USE_HTTPS || 'false').toLowerCase() === 'true';
    const sshPort = parseInt(process.env.TS_SSH_PORT || '10022', 10);
    const sshUsername = (process.env.TS_SSH_USER || '').trim() || null;
    const sshPasswordRaw = (process.env.TS_SSH_PASSWORD || '').trim();

    const row = await prisma.tsServerConfig.create({
      data: {
        name,
        host,
        webqueryPort: Number.isFinite(webqueryPort) ? webqueryPort : 10080,
        apiKey: encrypt(apiKey),
        useHttps,
        sshPort: Number.isFinite(sshPort) ? sshPort : 10022,
        sshUsername,
        sshPassword: sshPasswordRaw ? encrypt(sshPasswordRaw) : null,
        enabled: true,
      },
    });
    console.log(`[seed] Added default TS connection #${row.id}: "${name}" ${host}:${webqueryPort} (HTTPS=${useHttps})`);

    // Grant the first admin user (if any) access to this server. Fresh installs
    // usually haven't created the admin yet; setup.routes.ts creates them later.
    const admin = await prisma.user.findFirst({ where: { role: 'admin' } });
    if (admin) {
      await prisma.userServerAccess.upsert({
        where: { userId_serverConfigId: { userId: admin.id, serverConfigId: row.id } },
        update: {},
        create: { userId: admin.id, serverConfigId: row.id },
      });
      console.log(`[seed] Granted admin "${admin.username}" access to the seeded server.`);
    }
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((err) => {
  console.error('[seed] ERROR:', err?.message || err);
  // Don't abort the container — the user can still add connections manually
  process.exit(0);
});
