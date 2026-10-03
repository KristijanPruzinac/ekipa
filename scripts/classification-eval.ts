/**
 * Live check of the written category criteria against the real model (costs well under $0.01).
 *   OPENROUTER_API_KEY=... npx tsx scripts/classification-eval.ts
 * Cases deliberately pair the same art form with different attendee activities, use several
 * places and languages, and include no source- or city-specific hints. Exit code 1 on any miss.
 */
import {
  classifyEvents,
  MAX_CLASSIFICATION_BATCH,
  type ClassificationInput,
} from '../server/ai/openrouter.ts';

type Case = Omit<ClassificationInput, 'sourceUrl'> & { expected: string[] };
const cases: Case[] = [
  {
    id: 'c1',
    title: 'Labuđe jezero',
    text: 'Baletna predstava u tri čina. Ulaznice na blagajni.',
    venue: 'Gradsko kazalište',
    expected: ['theatre'],
  },
  {
    id: 'c2',
    title: 'Balet za odrasle — radionica',
    text: 'Naučite osnovne baletne pozicije i korake. Prijave obavezne.',
    venue: 'Gradsko kazalište',
    expected: ['dance'],
  },
  {
    id: 'c3',
    title: 'Ballet in cinema: Giselle',
    text: 'Screening of the recorded Royal Ballet production.',
    venue: 'Odeon',
    expected: ['film'],
  },
  {
    id: 'c4',
    title: 'Izložba fotografija baleta',
    text: 'Fotografije s proba i predstava, otvorenje izložbe.',
    venue: 'Galerija',
    expected: ['culture'],
  },
  {
    id: 'c5',
    title: 'Salsa social night',
    text: 'Open dance floor, salsa and bachata, beginners welcome.',
    venue: 'Bar Central',
    expected: ['dance'],
  },
  {
    id: 'c6',
    title: 'Koncert: jazz trio',
    text: 'Večer jazz standarda uz mogućnost plesa.',
    venue: 'Klub',
    expected: ['music'],
  },
  {
    id: 'c7',
    title: 'Kino na otvorenom',
    text: 'Projekcija filma pod zvijezdama u parku.',
    venue: 'Park',
    expected: ['film'],
  },
  {
    id: 'c8',
    title: 'Workshop: making a short film',
    text: 'Hands-on filmmaking workshop: shoot and edit a short film.',
    venue: 'Kino',
    expected: ['workshop'],
  },
  {
    id: 'c9',
    title: 'Predstavljanje romana',
    text: 'Autorica predstavlja novi roman uz čitanje ulomaka.',
    venue: 'Knjižnica',
    expected: ['literature'],
  },
  {
    id: 'c10',
    title: 'Radionica keramike',
    text: 'Izradite vlastitu šalicu na lončarskom kolu.',
    venue: 'Knjižnica',
    expected: ['workshop'],
  },
  {
    id: 'c11',
    title: 'Tanzkurs für Anfänger — Start',
    text: 'Neuer Tango-Kurs beginnt, 8 Termine.',
    venue: 'Tanzschule',
    expected: ['dance'],
  },
  {
    id: 'c12',
    title: 'Stand-up večer',
    text: 'Komičar izvodi novi solo nastup.',
    venue: 'Sportska dvorana',
    expected: ['theatre'],
  },
  {
    id: 'c13',
    title: 'Gradski polumaraton',
    text: 'Utrka na 21 km, prijave do petka.',
    venue: null,
    expected: ['sport'],
  },
  {
    id: 'c14',
    title: 'Dan otvorenih vrata',
    text: 'Upoznajte udrugu, igre za djecu i druženje.',
    venue: 'Dom kulture',
    expected: ['community'],
  },
  {
    id: 'c15',
    title: 'Večer',
    text: 'Više informacija uskoro.',
    venue: 'Klub',
    expected: ['culture', 'community', 'music', 'nightlife'],
  },
];

const apiKey = process.env.OPENROUTER_API_KEY;
if (!apiKey) {
  console.error('Set OPENROUTER_API_KEY to run the live classification check.');
  process.exit(2);
}
let spent = 0;
const verdicts = new Map<string, string>();
for (let start = 0; start < cases.length; start += MAX_CLASSIFICATION_BATCH) {
  const result = await classifyEvents(
    cases
      .slice(start, start + MAX_CLASSIFICATION_BATCH)
      .map(({ expected: _expected, ...input }) => ({
        ...input,
        sourceUrl: 'https://example.org/event',
      })),
    { apiKey, monthlyBudgetUsd: 1, searchEnabled: false },
    { reserve: () => 'eval', settle: (_id, cost) => void (spent += cost ?? 0) },
  );
  if (!result.complete) {
    console.error(result.reason);
    process.exit(1);
  }
  for (const item of result.classifications) verdicts.set(item.id, item.category);
}
let misses = 0;
for (const item of cases) {
  const got = verdicts.get(item.id) ?? 'missing';
  const ok = item.expected.includes(got);
  if (!ok) misses++;
  console.log(
    `${ok ? 'ok  ' : 'MISS'} ${item.title} → ${got} (expected ${item.expected.join('/')})`,
  );
}
console.log(`${cases.length - misses}/${cases.length} correct · cost $${spent.toFixed(5)}`);
process.exitCode = misses ? 1 : 0;
