-- =====================================================================
-- MANDALA -- CUSTOM NETWORKS SCHEMA
-- User-created networks, direct member additions, and feed scoping
-- =====================================================================

BEGIN;

-- 1. CUSTOM NETWORKS TABLE
CREATE TABLE IF NOT EXISTS public.custom_networks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id BIGINT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  icon_emoji TEXT NOT NULL DEFAULT '🌐',
  color_hex TEXT NOT NULL DEFAULT '#3B82F6',
  is_private BOOLEAN NOT NULL DEFAULT true,
  allow_anonymous BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT custom_networks_name_length CHECK (char_length(name) BETWEEN 1 AND 80)
);

CREATE INDEX IF NOT EXISTS custom_networks_creator_idx
  ON public.custom_networks (creator_id);

-- 2. CUSTOM NETWORK MEMBERS TABLE
-- Supports Mafia-style direct additions: any member can add from their connections
CREATE TABLE IF NOT EXISTS public.custom_network_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  network_id UUID NOT NULL REFERENCES public.custom_networks(id) ON DELETE CASCADE,
  user_id BIGINT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  added_by BIGINT NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member', -- 'creator', 'admin', 'member'
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  UNIQUE (network_id, user_id)
);

CREATE INDEX IF NOT EXISTS custom_network_members_user_idx
  ON public.custom_network_members (user_id);

CREATE INDEX IF NOT EXISTS custom_network_members_network_idx
  ON public.custom_network_members (network_id);

-- 3. POSTS TABLE ALTERATION
-- Add network_id column to posts table
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS network_id UUID REFERENCES public.custom_networks(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS posts_network_created_idx
  ON public.posts (network_id, created_at DESC)
  WHERE is_deleted = false;

COMMIT;
