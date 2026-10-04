import { useEffect, useId, useMemo, useRef, useState, type FormEvent } from 'react';
import {
  durationLabel,
  eventDurationText,
  isFeaturedEvent,
  isOngoing,
  rankForAudience,
  themeForCategory,
} from '../shared/discovery';
import {
  categories,
  type Category,
  type PublicFeed,
  type PublicEvent,
  type PublicEventResponse,
} from '../shared/types';
import { ADMIN_PATH, eventPath, publicSiteUrl } from '../shared/site';
import { Admin } from './Admin';
import { EventArt } from './EventArt';
import { EventTimeline } from './EventTimeline';
import { DayStrip } from './DayStrip';
import {
  api,
  ApiError,
  categoryNames,
  dateFormat,
  dayKey,
  errorText,
  eventCategoryLabel,
  eventDetailsLabel,
  openEventLink,
  safeLink,
  timeFormat,
} from './lib';
import { Arrow, Brand, Message, Modal, Pin, Spark, Spinner } from './ui';

export function App() {
  const path = window.location.pathname;
  if (path === ADMIN_PATH || path === `${ADMIN_PATH}/`) return <Admin />;
  if (path === '/') return <PublicApp />;
  const event = path.match(/^\/dogadaji\/([^/]+)\/?$/);
  if (event) {
    try {
      return <EventRoute id={decodeURIComponent(event[1])} />;
    } catch {
      /* malformed URL */
    }
  }
  return <PublicMissing />;
}

function PublicMissing() {
  return (
    <>
      <header className="site-header wrap">
        <Brand />
      </header>
      <main className="event-page wrap">
        <h1>Događaj nije pronađen.</h1>
        <p>Najava možda više nije dostupna.</p>
        <a className="button button-dark" href="/#dogadaji">
          Svi događaji <Arrow />
        </a>
      </main>
    </>
  );
}

function EventRoute({ id }: { id: string }) {
  const [data, setData] = useState<PublicEventResponse | null>(null);
  const [error, setError] = useState('');
  const [missing, setMissing] = useState(false);
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let cancelled = false;
    setError('');
    void api<PublicEventResponse>(`/api/events/${encodeURIComponent(id)}`)
      .then((value) => {
        if (!cancelled) setData(value);
      })
      .catch((error) => {
        if (cancelled) return;
        if (error instanceof ApiError && error.status === 404) setMissing(true);
        else setError(errorText(error));
      });
    return () => {
      cancelled = true;
    };
  }, [id, attempt]);
  if (data) return <EventPage event={data.event} now={data.meta.now} />;
  if (missing) return <PublicMissing />;
  return (
    <>
      <header className="site-header wrap">
        <Brand />
      </header>
      <main className="event-page wrap">
        {error ? (
          <>
            <Message error>{error}</Message>
            <button className="button button-dark" onClick={() => setAttempt(attempt + 1)}>
              Pokušaj ponovno
            </button>
          </>
        ) : (
          <Spinner label="Učitavanje događaja…" />
        )}
      </main>
    </>
  );
}

