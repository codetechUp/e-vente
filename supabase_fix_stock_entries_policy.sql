-- Supprimer toutes les politiques existantes sur stock_entries
DROP POLICY IF EXISTS "Allow authenticated users to read stock entries" ON public.stock_entries;
DROP POLICY IF EXISTS "Allow admins to insert stock entries" ON public.stock_entries;
DROP POLICY IF EXISTS "Allow admins to update stock entries" ON public.stock_entries;
DROP POLICY IF EXISTS "Allow admins to delete stock entries" ON public.stock_entries;

-- Politique simplifiée : permettre toutes les opérations aux utilisateurs authentifiés
-- (Tu peux restreindre plus tard si nécessaire)
CREATE POLICY "Allow all operations for authenticated users"
ON public.stock_entries
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);
