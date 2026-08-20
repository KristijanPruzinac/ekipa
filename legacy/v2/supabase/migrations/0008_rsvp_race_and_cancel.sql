-- v2 alignment, part 3 — a race-free RSVP trigger and a way out after yes.
--
-- Two gaps in handle_rsvp_change (0002):
--
--   1. Lost update. Two members saying yes at the same instant each counted
--      the yeses before the other committed, so neither saw a full house and
--      the meetup never flipped to confirmed. Serialize the transitions for a
--      given meetup by taking a row lock on the meetups row first; the second
--      trigger then waits and re-reads the committed truth.
--
--   2. No exit after confirmation. Life happens. A confirmed member must be
--      able to withdraw — but one person changing their mind can't punish the
--      rest, so the meetup stands unless withdrawal would drop it below two.

create or replace function handle_rsvp_change() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  cur_status text;
  total int;
  yes_count int;
begin
  -- Serialize all RSVP-driven transitions for this meetup. Concurrent triggers
  -- for the same meetup queue here instead of racing the count below.
  select status into cur_status from meetups where id = new.meetup_id for update;

  if new.rsvp = 'no' then
    if cur_status in ('proposed', 'forming') then
      -- Before a group forms, a single no dissolves the proposal quietly.
      update meetups set status = 'cancelled' where id = new.meetup_id;
    elsif cur_status = 'confirmed' then
      -- After confirmation the meetup holds for everyone else — unless the
      -- withdrawal leaves fewer than two people, at which point it's no longer
      -- a meetup and cancels for all.
      select count(*) filter (where rsvp = 'yes') into yes_count
        from meetup_members where meetup_id = new.meetup_id;
      if yes_count < 2 then
        update meetups set status = 'cancelled' where id = new.meetup_id;
      end if;
    end if;
    return new;
  end if;

  if new.rsvp = 'yes' then
    select count(*), count(*) filter (where rsvp = 'yes')
      into total, yes_count
      from meetup_members
      where meetup_id = new.meetup_id;

    if yes_count = total then
      update meetups set status = 'confirmed'
        where id = new.meetup_id and status in ('proposed', 'forming');
    else
      update meetups set status = 'forming'
        where id = new.meetup_id and status = 'proposed';
    end if;
  end if;

  return new;
end;
$$;
