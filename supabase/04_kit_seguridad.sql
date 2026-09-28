-- ============================================================
-- Nómade con Sentido — Tareas propias + Kit de seguridad
-- Correr UNA vez en Supabase: SQL Editor > New query > pegar > Run
-- Es seguro correrlo de nuevo: no duplica nada y NO pisa zonas que ya editaste.
-- Requiere 02_notas.sql y 03_hoja_de_ruta.sql.
-- ============================================================

-- ---------- Tareas que suma el propio cliente ----------
create table if not exists public.client_tasks (
  id          uuid primary key default gen_random_uuid(),
  feedback_id uuid not null references public.client_feedback(id) on delete cascade,
  client_id   uuid not null references public.profiles(id) on delete cascade,
  cat         text not null,
  stage       text not null default 'antes',
  text        text not null check (char_length(text) between 1 and 200),
  done        boolean not null default false,
  created_at  timestamptz not null default now()
);
alter table public.client_tasks enable row level security;
drop policy if exists "client_tasks admin read" on public.client_tasks;
create policy "client_tasks admin read" on public.client_tasks for select using (public.nc_is_admin());
drop policy if exists "client_tasks own all" on public.client_tasks;
create policy "client_tasks own all" on public.client_tasks for all
  using (client_id = auth.uid())
  with check (
    client_id = auth.uid()
    and exists (select 1 from public.client_feedback f
                where f.id = feedback_id and f.client_id = auth.uid() and f.published = true)
  );

