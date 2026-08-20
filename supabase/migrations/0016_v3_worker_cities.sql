-- 0016 · Which cities the nightly pass should match.
--
-- **The gap.** `mill match` took a `--city` and refused without one, so the
-- scheduled job would have had to name Osijek in a workflow file. That makes
-- launching a second city a code change plus a deploy, and the whole of D11 is
-- the claim that it should be a row.
--
-- **Active, and only active.** A city with a map and no members is not open
-- (see `tools/cartography/add_city.py`, which writes `active = false` on
-- purpose). Matching one would build groups nobody asked for and then cancel
-- them at the confirmation deadline, which costs real people a notification and
-- an infraction each. The flag is the switch, and this is where it is read.
--
-- **`horizon_days` travels with the city.** How far ahead to match is a
-- behavioural constant, so it is a config key rather than a literal (D5) — but
-- it is scoped per city, because a dense city can plan three days out and a
-- thin one needs a week to accumulate enough people for a group. Reading it
-- here means one round trip decides both which cities and how far, instead of
-- the worker asking about config once per city.
create or replace function public.worker_cities()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  -- Service-role only. The check is here and not merely in the grant, because
  -- a grant is a line somebody can add and a raised exception is one they have
  -- to mean (DP-5).
  if auth.role() is distinct from 'service_role' then
    raise exception 'worker only' using errcode = '42501';
  end if;

  return coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'name', c.name,
          'timezone', c.timezone,
          -- The count is here so the run log can say "matched 0 of 3 in
          -- Osijek" and somebody can tell a thin week from a broken worker.
          -- It is an operational number about a city, not about a person, and
          -- it never reaches a client.
          'people', (
            select count(*)
            from public.people p
            where p.city_id = c.id and p.deleted_at is null
          )
        )
        order by c.name
      )
      from public.cities c
      where c.active
    ),
    '[]'::jsonb
  );
end;
$$;

revoke all on function public.worker_cities() from public, anon, authenticated;
grant execute on function public.worker_cities() to service_role;