export function PublicApp({ initialFeed }: { initialFeed?: PublicFeed }) {
  const [feed, setFeed] = useState<PublicFeed | null>(initialFeed ?? null),
    [error, setError] = useState(''),
    [loading, setLoading] = useState(!initialFeed);
  const refreshing = useRef(false);
  const [selected, setSelected] = useState<PublicEvent | null>(null),
    [tipOpen, setTipOpen] = useState(false);
  const [activity, setActivity] = useState<Category | null>(null);
  const latestFeed = useRef(feed);
  latestFeed.current = feed;
  const homeTitle = useRef<string | null>(null);
  const pendingEventBack = useRef<Promise<void> | null>(null);
  const eventOpener = useRef<HTMLElement | null>(null);
  const focusGeneration = useRef(0);
  const pendingEventFocus = useRef<{
    opener: HTMLElement | null;
    generation: number;
  } | null>(null);
  const selectedRef = useRef(selected);
  selectedRef.current = selected;
  const selectEvent = async (event: PublicEvent) => {
    focusGeneration.current++;
    pendingEventFocus.current = null;
    const opener = document.activeElement;
    if (pendingEventBack.current) await pendingEventBack.current;
    eventOpener.current = opener instanceof HTMLElement ? opener : null;
    // Forward can revisit a closed tip dialog's entry without reopening it.
    // Reuse that entry, just as Modal does, instead of adding a phantom Back stop.
    const closedModal = window.history.state?.wagzModal;
    const previousState = closedModal ? closedModal.previous : window.history.state;
    const eventState = {
      ...(previousState && typeof previousState === 'object' ? previousState : {}),
      wagzPublicEvent: event.id,
    };
    if (closedModal) window.history.replaceState(eventState, '', eventPath(event.id));
    else window.history.pushState(eventState, '', eventPath(event.id));
    setSelected(event);
  };
  const closeEvent = () => {
    pendingEventFocus.current = {
      opener: eventOpener.current,
      generation: ++focusGeneration.current,
    };
    setSelected(null);
    if (window.history.state?.wagzPublicEvent && !pendingEventBack.current) {
      pendingEventBack.current = new Promise<void>((resolve) => {
        window.addEventListener(
          'popstate',
          () => {
            window.setTimeout(() => {
              pendingEventBack.current = null;
              resolve();
            }, 0);
          },
          { once: true },
        );
      });
      window.history.back();
    }
  };
  useEffect(() => {
    let historyRestoringFocus = false;
    const cancelPendingFocus = () => {
      if (pendingEventFocus.current) focusGeneration.current++;
    };
    const onFocusIn = (event: FocusEvent) => {
      // A traversal restores its saved focus after popstate, within the same
      // browser task. Later focus movement belongs to the user/assistive tool.
      if (
        !historyRestoringFocus &&
        pendingEventFocus.current &&
        event.target !== pendingEventFocus.current.opener &&
        event.target !== document.body &&
        !(event.target instanceof Element && event.target.closest('dialog'))
      )
        cancelPendingFocus();
    };
    const onPopState = () => {
      const returningFromEvent = selectedRef.current !== null || pendingEventBack.current !== null;
      const id = window.history.state?.wagzPublicEvent;
      const event = id ? latestFeed.current?.events.find((item) => item.id === id) : null;
      if (id && !event) window.location.reload();
      else {
        setSelected(event ?? null);
        if (event) {
          focusGeneration.current++;
          pendingEventFocus.current = null;
        } else if (returningFromEvent) {
          pendingEventFocus.current ??= {
            opener: eventOpener.current,
            generation: focusGeneration.current,
          };
          const request = pendingEventFocus.current;
          historyRestoringFocus = true;
          // History may restore an earlier hash target after the dialog cleanup.
          // Return to its actual opener once that browser restoration has finished.
          window.setTimeout(() => {
            historyRestoringFocus = false;
            window.requestAnimationFrame(() => {
              if (
                pendingEventFocus.current === request &&
                request.generation === focusGeneration.current &&
                request.opener?.isConnected &&
                !document.querySelector('dialog[open]')
              )
                request.opener.focus({ preventScroll: true });
              if (pendingEventFocus.current === request) pendingEventFocus.current = null;
            });
          }, 0);
        }
      }
    };
    window.addEventListener('popstate', onPopState);
    document.addEventListener('keydown', cancelPendingFocus, true);
    document.addEventListener('pointerdown', cancelPendingFocus, true);
    document.addEventListener('focusin', onFocusIn, true);
    return () => {
      window.removeEventListener('popstate', onPopState);
      document.removeEventListener('keydown', cancelPendingFocus, true);
      document.removeEventListener('pointerdown', cancelPendingFocus, true);
      document.removeEventListener('focusin', onFocusIn, true);
      focusGeneration.current++;
      pendingEventFocus.current = null;
    };
  }, []);
  useEffect(() => {
    homeTitle.current ??= document.title;
    document.title = selected ? `${selected.title} — We are gen Z` : homeTitle.current;
    document
      .querySelector('link[rel="canonical"]')
      ?.setAttribute('href', publicSiteUrl(selected ? eventPath(selected.id) : '/'));
  }, [selected]);
  async function refresh(background = false) {
    if (refreshing.current) return;
    refreshing.current = true;
    if (!background) {
      setLoading(true);
      setError('');
    }
    try {
      const fresh = await api<PublicFeed>('/api/events');
      setFeed(fresh);
      if (
        selectedRef.current &&
        !fresh.events.some((event) => event.id === selectedRef.current!.id)
      )
        closeEvent();
      setSelected((current) =>
        current ? (fresh.events.find((event) => event.id === current.id) ?? null) : null,
      );
      setError('');
    } catch (err) {
      if (!background) setError(errorText(err));
    } finally {
      refreshing.current = false;
      if (!background) setLoading(false);
    }
  }
  useEffect(() => {
    if (!initialFeed) void refresh();
    const foregroundRefresh = () => {
      if (document.visibilityState === 'visible') void refresh(true);
    };
    let timer: ReturnType<typeof setInterval> | undefined;
    const schedule = () => {
      clearInterval(timer);
      if (document.visibilityState === 'visible') timer = setInterval(foregroundRefresh, 60000);
    };
    const visibility = () => {
      schedule();
      foregroundRefresh();
    };
    schedule();
    window.addEventListener('focus', foregroundRefresh);
    document.addEventListener('visibilitychange', visibility);
    return () => {
      clearInterval(timer);
      window.removeEventListener('focus', foregroundRefresh);
      document.removeEventListener('visibilitychange', visibility);
    };
  }, []);
  const events = useMemo(() => rankForAudience(feed?.events ?? []), [feed]);
  const featured = events.filter(({ event }) => isFeaturedEvent(event));
  const activityCounts = new Map(
    categories.map((category) => [
      category,
      events.filter(({ event }) => event.category === category).length,
    ]),
  );
  const visibleEvents = activity
    ? events.filter(({ event }) => event.category === activity)
    : featured;
  const ongoing = visibleEvents.filter(({ event }) => isOngoing(event, feed!.meta.now));
  const upcoming = visibleEvents.filter(({ event }) => !isOngoing(event, feed!.meta.now));
  return (
    <>
      <a className="skip-link" href="#dogadaji">
        Preskoči na događaje
      </a>
      <header className="site-header wrap">
        <Brand />
        <div className="header-city">
          <span className="live-dot" />
          OSIJEK, HR
        </div>
        <button className="button button-dark header-tip" onClick={() => setTipOpen(true)}>
          Dojavi događaj <Arrow diagonal />
        </button>
      </header>
      <main>
        <section className="hero wrap" aria-labelledby="hero-title">
          <div className="hero-topline">
            <p className="eyebrow">TVOJ GRAD. TVOJA EKIPA. TVOJ PLAN.</p>
          </div>
          <div className="hero-heading">
            <h1 id="hero-title">
              Osijek,
              <br />
              vidimo se <span className="highlight-word">vani.</span>
            </h1>
            <div className="hero-stamp" aria-hidden="true">
              <Spark />
              <Arrow diagonal />
            </div>
          </div>
          <div className="hero-bottom">
            <p>
              Koncerti, predstave, radionice i izlasci.
              <br />
              Pronađi svoj razlog za izaći.
            </p>
            <a href="#dogadaji" className="hero-jump">
              ŠTO SE DOGAĐA <span>↓</span>
            </a>
          </div>
        </section>
        <section className="feed-section wrap" id="dogadaji" aria-labelledby="feed-title">
          <div className="section-title-row">
            <div className="section-heading">
              <span className="tiny-cross" aria-hidden="true">
                ✳
              </span>
              <h2 id="feed-title">Događanja u Osijeku</h2>
              <span
                className="event-count"
                aria-label={`${activity ? categoryNames[activity] : 'Izdvojeno'}, ${visibleEvents.length} događaja`}
              >
                {loading && !feed ? '—' : visibleEvents.length}
              </span>
            </div>
            <p className="section-note">DOBRI PLANOVI POČINJU OVDJE.</p>
          </div>
          {!loading && !error && (events.length > 0 || activity) && (
            <div className="activity-filters" role="group" aria-label="Vrsta događaja">
              <button
                type="button"
                aria-pressed={activity === null}
                onClick={() => setActivity(null)}
              >
                Izdvojeno <span>{featured.length}</span>
              </button>
              {categories
                .filter((category) => category !== 'other' && activityCounts.get(category)! > 0)
                .map((category) => (
                  <button
                    type="button"
                    key={category}
                    aria-pressed={activity === category}
                    onClick={() => setActivity(category)}
                  >
                    {categoryNames[category]} <span>{activityCounts.get(category)}</span>
                  </button>
                ))}
            </div>
          )}
          {loading ? (
            <div className="feed-loading">
              <Spinner label="Tražimo tvoj sljedeći plan…" />
            </div>
          ) : error ? (
            <div className="empty-state">
              <h3>Grad je tu. Veza je zapela.</h3>
              <p>{error}</p>
              <button className="button button-dark" onClick={() => void refresh()}>
                Pokušaj ponovno <Arrow />
              </button>
            </div>
          ) : events.length || activity ? (
            <>
              <a className="skip-to-events" href="#upcoming-events">
                Preskoči na nadolazeće događaje
              </a>
              <div className="discovery-layout">
                <EventTimeline
                  events={visibleEvents.map(({ event }) => event)}
                  now={feed!.meta.now}
                  onSelect={selectEvent}
                />
                <div className="card-feed">
                  <div className="results-line" aria-live="polite">
                    <span>
                      {visibleEvents.length} {visibleEvents.length === 1 ? 'događaj' : 'događaja'}{' '}
                      na tvom radaru
                    </span>
                    <span>PO DATUMU</span>
                  </div>
                  {ongoing.length > 0 && (
                    <OngoingEvents
                      events={ongoing.map(({ event }) => event)}
                      now={feed!.meta.now}
                      onSelect={selectEvent}
                    />
                  )}
                  {ongoing.length > 0 && (
                    <p className="upcoming-heading">
                      Sljedeće u gradu <span>{upcoming.length}</span>
                    </p>
                  )}
                  {visibleEvents.length === 0 ? (
                    <div className="activity-empty">
                      <p>
                        {activity
                          ? `Trenutno nema događaja vrste ${categoryNames[activity].toLocaleLowerCase('hr')}. Najave su se možda promijenile.`
                          : 'Trenutno nema izdvojenih događaja. Sve filmske projekcije pronađi pod Film.'}
                      </p>
                      <button
                        className="button button-dark"
                        onClick={() => setActivity(activity ? null : 'film')}
                      >
                        {activity ? 'Prikaži izdvojeno' : 'Prikaži filmove'} <Arrow />
                      </button>
                    </div>
                  ) : (
                    upcoming.length === 0 && (
                      <p className="ongoing-result-note">
                        Nove najave stižu uskoro. Programi koji traju dostupni su iznad.
                      </p>
                    )
                  )}
                  <div className="event-grid" id="upcoming-events" tabIndex={-1}>
                    {upcoming.map(({ event }) => (
                      <EventCard key={event.id} event={event} onSelect={() => selectEvent(event)} />
                    ))}
                  </div>
                </div>
              </div>
            </>
          ) : (
            <div className="empty-state">
              <Spark className="empty-spark" />
              <p className="eyebrow">RADAR JE UKLJUČEN</p>
              <h3>Novi planovi su na putu.</h3>
              <p>
                Trenutno nema najavljenih događaja u našem pregledu. Znaš što se sprema u Osijeku?
              </p>
              <button className="button button-dark" onClick={() => setTipOpen(true)}>
                Dojavi događaj <Arrow diagonal />
              </button>
            </div>
          )}
          {feed?.meta.lastCheckedAt && !loading && !error && (
            <p className="feed-updated">
              Zadnji dohvat:{' '}
              {dateFormat(feed.meta.lastCheckedAt, {
                day: 'numeric',
                month: 'numeric',
                hour: '2-digit',
                minute: '2-digit',
              })}
              {' · '}Sve vrijeme prikazano je za Osijek.
            </p>
          )}
        </section>
        <section className="tip-banner">
          <div className="wrap tip-banner-inner">
            <div>
              <p className="eyebrow">DOBRA INFORMACIJA DALEKO IDE.</p>
              <h2>Znaš nešto što mi ne znamo?</h2>
              <p>Mali koncert, veliki tulum, nešto sasvim treće. Pošalji nam dojavu.</p>
            </div>
            <button className="button button-dark" onClick={() => setTipOpen(true)}>
              Podijeli s ekipom <Arrow diagonal />
            </button>
          </div>
        </section>
      </main>
      <footer className="site-footer wrap">
        <div>
          <Brand small />
          <p>Manje skrolanja. Više Osijeka.</p>
        </div>
        <div className="footer-right">
          <span>NEOVISNI PREGLED DOGAĐANJA U OSIJEKU</span>
          <p>Detalje prije odlaska provjeri kod organizatora.</p>
        </div>
      </footer>
      {selected && <EventDetail event={selected} now={feed!.meta.now} onClose={closeEvent} />}
      {tipOpen && <TipDialog onClose={() => setTipOpen(false)} />}
    </>
  );
}

