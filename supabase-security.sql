-- ============================================================
-- SOLIMAT — Endurecimiento de seguridad (ejecutar en SQL Editor)
-- ============================================================

-- Login sin descargar la tabla completa de usuarios al navegador.
-- Devuelve datos del usuario si credenciales correctas; NULL si no.
create or replace function verify_user_login(p_usuario text, p_contrasena text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  rec usuarios%rowtype;
begin
  if coalesce(trim(p_usuario), '') = '' or coalesce(trim(p_contrasena), '') = '' then
    return null;
  end if;
                            
  select * into rec
  from usuarios
  where lower(trim(usuario)) = lower(trim(p_usuario))
    and contrasena = p_contrasena
    and activo = true
  limit 1;

  if not found then
    return null;
  end if;

  return json_build_object(
    'id', rec.id,
    'name', rec.nombre,
    'user', rec.usuario,
    'role', rec.rol
  );
end;
$$;

revoke all on function verify_user_login(text, text) from public;
grant execute on function verify_user_login(text, text) to anon, authenticated;

-- Vista sin contrasenas (solo para panel admin autenticado en la app).
create or replace view usuarios_sin_clave as
  select id, nombre, usuario, rol, activo, created_at, updated_at
  from usuarios
  where activo = true;

grant select on usuarios_sin_clave to anon, authenticated;

-- IMPORTANTE: Las policies "public_access" permiten leer/escribir todo con la anon key.
-- Para produccion real, migrar a Supabase Auth + RLS por rol JWT.
-- Documentacion: https://supabase.com/docs/guides/auth/row-level-security
