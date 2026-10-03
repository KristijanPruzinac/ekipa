import type { Category, EventDraft, PublicEvent } from '../shared/types';
import { isWorkshopEvent } from '../shared/discovery';
import type { MouseEvent } from 'react';

export const categoryNames: Record<Category, string> = {
  music: 'Glazba',
  nightlife: 'Noćni život',
  dance: 'Ples',
  workshop: 'Radionica',
  theatre: 'Kazalište',
  culture: 'Kultura',
  sport: 'Sport',
  community: 'Zajednica',
  other: 'Ostalo',
};
export const eventCategoryLabel = (event: PublicEvent) =>
  event.category === 'dance' && isWorkshopEvent(event)
    ? 'Ples · Radionica'
    : categoryNames[event.category];

/** Preserve open-in-new-tab/window and native navigation while enhancing ordinary clicks. */
export function openEventLink(click: MouseEvent<HTMLAnchorElement>, open: () => void) {
  if (click.button !== 0 || click.metaKey || click.ctrlKey || click.shiftKey || click.altKey)
    return;
  click.preventDefault();
  open();
}
export const TIMEZONE = 'Europe/Zagreb';
export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
  ) {
    super(message);
  }
}
export async function api<T>(path: string, options: RequestInit = {}, key?: string): Promise<T> {
  const headers = new Headers(options.headers);
  if (options.body) headers.set('Content-Type', 'application/json');
  if (key) headers.set('Authorization', `Bearer ${key}`);
  const response = await fetch(path, { ...options, headers });
  const body = await response.json().catch(() => ({}));
  if (!response.ok)
    throw new ApiError(body.error || `Zahtjev nije uspio (${response.status}).`, response.status);
  return body as T;
}
export const errorText = (error: unknown) =>
  error instanceof Error ? error.message : 'Nešto nije uspjelo. Pokušaj ponovno.';
export function dayKey(value: string | Date): string {
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date(value));
  return `${parts.find((p) => p.type === 'year')!.value}-${parts.find((p) => p.type === 'month')!.value}-${parts.find((p) => p.type === 'day')!.value}`;
}
export function dayOffset(day: string, offset: number) {
  const date = new Date(`${day}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + offset);
  return date.toISOString().slice(0, 10);
}
export function dateFormat(
  value: string,
  options: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'long' },
) {
  return new Intl.DateTimeFormat('hr-HR', { timeZone: TIMEZONE, ...options }).format(
    new Date(value.length === 10 ? `${value}T12:00:00Z` : value),
  );
}
export function timeFormat(value: string) {
  return value.length === 10
    ? 'Vrijeme još nije navedeno'
    : dateFormat(value, { hour: '2-digit', minute: '2-digit' });
}
export function safeLink(value: string | null | undefined): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    return ['http:', 'https:'].includes(url.protocol) &&
      !url.hostname.endsWith('.invalid') &&
      !url.username &&
      !url.password
      ? url.href
      : null;
  } catch {
    return null;
  }
}
export const normalize = (value: string) =>
  value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();
export type DateFilter = 'all' | 'today' | 'weekend' | 'week';
export function inDateFilter(event: PublicEvent, filter: DateFilter, now: string) {
  if (filter === 'all') return true;
  const today = dayKey(now),
    weekday = new Date(`${today}T12:00:00Z`).getUTCDay();
  let start = today,
    end = today;
  if (filter === 'week') end = dayOffset(today, (7 - weekday) % 7);
  if (filter === 'weekend') {
    start = weekday === 0 ? dayOffset(today, -2) : dayOffset(today, 5 - weekday);
    end = dayOffset(start, 2);
  }
  return dayKey(event.startsAt) <= end && dayKey(event.endsAt ?? event.startsAt) >= start;
}
export function localTime(value: string): string {
  return value.length > 10
    ? dateFormat(value, { hour: '2-digit', minute: '2-digit', hourCycle: 'h23' })
    : '';
}
// Convert a Zagreb wall-clock time independently of the device's timezone.
export function zonedTimestamp(day: string, time: string): string {
  if (!time) return day;
  const wall = Date.parse(`${day}T${time}:00Z`);
  let instant = wall;
  for (let i = 0; i < 3; i++) {
    const parts = new Intl.DateTimeFormat('en-CA', {
      timeZone: TIMEZONE,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).formatToParts(new Date(instant));
    const get = (type: string) => parts.find((p) => p.type === type)!.value;
    const represented = Date.parse(
      `${get('year')}-${get('month')}-${get('day')}T${get('hour')}:${get('minute')}:00Z`,
    );
    const delta = wall - represented;
    if (!delta) return new Date(instant).toISOString();
    instant += delta;
  }
  throw new Error('Odabrano vrijeme ne postoji zbog pomicanja sata. Provjeri vrijeme događaja.');
}
export function eventDraft(event: PublicEvent): EventDraft {
  return {
    title: event.title,
    description: event.description,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    venue: event.venue,
    address: event.address,
    city: event.city,
    category: event.category,
    price: event.price,
    status: event.status,
    sourceUrl: safeLink(event.sources[0]?.url),
  };
}
export const blankDraft = (): EventDraft => ({
  title: '',
  description: '',
  startsAt: '',
  endsAt: null,
  venue: null,
  address: null,
  city: 'Osijek',
  category: 'other',
  price: null,
  status: 'scheduled',
  sourceUrl: null,
});
