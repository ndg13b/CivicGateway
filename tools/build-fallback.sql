-- Build assets/fallback-data.json from a database.
--
-- The fallback snapshot has to mirror the exact nested shape supabase-js
-- returns for the query in fetchFromSupabase(), or the offline path renders
-- differently from the live one. Hand-editing that JSON is how it drifts, so
-- generate it instead:
--
--   psql "$DATABASE_URL" -At -f tools/build-fallback.sql > assets/fallback-data.json
--
-- Against a local throwaway Postgres loaded with schema.sql + seed.sql + every
-- migration in order, this also doubles as a check that the migrations
-- actually produce the data the site expects.

with race_json as (
  select r.id, r.election_id,
         to_jsonb(r) || jsonb_build_object(
           'candidates', coalesce((
             select jsonb_agg(to_jsonb(c) || jsonb_build_object(
                      'resource_links', coalesce((
                        select jsonb_agg(jsonb_build_object('resources', to_jsonb(res)))
                        from resource_links rl
                        join resources res on res.id = rl.resource_id
                        where rl.candidate_id = c.id), '[]'::jsonb))
                    order by c.sort_order, c.name)
             from candidates c where c.race_id = r.id), '[]'::jsonb),
           'resource_links', coalesce((
             select jsonb_agg(jsonb_build_object('resources', to_jsonb(res)))
             from resource_links rl
             join resources res on res.id = rl.resource_id
             where rl.race_id = r.id), '[]'::jsonb)
         ) as j
  from races r
),
election_json as (
  select e.id, e.jurisdiction_id, e.district_id,
         to_jsonb(e) || jsonb_build_object(
           'races', coalesce((
             select jsonb_agg(rj.j order by (rj.j->>'sort_order')::int, rj.j->>'title')
             from race_json rj where rj.election_id = e.id), '[]'::jsonb)
         ) as j
  from elections e
),
district_json as (
  select d.id,
         to_jsonb(d) || jsonb_build_object(
           'officials', coalesce((
             select jsonb_agg(to_jsonb(o) order by o.sort_order, o.name)
             from officials o where o.district_id = d.id), '[]'::jsonb),
           'elections', coalesce((
             select jsonb_agg(ej.j order by ej.j->>'election_date')
             from election_json ej where ej.district_id = d.id), '[]'::jsonb)
         ) as j
  from districts d
)
select jsonb_pretty(jsonb_build_object(
  'generated', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  'jurisdictions', coalesce((
    select jsonb_agg(
      to_jsonb(j) || jsonb_build_object(
        'officials', coalesce((
          select jsonb_agg(to_jsonb(o) order by o.sort_order, o.name)
          from officials o where o.jurisdiction_id = j.id), '[]'::jsonb),
        'elections', coalesce((
          select jsonb_agg(ej.j order by ej.j->>'election_date')
          from election_json ej where ej.jurisdiction_id = j.id), '[]'::jsonb),
        'jurisdiction_districts', coalesce((
          select jsonb_agg(jsonb_build_object('partial', jd.partial, 'districts', dj.j)
                           order by dj.j->>'sort_order', dj.j->>'name')
          from jurisdiction_districts jd
          join district_json dj on dj.id = jd.district_id
          where jd.jurisdiction_id = j.id), '[]'::jsonb)
      ) order by j.name)
    from jurisdictions j), '[]'::jsonb),
  'statewide', coalesce((
    select jsonb_agg(dj.j order by dj.j->>'sort_order')
    from district_json dj
    where (dj.j->>'level') = 'statewide'), '[]'::jsonb)
));
