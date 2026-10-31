-- Minimal stand-in for Supabase's auth schema so the migration can be tested on plain Postgres.
create schema auth;
create table auth.users (id uuid primary key, email text);
create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
create function auth.uid() returns uuid language sql stable as $$ select nullif(auth.jwt() ->> 'sub', '')::uuid $$;
create extension pgcrypto;
create publication supabase_realtime;
grant usage on schema public, auth to anon, authenticated;
alter default privileges in schema public grant all on tables to anon, authenticated;
