#!/usr/bin/env python3
"""Maquettes PNG du thème enrichi de Vision Pro 3D Viewer (docs/mockups/)."""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = os.path.join(os.path.dirname(__file__), "mockups")
os.makedirs(OUT, exist_ok=True)

W, H = 1600, 1000
TEXT = (240, 240, 245)
SUB = (165, 165, 175)
INDIGO = (99, 102, 241)
CYAN = (34, 211, 238)


def font(size):
    return ImageFont.load_default(size=size)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def vgradient(size, top, bottom):
    """Dégradé vertical."""
    w, h = size
    img = Image.new("RGB", size)
    d = ImageDraw.Draw(img)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(top, bottom, y / max(1, h - 1)))
    return img


def glow(img, cx, cy, radius, color, alpha):
    """Halo radial."""
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    steps = 40
    for i in range(steps, 0, -1):
        r = radius * i / steps
        a = int(alpha * (1 - i / steps) ** 2)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    img.paste(Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB"), (0, 0))


def base_bg():
    img = vgradient((W, H), (9, 11, 26), (23, 13, 44))
    glow(img, W - 150, 80, 420, CYAN, 90)
    glow(img, 120, H - 80, 460, INDIGO, 110)
    return img


def rrect(d, box, r, fill, outline=None, width=1):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=width)


def grad_circle(d, box, c1=INDIGO, c2=CYAN):
    """Pastille dégradée (approximée par des anneaux)."""
    x0, y0, x1, y1 = box
    steps = 24
    for i in range(steps, 0, -1):
        t = i / steps
        r = (x1 - x0) / 2 * t
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=lerp(c2, c1, t))


def cube(d, cx, cy, s, color):
    top = [(cx, cy - s), (cx + s * 0.87, cy - s * 0.5), (cx, cy), (cx - s * 0.87, cy - s * 0.5)]
    left = [(cx - s * 0.87, cy - s * 0.5), (cx, cy), (cx, cy + s), (cx - s * 0.87, cy + s * 0.5)]
    right = [(cx, cy), (cx + s * 0.87, cy - s * 0.5), (cx + s * 0.87, cy + s * 0.5), (cx, cy + s)]
    d.polygon(top, fill=tuple(min(255, c + 70) for c in color))
    d.polygon(left, fill=color)
    d.polygon(right, fill=tuple(max(0, c - 60) for c in color))


def header(d, title):
    d.rectangle([0, 0, W, 70], fill=(16, 18, 34))
    d.text((30, 20), title, font=font(30), fill=TEXT)
    # bouton dégradé
    btn = [W - 350, 13, W - 30, 57]
    for i in range(22):
        t = i / 21
        d.line([(btn[0], btn[1] + i * 2), (btn[2], btn[1] + i * 2)], fill=lerp(INDIGO, CYAN, t))
    d.rounded_rectangle(btn, radius=22, outline=None)
    for i in range(22):
        t = i / 21
        d.line([(btn[0] + 2, btn[1] + 2 + i * 2), (btn[2] - 2, btn[1] + 2 + i * 2)], fill=lerp(INDIGO, CYAN, t))
    d.text((W - 330, 22), "+  Ouvrir un fichier 3D", font=font(20), fill=(255, 255, 255))


