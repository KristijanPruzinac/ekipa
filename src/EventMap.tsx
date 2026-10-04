import type { PublicEvent } from '../shared/types';

/** Public CARTO basemaps key: it ships in tile URLs by design (free tier, 5M tiles/month). */
const CARTO_KEY = 'cb1_492f_1_cd5193653de49fdecc16a91a';

const ZOOM = 16;
const TILE = 256;

/** Minimal static map: light CARTO tiles around the venue with a lime pin (no map library). */
export function EventMap({ event }: { event: PublicEvent }) {
  if (!event.location) return null;
  const { lat, lon } = event.location;
  const scale = 2 ** ZOOM;
  const x = ((lon + 180) / 360) * scale;
  const latRad = (lat * Math.PI) / 180;
  const y = ((1 - Math.log(Math.tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2) * scale;
  const tileX = Math.floor(x),
    tileY = Math.floor(y);
  const offsetX = (x - tileX) * TILE,
    offsetY = (y - tileY) * TILE;
  const tiles: Array<{ dx: number; dy: number }> = [];
  for (let dy = -1; dy <= 1; dy++) for (let dx = -2; dx <= 2; dx++) tiles.push({ dx, dy });
  const maps = `https://www.google.com/maps/search/?api=1&query=${lat},${lon}`;
  return (
    <figure className="event-map">
      <a
        className="event-map-frame"
        href={maps}
        target="_blank"
        rel="noopener noreferrer"
        aria-label={`Otvori ${event.venue ?? 'lokaciju'} u kartama`}
      >
        {tiles.map(({ dx, dy }) => (
          <img
            key={`${dx}:${dy}`}
            alt=""
            loading="lazy"
            draggable={false}
            src={`https://${'abcd'[(tileX + dx + tileY + dy + 4) % 4]}.basemaps.cartocdn.com/light_all/${ZOOM}/${tileX + dx}/${tileY + dy}.png?key=${CARTO_KEY}`}
            style={{
              left: `calc(50% - ${offsetX}px + ${dx * TILE}px)`,
              top: `calc(50% - ${offsetY}px + ${dy * TILE}px)`,
            }}
          />
        ))}
        <span className="event-map-pin" aria-hidden="true" />
      </a>
      <figcaption>
        <a href={maps} target="_blank" rel="noopener noreferrer">
          Otvori u kartama
        </a>
        <span>
          ©{' '}
          <a
            href="https://www.openstreetmap.org/copyright"
            target="_blank"
            rel="noopener noreferrer"
          >
            OpenStreetMap
          </a>{' '}
          ·{' '}
          <a href="https://carto.com/attributions" target="_blank" rel="noopener noreferrer">
            CARTO
          </a>
        </span>
      </figcaption>
    </figure>
  );
}
