/** Domain types — mirror the Supabase schema in supabase/migrations. */

export type TalkLevel = 'chatty' | 'balanced' | 'quiet_company';

export type AvailabilitySlot =
  | 'weekday_morning'
  | 'weekday_evening'
  | 'weekend_day'
  | 'weekend_evening';

export interface Profile {
  id: string;
  firstName: string;
  city: string;
  activities: string[]; // activity slugs
  availability: AvailabilitySlot[];
  groupSizePref: 2 | 3 | 4;
  talkLevel: TalkLevel;
  sameGenderOnly: boolean;
  /** System-written one-liner shown to matched others. No free-text bio. */
  blurb: string;
}

export type GroupStatus =
  | 'proposed' // invites sent; members see only their own invite
  | 'forming' // some yeses in; still hidden
  | 'confirmed' // everyone accepted; now visible to all members
  | 'completed'
  | 'cancelled';

/** A person as shown inside a confirmed invitation. First name only. */
export interface Attendee {
  id: string;
  firstName: string;
  blurb: string;
}

export interface Meetup {
  id: string;
  status: GroupStatus;
  activitySlug: string;
  activityLabel: string;
  emoji: string;
  venueName: string;
  venueNote: string;
  city: string;
  startsAt: string; // ISO
  durationMin: number;
  attendees: Attendee[];
  isStanding: boolean;
  /** What actually happens — reduces ambiguity, the key anxiety tax. */
  whatToExpect: string;
}
