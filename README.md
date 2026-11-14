# Vision Pro 3D Viewer

Application **100 % Swift / SwiftUI** pour **Apple Vision Pro (visionOS)** permettant de
visualiser des fichiers 3D multi-formats, de manipuler la scène (zoom, déplacement,
rotation) et de **rouvrir chaque scène exactement comme elle a été laissée**
(niveau de zoom, position, rotation).

## Formats supportés

| Format | Chemin de chargement |
|--------|----------------------|
| USDZ / USD / USDA / USDC | `ModelEntity.load` (RealityKit natif, matériaux/animations conservés) |
| OBJ / STL | parseur intégré (`ModelLoader.swift`) → conversion en `MeshResource` RealityKit |

> ModelIO et SceneKit n'étant pas disponibles sur visionOS, les fichiers OBJ/STL
> sont parsés directement puis convertis en `MeshResource`. Les formats glTF/GLB/DAE
> ne sont pas pris en charge sur visionOS.

## Manipulation de la scène

| Geste | Action |
|-------|--------|
| Pincement à deux doigts (`MagnificationGesture`) | Zoom (échelle entre 5 % et 5000 %) |
| Drag (`DragGesture`) | Déplacement dans le plan |
| Rotation à deux doigts (`RotationGesture`) | Rotation autour de l'axe vertical |
| Double tap | Réinitialisation de la transformée |

## Persistance de l'état des scènes

Chaque scène est enregistrée en JSON dans `Documents/Scenes/<id>.json` :

- **bookmark de sécurité** du fichier (réouverture possible après redémarrage) ;
- **position**, **rotation (quaternion)** et **échelle (zoom)** de l'entité.

L'état est sauvegardé à la fin de chaque geste et à la fermeture de la vue ;
la scène est restaurée à l'identique à la réouverture depuis l'écran d'accueil.

## Stockage iCloud (multi-plateformes)

Les fichiers 3D peuvent être stockés dans le **conteneur iCloud Drive** de l'app
(`iCloud.<bundle-id>/Documents`) :

- **Upload** : menu contextuel « Copier vers iCloud Drive » sur une scène locale ;
- **Lecture** : section « iCloud Drive » listant les fichiers synchronisés, avec
  téléchargement à la demande (`startDownloadingUbiquitousItem`) ;
- **Multi-plateformes** : le même conteneur est accessible depuis visionOS, iOS,
  iPadOS et macOS (app Fichiers, Finder, ou une app compagnon partageant le même
  `iCloud.<bundle-id>`), ce qui synchronise automatiquement les fichiers 3D
  entre tous les appareils.

### Activation dans Xcode

Le package Swift ne peut pas embarquer d'entitlements : dans Xcode, sur la cible
de l'app, activez **Signing & Capabilities → + Capability → iCloud → iCloud Drive**
(conteneur `iCloud.$(CFBundleIdentifier)`), ou associez le fichier
`Visionpro3DViewer.entitlements` fourni à la racine du dépôt.

## Interface

- **Écran d'accueil** : grille de cartes (icône, nom, zoom mémorisé, badge iCloud),
  section iCloud Drive, import via `fileImporter`, menu contextuel
  (copier vers iCloud / supprimer) ;
- **Scène 3D** : composant `InteractiveModelView` (fenêtre + immersion) avec HUD
  (zoom %, « Réinitialiser », « Centrer » selon la bounding box), état de chargement,
  double tap pour réinitialiser ;
- **Mode immersif** : `ImmersiveSpace` plein écran (`immersionStyle: .full`),
  ouvert depuis la barre d'outils de la scène.

## Maquettes de l'interface

Rendus PNG du thème actuel (fond dégradé + halos, cartes à liseré dégradé, HUD capsule) :
[`docs/mockups/`](docs/mockups/) — accueil, scène 3D et mode immersif
(générés par `docs/make_mockups.py`).

## Lancer le projet

1. Ouvrir le dépôt dans **Xcode 16+** (`File > Open...` sur le `Package.swift`,
   le package contient une cible exécutable SwiftUI) ;
2. Sélectionner la cible **Visionpro3DViewer** ;
3. Choisir comme destination le simulateur **Apple Vision Pro** ou un appareil
   Vision Pro ;
4. Lancer (▶).

## Structure

```
Sources/Visionpro3DViewer/
├── Visionpro3DViewerApp.swift   # Point d'entrée (@main, fenêtre volumétrique)
├── ContentView.swift            # Grille de cartes des scènes + iCloud + import (fileImporter)
├── ViewerSceneView.swift        # InteractiveModelView (gestes/HUD/persistance) + fenêtre
├── ImmersiveViewerView.swift    # Espace immersif plein écran
├── ViewerSession.swift          # Scène courante partagée fenêtre / immersion
├── ModelLoader.swift            # USDZ (RealityKit) + OBJ/STL/glTF (ModelIO)
├── SceneState.swift             # Modèle Codable de l'état d'une scène
├── SceneStateStore.swift        # Persistance JSON des scènes (Documents/Scenes)
└── CloudStore.swift             # Conteneur iCloud Drive (upload, listing, téléchargement)
```

`Visionpro3DViewer.entitlements` (racine) : à activer dans Xcode pour iCloud Drive.
