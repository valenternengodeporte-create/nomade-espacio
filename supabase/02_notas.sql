-- ============================================================
-- Nómade con Sentido — Notas personalizadas (dos capas)
-- Correr UNA vez en Supabase: SQL Editor > New query > pegar > Run
-- Es seguro correrlo de nuevo (no duplica nada).
--
-- Capa 1: session_notes   -> notas clínicas PRIVADAS. Solo admin.
-- Capa 2: client_feedback -> devolución + plan de acción. El cliente
--         solo ve las suyas y solo si están publicadas.
-- Van en tablas separadas a propósito: la seguridad de Supabase (RLS)
-- es por fila, no por columna. Si estuvieran en la misma tabla, el
-- cliente podría leer las notas privadas.
-- ============================================================

-- Chequeo de admin sin recursión en las políticas
create or replace function public.nc_is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- ---------- CAPA 1: notas privadas ----------
create table if not exists public.session_notes (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid not null references public.profiles(id) on delete cascade,
  session_date date not null default current_date,
  body         text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists session_notes_client_idx on public.session_notes(client_id, session_date desc);

alter table public.session_notes enable row level security;
drop policy if exists "session_notes admin all" on public.session_notes;
create policy "session_notes admin all" on public.session_notes
  for all using (public.nc_is_admin()) with check (public.nc_is_admin());
-- Sin ninguna otra política: el cliente NO puede leer ni escribir nada acá.

-- ---------- CAPA 2: devoluciones visibles ----------
create table if not exists public.client_feedback (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid not null references public.profiles(id) on delete cascade,
  title        text not null,
  body         text,
  action_plan  text,            -- un paso por línea
  published    boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists client_feedback_client_idx on public.client_feedback(client_id, created_at desc);

alter table public.client_feedback enable row level security;
drop policy if exists "client_feedback admin all" on public.client_feedback;
create policy "client_feedback admin all" on public.client_feedback
  for all using (public.nc_is_admin()) with check (public.nc_is_admin());
drop policy if exists "client_feedback own published" on public.client_feedback;
create policy "client_feedback own published" on public.client_feedback
  for select using (client_id = auth.uid() and published = true);

-- ---------- updated_at automático ----------
create or replace function public.nc_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists session_notes_touch on public.session_notes;
create trigger session_notes_touch before update on public.session_notes
  for each row execute function public.nc_touch_updated_at();
drop trigger if exists client_feedback_touch on public.client_feedback;
create trigger client_feedback_touch before update on public.client_feedback
  for each row execute function public.nc_touch_updated_at();

-- ---------- Admin puede ver la lista de clientes ----------
drop policy if exists "profiles admin read all" on public.profiles;
create policy "profiles admin read all" on public.profiles
  for select using (public.nc_is_admin());
