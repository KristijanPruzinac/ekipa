import { type Audience, type Category, type WagzEvent } from './types.ts';

/** Display-only colors for event artwork, timeline points and duration branches. */
export const discoveryThemes = [
  {
    id: 'go-out',
    label: 'Glazba i izlasci',
    description: 'Koncerti, DJ večeri i noćni program.',
    categories: ['music', 'nightlife'],
  },
  {
    id: 'culture',
    label: 'Pozornica i kultura',
    description: 'Kazalište, izložbe, film i književnost.',
    categories: ['theatre', 'culture'],
  },
  {
    id: 'join-in',
    label: 'Pokret i druženje',
    description: 'Sport, radionice i događaji zajednice.',
    categories: ['community', 'sport'],
  },
] as const;
export type DiscoveryTheme = (typeof discoveryThemes)[number]['id'];

export function themeForCategory(category: Category): DiscoveryTheme | null {
  return (
    discoveryThemes.find((theme) => theme.categories.some((item) => item === category))?.id ?? null
  );
}

export interface RankedEvent {
  event: WagzEvent;
  index: number;
}

const zagrebDate = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Europe/Zagreb',
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});

function localDay(value: Date | string): string {
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
  const parts = zagrebDate.formatToParts(new Date(value));
  const part = (type: string) => parts.find((item) => item.type === type)!.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

function chronological(a: WagzEvent, b: WagzEvent): number {
  const dayOrder = localDay(a.startsAt).localeCompare(localDay(b.startsAt));
  if (dayOrder) return dayOrder;
  // Unknown times form the first group on their actual local day, never an invented hour.
  if (a.startsAt.length === 10 || b.startsAt.length === 10)
    return Number(a.startsAt.length > 10) - Number(b.startsAt.length > 10);
  return Date.parse(a.startsAt) - Date.parse(b.startsAt);
}

/** Every event stays in stable Zagreb chronology. Legacy audience arguments are ignored. */
export function rankForAudience(
  events: readonly WagzEvent[],
  _audience: 'all' | Audience = 'all',
  _now?: string,
): RankedEvent[] {
  return events
    .map((event, index) => ({ event, index }))
    .sort((a, b) => chronological(a.event, b.event) || a.index - b.index);
}

export const audienceLabels: Record<Audience, string> = {
  students: 'Studenti',
  adults: 'Odrasli',
  seniors: 'Stariji',
};

/** Source mentions, never inferred eligibility. Require evidence from this event's sources. */
export function sourceAudienceEvidence(event: WagzEvent) {
  const sources = new Set(event.sources.map((source) => source.url));
  const safeSource = (value: string) => {
    try {
      const url = new URL(value);
      return (
        ['https:', 'http:'].includes(url.protocol) &&
        !url.hostname.endsWith('.invalid') &&
        !url.username &&
        !url.password &&
        sources.has(value)
      );
    } catch {
      return false;
    }
  };
  return (Object.keys(audienceLabels) as Audience[]).flatMap((audience) => {
    const evidence = event.discovery?.audienceEvidence.find(
      (item) => item.audience === audience && item.reason.trim() && safeSource(item.sourceUrl),
    );
    return evidence ? [evidence] : [];
  });
}

export function sourceAudienceLabels(event: WagzEvent): string[] {
  return sourceAudienceEvidence(event).map((item) => audienceLabels[item.audience]);
}

export function knownEnd(event: WagzEvent): string | null {
  const end = event.endsAt;
  if (!end || !Number.isFinite(Date.parse(end))) return null;
  return (
    end.length === 10 || event.startsAt.length === 10
      ? localDay(end) >= localDay(event.startsAt)
      : Date.parse(end) > Date.parse(event.startsAt)
  )
    ? end
    : null;
}

export function durationLabel(event: WagzEvent): string | null {
  const end = knownEnd(event);
  if (!end || end.length === 10 || event.startsAt.length === 10) return null;
  const minutes = Math.round((Date.parse(end) - Date.parse(event.startsAt)) / 60000);
  const days = Math.floor(minutes / 1440),
    hours = Math.floor((minutes % 1440) / 60),
    rest = minutes % 60;
  return (
    [days && `${days} d`, hours && `${hours} h`, rest && `${rest} min`].filter(Boolean).join(' ') ||
    '< 1 min'
  );
}

export function isOngoing(event: WagzEvent, now: string): boolean {
  const end = knownEnd(event);
  if (!end || event.status !== 'scheduled') return false;
  const started =
    event.startsAt.length === 10
      ? localDay(event.startsAt) < localDay(now)
      : Date.parse(event.startsAt) <= Date.parse(now);
  return started && (end.length === 10 ? localDay(now) <= end : Date.parse(now) < Date.parse(end));
}

/** Compact public copy. Date-only ranges count calendar dates, never guessed hours. */
export function eventDurationText(event: WagzEvent, now?: string): string {
  const end = knownEnd(event);
  if (!end) return 'Kraj nije naveden';
  const endDay = localDay(end);
  const [, month, day] = endDay.split('-');
  const date = `${Number(day)}.${Number(month)}.`;
  const time =
    end.length > 10
      ? new Intl.DateTimeFormat('hr', {
          timeZone: 'Europe/Zagreb',
          hour: '2-digit',
          minute: '2-digit',
        }).format(new Date(end))
      : null;
  if (now && isOngoing(event, now)) {
    return time && localDay(now) === endDay
      ? `Danas do ${time}`
      : `Traje do ${date}${time ? ` · ${time}` : ''}`;
  }
  const exact = durationLabel(event);
  if (exact && localDay(event.startsAt) === endDay) return `Traje ${exact}`;
  if (event.startsAt.length === 10 && end.length === 10) {
    const days = Math.round((Date.parse(end) - Date.parse(event.startsAt)) / 86400000) + 1;
    return days === 1 ? 'Isti dan · sat završetka nije naveden' : `Traje ${days} dana`;
  }
  return `Traje do ${date}${time ? ` · ${time}` : ''}`;
}

export interface TimelineMoment {
  event: WagzEvent;
  value: string;
  ending: boolean;
}
export interface TimelineRange {
  event: WagzEvent;
  start: number;
  end: number;
  lane: number;
}

/** A single dated spine. Branches belong to event ranges, never categories.
 * Calendar-day endpoints stay date-only; space separates labels, not elapsed time.
 */
export function timelineFor(events: readonly WagzEvent[]) {
  const moments: TimelineMoment[] = events
    .flatMap((event) => {
      const end = knownEnd(event);
      return [
        { event, value: event.startsAt, ending: false },
        ...(end ? [{ event, value: end, ending: true }] : []),
      ];
    })
    .sort((a, b) => {
      const day = localDay(a.value).localeCompare(localDay(b.value));
      if (day) return day;
      const position = (item: TimelineMoment) =>
        item.value.length === 10 ? (item.ending ? Infinity : -Infinity) : Date.parse(item.value);
      return position(a) - position(b) || Number(a.ending) - Number(b.ending);
    });
  const ranges: TimelineRange[] = [];
  const occupied: number[] = [];
  moments.forEach((moment, start) => {
    if (moment.ending || !knownEnd(moment.event)) return;
    const end = moments.findIndex((item) => item.event.id === moment.event.id && item.ending);
    let lane = occupied.findIndex((until) => until < start);
    if (lane === -1) lane = occupied.length;
    occupied[lane] = end;
    ranges.push({ event: moment.event, start, end, lane });
  });
  return { moments, ranges };
}
