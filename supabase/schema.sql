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
create table if not exists public.collections (like public.clothing_items including all);

create table if not exists public.user_settings (
  user_id uuid primary key references auth.users on delete cascade,
  data jsonb not null
);

-- Row-level security: every user reads and writes only their own rows.
do $$
declare t text;
begin
  foreach t in array array['clothing_items', 'outfits', 'calendar_entries', 'shopping_items', 'collections', 'user_settings'] loop
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
alter table public.collections drop constraint if exists collections_user_id_fkey,
  add constraint collections_user_id_fkey foreign key (user_id) references auth.users on delete cascade;

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

-- Social: profiles, follows, blocks, public outfits and outfits made for someone else.
-- Rerunnable. The tables stay private to their owners; everything another user may
-- see goes through the security-definer functions below, which check blocks, private
-- accounts and follows, and copy only whitelisted fields (never price, notes or wear
-- history). Get a second pair of eyes on any change to who can see what.

create table if not exists public.profiles (
  user_id uuid primary key references auth.users on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_.]{3,20}$'),
  display_name text not null default '' check (char_length(display_name) <= 60),
  bio text not null default '' check (char_length(bio) <= 150),
  avatar_url text,
  is_private boolean not null default false,
  allow_styling boolean not null default true,
  updated_at timestamptz not null default now()
);

create table if not exists public.follows (
  follower_id uuid not null references auth.users on delete cascade,
  followee_id uuid not null references auth.users on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

create table if not exists public.blocks (
  blocker_id uuid not null references auth.users on delete cascade,
  blocked_id uuid not null references auth.users on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- One row per outfit shown on Discover.
create table if not exists public.outfit_posts (
  user_id uuid not null references auth.users on delete cascade,
  outfit_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, outfit_id)
);

-- Discover outfits someone kept as ideas.
create table if not exists public.saved_posts (
  user_id uuid not null references auth.users on delete cascade,
  owner_id uuid not null references auth.users on delete cascade,
  outfit_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, owner_id, outfit_id)
);

-- An outfit made from the recipient's own clothes. `data` is written only by
-- send_styled_outfit, which copies the pieces from the recipient's closet.
create table if not exists public.styled_outfits (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users on delete cascade,
  recipient_id uuid not null references auth.users on delete cascade,
  data jsonb not null,
  status text not null default 'pending' check (status in ('pending', 'saved', 'dismissed')),
  created_at timestamptz not null default now()
);

create table if not exists public.reports (
  id bigint generated always as identity primary key,
  reporter_id uuid not null references auth.users on delete cascade,
  target_id uuid not null references auth.users on delete cascade,
  outfit_id text,
  reason text not null check (char_length(reason) between 1 and 200),
  created_at timestamptz not null default now()
);

create or replace function public.is_blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a))
$$;

-- Public account: anyone signed in. Private: accepted followers only. Never across a block.
create or replace function public.can_view_closet(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select viewer = owner or (
    viewer is not null
    and not public.is_blocked_between(viewer, owner)
    and exists (
      select 1 from public.profiles p
      where p.user_id = owner and (
        not p.is_private or exists (
          select 1 from public.follows f
          where f.follower_id = viewer and f.followee_id = owner and f.status = 'accepted'))))
$$;

create or replace function public.can_style(viewer uuid, owner uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select viewer <> owner
    and public.can_view_closet(viewer, owner)
    and exists (select 1 from public.profiles where user_id = owner and allow_styling)
    and exists (select 1 from public.profiles where user_id = viewer)
$$;

-- What others see of a piece or an outfit. A whitelist, so new private fields stay private.
create or replace function public.public_item(d jsonb) returns jsonb
language sql immutable set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', d->'id', 'name', d->'name', 'imagePath', d->'imagePath', 'cutoutPath', d->'cutoutPath',
    'category', d->'category', 'subcategory', d->'subcategory', 'color', d->'color',
    'seasons', d->'seasons', 'brand', d->'brand', 'createdAt', d->'createdAt'))
