/** Human, calm date/time formatting for invitations. */

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const MONTHS = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

export function formatWhen(iso: string): string {
  const d = new Date(iso);
  return `${DAYS[d.getDay()]}, ${d.getDate()} ${MONTHS[d.getMonth()]} · ${formatTime(d)}`;
}

export function formatTime(d: Date): string {
  const h = d.getHours();
  const m = d.getMinutes().toString().padStart(2, '0');
  return `${h.toString().padStart(2, '0')}:${m}`;
}

export function formatDuration(min: number): string {
  if (min < 60) return `${min} min`;
  const h = min / 60;
  return Number.isInteger(h) ? `${h}h` : `${Math.floor(h)}h ${min % 60}m`;
}

export function endTimeLabel(iso: string, durationMin: number): string {
  const end = new Date(new Date(iso).getTime() + durationMin * 60000);
  return formatTime(end);
}