# ---------------------------------------------------------------- accueil
def mock_home():
    img = base_bg()
    d = ImageDraw.Draw(img)
    header(d, "Vision Pro 3D Viewer")
    grad_circle(d, [40, 96, 84, 140])
    d.text((58, 106), "▣", font=font(26), fill=(255, 255, 255))
    d.text((100, 102), "Scènes enregistrées", font=font(34), fill=TEXT)

    cards = [("modele.usdz", "zoom 140 %", True), ("piece.obj", "zoom 100 %", False), ("scan.glb", "zoom 75 %", False)]
    cw, ch, gap, x0, y0 = 460, 310, 30, 40, 170
    for i, (name, zoom, is_cloud) in enumerate(cards):
        x = x0 + i * (cw + gap)
        rrect(d, [x, y0, x + cw, y0 + ch], 24, (32, 34, 52))
        d.rounded_rectangle([x, y0, x + cw, y0 + ch], radius=24, outline=CYAN if is_cloud else INDIGO, width=2)
        grad_circle(d, [x + 24, y0 + 24, x + 104, y0 + 104])
        if is_cloud:
            d.text((x + 42, y0 + 46), "☁", font=font(30), fill=(255, 255, 255))
        else:
            cube(d, x + 64, y0 + 66, 26, (255, 255, 255))
        d.text((x + 24, y0 + 132), name, font=font(28), fill=TEXT)
        rrect(d, [x + 24, y0 + 200, x + 230, y0 + 242], 21, (48, 50, 74))
        d.text((x + 40, y0 + 208), "🔍 " + zoom, font=font(20), fill=SUB)
        if is_cloud:
            rrect(d, [x + 244, y0 + 200, x + 356, y0 + 242], 21, (48, 50, 74))
            d.text((x + 260, y0 + 208), "☁ iCloud", font=font(20), fill=CYAN)

    grad_circle(d, [40, 540, 84, 584])
    d.text((58, 550), "☁", font=font(26), fill=(255, 255, 255))
    d.text((100, 546), "iCloud Drive", font=font(34), fill=TEXT)
    for i, r in enumerate(["animation.usdz  —  téléchargé", "personnage.glb  —  ☁ à télécharger"]):
        y = 610 + i * 58
        rrect(d, [40, y, W - 40, y + 46], 14, (32, 34, 52))
        d.rounded_rectangle([40, y, W - 40, y + 46], radius=14, outline=(60, 62, 90), width=1)
        grad_circle(d, [56, y + 8, 84, y + 36], CYAN, INDIGO)
        d.text((100, y + 10), r, font=font(22), fill=TEXT)
    d.text((40, H - 56), "Menu contextuel : Copier vers iCloud Drive / Supprimer", font=font(20), fill=SUB)
    img.save(os.path.join(OUT, "01-accueil.png"))


# ---------------------------------------------------------------- scène 3D
def mock_scene():
    img = base_bg()
    d = ImageDraw.Draw(img)
    rrect(d, [120, 90, W - 120, H - 90], 40, (20, 22, 38))
    d.rounded_rectangle([120, 90, W - 120, H - 90], radius=40, outline=(70, 72, 110), width=2)
    d.text((160, 118), "modele.usdz", font=font(30), fill=TEXT)
    glow(img, W // 2, 470, 320, INDIGO, 90)
    d = ImageDraw.Draw(img)
    cube(d, W // 2, 470, 150, CYAN)
    # HUD capsule
    hx, hy, hw, hh = 400, H - 230, 800, 76
    rrect(d, [hx, hy, hx + hw, hy + hh], 38, (40, 42, 66))
    d.rounded_rectangle([hx, hy, hx + hw, hy + hh], radius=38, outline=CYAN, width=2)
    d.text((hx + 32, hy + 24), "↺  Réinitialiser", font=font(24), fill=TEXT)
    d.text((hx + 290, hy + 24), "◎  Centrer", font=font(24), fill=TEXT)
    d.text((hx + 480, hy + 24), "zoom 140 %", font=font(24), fill=SUB)
    # bouton immersif dégradé
    bx, by = 560, H - 130
    rrect(d, [bx, by, bx + 480, by + 56], 28, INDIGO)
    for i in range(28):
        t = i / 27
        d.line([(bx + 2, by + 2 + i * 2), (bx + 478, by + 2 + i * 2)], fill=lerp(INDIGO, CYAN, t))
    d.text((bx + 150, by + 14), "👓  Mode immersif", font=font(22), fill=(255, 255, 255))
    img.save(os.path.join(OUT, "02-scene.png"))


# ---------------------------------------------------------------- immersif
def mock_immersive():
    img = vgradient((W, H), (4, 5, 12), (10, 6, 24))
    glow(img, W // 2, H // 2, 520, INDIGO, 130)
    glow(img, W - 200, 200, 260, CYAN, 70)
    d = ImageDraw.Draw(img)
    cube(d, W // 2, H // 2, 260, CYAN)
    rrect(d, [W - 440, 40, W - 40, 104], 32, (40, 42, 66))
    d.rounded_rectangle([W - 440, 40, W - 40, 104], radius=32, outline=CYAN, width=2)
    d.text((W - 420, 58), "✕  Quitter l'immersion", font=font(24), fill=TEXT)
    hx, hy, hw, hh = 480, H - 140, 640, 76
    rrect(d, [hx, hy, hx + hw, hy + hh], 38, (40, 42, 66))
    d.rounded_rectangle([hx, hy, hx + hw, hy + hh], radius=38, outline=INDIGO, width=2)
    d.text((hx + 30, hy + 24), "↺ Réinitialiser   ◎ Centrer   zoom 140 %", font=font(24), fill=TEXT)
    d.text((40, 40), "ImmersiveSpace — immersion totale (.full)", font=font(26), fill=SUB)
    img.save(os.path.join(OUT, "03-immersif.png"))


mock_home()
mock_scene()
mock_immersive()
print("OK ->", OUT)
