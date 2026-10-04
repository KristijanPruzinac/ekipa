import { ticket, ticketLabel } from '../shared/day-strip';
import type { PublicEvent } from '../shared/types';

/** Train-ticket strip: one stub per day, perforated joins, daily hours printed once below. */
export function DayStrip({ event }: { event: PublicEvent }) {
  const { stubs, daily } = ticket(event);
  return (
    <>
      <span className="sr-only">{ticketLabel(event)}</span>
      <ol className="ticket" aria-hidden="true">
        {stubs.map((stub, index) => (
          <li key={index} className={`stub stub-${stub.tone}`}>
            {index > 0 && <i className="stub-notch" aria-hidden="true" />}
            {stub.big && (
              <strong className={stub.unknown ? 'stub-unknown' : undefined}>{stub.big}</strong>
            )}
            <small>{stub.small}</small>
          </li>
        ))}
      </ol>
      {daily && (
        <p className="ticket-daily" aria-hidden="true">
          svaki dan <strong>{daily}</strong>
        </p>
      )}
    </>
  );
}
