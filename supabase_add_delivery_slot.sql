-- Script SQL pour ajouter les colonnes de livraison à la table des commandes (orders)
-- À exécuter dans le SQL Editor de Supabase (https://supabase.com/dashboard)

ALTER TABLE public.orders 
ADD COLUMN IF NOT EXISTS desired_delivery_date timestamp with time zone,
ADD COLUMN IF NOT EXISTS delivery_slot text;

-- Optionnel : Notification pour confirmer que le script s'est bien exécuté
COMMENT ON COLUMN public.orders.delivery_slot IS 'Créneau horaire de livraison choisi par le client';
COMMENT ON COLUMN public.orders.desired_delivery_date IS 'Date de livraison choisie par le client';