$$;

create or replace function public.public_outfit(d jsonb) returns jsonb
language sql immutable set search_path = ''
as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'id', d->'id', 'name', d->'name', 'itemIds', d->'itemIds', 'occasion', d->'occasion',
    'seasons', d->'seasons', 'layout', d->'layout', 'createdAt', d->'createdAt'))
$$;

create or replace function public.profile_card(p public.profiles) returns jsonb
language sql stable set search_path = ''
as $$
  select jsonb_build_object('user_id', p.user_id, 'username', p.username,
    'display_name', p.display_name, 'avatar_url', p.avatar_url, 'is_private', p.is_private)
$$;

alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.blocks enable row level security;
alter table public.outfit_posts enable row level security;
alter table public.saved_posts enable row level security;
alter table public.styled_outfits enable row level security;
alter table public.reports enable row level security;

-- Username, name, photo and bio are public (as in Fits), except across a block.
drop policy if exists "read unblocked" on public.profiles;
create policy "read unblocked" on public.profiles for select to authenticated
  using (not public.is_blocked_between((select auth.uid()), user_id));
drop policy if exists "write own" on public.profiles;
create policy "write own" on public.profiles for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Follows are created by follow_user(); either side may end one, only the followee accepts.
drop policy if exists "read own" on public.follows;
create policy "read own" on public.follows for select to authenticated
  using ((select auth.uid()) in (follower_id, followee_id));
drop policy if exists "accept own" on public.follows;
create policy "accept own" on public.follows for update to authenticated
  using ((select auth.uid()) = followee_id) with check (status = 'accepted');
drop policy if exists "end own" on public.follows;
create policy "end own" on public.follows for delete to authenticated
  using ((select auth.uid()) in (follower_id, followee_id));
revoke update on public.follows from authenticated;
grant update (status) on public.follows to authenticated;

-- Blocks are created by block_user(); the blocker may read and lift them.
drop policy if exists "read own" on public.blocks;
create policy "read own" on public.blocks for select to authenticated
  using ((select auth.uid()) = blocker_id);
drop policy if exists "unblock own" on public.blocks;
create policy "unblock own" on public.blocks for delete to authenticated
  using ((select auth.uid()) = blocker_id);

drop policy if exists "own rows" on public.outfit_posts;
create policy "own rows" on public.outfit_posts for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id and exists (
    select 1 from public.outfits o where o.user_id = (select auth.uid()) and o.id = outfit_id));

drop policy if exists "own rows" on public.saved_posts;
create policy "own rows" on public.saved_posts for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "read own" on public.styled_outfits;
create policy "read own" on public.styled_outfits for select to authenticated
  using ((select auth.uid()) in (sender_id, recipient_id));
drop policy if exists "answer own" on public.styled_outfits;
create policy "answer own" on public.styled_outfits for update to authenticated
  using ((select auth.uid()) = recipient_id) with check ((select auth.uid()) = recipient_id);
drop policy if exists "delete own" on public.styled_outfits;
create policy "delete own" on public.styled_outfits for delete to authenticated
  using ((select auth.uid()) in (sender_id, recipient_id));
revoke update on public.styled_outfits from authenticated;
grant update (status) on public.styled_outfits to authenticated;

drop policy if exists "file own" on public.reports;
create policy "file own" on public.reports for insert to authenticated
  with check ((select auth.uid()) = reporter_id);

-- A profile with follower counts and what the caller may do with it; null when the
-- profile doesn't exist or its owner blocked the caller.
create or replace function public.profile_summary(p_user uuid) returns jsonb
language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'profile', to_jsonb(p) - 'updated_at',
    'followers', (select count(*) from public.follows where followee_id = p.user_id and status = 'accepted'),
    'following', (select count(*) from public.follows where follower_id = p.user_id and status = 'accepted'),
    'my_follow', (select status from public.follows where follower_id = auth.uid() and followee_id = p.user_id),
    'follows_me', exists (select 1 from public.follows
      where follower_id = p.user_id and followee_id = auth.uid() and status = 'accepted'),
    'blocked_by_me', exists (select 1 from public.blocks where blocker_id = auth.uid() and blocked_id = p.user_id),
    'can_view_closet', public.can_view_closet(auth.uid(), p.user_id),
    'can_style', public.can_style(auth.uid(), p.user_id))
  from public.profiles p
  where p.user_id = p_user
    and not exists (select 1 from public.blocks b where b.blocker_id = p.user_id and b.blocked_id = auth.uid())
