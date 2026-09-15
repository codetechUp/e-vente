-- SQL Migration: Add image_url column to public.audios table
-- Run this in your Supabase SQL Editor.

ALTER TABLE public.audios ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Refresh the PostgREST API schema cache
NOTIFY pgrst, 'reload schema';
