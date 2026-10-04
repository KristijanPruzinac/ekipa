import { ticket } from '../shared/day-strip';
import type { PublicEvent } from '../shared/types';

/** Train-ticket strip: one stub per day, perforated joins, daily hours printed once below. */
export function DayStrip({ event }: { event: PublicEvent }) {
  const { stubs, daily } = ticket(event);
  return (
    <>
      <ol className="ticket">
        {stubs.map((stub, index) => (
          <li key={index} className={`stub stub-${stub.tone}`}>
            {index > 0 && <span className="stub-notch" aria-hidden="true" />}
            {stub.big && <strong>{stub.big}</strong>}
            <small>{stub.small}</small>
          </li>
        ))}
      </ol>
      {daily && (
        <p className="ticket-daily">
          svaki dan <strong>{daily}</strong>
        </p>
      )}
    </>
  );
}