-- ---------- Zonas (las carga Valentina; las leen los clientes) ----------
create table if not exists public.safety_zones (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  state      text,
  content    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.safety_zones enable row level security;
drop policy if exists "safety_zones read" on public.safety_zones;
create policy "safety_zones read" on public.safety_zones for select using (auth.uid() is not null);
drop policy if exists "safety_zones admin all" on public.safety_zones;
create policy "safety_zones admin all" on public.safety_zones for all
  using (public.nc_is_admin()) with check (public.nc_is_admin());
drop trigger if exists safety_zones_touch on public.safety_zones;
create trigger safety_zones_touch before update on public.safety_zones
  for each row execute function public.nc_touch_updated_at();

-- ---------- Zona asignada a cada cliente ----------
create table if not exists public.client_safety (
  client_id uuid primary key references public.profiles(id) on delete cascade,
  zone_id   uuid references public.safety_zones(id) on delete set null
);
alter table public.client_safety enable row level security;
drop policy if exists "client_safety admin all" on public.client_safety;
create policy "client_safety admin all" on public.client_safety for all
  using (public.nc_is_admin()) with check (public.nc_is_admin());
drop policy if exists "client_safety own read" on public.client_safety;
create policy "client_safety own read" on public.client_safety for select using (client_id = auth.uid());

-- ---------- Misiones completadas ----------
create table if not exists public.safety_progress (
  client_id  uuid not null references public.profiles(id) on delete cascade,
  mission_id text not null,
  done_at    timestamptz not null default now(),
  primary key (client_id, mission_id)
);
alter table public.safety_progress enable row level security;
drop policy if exists "safety_progress admin read" on public.safety_progress;
create policy "safety_progress admin read" on public.safety_progress for select using (public.nc_is_admin());
drop policy if exists "safety_progress own read" on public.safety_progress;
create policy "safety_progress own read" on public.safety_progress for select using (client_id = auth.uid());
drop policy if exists "safety_progress own insert" on public.safety_progress;
create policy "safety_progress own insert" on public.safety_progress for insert with check (client_id = auth.uid());

-- ---------- Pedidos de zona nueva ----------
create table if not exists public.zone_requests (
  id         uuid primary key default gen_random_uuid(),
  client_id  uuid not null references public.profiles(id) on delete cascade,
  place      text not null check (char_length(place) between 1 and 80),
  resolved   boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.zone_requests enable row level security;
drop policy if exists "zone_requests admin all" on public.zone_requests;
create policy "zone_requests admin all" on public.zone_requests for all
  using (public.nc_is_admin()) with check (public.nc_is_admin());
drop policy if exists "zone_requests own read" on public.zone_requests;
create policy "zone_requests own read" on public.zone_requests for select using (client_id = auth.uid());
drop policy if exists "zone_requests own insert" on public.zone_requests;
create policy "zone_requests own insert" on public.zone_requests for insert
  with check (client_id = auth.uid() and resolved = false);

-- ---------- Zonas precargadas (datos verificados el 28/09/2026) ----------
insert into public.safety_zones (name, state, content) values
('Florianópolis', 'Santa Catarina', $${
  "health": [
    {"name":"UPA Norte da Ilha","addr":"Norte de la isla (Vargem Grande / Ingleses)","note":"Urgencias 24 h"},
    {"name":"UPA Sul da Ilha","addr":"Campeche, junto a la terminal TIRIO","note":"Urgencias 24 h"},
    {"name":"UPA Continente","addr":"Parte continental de la ciudad","note":"Urgencias 24 h"},
    {"name":"Hospital Universitário UFSC","addr":"Trindade","note":"Hospital de referencia para casos graves"}
  ],
  "police": [],
  "report": {"label":"Hacer el B.O. online (tiene sección para extranjeros)","url":"https://delegaciavirtual.sc.gov.br/"},
  "consulate": {"name":"Consulado General de Argentina en Florianópolis","addr":"Rod. José Carlos Daux (SC-401), 5500, Square Corporate, Torre Campeche, sala 218","phone":"(48) 3024-3035","emergency":"(48) 98808-4171","web":"https://cflor.cancilleria.gob.ar/"},
  "tips": ""
}$$::jsonb),
('Ubatuba', 'São Paulo', $${
  "health": [
    {"name":"Pronto Socorro – Santa Casa de Ubatuba","addr":"Rua Conceição, 135 – Centro","note":"Concentra las urgencias de la ciudad. Tel. (12) 3834-3230"}
  ],
  "police": [],
  "report": {"label":"Hacer el B.O. online (Delegacia Eletrônica SP)","url":"https://www.delegaciaeletronica.policiacivil.sp.gov.br/"},
  "consulate": {"name":"Consulado General de Argentina en São Paulo","addr":"Av. Paulista, 2313 – sobreloja","phone":"(11) 3897-9522","emergency":"(11) 99604-1561","web":"https://cpabl.cancilleria.gob.ar/"},
  "tips": ""
}$$::jsonb),
('Río de Janeiro', 'Río de Janeiro', $${
  "health": [
    {"name":"UPA 24h más cercana","addr":"Hay varias en la ciudad: buscá la más cercana en el mapa","note":"Urgencias 24 h"}
  ],
  "police": [
    {"name":"DEAT – Delegacia Especial de Apoio ao Turismo","addr":"Av. Afrânio de Melo Franco, 159 – Leblon","phone":"(21) 2332-2429","note":"Policía especializada en turistas extranjeros"}
  ],
  "report": {"label":"Hacer el registro online (Delegacia Online RJ)","url":"https://delegaciaonline.pcivil.rj.gov.br/"},
  "consulate": {"name":"Consulado General de Argentina en Río de Janeiro","addr":"Praia de Botafogo, 228 – sobreloja 201","phone":"(21) 2553-1646","emergency":"(21) 98476-0444","web":"https://crioj.cancilleria.gob.ar/"},
  "tips": ""
}$$::jsonb),
('Arraial do Cabo', 'Río de Janeiro', $${
  "health": [
    {"name":"Hospital Geral de Arraial do Cabo","addr":"Av. Getúlio Vargas – Centro","note":"Emergencias"}
  ],
  "police": [],
  "report": {"label":"Hacer el registro online (Delegacia Online RJ)","url":"https://delegaciaonline.pcivil.rj.gov.br/"},
  "consulate": {"name":"Consulado General de Argentina en Río de Janeiro","addr":"Praia de Botafogo, 228 – sobreloja 201","phone":"(21) 2553-1646","emergency":"(21) 98476-0444","web":"https://crioj.cancilleria.gob.ar/"},
  "tips": ""
}$$::jsonb),
('São Paulo', 'São Paulo', $${
  "health": [
    {"name":"UPA o AMA más cercana","addr":"Hay muchas en la ciudad: buscá la más cercana en el mapa","note":"Urgencias"}
  ],
  "police": [],
  "report": {"label":"Hacer el B.O. online (Delegacia Eletrônica SP)","url":"https://www.delegaciaeletronica.policiacivil.sp.gov.br/"},
  "consulate": {"name":"Consulado General de Argentina en São Paulo","addr":"Av. Paulista, 2313 – sobreloja","phone":"(11) 3897-9522","emergency":"(11) 99604-1561","web":"https://cpabl.cancilleria.gob.ar/"},
  "tips": ""
}$$::jsonb)
on conflict (name) do nothing;
