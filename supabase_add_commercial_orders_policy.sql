-- Politique de sécurité RLS pour permettre aux parrains (commerciaux) de voir les commandes de leurs filleuls (clients)
-- À exécuter dans la console Supabase (SQL Editor) : https://supabase.com/dashboard

-- Étape 1 : S'assurer que la table orders a RLS d'activé (ce qui est normalement le cas)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Étape 2 : Créer la policy permettant aux commerciaux de lire les commandes de leurs clients parrainés
DROP POLICY IF EXISTS "Commercials can view orders of their referred clients" ON public.orders;

CREATE POLICY "Commercials can view orders of their referred clients" ON public.orders
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = orders.user_id AND u.referrer_id = auth.uid()
        )
    );

-- Étape 3 : S'assurer également de l'accès aux lignes de commande (order_items) associées si besoin
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Commercials can view order items of their referred clients" ON public.order_items;

CREATE POLICY "Commercials can view order items of their referred clients" ON public.order_items
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.orders o
            JOIN public.users u ON o.user_id = u.id
            WHERE o.id = order_items.order_id AND u.referrer_id = auth.uid()
        )
    );

-- Étape 4 : Recharger le schéma d'API Postgrest
NOTIFY pgrst, 'reload schema';