function OngoingEvents({
  events,
  now,
  onSelect,
}: {
  events: PublicEvent[];
  now: string;
  onSelect: (event: PublicEvent) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  const shown = expanded ? events : events.slice(0, 2);
  return (
    <section className="ongoing-events" aria-label={`U tijeku: ${events.length} događaja`}>
      <div className="ongoing-heading">
        <h3>
          <span className="live-dot" /> U tijeku
        </h3>
        <span>
          {events.length} {events.length === 1 ? 'događaj' : 'događaja'}
        </span>
      </div>
      <p className="ongoing-note">Još stigneš. Točne termine provjeri u najavi.</p>
      <div id="ongoing-list">
        {shown.map((event) => (
          <a
            className={`ongoing-event theme-${themeForCategory(event.category) ?? 'other'}`}
            key={event.id}
            href={eventPath(event.id)}
            onClick={(click) => openEventLink(click, () => onSelect(event))}
            aria-label={`U tijeku. ${eventDetailsLabel(event, now)}${event.endsAt!.length === 10 ? ' Završni sat nije naveden.' : ''}`}
          >
            <span className="ongoing-dot" aria-hidden="true" />
            <span>
              <strong>{event.title}</strong>
              <small>
                {eventDurationText(event, now)}
                {event.endsAt!.length === 10 ? ' · završni sat nije naveden' : ''}
              </small>
            </span>
            <Arrow />
          </a>
        ))}
      </div>
      {events.length > 2 && (
        <button
          className="ongoing-expand"
          aria-expanded={expanded}
          aria-controls="ongoing-list"
          onClick={() => setExpanded(!expanded)}
        >
          {expanded ? 'Sažmi događaje u tijeku' : `Prikaži sve u tijeku (${events.length})`}
        </button>
      )}
    </section>
  );
}

function EventCard({ event, onSelect }: { event: PublicEvent; onSelect: () => void }) {
  const prominence = event.status === 'scheduled' ? event.discovery?.prominence : null;
  return (
    <article
      className={`event-card theme-${themeForCategory(event.category) ?? 'other'} ${prominence ? 'card-prominent' : ''} ${event.status !== 'scheduled' ? 'card-inactive' : ''}`}
    >
      <a
        className="event-card-button"
        href={eventPath(event.id)}
        onClick={(click) => openEventLink(click, onSelect)}
        aria-label={eventDetailsLabel(event)}
      >
        <div className="card-visual">
          <EventArt category={event.category} />
        </div>
        <div className="card-topline">
          <span className="category-label">{eventCategoryLabel(event)}</span>
        </div>
        <div className="card-title-area">
          {event.status !== 'scheduled' && (
            <span className={`status-label status-${event.status}`}>
              {event.status === 'cancelled' ? 'Otkazano' : 'Odgođeno'}
            </span>
          )}
          <h3>{event.title}</h3>
          {prominence && (
            <div className="card-reasons">
              <span className="card-reason">{prominence.label}</span>
            </div>
          )}
        </div>
        <div className="card-bottom">
          <div className="card-date">
            <span>{dateFormat(event.startsAt, { day: '2-digit' }).replace('.', '')}</span>
            <div>
              <strong>{dateFormat(event.startsAt, { month: 'short' }).toUpperCase()}</strong>
              <span>
                {dateFormat(event.startsAt, { weekday: 'short' })} ·{' '}
                {event.startsAt.length === 10
                  ? 'Vrijeme nije navedeno'
                  : timeFormat(event.startsAt)}
              </span>
            </div>
          </div>
          <div className="card-location">
            <Pin />
            <span>{event.venue || 'Lokacija još nije navedena'}</span>
          </div>
          <p className="card-duration">{eventDurationText(event)}</p>
          <div className="card-footer">
            <span>{event.price || 'Cijena nije navedena'}</span>
            <span className="card-open">
              Detalji <Arrow />
            </span>
          </div>
        </div>
      </a>
    </article>
  );
}

function EventDetail({
  event,
  now,
  onClose,
}: {
  event: PublicEvent;
  now: string;
  onClose: () => void;
}) {
  return (
    <Modal
      title={event.title}
      eyebrow={eventCategoryLabel(event)}
      onClose={onClose}
      className="event-modal"
      manageHistory={false}
    >
      <EventFacts event={event} now={now} />
    </Modal>
  );
}

export function EventFacts({ event, now }: { event: PublicEvent; now: string }) {
  const sources = event.sources.filter((source) => safeLink(source.url));
  const discovery = event.discovery;
  return (
    <>
      {event.status !== 'scheduled' && (
        <Message error>
          {event.status === 'cancelled'
            ? 'Ovaj događaj je otkazan.'
            : 'Ovaj događaj je odgođen. Novi termin provjeri kod organizatora.'}
        </Message>
      )}
      {isOngoing(event, now) && (
        <p className="detail-ongoing">
          <strong>U tijeku</strong>
          <span>
            {eventDurationText(event, now)}
            {event.endsAt!.length === 10 ? ' · završni sat nije naveden' : ''}
          </span>
        </p>
      )}
      <dl className="event-facts">
        <div>
          <dt>KADA</dt>
          <dd>
            <DayStrip event={event} />
            {durationLabel(event) && <span>Trajanje: {durationLabel(event)}</span>}
          </dd>
        </div>
        <div>
          <dt>GDJE</dt>
          <dd>
            {event.venue || 'Lokacija još nije navedena'}
            <span>{event.address || event.city}</span>
          </dd>
        </div>
        <div>
          <dt>ULAZ</dt>
          <dd>{event.price || 'Cijena nije navedena'}</dd>
        </div>
      </dl>
      {event.description && <div className="event-description">{event.description}</div>}
      {discovery?.prominence && (
        <section className="detail-discovery" aria-label="Razlozi oznaka">
          <h3>Dobro je znati</h3>
          <ul>
            {discovery?.prominence && (
              <li>
                <strong>{discovery.prominence.label}</strong>
                <p>{discovery.prominence.reason}</p>
                {safeLink(discovery.prominence.sourceUrl) && (
                  <a
                    href={safeLink(discovery.prominence.sourceUrl)!}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    Provjeri u najavi <Arrow diagonal />
                  </a>
                )}
              </li>
            )}
          </ul>
          {discovery?.prominence && (
            <p>Oznaka opisuje vrstu programa iz najave, a ne broj posjetitelja.</p>
          )}
        </section>
      )}
      <div className="detail-sources">
        <p className="eyebrow">IZVOR I DETALJI</p>
        {sources.length ? (
          sources.map((source, index) => (
            <a
              key={`${source.sourceId}-${index}`}
              href={safeLink(source.url)!}
              target="_blank"
              rel="noopener noreferrer"
              className="source-link"
            >
              <span>
                Otvori izvornu najavu
                <small>{source.sourceName}</small>
              </span>
              <Arrow diagonal />
            </a>
          ))
        ) : (
          <p>Objavljeno prema dojavi koju je pregledalo uredništvo.</p>
        )}
        <p className="fine-print">
          Planovi se mogu promijeniti. Prije odlaska provjeri izvornu najavu. Vrijeme je prikazano
          za Osijek.
        </p>
      </div>
    </>
  );
}

export function EventPage({
  event: initialEvent,
  now: initialNow,
}: {
  event: PublicEvent;
  now: string;
}) {
  const [event, setEvent] = useState(initialEvent);
  const [now, setNow] = useState(initialNow);
  const [missing, setMissing] = useState(false);
  const [tipOpen, setTipOpen] = useState(false);
  const refreshing = useRef(false);
  useEffect(() => {
    document.title = `${event.title} — We are gen Z`;
    document
      .querySelector('link[rel="canonical"]')
      ?.setAttribute('href', publicSiteUrl(eventPath(event.id)));
  }, [event.id, event.title]);
  useEffect(() => {
    const refresh = async () => {
      if (document.visibilityState !== 'visible' || refreshing.current) return;
      refreshing.current = true;
      try {
        const response = await fetch(`/api/events/${encodeURIComponent(initialEvent.id)}`);
        if (response.status === 404) {
          setMissing(true);
          return;
        }
        if (!response.ok) return;
        const fresh = (await response.json()) as { event: PublicEvent; meta: { now: string } };
        setEvent(fresh.event);
        setNow(fresh.meta.now);
      } catch {
        // Keep the previously loaded source-backed event during a transient outage.
      } finally {
        refreshing.current = false;
      }
    };
    const timer = window.setInterval(() => void refresh(), 60000);
    const foreground = () => void refresh();
    document.addEventListener('visibilitychange', foreground);
    window.addEventListener('focus', foreground);
    return () => {
      clearInterval(timer);
      document.removeEventListener('visibilitychange', foreground);
      window.removeEventListener('focus', foreground);
    };
  }, [initialEvent.id]);
  const until = event.endsAt ?? event.startsAt;
  const past =
    until.length === 10
      ? until < dayKey(now)
      : event.endsAt
        ? Date.parse(until) <= Date.parse(now)
        : Date.parse(until) < Date.parse(now);
  return (
    <>
      <header className="site-header wrap">
        <Brand />
        <a className="button button-dark event-back" href="/#dogadaji">
          Svi događaji <Arrow />
        </a>
      </header>
      <main className={`event-page wrap theme-${themeForCategory(event.category) ?? 'other'}`}>
        {missing ? (
          <section className="event-page-content">
            <h1>Događaj više nije dostupan.</h1>
            <p>Pogledaj aktualne najave u pregledu događaja.</p>
            <a className="button button-dark" href="/#dogadaji">
              Pronađi novi plan <Arrow />
            </a>
          </section>
        ) : (
          <article>
            <div className="event-page-art">
              <EventArt category={event.category} />
            </div>
            <div className="event-page-content">
              <p className="eyebrow">{eventCategoryLabel(event)}</p>
              <h1>{event.title}</h1>
              {past && (
                <div className="event-past" role="note">
                  <strong>
                    {event.endsAt && event.status === 'scheduled'
                      ? 'Događaj je završio.'
                      : 'Najavljeni termin je prošao.'}
                  </strong>
                  <p>
                    {event.endsAt
                      ? 'Ova najava ostaje dostupna kao zapis događaja.'
                      : 'Kraj nije naveden u izvoru. Ova najava više nije među nadolazećima.'}
                  </p>
                  <a href="/#dogadaji">
                    Pogledaj što slijedi u gradu <Arrow />
                  </a>
                </div>
              )}
              <EventFacts event={event} now={now} />
            </div>
          </article>
        )}
        <footer className="event-page-footer">
          <a href="/#dogadaji">← Svi događaji u Osijeku</a>
          <button className="button button-dark" onClick={() => setTipOpen(true)}>
            Dojavi događaj <Arrow diagonal />
          </button>
        </footer>
      </main>
      {tipOpen && <TipDialog onClose={() => setTipOpen(false)} />}
    </>
  );
}

function TipDialog({ onClose }: { onClose: () => void }) {
  const [note, setNote] = useState(''),
    [url, setUrl] = useState(''),
    [website, setWebsite] = useState(''),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [sent, setSent] = useState(false);
  const id = useId();
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      await api('/api/tips', {
        method: 'POST',
        body: JSON.stringify({ note, url: url.trim() || undefined, website }),
      });
      setSent(true);
    } catch (err) {
      setError(errorText(err));
    } finally {
      setBusy(false);
    }
  }
  return (
    <Modal
      title={sent ? 'Dobra dojava. Hvala!' : 'Što se sprema u gradu?'}
      eyebrow="OD EKIPE ZA EKIPU"
      onClose={onClose}
    >
      {sent ? (
        <div className="tip-success">
          <Spark />
          <p>
            Tvoja dojava je spremljena za sljedeću dnevnu provjeru. Pronađeni događaj pregledat ćemo
            prije objave.
          </p>
          <button className="button button-dark" onClick={onClose}>
            Natrag na događaje <Arrow />
          </button>
        </div>
      ) : (
        <form onSubmit={submit} className="tip-form">
          <p className="modal-intro">
            Napiši što znaš — naziv, mjesto, datum ili samo dobar trag. Ne trebaš imati sve detalje.
          </p>
          <label htmlFor={`${id}-note`}>
            Tvoja dojava <span>obavezno</span>
          </label>
          <textarea
            autoFocus
            id={`${id}-note`}
            required
            minLength={3}
            maxLength={2000}
            rows={5}
            value={note}
            onChange={(event) => setNote(event.target.value)}
            placeholder="Npr. u subotu je koncert u…"
          />
          <div className="field-caption">
            Bez prijave. Bez komplikacija.<span>{note.length}/2000</span>
          </div>
          <label htmlFor={`${id}-url`}>
            Poveznica na najavu <span>ako je imaš</span>
          </label>
          <input
            id={`${id}-url`}
            type="url"
            maxLength={2048}
            placeholder="https://…"
            value={url}
            onChange={(event) => setUrl(event.target.value)}
          />
          <div className="honeypot" aria-hidden="true">
            <label htmlFor={`${id}-website`}>Web stranica</label>
            <input
              id={`${id}-website`}
              name="website"
              tabIndex={-1}
              autoComplete="off"
              value={website}
              onChange={(event) => setWebsite(event.target.value)}
            />
          </div>
          {error && <Message error>{error}</Message>}
          <button type="submit" className="button button-dark full-width" disabled={busy}>
            {busy ? 'Šaljemo…' : 'Pošalji dojavu'}
            {!busy && <Arrow diagonal />}
          </button>
          <p className="fine-print">
            Dojave provjeravamo uz dnevni dohvat događaja. Svaki prijedlog pregledamo prije objave.
            Pošalji informacije o događaju, bez osobnih podataka.
          </p>
        </form>
      )}
    </Modal>
  );
}
