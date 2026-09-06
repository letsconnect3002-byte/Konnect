-- =====================================================================
-- MANDALA — CIRCLE FEED
-- MVP schema: posts, replies, seen-tracking, reachability, feed retrieval
--
-- Run this once in the Supabase SQL editor. It's written to be safely
-- re-runnable (IF NOT EXISTS / CREATE OR REPLACE / DROP-then-CREATE for
-- triggers) in case you need to tweak and re-apply during development.
--
-- Deliberately NOT included, per current scope:
--   - Row Level Security policies (flagged as a pre-launch item, not an
--     MVP blocker — see the notes in the agent prompt doc)
--   - Table partitioning, cached reachability, cleanup jobs — none of
--     these are needed at MVP scale; notes on when to add them are in
--     the accompanying prompt doc.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. POSTS TABLE
-- ---------------------------------------------------------------------
-- root_post_id is always set (self-referencing for a top-level post,
-- inherited from the parent for a reply). This means "top-level post"
-- is always just `id = root_post_id`, and "everything in this thread"
-- is always just `root_post_id = :id` — no nullable special-casing
-- needed anywhere that queries this table.

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id bigint not null references public.profiles(id),
  content text not null,
  reply_to_post_id uuid references public.posts(id),
  root_post_id uuid not null references public.posts(id),
  reply_count integer not null default 0,
  reaction_counts jsonb not null default '{}'::jsonb,
  is_deleted boolean not null default false,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  constraint posts_content_length check (char_length(content) between 1 and 500)
);

-- Feed queries: "recent top-level posts from these authors, not deleted"
create index if not exists posts_author_created_idx
  on public.posts (author_id, created_at desc)
  where is_deleted = false;

-- Thread queries: "everything under this root, oldest first"
create index if not exists posts_root_created_idx
  on public.posts (root_post_id, created_at asc);

-- ---------------------------------------------------------------------
-- 2. TRIGGERS — root_post_id resolution + reply_count maintenance
-- ---------------------------------------------------------------------
-- These stay server-side deliberately: root_post_id has to be correct
-- and consistent regardless of what the client sends (it's what the
-- feed/thread queries filter and index on), and reply_count has to be
-- updated atomically — a client-side "read then write +1" is a race
-- condition the moment two replies land close together.

create or replace function public.posts_before_insert()
returns trigger
language plpgsql
as $$
declare
  parent_root uuid;
begin
  if new.reply_to_post_id is null then
    -- top-level post: it is its own root
    new.root_post_id := new.id;
  else
    select root_post_id into parent_root
    from public.posts
    where id = new.reply_to_post_id;

    if parent_root is null then
      raise exception 'Cannot reply to a post that does not exist';
    end if;

    new.root_post_id := parent_root;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_posts_before_insert on public.posts;
create trigger trg_posts_before_insert
  before insert on public.posts
  for each row
  execute function public.posts_before_insert();


create or replace function public.posts_after_insert()
returns trigger
language plpgsql
as $$
declare
  v_parent_author_id bigint;
  v_parent_author_name text;
  v_reply_snippet text;
  v_note_json text;
  v_actor_anon_name text;
