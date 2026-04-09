-- Solution 1: Rendre created_by nullable (optionnel)
-- Cela permet de créer des entrées sans spécifier l'utilisateur
ALTER TABLE public.stock_entries 
ALTER COLUMN created_by DROP NOT NULL;

-- Solution 2: Supprimer complètement la contrainte de clé étrangère
-- et la recréer avec ON DELETE SET NULL
ALTER TABLE public.stock_entries 
DROP CONSTRAINT IF EXISTS stock_entries_created_by_fkey;

ALTER TABLE public.stock_entries
ADD CONSTRAINT stock_entries_created_by_fkey 
FOREIGN KEY (created_by) 
REFERENCES public.users(id) 
ON DELETE SET NULL;
