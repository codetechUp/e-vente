-- ─────────────────────────────────────────────────────────────────────────────
-- Table: app_config
-- One single row (id = 1) holds all store configuration.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.app_config (
  id              int PRIMARY KEY DEFAULT 1 CHECK (id = 1),  -- singleton row
  store_name      text NOT NULL DEFAULT 'Ma Boutique',
  location        text NOT NULL DEFAULT '',
  display_phone   text NOT NULL DEFAULT '',        -- shown in the discover header
  whatsapp_numbers text[] NOT NULL DEFAULT '{}',  -- up to 2 numbers
  call_numbers     text[] NOT NULL DEFAULT '{}'   -- up to 2 numbers
);rajoute sur 

-- Insert the default singleton row if it doesn't exist yet
INSERT INTO public.app_config (id, store_name, location, display_phone, whatsapp_numbers, call_numbers)
VALUES (1, 'Saliou Kane', 'GRAND MBAO', '+221 77 999 02 02', ARRAY['+221779990202'], ARRAY['+221779990202'])
ON CONFLICT (id) DO NOTHING;

-- Allow authenticated users to read the config (clients / livreurs need to see it too)
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read app_config"
  ON public.app_config FOR SELECT
  USING (true);

CREATE POLICY "Admin write app_config"
  ON public.app_config FOR ALL
  USING (auth.role() = 'authenticated');
