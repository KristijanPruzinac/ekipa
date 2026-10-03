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