$$;

-- Someone's unarchived clothes and their outfits, or null when the caller may not see them.
create or replace function public.profile_closet(p_user uuid) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.can_view_closet(auth.uid(), p_user) then
    return null;
  end if;
  return jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(public.public_item(c.data) order by c.data->>'createdAt' desc)
      from public.clothing_items c
      where c.user_id = p_user and coalesce((c.data->>'isArchived')::boolean, false) = false), '[]'),
    'outfits', coalesce((
      select jsonb_agg(public.public_outfit(o.data) order by o.data->>'createdAt' desc)
      from public.outfits o where o.user_id = p_user), '[]'));
end $$;

-- Public outfits, newest first. 'latest': public accounts; 'following': people the
-- caller follows (private ones too, once accepted); 'saved': the caller's saved ideas.
create or replace function public.discover_feed(
  p_filter text default 'latest', p_before timestamptz default null, p_limit integer default 30)
returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(post order by posted_at desc), '[]') from (
    select p.created_at as posted_at, jsonb_build_object(
      'owner', public.profile_card(pr),
      'posted_at', p.created_at,
      'saved', exists (select 1 from public.saved_posts s
        where s.user_id = auth.uid() and s.owner_id = p.user_id and s.outfit_id = p.outfit_id),
      'outfit', public.public_outfit(o.data),
      'items', (select coalesce(jsonb_agg(public.public_item(c.data)), '[]')
        from public.clothing_items c
        where c.user_id = p.user_id and o.data->'itemIds' ? c.id)) as post
    from public.outfit_posts p
    join public.profiles pr on pr.user_id = p.user_id
    join public.outfits o on o.user_id = p.user_id and o.id = p.outfit_id
    where public.can_view_closet(auth.uid(), p.user_id)
      and (p_before is null or p.created_at < p_before)
      and case p_filter
        when 'following' then exists (select 1 from public.follows f
          where f.follower_id = auth.uid() and f.followee_id = p.user_id and f.status = 'accepted')
        when 'saved' then exists (select 1 from public.saved_posts s
          where s.user_id = auth.uid() and s.owner_id = p.user_id and s.outfit_id = p.outfit_id)
        else not pr.is_private or p.user_id = auth.uid()
      end
    order by p.created_at desc
    limit least(greatest(p_limit, 1), 60)
  ) page
$$;

-- Follows a public account straight away, or asks a private one. Returns the status.
create or replace function public.follow_user(p_target uuid) returns text
language plpgsql security definer set search_path = ''
as $$
declare
  v_status text;
begin
  if auth.uid() is null or p_target = auth.uid() then
    raise exception 'You can''t follow yourself.';
  end if;
  if not exists (select 1 from public.profiles where user_id = auth.uid()) then
    raise exception 'Create your profile first.';
  end if;
  if public.is_blocked_between(auth.uid(), p_target) then
    raise exception 'You can''t follow this account.';
  end if;
  select case when is_private then 'pending' else 'accepted' end into v_status
  from public.profiles where user_id = p_target;
  if v_status is null then
    raise exception 'This account no longer exists.';
  end if;
  insert into public.follows (follower_id, followee_id, status)
  values (auth.uid(), p_target, v_status)
  on conflict (follower_id, followee_id) do nothing;
  select status into v_status from public.follows
  where follower_id = auth.uid() and followee_id = p_target;
  return v_status;
end $$;

