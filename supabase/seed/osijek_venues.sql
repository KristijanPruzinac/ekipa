-- Venues and clusters for Osijek. GENERATED — do not edit.
--
-- Regenerate with:
--   python tools/cartography/build_venues.py \
--     --source <overpass.json> --city 'Osijek' \
--     --eps 300 --min-samples 3 \
--     --out C:\Users\kikom\Documents\GitHub\ekipa\supabase\seed\osijek_venues.sql
--
-- Clusters are DBSCAN over the positions, not drawn by anybody: a
-- human drawing neighbourhood boundaries is the ongoing per-city
-- labour D11 forbids, and distance is the question the matcher
-- actually asks. Venues in no cluster are kept, because discarding
-- them would quietly shrink a small city to its centre.
--
-- 246 venues, 11 clusters, 38 unclustered. Sizes: 154, 15, 3, 14, 4, 3, 3, 3, 3, 3, 3.
--
-- A lopsided first cluster is expected and is not a bug: DBSCAN
-- chains through a contiguous walkable centre, and in a city this
-- size the centre genuinely is one place people converge on. If a
-- city ever needs it split, that is an --eps decision made against
-- the console's own outcome data, not a boundary somebody draws.
--
-- Data (c) OpenStreetMap contributors, ODbL.

do $$
declare
  v_city uuid;
