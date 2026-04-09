-- Créer la table stock_entries pour enregistrer les entrées de stock
CREATE TABLE IF NOT EXISTS public.stock_entries (
  id SERIAL PRIMARY KEY,
  product_id INTEGER NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL,
  entry_type VARCHAR(50) NOT NULL DEFAULT 'purchase', -- 'purchase', 'adjustment', 'return'
  notes TEXT,
  created_by UUID REFERENCES public.users(id),
  created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

-- Créer un index sur product_id pour des requêtes plus rapides
CREATE INDEX IF NOT EXISTS idx_stock_entries_product_id ON public.stock_entries(product_id);

-- Créer un index sur created_at pour trier par date
CREATE INDEX IF NOT EXISTS idx_stock_entries_created_at ON public.stock_entries(created_at DESC);

-- Fonction pour mettre à jour automatiquement le stock lors d'une nouvelle entrée
CREATE OR REPLACE FUNCTION update_stock_on_entry()
RETURNS TRIGGER AS $$
BEGIN
  -- Vérifier si un enregistrement de stock existe pour ce produit
  IF EXISTS (SELECT 1 FROM public.stocks WHERE product_id = NEW.product_id) THEN
    -- Mettre à jour la quantité existante
    UPDATE public.stocks
    SET quantity = quantity + NEW.quantity,
        updated_at = NOW()
    WHERE product_id = NEW.product_id;
  ELSE
    -- Créer un nouveau enregistrement de stock
    INSERT INTO public.stocks (product_id, quantity, updated_at)
    VALUES (NEW.product_id, NEW.quantity, NOW());
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Créer le trigger pour mettre à jour automatiquement les stocks
DROP TRIGGER IF EXISTS trigger_update_stock_on_entry ON public.stock_entries;
CREATE TRIGGER trigger_update_stock_on_entry
AFTER INSERT ON public.stock_entries
FOR EACH ROW
EXECUTE FUNCTION update_stock_on_entry();

-- Activer RLS (Row Level Security)
ALTER TABLE public.stock_entries ENABLE ROW LEVEL SECURITY;

-- Politique pour permettre la lecture à tous les utilisateurs authentifiés
CREATE POLICY "Allow authenticated users to read stock entries"
ON public.stock_entries
FOR SELECT
TO authenticated
USING (true);

-- Politique pour permettre l'insertion uniquement aux admins
DROP POLICY IF EXISTS "Allow admins to insert stock entries" ON public.stock_entries;
CREATE POLICY "Allow admins to insert stock entries"
ON public.stock_entries
FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.roles r ON u.role_id = r.id
    WHERE u.id = auth.uid() AND LOWER(r.name) = 'admin'
  )
);

-- Politique pour permettre la mise à jour uniquement aux admins
CREATE POLICY "Allow admins to update stock entries"
ON public.stock_entries
FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.roles r ON u.role_id = r.id
    WHERE u.id = auth.uid() AND r.name = 'admin'
  )
);

-- Politique pour permettre la suppression uniquement aux admins
CREATE POLICY "Allow admins to delete stock entries"
ON public.stock_entries
FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    JOIN public.roles r ON u.role_id = r.id
    WHERE u.id = auth.uid() AND r.name = 'admin'
  )
);
