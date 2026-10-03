import type { Category } from '../shared/types';

/** Category illustrations, not photos or another set of controls. */
export function EventArt({ category }: { category: Category }) {
  return (
    <svg className="event-art" viewBox="0 0 320 108" fill="none" aria-hidden="true">
      <g stroke="currentColor" strokeWidth="1" opacity=".15">
        <path d="M0 27h320M0 54h320M0 81h320M40 0v108M80 0v108M120 0v108M160 0v108M200 0v108M240 0v108M280 0v108" />
      </g>
      <g stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
        {category === 'music' || category === 'nightlife' ? (
          <>
            <circle cx="227" cy="54" r="40" fill="currentColor" fillOpacity=".08" />
            <circle cx="227" cy="54" r="29" opacity=".5" />
            <circle cx="227" cy="54" r="18" opacity=".5" />
            <circle cx="227" cy="54" r="6" fill="currentColor" />
            <path
              d="M55 45v18m12-29v40m12-51v62m12-51v40m12-53v66m12-51v36m12-24v12"
              strokeWidth="5"
            />
            <path d="m281 18 8-8m-2 30h12m-18 50 8 8" opacity=".5" />
          </>
        ) : category === 'theatre' || category === 'culture' ? (
          <>
            <path
              d="M49 84V48a30 30 0 0 1 60 0v36M60 84V48a19 19 0 0 1 38 0v36M38 86h82"
              opacity=".65"
            />
            <path
              d="m175 19 55 7-5 37c-2 18-19 25-27 26-8-4-20-15-18-33Z"
              fill="currentColor"
              fillOpacity=".06"
            />
            <path d="m189 41 9 1m15 2 9 1m-31 18q11 12 23 2" />
            <path
              d="m232 36 41-10 8 34c4 16-7 29-15 35-11-1-23-7-27-20"
              fill="currentColor"
              fillOpacity=".1"
            />
            <path d="m245 50 6-2m13-3 6-2m-16 31q7-8 16-4" />
          </>
        ) : category === 'sport' ? (
          <>
            <circle cx="225" cy="54" r="39" fill="currentColor" fillOpacity=".08" />
            <path d="M186 54h78m-39-39v78m-27-67q38 28 0 56m54-56q-38 28 0 56M45 36h70M35 54h88M55 72h60" />
          </>
        ) : category === 'community' ? (
          <>
            <circle cx="204" cy="35" r="13" />
            <circle cx="248" cy="41" r="11" />
            <path d="M179 87V76c0-17 10-25 25-25s25 8 25 25v11m6-26c15-5 32 4 32 21v5" />
            <path d="M45 79h27V55h26V31h27m-10-10 10 10-10 10" />
            <circle cx="48" cy="35" r="6" fill="currentColor" fillOpacity=".12" />
          </>
        ) : (
          <>
            <path
              d="m222 13 10 27 28 1-22 17 8 28-24-16-24 16 8-28-22-17 28-1Z"
              fill="currentColor"
              fillOpacity=".08"
            />
            <path d="M45 36h65M45 54h45M45 72h55" />
          </>
        )}
      </g>
    </svg>
  );
}
