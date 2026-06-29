-- ============================================================
-- SOLIMAT
-- Ejecuta esto en Supabase → SQL Editor
-- ============================================================

-- Tabla auxiliar: contador de folios (requestSeq en la app)
create table if not exists app_meta (
  id int primary key default 1 check (id = 1),
  request_seq int not null default 0,
  updated_at timestamptz not null default now()
);

insert into app_meta (id, request_seq)
values (1, 0)
on conflict (id) do nothing;

-- ------------------------------------------------------------
-- 1. Solicitudes (cabecera por folio)
-- ------------------------------------------------------------
create table if not exists solicitudes (
  folio text primary key,
  solicitado_por text not null default '',
  solicitado_por_usuario text not null default '',
  area text not null default '',
  estatus text not null default 'pendiente'
    check (estatus in ('pendiente', 'surtido', 'corto')),
  fecha_creacion text not null default '',
  fecha_atendida text not null default '',
  surtido_por text not null default '',
  tiempo_atencion_min int not null default 0,
  observaciones text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_solicitudes_estatus on solicitudes (estatus);
create index if not exists idx_solicitudes_area on solicitudes (area);
create index if not exists idx_solicitudes_fecha_creacion on solicitudes (fecha_creacion);

-- ------------------------------------------------------------
-- 2. Solicitud detalles (cada linea de material)
-- ------------------------------------------------------------
create table if not exists solicitud_detalles (
  id bigserial primary key,
  line_key text not null unique,
  folio_solicitud text not null references solicitudes (folio) on delete cascade,
  no_parte text not null default '',
  material_codigo text not null default '',
  descripcion text not null default '',
  cantidad_solicitada int not null default 1 check (cantidad_solicitada >= 1),
  cantidad_surtida int not null default 0 check (cantidad_surtida >= 0),
  estatus_linea text not null default 'pendiente'
    check (estatus_linea in ('pendiente', 'surtido', 'corto')),
  surtido_por text not null default '',
  fecha_atendida text not null default '',
  unidad_medida text not null default 'pza',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_detalles_folio on solicitud_detalles (folio_solicitud);
create index if not exists idx_detalles_estatus on solicitud_detalles (estatus_linea);
create index if not exists idx_detalles_material on solicitud_detalles (material_codigo);

-- ------------------------------------------------------------
-- 3. Catalogo BOM (materiales por area y parte)
-- ------------------------------------------------------------
create table if not exists catalogo_bom (
  id bigserial primary key,
  area text not null,
  no_parte text not null,
  material_codigo text not null,
  descripcion text not null,
  unidad_medida text not null default 'pza',
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (area, no_parte, material_codigo)
);

create index if not exists idx_catalogo_area on catalogo_bom (area);
create index if not exists idx_catalogo_parte on catalogo_bom (no_parte);
create index if not exists idx_catalogo_activo on catalogo_bom (activo);

-- ------------------------------------------------------------
-- 4. Usuarios (produccion, almacen, admin)
-- ------------------------------------------------------------
create table if not exists usuarios (
  id text primary key,
  nombre text not null,
  usuario text not null unique,
  contrasena text not null,  -- hash SHA-256: $sha256$ + hex (ver solimat_password_hash)
  rol text not null default 'produccion'
    check (rol in ('produccion', 'almacen', 'admin', 'todos')),
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_usuarios_rol on usuarios (rol);
create index if not exists idx_usuarios_activo on usuarios (activo);

-- ------------------------------------------------------------
-- Trigger: updated_at automatico
-- ------------------------------------------------------------
create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_solicitudes_updated_at on solicitudes;
create trigger trg_solicitudes_updated_at
before update on solicitudes
for each row execute function set_updated_at();

drop trigger if exists trg_detalles_updated_at on solicitud_detalles;
create trigger trg_detalles_updated_at
before update on solicitud_detalles
for each row execute function set_updated_at();

drop trigger if exists trg_catalogo_updated_at on catalogo_bom;
create trigger trg_catalogo_updated_at
before update on catalogo_bom
for each row execute function set_updated_at();

drop trigger if exists trg_usuarios_updated_at on usuarios;
create trigger trg_usuarios_updated_at
before update on usuarios
for each row execute function set_updated_at();

drop trigger if exists trg_app_meta_updated_at on app_meta;
create trigger trg_app_meta_updated_at
before update on app_meta
for each row execute function set_updated_at();

-- ------------------------------------------------------------
-- Row Level Security (acceso publico para demo / app interna)
-- En produccion, reemplaza estas policies por auth real.
-- ------------------------------------------------------------
alter table app_meta enable row level security;
alter table solicitudes enable row level security;
alter table solicitud_detalles enable row level security;
alter table catalogo_bom enable row level security;
alter table usuarios enable row level security;

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

-- ------------------------------------------------------------
-- Sin datos de prueba. Crea el primer administrador desde Supabase:
--
-- insert into usuarios (id, nombre, usuario, contrasena, rol, activo)
-- values ('0001', 'Administrador', 'usuario', 'clave', 'admin', true);
--
-- O importa un JSON desde Administrador en la app.
-- ------------------------------------------------------------

-- Si ya tenias la tabla creada, ejecuta esto para permitir rol "todos":
-- alter table usuarios drop constraint if exists usuarios_rol_check;
-- alter table usuarios add constraint usuarios_rol_check
--   check (rol in ('produccion', 'almacen', 'admin', 'todos'));