begin
  if new.reply_to_post_id is not null then
    -- 1. Increment reply_count
    update public.posts
    set reply_count = reply_count + 1
    where id = new.root_post_id;

    -- 2. Fetch parent post author with strict anonymity respect
    select p.author_id,
           case
             when p.is_anonymous = true then coalesce(nullif(pr.anon_name, ''), 'Anonymous')
             else coalesce(nullif(pr.name, ''), 'a post')
           end
    into v_parent_author_id, v_parent_author_name
    from public.posts p
    left join public.profiles pr on pr.id = p.author_id
    where p.id = new.reply_to_post_id;

    if v_parent_author_name is null or v_parent_author_name = '' then
      v_parent_author_name := 'a post';
    end if;

    -- 3. Prepare snippet
    if length(new.content) > 50 then
      v_reply_snippet := substring(new.content from 1 for 50) || '...';
    else
      v_reply_snippet := new.content;
    end if;

    -- 4. Determine replier anonymous alias if anonymous
    if new.is_anonymous = true then
      select coalesce(nullif(anon_name, ''), 'Anonymous')
      into v_actor_anon_name
      from public.profiles
      where id = new.author_id;
      if v_actor_anon_name is null or v_actor_anon_name = '' then
        v_actor_anon_name := 'Anonymous';
      end if;
    end if;

    v_note_json := json_build_object(
      'real_type', 'feed_connection_reply',
      'post_id', new.id::text,
      'root_post_id', new.root_post_id::text,
      'parent_author_name', v_parent_author_name,
      'reply_snippet', v_reply_snippet,
      'is_anonymous', coalesce(new.is_anonymous, false),
      'actor_name', case when new.is_anonymous = true then v_actor_anon_name else null end
    )::text;

    -- 5. Dispatch connection reply notification to eligible 1st-degree connections with 24h deduplication
    insert into public.connection_notifications (
      user_id,
      other_user_id,
      type,
      note,
      is_seen,
      created_at
    )
    select 
      ng.primary_user_id,
      new.author_id,
      'feed_connection_reply',
      v_note_json,
      false,
      now()
    from public.network_graph ng
    where ng.connected_user_id = new.author_id
      and (new.visibility = 'both' or ng.shared_card = 'both' or ng.shared_card = new.visibility)
      and ng.primary_user_id != new.author_id
      and (v_parent_author_id is null or ng.primary_user_id != v_parent_author_id)
      and not exists (
        select 1 from public.connection_notifications cn
        where cn.user_id = ng.primary_user_id
          and cn.type = 'feed_connection_reply'
          and cn.note like '%"root_post_id":"' || new.root_post_id::text || '"%'
          and cn.created_at > (now() - interval '24 hours')
      );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_posts_after_insert on public.posts;
create trigger trg_posts_after_insert
  after insert on public.posts
  for each row
  execute function public.posts_after_insert();

create or replace function public.posts_after_update_or_delete()
returns trigger
language plpgsql
as $$
begin
  -- 1. Handling DELETE (hard delete)
  if tg_op = 'DELETE' then
    if old.reply_to_post_id is not null and old.is_deleted = false then
      update public.posts
      set reply_count = greatest(0, reply_count - 1)
      where id = old.root_post_id;
    end if;
    return old;
  end if;

  -- 2. Handling UPDATE (soft delete or undelete)
  if tg_op = 'UPDATE' then
    if old.reply_to_post_id is not null then
      -- Newly marked as deleted
      if old.is_deleted = false and new.is_deleted = true then
        update public.posts
        set reply_count = greatest(0, reply_count - 1)
        where id = old.root_post_id;
      -- Restored / un-deleted
      elsif old.is_deleted = true and new.is_deleted = false then
        update public.posts
        set reply_count = reply_count + 1
        where id = new.root_post_id;
      end if;
    end if;
    return new;
  end if;

  return null;
end;
$$;

drop trigger if exists trg_posts_after_update_or_delete on public.posts;
create trigger trg_posts_after_update_or_delete
  after update of is_deleted or delete on public.posts
  for each row
  execute function public.posts_after_update_or_delete();

create or replace function public.post_reactions_after_change()
returns trigger
language plpgsql
security definer
as $$
declare
  target_post_id uuid;
  counts_json jsonb;
begin
  target_post_id := coalesce(NEW.post_id, OLD.post_id);
  if target_post_id is not null then
    select coalesce(
      jsonb_object_agg(sub.reaction_type, sub.cnt),
      '{}'::jsonb
    ) into counts_json
    from (
      select pr.reaction_type, count(*)::int as cnt
      from public.post_reactions pr
      where pr.post_id = target_post_id
      group by pr.reaction_type
    ) sub;

    update public.posts
    set reaction_counts = counts_json,
        updated_at = timezone('utc'::text, now())
    where id = target_post_id;
  end if;
  return coalesce(NEW, OLD);
end;
$$;

drop trigger if exists trg_post_reactions_after_change on public.post_reactions;
create trigger trg_post_reactions_after_change
  after insert or update or delete on public.post_reactions
  for each row
  execute function public.post_reactions_after_change();

-- ---------------------------------------------------------------------
-- 3. SEEN TRACKING
-- ---------------------------------------------------------------------
-- Composite primary key does two jobs: it's the index the "have I seen
-- this" check needs, and it makes the write naturally idempotent
-- (ON CONFLICT DO NOTHING costs nothing extra on a repeat).

