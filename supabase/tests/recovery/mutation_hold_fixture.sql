begin;

create table public.sai_mutation_hold_probe (
  id bigint generated always as identity primary key,
  note text not null,
  created_at timestamptz not null default now()
);
alter table public.sai_mutation_hold_probe enable row level security;
create policy sai_mutation_hold_probe_authenticated
  on public.sai_mutation_hold_probe
  for all to authenticated
  using (true) with check (true);
grant select, insert, update, delete, truncate on public.sai_mutation_hold_probe
  to anon, authenticated, service_role;
grant usage, select on sequence public.sai_mutation_hold_probe_id_seq
  to anon, authenticated, service_role;

create function public.sai_mutation_hold_probe_rpc()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.sai_mutation_hold_probe(note) values ('rpc');
end
$$;
grant execute on function public.sai_mutation_hold_probe_rpc() to authenticated;

commit;
