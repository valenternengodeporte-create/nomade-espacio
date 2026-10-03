-- ============================================================
-- Nómade con Sentido — Proteger el permiso de admin
-- Corrido en Supabase el 2026-09-29 (SQL Editor > New query > Run).
-- Es seguro correrlo de nuevo.
--
-- La regla "usuario edita su perfil" deja que cada persona edite SU
-- fila de profiles, pero no limita qué columnas. Sin esto, una clienta
-- podía ponerse is_admin = true desde la API y leer las notas de todas.
-- El sitio solo necesita que la clienta edite su nombre.
-- Para hacer admin a alguien: Table Editor del panel de Supabase.
-- ============================================================

revoke update on public.profiles from anon, authenticated;
grant update (name) on public.profiles to authenticated;

-- Control: tiene que devolver una sola fila, "name".
-- select column_name from information_schema.column_privileges
-- where table_schema = 'public' and table_name = 'profiles'
--   and grantee = 'authenticated' and privilege_type = 'UPDATE';
