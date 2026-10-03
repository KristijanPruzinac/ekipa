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
      /\b(?:za studente|studentima|studentsk\w* (?:popust|ulaznic|program|party|zabav)|brucosijad|poziva\w*[^.!?]{0,160}\bstudente\b)/,
    reason: 'Najava navodi program ili pogodnost za studente.',
  },
  {
    audience: 'adults',
    pattern: /\b(?:za odrasle|odraslima|program za odrasl)/,
    reason: 'Najava izričito navodi program za odrasle.',
  },
  {
    audience: 'seniors',
    pattern:
      /\b(?:za umirovljenike|umirovljenicima|za starije osobe|za osobe trece (?:zivotne )?dobi)/,
    reason: 'Najava navodi program ili pogodnost za starije osobe.',
  },
];

// These are conservative text cues, not a language model. Keep independent
// affirmative clauses usable, but never turn a denied offer into an audience.
// Do not split comma-separated invitees ("pozivamo inovatore, studente...").
const audienceClauses = (text: string) =>
  text
    .replace(/\s+/g, ' ')
    .split(
      /(?<!\d)\.|[!?;]+|\s+(?:ali|nego|no|dok)\s+|,\s*a\s+|,\s*(?=(?:ne|nije|nisu|nema|program|radionica|ulaz|popust|pogodnost|za)\b)/,
    );
const deniedAudienceClaim =
  /\b(?:ne|nije|nisu|nema|nemaju|nemamo|nedostup\w*|nedozvol\w*|zabranjen\w*|iskljucen\w*|ukinut\w*|otkazan\w*)\b|\bbez\s+(?:posebnog\s+)?(?:popust\w*|pogodnost\w*)/;

/** Use fetched event copy, not age/genre stereotypes or the model's judgement of importance. */
export function inferDiscovery(
  title: string,
  sourceText: string,
  sourceUrl: string,
  price: string | null = null,
): EventDiscovery {
  const text = plain(`${title} ${sourceText}`);
  const affirmative = audienceClauses(text).filter((clause) => !deniedAudienceClaim.test(clause));
  const audienceEvidence = audienceRules
    // "Senior" also names sporting divisions. Only explicit older-person or
    // retiree wording establishes this audience; genre cannot disambiguate it.
    .filter((rule) => affirmative.some((clause) => rule.pattern.test(clause)))
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
  const s = row.screening;
  const screening =
    s &&
    ['routine', 'special'].includes(s.kind) &&
    s.sourceUrl === sourceUrl &&
    typeof s.reason === 'string' &&
    s.reason.trim().length > 0 &&
    s.reason.length <= 300
      ? s
      : undefined;
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
    ...(screening ? { screening } : {}),
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
  const oldScreening = current?.screening?.sourceUrl !== sourceUrl ? current?.screening : undefined;
  // Special source evidence overrides routine evidence in either arrival order.
  // A refresh of its own source withdraws a claim that is no longer supported.
  const screening =
    [oldScreening, fresh?.screening].find((item) => item?.kind === 'special') ??
    fresh?.screening ??
    oldScreening;
  return {
    ...(screening ? { screening } : {}),
    audiences: [...new Set(audienceEvidence.map((item) => item.audience))],
    audienceEvidence,
    prominence:
      fresh?.prominence ??
      (current?.prominence?.sourceUrl !== sourceUrl ? (current?.prominence ?? null) : null),
    free: isFree(price),
  };
}
