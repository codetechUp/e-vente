# Configuration des icônes et splash screen

## Packages ajoutés dans pubspec.yaml

- `flutter_launcher_icons: ^0.13.1` - Pour générer les icônes de l'app
- `flutter_native_splash: ^2.4.0` - Pour générer le splash screen

## Image utilisée

`assets/images/logo.png`

## Commandes à exécuter

### 1. Installer les packages
```bash
flutter pub get
```

### 2. Générer les icônes de l'app
```bash
flutter pub run flutter_launcher_icons
```

### 3. Générer le splash screen
```bash
flutter pub run flutter_native_splash:create
```

### 4. Nettoyer et reconstruire l'app
```bash
flutter clean
flutter pub get
flutter run
```

## Configuration actuelle

### Icône de l'app (flutter_launcher_icons)
- Android: activé
- iOS: activé
- Image: `assets/images/logo.png`
- Fond adaptatif Android: blanc (#FFFFFF)
- Icône adaptative Android: `assets/images/logo.png`

### Splash screen (flutter_native_splash)
- Couleur de fond: blanc (#FFFFFF)
- Image: `assets/images/logo.png`
- Android: activé
- iOS: activé
- Android 12+: activé avec même configuration

## Résultat attendu

Après avoir exécuté ces commandes, l'app aura:
- Une icône personnalisée avec le logo sur Android et iOS
- Un splash screen blanc avec le logo au centre qui s'affiche au démarrage
