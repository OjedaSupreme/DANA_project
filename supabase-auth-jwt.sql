-- ============================================================
-- SOLIMAT — Supabase Auth + JWT + RLS (plan de migracion)
-- Ejecutar en orden en Supabase → SQL Editor
-- ============================================================
--
-- CONCEPTO:
--   1. Supabase Auth emite el JWT (access_token) al hacer login.
--   2. El cliente supabase-js lo envia automaticamente en cada query.
--   3. RLS lee auth.uid() y el rol del usuario para permitir/denegar.
--
-- ANTES: anon key + policies "using (true)" = cualquiera lee/escribe todo.
-- DESPUES: solo usuarios con JWT valido y rol correcto.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Vincular tabla usuarios con auth.users
-- ------------------------------------------------------------
alter table usuarios
  add column if not exists auth_id uuid unique references auth.users (id) on delete set null;

create index if not exists idx_usuarios_auth_id on usuarios (auth_id);

-- Email interno por login (ej. juan.perez → juan.perez@solimat.internal)
-- Crealo al registrar usuarios en Auth o via Edge Function.

-- ------------------------------------------------------------
-- 2. Funciones helper para RLS (leen rol del JWT / perfil)
-- ------------------------------------------------------------
create or replace function public.current_user_rol()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select rol from usuarios where auth_id = auth.uid() and activo = true limit 1),
    ''
  );
$$;

create or replace function public.is_authenticated()
returns boolean
language sql
stable
as $$
  select auth.uid() is not null;
$$;

create or replace function public.has_rol(roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select current_user_rol() = any (roles);
$$;

-- ------------------------------------------------------------
-- 3. ELIMINAR policies publicas (anon sin login)
--    Ejecutar solo cuando todos los usuarios ya tengan auth_id.
-- ------------------------------------------------------------
drop policy if exists "app_meta_public_access" on app_meta;
drop policy if exists "solicitudes_public_access" on solicitudes;
drop policy if exists "detalles_public_access" on solicitud_detalles;
drop policy if exists "catalogo_public_access" on catalogo_bom;
drop policy if exists "usuarios_public_access" on usuarios;

-- ------------------------------------------------------------
-- 4. Policies con JWT (rol en tabla usuarios)
-- ------------------------------------------------------------

-- app_meta: solo admin
create policy "app_meta_admin"
  on app_meta for all
  using (has_rol(array['admin', 'todos']))
  with check (has_rol(array['admin', 'todos']));

-- solicitudes: leer autenticados; escribir segun rol
create policy "solicitudes_select_auth"
  on solicitudes for select
  using (is_authenticated());

create policy "solicitudes_insert_prod"
  on solicitudes for insert
  with check (has_rol(array['produccion', 'todos', 'admin']));

create policy "solicitudes_update_alm"
  on solicitudes for update
  using (has_rol(array['almacen', 'todos', 'admin']))
  with check (has_rol(array['almacen', 'todos', 'admin']));

create policy "solicitudes_admin"
  on solicitudes for all
  using (has_rol(array['admin', 'todos']))
  with check (has_rol(array['admin', 'todos']));

-- detalles: mismas reglas que solicitudes
create policy "detalles_select_auth"
  on solicitud_detalles for select
  using (is_authenticated());

create policy "detalles_insert_prod"
  on solicitud_detalles for insert
  with check (has_rol(array['produccion', 'todos', 'admin']));

create policy "detalles_update_alm"
  on solicitud_detalles for update
  using (has_rol(array['almacen', 'todos', 'admin']))
  with check (has_rol(array['almacen', 'todos', 'admin']));

create policy "detalles_admin"
  on solicitud_detalles for all
  using (has_rol(array['admin', 'todos']))
  with check (has_rol(array['admin', 'todos']));

-- catalogo: leer todos autenticados; escribir admin
create policy "catalogo_select_auth"
  on catalogo_bom for select
  using (is_authenticated());

create policy "catalogo_admin_write"
  on catalogo_bom for all
  using (has_rol(array['admin', 'todos']))
  with check (has_rol(array['admin', 'todos']));

-- usuarios: solo admin ve/gestiona (sin contrasena en select desde app)
create policy "usuarios_admin"
  on usuarios for all
  using (has_rol(array['admin', 'todos']))
  with check (has_rol(array['admin', 'todos']));

-- ------------------------------------------------------------
-- 5. Crear primer admin en Auth (Dashboard o SQL con extension)
--    En Dashboard: Authentication → Users → Add user
--    Email: admin@solimat.internal  Password: (segura)
--    Luego vincular:
-- ------------------------------------------------------------
-- insert into usuarios (id, nombre, usuario, contrasena, rol, activo, auth_id)
-- values (
--   '0001',
--   'Administrador',
--   'admin',
--   '',  -- ya no se usa; la clave vive en auth.users
--   'admin',
--   true,
--   'UUID-DEL-USUARIO-EN-AUTH-USERS'
-- );

-- ------------------------------------------------------------
-- 6. (Opcional) Rol en JWT como custom claim — Edge Function
--    Ver docs: supabase.com/docs/guides/auth/custom-claims-and-role-based-access-control-rbac
-- ------------------------------------------------------------

revoke execute on function verify_user_login(text, text) from anon;
-- Tras migrar, desactivar login RPC legacy.
