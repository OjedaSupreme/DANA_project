-- ============================================================
-- SOLIMAT — Restaurar acceso RLS para la app actual (anon + RPC)
-- Usar si ves: "new row violates row-level security policy for table app_meta"
-- Causa habitual: se ejecuto supabase-auth-jwt.sql antes de migrar el login.
-- ============================================================

-- Quitar policies estrictas de auth-jwt (si existen)
drop policy if exists "app_meta_admin" on app_meta;
drop policy if exists "solicitudes_select_auth" on solicitudes;
drop policy if exists "solicitudes_insert_prod" on solicitudes;
drop policy if exists "solicitudes_update_alm" on solicitudes;
drop policy if exists "solicitudes_admin" on solicitudes;
drop policy if exists "detalles_select_auth" on solicitud_detalles;
drop policy if exists "detalles_insert_prod" on solicitud_detalles;
drop policy if exists "detalles_update_alm" on solicitud_detalles;
drop policy if exists "detalles_admin" on solicitud_detalles;
drop policy if exists "catalogo_select_auth" on catalogo_bom;
drop policy if exists "catalogo_admin_write" on catalogo_bom;
drop policy if exists "usuarios_admin" on usuarios;

-- Restaurar policies publicas (app con anon key + verify_user_login)
drop policy if exists "app_meta_public_access" on app_meta;
create policy "app_meta_public_access"
  on app_meta for all
  using (true)
  with check (true);

drop policy if exists "solicitudes_public_access" on solicitudes;
create policy "solicitudes_public_access"
  on solicitudes for all
  using (true)
  with check (true);

drop policy if exists "detalles_public_access" on solicitud_detalles;
create policy "detalles_public_access"
  on solicitud_detalles for all
  using (true)
  with check (true);

drop policy if exists "catalogo_public_access" on catalogo_bom;
create policy "catalogo_public_access"
  on catalogo_bom for all
  using (true)
  with check (true);

drop policy if exists "usuarios_public_access" on usuarios;
create policy "usuarios_public_access"
  on usuarios for all
  using (true)
  with check (true);

-- Asegurar que el login RPC sigue disponible
grant execute on function verify_user_login(text, text) to anon, authenticated;
