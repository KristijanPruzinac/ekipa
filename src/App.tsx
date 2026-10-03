import { useEffect, useId, useMemo, useState, type FormEvent } from 'react';
import { recommendationFor, type DiscoveryProfile } from '../shared/discovery';
import { categories, type Category, type PublicFeed, type WagzEvent } from '../shared/types';
import { Admin } from './Admin';
import { Preferences, readPreferences, savePreferences } from './Preferences';
import {
  api,
  categoryNames,
  dateFormat,
  errorText,
  inDateFilter,
  normalize,
  safeLink,
  timeFormat,
  type DateFilter,
} from './lib';
import { Arrow, Brand, Message, Modal, Pin, SearchIcon, Spark, Spinner } from './ui';

const dateTabs: { id: DateFilter; label: string }[] = [
  { id: 'all', label: 'Sve' },
  { id: 'today', label: 'Danas' },
  { id: 'weekend', label: 'Ovaj vikend' },
  { id: 'week', label: 'Ovaj tjedan' },
];

export function App() {
  return /^\/admin\/?$/.test(window.location.pathname) ? <Admin /> : <PublicApp />;
}

function PublicApp() {
  const [feed, setFeed] = useState<PublicFeed | null>(null),
    [error, setError] = useState(''),
    [loading, setLoading] = useState(true);
  const [date, setDate] = useState<DateFilter>('all'),
    [category, setCategory] = useState<Category | 'all'>('all'),
    [query, setQuery] = useState(''),
    [freeOnly, setFreeOnly] = useState(false),
    [sort, setSort] = useState<'date' | 'personal'>('date');
  const [preferences, setPreferences] = useState<DiscoveryProfile>(readPreferences);
  const [selected, setSelected] = useState<WagzEvent | null>(null),
    [tipOpen, setTipOpen] = useState(false);
  const personalized = preferences.audience !== 'all' || preferences.interests.length > 0;
  function changePreferences(value: DiscoveryProfile) {
    setPreferences(value);
    savePreferences(value);
    if (value.audience === 'all' && value.interests.length === 0) setSort('date');
  }
  async function refresh() {
    setLoading(true);
    setError('');
    try {
      setFeed(await api<PublicFeed>('/api/events'));
    } catch (err) {
      setError(errorText(err));
    } finally {
      setLoading(false);
    }
  }
  useEffect(() => {
    void refresh();
  }, []);
  const events = useMemo(
    () =>
      (feed?.events ?? [])
        .filter(
          (event) =>
            (category === 'all' || event.category === category) &&
            (!freeOnly || event.discovery?.free === true) &&
            inDateFilter(event, date, feed!.meta.now) &&
            normalize(`${event.title} ${event.venue ?? ''} ${event.description}`).includes(
              normalize(query.trim()),
            ),
        )
        .map((event, index) => ({
          event,
          index,
          recommendation: recommendationFor(event, preferences),
        }))
        .sort((a, b) =>
          sort === 'personal'
            ? b.recommendation.score - a.recommendation.score || a.index - b.index
            : a.index - b.index,
        ),
    [feed, category, date, query, freeOnly, preferences, sort],
  );
  const filtered = date !== 'all' || category !== 'all' || query.trim().length > 0 || freeOnly;
  const noAudienceEvidence =
    preferences.audience !== 'all' &&
    feed &&
    !feed.events.some(
      (event) =>
        event.status === 'scheduled' &&
        event.discovery?.audienceEvidence.some((item) => item.audience === preferences.audience),
    );
  const clear = () => {
    setDate('all');
    setCategory('all');
    setQuery('');
    setFreeOnly(false);
  };
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
            <span className="coordinates">45°33′ N &nbsp; 18°41′ E</span>
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
                aria-label={`${feed?.meta.totalUpcoming ?? 0} nadolazećih događaja`}
              >
                {loading && !feed ? '—' : (feed?.meta.totalUpcoming ?? '—')}
              </span>
            </div>
            <p className="section-note">DOBRI PLANOVI POČINJU OVDJE.</p>
          </div>
          <Preferences value={preferences} onChange={changePreferences} />
          <div className="filter-top">
            <div className="date-filters" role="group" aria-label="Razdoblje">
              {dateTabs.map((tab) => (
                <button
                  key={tab.id}
                  className={`date-tab ${date === tab.id ? 'active' : ''}`}
                  aria-pressed={date === tab.id}
                  onClick={() => setDate(tab.id)}
                >
                  {tab.label}
                </button>
              ))}
            </div>
            <label className="search-field">
              <SearchIcon />
              <input
                aria-label="Pretraži događaje"
                placeholder="Što ti se radi?"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
              />
              {query && (
                <button onClick={() => setQuery('')} aria-label="Očisti pretragu">
                  ×
                </button>
              )}
            </label>
          </div>
          <div className="category-filters" role="group" aria-label="Kategorija">
            <button
              className={`category-chip ${category === 'all' ? 'active' : ''}`}
              aria-pressed={category === 'all'}
              onClick={() => setCategory('all')}
            >
              Sve kategorije
            </button>
            {categories.map((id) => (
              <button
                key={id}
                className={`category-chip ${category === id ? 'active' : ''}`}
                aria-pressed={category === id}
                onClick={() => setCategory(id)}
              >
                {categoryNames[id]}
              </button>
            ))}
          </div>
          <div className="filter-bottom">
            <div className="extra-filters">
              <button
                className={`free-filter ${freeOnly ? 'active' : ''}`}
                aria-pressed={freeOnly}
                onClick={() => setFreeOnly(!freeOnly)}
              >
                <span className="free-filter-mark" aria-hidden="true">
                  {freeOnly ? '✓' : ''}
                </span>
                Besplatan ulaz
              </button>
              {filtered && (
                <button className="text-button filter-reset" onClick={clear}>
                  Očisti filtre
                </button>
              )}
            </div>
            <label className="sort-select">
              Redoslijed
              <select
                value={sort}
                onChange={(event) => setSort(event.target.value as 'date' | 'personal')}
              >
                <option value="date">Po datumu</option>
                <option value="personal" disabled={!personalized}>
                  Za tebe
                </option>
              </select>
            </label>
          </div>
          {loading ? (
            <div className="feed-loading">
              <Spinner label="Tražimo tvoj sljedeći plan…" />
            </div>
          ) : error ? (
            <div className="empty-state">
              <span className="empty-symbol" aria-hidden="true">
                ↻
              </span>
              <h3>Grad je tu. Veza je zapela.</h3>
              <p>{error}</p>
              <button className="button button-dark" onClick={() => void refresh()}>
                Pokušaj ponovno <Arrow />
              </button>
            </div>
          ) : events.length ? (
            <>
              {noAudienceEvidence && (
                <p className="discovery-feedback" role="status">
                  Za odabranu publiku zasad nema posebno označenih programa u našim najavama.
                  Odaberi i interese za osobne prijedloge; svi događaji ostaju dostupni.
                </p>
              )}
              <div className="results-line" aria-live="polite">
                <span>
                  {events.length} {events.length === 1 ? 'događaj' : 'događaja'}{' '}
                  {filtered ? 'za tvoj odabir' : 'na tvom radaru'}
                </span>
                <span>{sort === 'date' ? 'NAJBLIŽI DATUMI PRVO' : 'PREMA TVOM ODABIRU'}</span>
              </div>
              <p className="discovery-note">
                {personalized && (
                  <span className="personal-legend">Zeleno: prema tvom odabiru</span>
                )}
                <span>Topla nijansa: festivali i gradska događanja</span>
                Razlog oznake vidi u detaljima.
              </p>
              <div className="event-grid">
                {events.map(({ event, recommendation }, index) => (
                  <EventCard
                    key={event.id}
                    event={event}
                    index={index}
                    recommendation={recommendation}
                    onSelect={() => setSelected(event)}
                  />
                ))}
              </div>
            </>
          ) : (
            <div className="empty-state">
              <Spark className="empty-spark" />
              <p className="eyebrow">{filtered ? 'MALO ŠIRI PLAN?' : 'RADAR JE UKLJUČEN'}</p>
              <h3>{filtered ? 'Ovdje je zasad mirno.' : 'Novi planovi su na putu.'}</h3>
              <p>
                {filtered
                  ? freeOnly
                    ? 'Za ovaj odabir nemamo najava s potvrđenim besplatnim ulazom. U drugim najavama cijena možda još nije navedena.'
                    : 'Za ovaj odabir još nema događaja. Pogledaj druge datume ili kategorije.'
                  : 'Trenutno nema najavljenih događaja u našem pregledu. Znaš što se sprema u Osijeku? Podijeli s ekipom.'}
              </p>
              <button
                className="button button-dark"
                onClick={filtered ? clear : () => setTipOpen(true)}
              >
                {filtered ? 'Prikaži sve događaje' : 'Dojavi događaj'} <Arrow diagonal />
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
              })}{' '}
              · Sve vrijeme prikazano je za Osijek.
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
        <EventDetail event={selected} preferences={preferences} onClose={() => setSelected(null)} />
      )}
      {tipOpen && <TipDialog onClose={() => setTipOpen(false)} />}
    </>
  );
}

