import type { Meetup } from './types';

/** Sample invitation used to explore the UI before the backend is wired. */
export const MOCK_MEETUP: Meetup = {
  id: 'mtp_demo_1',
  status: 'proposed',
  activitySlug: 'walk',
  activityLabel: 'Walking',
  emoji: '🌿',
  venueName: 'Park by the Drava',
  venueNote: 'Meet at the main entrance, near the fountain.',
  city: 'Osijek',
  startsAt: nextSaturdayAt(15, 0),
  durationMin: 90,
  isStanding: false,
  whatToExpect:
    'A relaxed 90-minute walk along the river with three other people. No pressure to keep talking — walking side by side does the work. You can head off whenever you like; nobody will ask why.',
  attendees: [
    { id: 'u1', firstName: 'Lucija', blurb: 'Into photo walks and sci-fi. Prefers small, quiet groups.' },
    { id: 'u2', firstName: 'Marko', blurb: 'Bouldering and board games. Easy-going, happy in silence.' },
    { id: 'u3', firstName: 'Ivana', blurb: 'Loves nature and reading. New to the city.' },
  ],
};

/** A second, already-confirmed standing group to show Stage 2. */
export const MOCK_STANDING: Meetup = {
  ...MOCK_MEETUP,
  id: 'mtp_demo_2',
  status: 'confirmed',
  activitySlug: 'boardgames',
  activityLabel: 'Board games',
  emoji: '🎲',
  venueName: 'Kocka board-game café',
  venueNote: 'Table booked under "Ekipa".',
  startsAt: nextSaturdayAt(18, 0),
  isStanding: true,
  whatToExpect:
    'Your regular group, every other Saturday. Same faces, a familiar table, no organizing on your part.',
};

function nextSaturdayAt(hour: number, minute: number): string {
  const d = new Date();
  const day = d.getDay();
  const daysUntilSat = (6 - day + 7) % 7 || 7;
  d.setDate(d.getDate() + daysUntilSat);
  d.setHours(hour, minute, 0, 0);
  return d.toISOString();
}
