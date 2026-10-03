import { categories, type Audience, type Category, type WagzEvent } from './types.ts';

export interface DiscoveryProfile {
  audience: 'all' | Audience;
  interests: Category[];
}
export const defaultProfile: DiscoveryProfile = { audience: 'all', interests: [] };
const categoryLabels: Record<Category, string> = {
  music: 'Glazba',
  nightlife: 'Noćni život',
  theatre: 'Kazalište',
  culture: 'Kultura',
  sport: 'Sport',
  community: 'Zajednica',
  other: 'Ostalo',
};

/** A device preference, not a collected birth date or an inferred age. */
export function parseProfile(value: unknown): DiscoveryProfile {
  if (!value || typeof value !== 'object') return { ...defaultProfile, interests: [] };
  const row = value as Record<string, unknown>;
  return {
    audience: ['all', 'students', 'adults', 'seniors'].includes(String(row.audience))
      ? (row.audience as DiscoveryProfile['audience'])
      : 'all',
    interests: Array.isArray(row.interests)
      ? [
          ...new Set(
            row.interests.filter((item): item is Category => categories.includes(item as Category)),
          ),
        ]
      : [],
  };
}

/** Explainable cues only: audience + interests + event format, never guessed popularity. */
export function recommendationFor(event: WagzEvent, profile: DiscoveryProfile) {
  const reasons: string[] = [];
  let score = 0;
  let personal = false;
  if (event.status !== 'scheduled') return { score, reasons, personal };
  const match = event.discovery?.audienceEvidence.find(
    (item) => item.audience === profile.audience,
  );
  if (match) {
    score += 4;
    personal = true;
    reasons.push(match.reason);
  }
  if (profile.interests.includes(event.category)) {
    score += 2;
    personal = true;
    reasons.push(`Tvoj interes: ${categoryLabels[event.category]}.`);
  }
  if (event.discovery?.prominence) {
    score += 1;
    reasons.push(event.discovery.prominence.reason);
  }
  return { score, reasons, personal };
}

/** Display-only category groups for event artwork and timeline lanes. */
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
  recommendation: ReturnType<typeof recommendationFor>;
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

/**
 * An audience choice brings explicit source matches first and keeps every event.
 * Interests, genre and festival status never affect this order. With "all", order
 * is simply chronological; exact ties preserve the supplied order.
 */
export function rankForAudience(
  events: readonly WagzEvent[],
  audience: DiscoveryProfile['audience'] = 'all',
): RankedEvent[] {
  const profile: DiscoveryProfile = { audience, interests: [] };
  return events
    .map((event, index) => ({ event, index, recommendation: recommendationFor(event, profile) }))
    .sort(
      (a, b) =>
        Number(b.recommendation.personal) - Number(a.recommendation.personal) ||
        chronological(a.event, b.event) ||
        a.index - b.index,
    );
}
