import { useState } from 'react';
import { rankForAudience, themeForCategory } from '../shared/discovery';
import type { WagzEvent } from '../shared/types';
import { categoryNames, dateFormat, dayKey, timeFormat } from './lib';

export function EventTimeline({
  events,
  onSelect,
}: {
  events: WagzEvent[];
  onSelect: (event: WagzEvent) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const chronological = rankForAudience(events).map(({ event }) => event);
  const preview = expanded ? chronological : chronological.slice(0, 6);
  return (
    <section className="event-timeline" aria-labelledby="timeline-title">
      <div className="timeline-heading">
        <div>
          <p className="eyebrow">SLJEDEĆE STANICE</p>
          <h3 id="timeline-title">Grad, po danima.</h3>
        </div>
        <span className="timeline-direction" aria-hidden="true">
          ↓
        </span>
      </div>
      <p className="timeline-description">Tvoj brzi pogled na ono što dolazi.</p>
      <div className="timeline-legend" aria-label="Vrste događaja">
        <span className="theme-go-out">Glazba i izlasci</span>
        <span className="theme-culture">Pozornica i kultura</span>
        <span className="theme-join-in">Pokret i druženje</span>
      </div>
      <ol className="timeline-stations" data-expanded={expanded}>
        {preview.map((event, index) => {
          const theme = themeForCategory(event.category) ?? 'other';
          const newDay =
            index === 0 || dayKey(event.startsAt) !== dayKey(preview[index - 1].startsAt);
          return (
            <li
              key={event.id}
              className={`timeline-station theme-${theme} ${event.status !== 'scheduled' ? 'station-inactive' : ''}`}
            >
              <div className="timeline-rails" aria-hidden="true">
                <i />
                <i />
                <i />
                <span className="station-dot" />
              </div>
              <button
                onClick={() => onSelect(event)}
                aria-label={`Na vremenskoj crti: ${event.title}`}
              >
                {newDay && (
                  <time dateTime={event.startsAt} className="station-day">
                    {dateFormat(event.startsAt, {
                      weekday: 'short',
                      day: 'numeric',
                      month: 'short',
                    })}
                  </time>
                )}
                <strong>{event.title}</strong>
                <span className="station-meta">
                  {categoryNames[event.category]} ·{' '}
                  {event.startsAt.length === 10
                    ? 'Vrijeme nije navedeno'
                    : timeFormat(event.startsAt)}
                </span>
                {event.status !== 'scheduled' && (
                  <span className="station-status">
                    {event.status === 'cancelled' ? 'Otkazano' : 'Odgođeno'}
                  </span>
                )}
              </button>
            </li>
          );
        })}
      </ol>
      {chronological.length > 3 && (
        <button
          className={`timeline-expand ${chronological.length <= 6 ? 'mobile-expand-only' : ''}`}
          aria-expanded={expanded}
          onClick={() => setExpanded(!expanded)}
        >
          {expanded ? 'Prikaži manje' : 'Cijela vremenska crta'}{' '}
          <span aria-hidden="true">{expanded ? '−' : '+'}</span>
        </button>
      )}
    </section>
  );
}
