#!/usr/bin/env python3
"""Génère les maquettes PNG de l'interface de Vision Pro 3D Viewer (docs/mockups/)."""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = os.path.join(os.path.dirname(__file__), "mockups")
os.makedirs(OUT, exist_ok=True)

W, H = 1600, 1000
BG = (18, 18, 22)
PANEL = (38, 38, 46)
PANEL2 = (52, 52, 64)
TEXT = (240, 240, 245)
SUB = (160, 160, 170)
ACCENT = (10, 132, 255)
CLOUD = (90, 160, 250)


def font(size, bold=False):
    return ImageFont.load_default(size=size)


def rrect(d, box, r, fill, outline=None, width=1):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def cube(d, cx, cy, s, color):
    """Dessine un cube isométrique simple."""
    import math
    top = [(cx, cy - s), (cx + s * 0.87, cy - s * 0.5), (cx, cy), (cx - s * 0.87, cy - s * 0.5)]
    left = [(cx - s * 0.87, cy - s * 0.5), (cx, cy), (cx, cy + s), (cx - s * 0.87, cy + s * 0.5)]
    right = [(cx, cy), (cx + s * 0.87, cy - s * 0.5), (cx + s * 0.87, cy + s * 0.5), (cx, cy + s)]
    d.polygon(top, fill=tuple(min(255, c + 60) for c in color))
    d.polygon(left, fill=color)
    d.polygon(right, fill=tuple(max(0, c - 50) for c in color))


def header(d, title):
    d.rectangle([0, 0, W, 70], fill=(28, 28, 34))
    d.text((30, 20), title, font=font(30), fill=TEXT)
    rrect(d, [W - 320, 14, W - 30, 56], 20, ACCENT)
    d.text((W - 300, 22), "+  Ouvrir un fichier 3D", font=font(20), fill=(255, 255, 255))


# ---------------------------------------------------------------- accueil
def mock_home():
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    header(d, "Vision Pro 3D Viewer")
    d.text((40, 100), "Scènes enregistrées", font=font(34), fill=TEXT)

    cards = [
        ("modele.usdz", "zoom 140 %", True, True),
        ("piece.obj", "zoom 100 %", False, False),
        ("scan.glb", "zoom 75 %", False, False),
    ]
    cw, ch, gap, x0, y0 = 460, 300, 30, 40, 160
    for i, (name, zoom, is_cloud, _sel) in enumerate(cards):
        x = x0 + i * (cw + gap)
        rrect(d, [x, y0, x + cw, y0 + ch], 24, PANEL)
        if is_cloud:
            d.ellipse([x + 24, y0 + 24, x + 104, y0 + 104], fill=CLOUD)
            d.text((x + 44, y0 + 48), "iC", font=font(28), fill=(255, 255, 255))
        else:
            cube(d, x + 64, y0 + 66, 34, ACCENT)
        d.text((x + 24, y0 + 130), name, font=font(28), fill=TEXT)
        rrect(d, [x + 24, y0 + 190, x + 220, y0 + 230], 20, PANEL2)
        d.text((x + 38, y0 + 197), zoom, font=font(20), fill=SUB)
        if is_cloud:
            rrect(d, [x + 232, y0 + 190, x + 330, y0 + 230], 20, PANEL2)
            d.text((x + 246, y0 + 197), "iCloud", font=font(20), fill=CLOUD)

    d.text((40, 520), "iCloud Drive", font=font(34), fill=TEXT)
    rows = ["animation.usdz (téléchargé)", "personnage.glb (à télécharger)"]
    for i, r in enumerate(rows):
        y = 580 + i * 56
        rrect(d, [40, y, W - 40, y + 44], 12, PANEL)
        d.ellipse([58, y + 10, 78, y + 30], fill=CLOUD if i == 0 else SUB)
        d.text((92, y + 9), r, font=font(22), fill=TEXT)

    d.text((40, H - 60), "Menu contextuel sur une carte : Copier vers iCloud Drive / Supprimer",
           font=font(20), fill=SUB)
    img.save(os.path.join(OUT, "01-accueil.png"))


# ---------------------------------------------------------------- scène 3D
def mock_scene():
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    # fenêtre volumétrique
    rrect(d, [120, 90, W - 120, H - 90], 40, (24, 24, 30))
    d.text((160, 120), "modele.usdz", font=font(30), fill=TEXT)
    # zone 3D
    cube(d, W // 2, 480, 150, ACCENT)
    # HUD
    hx, hy, hw, hh = 430, H - 220, 740, 70
    rrect(d, [hx, hy, hx + hw, hy + hh], 35, (60, 60, 72))
    d.text((hx + 30, hy + 20), "↺  Réinitialiser", font=font(24), fill=TEXT)
    d.text((hx + 260, hy + 20), "◎  Centrer", font=font(24), fill=TEXT)
    d.text((hx + 420, hy + 20), "zoom 140 %", font=font(24), fill=SUB)
    # barre d'outils
    rrect(d, [430, H - 130, 1170, H - 100 + 40], 20, ACCENT)
    d.text((620, H - 118), "👓  Mode immersif", font=font(22), fill=(255, 255, 255))
    img.save(os.path.join(OUT, "02-scene.png"))


# ---------------------------------------------------------------- immersif
def mock_immersive():
    img = Image.new("RGB", (W, H), (5, 5, 8))
    d = ImageDraw.Draw(img)
    cube(d, W // 2, H // 2, 260, ACCENT)
    rrect(d, [W - 420, 40, W - 40, 100], 30, (60, 60, 72))
    d.text((W - 400, 56), "✕  Quitter l'immersion", font=font(24), fill=TEXT)
    hx, hy, hw, hh = 500, H - 130, 600, 70
    rrect(d, [hx, hy, hx + hw, hy + hh], 35, (50, 50, 62))
    d.text((hx + 30, hy + 20), "↺  Réinitialiser   ◎  Centrer   zoom 140 %", font=font(24), fill=TEXT)
    d.text((40, 40), "ImmersiveSpace — immersion totale (.full)", font=font(26), fill=SUB)
    img.save(os.path.join(OUT, "03-immersif.png"))


mock_home()
mock_scene()
mock_immersive()
print("OK ->", OUT)
