import { useEffect, useId, useRef, type ReactNode } from 'react';

let modalSequence = 0;
let pendingModalBack: Promise<void> | null = null;

export function Arrow({ diagonal = false }: { diagonal?: boolean }) {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        d={diagonal ? 'M6 18 18 6M6 6h12v12' : 'M4 12h16m-6-6 6 6-6 6'}
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}
export function Pin() {
  return (
    <svg width="16" height="18" viewBox="0 0 20 22" fill="none" aria-hidden="true">
      <path
        d="M17 8.5c0 5-7 11-7 11s-7-6-7-11a7 7 0 1 1 14 0Z"
        stroke="currentColor"
        strokeWidth="1.6"
      />
      <circle cx="10" cy="8" r="2.3" stroke="currentColor" strokeWidth="1.6" />
    </svg>
  );
}
export function SearchIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <circle cx="10.5" cy="10.5" r="6.5" stroke="currentColor" strokeWidth="1.7" />
      <path d="m16 16 4.5 4.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}
export function Spark({ className = '' }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 100 100" fill="none" aria-hidden="true">
      <path
        d="M50 0 57 30 78 8 71 37 100 28 79 50 100 72 71 63 78 92 57 70 50 100 43 70 22 92 29 63 0 72 21 50 0 28 29 37 22 8 43 30Z"
        fill="currentColor"
      />
    </svg>
  );
}
export function Brand({ small = false }: { small?: boolean }) {
  return (
    <a className={`brand ${small ? 'brand-small' : ''}`} href="/" aria-label="WagZ — početna">
      <span className="wordmark">
        WagZ
        <span className="brand-dot" aria-hidden="true">
          ✳
        </span>
      </span>
      <span className="brand-caption">WE ARE GEN Z</span>
    </a>
  );
}
export function Modal({
  title,
  children,
  onClose,
  className = '',
  eyebrow,
}: {
  title: string;
  children: ReactNode;
  onClose: () => void;
  className?: string;
  eyebrow?: string;
}) {
  const ref = useRef<HTMLDialogElement>(null),
    titleId = useId();
  const close = useRef(onClose);
  close.current = onClose;
  useEffect(() => {
    const dialog = ref.current!,
      previous = document.activeElement as HTMLElement | null;
    const id = ++modalSequence;
    const openedUrl = window.location.href;
    let previousState: unknown;
    let historyReady = false;
    let disposed = false;
    const restoreFocus = () => {
      if (previous?.isConnected && !document.querySelector('dialog[open]'))
        previous.focus({ preventScroll: true });
    };
    let navigatedBack = false;
    const onPopState = () => {
      if (window.history.state?.wagzModal?.id !== id) {
        navigatedBack = true;
        close.current();
      }
    };
    const claimHistory = () => {
      if (disposed) return;
      if (window.location.href !== openedUrl) {
        close.current();
        return;
      }
      const existing = window.history.state?.wagzModal;
      previousState = existing ? existing.previous : window.history.state;
      const modalState = {
        ...(previousState && typeof previousState === 'object' ? previousState : {}),
        wagzModal: { id, previous: previousState },
      };
      // Remounting an editor or replaying StrictMode reuses one visible entry.
      if (existing) window.history.replaceState(modalState, '');
      else window.history.pushState(modalState, '');
      historyReady = true;
      window.addEventListener('popstate', onPopState);
    };
    // A previous dialog may have closed just before this one opened. Let its
    // navigation finish before this dialog creates an entry or handles Back.
    if (pendingModalBack) void pendingModalBack.then(claimHistory);
    else claimHistory();
    dialog.showModal();
    const oldOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      disposed = true;
      window.removeEventListener('popstate', onPopState);
      dialog.close();
      document.body.style.overflow = oldOverflow;
      restoreFocus();
      // Wait until a replacement dialog can claim the entry before removing it.
      queueMicrotask(() => {
        if (
          historyReady &&
          !navigatedBack &&
          window.location.href === openedUrl &&
          window.history.state?.wagzModal?.id === id
        ) {
          window.history.replaceState(previousState, '');
          pendingModalBack = new Promise<void>((resolve) => {
            window.addEventListener(
              'popstate',
              () => {
                // Finish browser restoration before a waiting dialog pushes again.
                window.setTimeout(() => {
                  pendingModalBack = null;
                  restoreFocus();
                  resolve();
                }, 0);
              },
              { once: true },
            );
          });
          window.history.back();
        } else if (navigatedBack) {
          requestAnimationFrame(restoreFocus);
        }
      });
    };
  }, []);
  return (
    <dialog
      ref={ref}
      className={`modal ${className}`}
      aria-labelledby={titleId}
      onCancel={(event) => {
        event.preventDefault();
        onClose();
      }}
      onClick={(event) => {
        if (event.target === ref.current) {
          const rect = ref.current.getBoundingClientRect();
          if (
            event.clientX < rect.left ||
            event.clientX > rect.right ||
            event.clientY < rect.top ||
            event.clientY > rect.bottom
          )
            onClose();
        }
      }}
    >
      <div className="modal-close-rail">
        <button className="close-button" aria-label="Zatvori" onClick={onClose}>
          <span aria-hidden="true">×</span>
        </button>
      </div>
      <div className="modal-content">
        {eyebrow && <p className="eyebrow">{eyebrow}</p>}
        <h2 id={titleId}>{title}</h2>
        {children}
      </div>
    </dialog>
  );
}
export function Message({ children, error = false }: { children: ReactNode; error?: boolean }) {
  return (
    <div className={`message ${error ? 'message-error' : ''}`} role={error ? 'alert' : 'status'}>
      {children}
    </div>
  );
}
export function Spinner({ label = 'Učitavanje…' }: { label?: string }) {
  return (
    <span className="loading-line" role="status">
      <span className="spinner" aria-hidden="true" />
      {label}
    </span>
  );
}
