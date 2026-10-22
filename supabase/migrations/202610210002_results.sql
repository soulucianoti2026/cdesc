-- Published aggregate snapshots. No individual ballot or CPF reaches this API.
create table cde_private.result_snapshots (
  election_id uuid not null references cde_private.elections,
  is_final boolean not null,
  generated_at timestamptz not null default now(),
  segments jsonb not null check (jsonb_typeof(segments) = 'array'),
  primary key(election_id, is_final)
);
alter table cde_private.result_snapshots enable row level security;
revoke all on cde_private.result_snapshots from public, anon, authenticated;

create function public.cde_results(actor uuid, final_result boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare school uuid; election cde_private.elections; snapshot cde_private.result_snapshots;
begin
  select school_id into school from cde_private.profiles where user_id = actor and enabled and role = 'director';
  if not found then raise exception 'Access denied'; end if;
  select * into election from cde_private.elections where school_id = school;
  if not found then raise exception 'Election unavailable'; end if;
  if final_result and (election.status <> 'closed' or now() < election.closes_at) then
    raise exception 'Final result unavailable';
  end if;
  select * into snapshot from cde_private.result_snapshots where election_id = election.id and is_final = final_result;
  if not found then raise exception 'Result not published'; end if;
  return jsonb_build_object('is_final', snapshot.is_final, 'generated_at', snapshot.generated_at, 'segments', snapshot.segments);
end $$;
revoke all on function public.cde_results(uuid,boolean) from public, anon, authenticated;
grant execute on function public.cde_results(uuid,boolean) to service_role;
