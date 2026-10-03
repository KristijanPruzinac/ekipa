import type { Audience, EventDiscovery } from '../shared/types.ts';

const plain = (value: string) =>
  value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();
export const isFree = (price: string | null) =>
  /^(?:besplatno|besplatan ulaz|ulaz (?:je )?besplatan|free(?: entry)?|0(?:[,.]00)?\s*(?:€|eur)?)\.?$/i.test(
    (price ?? '').trim(),
  );
const audienceRules: Array<{ audience: Audience; pattern: RegExp; reason: string }> = [
  {
    audience: 'students',
    pattern:
      /\b(?:za studente|studentima|studentsk\w* (?:popust|ulaznic|program|party|zabav)|brucosijad|za mlade|mladima|program za mlad|poziva\w*[^.!?]{0,160}\b(?:studente|mlade)\b)/,
    reason: 'Najava navodi program ili pogodnost za studente i mlade.',
  },
  {
    audience: 'adults',
    pattern: /\b(?:za odrasle|odraslima|program za odrasl)/,
    reason: 'Najava izričito navodi program za odrasle.',
  },
  {
    audience: 'seniors',
    pattern:
      /\b(?:za umirovljenike|umirovljenicima|za starije osobe|za osobe trece (?:zivotne )?dobi|program za seniore)/,
    reason: 'Najava navodi program ili pogodnost za starije osobe.',
  },
];

/** Use fetched event copy, not age/genre stereotypes or the model's judgement of importance. */
export function inferDiscovery(
  title: string,
  sourceText: string,
  sourceUrl: string,
  price: string | null = null,
): EventDiscovery {
  const text = plain(`${title} ${sourceText}`);
  const audienceEvidence = audienceRules
    .filter((rule) => rule.pattern.test(text))
    .map(({ audience, reason }) => ({ audience, reason, sourceUrl }));
  const heading = plain(title);
  // A mention of some other festival in the body does not classify this event.
  const festival = /\bfestival\w*\b/.test(heading);
  const cityEvent = /\b(advent|dan\w* grada|gradsk\w* manifestacij)\b/.test(heading);
  return {
    audiences: audienceEvidence.map((item) => item.audience),
    audienceEvidence,
    prominence: festival
      ? {
          kind: 'festival',
          label: 'Festival',
          reason: 'Službena najava opisuje događaj kao festival.',
          sourceUrl,
        }
      : cityEvent
        ? {
            kind: 'city_event',
            label: 'Gradski program',
            reason: 'Službena najava opisuje gradski program.',
            sourceUrl,
          }
        : null,
    free: isFree(price),
  };
}

/** Only metadata linked to this fetched source may enter the public feed. */
export function validateDiscovery(value: unknown, sourceUrl: string): EventDiscovery | undefined {
  if (!value || typeof value !== 'object') return undefined;
  const row = value as EventDiscovery;
  const audienceEvidence = Array.isArray(row.audienceEvidence)
    ? row.audienceEvidence.filter(
        (item) =>
          item &&
          ['students', 'adults', 'seniors'].includes(item.audience) &&
          item.sourceUrl === sourceUrl &&
          typeof item.reason === 'string' &&
          item.reason.length > 0 &&
          item.reason.length <= 300,
      )
    : [];
  const p = row.prominence;
  const prominence =
    p &&
    ['festival', 'city_event'].includes(p.kind) &&
    p.sourceUrl === sourceUrl &&
    typeof p.label === 'string' &&
    p.label.length <= 60 &&
    typeof p.reason === 'string' &&
    p.reason.length <= 300
      ? p
      : null;
  return {
    audiences: [...new Set(audienceEvidence.map((item) => item.audience))],
    audienceEvidence,
    prominence,
    free: row.free === true,
  };
}

export function mergeDiscovery(
  current: EventDiscovery | undefined,
  fresh: EventDiscovery | undefined,
  sourceUrl: string,
  price: string | null,
): EventDiscovery {
  const evidence = [
    ...(current?.audienceEvidence ?? []).filter((item) => item.sourceUrl !== sourceUrl),
    ...(fresh?.audienceEvidence ?? []),
  ];
  const audienceEvidence = evidence.filter(
    (item, index) =>
      evidence.findIndex(
        (other) => other.audience === item.audience && other.sourceUrl === item.sourceUrl,
      ) === index,
  );
  return {
    audiences: [...new Set(audienceEvidence.map((item) => item.audience))],
    audienceEvidence,
    prominence:
      fresh?.prominence ??
      (current?.prominence?.sourceUrl !== sourceUrl ? (current?.prominence ?? null) : null),
    free: isFree(price),
  };
}
