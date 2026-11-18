-- Run this script in Supabase > SQL Editor.
-- Create each team account in Supabase Authentication, then add its UUID to
-- mt001_usuarios_permitidos. Only allowlisted accounts can access the records.

create table if not exists public.mt001_usuarios_permitidos (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.mt001_usuarios_permitidos enable row level security;
revoke all on table public.mt001_usuarios_permitidos from public, anon, authenticated;
grant select on table public.mt001_usuarios_permitidos to authenticated;

drop policy if exists "Users can check their own MT-001 access"
  on public.mt001_usuarios_permitidos;
create policy "Users can check their own MT-001 access"
  on public.mt001_usuarios_permitidos
  for select
  to authenticated
  using (user_id = auth.uid());

create table if not exists public.mt001_intervenciones (
  sid text primary key,
  data jsonb not null check (jsonb_typeof(data) = 'object'),
  saved_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  last_by uuid references auth.users (id) on delete set null,
  anulada boolean not null default false,
  motivo text,
  anulada_por uuid references auth.users (id) on delete set null,
  anulada_en timestamptz
);

alter table public.mt001_intervenciones enable row level security;

revoke all on table public.mt001_intervenciones from public, anon, authenticated;
grant select, insert, update on table public.mt001_intervenciones to authenticated;

drop policy if exists "Authenticated users can read MT-001 records"
  on public.mt001_intervenciones;
create policy "Authenticated users can read MT-001 records"
  on public.mt001_intervenciones
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.mt001_usuarios_permitidos
      where user_id = auth.uid()
    )
  );

drop policy if exists "Authenticated users can insert MT-001 records"
  on public.mt001_intervenciones;
create policy "Authenticated users can insert MT-001 records"
  on public.mt001_intervenciones
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.mt001_usuarios_permitidos
      where user_id = auth.uid()
    )
  );

drop policy if exists "Authenticated users can update MT-001 records"
  on public.mt001_intervenciones;
create policy "Authenticated users can update MT-001 records"
  on public.mt001_intervenciones
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.mt001_usuarios_permitidos
      where user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.mt001_usuarios_permitidos
      where user_id = auth.uid()
    )
  );

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'mt001_intervenciones'
  ) then
    alter publication supabase_realtime
      add table public.mt001_intervenciones;
  end if;
end
$$;
