import { dailyHoursText, dayStrip } from '../shared/day-strip';
import type { PublicEvent } from '../shared/types';

/** Calendar-like start/end strip: each day is a box; times sit on the start and end boxes. */
export function DayStrip({ event }: { event: PublicEvent }) {
  const cells = dayStrip(event);
  const daily = cells.length > 1 ? dailyHoursText(event.dailyHours ?? null) : null;
  return (
    <>
      <ol className="day-strip">
        {cells.map((cell, index) => (
          <li key={index} className={`day-cell day-${cell.kind}`}>
            {cell.kind === 'gap' ? (
              <span className="day-gap">+ {cell.hidden} dana</span>
            ) : (
              <>
                <span className="day-weekday">{cell.weekday}</span>
                <strong className="day-date">{cell.date}</strong>
                {cell.kind === 'open' ? (
                  <span className="day-time day-time-missing">nije naveden</span>
                ) : cell.kind !== 'mid' || cell.time ? (
                  <span className={`day-time${cell.time ? '' : ' day-time-missing'}`}>
                    {cell.time ?? (cell.kind === 'single' ? 'vrijeme nije navedeno' : '—')}
                  </span>
                ) : null}
              </>
            )}
          </li>
        ))}
      </ol>
      {daily && <span className="day-daily">Svaki dan {daily}</span>}
    </>
  );
}