create table if not exists public.post_seen (
  viewer_id bigint not null references public.profiles(id),
  post_id uuid not null references public.posts(id),
  seen_at timestamp with time zone not null default timezone('utc'::text, now()),
  primary key (viewer_id, post_id)
);

-- ---------------------------------------------------------------------
-- 4. REPORTING — reuse the existing pipeline
-- ---------------------------------------------------------------------
-- No content snapshot column needed: posts are soft-deleted, so the
-- reported content is still readable via post_id even after removal.

alter table public.content_reports
  add column if not exists post_id uuid references public.posts(id);

-- ---------------------------------------------------------------------
-- 5. SUPPORTING INDEX ON user_connections
-- ---------------------------------------------------------------------
-- The existing primary key (user_id_1, user_id_2) only makes lookups
-- starting from user_id_1 fast. network_graph's second branch looks
-- things up from user_id_2, so it needs its own index too.

create index if not exists user_connections_user_2_idx
  on public.user_connections (user_id_2);

-- ---------------------------------------------------------------------
-- 6. REACHABILITY — bounded 3-hop walk, computed live at read time
-- ---------------------------------------------------------------------
-- No cache table for MVP. This runs on every feed load, which is fine
-- at MVP-scale connection graphs. Add a precomputed/cached version
-- later only if feed loads start measurably slowing down.

create or replace function public.get_network_reach(
  p_viewer_id bigint,
  p_visibility text default 'both',
  p_max_degree int default 3
)
returns table (reachable_user_id bigint, degree int)
language sql
stable
as $$
  with recursive reach as (
    -- Degree 1: Direct connections
    select 
      ng.connected_user_id as user_id, 
      1 as degree,
      array[p_viewer_id, ng.connected_user_id] as path
    from public.network_graph ng
    where ng.primary_user_id = p_viewer_id
      and (p_visibility = 'both' or ng.shared_card = 'both' or ng.shared_card = p_visibility)

    union all

    -- Degree 2+: Multi-hop connections
    select 
      ng.connected_user_id, 
      r.degree + 1,
      r.path || ng.connected_user_id
    from reach r
    join public.network_graph ng on ng.primary_user_id = r.user_id
    where r.degree < p_max_degree
      and not (ng.connected_user_id = any(r.path))
      and (p_visibility = 'both' or ng.shared_card = 'both' or ng.shared_card = p_visibility)
      -- Exclude anyone who is ALREADY a 1st-degree connection to the viewer!
      and not exists (
        select 1 
        from public.network_graph direct_ng 
        where direct_ng.primary_user_id = p_viewer_id 
          and direct_ng.connected_user_id = ng.connected_user_id
      )
  )
  select user_id as reachable_user_id, min(degree) as degree
  from reach
  where user_id <> p_viewer_id
    and not exists (
      select 1 from public.blocked_users b
      where (b.blocker_id = p_viewer_id and b.blocked_id = user_id)
         or (b.blocker_id = user_id and b.blocked_id = p_viewer_id)
    )
  group by user_id;
$$;

-- ---------------------------------------------------------------------
-- 7. THE FEED — unseen-first, then seen, both by recency
-- ---------------------------------------------------------------------
-- One call returns one page, already filtered, bucketed, and ordered.
-- Cursor-paginated (never OFFSET) so page N costs the same as page 1
-- regardless of how deep someone scrolls.

