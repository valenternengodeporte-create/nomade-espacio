-- ============================================================
-- Nómade con Sentido — Hoja de ruta (tareas por categoría + progreso)
-- Correr UNA vez en Supabase: SQL Editor > New query > pegar > Run
-- Es seguro correrlo de nuevo (no duplica nada). Requiere 02_notas.sql.
-- ============================================================

-- Nuevos datos de la devolución
alter table public.client_feedback add column if not exists destination    text;
alter table public.client_feedback add column if not exists departure_date date;
alter table public.client_feedback add column if not exists items          jsonb not null default '[]'::jsonb;

-- Progreso: qué tareas tachó cada cliente
create table if not exists public.plan_progress (
  feedback_id uuid not null references public.client_feedback(id) on delete cascade,
  item_id     text not null,
  client_id   uuid not null references public.profiles(id) on delete cascade,
  done_at     timestamptz not null default now(),
  primary key (feedback_id, item_id)
);

alter table public.plan_progress enable row level security;

drop policy if exists "plan_progress admin read" on public.plan_progress;
create policy "plan_progress admin read" on public.plan_progress
  for select using (public.nc_is_admin());

drop policy if exists "plan_progress own read" on public.plan_progress;
create policy "plan_progress own read" on public.plan_progress
  for select using (client_id = auth.uid());

-- El cliente solo puede tachar tareas de SUS hojas de ruta publicadas
drop policy if exists "plan_progress own insert" on public.plan_progress;
create policy "plan_progress own insert" on public.plan_progress
  for insert with check (
    client_id = auth.uid()
    and exists (select 1 from public.client_feedback f
                where f.id = feedback_id and f.client_id = auth.uid() and f.published = true)
  );

drop policy if exists "plan_progress own delete" on public.plan_progress;
create policy "plan_progress own delete" on public.plan_progress
  for delete using (client_id = auth.uid());
