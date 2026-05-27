-- =========================================================================
-- SCRIPT GLOBAL DE FIXATION DES UTILISATEURS (TRIGGERS, RLS ET MIGRATION ID)
-- Exécutez l'ensemble de ce script dans le "SQL Editor" de votre console Supabase.
-- =========================================================================

-- -------------------------------------------------------------------------
-- 1. Configuration des Clés Étrangères en Cascades (ON UPDATE CASCADE)
-- Indispensable pour modifier les IDs des utilisateurs sans casser les liaisons existantes.
-- -------------------------------------------------------------------------

-- Contrainte pour public.orders(user_id)
ALTER TABLE public.orders 
DROP CONSTRAINT IF EXISTS orders_user_id_fkey,
ADD CONSTRAINT orders_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES public.users(id) 
  ON UPDATE CASCADE ON DELETE CASCADE;

-- Contrainte pour public.stock_entries(created_by)
ALTER TABLE public.stock_entries 
DROP CONSTRAINT IF EXISTS stock_entries_created_by_fkey,
ADD CONSTRAINT stock_entries_created_by_fkey 
  FOREIGN KEY (created_by) REFERENCES public.users(id) 
  ON UPDATE CASCADE ON DELETE SET NULL;

-- Contrainte pour public.invoices(created_by)
ALTER TABLE public.invoices 
DROP CONSTRAINT IF EXISTS invoices_created_by_fkey,
ADD CONSTRAINT invoices_created_by_fkey 
  FOREIGN KEY (created_by) REFERENCES public.users(id) 
  ON UPDATE CASCADE ON DELETE SET NULL;

-- Contrainte pour public.users(referrer_id)
ALTER TABLE public.users 
DROP CONSTRAINT IF EXISTS users_referrer_id_fkey,
ADD CONSTRAINT users_referrer_id_fkey 
  FOREIGN KEY (referrer_id) REFERENCES public.users(id) 
  ON UPDATE CASCADE ON DELETE SET NULL;


-- -------------------------------------------------------------------------
-- 2. Assouplissement de la Table public.users (email non obligatoire)
-- -------------------------------------------------------------------------
ALTER TABLE public.users ALTER COLUMN email DROP NOT NULL;


-- -------------------------------------------------------------------------
-- 2.5. Fonction de Normalisation du Numéro de Téléphone (+221...)
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalize_phone(phone_str TEXT)
RETURNS TEXT AS $$
DECLARE
  cleaned TEXT;
BEGIN
  IF phone_str IS NULL OR phone_str = '' THEN
    RETURN NULL;
  END IF;
  
  -- Enlever tous les caractères non numériques
  cleaned := regexp_replace(phone_str, '[^0-9]', '', 'g');
  
  -- Si le numéro fait 9 chiffres (ex: 775741341), ajouter le code pays '221'
  IF length(cleaned) = 9 THEN
    cleaned := '221' || cleaned;
  END IF;
  
  -- Si le numéro commence par '00221' et fait 14 chiffres, enlever les '00'
  IF length(cleaned) = 14 AND cleaned LIKE '00221%' THEN
    cleaned := substring(cleaned from 3);
  END IF;
  
  -- Si le numéro commence par '221' et fait 12 chiffres, ajouter le '+'
  IF length(cleaned) = 12 AND cleaned LIKE '221%' THEN
    RETURN '+' || cleaned;
  END IF;
  
  RETURN '+' || cleaned;
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- -------------------------------------------------------------------------
-- 3. Mise à jour de la fonction du Trigger d'inscription/authentification
-- Correction : utilise NULL au lieu de '' pour l'email s'il n'est pas fourni,
-- ce qui évite les violations de contrainte unique sur l'email lors de la connexion par téléphone.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  existing_id UUID;
  new_phone TEXT;
  new_email TEXT;
BEGIN
  new_phone := public.normalize_phone(coalesce(new.phone, new.raw_user_meta_data->>'phone'));
  -- Si l'email est absent ou vide '', on utilise NULL pour éviter les conflits d'unicité
  new_email := NULLIF(coalesce(new.email, new.raw_user_meta_data->>'email', ''), '');

  -- Chercher s'il y a déjà un utilisateur pré-enregistré avec ce numéro de téléphone
  IF new_phone IS NOT NULL AND new_phone <> '' THEN
    SELECT id INTO existing_id FROM public.users 
    WHERE public.normalize_phone(phone) = new_phone LIMIT 1;
    -- Si le numéro de téléphone n'est pas pré-enregistré, on bloque la création
    IF existing_id IS NULL THEN
      RAISE EXCEPTION 'Ce numéro de téléphone n''est pas pré-enregistré. Veuillez contacter un commercial.';
    END IF;
  END IF;

  -- Si non trouvé par téléphone, chercher par email (uniquement s'il n'est pas nul)
  IF existing_id IS NULL AND new_email IS NOT NULL THEN
    SELECT id INTO existing_id FROM public.users WHERE email = new_email LIMIT 1;
  END IF;

  -- Si un compte pré-enregistré existe, on met à jour son ID pour le lier aux identifiants auth
  IF existing_id IS NOT NULL THEN
    UPDATE public.users
    SET 
      id = new.id,
      email = coalesce(email, new_email),
      phone = coalesce(phone, new_phone),
      name = coalesce(name, new.raw_user_meta_data->>'name')
    WHERE id = existing_id;
  ELSE
    -- Sinon, on crée un nouvel utilisateur (client par défaut)
    INSERT INTO public.users (id, email, name, phone, role_id, is_active)
    VALUES (
      new.id,
      new_email,
      new.raw_user_meta_data->>'name',
      new_phone,
      (SELECT id FROM public.roles WHERE name = 'client' LIMIT 1),
      true
    );
  END IF;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 4. Liaison du trigger sur la table auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- -------------------------------------------------------------------------