create or replace function public.get_feed(
  p_viewer_id bigint,
  p_bucket text default 'unseen',
  p_cursor_created_at timestamptz default null,
  p_cursor_post_id uuid default null,
  p_limit int default 20,
  p_scope text default 'network'
)
returns table (
  post_id uuid,
  author_id bigint,
  author_name text,
  author_avatar_url text,
  content text,
  created_at timestamptz,
  reply_count int,
  active_reply_count int,
  degree int,
  user_reaction text,
  reaction_counts jsonb,
  visibility text
)
language plpgsql
stable
as $$
begin
  if p_bucket not in ('unseen', 'seen', 'all') then
    raise exception 'p_bucket must be ''unseen'', ''seen'', or ''all''';
  end if;

  return query
  select
    p.id,
    p.author_id,
    pr.name,
    pr.avatar_url,
    p.content,
    p.created_at,
    p.reply_count,
    (
      select count(*)::int
      from public.posts r
      where r.root_post_id = p.id
        and r.id != p.id
        and r.is_deleted = false
    ) as active_reply_count,
    coalesce(va.deg, case when p.author_id = p_viewer_id then 0 else 3 end) as degree,
    (
      select pr_user.reaction_type
      from public.post_reactions pr_user
      where pr_user.post_id = p.id and pr_user.user_id = p_viewer_id
      limit 1
    ) as user_reaction,
    coalesce(
      (
        select jsonb_object_agg(sub.reaction_type, sub.cnt)
        from (
          select pr_agg.reaction_type, count(*)::int as cnt
          from public.post_reactions pr_agg
          where pr_agg.post_id = p.id
          group by pr_agg.reaction_type
        ) sub
      ),
      '{}'::jsonb
    ) as reaction_counts,
    p.visibility
  from public.posts p
  join public.profiles pr on pr.id = p.author_id
  left join lateral (
    select 0 as deg
    where p.author_id = p_viewer_id
    union all
    select r.degree as deg
    from public.get_network_reach(p_viewer_id) r
    where r.reachable_user_id = p.author_id
    limit 1
  ) va on true
  where p.id = p.root_post_id          -- feed shows top-level posts only
    and p.is_deleted = false
    and (
      p_scope = 'global'
      or p.author_id = p_viewer_id
      or exists (
        select 1
        from public.get_network_reach(p_viewer_id, p.visibility) vr
        where vr.reachable_user_id = p.author_id
      )
    )
    and (
      p_bucket = 'all'
      or
      (p_bucket = 'unseen' and not exists (
        select 1 from public.post_seen ps
        where ps.viewer_id = p_viewer_id and ps.post_id = p.id
      ))
      or
      (p_bucket = 'seen' and exists (
        select 1 from public.post_seen ps
        where ps.viewer_id = p_viewer_id and ps.post_id = p.id
      ))
    )
    and (
      p_cursor_created_at is null
      or (p.created_at, p.id) < (p_cursor_created_at, p_cursor_post_id)
    )
  order by p.created_at desc, p.id desc
  limit least(p_limit, 50);
end;
$$;

-- ---------------------------------------------------------------------
-- 8. A THREAD — root post + every reply, in one call
-- ---------------------------------------------------------------------
-- Includes soft-deleted rows on purpose: the client renders those as
-- "this post was removed" placeholders rather than breaking the thread.

create or replace function public.get_thread(
  p_root_post_id uuid,
  p_viewer_id bigint default null
)
returns table (
  post_id uuid,
  author_id bigint,
  author_name text,
  author_avatar_url text,
  content text,
  created_at timestamptz,
  reply_count int,
  degree int,
  is_deleted boolean,
  reply_to_post_id uuid,
  user_reaction text,
  reaction_counts jsonb
)
language sql
stable
as $$
  with visible_authors as (
    select p_viewer_id as user_id, 0 as deg
    union all
    select r.reachable_user_id, r.degree as deg
    from public.get_network_reach(p_viewer_id) r
    where p_viewer_id is not null
  )
  select
    p.id,
    p.author_id,
    pr.name,
    pr.avatar_url,
    p.content,
    p.created_at,
    p.reply_count,
    coalesce(va.deg, case when p_viewer_id is not null and p.author_id = p_viewer_id then 0 else 3 end) as degree,
    p.is_deleted,
    p.reply_to_post_id,
    (
      select pr_user.reaction_type
      from public.post_reactions pr_user
      where pr_user.post_id = p.id and pr_user.user_id = p_viewer_id
      limit 1
    ) as user_reaction,
    coalesce(
      (
        select jsonb_object_agg(sub.reaction_type, sub.cnt)
        from (
          select pr_agg.reaction_type, count(*)::int as cnt
          from public.post_reactions pr_agg
          where pr_agg.post_id = p.id
          group by pr_agg.reaction_type
        ) sub
      ),
      '{}'::jsonb
    ) as reaction_counts
  from public.posts p
  join public.profiles pr on pr.id = p.author_id
  left join visible_authors va on va.user_id = p.author_id
  where p.root_post_id = p_root_post_id
  order by p.created_at asc;
$$;

