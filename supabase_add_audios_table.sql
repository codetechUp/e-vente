-- SQL Migration: Add Audios Table for Broadcast Announcements
-- Run this in your Supabase SQL Editor.

-- public.audios table creation
CREATE TABLE IF NOT EXISTS public.audios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    audio_url TEXT NOT NULL,
    duration_seconds INTEGER,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

-- Enable Row Level Security (RLS) on public.audios
ALTER TABLE public.audios ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read audios
DROP POLICY IF EXISTS "Allow all authenticated users to read audios" ON public.audios;
CREATE POLICY "Allow all authenticated users to read audios" ON public.audios
    FOR SELECT TO authenticated USING (true);

-- Allow only administrators to manage audios
DROP POLICY IF EXISTS "Allow admins to manage audios" ON public.audios;
CREATE POLICY "Allow admins to manage audios" ON public.audios
    FOR ALL TO authenticated USING (
        EXISTS (
            SELECT 1 FROM public.users u
            JOIN public.roles r ON u.role_id = r.id
            WHERE u.id = auth.uid() AND r.name = 'admin'
        )
    );

-- --- STORAGE BUCKET CONFIGURATION ---
-- Create the 'audios' storage bucket in Supabase (marked public so files are accessible via URL)
INSERT INTO storage.buckets (id, name, public)
VALUES ('audios', 'audios', true)
ON CONFLICT (id) DO NOTHING;

-- RLS Policies on storage.objects for the 'audios' bucket

-- 1. Allow public select access to the files in the 'audios' bucket
DROP POLICY IF EXISTS "Give public select access to audios bucket" ON storage.objects;
CREATE POLICY "Give public select access to audios bucket" ON storage.objects
    FOR SELECT TO public USING (bucket_id = 'audios');

-- 2. Allow admins to insert files in the 'audios' bucket
DROP POLICY IF EXISTS "Allow admins to upload audios" ON storage.objects;
CREATE POLICY "Allow admins to upload audios" ON storage.objects
    FOR INSERT TO authenticated WITH CHECK (
        bucket_id = 'audios' AND EXISTS (
            SELECT 1 FROM public.users u
            JOIN public.roles r ON u.role_id = r.id
            WHERE u.id = auth.uid() AND r.name = 'admin'
        )
    );

-- 3. Allow admins to update files in the 'audios' bucket
DROP POLICY IF EXISTS "Allow admins to update audios" ON storage.objects;
CREATE POLICY "Allow admins to update audios" ON storage.objects
    FOR UPDATE TO authenticated USING (
        bucket_id = 'audios' AND EXISTS (
            SELECT 1 FROM public.users u
            JOIN public.roles r ON u.role_id = r.id
            WHERE u.id = auth.uid() AND r.name = 'admin'
        )
    );

-- 4. Allow admins to delete files in the 'audios' bucket
DROP POLICY IF EXISTS "Allow admins to delete audios" ON storage.objects;
CREATE POLICY "Allow admins to delete audios" ON storage.objects
    FOR DELETE TO authenticated USING (
        bucket_id = 'audios' AND EXISTS (
            SELECT 1 FROM public.users u
            JOIN public.roles r ON u.role_id = r.id
            WHERE u.id = auth.uid() AND r.name = 'admin'
        )
    );

-- Refresh the PostgREST API schema cache
NOTIFY pgrst, 'reload schema';
