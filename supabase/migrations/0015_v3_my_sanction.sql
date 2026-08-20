-- 0015 · What a sanctioned person is told, decided on the server.
--
-- **The gap.** `sanctions` stores `reason_code`, `kind`, `ladder_step`,
-- `ends_at`, `appealed_at` and `overturned_at`. The screen needs a sentence, an
-- end date, and whether there is any point tapping "appeal". None of those
-- three is a column, and all three are decisions:
--
--   * **The sentence.** A code rendered to a person is not an explanation, and
--     assembling one in the client would put the product's most-reread copy in
--     a place that needs an app release to fix — in two languages, in two
--     clients, drifting.
--   * **Appealability.** Whether a sanction can be appealed depends on its
--     rung, on whether it has already been appealed, and on whether it has
--     already been overturned. That is a trust rule, and `11_SECURITY.md`
--     rule 6 says a trust rule the UI acts on has to be one the server also
--     refuses on. A client that decided it would show an appeal button to
--     somebody the appeal endpoint will turn away.
--   * **Which one.** A person can hold more than one sanction. The one that
--     matters is the heaviest currently in force, not the newest — a
--     `THROTTLE` created yesterday does not supersede a `SUSPENSION` from last
--     week, and showing it instead would tell somebody they are throttled when
--     they are actually out.
--
-- **What it still refuses to say.** No count, no score, no rung number, no
-- "you are one away from". Invariant 7 keeps standing service-role only, and a
-- visible ladder position is a standing score with extra steps — it turns the
-- trust system into a game with a progress bar. The person is told what is
-- happening to them and when it ends. That is the whole of it.
--
-- **`visible` is honoured, not worked around.** A sanction can be in force and
-- deliberately unannounced while the automation watches (`04_TRUST.md`). This
-- function returns no row for those, exactly as the policy does, and the app
-- cannot tell that case apart from having nothing against them. That is the
-- intended outcome, not an oversight.

create or replace function public.my_sanction()
returns table (
  kind        text,
  reason      text,
  until       timestamptz,
  appealable  boolean
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_person uuid := public.current_person_id();
begin
  if v_person is null then
    raise exception 'no person for this session' using errcode = '42501';
  end if;

  return query
  select
    s.kind::text,
    -- One sentence per kind, in the second person, saying what is happening
    -- and never why in terms of another member. Naming what somebody else
    -- reported would identify the reporter by elimination in a group of four
    -- (invariant 6), so the reason describes the *behaviour*, never the
    -- report.
    case s.kind
      when 'THROTTLE' then
        'You are being matched less often for a while. Turn up to what you '
        || 'have said yes to and this lifts on its own.'
      when 'SEGREGATE' then
        'You are being matched with a narrower set of people for a while.'
      when 'DATING_REMOVAL' then
        'The dating layer is closed for you. Ordinary hangouts are not '
        || 'affected.'
      when 'SUSPENSION' then
        'You are suspended and will not be matched until this ends.'
      when 'BAN' then
        'Your account is closed and will not be matched again.'
      else
        'There is a restriction on your account.'
    end,
    s.ends_at,
    -- **The appeal rule, in one place.** A sanction is appealable when it is
    -- heavy enough to be worth a person's time, has not already been appealed,
    -- and has not already been overturned. A throttle is not: it lifts by
    -- itself within days, and inviting an appeal against something that
    -- expires before the appeal is read is a waste of the appellant's hope.
    (
      s.kind in ('SEGREGATE', 'DATING_REMOVAL', 'SUSPENSION', 'BAN')
      and s.appealed_at is null
      and s.overturned_at is null
    )
  from public.sanctions s
  where s.person_id = v_person
    and s.visible
    and s.overturned_at is null
    and s.starts_at <= now()
    and (s.ends_at is null or s.ends_at > now())
  -- Heaviest first, then longest-lasting. `ends_at is null` is a ban or an
  -- indefinite hold and sorts before any dated one.
  order by
    case s.kind
      when 'BAN' then 0
      when 'SUSPENSION' then 1
      when 'SEGREGATE' then 2
      when 'DATING_REMOVAL' then 3
      else 4
    end,
    s.ends_at desc nulls first
  limit 1;
end;
$$;

revoke all on function public.my_sanction() from public, anon;
grant execute on function public.my_sanction() to authenticated;
