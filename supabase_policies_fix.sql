-- ============================================
-- FIX: Permettre aux admins de modifier les rôles utilisateurs
-- ============================================

-- 1. Supprimer les anciennes policies UPDATE sur public.users (si elles existent)
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Admins can update user roles" ON public.users;
DROP POLICY IF EXISTS "Allow all updates for testing" ON public.users;

-- 2. Policy pour permettre aux utilisateurs de modifier leur propre profil (sauf role_id)
CREATE POLICY "Users can update own profile"
ON public.users
FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id 
  AND role_id = (SELECT role_id FROM public.users WHERE id = auth.uid())
);

-- 3. Policy pour permettre aux admins de modifier tous les utilisateurs (y compris role_id)
CREATE POLICY "Admins can update all users"
ON public.users
FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role_id = (SELECT id FROM public.roles WHERE name = 'admin')
  )
)
WITH CHECK (true);

-- 4. Vérifier que RLS est activé sur public.users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 5. Policy SELECT pour que tout le monde puisse lire les utilisateurs
DROP POLICY IF EXISTS "Users are viewable by authenticated users" ON public.users;
CREATE POLICY "Users are viewable by authenticated users"
ON public.users
FOR SELECT
USING (auth.role() = 'authenticated');

-- ============================================
-- ALTERNATIVE SIMPLE (pour tester rapidement)
-- ============================================
-- Si tu veux juste tester rapidement sans restrictions,
-- décommente les lignes suivantes et commente tout le code ci-dessus :

-- DROP POLICY IF EXISTS "Allow all operations for testing" ON public.users;
-- CREATE POLICY "Allow all operations for testing"
-- ON public.users
-- FOR ALL
-- USING (true)
-- WITH CHECK (true);
