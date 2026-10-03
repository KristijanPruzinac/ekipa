import React from 'react';
import ReactDOM from 'react-dom/client';
import { App, EventPage, PublicApp } from './App';
import type { PublicPageData } from '../shared/types';
import './styles.css';
import './discovery.css';

const root = document.getElementById('root')!;
const payload = document.getElementById('wagz-page-data');
if (payload?.textContent) {
  const page = JSON.parse(payload.textContent) as PublicPageData;
  ReactDOM.hydrateRoot(
    root,
    page.kind === 'feed' ? (
      <PublicApp initialFeed={page.feed} />
    ) : (
      <EventPage event={page.event} now={page.now} />
    ),
  );
} else {
  ReactDOM.createRoot(root).render(
    <React.StrictMode>
      <App />
    </React.StrictMode>,
  );
}
