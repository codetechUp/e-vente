-- SQL Script to add GPS location fields to the users table
-- Run this in your Supabase SQL Editor.

-- Add latitude and longitude columns
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION,
ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- Comment fields for documentation
COMMENT ON COLUMN public.users.latitude IS 'Latitude coordinates for delivery location';
COMMENT ON COLUMN public.users.longitude IS 'Longitude coordinates for delivery location';
