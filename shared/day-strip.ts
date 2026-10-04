import { knownEnd } from './discovery.ts';
import type { PublicEvent } from './types.ts';

/** One calendar cell in the event detail day strip. Times are never invented. */
export interface DayCell {
  kind: 'single' | 'start' | 'mid' | 'end' | 'gap' | 'open';
  weekday: string;
  date: string;
  /** Printed time on start/end/single cells; null means the source gave none. */
  time: string | null;
  /** Number of collapsed days for a `gap` cell. */
  hidden?: number;
}

export const MAX_VISIBLE_DAYS = 5;
const zone = 'Europe/Zagreb';
const dayFormat = new Intl.DateTimeFormat('en-CA', {
  timeZone: zone,
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
});
const timeFormat = new Intl.DateTimeFormat('en-GB', {
  timeZone: zone,
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});
const SHORT = ['ned', 'pon', 'uto', 'sri', 'čet', 'pet', 'sub'];
const LONG = ['nedjelja', 'ponedjeljak', 'utorak', 'srijeda', 'četvrtak', 'petak', 'subota'];

function day(value: string): string {
  if (value.length === 10) return value;
  const parts = Object.fromEntries(
    dayFormat.formatToParts(new Date(value)).map((part) => [part.type, part.value]),
  );
  return `${parts.year}-${parts.month}-${parts.day}`;
}
const time = (value: string) => (value.length === 10 ? null : timeFormat.format(new Date(value)));
const weekday = (iso: string) => new Date(`${iso}T12:00:00Z`).getUTCDay();
const label = (iso: string) => `${Number(iso.slice(8, 10))}.${Number(iso.slice(5, 7))}.`;
const addDays = (iso: string, days: number) => {
  const date = new Date(`${iso}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
};
const cell = (kind: DayCell['kind'], iso: string, at: string | null, long = false): DayCell => ({
  kind,
  weekday: (long ? LONG : SHORT)[weekday(iso)],
  date: label(iso),
  time: at,
});

/** "18:00–21:00" for daily hours, "od 18:00" when only the start is stated. */
export function dailyHoursText(hours: PublicEvent['dailyHours']): string | null {
  if (!hours) return null;
  return hours.end ? `${hours.start}–${hours.end}` : `od ${hours.start}`;
}

export function dayStrip(
  event: Pick<PublicEvent, 'startsAt' | 'endsAt'> & { dailyHours?: PublicEvent['dailyHours'] },
): DayCell[] {
  const startDay = day(event.startsAt);
  const startTime = time(event.startsAt);
  const end = knownEnd(event as PublicEvent);
  if (!end) {
    const first = cell(startTime ? 'start' : 'single', startDay, startTime, !startTime);
    return startTime ? [first, { kind: 'open', weekday: 'kraj', date: '?', time: null }] : [first];
  }
  const endDay = day(end);
  const endTime = time(end);
  if (endDay === startDay)
    return [
      cell(
        'single',
        startDay,
        startTime && endTime
          ? `${startTime}–${endTime}`
          : (startTime ?? (endTime ? `do ${endTime}` : null)),
        true,
      ),
    ];
  const span =
    Math.round(
      (Date.parse(`${endDay}T12:00:00Z`) - Date.parse(`${startDay}T12:00:00Z`)) / 86_400_000,
    ) + 1;
  // Daily hours are printed once under the ticket, so the day stubs carry dates only.
  const daily = Boolean(event.dailyHours);
  const first = cell('start', startDay, daily ? null : startTime);
  const last = cell('end', endDay, daily ? null : endTime);
  if (span > MAX_VISIBLE_DAYS)
    return [first, { kind: 'gap', weekday: '', date: '', time: null, hidden: span - 2 }, last];
  return [
    first,
    ...Array.from({ length: span - 2 }, (_, index) =>
      cell('mid', addDays(startDay, index + 1), null),
    ),
    last,
  ];
}

/** One stub of the event-detail ticket: a big line and a small line. */
export interface Stub {
  tone: 'main' | 'mid' | 'open';
  big: string | null;
  small: string;
}

/** Ticket stubs plus daily hours, printed once under the ticket for multi-day runs. */
export function ticket(
  event: Pick<PublicEvent, 'startsAt' | 'endsAt'> & { dailyHours?: PublicEvent['dailyHours'] },
): { stubs: Stub[]; daily: string | null } {
  const cells = dayStrip(event);
  const daily = cells.length > 1 ? dailyHoursText(event.dailyHours ?? null) : null;
  const stubs = cells.map((cell): Stub => {
    if (cell.kind === 'gap') return { tone: 'mid', big: `+${cell.hidden}`, small: 'dana' };
    if (cell.kind === 'open') return { tone: 'open', big: '?', small: 'kraj' };
    if (cell.kind === 'mid')
      return {
        tone: 'mid',
        big: daily ? `${cell.date.split('.')[0]}.` : null,
        small: cell.weekday,
      };
    return cell.time
      ? { tone: 'main', big: cell.time, small: `${cell.weekday} ${cell.date}` }
      : { tone: 'main', big: cell.date, small: cell.weekday };
  });
  return { stubs, daily };
}
