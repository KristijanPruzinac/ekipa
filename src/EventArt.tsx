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
        ) : category === 'dance' ? (
          <g data-motif="dance">
            <path d="M209 0v18" />
            <circle cx="209" cy="54" r="36" fill="currentColor" fillOpacity=".04" />
            <path
              d="M191 38q9 3 18 3v20q-12 0-21-3 0-11 3-20Zm18 23q12 0 21-3-1 13-7 24-7 3-14 3Z"
              fill="currentColor"
              fillOpacity=".13"
              stroke="none"
            />
            <g strokeWidth="1.6" opacity=".8">
              <path d="M209 18c-27 17-27 55 0 72m0-72c27 17 27 55 0 72m0-72v72" />
              <path d="M181 32q28 16 56 0m-64 22q36 14 72 0m-63 23q27 15 54 0" />
            </g>
            <path
              d="M82 28q4 20 23 24-19 4-23 24-4-20-23-24 19-4 23-24Z"
              fill="currentColor"
              fillOpacity=".06"
            />
            <path d="M127 19v14m-7-7h14m129 49v14m-7-7h14" />
            <path d="m122 82 7-3m129-56 7 4" opacity=".5" />
          </g>
        ) : category === 'workshop' ? (
          <g data-motif="workshop">
            <path d="m53 78 27-54 10 5-27 54-14 9Zm22-45 10 5M53 78l10 5" />
            <circle cx="123" cy="77" r="10" />
            <circle cx="148" cy="83" r="10" />
            <path d="m127 68 27-41-9 45m-5 4-20-52 20 29" />
            <circle cx="138" cy="59" r="2" fill="currentColor" />
            <path d="m199 24 43-5 21 17 6 46-62 8Zm43-5 2 20 19-3" />
            <path d="m216 53 29-4m-27 17 20-3" opacity=".55" />
          </g>
        ) : category === 'film' ? (
          <g data-motif="film">
            <path
              d="m48 40 78-16 4 20-78 16Zm7 19h77v33H55Z"
              fill="currentColor"
              fillOpacity=".06"
            />
            <path d="m59 38 11 18m11-23 11 18m11-23 11 18M66 73h45m-45 9h26" />
            <circle cx="226" cy="53" r="37" fill="currentColor" fillOpacity=".06" />
            <circle cx="226" cy="53" r="5" />
            <circle cx="226" cy="30" r="9" />
            <circle cx="249" cy="53" r="9" />
            <circle cx="226" cy="76" r="9" />
            <circle cx="203" cy="53" r="9" />
            <path d="M226 90h38q19 0 19-17" opacity=".6" />
          </g>
        ) : category === 'literature' ? (
          <g data-motif="literature">
            <path
              d="M174 30q23-13 46 0 23-13 46 0v59q-23-13-46 0-23-13-46 0Z"
              fill="currentColor"
              fillOpacity=".06"
            />
            <path d="M220 30v59m-36-45q13-5 26 0m-26 13q13-5 26 0m-26 13q13-5 26 0m20-26q13-5 26 0m-26 13q13-5 26 0m-26 13q13-5 26 0" />
            <path d="M55 32h61v17H55Zm-6 18h73v17H49Zm9 18h62v17H58ZM66 37v7m43 11v7M68 73v7" />
            <path d="m246 27 7-11m19 19 12-4" opacity=".5" />
          </g>
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
