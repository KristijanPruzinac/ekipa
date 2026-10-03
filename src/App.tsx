import { useEffect, useId, useMemo, useRef, useState, type FormEvent } from 'react';
import {
  audienceLabels,
  durationLabel,
  eventDurationText,
  isOngoing,
  rankForAudience,
  sourceAudienceEvidence,
  sourceAudienceLabels,
  themeForCategory,
} from '../shared/discovery';
import { type PublicFeed, type WagzEvent } from '../shared/types';
import { Admin } from './Admin';
import { EventArt } from './EventArt';
import { EventTimeline } from './EventTimeline';
import { api, categoryNames, dateFormat, errorText, safeLink, timeFormat } from './lib';
import { Arrow, Brand, Message, Modal, Pin, Spark, Spinner } from './ui';

export function App() {
  return /^\/admin\/?$/.test(window.location.pathname) ? <Admin /> : <PublicApp />;
}

function PublicApp() {
  const [feed, setFeed] = useState<PublicFeed | null>(null),
    [error, setError] = useState(''),
    [loading, setLoading] = useState(true);
  const refreshing = useRef(false);
  const [selected, setSelected] = useState<WagzEvent | null>(null),
    [tipOpen, setTipOpen] = useState(false);
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
    void refresh();
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
  const ongoing = events.filter(({ event }) => isOngoing(event, feed!.meta.now));
  const upcoming = events.filter(({ event }) => !isOngoing(event, feed!.meta.now));
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
              Koncerti, izlasci i sve između.
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
              <h2 id="feed-title">Uhvati grad.</h2>
              <span
                className="event-count"
                aria-label={`${feed?.events.length ?? 0} nadolazećih događaja`}
              >
                {loading && !feed ? '—' : (feed?.events.length ?? '—')}
              </span>
            </div>
            <p className="section-note">DOBRI PLANOVI POČINJU OVDJE.</p>
          </div>
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
          ) : events.length ? (
            <>
              <a className="skip-to-events" href="#upcoming-events">
                Preskoči na nadolazeće događaje
              </a>
              <div className="discovery-layout">
                <EventTimeline events={feed!.events} now={feed!.meta.now} onSelect={setSelected} />
                <div className="card-feed">
                  <div className="results-line" aria-live="polite">
                    <span>
                      {events.length} {events.length === 1 ? 'događaj' : 'događaja'} na tvom radaru
                    </span>
                    <span>PO DATUMU</span>
                  </div>
                  {ongoing.length > 0 && (
                    <OngoingEvents
                      events={ongoing.map(({ event }) => event)}
                      now={feed!.meta.now}
                      onSelect={setSelected}
                    />
                  )}
                  {ongoing.length > 0 && (
                    <p className="upcoming-heading">
                      Sljedeće u gradu <span>{upcoming.length}</span>
                    </p>
                  )}
                  {upcoming.length === 0 && (
                    <p className="audience-result-note">
                      Nove najave stižu uskoro. Programi koji traju dostupni su iznad.
                    </p>
                  )}
                  <div className="event-grid" id="upcoming-events" tabIndex={-1}>
                    {upcoming.map(({ event }) => (
                      <EventCard key={event.id} event={event} onSelect={() => setSelected(event)} />
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
          <a href="/admin">
            Uredništvo <Arrow diagonal />
          </a>
        </div>
      </footer>
      {selected && (
        <EventDetail event={selected} now={feed!.meta.now} onClose={() => setSelected(null)} />
      )}
      {tipOpen && <TipDialog onClose={() => setTipOpen(false)} />}
    </>
  );
}

function OngoingEvents({
  events,
  now,
  onSelect,
}: {
  events: WagzEvent[];
  now: string;
  onSelect: (event: WagzEvent) => void;
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
          <button
            className={`ongoing-event theme-${themeForCategory(event.category) ?? 'other'}`}
            key={event.id}
            onClick={() => onSelect(event)}
            aria-label={`U tijeku: ${event.title}`}
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
          </button>
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

function EventCard({ event, onSelect }: { event: WagzEvent; onSelect: () => void }) {
  const audiences = sourceAudienceLabels(event);
  const prominence = event.status === 'scheduled' ? event.discovery?.prominence : null;
  return (
    <article
      className={`event-card theme-${themeForCategory(event.category) ?? 'other'} ${prominence ? 'card-prominent' : ''} ${event.status !== 'scheduled' ? 'card-inactive' : ''}`}
    >
      <button
        className="event-card-button"
        onClick={onSelect}
        aria-label={`Detalji: ${event.title}`}
      >
        <div className="card-visual">
          <EventArt category={event.category} />
        </div>
        <div className="card-topline">
          <span className="category-label">{categoryNames[event.category]}</span>
        </div>
        {audiences.length > 0 && <p className="card-audience">{audiences.join(' · ')}</p>}
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
      </button>
    </article>
  );
}

function EventDetail({
  event,
  now,
  onClose,
}: {
  event: WagzEvent;
  now: string;
  onClose: () => void;
}) {
  const sources = event.sources.filter((source) => safeLink(source.url));
  const audienceEvidence = sourceAudienceEvidence(event);
  const discovery = event.discovery;
  return (
    <Modal
      title={event.title}
      eyebrow={categoryNames[event.category]}
      onClose={onClose}
      className="event-modal"
    >
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
            {dateFormat(event.startsAt, {
              weekday: 'long',
              day: 'numeric',
              month: 'long',
              year: 'numeric',
            })}
            <span>{timeFormat(event.startsAt)}</span>
            {event.endsAt && (
              <span>
                Do {dateFormat(event.endsAt, { day: 'numeric', month: 'long' })}
                {event.endsAt.length > 10 ? `, ${timeFormat(event.endsAt)}` : ''}
              </span>
            )}
            {durationLabel(event) && <span>Trajanje: {durationLabel(event)}</span>}
            {!event.endsAt && <span>Kraj nije naveden</span>}
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
      {Boolean(discovery?.prominence || audienceEvidence.length) && (
        <section className="detail-discovery" aria-label="Razlozi oznaka">
          <h3>Dobro je znati</h3>
          {audienceEvidence.length > 0 && <p>Publika navedena u najavi</p>}
          <ul>
            {audienceEvidence.map((evidence) => (
              <li key={`${evidence.audience}-${evidence.sourceUrl}`}>
                <strong>{audienceLabels[evidence.audience]}</strong>
                <p>{evidence.reason}</p>
                {safeLink(evidence.sourceUrl) && (
                  <a href={safeLink(evidence.sourceUrl)!} target="_blank" rel="noopener noreferrer">
                    Provjeri u najavi <Arrow diagonal />
                  </a>
                )}
              </li>
            ))}
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
    </Modal>
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
