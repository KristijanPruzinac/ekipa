import { useCallback, useEffect, useId, useMemo, useRef, useState, type FormEvent } from 'react';
import {
  categories,
  type AdminDashboard,
  type EventDraft,
  type Publication,
  type Tip,
  type WagzEvent,
} from '../shared/types';
import {
  api,
  ApiError,
  blankDraft,
  categoryNames,
  dateFormat,
  dayKey,
  errorText,
  eventDraft,
  localTime,
  safeLink,
  zonedTimestamp,
} from './lib';
import { Arrow, Brand, Message, Modal, Spinner } from './ui';

type Tab = 'inbox' | 'events' | 'sources';
type Action = (
  path: string,
  method: 'POST' | 'PATCH',
  body: unknown,
  message: string | ((result: unknown) => string),
) => Promise<boolean>;
type ActionState = { path: string; progress: string; result?: string; error?: boolean };
const tipStatus: Record<Tip['status'], string> = {
  inbox: 'Čeka provjeru',
  draft: 'Prijedlog za pregled',
  accepted: 'Prihvaćeno',
  rejected: 'Odbijeno',
  archived: 'Arhiva',
};
const publicationNames: Record<Publication, string> = {
  draft: 'Nacrt',
  published: 'Objavljeno',
  rejected: 'Odbijeno',
};

