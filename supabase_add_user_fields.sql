-- Ajouter les colonnes 'nom' et 'adresse' à la table users
-- Exécuter ce script dans l'éditeur SQL de Supabase

-- Ajouter la colonne 'nom' (prénom et nom complet)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS nom TEXT;

-- Ajouter la colonne 'adresse' (adresse complète de livraison)
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS adresse TEXT;

-- Optionnel: Ajouter des commentaires pour documenter les colonnes
COMMENT ON COLUMN public.users.nom IS 'Nom complet de l''utilisateur';
COMMENT ON COLUMN public.users.adresse IS 'Adresse de livraison de l''utilisateur';