-- ---------------------------------------------------------------------
-- 9. MARK POSTS SEEN — one batched call covers many posts
-- ---------------------------------------------------------------------

create or replace function public.mark_posts_seen(
  p_viewer_id bigint,
  p_post_ids uuid[]
)
returns void
language sql
as $$
  insert into public.post_seen (viewer_id, post_id)
  select p_viewer_id, unnest(p_post_ids)
  on conflict (viewer_id, post_id) do nothing;
$$;

-- ---------------------------------------------------------------------
-- 10. UNSEEN COUNT — for a "N new" badge, capped so it stays cheap
-- ---------------------------------------------------------------------

create or replace function public.get_unseen_count(
  p_viewer_id bigint,
  p_cap int default 20,
  p_scope text default 'network'
)
returns int
language sql
stable
as $$
  select count(*)::int from (
    select p.id
    from public.posts p
    left join lateral (
      select r.degree
      from public.get_network_reach(p_viewer_id, p.visibility) r
      where r.reachable_user_id = p.author_id
      limit 1
    ) va on true
    where p.id = p.root_post_id
      and p.is_deleted = false
      and p.author_id != p_viewer_id
      and (p_scope = 'global' or va.degree is not null)
      and not exists (
        select 1 from public.post_seen ps
        where ps.viewer_id = p_viewer_id and ps.post_id = p.id
      )
    limit p_cap
  ) capped;
$$;

-- ---------------------------------------------------------------------
-- 11. MUTUAL CONNECTIONS — optional helper for the Connect modal
-- ---------------------------------------------------------------------
-- Only needed if your existing referral pipeline doesn't already
-- expose a reusable "who connects me to this person" query. If it
-- does, skip this and call that instead.

create or replace function public.get_mutual_connections(
  p_viewer_id bigint,
  p_target_id bigint
)
returns table (mutual_user_id bigint, mutual_name text, mutual_avatar_url text)
language sql
stable
as $$
  select pr.id, pr.name, pr.avatar_url
  from public.network_graph ng1
  join public.network_graph ng2
    on ng2.primary_user_id = p_target_id
   and ng2.connected_user_id = ng1.connected_user_id
  join public.profiles pr on pr.id = ng1.connected_user_id
  where ng1.primary_user_id = p_viewer_id;
$$;

-- ---------------------------------------------------------------------
-- 13. REACTION SUMMARY RPCS (FOR RECONNECT RECONCILIATION)
-- ---------------------------------------------------------------------

create or replace function public.get_posts_reaction_summaries(
  p_post_ids uuid[],
  p_viewer_id bigint default null
)
returns jsonb
language plpgsql
stable
security definer
as $$
begin
  return coalesce(
    (
      select jsonb_object_agg(
        p.id,
        jsonb_build_object(
          'post_id', p.id,
          'reaction_counts', p.reaction_counts,
          'user_reaction', (
            select pr.reaction_type
            from public.post_reactions pr
            where pr.post_id = p.id and pr.user_id = p_viewer_id
            limit 1
          )
        )
      )
      from public.posts p
      where p.id = any(p_post_ids)
    ),
    '{}'::jsonb
  );
end;
$$;

create or replace function public.get_post_reaction_summary(
  p_post_id uuid,
  p_viewer_id bigint default null
)
returns jsonb
language plpgsql
stable
security definer
as $$
declare
  v_user_reaction text := null;
  v_reaction_counts jsonb := '{}'::jsonb;
begin
  if p_viewer_id is not null then
    select reaction_type into v_user_reaction
    from public.post_reactions
    where post_id = p_post_id and user_id = p_viewer_id
    limit 1;
  end if;

  select reaction_counts into v_reaction_counts
  from public.posts
  where id = p_post_id;

  if v_reaction_counts is null then
    select coalesce(
      jsonb_object_agg(sub.reaction_type, sub.cnt),
      '{}'::jsonb
    ) into v_reaction_counts
    from (
      select pr.reaction_type, count(*)::int as cnt
      from public.post_reactions pr
      where pr.post_id = p_post_id
      group by pr.reaction_type
    ) sub;
  end if;

  return jsonb_build_object(
    'post_id', p_post_id,
    'user_reaction', v_user_reaction,
    'reaction_counts', coalesce(v_reaction_counts, '{}'::jsonb)
  );
end;
$$;

commit;