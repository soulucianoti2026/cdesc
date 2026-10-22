-- All tables are private. Only the authenticated Edge Function may call RPCs.
create schema if not exists cde_private;
revoke all on schema cde_private from public, anon, authenticated;

create table cde_private.schools (
  id uuid primary key default gen_random_uuid(), name text not null,
  city text not null, director text not null, email text not null, phone text not null
);
create table cde_private.elections (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references cde_private.schools,
  opens_at timestamptz not null, closes_at timestamptz not null,
  status text not null default 'preparation' check (status in ('preparation','open','closed')),
  check (closes_at > opens_at), unique(school_id)
);
create table cde_private.slates (
  id uuid primary key default gen_random_uuid(), election_id uuid not null references cde_private.elections,
  number text not null check (number ~ '^[0-9]{2,3}$'), name text not null check (length(name) between 1 and 150),
  segment int not null check (segment between 0 and 2),
  members jsonb not null check (jsonb_typeof(members) = 'array' and jsonb_array_length(members) >= 2),
  -- Encrypted CPF envelopes, never included in client responses.
  member_cpfs jsonb not null,
  unique(election_id, segment, number)
);
create table cde_private.voters (
  id uuid primary key default gen_random_uuid(), school_id uuid not null references cde_private.schools,
  name text not null check (length(name) between 1 and 150),
  category int not null check (category between 0 and 3),
  link text not null, enabled boolean not null default false,
  student_id uuid references cde_private.voters,
  cpf_cipher jsonb not null, cpf_digest text not null,
  unique(school_id, cpf_digest),
  check ((category = 2 and student_id is not null) or (category <> 2 and student_id is null))
);
create unique index one_enabled_guardian_per_student on cde_private.voters(student_id) where category = 2 and enabled;
create table cde_private.profiles (
  user_id uuid primary key references auth.users on delete cascade,
  school_id uuid not null references cde_private.schools,
  role text not null check (role in ('director','voter')),
  voter_id uuid unique references cde_private.voters,
  enabled boolean not null default true,
  check ((role = 'voter' and voter_id is not null) or (role = 'director' and voter_id is null))
);
create table cde_private.participation (
  election_id uuid not null references cde_private.elections,
  voter_id uuid not null references cde_private.voters,
  primary key(election_id, voter_id)
);
create table cde_private.ballots (
  id uuid primary key default gen_random_uuid(),
  election_id uuid not null references cde_private.elections,
  segment int not null check (segment between 0 and 2),
  ciphertext jsonb not null
  -- No voter, user, receipt, timestamp, or participation foreign key.
);
do $$ declare t text; begin
  foreach t in array array['schools','elections','slates','voters','profiles','participation','ballots'] loop
    execute format('alter table cde_private.%I enable row level security', t);
    execute format('revoke all on cde_private.%I from public, anon, authenticated', t);
  end loop;
end $$;

create function public.cde_bootstrap(actor uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p cde_private.profiles; e cde_private.elections; v cde_private.voters; seg int := 0; result jsonb;
begin
  select * into p from cde_private.profiles where user_id = actor and enabled;
  if not found then raise exception 'Access denied'; end if;
  select * into e from cde_private.elections where school_id = p.school_id;
  if not found then raise exception 'Election unavailable'; end if;
  if p.role = 'voter' then
    select * into v from cde_private.voters where id = p.voter_id and school_id = p.school_id and enabled;
    if not found then raise exception 'Access denied'; end if;
    seg := case v.category when 0 then 1 when 2 then 0 else 2 end;
  end if;
  select jsonb_build_object(
    'school', jsonb_build_object('name', s.name, 'city', s.city, 'director', s.director, 'email', s.email, 'phone', s.phone),
    'director', p.role = 'director', 'user_name', case when p.role = 'director' then s.director else v.name end,
    'segment', seg,
    'election_date', to_char(e.opens_at at time zone 'America/Sao_Paulo', 'DD/MM/YYYY'),
    'election_status', case e.status when 'preparation' then 'Em preparação' when 'open' then 'Votação aberta' else 'Encerrada' end,
    'has_voted', exists(select 1 from cde_private.participation where election_id = e.id and voter_id = p.voter_id),
    'slates', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'number', c.number, 'name', c.name, 'segment', c.segment, 'members', c.members) order by c.segment, c.number)
      from cde_private.slates c where c.election_id = e.id and (p.role = 'director' or c.segment = seg)), '[]'::jsonb),
    'voters', case when p.role = 'director' then coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'category', x.category, 'link', x.link, 'enabled', x.enabled, 'student_id', x.student_id) order by x.name)
      from cde_private.voters x where x.school_id = p.school_id), '[]'::jsonb) else '[]'::jsonb end
  ) into result from cde_private.schools s where s.id = p.school_id;
  return result;