-- Blocking ends follows both ways and drops outfits they made for you that you haven't answered.
create or replace function public.block_user(p_target uuid) returns void
language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or p_target = auth.uid() then
    raise exception 'You can''t block yourself.';
  end if;
  insert into public.blocks (blocker_id, blocked_id) values (auth.uid(), p_target)
  on conflict do nothing;
  delete from public.follows
  where (follower_id = auth.uid() and followee_id = p_target)
     or (follower_id = p_target and followee_id = auth.uid());
  delete from public.styled_outfits
  where status = 'pending' and sender_id = p_target and recipient_id = auth.uid();
end $$;

-- ponytail: no rate limit on sending; add one if people get spammed.
create or replace function public.send_styled_outfit(
  p_recipient uuid, p_name text, p_message text, p_item_ids text[], p_layout jsonb)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_items jsonb;
  v_id uuid;
begin
  if not public.can_style(auth.uid(), p_recipient) then
    raise exception 'You can''t create outfits for this person.';
  end if;
  if char_length(coalesce(p_name, '')) > 60 or char_length(coalesce(p_message, '')) > 300
     or jsonb_typeof(coalesce(p_layout, '[]')) <> 'array' or jsonb_array_length(coalesce(p_layout, '[]')) > 50 then
    raise exception 'This outfit can''t be sent.';
  end if;
  select jsonb_agg(public.public_item(c.data)) into v_items
  from public.clothing_items c
  where c.user_id = p_recipient and c.id = any(p_item_ids)
    and coalesce((c.data->>'isArchived')::boolean, false) = false;
  if v_items is null then
    raise exception 'Pick at least one piece.';
  end if;
  insert into public.styled_outfits (sender_id, recipient_id, data)
  values (auth.uid(), p_recipient, jsonb_build_object(
    'name', nullif(trim(p_name), ''), 'message', nullif(trim(p_message), ''),
    'itemIds', to_jsonb(p_item_ids), 'layout', coalesce(p_layout, '[]'), 'items', v_items))
  returning id into v_id;
  return v_id;
end $$;

-- Outfits made for the caller (unless dismissed) and by the caller, newest first.
create or replace function public.styled_outfits_list() returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', s.id, 'data', s.data, 'status', s.status, 'created_at', s.created_at,
    'incoming', s.recipient_id = auth.uid(), 'other', public.profile_card(pr))
    order by s.created_at desc), '[]')
  from public.styled_outfits s
  join public.profiles pr on pr.user_id =
    case when s.recipient_id = auth.uid() then s.sender_id else s.recipient_id end
  where (s.recipient_id = auth.uid() and s.status <> 'dismissed') or s.sender_id = auth.uid()
$$;

-- Everyone who follows the caller or whom the caller follows, including pending requests.
create or replace function public.my_connections() returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'profile', public.profile_card(pr), 'follower', c.follower, 'status', c.status)
    order by c.created_at desc), '[]')
  from (
    select follower_id as other, true as follower, status, created_at
    from public.follows where followee_id = auth.uid()
    union all
    select followee_id, false, status, created_at
    from public.follows where follower_id = auth.uid()
  ) c
  join public.profiles pr on pr.user_id = c.other
$$;

create or replace function public.blocked_profiles() returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(public.profile_card(pr) order by b.created_at desc), '[]')
  from public.blocks b join public.profiles pr on pr.user_id = b.blocked_id
  where b.blocker_id = auth.uid()
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'is_blocked_between(uuid, uuid)', 'can_view_closet(uuid, uuid)', 'can_style(uuid, uuid)',
    'public_item(jsonb)', 'public_outfit(jsonb)', 'profile_card(public.profiles)',
    'profile_summary(uuid)', 'profile_closet(uuid)', 'discover_feed(text, timestamptz, integer)',
    'follow_user(uuid)', 'block_user(uuid)', 'send_styled_outfit(uuid, text, text, text[], jsonb)',
    'styled_outfits_list()', 'my_connections()', 'blocked_profiles()'] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
