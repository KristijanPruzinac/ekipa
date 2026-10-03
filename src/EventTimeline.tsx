import { useState, useSyncExternalStore, type CSSProperties } from 'react';
import {
  durationLabel,
  isOngoing,
  knownEnd,
  rankForAudience,
  themeForCategory,
  timelineFor,
} from '../shared/discovery';
import type { WagzEvent } from '../shared/types';
import { categoryNames, dateFormat, timeFormat } from './lib';

const compactQuery = () => window.matchMedia('(max-width: 760px)');
const subscribe = (callback: () => void) => {
  const media = compactQuery();
  media.addEventListener('change', callback);
  return () => media.removeEventListener('change', callback);
};

export function EventTimeline({
  events,
  now,
  onSelect,
}: {
  events: WagzEvent[];
  now: string;
  onSelect: (event: WagzEvent) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const compact = useSyncExternalStore(subscribe, () => compactQuery().matches);
  const chartOpen = !compact || mobileOpen;
  const chronological = rankForAudience(events).map(({ event }) => event);
  const limit = compact ? 3 : 6;
  const preview = expanded ? chronological : chronological.slice(0, limit);
  const { moments, ranges } = timelineFor(preview);
  const lanes = Math.max(1, ...ranges.map((range) => range.lane + 1));
  return (
    <section
      className={`event-timeline ${chartOpen ? '' : 'timeline-collapsed'}`}
      aria-labelledby={chartOpen ? 'timeline-title' : undefined}
      aria-label={chartOpen ? undefined : 'Vremenska crta događaja'}
    >
      {chartOpen && (
        <>
          <div className="timeline-heading">
            <div>
              <p className="eyebrow">RITAM GRADA</p>
              <h3 id="timeline-title">Sve ima svoj trenutak.</h3>
            </div>
            <span className="timeline-direction" aria-hidden="true">
              ↘
            </span>
          </div>
          <p className="timeline-description">Početak, kraj i sve između.</p>
        </>
      )}
      {compact && (
        <button
          className="timeline-mobile-toggle"
          aria-expanded={mobileOpen}
          aria-controls="timeline-chart"
          aria-label={mobileOpen ? 'Zatvori vremensku crtu' : 'Otvori vremensku crtu'}
          onClick={() => {
            setMobileOpen(!mobileOpen);
            setExpanded(false);
          }}
        >
          <span className="timeline-toggle-copy">
            <strong>{mobileOpen ? 'Zatvori vremensku crtu' : 'Otvori vremensku crtu'}</strong>
            {!mobileOpen && <small>Datumi i trajanja na jednom mjestu.</small>}
          </span>
          <span aria-hidden="true">{mobileOpen ? '−' : '+'}</span>
        </button>
      )}
      {chartOpen && (
        <div id="timeline-chart">
          <div className="timeline-legend" aria-label="Vrste događaja">
            <span className="theme-go-out">Izlasci</span>
            <span className="theme-culture">Kultura</span>
            <span className="theme-join-in">Druženje</span>
          </div>
          <div className="timeline-symbols" aria-label="Oznake na vremenskoj crti">
            <span>
              <i aria-hidden="true" />
              Početak
            </span>
            <span>
              <i className="symbol-end" aria-hidden="true" />
              Kraj
            </span>
          </div>
          <p className="timeline-scale-note">
            Luk spaja početak i kraj. Razmaci nisu mjerilo trajanja.
          </p>
          <div
            className="timeline-track"
            style={{ '--range-space': `${18 + lanes * 7}px` } as CSSProperties}
          >
            <div className="timeline-spine" aria-hidden="true" />
            {ranges.map(({ event, start, end, lane }) => (
              <div
                key={event.id}
                aria-hidden="true"
                className={`timeline-range theme-${themeForCategory(event.category) ?? 'other'} ${event.status !== 'scheduled' ? 'range-inactive' : ''}`}
                style={{ gridRow: `${start + 1} / ${end + 1}`, width: `${12 + lane * 7}px` }}
              />
            ))}
            <ol className="timeline-stations">
              {moments.map(({ event, value, ending }, index) => {
                const end = knownEnd(event);
                const duration = durationLabel(event);
                return (
                  <li
                    key={`${event.id}-${ending ? 'end' : 'start'}`}
                    style={{ gridRow: index + 1 }}
                    className={`timeline-station theme-${themeForCategory(event.category) ?? 'other'} ${ending ? 'station-ending' : 'station-start'} ${event.status !== 'scheduled' ? 'station-inactive' : ''}`}
                  >
                    <time dateTime={value} className="station-time">
                      <b>{dateFormat(value, { day: 'numeric', month: 'numeric' })}</b>
                      <span>{value.length === 10 ? 'sat nije naveden' : timeFormat(value)}</span>
                    </time>
                    <span className="station-dot" aria-hidden="true" />
                    <button
                      onClick={() => onSelect(event)}
                      aria-label={`${ending ? 'Završetak' : 'Na vremenskoj crti'}: ${event.title}`}
                    >
                      {ending ? (
                        <>
                          <span className="station-end-label">ZAVRŠETAK</span>
                          <span className="station-end-title">{event.title}</span>
                        </>
                      ) : (
                        <>
                          {isOngoing(event, now) && <span className="station-live">U TIJEKU</span>}
                          <strong>{event.title}</strong>
                          <span className="station-category">{categoryNames[event.category]}</span>
                          <span className={`station-duration ${end ? 'has-end' : ''}`}>
                            {end ? (
                              <>
                                <span aria-hidden="true">↳ </span>
                                {duration ??
                                  `${dateFormat(event.startsAt, { day: 'numeric', month: 'numeric' })} – ${dateFormat(end, { day: 'numeric', month: 'numeric' })}`}
                              </>
                            ) : (
                              'Kraj nije naveden'
                            )}
                          </span>
                          {event.status !== 'scheduled' && (
                            <span className="station-status">
                              {event.status === 'cancelled' ? 'Otkazano' : 'Odgođeno'}
                            </span>
                          )}
                        </>
                      )}
                      <span className="station-open">
                        Detalji <span aria-hidden="true">›</span>
                      </span>
                    </button>
                  </li>
                );
              })}
            </ol>
          </div>
          {chronological.length > limit && (
            <button
              className="timeline-expand"
              aria-expanded={expanded}
              onClick={() => setExpanded(!expanded)}
            >
              {expanded ? 'Prikaži manje' : 'Cijela vremenska crta'}{' '}
              <span aria-hidden="true">{expanded ? '−' : '+'}</span>
            </button>
          )}
        </div>
      )}
    </section>
  );
}
