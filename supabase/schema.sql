-- All Fits schema. Run once in Supabase: Dashboard -> SQL Editor -> paste -> Run.
-- Each record is one row; `data` holds the model's JSON (see *.toJson in lib/data/models).

create table if not exists public.clothing_items (
  user_id uuid not null references auth.users on delete cascade,
  id text not null,
  data jsonb not null,
  primary key (user_id, id)
);

create table if not exists public.outfits (like public.clothing_items including all);
create table if not exists public.calendar_entries (like public.clothing_items including all);
create table if not exists public.shopping_items (like public.clothing_items including all);

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users on delete cascade,
  data jsonb not null
);

-- Row-level security: every user reads and writes only their own rows.
do $$
declare t text;
begin
  foreach t in array array['clothing_items', 'outfits', 'calendar_entries', 'shopping_items', 'user_settings'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "own rows" on public.%I', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated
         using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
  end loop;
end $$;

-- Foreign keys from `like` are not copied, so add them for the cloned tables.
alter table public.outfits drop constraint if exists outfits_user_id_fkey,
  add constraint outfits_user_id_fkey foreign key (user_id) references auth.users on delete cascade;
alter table public.calendar_entries drop constraint if exists calendar_entries_user_id_fkey,
  add constraint calendar_entries_user_id_fkey foreign key (user_id) references auth.users on delete cascade;
alter table public.shopping_items drop constraint if exists shopping_items_user_id_fkey,
  add constraint shopping_items_user_id_fkey foreign key (user_id) references auth.users on delete cascade;

-- Clothing photos: public read, upload/delete only inside your own `<user id>/` folder.
insert into storage.buckets (id, name, public)
values ('wardrobe-images', 'wardrobe-images', true)
on conflict (id) do nothing;

drop policy if exists "upload own photos" on storage.objects;
create policy "upload own photos" on storage.objects for insert to authenticated
  with check (bucket_id = 'wardrobe-images' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Storage's remove() needs select as well as delete.
drop policy if exists "list own photos" on storage.objects;
create policy "list own photos" on storage.objects for select to authenticated
  using (bucket_id = 'wardrobe-images' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "delete own photos" on storage.objects;
create policy "delete own photos" on storage.objects for delete to authenticated
  using (bucket_id = 'wardrobe-images' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Premium bought through payOS (supabase/functions/payos, setup in docs/payos.md).
-- Only that Edge Function writes these tables, so nobody can grant themselves Premium.
create table if not exists public.payments (
  order_code bigint generated always as identity primary key,
  user_id uuid not null references auth.users on delete cascade,
  amount integer not null,
  status text not null default 'PENDING',
  checkout_url text,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);

create table if not exists public.subscriptions (
  user_id uuid primary key references auth.users on delete cascade,
  premium_since timestamptz not null,
  premium_until timestamptz not null
);

alter table public.payments enable row level security;
alter table public.subscriptions enable row level security;
drop policy if exists "read own rows" on public.payments;
create policy "read own rows" on public.payments for select to authenticated
  using ((select auth.uid()) = user_id);
drop policy if exists "read own rows" on public.subscriptions;
create policy "read own rows" on public.subscriptions for select to authenticated
  using ((select auth.uid()) = user_id);

-- Marks a payment paid and adds p_days of Premium, or extends it. The webhook and the
-- app's status check may both call it; only the first call counts. Returns the new end
-- of Premium, or null when nothing changed (already paid, unknown order, amount short).
create or replace function public.mark_payment_paid(p_order_code bigint, p_amount integer, p_days integer)
returns timestamptz
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid;
  v_until timestamptz;
begin
  update public.payments set status = 'PAID', paid_at = now()
  where order_code = p_order_code and status <> 'PAID' and p_amount >= amount
  returning user_id into v_user;
  if v_user is null then
    return null;
  end if;
  insert into public.subscriptions as s (user_id, premium_since, premium_until)
  values (v_user, now(), now() + make_interval(days => p_days))
  on conflict (user_id) do update set
    premium_since = case when s.premium_until > now() then s.premium_since else now() end,
    premium_until = greatest(s.premium_until, now()) + make_interval(days => p_days)
  returning premium_until into v_until;
  return v_until;
end $$;

revoke execute on function public.mark_payment_paid(bigint, integer, integer) from public, anon, authenticated;
grant execute on function public.mark_payment_paid(bigint, integer, integer) to service_role;