export function Admin() {
  const [key, setKey] = useState(''),
    [keyInput, setKeyInput] = useState(''),
    [dashboard, setDashboard] = useState<AdminDashboard | null>(null);
  const [tab, setTab] = useState<Tab>('inbox'),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [message, setMessage] = useState('');
  const [editingTip, setEditingTip] = useState<Tip | null>(null),
    [editingEvent, setEditingEvent] = useState<WagzEvent | null>(null);
  const [actionState, setActionState] = useState<ActionState | null>(null);
  const session = useRef('');
  const refreshVersion = useRef(0);
  const acting = useRef(false);
  const logout = useCallback(() => {
    session.current = '';
    refreshVersion.current++;
    setKey('');
    setKeyInput('');
    setDashboard(null);
    setEditingTip(null);
    setEditingEvent(null);
    setMessage('');
    setActionState(null);
  }, []);
  const handleError = useCallback(
    (err: unknown) => {
      if (err instanceof ApiError && err.status === 401) logout();
      setError(errorText(err));
    },
    [logout],
  );
  const refresh = useCallback(async () => {
    if (!key) return;
    const version = ++refreshVersion.current;
    try {
      const next = await api<AdminDashboard>('/api/admin/dashboard', {}, key);
      if (session.current === key && version === refreshVersion.current) setDashboard(next);
    } catch (err) {
      if (session.current === key && version === refreshVersion.current) handleError(err);
    }
  }, [key, handleError]);
  const processing = Boolean(dashboard?.collecting || dashboard?.preparingTipIds?.length);
  useEffect(() => {
    if (!key) return;
    const update = () => {
      if (document.visibilityState === 'visible') void refresh();
    };
    const timer = window.setInterval(update, processing ? 2500 : 15000);
    window.addEventListener('focus', update);
    document.addEventListener('visibilitychange', update);
    return () => {
      window.clearInterval(timer);
      window.removeEventListener('focus', update);
      document.removeEventListener('visibilitychange', update);
    };
  }, [processing, key, refresh]);
  async function login(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      const candidate = keyInput.trim();
      const data = await api<AdminDashboard>('/api/admin/dashboard', {}, candidate);
      session.current = candidate;
      setKey(candidate);
      setKeyInput('');
      setDashboard(data);
    } catch (err) {
      setError(errorText(err));
    } finally {
      setBusy(false);
    }
  }
  const act: Action = async (path, method, body, success) => {
    if (acting.current) return false;
    acting.current = true;
    setBusy(true);
    setError('');
    setMessage('');
    const progress = path.endsWith('/prepare')
      ? 'Provjeravam izvore i pripremam prijedlog… To može potrajati do dvije minute.'
      : 'Spremam promjene…';
    setActionState({ path, progress });
    try {
      const result = await api(
        path,
        { method, ...(body === undefined ? {} : { body: JSON.stringify(body) }) },
        key,
      );
      if (session.current !== key) return false;
      const feedback = typeof success === 'function' ? success(result) : success;
      setMessage(feedback);
      setActionState({ path, progress: '', result: feedback });
      await refresh();
      return true;
    } catch (err) {
      if (session.current !== key) return false;
      handleError(err);
      setActionState({ path, progress: '', result: errorText(err), error: true });
      if (err instanceof ApiError && err.status === 409) await refresh();
      return false;
    } finally {
      acting.current = false;
      setBusy(false);
    }
  };
  const inboxCount =
    dashboard?.tips.filter((tip) => ['inbox', 'draft'].includes(tip.status)).length ?? 0;
  return (
    <div className="admin-page">
      <header className="site-header wrap">
        <Brand small />
        <a className="back-to-site" href="/">
          Na javni pregled <Arrow diagonal />
        </a>
        {key && (
          <button className="button button-outline button-small" onClick={logout}>
            Odjavi se
          </button>
        )}
      </header>
      {!key || !dashboard ? (
        <main className="admin-login wrap">
          <p className="eyebrow">WAGZ / UREDNIŠTVO</p>
          <h1>Hej, uredniče.</h1>
          <p>Pregled dojava, događaja i izvora na jednom mjestu.</p>
          <form onSubmit={login}>
            <label htmlFor="admin-key">Admin ključ</label>
            <input
              id="admin-key"
              type="password"
              autoComplete="off"
              required
              value={keyInput}
              onChange={(event) => setKeyInput(event.target.value)}
              placeholder="Unesi svoj ključ"
            />
            {error && <Message error>{error}</Message>}
            <button className="button button-dark" disabled={busy}>
              {busy ? 'Prijava…' : 'Otvori uredništvo'}
              <Arrow />
            </button>
            <p className="fine-print">
              Ključ ostaje samo u memoriji ove kartice. Osvježavanje stranice odjavljuje te.
            </p>
          </form>
        </main>
      ) : (
        <main className="admin-main wrap">
          <div className="admin-heading">
            <div>
              <p className="eyebrow">WAGZ / UREDNIŠTVO</p>
              <h1>Grad pod kontrolom.</h1>
            </div>
            <button
              className="button button-outline button-small"
              disabled={busy}
              onClick={() => void refresh()}
            >
              Osvježi pregled <span aria-hidden="true">↻</span>
            </button>
          </div>
          <nav className="admin-tabs" aria-label="Uredništvo">
            <button
              aria-current={tab === 'inbox' ? 'page' : undefined}
              onClick={() => setTab('inbox')}
            >
              Inbox <span>{inboxCount}</span>
            </button>
            <button
              aria-current={tab === 'events' ? 'page' : undefined}
              onClick={() => setTab('events')}
            >
              Događaji <span>{dashboard.events.length}</span>
            </button>
            <button
              aria-current={tab === 'sources' ? 'page' : undefined}
              onClick={() => setTab('sources')}
            >
              Izvori <span>{dashboard.sources.length}</span>
            </button>
          </nav>
          {!editingTip && !editingEvent && error && <Message error>{error}</Message>}
          {message && <Message>{message}</Message>}
          {busy && actionState && !editingTip && !editingEvent && (
            <Spinner label={actionState.progress} />
          )}
          {tab === 'inbox' && (
            <Inbox
              tips={dashboard.tips}
              busy={busy}
              actionState={actionState}
              preparingTipIds={dashboard.preparingTipIds ?? []}
              act={act}
              onEdit={(tip) => {
                setError('');
                setEditingTip(tip);
              }}
            />
          )}
          {tab === 'events' && (
            <EventList
              events={dashboard.events}
              busy={busy}
              act={act}
              onEdit={(event) => {
                setError('');
                setEditingEvent(event);
              }}
            />
          )}
          {tab === 'sources' && <Sources dashboard={dashboard} busy={busy} act={act} />}
        </main>
      )}
      {editingTip && (
        <DraftEditor
          key={`${editingTip.id}:${editingTip.revision ?? 0}`}
          title="Pregled dojave"
          initial={editingTip.draft ?? { ...blankDraft(), sourceUrl: safeLink(editingTip.url) }}
          busy={busy}
          error={error}
          tip={editingTip}
          stale={
            (dashboard?.tips.find((tip) => tip.id === editingTip.id)?.revision ?? 0) !==
            (editingTip.revision ?? 0)
          }
          onReload={() => {
            const latest = dashboard?.tips.find((tip) => tip.id === editingTip.id);
            if (latest) {
              setError('');
              if (['inbox', 'draft'].includes(latest.status)) setEditingTip(latest);
              else setEditingTip(null);
            }
          }}
          onClose={() => setEditingTip(null)}
          onSubmit={async (draft, publish) => {
            if (
              await act(
                `/api/admin/tips/${encodeURIComponent(editingTip.id)}`,
                'PATCH',
                { action: publish ? 'accept' : 'save', draft, revision: editingTip.revision ?? 0 },
                publish
                  ? 'Dojava je prihvaćena i događaj je objavljen.'
                  : 'Prijedlog je spremljen.',
              )
            )
              setEditingTip(null);
          }}
        />
      )}
      {editingEvent && (
        <DraftEditor
          title="Uredi događaj"
          initial={eventDraft(editingEvent)}
          busy={busy}
          error={error}
          onClose={() => setEditingEvent(null)}
          onSubmit={async (draft) => {
            if (
              await act(
                `/api/admin/events/${encodeURIComponent(editingEvent.id)}`,
                'PATCH',
                { fields: draft },
                'Promjene događaja su spremljene.',
              )
            )
              setEditingEvent(null);
          }}
        />
      )}
    </div>
  );
}

