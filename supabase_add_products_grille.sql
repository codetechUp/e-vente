-- Ajouter une colonne de priorite d'affichage pour les produits
-- Valeurs attendues: premium/silver/gold ou 1/2/3
-- Executer ce script dans l'editeur SQL Supabase

ALTER TABLE public.products
ADD COLUMN IF NOT EXISTS grille TEXT;

-- Normaliser les valeurs numeriques vers des libelles
UPDATE public.products
SET grille = CASE
  WHEN TRIM(LOWER(grille)) = '1' THEN 'premium'
  WHEN TRIM(LOWER(grille)) = '2' THEN 'silver'
  WHEN TRIM(LOWER(grille)) = '3' THEN 'gold'
  ELSE TRIM(LOWER(grille))
END
WHERE grille IS NOT NULL;

-- Autoriser uniquement les valeurs connues
ALTER TABLE public.products
DROP CONSTRAINT IF EXISTS products_grille_check;

ALTER TABLE public.products
ADD CONSTRAINT products_grille_check
CHECK (
  grille IS NULL
  OR TRIM(LOWER(grille)) IN ('premium', 'silver', 'gold', '1', '2', '3')
);

COMMENT ON COLUMN public.products.grille IS
'Priorite d''affichage produit: premium/silver/gold (ou 1/2/3 pour compatibilite)';
