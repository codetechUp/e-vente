#!/usr/bin/env python3
"""
Script pour ajouter des marges (padding) au logo de l'application.
Cela permet d'avoir un meilleur affichage de l'icône sur les appareils.
"""

from PIL import Image
import os

def add_padding_to_logo(input_path, output_path, padding_percent=15):
    """
    Ajoute des marges blanches autour d'une image.
    
    Args:
        input_path: Chemin de l'image source
        output_path: Chemin de l'image de sortie
        padding_percent: Pourcentage de padding à ajouter (par défaut 15%)
    """
    # Ouvrir l'image
    img = Image.open(input_path)
    
    # Calculer les nouvelles dimensions
    width, height = img.size
    padding = int(max(width, height) * (padding_percent / 100))
    
    new_width = width + (2 * padding)
    new_height = height + (2 * padding)
    
    # Créer une nouvelle image avec fond blanc
    new_img = Image.new('RGBA', (new_width, new_height), (255, 255, 255, 255))
    
    # Coller l'image originale au centre
    new_img.paste(img, (padding, padding), img if img.mode == 'RGBA' else None)
    
    # Sauvegarder
    new_img.save(output_path, 'PNG')
    print(f"✅ Logo avec marges créé: {output_path}")
    print(f"   Dimensions originales: {width}x{height}")
    print(f"   Nouvelles dimensions: {new_width}x{new_height}")
    print(f"   Padding: {padding}px ({padding_percent}%)")

if __name__ == "__main__":
    # Chemins
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_logo = os.path.join(script_dir, "assets", "images", "logo.png")
    output_logo = os.path.join(script_dir, "assets", "images", "logo_padded.png")
    
    # Vérifier que le logo existe
    if not os.path.exists(input_logo):
        print(f"❌ Erreur: Logo non trouvé à {input_logo}")
        exit(1)
    
    # Ajouter le padding
    add_padding_to_logo(input_logo, output_logo, padding_percent=15)
    
    print("\n📝 Prochaines étapes:")
    print("1. Vérifiez que logo_padded.png vous convient")
    print("2. Mettez à jour pubspec.yaml pour utiliser logo_padded.png")
    print("3. Exécutez: flutter pub run flutter_launcher_icons")
