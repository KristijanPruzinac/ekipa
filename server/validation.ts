import { categories, type EventCandidate, type EventDraft } from '../shared/types.ts';
import { inferDiscovery, isFree, validateDiscovery } from './discovery.ts';

export class ValidationError extends Error {}
export const TIMEZONE = 'Europe/Zagreb';
export const normalize = (value: string) =>
  value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
export const localDay = (now = new Date()) =>
  new Intl.DateTimeFormat('en-CA', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);

export function validDate(value: unknown): value is string {
  if (
    typeof value !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,3})?)?(?:Z|[+-]\d{2}:\d{2}))?$/.test(
      value,
    )
  )
    return false;
  const date = value.slice(0, 10);
  const day = new Date(`${date}T12:00:00Z`);
  return (
    Number.isFinite(day.getTime()) &&
    day.toISOString().slice(0, 10) === date &&
    Number.isFinite(Date.parse(value))
  );
}

function canonicalDate(value: string): string {
  if (value.length === 10) return value;
  const date = new Date(value);
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: TIMEZONE,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hourCycle: 'h23',
    })
      .formatToParts(date)
      .map((part) => [part.type, part.value]),
  );
  const local = `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}`;
  const offset = Math.round((Date.parse(`${local}Z`) - date.getTime()) / 60000);
  return `${local}${offset >= 0 ? '+' : '-'}${String(Math.floor(Math.abs(offset) / 60)).padStart(2, '0')}:${String(Math.abs(offset) % 60).padStart(2, '0')}`;
}

/** Explicit tip dates only; a missing year is retained as --MM-DD, never guessed. */
export function tipDates(note: string): { dates: string[]; hasYear: boolean; invalid: boolean } {
  const dates = new Set<string>();
  let hasYear = false,
    invalid = false;
  const add = (day: string, month: string, year?: string) => {
    const fullYear = year ? (year.length === 2 ? `20${year}` : year) : undefined;
    const tail = `${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
    if (!validDate(`${fullYear ?? '2000'}-${tail}`)) {
      invalid = true;
      return;
    }
    if (fullYear) hasYear = true;
    dates.add(`${fullYear ?? '-'}-${tail}`);
  };
  for (const match of note.matchAll(/\b(\d{4})-(\d{2})-(\d{2})\b/g))
    add(match[3], match[2], match[1]);
  for (const match of note.matchAll(
    /(?<![\d./-])(\d{1,2})\s*([./])\s*(\d{1,2})(?:\s*\2\s*(\d{4}|\d{2})(?!\d))?\.?(?![\d./])/g,
  ))
    add(match[1], match[3], match[4]);
  const months = [
    'sijecanj|sijecnja',
    'veljaca|veljace',
    'ozujak|ozujka',
    'travanj|travnja',
    'svibanj|svibnja',
    'lipanj|lipnja',
    'srpanj|srpnja',
    'kolovoz|kolovoza',
    'rujan|rujna',
    'listopad|listopada',
    'studeni|studenog|studenoga',
    'prosinac|prosinca',
  ];
  const plain = note
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();
  const written = new RegExp(
    `\\b(\\d{1,2})\\.?\\s+(${months.join('|')})\\b(?:\\s+(\\d{4})(?!\\d))?`,
    'g',
  );
  for (const match of plain.matchAll(written)) {
    const month = months.findIndex((names) => names.split('|').includes(match[2])) + 1;
    add(match[1], String(month), match[3]);
  }
  return { dates: [...dates], hasYear, invalid };
}

export function safeUrl(value: unknown): string | null {
  if (value === null || value === undefined || value === '') return null;
  if (typeof value !== 'string' || value.length > 2048)
    throw new ValidationError('Poveznica je preduga ili neispravna.');
  try {
    const url = new URL(value);
    if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password)
      throw new Error();
    return url.href;
  } catch {
    throw new ValidationError('Unesi valjanu http ili https poveznicu.');
  }
}

function text(value: unknown, max: number, required = false): string | null {
  if ((value === null || value === undefined || value === '') && !required) return null;
  if (typeof value !== 'string' || value.trim().length > max || (required && !value.trim()))
    throw new ValidationError('Provjeri obavezna polja i duljinu teksta.');
  return value.trim();
}

export function validateDraft(input: unknown): EventDraft {
  if (!input || typeof input !== 'object' || Array.isArray(input))
    throw new ValidationError('Neispravan događaj.');
  const row = input as Record<string, unknown>;
  if (!validDate(row.startsAt))
    throw new ValidationError(
      'Potreban je valjan datum; vrijeme ostavi nepoznato ako nije navedeno.',
    );
  if (row.endsAt && !validDate(row.endsAt))
    throw new ValidationError('Neispravan datum završetka.');
  const startsAt = canonicalDate(row.startsAt);
  const endsAt = row.endsAt ? canonicalDate(String(row.endsAt)) : null;
  if (endsAt && endsAt.slice(0, 10) < startsAt.slice(0, 10))
    throw new ValidationError('Završetak ne može biti prije početka.');
  if (
    endsAt &&
    endsAt.length > 10 &&
    startsAt.length > 10 &&
    Date.parse(endsAt) < Date.parse(startsAt)
  )
    throw new ValidationError('Završetak ne može biti prije početka.');
  if (!categories.includes(row.category as never)) throw new ValidationError('Odaberi kategoriju.');
  if (!['scheduled', 'cancelled', 'postponed'].includes(String(row.status)))
    throw new ValidationError('Neispravan status.');
  if (normalize(String(row.city ?? 'Osijek')) !== 'osijek')
    throw new ValidationError('WagZ v1 prikuplja događaje u Osijeku.');
  return {
    title: text(row.title, 300, true)!,
    description: text(row.description, 5000) ?? '',
    startsAt,
    endsAt,
    venue: text(row.venue, 300),
    address: text(row.address, 500),
    city: 'Osijek',
    category: row.category as EventDraft['category'],
    price: text(row.price, 300),
    status: row.status as EventDraft['status'],
    sourceUrl: safeUrl(row.sourceUrl),
  };
}

export function validateCandidate(input: EventCandidate): EventCandidate {
  const draft = validateDraft(input);
  if (!draft.sourceUrl || !input.sourceId || !input.externalId)
    throw new ValidationError('Događaju nedostaje izvor.');
  return {
    ...draft,
    sourceUrl: draft.sourceUrl,
    sourceId: text(input.sourceId, 100, true)!,
    externalId: text(input.externalId, 2048, true)!,
    discovery: {
      ...(validateDiscovery(input.discovery, draft.sourceUrl) ??
        inferDiscovery(draft.title, draft.description, draft.sourceUrl, draft.price)),
      free: isFree(draft.price),
    },
  };
}

export function upcoming(
  event: Pick<EventDraft, 'startsAt' | 'endsAt'>,
  now = new Date(),
): boolean {
  const until = event.endsAt ?? event.startsAt;
  return until.length === 10 ? until >= localDay(now) : Date.parse(until) >= now.getTime();
}

export function classifyTip(note: string, honeypot = ''): { archive: boolean; reason: string } {
  if (honeypot.trim())
    return {
      archive: true,
      reason: 'Automatski arhivirano: popunjeno polje namijenjeno zaštiti od botova.',
    };
  if (/^(.)\1{10,}$/u.test(note.replace(/\s/g, '')))
    return { archive: true, reason: 'Automatski arhivirano: ponovljeni besmisleni sadržaj.' };
  return {
    archive: false,
    reason: 'Dojava čeka provjeru. Nepotpuni podaci nisu razlog za odbacivanje.',
  };
}
