-- Ekipa — automatic meetup status transitions on RSVP.
--
-- 0001_init.sql lets a member write only their own `meetup_members.rsvp`
-- (members_update_own) and never the meetup's `status` directly — a client
-- must not be able to mark its own meetup confirmed. Something still has to
-- flip proposed -> forming -> confirmed as yeses come in, and proposed ->
-- cancelled the instant anyone says no (a decline this population can't
-- structurally afford to negotiate around in groups this small: per
-- docs/PLAN.md, "the proposal simply doesn't form"). That's this trigger.

create function handle_rsvp_change() returns trigger
  language plpgsql security definer set search_path = public as $$
declare
  total int;
  yes_count int;
begin
  if new.rsvp = 'no' then
    update meetups set status = 'cancelled'
      where id = new.meetup_id and status in ('proposed', 'forming');
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

create trigger on_rsvp_change
  after update of rsvp on meetup_members
  for each row execute function handle_rsvp_change();
