# Vision Pro 3D Viewer

Application **100 % Swift / SwiftUI** pour **Apple Vision Pro (visionOS)** permettant de
visualiser des fichiers 3D multi-formats, de manipuler la scène (zoom, déplacement,
rotation) et de **rouvrir chaque scène exactement comme elle a été laissée**
(niveau de zoom, position, rotation).

## Formats supportés

| Format | Chemin de chargement |
|--------|----------------------|
| USDZ / USD / USDA / USDC | `ModelEntity.load` (RealityKit natif, matériaux/animations conservés) |
| OBJ / STL / glTF / GLB / DAE | ModelIO (`MDLAsset`) → conversion en `MeshResource` RealityKit |

> SceneKit n'étant pas disponible sur visionOS, les formats non-USD sont convertis
> maillage par maillage via ModelIO (`ModelLoader.swift`).

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
├── ContentView.swift            # Liste des scènes + import de fichier (fileImporter)
├── ViewerSceneView.swift        # RealityView + gestes + restauration/persistance
├── ModelLoader.swift            # USDZ (RealityKit) + OBJ/STL/glTF (ModelIO)
├── SceneState.swift             # Modèle Codable de l'état d'une scène
└── SceneStateStore.swift        # Persistance JSON des scènes (Documents/Scenes)
```
