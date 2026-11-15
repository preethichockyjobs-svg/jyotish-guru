-- Jyotish Guru database. Paste this whole file into Supabase > SQL Editor > New query, then click Run.
-- Safe to run once on a new project.

create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  username    text unique not null check (username ~ '^[a-z0-9._-]{3,30}$'),
  full_name   text,
  role        text not null default 'astrologer' check (role in ('admin','astrologer','client')),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

create table if not exists public.clients (
  id          uuid primary key default gen_random_uuid(),
  owner       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null,
  dob         date not null,
  tob         time not null,
  gender      text,
  city        text,
  lat         numeric,
  lon         numeric,
  tz          numeric,
  focus       text,
  q           text,
  created_at  timestamptz not null default now(),
  unique (owner, name, dob)
);

-- Helper checks used by the security rules. They run with elevated rights so they can read profiles.
create or replace function public.is_active() returns boolean
language sql security definer set search_path = public stable as
$$ select exists (select 1 from public.profiles where id = auth.uid() and active) $$;

create or replace function public.is_admin() returns boolean
language sql security definer set search_path = public stable as
$$ select exists (select 1 from public.profiles where id = auth.uid() and active and role = 'admin') $$;

-- Row Level Security: this is what keeps each user's data separate.
alter table public.profiles enable row level security;
alter table public.clients  enable row level security;

drop policy if exists "profiles read"   on public.profiles;
drop policy if exists "profiles insert" on public.profiles;
drop policy if exists "profiles update" on public.profiles;
drop policy if exists "profiles delete" on public.profiles;
create policy "profiles read"   on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "profiles insert" on public.profiles for insert with check (public.is_admin());
create policy "profiles update" on public.profiles for update using (public.is_admin()) with check (public.is_admin());
create policy "profiles delete" on public.profiles for delete using (public.is_admin());

drop policy if exists "clients own"   on public.clients;
drop policy if exists "clients admin" on public.clients;
create policy "clients own"   on public.clients for all
  using (owner = auth.uid() and public.is_active())
  with check (owner = auth.uid() and public.is_active());
create policy "clients admin" on public.clients for select using (public.is_admin());

-- FIRST ADMIN (run after creating the user in Authentication > Users > Add user,
-- with email admin@jyotish.example, your password, and "Auto Confirm User" ticked):
--
-- insert into public.profiles (id, username, full_name, role)
-- select id, 'admin', 'Administrator', 'admin' from auth.users where email = 'admin@jyotish.example';