function Inbox({
  tips,
  busy,
  actionState,
  preparingTipIds,
  act,
  onEdit,
}: {
  tips: Tip[];
  busy: boolean;
  actionState: ActionState | null;
  preparingTipIds: string[];
  act: Action;
  onEdit: (tip: Tip) => void;
}) {
  const [filter, setFilter] = useState<'all' | Tip['status']>('draft');
  const shown = tips.filter((tip) => filter === 'all' || tip.status === filter);
  const filters = [
    { id: 'draft', label: 'Za pregled' },
    { id: 'inbox', label: 'Čeka provjeru' },
    { id: 'accepted', label: 'Prihvaćeno' },
    { id: 'archived', label: 'Arhiva' },
    { id: 'rejected', label: 'Odbijeno' },
    { id: 'all', label: 'Sve' },
  ] as const;
  return (
    <section aria-labelledby="inbox-title">
      <div className="admin-section-header">
        <div>
          <h2 id="inbox-title">Od ekipe, za grad.</h2>
          <p>Pronađeni događaji čekaju tvoje odobrenje prije objave.</p>
          <p className="fine-print">
            Nove dojave provjeravaju se uz dnevni dohvat. Spam i dojave bez potvrđenog događaja
            odlaze u arhivu s razlogom. Neuspjela provjera čeka ponovni pokušaj.
          </p>
        </div>
      </div>
      <div className="category-filters admin-filters" role="group" aria-label="Status dojave">
        {filters.map((item) => (
          <button
            className={`category-chip ${filter === item.id ? 'active' : ''}`}
            aria-pressed={filter === item.id}
            aria-label={item.label}
            key={item.id}
            onClick={() => setFilter(item.id)}
          >
            {item.label}{' '}
            <span>
              {item.id === 'all'
                ? tips.length
                : tips.filter((tip) => tip.status === item.id).length}
            </span>
          </button>
        ))}
      </div>
      {!shown.length ? (
        <AdminEmpty
          title={
            filter === 'draft'
              ? 'Nema prijedloga za pregled.'
              : filter === 'inbox'
                ? 'Red za provjeru je prazan.'
                : 'Nema dojava u ovom prikazu.'
          }
          text={
            filter === 'draft'
              ? 'Nove dojave pronaći ćeš pod „Čeka provjeru”.'
              : 'Dojave i spremljeni prijedlozi ostaju dostupni u ostalim prikazima.'
          }
        />
      ) : (
        <div className="admin-list">
          {shown.map((tip) => (
            <article className="tip-row" key={tip.id}>
              <div className="admin-row-top">
                <span className={`admin-badge badge-${tip.status}`}>{tipStatus[tip.status]}</span>
                <span>
                  {dateFormat(tip.submittedAt, {
                    day: 'numeric',
                    month: 'numeric',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                  })}
                </span>
              </div>
              <p className="tip-note">{tip.note}</p>
              {safeLink(tip.url) && (
                <a
                  className="inline-source"
                  href={safeLink(tip.url)!}
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  Izvorna poveznica <Arrow diagonal />
                </a>
              )}
              <div className="tip-reason">
                <strong>
                  {tip.verification === 'source_match'
                    ? 'Moguće podudaranje s izvorom'
                    : 'Podaci nisu neovisno potvrđeni'}
                </strong>
                <p>{tip.reason}</p>
              </div>
              {tip.draft && (
                <p className="draft-preview">
                  <span>Prijedlog</span>
                  {tip.draft.title || 'Naziv još nije naveden'} ·{' '}
                  {tip.draft.startsAt ? dateFormat(tip.draft.startsAt) : 'Datum još nije poznat'}
                </p>
              )}
              {(preparingTipIds.includes(tip.id) ||
                (actionState?.path.includes(`/tips/${encodeURIComponent(tip.id)}`) &&
                  actionState.progress)) && (
                <div className="tip-progress">
                  <Spinner
                    label={
                      actionState?.path.includes(`/tips/${encodeURIComponent(tip.id)}`) &&
                      actionState.progress
                        ? actionState.progress
                        : 'Provjera dojave je u tijeku. Rezultat će se prikazati ovdje.'
                    }
                  />
                </div>
              )}
              {actionState?.path.includes(`/tips/${encodeURIComponent(tip.id)}`) &&
                actionState.result && (
                  <Message error={actionState.error}>{actionState.result}</Message>
                )}
              <div className="admin-actions">
                {['inbox', 'draft'].includes(tip.status) && (
                  <>
                    <button
                      className="button button-dark button-small"
                      disabled={busy}
                      onClick={() => onEdit(tip)}
                    >
                      {tip.draft ? 'Pregledaj prijedlog' : 'Uredi prijedlog'}
                      <Arrow />
                    </button>
                    <button
                      className="button button-outline button-small"
                      disabled={busy || preparingTipIds.includes(tip.id)}
                      onClick={() =>
                        void act(
                          `/api/admin/tips/${encodeURIComponent(tip.id)}/prepare`,
                          'POST',
                          undefined,
                          (result) => {
                            const prepared = result as Tip;
                            return prepared.reason || 'Provjera je završena. Pregledaj prijedlog.';
                          },
                        )
                      }
                    >
                      {preparingTipIds.includes(tip.id)
                        ? 'Provjera u tijeku…'
                        : 'Pripremi / provjeri izvore'}
                    </button>
                    <button
                      className="text-button danger"
                      disabled={busy}
                      onClick={() =>
                        void act(
                          `/api/admin/tips/${encodeURIComponent(tip.id)}`,
                          'PATCH',
                          { action: 'reject', revision: tip.revision ?? 0 },
                          'Dojava je odbijena.',
                        )
                      }
                    >
                      Odbij
                    </button>
                  </>
                )}
                {['archived', 'rejected'].includes(tip.status) && (
                  <button
                    className="button button-outline button-small"
                    disabled={busy}
                    onClick={() =>
                      void act(
                        `/api/admin/tips/${encodeURIComponent(tip.id)}`,
                        'PATCH',
                        { action: 'restore', revision: tip.revision ?? 0 },
                        tip.draft
                          ? 'Prijedlog je vraćen na pregled.'
                          : 'Dojava je vraćena u red za dnevnu provjeru.',
                      )
                    }
                  >
                    {tip.draft ? 'Vrati na pregled' : 'Vrati na provjeru'}
                  </button>
                )}
                {tip.status !== 'archived' && (
                  <button
                    className="text-button"
                    disabled={busy}
                    onClick={() =>
                      void act(
                        `/api/admin/tips/${encodeURIComponent(tip.id)}`,
                        'PATCH',
                        { action: 'archive', revision: tip.revision ?? 0 },
                        'Dojava je arhivirana i može se vratiti.',
                      )
                    }
                  >
                    Arhiviraj
                  </button>
                )}
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}

function EventList({
  events,
  busy,
  act,
  onEdit,
}: {
  events: WagzEvent[];
  busy: boolean;
  act: Action;
  onEdit: (event: WagzEvent) => void;
}) {
  const [filter, setFilter] = useState<Publication | 'all'>('all'),
    [query, setQuery] = useState('');
  const shown = useMemo(
    () =>
      events.filter(
        (event) =>
          (filter === 'all' || event.publication === filter) &&
          event.title.toLocaleLowerCase('hr').includes(query.toLocaleLowerCase('hr')),
      ),
    [events, filter, query],
  );
  return (
    <section aria-labelledby="admin-events-title">
      <div className="admin-section-header">
        <div>
          <h2 id="admin-events-title">Što ide u javnost.</h2>
          <p>Nacrti čekaju odobrenje. Ručne izmjene čuvaju se pri sljedećem dohvatu.</p>
        </div>
        <input
          className="admin-search"
          aria-label="Pretraži sve događaje"
          placeholder="Pronađi događaj…"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </div>
      <div className="category-filters admin-filters" role="group" aria-label="Status objave">
        {(['all', 'draft', 'published', 'rejected'] as const).map((id) => (
          <button
            key={id}
            aria-pressed={filter === id}
            className={`category-chip ${filter === id ? 'active' : ''}`}
            onClick={() => setFilter(id)}
          >
            {id === 'all' ? 'Sve' : publicationNames[id]}
          </button>
        ))}
      </div>
      {!shown.length ? (
        <AdminEmpty
          title="Još nema događaja u ovom prikazu."
          text="Pokreni dohvat u kartici Izvori ili pregledaj pristigle dojave."
        />
      ) : (
        <div className="admin-list">
          {shown.map((event) => (
            <article className="admin-event-row" key={event.id}>
              <div className="admin-event-info">
                <div className="event-admin-meta">
                  <span className={`admin-badge badge-${event.publication}`}>
                    {publicationNames[event.publication]}
                  </span>
                  <span>{categoryNames[event.category]}</span>
                  {event.status !== 'scheduled' && (
                    <span className="danger">
                      {event.status === 'cancelled' ? 'Otkazano' : 'Odgođeno'}
                    </span>
                  )}
                </div>
                <h3>{event.title}</h3>
                <p>
                  {dateFormat(event.startsAt, { day: 'numeric', month: 'long', year: 'numeric' })}
                  {event.startsAt.length > 10 && ` · ${localTime(event.startsAt)}`} ·{' '}
                  {event.venue || 'Lokacija nije navedena'}
                </p>
                {safeLink(event.sources[0]?.url) && (
                  <a
                    className="inline-source"
                    href={safeLink(event.sources[0]?.url)!}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {event.sources[0].sourceName}
                    <Arrow diagonal />
                  </a>
                )}
              </div>
              <div className="admin-actions">
                <button
                  className="button button-outline button-small"
                  disabled={busy}
                  onClick={() => onEdit(event)}
                >
                  Uredi
                </button>
                {event.publication !== 'published' ? (
                  <button
                    className="button button-dark button-small"
                    disabled={busy}
                    onClick={() =>
                      void act(
                        `/api/admin/events/${encodeURIComponent(event.id)}`,
                        'PATCH',
                        { publication: 'published' },
                        'Događaj je objavljen.',
                      )
                    }
                  >
                    Objavi
                  </button>
                ) : (
                  <button
                    className="text-button"
                    disabled={busy}
                    onClick={() =>
                      void act(
                        `/api/admin/events/${encodeURIComponent(event.id)}`,
                        'PATCH',
                        { publication: 'draft' },
                        'Događaj je povučen u nacrte.',
                      )
                    }
                  >
                    Povuci objavu
                  </button>
                )}
                {event.publication !== 'rejected' && (
                  <button
                    className="text-button danger"
                    disabled={busy}
                    onClick={() =>
                      void act(
                        `/api/admin/events/${encodeURIComponent(event.id)}`,
                        'PATCH',
                        { publication: 'rejected' },
                        'Događaj je odbijen.',
                      )
                    }
                  >
                    Odbij
                  </button>
                )}
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}

function Sources({
  dashboard,
  busy,
  act,
}: {
  dashboard: AdminDashboard;
  busy: boolean;
  act: Action;
}) {
  const runNames = {
    running: 'Dohvat u tijeku',
    success: 'Uspješno',
    partial: 'Djelomično',
    error: 'Greška',
  };
  return (
    <section aria-labelledby="sources-title">
      <div className="admin-section-header">
        <div>
          <h2 id="sources-title">Gradski radar.</h2>
          <p>Stvarni izvori, zadnji dohvat i što je pošlo po planu.</p>
          <p>
            Broj pronađenih i preskočenih zapisa uključuje i prošle događaje. Javni pregled
            prikazuje samo nadolazeće.
          </p>
        </div>
        <button
          className="button button-dark"
          disabled={busy || dashboard.collecting}
          onClick={() =>
            void act(
              '/api/admin/collect',
              'POST',
              undefined,
              'Dohvat je pokrenut. Rezultati se osvježavaju dok je aktivan.',
            )
          }
        >
          {dashboard.collecting ? (
            <Spinner label="Prikupljanje…" />
          ) : (
            <>
              Dohvati sada <Arrow />
            </>
          )}
        </button>
      </div>
      <div className="settings-panel">
        <div>
          <h3>Automatski objavi prikupljene događaje</h3>
          <p>
            Nove događaje iz poznatih izvora objavi odmah. Isključi za urednički pregled svakog
            novog događaja. AI prijedlozi iz dojava uvijek čekaju pregled.
          </p>
        </div>
        <label className="toggle">
          <input
            type="checkbox"
            checked={dashboard.autoPublish}
            disabled={busy}
            onChange={(event) =>
              void act(
                '/api/admin/settings',
                'PATCH',
                { autoPublish: event.target.checked },
                event.target.checked
                  ? 'Automatska objava je uključena.'
                  : 'Automatska objava je isključena. Novi događaji čekaju pregled.',
              )
            }
            aria-label="Automatska objava prikupljenih događaja"
          />
          <span className="toggle-track" aria-hidden="true" />
          <span>{dashboard.autoPublish ? 'Uključeno' : 'Isključeno'}</span>
        </label>
      </div>
      <div className="ai-panel">
        <span className={`admin-badge ${dashboard.ai.enabled ? 'badge-published' : 'badge-draft'}`}>
          {dashboard.ai.enabled ? 'AI aktivan' : 'AI nije aktivan'}
        </span>
        <p>{dashboard.ai.description}</p>
      </div>
      <div className="source-grid">
        {dashboard.sources.map((source) => (
          <article className="source-card" key={source.id}>
            <div className="admin-row-top">
              <span className={`admin-badge badge-${source.latestRun?.status ?? 'draft'}`}>
                {source.latestRun ? runNames[source.latestRun.status] : 'Još nije dohvaćeno'}
              </span>
              <span>{source.enabled ? 'Aktivan izvor' : 'Isključen izvor'}</span>
            </div>
            <h3>{source.name}</h3>
            <p>{source.description}</p>
            {safeLink(source.url) && (
              <a
                className="inline-source"
                href={safeLink(source.url)!}
                target="_blank"
                rel="noopener noreferrer"
              >
                Otvori izvor <Arrow diagonal />
              </a>
            )}
            <dl className="source-stats">
              <div>
                <dt>Događaja u bazi</dt>
                <dd>{source.eventCount}</dd>
              </div>
              <div>
                <dt>Zadnji dohvat: pronađeno</dt>
                <dd>{source.latestRun?.discovered ?? '—'}</dd>
              </div>
              <div>
                <dt>Spremljeno / ažurirano</dt>
                <dd>{source.latestRun?.imported ?? '—'}</dd>
              </div>
              <div>
                <dt>Preskočeno</dt>
                <dd>{source.latestRun?.skipped ?? '—'}</dd>
              </div>
            </dl>
            <p className="fine-print">
              Zadnji uspješan dohvat:{' '}
              {source.lastSuccessAt
                ? dateFormat(source.lastSuccessAt, {
                    day: 'numeric',
                    month: 'numeric',
                    year: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit',
                  })
                : 'Još nema uspješnog dohvata'}
            </p>
            {source.latestRun && (
              <p className="fine-print">
                Zadnji pokušaj:{' '}
                {dateFormat(source.latestRun.startedAt, {
                  day: 'numeric',
                  month: 'numeric',
                  hour: '2-digit',
                  minute: '2-digit',
                })}{' '}
                · {source.latestRun.pagesFetched} stranica
              </p>
            )}
            {Boolean(source.latestRun?.warnings.length) && (
              <details className="source-warnings" open={source.latestRun?.status === 'error'}>
                <summary>Napomene dohvata ({source.latestRun!.warnings.length})</summary>
                <ul>
                  {source.latestRun!.warnings.map((warning, index) => (
                    <li key={index}>{warning}</li>
                  ))}
                </ul>
              </details>
            )}
          </article>
        ))}
      </div>
      {!dashboard.sources.length && (
        <AdminEmpty
          title="Izvori još nisu postavljeni."
          text="Povezani izvori prikazat će se ovdje."
        />
      )}
    </section>
  );
}

function AdminEmpty({ title, text }: { title: string; text: string }) {
  return (
    <div className="admin-empty">
      <span aria-hidden="true">↗</span>
      <h3>{title}</h3>
      <p>{text}</p>
    </div>
  );
}

function DraftEditor({
  title,
  initial,
  tip,
  busy,
  error,
  stale = false,
  onReload,
  onClose,
  onSubmit,
}: {
  title: string;
  initial: EventDraft;
  tip?: Tip;
  busy: boolean;
  error: string;
  stale?: boolean;
  onReload?: () => void;
  onClose: () => void;
  onSubmit: (draft: EventDraft, publish: boolean) => Promise<void>;
}) {
  const [draft, setDraft] = useState(initial),
    [day, setDay] = useState(initial.startsAt ? dayKey(initial.startsAt) : ''),
    [time, setTime] = useState(initial.startsAt ? localTime(initial.startsAt) : '');
  const [endDay, setEndDay] = useState(initial.endsAt ? dayKey(initial.endsAt) : ''),
    [endTime, setEndTime] = useState(initial.endsAt ? localTime(initial.endsAt) : ''),
    [localError, setLocalError] = useState('');
  const id = useId();
  const update = <K extends keyof EventDraft>(field: K, value: EventDraft[K]) =>
    setDraft((old) => ({ ...old, [field]: value }));
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || stale) return;
    setLocalError('');
    try {
      const publish =
        (event.nativeEvent as SubmitEvent).submitter?.getAttribute('value') === 'publish';
      if ((!tip || publish) && !event.currentTarget.reportValidity()) return;
      if (publish && !draft.venue?.trim())
        throw new Error('Za objavu je potrebno potvrđeno mjesto održavanja.');
      await onSubmit(
        {
          ...draft,
          title: draft.title.trim(),
          startsAt: day ? zonedTimestamp(day, time) : '',
          endsAt: endDay ? zonedTimestamp(endDay, endTime) : null,
          city: 'Osijek',
        },
        publish,
      );
    } catch (err) {
      setLocalError(errorText(err));
    }
  }
  return (
    <Modal title={title} eyebrow="UREĐIVANJE / OSIJEK" className="editor-modal" onClose={onClose}>
      {tip && (
        <div className="original-tip">
          <strong>Izvorna dojava</strong>
          <p>{tip.note}</p>
          {safeLink(tip.url) && (
            <a
              className="inline-source"
              href={safeLink(tip.url)!}
              target="_blank"
              rel="noopener noreferrer"
            >
              Otvori poveznicu <Arrow diagonal />
            </a>
          )}
          <p className="fine-print">
            {tip.verification === 'source_match'
              ? 'Moguće podudaranje s prikupljenim događajem. Provjeri prije prihvaćanja.'
              : 'Prijedlog nije potvrđen. Provjeri datum, lokaciju i najavu prije objave.'}
          </p>
        </div>
      )}
      {stale && (
        <div className="editor-conflict" role="alert">
          <p>
            Dojava je u međuvremenu promijenjena. Tvoj unos ostaje u obrascu. Prije spremanja učitaj
            najnoviji prijedlog; to će zamijeniti ovaj unos.
          </p>
          <button type="button" className="button button-outline button-small" onClick={onReload}>
            Učitaj najnoviji prijedlog
          </button>
        </div>
      )}
      <form onSubmit={submit} className="draft-form">
        <div className="form-grid">
          <div className="field field-full">
            <label htmlFor={`${id}-title`}>Naziv događaja</label>
            <input
              id={`${id}-title`}
              autoFocus
              required
              maxLength={300}
              value={draft.title}
              onChange={(event) => update('title', event.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor={`${id}-date`}>Datum početka</label>
            <input
              id={`${id}-date`}
              type="date"
              required
              value={day}
              onChange={(event) => setDay(event.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor={`${id}-time`}>
              Vrijeme <span>ako je poznato</span>
            </label>
            <input
              id={`${id}-time`}
              type="time"
              value={time}
              onChange={(event) => setTime(event.target.value)}
            />
          </div>
          <p className="field-full fine-print">
            Svi datumi i vremena su za Osijek (Europe/Zagreb). Nepoznato vrijeme ostavi prazno.
            {tip &&
              ' Prijedlog možeš spremiti bez naziva ili datuma; objava traži potvrđene podatke.'}
          </p>
          <div className="field">
            <label htmlFor={`${id}-end-date`}>
              Datum završetka <span>neobavezno</span>
            </label>
            <input
              id={`${id}-end-date`}
              type="date"
              min={day || undefined}
              value={endDay}
              onChange={(event) => setEndDay(event.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor={`${id}-end-time`}>Vrijeme završetka</label>
            <input
              id={`${id}-end-time`}
              type="time"
              disabled={!endDay}
              value={endTime}
              onChange={(event) => setEndTime(event.target.value)}
            />
          </div>
          <div className="field">
            <label htmlFor={`${id}-venue`}>Mjesto održavanja</label>
            <input
              id={`${id}-venue`}
              maxLength={300}
              value={draft.venue ?? ''}
              onChange={(event) => update('venue', event.target.value || null)}
            />
          </div>
          <div className="field">
            <label htmlFor={`${id}-address`}>
              Adresa <span>neobavezno</span>
            </label>
            <input
              id={`${id}-address`}
              maxLength={500}
              value={draft.address ?? ''}
              onChange={(event) => update('address', event.target.value || null)}
            />
          </div>
          <div className="field">
            <label htmlFor={`${id}-category`}>Kategorija</label>
            <select
              id={`${id}-category`}
              value={draft.category}
              onChange={(event) => update('category', event.target.value as EventDraft['category'])}
            >
              {categories.map((category) => (
                <option key={category} value={category}>
                  {categoryNames[category]}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label htmlFor={`${id}-status`}>Status događaja</label>
            <select
              id={`${id}-status`}
              value={draft.status}
              onChange={(event) => update('status', event.target.value as EventDraft['status'])}
            >
              <option value="scheduled">Najavljen</option>
              <option value="cancelled">Otkazan</option>
              <option value="postponed">Odgođen</option>
            </select>
          </div>
          <div className="field">
            <label htmlFor={`${id}-price`}>
              Cijena <span>ako je poznata</span>
            </label>
            <input
              id={`${id}-price`}
              maxLength={300}
              placeholder="Npr. 10 € ili besplatno"
              value={draft.price ?? ''}
              onChange={(event) => update('price', event.target.value || null)}
            />
          </div>
          <div className="field">
            <label htmlFor={`${id}-source`}>Izvorna poveznica</label>
            <input
              id={`${id}-source`}
              type="url"
              maxLength={2048}
              placeholder="https://…"
              value={draft.sourceUrl ?? ''}
              onChange={(event) => update('sourceUrl', event.target.value || null)}
            />
          </div>
          <div className="field field-full">
            <label htmlFor={`${id}-description`}>Opis</label>
            <textarea
              id={`${id}-description`}
              rows={4}
              maxLength={5000}
              value={draft.description}
              onChange={(event) => update('description', event.target.value)}
            />
          </div>
        </div>
        {(error || localError) && <Message error>{localError || error}</Message>}
        <div className="editor-actions">
          <button
            type="submit"
            value="save"
            formNoValidate={Boolean(tip)}
            className={`button ${tip ? 'button-outline' : 'button-dark'}`}
            disabled={busy || stale}
          >
            {busy ? 'Spremanje…' : tip ? 'Spremi prijedlog' : 'Spremi promjene'}
          </button>
          {tip && (
            <button
              type="submit"
              value="publish"
              className="button button-dark"
              disabled={busy || stale}
            >
              {busy ? 'Spremanje…' : 'Prihvati i objavi'} <Arrow diagonal />
            </button>
          )}
        </div>
      </form>
    </Modal>
  );
}
