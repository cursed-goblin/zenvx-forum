-- =============================================================
-- ZenVX Forum — initial schema, triggers, and RLS
-- =============================================================

-- ---------- TABLES ----------

-- PROFILES (1:1 with auth.users)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  avatar_url text,
  role text not null default 'member' check (role in ('member','moderator','admin')),
  created_at timestamptz not null default now()
);

-- CATEGORIES
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  description text,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

-- THREADS
create table public.threads (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  author_id  uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  slug  text not null,
  body  text not null,
  is_pinned  boolean not null default false,
  is_locked  boolean not null default false,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index threads_slug_idx on public.threads(slug);
create index threads_category_created_idx on public.threads(category_id, created_at desc);

-- POSTS (replies; nested via parent_post_id)
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.threads(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  parent_post_id uuid references public.posts(id) on delete cascade,
  body text not null,
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index posts_thread_created_idx on public.posts(thread_id, created_at);

-- VOTES (one per user per target)
create table public.votes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('thread','post')),
  target_id uuid not null,
  value smallint not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  unique (user_id, target_type, target_id)
);
create index votes_target_idx on public.votes(target_type, target_id);

-- REPORTS (moderation queue)
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('thread','post')),
  target_id uuid not null,
  reason text not null,
  status text not null default 'open' check (status in ('open','reviewed','actioned')),
  resolved_by uuid references public.profiles(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index reports_status_idx on public.reports(status, created_at);

-- ---------- FUNCTIONS & TRIGGERS ----------

-- Auto-insert a profiles row whenever a new auth user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8))
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Admin check used by RLS policies
create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- Aggregated vote scores
create or replace view public.target_scores as
select target_type, target_id,
       coalesce(sum(value), 0) as score,
       count(*) as vote_count
from public.votes
group by target_type, target_id;

-- ---------- ROW LEVEL SECURITY ----------

alter table public.profiles   enable row level security;
alter table public.categories enable row level security;
alter table public.threads    enable row level security;
alter table public.posts      enable row level security;
alter table public.votes      enable row level security;
alter table public.reports    enable row level security;

-- PROFILES: public read, self update
create policy "profiles public read" on public.profiles
  for select using (true);
create policy "profiles self update" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- CATEGORIES: public read, admin-managed
create policy "categories public read" on public.categories
  for select using (true);
create policy "categories admin manage" on public.categories
  for all using (public.is_admin()) with check (public.is_admin());

-- THREADS: anon read non-deleted; authed insert own; owner/admin update
create policy "threads public read" on public.threads
  for select using (is_deleted = false or public.is_admin());
create policy "threads authed insert" on public.threads
  for insert to authenticated with check (author_id = auth.uid());
create policy "threads owner/admin update" on public.threads
  for update using (author_id = auth.uid() or public.is_admin())
  with check (author_id = auth.uid() or public.is_admin());

-- POSTS: same pattern as threads
create policy "posts public read" on public.posts
  for select using (is_deleted = false or public.is_admin());
create policy "posts authed insert" on public.posts
  for insert to authenticated with check (author_id = auth.uid());
create policy "posts owner/admin update" on public.posts
  for update using (author_id = auth.uid() or public.is_admin())
  with check (author_id = auth.uid() or public.is_admin());

-- VOTES: public read counts; users manage only their own
create policy "votes public read" on public.votes
  for select using (true);
create policy "votes self manage" on public.votes
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- REPORTS: authed users file; only admins read/resolve
create policy "reports authed insert" on public.reports
  for insert to authenticated with check (reporter_id = auth.uid());
create policy "reports admin read" on public.reports
  for select using (public.is_admin());
create policy "reports admin update" on public.reports
  for update using (public.is_admin()) with check (public.is_admin());

-- NOTE: No DELETE policies anywhere => hard deletes are blocked for all clients.
-- "Deleting" content = setting is_deleted = true (allowed by owner/admin UPDATE).
