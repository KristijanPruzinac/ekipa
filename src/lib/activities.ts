/**
 * The activity catalog. Deliberately shoulder-to-shoulder and parallel:
 * activities that remove the conversational spotlight. "Just talk" is the
 * hardest format for this population and is intentionally absent.
 */
export interface Activity {
  slug: string;
  label: string;
  emoji: string;
  /** Cheapest to organize + most silence-tolerant seed the first cohorts. */
  seed?: boolean;
}

export const ACTIVITIES: Activity[] = [
  { slug: 'walk', label: 'Walking', emoji: '🌿', seed: true },
  { slug: 'boardgames', label: 'Board games', emoji: '🎲', seed: true },
  { slug: 'hike', label: 'Hiking', emoji: '⛰️' },
  { slug: 'bouldering', label: 'Bouldering', emoji: '🧗' },
  { slug: 'coffee_quiet', label: 'Quiet coffee', emoji: '🍵' },
  { slug: 'photography', label: 'Photo walks', emoji: '📷' },
  { slug: 'cowork_hobby', label: 'Hobby co-working', emoji: '🎨' },
  { slug: 'cooking', label: 'Cooking', emoji: '🍲' },
  { slug: 'cinema', label: 'Cinema', emoji: '🎬' },
  { slug: 'reading', label: 'Reading together', emoji: '📖' },
];

export function activityBySlug(slug: string): Activity | undefined {
  return ACTIVITIES.find((a) => a.slug === slug);
}
