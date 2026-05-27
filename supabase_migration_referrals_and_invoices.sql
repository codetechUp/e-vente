-- Migration SQL pour E-Vente : Rôle Commercial, Parrainage & Facturation
-- Exécutez ce script dans l'éditeur SQL de votre Dashboard Supabase.

-- 1. Ajouter le rôle 'commercial' s'il n'existe pas
INSERT INTO public.roles (name)
VALUES ('commercial')
ON CONFLICT (name) DO NOTHING;

-- 2. Ajouter la liaison de parrainage dans la table des utilisateurs
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS referrer_id UUID REFERENCES public.users(id) ON DELETE SET NULL;

-- 3. Créer la table des factures (invoices)
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id INTEGER NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    invoice_number TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL
);

-- Commenter les tables/colonnes pour documentation
COMMENT ON COLUMN public.users.referrer_id IS 'ID de l''utilisateur (commercial) qui a parrainé ce client';
COMMENT ON TABLE public.invoices IS 'Tableau de stockage de l''historique de facturation des commandes';

-- 4. Activer RLS pour la table invoices
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- 5. Créer les politiques de sécurité (Policies) pour la table invoices
DROP POLICY IF EXISTS "Allow all authenticated users to read invoices" ON public.invoices;
CREATE POLICY "Allow all authenticated users to read invoices" ON public.invoices
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Allow admins and preparators to insert invoices" ON public.invoices;
CREATE POLICY "Allow admins and preparators to insert invoices" ON public.invoices
    FOR INSERT TO authenticated WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users u
            JOIN public.roles r ON u.role_id = r.id
            WHERE u.id = auth.uid() AND r.name IN ('admin', 'preparateur')
        )
    );

-- 6. Ajouter la colonne delivery_slot dans la table des commandes (orders) si elle n'existe pas
ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS delivery_slot TEXT;

