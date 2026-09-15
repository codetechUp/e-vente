-- ─────────────────────────────────────────────────────────────────────────────
-- Add Column: purchase_price to public.products
-- Executer ce script dans le SQL Editor de Supabase
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS purchase_price numeric NOT NULL DEFAULT 0.0;

COMMENT ON COLUMN public.products.purchase_price IS 'Taux d achat / Prix d achat du produit (pour calcul de marge et benefice)';
