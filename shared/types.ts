export const categories = [
  'music',
  'nightlife',
  'dance',
  'workshop',
  'theatre',
  'film',
  'literature',
  'culture',
  'sport',
  'community',
  'other',
] as const;
export type Category = (typeof categories)[number];
export type EventStatus = 'scheduled' | 'cancelled' | 'postponed';
export type Publication = 'published' | 'draft' | 'rejected';

export type Audience = 'students' | 'adults' | 'seniors';
export interface EventDiscovery {
  audiences: Audience[];
  audienceEvidence: Array<{ audience: Audience; reason: string; sourceUrl: string }>;
  prominence: {
    kind: 'festival' | 'city_event';
    label: string;
    reason: string;
    sourceUrl: string;
  } | null;
  free: boolean;
}

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
  discovery?: EventDiscovery;
  /**
   * The announcement's own text, used only as AI classification input and never stored or shown.
   * Descriptions may be templated from a provisional keyword category; this keeps that guess
   * out of the classifier's view.
   */
  classificationText?: string;
}

export interface EventEvidence {
  sourceId: string;
  sourceName: string;
  url: string;
  lastSeenAt: string;
}

export interface PublicEvent extends Omit<EventCandidate, 'sourceId' | 'sourceUrl' | 'externalId'> {
  id: string;
  sources: EventEvidence[];
  firstSeenAt: string;
  updatedAt: string;
}
export interface WagzEvent extends PublicEvent {
  publication: Publication;
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
  /** Deterministic source conflicts require review even when a venue is known. */
  reviewExternalIds?: string[];
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
  revision?: number;
  note: string;
  url: string | null;
  status: 'inbox' | 'archived' | 'draft' | 'accepted' | 'rejected';
  reason: string;
  submittedAt: string;
  updatedAt: string;
  /** Daily automatic checks use the Zagreb calendar day; operator refresh remains available. */
  lastAutomaticAttemptAt?: string | null;
  draft: EventDraft | null;
  matchedEventId: string | null;
  /** Material source-event state reviewed with this linked draft. */
  matchedEventSnapshot?: string | null;
  verification: 'unverified' | 'source_match';
}
export interface PublicFeed {
  events: PublicEvent[];
  meta: {
    city: string;
    timezone: string;
    now: string;
    lastCheckedAt: string | null;
    sourceCount: number;
    totalUpcoming: number;
  };
}
export interface PublicEventResponse {
  event: PublicEvent;
  meta: { now: string; timezone: string };
}
export type PublicPageData =
  { kind: 'feed'; feed: PublicFeed } | { kind: 'event'; event: PublicEvent; now: string };
export interface AdminDashboard {
  events: WagzEvent[];
  tips: Tip[];
  sources: SourceHealth[];
  runs: SourceRun[];
  collecting: boolean;
  preparingTipIds?: string[];
  autoPublish: boolean;
  ai: { enabled: boolean; description: string };
}
