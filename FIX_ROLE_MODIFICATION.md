# Fix : Modification du rôle utilisateur bloquée

## Problème identifié

Le log montre que `role_id` reste `null` après modification :
```
row={..., role_id: null, ...}
```

**Cause** : Les policies RLS (Row Level Security) de Supabase bloquent la modification de la colonne `role_id`.

## Solution

### Étape 1 : Aller dans Supabase Dashboard

1. Ouvre ton projet Supabase : https://supabase.com/dashboard
2. Va dans **SQL Editor**

### Étape 2 : Exécuter le script SQL

Copie et exécute le contenu du fichier `supabase_policies_fix.sql` dans le SQL Editor.

Ce script va :
- Créer une policy permettant aux admins de modifier tous les utilisateurs (y compris `role_id`)
- Créer une policy permettant aux utilisateurs de modifier leur propre profil (sauf `role_id`)
- Activer RLS sur la table `public.users`

### Étape 3 : Tester

1. Redémarre l'app Flutter
2. Connecte-toi en tant qu'admin
3. Modifie le rôle d'un utilisateur
4. Vérifie que le `role_id` est bien sauvegardé

## Alternative rapide (pour tester)

Si tu veux juste tester rapidement sans configurer les policies :

### Option A : Désactiver RLS temporairement

Dans Supabase Dashboard :
1. Va dans **Table Editor** → **users**
2. Clique sur les 3 points → **Edit table**
3. Décoche **Enable Row Level Security (RLS)**
4. Sauvegarde

⚠️ **Attention** : Ne fais ça qu'en développement, jamais en production !

### Option B : Policy permissive temporaire

Exécute ce SQL dans le SQL Editor :

```sql
DROP POLICY IF EXISTS "Allow all operations for testing" ON public.users;
CREATE POLICY "Allow all operations for testing"
ON public.users
FOR ALL
USING (true)
WITH CHECK (true);
```

## Vérification

Après avoir appliqué la solution, tu devrais voir dans les logs :

```
[SupabaseTableService] getById table=users id=... row={..., role_id: 3, ...}
```

Au lieu de :

```
row={..., role_id: null, ...}
```

## Résumé

Le problème n'est **pas dans le code Flutter**, mais dans les **permissions Supabase**.

L'update Flutter fonctionne, mais Supabase refuse silencieusement de modifier `role_id` à cause de RLS.
