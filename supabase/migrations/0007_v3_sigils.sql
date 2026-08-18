-- 0007 · The sigil set.
--
-- 24 symbols × 6 colours = 144 combinations, against a venue that will never
-- hold more than a handful of groups at once (05_PLACES.md §8). The surplus is
-- the point: collision avoidance is a uniqueness constraint, and a constraint
-- with a tight domain fails by refusing to allocate.
--
-- **Codes, not glyphs and not hex.** `symbol` is `'circle'`, never an emoji;
-- `colour` is `'red'`, never `#E5715F`. The reveal screen is the one screen the
-- product has to carry, and it renders drawn marks from the design system, not
-- whatever the platform's emoji font decided a circle looks like this year.
-- Keeping the palette out of the database also keeps it in exactly one place —
-- `ZarColours` — which is the same reason `DisplayName` owns the name mask.
--
-- The labels exist so the sigil can be **said out loud**: "we're the red
-- circle" is how four strangers find each other when one of them has a dead
-- phone. That is also why Croatian adjectives are declined per symbol rather
-- than concatenated: `crvena zvijezda`, `crveno sunce`, `crveni krug`. A
-- product that gets the grammar wrong on its most-read screen reads as
-- machine-made, and this one is asking people to trust it with an evening.

insert into public.sigils (symbol, colour, label_hr, label_en)
select
  symbol.code,
  colour.code,
  case symbol.gender
    when 'm' then colour.hr_m
    when 'f' then colour.hr_f
    else colour.hr_n
  end || ' ' || symbol.hr,
  colour.en || ' ' || symbol.en
from (values
  -- Geometry first: unmistakable at a glance, unmistakable when described.
  ('circle',   'm', 'krug',     'circle'),
  ('square',   'm', 'kvadrat',  'square'),
  ('triangle', 'm', 'trokut',   'triangle'),
  ('diamond',  'm', 'romb',     'diamond'),
  ('star',     'f', 'zvijezda', 'star'),
  ('heart',    'n', 'srce',     'heart'),
  -- Sky and weather.
  ('sun',      'n', 'sunce',    'sun'),
  ('moon',     'm', 'mjesec',   'moon'),
  ('cloud',    'm', 'oblak',    'cloud'),
  ('bolt',     'f', 'munja',    'bolt'),
  ('drop',     'f', 'kap',      'drop'),
  ('wave',     'm', 'val',      'wave'),
  -- Growing things.
  ('leaf',     'm', 'list',     'leaf'),
  ('flower',   'm', 'cvijet',   'flower'),
  ('tree',     'n', 'drvo',     'tree'),
  ('mountain', 'f', 'planina',  'mountain'),
  ('feather',  'n', 'pero',     'feather'),
  ('shell',    'f', 'školjka',  'shell'),
  -- Objects, all of them things a six-year-old could draw from memory.
  ('key',      'm', 'ključ',    'key'),
  ('anchor',   'n', 'sidro',    'anchor'),
  ('bell',     'n', 'zvono',    'bell'),
  ('arrow',    'f', 'strelica', 'arrow'),
  ('flame',    'm', 'plamen',   'flame'),
  ('bird',     'f', 'ptica',    'bird')
) as symbol (code, gender, hr, en)
cross join (values
  ('red',    'crveni',     'crvena',     'crveno',     'red'),
  ('orange', 'narančasti', 'narančasta', 'narančasto', 'orange'),
  ('yellow', 'žuti',       'žuta',       'žuto',       'yellow'),
  ('green',  'zeleni',     'zelena',     'zeleno',     'green'),
  ('blue',   'plavi',      'plava',      'plavo',      'blue'),
  ('purple', 'ljubičasti', 'ljubičasta', 'ljubičasto', 'purple')
) as colour (code, hr_m, hr_f, hr_n, en);

-- No client policy, deliberately. A sigil is only ever seen through
-- `hangout_reveal`, which is `security definer` and therefore reads this table
-- regardless. Publishing the catalogue would tell an observer nothing useful,
-- but it would also buy nothing, and DP-2's default is deny.
