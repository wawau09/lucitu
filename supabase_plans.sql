create extension if not exists pgcrypto;

create table if not exists public.plans (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  plan_date date not null,
  plan_code text not null unique,
  item_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.plan_collaborators (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  collaborator_email text not null,
  role text not null default 'editor',
  created_at timestamptz not null default now(),
  unique (plan_id, collaborator_email)
);

create table if not exists public.plan_items (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.plans(id) on delete cascade,
  title text not null,
  place_name text,
  start_time text,
  note text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.plans enable row level security;
alter table public.plan_collaborators enable row level security;
alter table public.plan_items enable row level security;

create or replace function public.is_plan_member(p_plan_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    exists (
      select 1
      from public.plans p
      where p.id = p_plan_id
        and p.owner_id = auth.uid()
    )
    or exists (
      select 1
      from public.plan_collaborators c
      where c.plan_id = p_plan_id
        and lower(c.collaborator_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    );
$$;

drop policy if exists "plans_select_visible" on public.plans;
create policy "plans_select_visible"
  on public.plans
  for select
  to authenticated
  using (public.is_plan_member(id));

drop policy if exists "plans_insert_own" on public.plans;
create policy "plans_insert_own"
  on public.plans
  for insert
  to authenticated
  with check (auth.uid() = owner_id);

drop policy if exists "plans_update_own" on public.plans;
create policy "plans_update_own"
  on public.plans
  for update
  to authenticated
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

drop policy if exists "plans_delete_own" on public.plans;
create policy "plans_delete_own"
  on public.plans
  for delete
  to authenticated
  using (auth.uid() = owner_id);

drop policy if exists "plan_collaborators_select_visible" on public.plan_collaborators;
create policy "plan_collaborators_select_visible"
  on public.plan_collaborators
  for select
  to authenticated
  using (
    public.is_plan_member(plan_id)
    or lower(collaborator_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "plan_collaborators_insert_owner" on public.plan_collaborators;
create policy "plan_collaborators_insert_owner"
  on public.plan_collaborators
  for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.plans p
      where p.id = plan_id
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists "plan_collaborators_update_owner" on public.plan_collaborators;
create policy "plan_collaborators_update_owner"
  on public.plan_collaborators
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.plans p
      where p.id = plan_id
        and p.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.plans p
      where p.id = plan_id
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists "plan_collaborators_delete_owner" on public.plan_collaborators;
create policy "plan_collaborators_delete_owner"
  on public.plan_collaborators
  for delete
  to authenticated
  using (
    exists (
      select 1
      from public.plans p
      where p.id = plan_id
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists "plan_items_select_visible" on public.plan_items;
create policy "plan_items_select_visible"
  on public.plan_items
  for select
  to authenticated
  using (public.is_plan_member(plan_id));

drop policy if exists "plan_items_insert_visible" on public.plan_items;
create policy "plan_items_insert_visible"
  on public.plan_items
  for insert
  to authenticated
  with check (public.is_plan_member(plan_id));

drop policy if exists "plan_items_update_visible" on public.plan_items;
create policy "plan_items_update_visible"
  on public.plan_items
  for update
  to authenticated
  using (public.is_plan_member(plan_id))
  with check (public.is_plan_member(plan_id));

drop policy if exists "plan_items_delete_visible" on public.plan_items;
create policy "plan_items_delete_visible"
  on public.plan_items
  for delete
  to authenticated
  using (public.is_plan_member(plan_id));

create or replace function public.touch_plan_from_items()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.plans
      set item_count = (
        select count(*) from public.plan_items where plan_id = new.plan_id
      ),
      updated_at = now()
    where id = new.plan_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.plans
      set item_count = (
        select count(*) from public.plan_items where plan_id = old.plan_id
      ),
      updated_at = now()
    where id = old.plan_id;
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists trg_plan_items_touch_insert on public.plan_items;
create trigger trg_plan_items_touch_insert
after insert on public.plan_items
for each row execute function public.touch_plan_from_items();

drop trigger if exists trg_plan_items_touch_delete on public.plan_items;
create trigger trg_plan_items_touch_delete
after delete on public.plan_items
for each row execute function public.touch_plan_from_items();

create or replace function public.touch_plan_from_collaborators()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.plans
      set updated_at = now()
    where id = new.plan_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.plans
      set updated_at = now()
    where id = old.plan_id;
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists trg_plan_collaborators_touch_insert on public.plan_collaborators;
create trigger trg_plan_collaborators_touch_insert
after insert on public.plan_collaborators
for each row execute function public.touch_plan_from_collaborators();

drop trigger if exists trg_plan_collaborators_touch_delete on public.plan_collaborators;
create trigger trg_plan_collaborators_touch_delete
after delete on public.plan_collaborators
for each row execute function public.touch_plan_from_collaborators();

create or replace function public.create_plan_entry(
  p_name text,
  p_plan_date date
)
returns public.plans
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_plan public.plans;
begin
  if v_user_id is null then
    raise exception 'loginRequired';
  end if;

  insert into public.plans (
    owner_id,
    name,
    plan_date,
    plan_code
  )
  values (
    v_user_id,
    btrim(p_name),
    p_plan_date,
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 4))
  )
  returning * into v_plan;

  return v_plan;
end;
$$;

revoke all on function public.create_plan_entry(text, date) from public;
grant execute on function public.create_plan_entry(text, date) to authenticated;

create or replace function public.join_plan_by_code(
  p_plan_code text
)
returns public.plans
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text := lower(coalesce(
    auth.jwt() ->> 'email',
    (select email from auth.users where id = auth.uid()),
    (select raw_user_meta_data->>'email' from auth.users where id = auth.uid()),
    auth.uid()::text || '@user.local'
  ));
  v_plan public.plans;
  v_clean_code text := btrim(p_plan_code);
begin
  if v_user_id is null then
    raise exception 'loginRequired';
  end if;

  if v_clean_code = '' then
    raise exception 'planCodeRequired';
  end if;

  -- 1. 일치하는 계획 검색 (정확한 일치 우선, 그 후 접미사/부분 일치)
  select *
    into v_plan
    from public.plans
   where upper(plan_code) = upper(v_clean_code)
      or upper(plan_code) like '%' || upper(v_clean_code)
   order by case when upper(plan_code) = upper(v_clean_code) then 0 else 1 end
   limit 1;

  if not found then
    raise exception 'planNotFound';
  end if;

  if v_plan.owner_id = v_user_id then
    return v_plan;
  end if;

  insert into public.plan_collaborators (
    plan_id,
    collaborator_email,
    role
  )
  values (
    v_plan.id,
    v_email,
    'editor'
  )
  on conflict (plan_id, collaborator_email)
  do update set role = excluded.role;

  return v_plan;
end;
$$;

revoke all on function public.join_plan_by_code(text) from public;
grant execute on function public.join_plan_by_code(text) to authenticated;
