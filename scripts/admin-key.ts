import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

const key = randomBytes(32).toString('base64url');
const previous = existsSync('.env') ? readFileSync('.env', 'utf8') : '';
const line = `WAGZ_ADMIN_KEY=${key}`;
writeFileSync(
  '.env',
  /^WAGZ_ADMIN_KEY=.*$/m.test(previous)
    ? previous.replace(/^WAGZ_ADMIN_KEY=.*$/m, line)
    : `${previous.trimEnd()}\n${line}\n`,
  { mode: 0o600 },
);
console.log(
  'A new admin key was saved to .env. Open that file locally to copy it. Restart WagZ after rotating the key.',
);
