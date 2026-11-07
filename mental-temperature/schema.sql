-- Supabase → SQL Editor-এ পুরোটা paste করে Run দাও (আগে চালানো থাকলেও আবার চালানো যাবে)

create table if not exists submissions (
  id bigserial primary key,
  temp int not null check (temp between 15 and 55),
  division text,
  created_at timestamptz not null default now()
);

alter table submissions add column if not exists name text;
alter table submissions drop constraint if exists submissions_division_check;
alter table submissions add constraint submissions_division_check
  check (division is null or division in ('ঢাকা','চট্টগ্রাম','রাজশাহী','খুলনা','বরিশাল','সিলেট','রংপুর','ময়মনসিংহ'));

alter table submissions enable row level security;

-- যে কেউ নাম ও তাপমাত্রা যোগ করতে পারবে; টেবিল সরাসরি পড়া যাবে না (নাম গোপন থাকবে)
drop policy if exists "anon insert" on submissions;
create policy "anon insert" on submissions for insert to anon
  with check (temp between 15 and 55 and char_length(name) between 1 and 30);

create or replace function get_stats() returns json
language sql security definer set search_path = public as $$
  select json_build_object(
    'total', (select count(*) from submissions where created_at > now() - interval '24 hours'),
    'avg',   (select coalesce(round(avg(temp)::numeric,1),0) from submissions where created_at > now() - interval '24 hours'),
    'high',  (select count(*) from submissions where temp >= 38 and created_at > now() - interval '24 hours'),
    'hour',  (select json_build_array(
                count(*) filter (where temp <= 25),
                count(*) filter (where temp between 26 and 32),
                count(*) filter (where temp between 33 and 37),
                count(*) filter (where temp between 38 and 42),
                count(*) filter (where temp between 43 and 48),
                count(*) filter (where temp >= 49))
              from submissions where created_at > now() - interval '1 hour'),
    'divisions', (select coalesce(json_object_agg(division, a), '{}'::json)
              from (select division, round(avg(temp)::numeric,1) a from submissions
                    where division is not null and created_at > now() - interval '24 hours'
                    group by division) d)
  );
$$;
grant execute on function get_stats() to anon;

-- সাম্প্রতিক ১০ জনের নাম ও তাপমাত্রা (শুধু এটুকুই পড়া যাবে)
create or replace function get_recent() returns json
language sql security definer set search_path = public as $$
  select coalesce(json_agg(r), '[]'::json) from (
    select name, temp, created_at from submissions
    where name is not null
    order by created_at desc limit 10
  ) r;
$$;
grant execute on function get_recent() to anon;
