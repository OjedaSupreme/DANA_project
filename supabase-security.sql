-- ============================================================
-- SOLIMAT — Seguridad: login RPC + contraseñas SHA-256
-- Ejecutar en Supabase → SQL Editor
-- ============================================================

create extension if not exists pgcrypto;

-- Mismo algoritmo que index.html: SHA-256 de 'solimat:' + contraseña
create or replace function solimat_password_hash(plain text)
returns text
language sql
immutable
as $$
  select '$sha256$' || encode(digest('solimat:' || coalesce(plain, ''), 'sha256'), 'hex');
$$;

-- Login sin descargar la tabla completa de usuarios al navegador.
-- p_contrasena: hash $sha256$... (enviado por la app) o texto plano (legacy).
create or replace function verify_user_login(p_usuario text, p_contrasena text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  rec usuarios%rowtype;
  input_hash text;
begin
  if coalesce(trim(p_usuario), '') = '' or coalesce(trim(p_contrasena), '') = '' then
    return null;
  end if;

  if p_contrasena like '$sha256$%' then
    input_hash := p_contrasena;
  else
    input_hash := solimat_password_hash(p_contrasena);
  end if;

  select * into rec
  from usuarios
  where lower(trim(usuario)) = lower(trim(p_usuario))
    and activo = true
    and (
      contrasena = input_hash
      or contrasena = solimat_password_hash(p_contrasena)
      or contrasena = p_contrasena
    )
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

create or replace view usuarios_sin_clave as
  select id, nombre, usuario, rol, activo, created_at, updated_at
  from usuarios
  where activo = true;

grant select on usuarios_sin_clave to anon, authenticated;

-- Migrar contraseñas en texto plano existentes a SHA-256 (ejecutar una vez):
-- update usuarios
-- set contrasena = solimat_password_hash(contrasena)
-- where contrasena is not null
--   and contrasena <> ''
--   and contrasena not like '$sha256$%';
