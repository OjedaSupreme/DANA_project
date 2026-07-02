-- SOLIMAT — Columnas para codigo de verificacion por solicitud
-- Ejecutar en Supabase → SQL Editor

alter table solicitudes
  add column if not exists token_verificacion text not null default '',
  add column if not exists token_hash text not null default '';
