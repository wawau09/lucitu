-- Enable pgcrypto for UUID generation
create extension if not exists pgcrypto;

-- 1. Store Menus Table (카페 메뉴 테이블)
create table if not exists public.store_menus (
  id uuid primary key default gen_random_uuid(),
  store_id text not null,
  category text not null default '음료',
  name text not null,
  price integer not null default 0,
  description text,
  image_url text,
  is_available boolean not null default true,
  options jsonb default '[]'::jsonb, -- e.g. [{"name": "온도", "values": ["HOT", "ICE"]}, {"name": "샷추가", "price": 500}]
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Orders Table (주문 헤더 테이블)
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null, -- e.g. 'A-101'
  store_id text not null,
  user_id uuid references auth.users(id) on delete set null,
  user_name text not null default '손님',
  user_phone text,
  status text not null default 'pending', -- pending, accepted, preparing, ready, completed, cancelled
  total_amount integer not null default 0,
  user_note text,
  estimated_minutes integer default 10,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Order Items Table (주문 상세 항목 테이블)
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  menu_id uuid references public.store_menus(id) on delete set null,
  menu_name text not null,
  price integer not null default 0,
  quantity integer not null default 1,
  selected_options text, -- e.g. "ICE / 샷 1개 추가 (+500원)"
  subtotal integer not null default 0,
  created_at timestamptz not null default now()
);

-- RLS Policies
alter table public.store_menus enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- Store Menus: Everyone can read
drop policy if exists "store_menus_select_all" on public.store_menus;
create policy "store_menus_select_all" on public.store_menus
  for select using (true);

-- Orders: Everyone authenticated or anon can select and insert
drop policy if exists "orders_select_all" on public.orders;
create policy "orders_select_all" on public.orders
  for select using (true);

drop policy if exists "orders_insert_all" on public.orders;
create policy "orders_insert_all" on public.orders
  for insert with check (true);

drop policy if exists "orders_update_all" on public.orders;
create policy "orders_update_all" on public.orders
  for update using (true);

-- Order Items: Everyone can select/insert
drop policy if exists "order_items_select_all" on public.order_items;
create policy "order_items_select_all" on public.order_items
  for select using (true);

drop policy if exists "order_items_insert_all" on public.order_items;
create policy "order_items_insert_all" on public.order_items
  for insert with check (true);

-- Enable Supabase Realtime for orders table
alter publication supabase_realtime add table public.orders;
