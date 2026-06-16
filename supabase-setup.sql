-- Ejecuta esto en Supabase → SQL Editor

create table registros (
  id uuid default gen_random_uuid() primary key,
  titulo text not null,
  descripcion text,
  created_at timestamptz default now()
);

alter table registros enable row level security;

-- Solo para demo: permite leer y escribir a todos.
-- En producción, restringe por usuario autenticado.
create policy "demo_public_access"
  on registros for all
  using (true)
  with check (true);