-- 5. Politiques de Sécurité (RLS) pour autoriser les commerciaux à ajouter/modifier
-- -------------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- SELECT : Tout le monde authentifié peut lire les utilisateurs
DROP POLICY IF EXISTS "Users are viewable by authenticated users" ON public.users;
CREATE POLICY "Users are viewable by authenticated users"
ON public.users FOR SELECT
USING (auth.role() = 'authenticated');

-- INSERT 1 : Un utilisateur peut insérer son propre profil (fallback)
DROP POLICY IF EXISTS "Users can insert own profile" ON public.users;
CREATE POLICY "Users can insert own profile"
ON public.users FOR INSERT
WITH CHECK (auth.uid() = id);

-- INSERT 2 : Les administrateurs peuvent insérer n'importe quel utilisateur
DROP POLICY IF EXISTS "Admins can insert users" ON public.users;
CREATE POLICY "Admins can insert users"
ON public.users FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role_id = (SELECT id FROM public.roles WHERE name = 'admin')
  )
);

-- INSERT 3 : Les commerciaux peuvent insérer de nouveaux clients
DROP POLICY IF EXISTS "Commercials can insert users" ON public.users;
CREATE POLICY "Commercials can insert users"
ON public.users FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role_id = (SELECT id FROM public.roles WHERE name = 'commercial')
  )
);

-- UPDATE 1 : Un utilisateur peut modifier son propre profil (hors rôle)
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
CREATE POLICY "Users can update own profile"
ON public.users FOR UPDATE
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id 
  AND role_id = (SELECT role_id FROM public.users WHERE id = auth.uid())
);

-- UPDATE 2 : Les admins peuvent modifier tout le monde
DROP POLICY IF EXISTS "Admins can update all users" ON public.users;
CREATE POLICY "Admins can update all users"
ON public.users FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role_id = (SELECT id FROM public.roles WHERE name = 'admin')
  )
)
WITH CHECK (true);

-- UPDATE 3 : Les commerciaux peuvent modifier les infos des clients qu'ils parrainent (ex. GPS)
DROP POLICY IF EXISTS "Commercials can update sponsored users" ON public.users;
CREATE POLICY "Commercials can update sponsored users"
ON public.users FOR UPDATE
USING (
  referrer_id = auth.uid() 
  AND EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role_id = (SELECT id FROM public.roles WHERE name = 'commercial')
  )
)
WITH CHECK (
  referrer_id = auth.uid() 
  AND EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
    AND role_id = (SELECT id FROM public.roles WHERE name = 'commercial')
  )
);


-- -------------------------------------------------------------------------
-- 6. Correctif Rétroactif (Liaison des ID de commerciaux existants)
-- -------------------------------------------------------------------------
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN 
    SELECT p.id AS old_id, a.id AS new_id
    FROM public.users p
    JOIN auth.users a ON (p.email = a.email OR p.phone = a.phone)
    WHERE p.id <> a.id
  LOOP
    RAISE NOTICE 'Début de la migration de l''utilisateur de % vers %', r.old_id, r.new_id;

    -- A0. Supprimer l'éventuel doublon vide/automatique créé lors de la connexion
    DELETE FROM public.users WHERE id = r.new_id;

    -- A1. Mettre à jour la clé primaire directement (les clés filles suivent grâce au ON UPDATE CASCADE)
    UPDATE public.users SET id = r.new_id WHERE id = r.old_id;
    
    RAISE NOTICE 'Migration réussie pour l''utilisateur %', r.new_id;
  END LOOP;
END;
$$;


-- -------------------------------------------------------------------------
-- 7. Fonction Publique pour Vérifier si un numéro est pré-enregistré
-- Cette fonction peut être appelée par des utilisateurs anonymes (via RPC)
-- afin de bloquer l'envoi de SMS OTP pour les numéros inconnus.
-- -------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_phone_registered(phone_to_check TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE public.normalize_phone(phone) = public.normalize_phone(phone_to_check)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Accorder le droit d'exécution aux utilisateurs anonymes (public)
GRANT EXECUTE ON FUNCTION public.check_phone_registered(TEXT) TO anon, authenticated;


-- 8. Forcer le rechargement immédiat du cache d'API
NOTIFY pgrst, 'reload schema';