end $$;

create function public.cde_save_school(actor uuid, contact_email text, contact_phone text) returns void
language plpgsql security definer set search_path = '' as $$
declare school uuid;
begin
  select school_id into school from cde_private.profiles where user_id = actor and enabled and role = 'director';
  if not found then raise exception 'Access denied'; end if;
  if length(contact_email) > 254 or contact_email !~ '^[^ @]+@[^ @]+[.][^ @]+$' or length(contact_phone) > 30 then raise exception 'Invalid contact'; end if;
  update cde_private.schools set email = contact_email, phone = contact_phone where id = school;
end $$;

create function public.cde_save_slate(actor uuid, payload jsonb, encrypted_cpfs jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare school uuid; election uuid; sid uuid; old_cpfs jsonb; merged jsonb := '[]'; item jsonb; idx int;
begin
  select school_id into school from cde_private.profiles where user_id = actor and enabled and role = 'director';
  if not found then raise exception 'Access denied'; end if;
  select id into election from cde_private.elections where school_id = school and status = 'preparation' for update;
  if not found then raise exception 'Election is locked'; end if;
  sid := nullif(payload->>'id','')::uuid;
  if sid is not null then
    select member_cpfs into old_cpfs from cde_private.slates where id = sid and election_id = election for update;
    if not found then raise exception 'Access denied'; end if;
  end if;
  if jsonb_array_length(encrypted_cpfs) <> jsonb_array_length(payload->'members') then raise exception 'Invalid members'; end if;
  for idx in 0..jsonb_array_length(encrypted_cpfs)-1 loop
    item := encrypted_cpfs->idx;
    if item = 'null'::jsonb then item := old_cpfs->idx; end if;
    if item is null or item = 'null'::jsonb then raise exception 'CPF required'; end if;
    merged := merged || jsonb_build_array(item);
  end loop;
  if (select count(*) from jsonb_array_elements(merged)) <> (select count(distinct x->>'digest') from jsonb_array_elements(merged) x) then raise exception 'Duplicate CPF'; end if;
  insert into cde_private.slates(id, election_id, number, name, segment, members, member_cpfs)
    values(coalesce(sid, gen_random_uuid()), election, payload->>'number', payload->>'name', (payload->>'segment')::int, payload->'members', merged)
    on conflict(id) do update set number = excluded.number, name = excluded.name, segment = excluded.segment, members = excluded.members, member_cpfs = excluded.member_cpfs;
end $$;

create function public.cde_save_voter(actor uuid, payload jsonb, encrypted_cpf jsonb, digest text) returns void
language plpgsql security definer set search_path = '' as $$
declare school uuid; vid uuid; student uuid; old cde_private.voters;
begin
  select school_id into school from cde_private.profiles where user_id = actor and enabled and role = 'director';
  if not found then raise exception 'Access denied'; end if;
  -- Freeze roll during/after voting; serialize against election state changes.
  perform 1 from cde_private.elections where school_id = school and status = 'preparation' for update;
  if not found then raise exception 'Election is locked'; end if;
  vid := nullif(payload->>'id','')::uuid;
  if vid is not null then
    select * into old from cde_private.voters where id = vid and school_id = school for update;
    if not found then raise exception 'Access denied'; end if;
  end if;
  student := nullif(payload->>'student_id','')::uuid;
  if digest is not null and digest is distinct from old.cpf_digest and exists(select 1 from cde_private.profiles where voter_id = vid) then
    raise exception 'Linked identity is immutable';
  end if;
  if (payload->>'category')::int = 2 then
    perform 1 from cde_private.voters where id = student and school_id = school and category = 0 for update;
    if not found then raise exception 'Invalid student'; end if;
  elsif student is not null then raise exception 'Invalid student'; end if;
  if old.category = 0 and (payload->>'category')::int <> 0 and exists(select 1 from cde_private.voters where student_id = vid) then raise exception 'Student has guardians'; end if;
  insert into cde_private.voters(id, school_id, name, category, link, enabled, student_id, cpf_cipher, cpf_digest)
    values(coalesce(vid, gen_random_uuid()), school, payload->>'name', (payload->>'category')::int, payload->>'link', true, student,
      coalesce(encrypted_cpf, old.cpf_cipher), coalesce(digest, old.cpf_digest))
    on conflict(id) do update set name = excluded.name, category = excluded.category, link = excluded.link, enabled = true,
      student_id = excluded.student_id, cpf_cipher = excluded.cpf_cipher, cpf_digest = excluded.cpf_digest;
end $$;

create function public.cde_vote(actor uuid, slate_id uuid, encrypted_ballot jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare p cde_private.profiles; v cde_private.voters; e cde_private.elections; seg int;
begin
  select * into p from cde_private.profiles where user_id = actor and enabled and role = 'voter';
  if not found then raise exception 'Access denied'; end if;
  select * into v from cde_private.voters where id = p.voter_id and school_id = p.school_id and enabled for update;
  if not found then raise exception 'Access denied'; end if;
  select * into e from cde_private.elections where school_id = p.school_id and status = 'open' and now() >= opens_at and now() < closes_at for share;
  if not found then raise exception 'Election is not open'; end if;
  seg := case v.category when 0 then 1 when 2 then 0 else 2 end;
  if slate_id is not null then
    perform 1 from cde_private.slates where id = slate_id and election_id = e.id and segment = seg;
    if not found then raise exception 'Invalid slate'; end if;
  end if;
  if exists(select 1 from cde_private.participation where election_id = e.id and voter_id = v.id) then return; end if;
  -- Atomic, idempotent retry: participation and encrypted ballot commit together.
  insert into cde_private.participation values(e.id, v.id);
  insert into cde_private.ballots(election_id, segment, ciphertext) values(e.id, seg, encrypted_ballot);
end $$;

revoke all on function public.cde_bootstrap(uuid) from public, anon, authenticated;
revoke all on function public.cde_save_school(uuid,text,text) from public, anon, authenticated;
revoke all on function public.cde_save_slate(uuid,jsonb,jsonb) from public, anon, authenticated;
revoke all on function public.cde_save_voter(uuid,jsonb,jsonb,text) from public, anon, authenticated;
revoke all on function public.cde_vote(uuid,uuid,jsonb) from public, anon, authenticated;
grant execute on function public.cde_bootstrap(uuid) to service_role;
grant execute on function public.cde_save_school(uuid,text,text) to service_role;
grant execute on function public.cde_save_slate(uuid,jsonb,jsonb) to service_role;
grant execute on function public.cde_save_voter(uuid,jsonb,jsonb,text) to service_role;
grant execute on function public.cde_vote(uuid,uuid,jsonb) to service_role;

create function public.cde_search_cpf(actor uuid, digest text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare school uuid; result jsonb;
begin
  select school_id into school from cde_private.profiles where user_id = actor and enabled and role = 'director';
  if not found then raise exception 'Access denied'; end if;
  select jsonb_build_object('voters', coalesce(jsonb_agg(jsonb_build_object(
    'id', v.id, 'name', v.name, 'category', v.category, 'link', v.link, 'enabled', v.enabled, 'student_id', v.student_id)), '[]'::jsonb))
    into result from cde_private.voters v where v.school_id = school and v.cpf_digest = digest;
  return result;
end $$;
revoke all on function public.cde_search_cpf(uuid,text) from public, anon, authenticated;
grant execute on function public.cde_search_cpf(uuid,text) to service_role;
