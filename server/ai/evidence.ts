const months = [
  'sijecanj|sijecnja',
  'veljaca|veljace',
  'ozujak|ozujka',
  'travanj|travnja',
  'svibanj|svibnja',
  'lipanj|lipnja',
  'srpanj|srpnja',
  'kolovoz|kolovoza',
  'rujan|rujna',
  'listopad|listopada',
  'studeni|studenog|studenoga',
  'prosinac|prosinca',
];
const monthNames = months.join('|');
const monthNumber = (name: string) =>
  months.findIndex((names) => names.split('|').includes(name)) + 1;

/** Only explicit calendar days count. A month/year cannot justify its first day. */
export function supportedDays(quote: string): Set<string> {
  const days = new Set<string>();
  const text = quote
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase();
  const add = (d: string, m: string | number, y: string) => {
    const value = `${y}-${String(m).padStart(2, '0')}-${d.padStart(2, '0')}`;
    const date = new Date(`${value}T12:00:00Z`);
    if (Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value)
      days.add(value);
  };
  // A timestamp's T is a word character, so a trailing word boundary loses its day.
  for (const match of text.matchAll(/\b(\d{4})-(\d{2})-(\d{2})(?=t\d{2}:\d{2}|\b)/g))
    add(match[3], match[2], match[1]);
  // KC separates dates and times with slashes, e.g. 9.10.2026./20.00 sati/.
  for (const match of text.matchAll(
    /(?<![\d./-])(\d{1,2})\s*([./])\s*(\d{1,2})\s*\2\s*(\d{4})(?!\w)/g,
  ))
    add(match[1], match[3], match[4]);
  const written = new RegExp(`\\b(\\d{1,2})\\.?\\s+(${monthNames})\\s*,?\\s*(\\d{4})\\b`, 'g');
  for (const match of text.matchAll(written)) add(match[1], monthNumber(match[2]), match[3]);

  // Share the explicitly stated month/year only between written range endpoints.
  // No intermediate days are invented for a range or a list joined with "i".
  for (const match of text.matchAll(
    /\b(\d{1,2})\.?(?:\s*(\d{1,2})\.)?\s*(?:[-–—]|do|i)\s*(\d{1,2})\s*\.\s*(\d{1,2})\s*\.\s*(\d{4})\b/g,
  )) {
    add(match[1], match[2] ?? match[4], match[5]);
    add(match[3], match[4], match[5]);
  }
  const writtenRange = new RegExp(
    `\\b(\\d{1,2})\\.?(?:\\s+(${monthNames}))?\\s*(?:[-–—]|do|i)\\s*(\\d{1,2})\\.?\\s+(${monthNames})\\s*,?\\s*(\\d{4})\\b`,
    'g',
  );
  for (const match of text.matchAll(writtenRange)) {
    add(match[1], monthNumber(match[2] ?? match[4]), match[5]);
    add(match[3], monthNumber(match[4]), match[5]);
  }
  return days;
}

/** Omit unsubstantiated times rather than silently treating midnight as known. */
export function supportedTime(value: string, quote: string): string {
  if (value.length === 10) return value;
  const [hour, minute, second = '00'] = value.slice(11, 19).split(':');
  // Offsets, date components and a timestamp's minute/second pair are not clocks.
  const text = quote
    .replace(/(\b\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(?::\d{2})?)(?:[+-]\d{2}:\d{2}|Z)\b/gi, '$1')
    .replace(/\b(?:UTC|GMT)[+-]\d{2}:\d{2}\b/gi, '');
  const precise = /(?<![\d:.])([01]?\d|2[0-3])([:.])([0-5]\d)(?::([0-5]\d))?(?![\d:]|\.\d)/g;
  for (const match of text.matchAll(precise)) {
    if (Number(match[1]) !== Number(hour) || match[3] !== minute) continue;
    // A bare "9.10" can be a Croatian date; dotted clocks require a time cue.
    if (
      match[2] === '.' &&
      Number(match[3]) >= 1 &&
      Number(match[3]) <= 12 &&
      !/^\s*(?:h\b|sati\b)/i.test(text.slice(match.index! + match[0].length))
    )
      continue;
    if (match[4] === second) return value;
    if (!match[4]) return `${value.slice(0, 17)}00${value.slice(19)}`;
  }
  const h = Number(hour);
  const wholeHour =
    minute === '00' &&
    (new RegExp(`(?<![\\d:.])0?${h}\\s*(?:h\\b|sati\\b)`, 'i').test(text) ||
      new RegExp(
        `(?<![\\d:.])0?${h}\\s*(?:[-–—]|do)\\s*(?:[01]?\\d|2[0-3])\\s*(?:h\\b|sati\\b)`,
        'i',
      ).test(text));
  return wholeHour ? `${value.slice(0, 17)}00${value.slice(19)}` : value.slice(0, 10);
}
