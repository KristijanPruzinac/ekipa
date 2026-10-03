import type { Request } from 'express';
import type { TLSSocket } from 'node:tls';

export const DEFAULT_TIP_DAILY_LIMIT = 100;
export const QUOTA_HOUR_MS = 60 * 60_000;
export const QUOTA_DAY_MS = 24 * QUOTA_HOUR_MS;

/** Native clients omit Origin; browser origins must match the complete origin tuple. */
export function sameRequestOrigin(request: Request, hosted = false): boolean {
  const origin = request.get('origin');
  if (origin === undefined) return true;
  try {
    // An Origin is an origin, not a URL with credentials, a path, query or fragment.
    if (!/^https?:\/\/[^/?#\\\s]+$/i.test(origin)) return false;
    const parsed = new URL(origin);
    if (parsed.username || parsed.password) return false;
    // Vercel terminates TLS before the function. Hosted mode is server configuration,
    // never a request header. Ignore Forwarded and X-Forwarded-{Proto,Host,Port}.
    const scheme = hosted || (request.socket as TLSSocket).encrypted ? 'https' : 'http';
    const host = request.get('host');
    if (!host || /[\s/?#\\@]/.test(host)) return false;
    return parsed.origin === new URL(`${scheme}://${host}`).origin;
  } catch {
    return false;
  }
}