function EventCard({
  event,
  index,
  recommendation,
  onSelect,
}: {
  event: WagzEvent;
  index: number;
  recommendation: ReturnType<typeof recommendationFor>;
  onSelect: () => void;
}) {
  const prominence = event.status === 'scheduled' ? event.discovery?.prominence : null;
  return (
    <article
      className={`event-card ${prominence ? 'card-prominent' : ''} ${recommendation.personal ? 'card-personal' : ''} ${event.status !== 'scheduled' ? 'card-inactive' : ''}`}
    >
      <button
        className="event-card-button"
        onClick={onSelect}
        aria-label={`Detalji: ${event.title}`}
      >
        <div className="card-topline">
          <span className="category-label">{categoryNames[event.category]}</span>
          <span className="card-number">/{String(index + 1).padStart(2, '0')}</span>
        </div>
        <div className="card-title-area">
          {event.status !== 'scheduled' && (
            <span className={`status-label status-${event.status}`}>
              {event.status === 'cancelled' ? 'Otkazano' : 'Odgođeno'}
            </span>
          )}
          <h3>{event.title}</h3>
          {(recommendation.personal || prominence) && (
            <div className="card-reasons">
              {recommendation.personal && (
                <span className="card-reason card-reason-personal">✓ Za tebe</span>
              )}
              {prominence && <span className="card-reason">{prominence.label}</span>}
            </div>
          )}
          {recommendation.personal && (
            <p className="card-personal-reason">{recommendation.reasons[0]}</p>
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
          <div className="card-footer">
            <span>{event.price || 'Cijena nije navedena'}</span>
            <span className="card-open">
              <Arrow diagonal />
            </span>
          </div>
        </div>
      </button>
    </article>
  );
}

function EventDetail({
  event,
  preferences,
  onClose,
}: {
  event: WagzEvent;
  preferences: DiscoveryProfile;
  onClose: () => void;
}) {
  const sources = event.sources.filter((source) => safeLink(source.url));
  const recommendation = recommendationFor(event, preferences);
  const discovery = event.discovery;
  const audienceLabels = { students: 'Studenti i mladi', adults: 'Odrasli', seniors: 'Stariji' };
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
      {Boolean(
        recommendation.personal || discovery?.prominence || discovery?.audienceEvidence.length,
      ) && (
        <section className="detail-discovery" aria-label="Razlozi oznaka">
          <h3>Dobro je znati</h3>
          <ul>
            {preferences.interests.includes(event.category) && recommendation.personal && (
              <li>
                <strong>Prema tvom odabiru</strong>Odabrao/la si interes:{' '}
                {categoryNames[event.category]}.
              </li>
            )}
            {discovery?.audienceEvidence.map((evidence) => (
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
                {source.sourceName}
                <small>Otvori izvornu najavu</small>
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
          <p>Tvoja dojava je spremljena. Pregledat ćemo informacije prije objave.</p>
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
            Dojave provjeravamo prije objave. Pošalji informacije o događaju, bez osobnih podataka.
          </p>
        </form>
      )}
    </Modal>
  );
}