begin
  select id into v_city from public.cities where name = 'Osijek';
  if v_city is null then
    raise exception 'no city called Osijek';
  end if;

  -- Every id below is derived from the city and the DBSCAN label, so
  -- re-running this file updates the rows it already wrote rather than
  -- adding a second set. See `cluster_id` for why that is worth the
  -- trouble: a wipe-and-rebuild hands every cluster a new uuid on a
  -- run that changed nothing, and orphans anything that referenced
  -- one.
  --
  -- A cluster this run no longer produces is deleted, and that is a
  -- real deletion rather than a side effect of a wipe. Venues survive
  -- it (the foreign key is `on delete set null`) and every one of
  -- them is reassigned by the upserts below.
  delete from public.venue_clusters
   where city_id = v_city
     and id <> all (array[
       '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid,
       'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid,
       'aaefab4a-3a4b-5b4b-8875-f78880ba7892'::uuid,
       'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid,
       'ae6eba2f-4742-5b67-8203-ef38a19b755b'::uuid,
       '59ccf7b9-0dd3-55e5-a039-35614a7f7fa9'::uuid,
       'b2512bbf-f79d-58cf-b992-4cc2556d5591'::uuid,
       'b635fa03-e46c-5b22-99c8-750e3f781445'::uuid,
       'cb9b9bb9-a814-5c9e-b09a-c67c2680e5f7'::uuid,
       'c57ee783-66a1-5368-9e67-7731c36cec29'::uuid,
       '16f1c31e-a8b1-528b-be92-24540d54d373'::uuid]);

  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('2c06e6e3-b1ae-53c6-be24-685d2aec2d14', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.682788, 45.558849), 4326)::extensions.geography, 154)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('a7d689ed-c62b-55d1-a840-799523da2e95', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.717566, 45.555125), 4326)::extensions.geography, 15)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('aaefab4a-3a4b-5b4b-8875-f78880ba7892', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.700408, 45.549982), 4326)::extensions.geography, 3)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('c6b9404e-2e97-55f5-ac3f-c17d6484d3f3', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.691822, 45.548466), 4326)::extensions.geography, 14)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('ae6eba2f-4742-5b67-8203-ef38a19b755b', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.679717, 45.545817), 4326)::extensions.geography, 4)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('59ccf7b9-0dd3-55e5-a039-35614a7f7fa9', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.709769, 45.557529), 4326)::extensions.geography, 3)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('b2512bbf-f79d-58cf-b992-4cc2556d5591', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.656822, 45.546024), 4326)::extensions.geography, 3)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('b635fa03-e46c-5b22-99c8-750e3f781445', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.653766, 45.564686), 4326)::extensions.geography, 3)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('cb9b9bb9-a814-5c9e-b09a-c67c2680e5f7', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.705437, 45.551271), 4326)::extensions.geography, 3)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('c57ee783-66a1-5368-9e67-7731c36cec29', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.637186, 45.554926), 4326)::extensions.geography, 3)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();
  insert into public.venue_clusters (id, city_id, centroid, venue_count)
  values ('16f1c31e-a8b1-528b-be92-24540d54d373', v_city, extensions.ST_SetSRID(extensions.ST_MakePoint(18.603989, 45.571532), 4326)::extensions.geography, 3)
  on conflict (id) do update set
    centroid = excluded.centroid, venue_count = excluded.venue_count,
    computed_at = now();

  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/287625300', 'Waldinger Caffe', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.675787, 45.558573), 4326)::extensions.geography, 'Županijska ulica 8', 'Just inside, by the door. Stay where somebody walking in can see you.', '07:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/356921401', 'Galerija', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.683956, 45.560417), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/415695441', 'Patricija', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.701778, 45.543049), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/419828439', 'Internet Zona', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.697294, 45.545732), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/448132666', 'Dalmacija', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.675820, 45.556980), 4326)::extensions.geography, 'Županijska ulica 27', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/448134225', 'Gundulić', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.675768, 45.556652), 4326)::extensions.geography, 'Županijska ulica 33', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/454975879', 'San Francisco', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682375, 45.559078), 4326)::extensions.geography, 'Ulica Stjepana Radića 12', 'Just inside, by the door. Stay where somebody walking in can see you.', '08:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/454975881', 'As', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682395, 45.558642), 4326)::extensions.geography, 'Ulica Stjepana Radića 16', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Th 09:00-23:00; Fr-Sa 09:00-23:00; Su 11:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/454975883', 'Amsterdam', 'pub', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682409, 45.558431), 4326)::extensions.geography, 'Ulica Stjepana Radića 18', 'Just inside, by the door. Stay where somebody walking in can see you.', '07:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/454979297', 'Bonus', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681775, 45.558025), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/454997105', 'Lovac', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.685826, 45.556551), 4326)::extensions.geography, 'Ulica kardinala Alojzija Stepinca 14', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/454999696', 'No.22', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.675961, 45.560482), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/454999697', 'Central', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676356, 45.561524), 4326)::extensions.geography, 'Trg Ante Starčevića 6', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/455002467', 'Valentino', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.685927, 45.555775), 4326)::extensions.geography, 'Ulica kardinala Alojzija Stepinca 18a', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/459664701', 'Exclusive', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.697109, 45.554493), 4326)::extensions.geography, null, 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/471545722', 'Brooklyn', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.680440, 45.562283), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/471749118', 'College', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682546, 45.557221), 4326)::extensions.geography, 'Ulica Stjepana Radića 28', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/485256607', 'Slavonska kuća', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.693043, 45.560318), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/489414395', 'Prehrana', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.677074, 45.551644), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 08:00-20:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/490213921', 'Nautic', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681150, 45.562176), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/490213924', 'Capuccino', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681389, 45.562168), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/490213926', 'Havana', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681604, 45.562177), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/490213928', 'Sunset', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681771, 45.562181), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/490213930', 'Bounty', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682022, 45.562143), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/490766029', 'Promenda Hotel Osijek', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.680025, 45.562348), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, true)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/490771278', 'Zimska luka', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.679632, 45.562388), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/496303370', 'Goldfinger', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.719309, 45.557190), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', '08:00-22:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/496303372', 'Donjogradska cafeteria', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.719797, 45.556309), 4326)::extensions.geography, 'Ulica Ive Tijardovića 4a', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/506076607', 'M bar', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.697051, 45.560751), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/519458008', 'General von Becker''s', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.695612, 45.560066), 4326)::extensions.geography, 'Ulica Franje Kuhača 13', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', 'Mo-We 07:00-24:00; Th-Fr 07:00-01:00; Sa 07:30-04:00; Su 09:30-24:00', true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/519458011', 'Memories', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.695452, 45.560101), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/519458023', 'Luna', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694633, 45.560275), 4326)::extensions.geography, 'Ulica Franje Kuhača 19', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'aaefab4a-3a4b-5b4b-8875-f78880ba7892'::uuid, 'osm', 'node/521847622', 'Sedam', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.700545, 45.550677), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/521983246', 'M13', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.686953, 45.550452), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/521983248', 'Sloga', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.678210, 45.549930), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/523488330', 'Crvena malina', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.691471, 45.557835), 4326)::extensions.geography, 'Ulica Otokara Keršovanija 1', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/527124686', 'Lumiere', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682548, 45.561556), 4326)::extensions.geography, 'Šetalište kardinala Franje Šepera 8', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 08:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/527155428', 'Excalibur', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.686856, 45.557173), 4326)::extensions.geography, 'Ulica Franje Krežme 22', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 08:00-24:00;Sa 09:00-24:00;Su 16:00-24:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'ae6eba2f-4742-5b67-8203-ef38a19b755b'::uuid, 'osm', 'node/600857439', 'Cafe Bar Dvorac', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.679247, 45.545871), 4326)::extensions.geography, 'Drinska ulica 2', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 07:30-23:00; Su 08:30-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/600882782', 'Ara', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.725917, 45.544820), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/601472914', 'Petar Pan', 'ice_cream', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676560, 45.562285), 4326)::extensions.geography, 'Ribarska ulica 1', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 07:30-23:00; Su 10:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/618030621', 'Cafe Press', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.680455, 45.558391), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/622302975', 'Cafe Rio', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.651902, 45.542669), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'aaefab4a-3a4b-5b4b-8875-f78880ba7892'::uuid, 'osm', 'node/652646887', 'Pizzeria Sebastian', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.700772, 45.549914), 4326)::extensions.geography, 'Sjenjak 59', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', 'Mo-Sa 09:00-23:00; Su 17:00-23:00', true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '59ccf7b9-0dd3-55e5-a039-35614a7f7fa9'::uuid, 'osm', 'node/655123411', 'Roda', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.710779, 45.558068), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/658426309', 'Zimska Luka', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.677334, 45.562725), 4326)::extensions.geography, 'Šetalište kardinala Franje Šepera 12', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 08:00-23:00; Su 09:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/665066019', 'Vege Lege', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.683563, 45.559406), 4326)::extensions.geography, 'Trg Ljudevita Gaja 4', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 09:00-19:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/668641347', 'Caffe Prestige', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.718712, 45.543305), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', '07:00-22:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/696856717', 'Punk Rock Caffe Crna Ovca', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.684823, 45.557252), 4326)::extensions.geography, 'Vukovarska cesta 4a', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/703649189', 'Downtown', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.730685, 45.517361), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/709038520', 'Station', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.688648, 45.542961), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'b635fa03-e46c-5b22-99c8-750e3f781445'::uuid, 'osm', 'node/727519398', 'Fort Caffe', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.656311, 45.563783), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/820604437', 'Monokl', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682908, 45.553908), 4326)::extensions.geography, 'Ulica Stjepana Radića 56', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/829908716', 'Barcelona Pub', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.685986, 45.555042), 4326)::extensions.geography, 'Ulica kardinala Alojzija Stepinca 28', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/830167895', 'Marjan', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.674906, 45.562215), 4326)::extensions.geography, 'Ulica Josipa Jurja Strossmayera 15', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 07:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/830175884', 'Viktoria', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.674241, 45.562686), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/830185273', 'Caffe Sax', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.673401, 45.563039), 4326)::extensions.geography, 'Gornjodravska obala 91', 'Just inside, by the door. Stay where somebody walking in can see you.', '07:00-24:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/831051617', 'Mursa VBK', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.698332, 45.555809), 4326)::extensions.geography, null, 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/836286498', 'Romano caffe', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682802, 45.554617), 4326)::extensions.geography, 'Reisnerova ulica 65', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/836291597', 'G', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682731, 45.555451), 4326)::extensions.geography, 'Ulica Stjepana Radića 42', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/875622366', 'Druga Scena (Voodoo)', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681646, 45.557664), 4326)::extensions.geography, 'Sunčana ulica 8', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 08:00-24:00; Sa 09:00-24:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/875622511', 'Osijek United Forces', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681494, 45.557118), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/894112881', 'Axmann Pub', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.680008, 45.561405), 4326)::extensions.geography, 'Kapucinska ulica 26', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', 'Mo-Fr 07:00-24:00; Sa,Su 08:00-24:00', true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/906800944', 'Club Galerija Magis', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.686382, 45.560422), 4326)::extensions.geography, 'Europska avenija 6', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/906801921', 'Sokol', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.686747, 45.559801), 4326)::extensions.geography, 'Park kralja Petra Krešimira IV. 2', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/906824602', 'Studentski Klub', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694198, 45.556255), 4326)::extensions.geography, 'Istarska ulica 5', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 07:00-20:00; Sa 08:00-15:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/906828320', 'Cup of Joy', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.695863, 45.556721), 4326)::extensions.geography, 'Ulica kneza Trpimira 2b', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/914263611', 'Davos', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676548, 45.562392), 4326)::extensions.geography, 'Ribarska ulica 1', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/914266919', 'Domin', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.671881, 45.554936), 4326)::extensions.geography, 'Ulica svete Ane 84', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/914267713', 'Atrij', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.687975, 45.556821), 4326)::extensions.geography, 'Vukovarska cesta 15', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/914269013', 'Figaro', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.683813, 45.549619), 4326)::extensions.geography, 'Krbavska ulica 26', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/914293830', 'Berlin', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676598, 45.562624), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/914297626', 'Esseker Cafeterija', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.677166, 45.562351), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/914297803', 'Cafe Galerija', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.677214, 45.562542), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/915334173', 'Palazzo', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.679266, 45.556992), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 07:00-23:00; Sa 15:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/915405634', 'Cafe Bar K', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.686099, 45.553760), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/918401207', 'Mister X', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.652786, 45.557172), 4326)::extensions.geography, 'Sljemenska ulica 63', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/922756562', 'Verdi', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.698174, 45.556265), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/923986666', 'Lipov Hlad', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.716302, 45.556297), 4326)::extensions.geography, 'Trg bana Josipa Jelačića 2', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 07:00-23:00; Su 10:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/933230209', 'Đuro', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.672218, 45.561852), 4326)::extensions.geography, 'Ulica Pavla Pejačevića 30', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/933232131', 'Rustika', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.671879, 45.561994), 4326)::extensions.geography, 'Ulica Pavla Pejačevića 32', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Th,Su 10:00-22:00; Fr-Sa 10:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/938325294', 'Rokus', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.670590, 45.563963), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/942517220', 'Feral', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.683788, 45.559410), 4326)::extensions.geography, 'Trg Ljudevita Gaja 5', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 07:00-18:00;Su 07:00-12:00', false, true)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/946565922', 'Esseker', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681375, 45.558049), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/960250246', 'Santos', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682658, 45.556367), 4326)::extensions.geography, 'Ulica Stjepana Radića', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/960251585', 'La Coccolata', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682640, 45.556560), 4326)::extensions.geography, 'Ulica Stjepana Radića 32', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/960252345', 'Radić', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682652, 45.556430), 4326)::extensions.geography, 'Ulica Stjepana Radića', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/960254035', 'In', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682598, 45.556852), 4326)::extensions.geography, 'Ulica Stjepana Radića 28', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/960255958', 'New York', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682506, 45.557443), 4326)::extensions.geography, 'Ulica Stjepana Radića 22', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/960509671', 'Apsolvent', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694024, 45.556085), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/960524377', 'Tango', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.695082, 45.550963), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, true)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/972954635', 'Mali sokak', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.715484, 45.553131), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/972954662', 'Skuter club Sloboda', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.714480, 45.552144), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/972954667', 'Bonaca', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.713626, 45.551144), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/974090119', 'Marinero', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.661258, 45.559759), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/974405197', 'Cukarin', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.688060, 45.550021), 4326)::extensions.geography, 'Drinska ulica 93', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 06:30-22:30', false, true)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/974423892', 'Star Caffe', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.688481, 45.550124), 4326)::extensions.geography, 'Drinska ulica 99', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 07:00-23:00; Sa 08:00-15:00,17:00-22:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/976973827', 'Baroko', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.663926, 45.564040), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, true)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'ae6eba2f-4742-5b67-8203-ef38a19b755b'::uuid, 'osm', 'node/985040631', 'Caffe Bar Mačak', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.680749, 45.545500), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/994551828', 'Caffe Bar Greenfield', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.730222, 45.552713), 4326)::extensions.geography, 'Ulica Matije Gupca 57a', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', 'Mo-Su 07:00-23:00', true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'b2512bbf-f79d-58cf-b992-4cc2556d5591'::uuid, 'osm', 'node/994630654', 'Tiho', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.657157, 45.545198), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1026418332', 'De Paris', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.673812, 45.562958), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1083362686', 'Tutto Bene', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.675373, 45.552979), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1099400514', 'Snoopy', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681189, 45.554930), 4326)::extensions.geography, 'Zrinjevac 11', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1099461376', 'Sporting', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681187, 45.554994), 4326)::extensions.geography, 'Zrinjevac 11', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1099475838', 'San Marco', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681151, 45.555488), 4326)::extensions.geography, 'Zrinjevac 5', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1099484209', 'Demode', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682222, 45.556316), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1099484619', 'Zanzibar', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682343, 45.556316), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'aaefab4a-3a4b-5b4b-8875-f78880ba7892'::uuid, 'osm', 'node/1260715177', 'Caffeteria Novi grad', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.699907, 45.549355), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1262215040', 'Željezničar', 'bar', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681641, 45.554863), 4326)::extensions.geography, 'Reisnerova ulica 44', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1308373045', 'Pizzeria Gondola', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.675556, 45.555299), 4326)::extensions.geography, 'Županijska ulica 43', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 09:00-23:00, Su', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/1325228662', 'Quare', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.718917, 45.556214), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/1325229394', 'Šport', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.719143, 45.556274), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'b2512bbf-f79d-58cf-b992-4cc2556d5591'::uuid, 'osm', 'node/1340224585', 'Lotus bar', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.656117, 45.546188), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Su 08:00-01:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/1342429788', 'Twins', 'bar', extensions.ST_SetSRID(extensions.ST_MakePoint(18.673464, 45.520850), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/1574099030', 'Caffe Bar Moreno', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.715898, 45.555646), 4326)::extensions.geography, 'Ulica Josipa Huttlera 27', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1602462862', 'Cafe Bar Remy', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.674396, 45.563047), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 07:00-23:00;Su 09:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1602462885', 'Pizza Grill Corolla', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.671961, 45.563247), 4326)::extensions.geography, 'Ulica Josipa Jurja Strossmayera 41', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 08:30-23:00, Su 11:30-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1602462887', 'Klanac', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.672015, 45.563842), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/1602462908', 'Patika', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.672027, 45.563539), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/1602462910', 'Viva', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.715934, 45.557724), 4326)::extensions.geography, 'Ulica Josipa Huttlera', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/1689495697', 'Platana', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.637232, 45.536259), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/1738185745', 'Kavana Jelačić', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.720126, 45.554766), 4326)::extensions.geography, 'Trg bana Josipa Jelačića 20', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '59ccf7b9-0dd3-55e5-a039-35614a7f7fa9'::uuid, 'osm', 'node/1875081698', 'Grof', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.710800, 45.557913), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/1878227504', 'Dallas', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.716976, 45.555662), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2630583860', 'Hir', 'bar', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681263, 45.553763), 4326)::extensions.geography, 'Ulica fra Andrije Kačića Miošića 11', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2909021034', 'Alas', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.690145, 45.554871), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2910000021', 'Plus', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.693155, 45.557429), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2911247814', 'Trica', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.680371, 45.561971), 4326)::extensions.geography, 'Lučki prilaz 2', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2916988759', 'Dali', 'bar', extensions.ST_SetSRID(extensions.ST_MakePoint(18.688008, 45.555020), 4326)::extensions.geography, 'Zagrebačka ulica 26', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2916988760', 'Korzo 23', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.680339, 45.561061), 4326)::extensions.geography, 'Kapucinska ulica 23', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2917064597', 'Sport Klub', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682926, 45.553470), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2917087354', 'Corolla', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676334, 45.561415), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2917087366', 'The Kavana', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676123, 45.560451), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/2962554748', 'Roko Caffe', 'bar', extensions.ST_SetSRID(extensions.ST_MakePoint(18.668606, 45.560488), 4326)::extensions.geography, 'Ulica sv. Roka 40', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2992360460', 'Forum 1', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682748, 45.559079), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2992365098', 'Glembay', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682616, 45.560131), 4326)::extensions.geography, 'Ulica Stjepana Radića 5', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2995095489', 'Slastičarnica Sunčana', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681883, 45.557454), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2995095490', 'Leggero', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682406, 45.558362), 4326)::extensions.geography, 'Ulica Stjepana Radića 18', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2995095491', 'Krakow', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682409, 45.558483), 4326)::extensions.geography, 'Ulica Stjepana Radića 18', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/2995095492', 'Smile', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681899, 45.558363), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/3152311036', 'Fabrique', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.678631, 45.559008), 4326)::extensions.geography, null, 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/3152311039', 'Lotus City Bar', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.677945, 45.559527), 4326)::extensions.geography, 'Trg Slobode 7', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/3183073191', 'Tivoli', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682534, 45.557294), 4326)::extensions.geography, 'Ulica Stjepana Radića 26', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'node/3301614998', 'Caffe "Kino"', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.721594, 45.554828), 4326)::extensions.geography, 'Ulica Matije Gupca 9', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/3739705158', 'Vinica', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.647839, 45.564039), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'b635fa03-e46c-5b22-99c8-750e3f781445'::uuid, 'osm', 'node/3790484609', 'Caffeteria RTF', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.652709, 45.564150), 4326)::extensions.geography, 'Ulica Ljudevita Posavskog 203', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/4427890291', 'Craft Pub', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694131, 45.550038), 4326)::extensions.geography, 'Sjenjak 109', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/4427915894', 'Svačić', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.677857, 45.558579), 4326)::extensions.geography, 'Hrvatske Republike', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/4714064407', 'Gaudeamus', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694385, 45.555997), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/4714064408', 'Restoran Istarska', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694191, 45.556152), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 08:00-19:30', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/4925245372', 'the krig', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.678233, 45.559851), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/5363423448', 'GOLD by Waldinger', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676189, 45.558639), 4326)::extensions.geography, 'Županijska ulica 15', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 08:00-23:00; Sa-Su 08:00-24:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/5367015696', 'Petar Pan', 'ice_cream', extensions.ST_SetSRID(extensions.ST_MakePoint(18.697344, 45.559701), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/5380392822', 'America Bar Dollar', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676536, 45.560301), 4326)::extensions.geography, 'Županijska ulica 5', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/5389048354', 'Atellier Bar', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694389, 45.555358), 4326)::extensions.geography, null, 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/5419818279', 'Riverside restaurant', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.668034, 45.568162), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'b2512bbf-f79d-58cf-b992-4cc2556d5591'::uuid, 'osm', 'node/5423567213', 'Caffe Bara', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.657191, 45.546686), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo,Tu 09:00-17:00; We-Su 09:00-21:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/5846947042', 'Kavana gradski vrt', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.695766, 45.548899), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/6365013457', 'Hip Hop', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.636823, 45.565374), 4326)::extensions.geography, null, 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/6533519285', 'ČinkOs pancakes', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682624, 45.556630), 4326)::extensions.geography, 'Ulica Stjepana Radića 30a', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 10:00-23:00; Su 17:00-22:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/6711781317', 'Caffe Bar Diesel', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.680272, 45.553652), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/6791170827', 'Caffe bar Salsa', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.674785, 45.554913), 4326)::extensions.geography, 'Reisnerova ulica 72', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/6828358985', 'Caffe bar Sjenjak', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.695656, 45.551358), 4326)::extensions.geography, 'Sjenjak 133', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'ae6eba2f-4742-5b67-8203-ef38a19b755b'::uuid, 'osm', 'node/7787991447', 'Caffe Bar Cigla', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.677247, 45.544840), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/8856557832', 'Caffe Bar - Pub Beerc', 'bar', extensions.ST_SetSRID(extensions.ST_MakePoint(18.680373, 45.557375), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'b635fa03-e46c-5b22-99c8-750e3f781445'::uuid, 'osm', 'node/9024827117', 'Ugostiteljstvo Madarska Retfala', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.652279, 45.566124), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'cb9b9bb9-a814-5c9e-b09a-c67c2680e5f7'::uuid, 'osm', 'node/9509020960', 'Caffeteria Time', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.705158, 45.551599), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/9561211880', 'Hedonist Bar', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694463, 45.555715), 4326)::extensions.geography, null, 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c57ee783-66a1-5368-9e67-7731c36cec29'::uuid, 'osm', 'node/11284409551', 'Leggiero', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.637213, 45.554663), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c57ee783-66a1-5368-9e67-7731c36cec29'::uuid, 'osm', 'node/11284409553', 'Congo Caffe', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.637080, 45.555125), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c57ee783-66a1-5368-9e67-7731c36cec29'::uuid, 'osm', 'node/11284409569', 'Caffe Bar Dah', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.637264, 45.554990), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/12158287924', 'Gacka Caffe', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.690275, 45.547146), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/12340932818', 'Pepe pizza place', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.679844, 45.562370), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/12415858518', 'Batak', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.636533, 45.560509), 4326)::extensions.geography, 'Svilajska ulica 35b', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/12436973994', 'Vivas bar', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.636520, 45.560436), 4326)::extensions.geography, 'Svilajska ulica 35B', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/12554218640', 'Caffe bar Samo Fino', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.689893, 45.544946), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/12615353833', 'Vaduz', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.684774, 45.557269), 4326)::extensions.geography, 'Vukovarska cesta 4', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/12745722520', 'Pickles Burger Bar', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694836, 45.554769), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/12751877764', 'Rubicon Caffee Bar', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.682760, 45.555234), 4326)::extensions.geography, 'Ulica Stjepana Radića 44', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/12842230095', 'Pečenjarnica More', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694551, 45.554847), 4326)::extensions.geography, 'Vukovarska cesta 60', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/12961576048', 'Bulart', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.697474, 45.559885), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/13457785830', 'Beertija', 'pub', extensions.ST_SetSRID(extensions.ST_MakePoint(18.674315, 45.560976), 4326)::extensions.geography, 'Ulica Pavla Pejačevića 5', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/13457785831', 'Gajba', 'pub', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681818, 45.557240), 4326)::extensions.geography, 'Sunčana ulica 3', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/13457785832', 'Pivnica Runda', 'pub', extensions.ST_SetSRID(extensions.ST_MakePoint(18.686066, 45.560482), 4326)::extensions.geography, 'Europska avenija 8', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'node/13545593490', 'Beertija', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.697626, 45.559840), 4326)::extensions.geography, 'Ulica Franje Kuhača', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'node/13598050630', 'Pizzeria Novi Saloon', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.693042, 45.544695), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '16f1c31e-a8b1-528b-be92-24540d54d373'::uuid, 'osm', 'node/13987984672', 'Ostejecko Caffe-bar', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.605221, 45.571640), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'node/14055783434', 'Cafe Bar Parenzo', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.640531, 45.564587), 4326)::extensions.geography, 'Ulica Josipa Jurja Strossmayera 313', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/26149279', 'Park kralja Petra Krešimira IV.', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.688343, 45.559264), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/26159114', 'Park lijeva obala Drave', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.677393, 45.566805), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/26744805', 'Zrinjevac', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.679848, 45.555463), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/30887519', 'Trg baruna Franje Trenka', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.686416, 45.556737), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/31875588', 'Perivoj kralja Tomislava', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.689719, 45.561002), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/35610029', 'Park kralja Držislava', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.692832, 45.558465), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, true)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/35610387', 'Park Svetišta Srca Isusova', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.683510, 45.558202), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/35610388', 'Park Oscara Nemona', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.683470, 45.557755), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/42221169', 'Park kneza Branimira', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.690466, 45.557984), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/73965503', 'Plan B', 'bar', extensions.ST_SetSRID(extensions.ST_MakePoint(18.685382, 45.555765), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Fr 10:00-20:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/75394062', 'Vijenac Paje Kolarića', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.679053, 45.558718), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/75487588', 'Sport House', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.686213, 45.553171), 4326)::extensions.geography, 'Trg Lavoslava Ružičke bb', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', 'Tu-Fr 14:00-23:00, Sa 12:00-24:00, Su 12:00-23:00', true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/75488780', 'El Paso', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681265, 45.562591), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/75488789', 'Projekt 9', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676185, 45.564257), 4326)::extensions.geography, 'Gornjodravska obala bb', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Su-Th 11:00-23:00; Fr-Sa 11:00-01:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '16f1c31e-a8b1-528b-be92-24540d54d373'::uuid, 'osm', 'way/75597038', 'Stara Drava', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.605191, 45.571590), 4326)::extensions.geography, 'Ulica Nova Dalmacija 21', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'way/75649206', 'Restoran Bijelo-Plavi', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.695329, 45.548747), 4326)::extensions.geography, 'Ulica Martina Divalta 8', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/77040599', 'Merlon', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.695175, 45.559931), 4326)::extensions.geography, 'Ulica Franje Markovića 3', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '59ccf7b9-0dd3-55e5-a039-35614a7f7fa9'::uuid, 'osm', 'way/77069829', 'Restoran Campus', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.707727, 45.556605), 4326)::extensions.geography, 'Ulica Lavoslava Ružičke 3', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'way/77228501', 'Restoran Karaka', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.692383, 45.548978), 4326)::extensions.geography, 'Ulica kneza Trpimira 16', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, true)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'c6b9404e-2e97-55f5-ac3f-c17d6484d3f3'::uuid, 'osm', 'way/77228502', 'Kayenn', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.691814, 45.549194), 4326)::extensions.geography, 'Ulica kneza Trpimira 16a', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Sa 06:30-24:00; Su 06:30-22:30', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '16f1c31e-a8b1-528b-be92-24540d54d373'::uuid, 'osm', 'way/78123186', 'Bell', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.601553, 45.571365), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/79241193', 'Querido', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.613545, 45.568805), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/81654259', 'Slatki Život', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.620068, 45.565631), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/116910039', 'Plavi Anđeo', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.706818, 45.546686), 4326)::extensions.geography, 'Ulica kralja Petra Svačića 38', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/127525849', 'Restoran Kopika', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.697323, 45.565181), 4326)::extensions.geography, 'Biljska cesta 1d', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/131292083', 'Žuta podmornica', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.677638, 45.563249), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/161943729', 'Caffe bar BMW', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.704056, 45.554330), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/177479369', 'Kod Javora', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.717706, 45.560789), 4326)::extensions.geography, 'Donjodravska obala 14', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/310879220', 'Kompa', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.668928, 45.565774), 4326)::extensions.geography, 'Splavarska ulica 1', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/418269100', 'Limenka', 'pub', extensions.ST_SetSRID(extensions.ST_MakePoint(18.702506, 45.553790), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/443172367', '5', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.732022, 45.555275), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/511039586', 'Perivoj bana Josipa Šokčevića', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.700614, 45.558282), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/545290629', 'Zoo park', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.668956, 45.568117), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/545290663', 'Beach Bar', 'bar', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694633, 45.565475), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/545346554', 'Teletabis park', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.679600, 45.560762), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/554992535', 'Park Katakombe', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.700452, 45.564671), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/555012322', 'Ružin vrt', 'garden', extensions.ST_SetSRID(extensions.ST_MakePoint(18.692090, 45.558955), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/555305222', 'Trg Nikole Tesle', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.718886, 45.560937), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'ae6eba2f-4742-5b67-8203-ef38a19b755b'::uuid, 'osm', 'way/555758651', 'Park hrvatskog dragovoljca Domovinskog rata', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681625, 45.547058), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'way/555806276', 'Park kraljice Katarine Kosača', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.714492, 45.556941), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/559879855', 'Restoran Corner', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.728366, 45.545492), 4326)::extensions.geography, 'Velebitska ulica', 'Just inside, by the door. Stay where somebody walking in can see you.', 'Mo-Su 09:00-23:00', false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'cb9b9bb9-a814-5c9e-b09a-c67c2680e5f7'::uuid, 'osm', 'way/560062759', 'Pizzeria Strossmayer No. 2', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.705603, 45.550540), 4326)::extensions.geography, 'Ulica kralja Petra Svačića 16a', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'cb9b9bb9-a814-5c9e-b09a-c67c2680e5f7'::uuid, 'osm', 'way/560690444', 'Svačić', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.705552, 45.551675), 4326)::extensions.geography, 'Frankopanska ulica 1', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/561057234', 'Tomislavgrad', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.766610, 45.539652), 4326)::extensions.geography, 'Nemetin 5', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/562171472', 'Pizzeria Maslina', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.668260, 45.568121), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/562768229', 'Čarda kod Baranjca', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.703862, 45.565042), 4326)::extensions.geography, 'Biljska cesta 54', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/562768258', 'Orange bar', 'bar', extensions.ST_SetSRID(extensions.ST_MakePoint(18.706478, 45.561300), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/570347179', 'Davos', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.676656, 45.562475), 4326)::extensions.geography, null, 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/620685248', 'Sakuntala park', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.681270, 45.561390), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/681397578', 'NK Višnjevac', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.617784, 45.560413), 4326)::extensions.geography, null, 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', null, true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/682223106', 'Caffe bar Baza', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.619580, 45.564538), 4326)::extensions.geography, 'Ulica Nikole Šubića Zrinjskog 3d', 'Outside if the tables are out, otherwise just inside the door. Have a look at both before you decide nobody is there.', 'Mo-Su 07:00-23:00', true, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/708936489', 'Bauštela', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.742604, 45.545477), 4326)::extensions.geography, 'Vukovarska cesta 322', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/724126782', 'Rim', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.675517, 45.555047), 4326)::extensions.geography, 'Županijska ulica 49', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/1242381974', 'Perivoj hrvatskih velikana', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.694589, 45.559185), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, null, 'osm', 'way/1245896199', 'Caffe bar Ferrari', 'cafe', extensions.ST_SetSRID(extensions.ST_MakePoint(18.608781, 45.529302), 4326)::extensions.geography, 'Omladinska ulica 114', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, 'a7d689ed-c62b-55d1-a840-799523da2e95'::uuid, 'osm', 'way/1279066017', 'Trg Josifa Runjanina', 'park', extensions.ST_SetSRID(extensions.ST_MakePoint(18.721405, 45.552607), 4326)::extensions.geography, null, 'By the main entrance to the park. If there is more than one, the one nearest the road.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
  insert into public.venues (city_id, cluster_id, source, source_ref, name, kind, location, street, standing_spot, opening_hours, outdoor_seating, step_free)
  values (v_city, '2c06e6e3-b1ae-53c6-be24-685d2aec2d14'::uuid, 'osm', 'way/1395987681', 'Osječka pivnica Tvrđa', 'restaurant', extensions.ST_SetSRID(extensions.ST_MakePoint(18.693402, 45.560112), 4326)::extensions.geography, 'Ulica Kamila Firingera 24', 'Just inside, by the door. Stay where somebody walking in can see you.', null, false, false)
  on conflict (source, source_ref) do update set
    name = excluded.name, location = excluded.location,
    street = excluded.street, standing_spot = excluded.standing_spot,
    opening_hours = excluded.opening_hours,
    outdoor_seating = excluded.outdoor_seating,
    step_free = excluded.step_free,
    cluster_id = excluded.cluster_id, active = true,
    deactivated_at = null;
end;
$$;
