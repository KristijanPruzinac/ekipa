export const categories = [
  'music',
  'nightlife',
  'theatre',
  'culture',
  'sport',
  'community',
  'other',
] as const;
export type Category = (typeof categories)[number];
export type EventStatus = 'scheduled' | 'cancelled' | 'postponed';
export type Publication = 'published' | 'draft' | 'rejected';

export interface EventCandidate {
  sourceId: string;
  sourceUrl: string;
  externalId: string;
  title: string;
  description: string;
  // Offset ISO timestamp, or YYYY-MM-DD when the source does not give a time.
  startsAt: string;
  endsAt: string | null;
  venue: string | null;
  address: string | null;
  city: string;
  category: Category;
  price: string | null;
  status: EventStatus;
}

export interface EventEvidence {
  sourceId: string;
  sourceName: string;
  url: string;
  lastSeenAt: string;
}

export interface WagzEvent extends Omit<EventCandidate, 'sourceId' | 'sourceUrl' | 'externalId'> {
  id: string;
  publication: Publication;
  sources: EventEvidence[];
  firstSeenAt: string;
  updatedAt: string;
  manuallyEdited: boolean;
  autoPublishEligible?: boolean;
}

export interface SourceDefinition {
  id: string;
  name: string;
  url: string;
  description: string;
  enabled: boolean;
}
export interface FetchResult {
  events: EventCandidate[];
  pagesFetched: number;
  discovered: number;
  skipped: number;
  warnings: string[];
  extractionPages?: Array<{ url: string; text: string }>;
}
export interface SourceRun {
  id: string;
  sourceId: string;
  startedAt: string;
  finishedAt: string | null;
  status: 'running' | 'success' | 'partial' | 'error';
  discovered: number;
  imported: number;
  skipped: number;
  pagesFetched: number;
  warnings: string[];
}
export interface SourceHealth extends SourceDefinition {
  latestRun: SourceRun | null;
  lastSuccessAt: string | null;
  eventCount: number;
}
export interface EventDraft {
  title: string;
  description: string;
  startsAt: string;
  endsAt: string | null;
  venue: string | null;
  address: string | null;
  city: string;
  category: Category;
  price: string | null;
  status: EventStatus;
  sourceUrl: string | null;
}
export interface Tip {
  id: string;
  note: string;
  url: string | null;
  status: 'inbox' | 'archived' | 'draft' | 'accepted' | 'rejected';
  reason: string;
  submittedAt: string;
  updatedAt: string;
  draft: EventDraft | null;
  matchedEventId: string | null;
  verification: 'unverified' | 'source_match';
}
export interface PublicFeed {
  events: WagzEvent[];
  meta: {
    city: string;
    timezone: string;
    now: string;
    lastCheckedAt: string | null;
    sourceCount: number;
    totalUpcoming: number;
  };
}
export interface AdminDashboard {
  events: WagzEvent[];
  tips: Tip[];
  sources: SourceHealth[];
  runs: SourceRun[];
  collecting: boolean;
  autoPublish: boolean;
  ai: { enabled: boolean; description: string };
}
