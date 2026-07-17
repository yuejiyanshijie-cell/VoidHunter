"""
generate_sprites.py - Void Hunter Pixel Art Generator
Generates all placeholder pixel art assets for the demo.
"""
import math, os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "assets", "sprites")
SCALE = 2

# ----- Color palette (RGB tuples) -----
C = {
    "void_black":    (8, 8, 16),
    "dark_gray":     (24, 24, 40),
    "mid_gray":      (48, 48, 64),
    "metal_silver":  (180, 180, 200),
    "metal_rust":    (140, 100, 60),
    "cloak_dark":    (16, 12, 24),
    "cloak_accent":  (32, 20, 48),
    "eye_cyan":      (0, 220, 255),
    "energy_blue":   (60, 80, 255),
    "energy_purple": (140, 40, 255),
    "energy_light":  (180, 140, 255),
    "enemy_mech":    (80, 60, 40),
    "enemy_guard":   (60, 60, 140),
    "enemy_boss":    (140, 30, 30),
    "tile_wall":     (30, 30, 50),
    "tile_floor":    (50, 50, 70),
    "tile_platform": (40, 40, 100),
    "ui_bg":         (20, 20, 40),
    "ui_border":     (100, 100, 180),
    "ui_health":     (200, 40, 40),
    "ui_energy":     (60, 80, 255),
}

def fc(name, a=255):
    """full color = C[name] + (alpha,)"""
    return C[name] + (a,)

def make(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))

def save(img, path):
    img = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print(f"  Saved: {path}")

def px(draw, xy, color):
    try:
        draw.point(xy, fill=color)
    except:
        pass

# =====================================================
# PLAYER SPRITES (32x32 base)
# =====================================================
def gen_player():
    print("\n[Player]")
    base = os.path.join(OUT, "player")

    # --- Idle (2 frames) ---
    for fi in range(2):
        img = make(32, 32); d = ImageDraw.Draw(img)
        for y in range(8, 28):
            for x in range(8, 24): px(d, (x, y), fc("cloak_dark"))
        for y in range(2, 10):
            for x in range(12, 20): px(d, (x, y), fc("dark_gray"))
        for y in range(0, 4):
            for x in range(11, 21): px(d, (x, y), fc("cloak_dark"))
        img.putpixel((14, 5), fc("eye_cyan"))
        img.putpixel((17, 5), fc("eye_cyan"))
        for y in range(26, 32):
            px(d, (11, y), fc("dark_gray")); px(d, (20, y), fc("dark_gray"))
        ao = 0 if fi == 0 else 1
        for y in range(14, 22):
            px(d, (24 + ao, y), fc("mid_gray")); px(d, (7 - ao, y), fc("mid_gray"))
        for y in range(16, 26):
            px(d, (27, y + fi * 2), fc("metal_silver"))
        save(img, f"{base}/idle_{fi}.png")

    # --- Run (4 frames) ---
    for fi in range(4):
        img = make(32, 32); d = ImageDraw.Draw(img)
        tilt = 1 if fi % 2 == 0 else -1
        for y in range(8, 26):
            for x in range(8, 24): px(d, (x + (tilt if y > 18 else 0), y), fc("cloak_dark"))
        for y in range(2, 10):
            for x in range(12, 20): px(d, (x, y), fc("dark_gray"))
        img.putpixel((14, 5), fc("eye_cyan")); img.putpixel((17, 5), fc("eye_cyan"))
        for y in range(0, 4):
            for x in range(11, 21): px(d, (x, y), fc("cloak_dark"))
        ly = [26, 28, 26, 28][fi]
        for y in range(ly, 32):
            px(d, (11, y), fc("dark_gray")); px(d, (20, y), fc("dark_gray"))
        save(img, f"{base}/run_{fi}.png")

    # --- Jump ---
    for jt, name in [("up", "jump_up"), ("down", "jump_down")]:
        img = make(32, 32); d = ImageDraw.Draw(img)
        for y in range(6, 24):
            for x in range(8, 24): px(d, (x, y), fc("cloak_dark"))
        for y in range(0, 6):
            for x in range(12, 20): px(d, (x, y), fc("dark_gray"))
        img.putpixel((14, 2), fc("eye_cyan")); img.putpixel((17, 2), fc("eye_cyan"))
        if jt == "up":
            for y in range(22, 28):
                for x in [10, 13, 18, 21]: px(d, (x, y), fc("dark_gray"))
        else:
            for y in range(22, 32):
                for x in [9, 12, 19, 22]: px(d, (x, y), fc("dark_gray"))
        save(img, f"{base}/{name}.png")

    # --- Wall Slide ---
    img = make(32, 32); d = ImageDraw.Draw(img)
    for y in range(4, 28):
        for x in range(6, 22): px(d, (x, y), fc("cloak_dark"))
    for y in range(0, 6):
        for x in range(10, 18): px(d, (x, y), fc("dark_gray"))
    img.putpixel((12, 2), fc("eye_cyan")); img.putpixel((15, 2), fc("eye_cyan"))
    for y in range(14, 18):
        px(d, (22, y), fc("mid_gray")); px(d, (23, y), fc("mid_gray"))
    save(img, f"{base}/wall_slide.png")

    # --- Dash ---
    img = make(32, 32); d = ImageDraw.Draw(img)
    for y in range(6, 26):
        for x in range(6, 26): px(d, (x + (y - 10) // 3, y), fc("cloak_dark"))
    for y in range(0, 6):
        for x in range(14, 22): px(d, (x, y), fc("dark_gray"))
    for i in range(4):
        px(d, (2 + i, 10 + i * 3), fc("energy_blue", 100 - i * 25))
        px(d, (3 + i, 11 + i * 3), fc("energy_purple", 100 - i * 25))
    save(img, f"{base}/dash.png")

    # --- Attack 1/2/3 ---
    scs = ["metal_silver", "energy_blue", "energy_purple"]
    for ai in range(3):
        img = make(48, 32); d = ImageDraw.Draw(img)
        for y in range(4, 28):
            for x in range(8, 24): px(d, (x, y), fc("cloak_dark"))
        for y in range(0, 4):
            for x in range(12, 20): px(d, (x, y), fc("dark_gray"))
        img.putpixel((14, 1), fc("eye_cyan")); img.putpixel((17, 1), fc("eye_cyan"))
        for sy in range(10, 24):
            for sx in range(24, 34 + ai * 5):
                px(d, (sx, sy + (ai - 1) * 4), fc(scs[ai], 150))
        for i in range(8):
            ang = math.pi * i / 8
            sx = int(24 + 12 * math.cos(ang))
            sy = int(16 + 8 * math.sin(ang))
            px(d, (sx, sy), fc("energy_light", 120))
        save(img, f"{base}/attack_{ai + 1}.png")

    # --- Heavy Attack ---
    img = make(48, 32); d = ImageDraw.Draw(img)
    for y in range(4, 28):
        for x in range(8, 24): px(d, (x, y), fc("cloak_dark"))
    for y in range(0, 4):
        for x in range(12, 20): px(d, (x, y), fc("dark_gray"))
    img.putpixel((14, 1), fc("eye_cyan")); img.putpixel((17, 1), fc("eye_cyan"))
    for y in range(6, 28):
        for x in range(24, 32): px(d, (x, y), fc("energy_purple", 180))
    for i in range(5):
        px(d, (20 + i * 2, 15 + i), fc("energy_light", 150))
    save(img, f"{base}/attack_heavy.png")

    # --- Death ---
    img = make(32, 32); d = ImageDraw.Draw(img)
    for y in range(18, 30):
        for x in range(6, 26): px(d, (x, y), fc("cloak_dark"))
    for y in range(14, 20):
        for x in range(10, 22): px(d, (x, y), fc("dark_gray"))
    img.putpixel((14, 15), fc("eye_cyan", 60))
    save(img, f"{base}/death.png")


# =====================================================
# ENEMY SPRITES
# =====================================================
def gen_enemies():
    print("\n[Enemies]")
    base = os.path.join(OUT, "enemies")

    # --- Bug (24x16, 2 frames) ---
    for fi in range(2):
        img = make(24, 16); d = ImageDraw.Draw(img)
        for y in range(4, 14):
            for x in range(4, 20): px(d, (x, y), fc("enemy_mech"))
        for y in range(2, 6):
            for x in range(5, 19): px(d, (x, y), fc("mid_gray"))
        for x in range(5, 18, 3):
            px(d, (x, 14 + fi), fc("dark_gray"))
            px(d, (x + 1, 15 - fi), fc("dark_gray"))
        img.putpixel((17, 5), fc("enemy_boss")); img.putpixel((18, 5), fc("enemy_boss"))
        save(img, f"{base}/bug_{fi}.png")

    # --- Guard (28x28, 2 frames) ---
    for fi in range(2):
        img = make(28, 28); d = ImageDraw.Draw(img)
        for y in range(6, 22):
            for x in range(6, 22): px(d, (x, y), fc("enemy_guard"))
        for y in range(4, 8):
            for x in range(4, 24): px(d, (x, y), fc("mid_gray"))
        for y in range(0, 8):
            for x in range(8, 20): px(d, (x, y), fc("dark_gray"))
        img.putpixel((11, 3), fc("energy_blue")); img.putpixel((16, 3), fc("energy_blue"))
        for y in range(12, 16):
            for x in range(10, 18): px(d, (x, y), fc("energy_light", 120 + fi * 40))
        save(img, f"{base}/guard_{fi}.png")

    # --- Boss (48x40, 4 frames) ---
    for fi in range(4):
        img = make(48, 40); d = ImageDraw.Draw(img)
        for y in range(8, 36):
            for x in range(4, 44): px(d, (x, y), fc("dark_gray"))
        for y in range(4, 12):
            for x in range(6, 42): px(d, (x, y), fc("enemy_boss"))
        for y in range(0, 10):
            for x in range(12, 36): px(d, (x, y), fc("enemy_mech"))
        for ex in [16, 22, 28]:
            img.putpixel((ex, 3 + fi % 2), fc("energy_purple"))
        for y in range(30, 40):
            px(d, (2, y), fc("metal_rust")); px(d, (45, y), fc("metal_rust"))
        for x in [8, 16, 24, 32, 40]:
            px(d, (x, 36 + (x + fi * 2) % 2 * 2), fc("enemy_boss"))
        save(img, f"{base}/boss_{fi}.png")


# =====================================================
# TILES (16x16 base)
# =====================================================
def gen_tiles():
    print("\n[Tiles]")
    base = os.path.join(OUT, "tiles")

    # Wall
    img = make(16, 16); d = ImageDraw.Draw(img)
    for y in range(16):
        for x in range(16): px(d, (x, y), fc("tile_wall"))
    for y in [4, 8, 12]:
        for x in range(16): px(d, (x, y), fc("void_black", 80))
    for x in [8]:
        for y in range(16): px(d, (x, y), fc("void_black", 40))
    px(d, (3, 3), fc("energy_blue", 30)); px(d, (11, 11), fc("energy_purple", 30))
    save(img, f"{base}/wall.png")

    # Floor
    img = make(16, 16); d = ImageDraw.Draw(img)
    for y in range(16):
        for x in range(16): px(d, (x, y), fc("tile_floor"))
    for x in range(16): px(d, (x, 8), fc("mid_gray", 100))
    for y in range(16): px(d, (0, y), fc("mid_gray", 60))
    save(img, f"{base}/floor.png")

    # Platform
    img = make(48, 8); d = ImageDraw.Draw(img)
    for y in range(8):
        for x in range(48):
            px(d, (x, y), fc("tile_platform", 255) if y < 3 else fc("dark_gray", 255))
    for x in range(4, 44): px(d, (x, 2), fc("energy_blue", 80))
    save(img, f"{base}/platform.png")

    # Pillar
    img = make(16, 32); d = ImageDraw.Draw(img)
    for y in range(32):
        for x in range(16):
            px(d, (x, y), fc("tile_wall", 255) if x < 14 else fc("mid_gray", 255))
    for y in range(4, 28, 6):
        for x in range(2, 13): px(d, (x, y), fc("energy_purple", 40))
    save(img, f"{base}/pillar.png")

    # Pipe (background decoration)
    img = make(32, 8); d = ImageDraw.Draw(img)
    for y in range(8):
        for x in range(32):
            px(d, (x, y), fc("energy_blue", 60) if y in [2, 3, 4, 5] else fc("dark_gray", 120))
    save(img, f"{base}/pipe_bg.png")


# =====================================================
# EFFECT SPRITES
# =====================================================
def gen_effects():
    print("\n[Effects]")
    base = os.path.join(OUT, "effects")

    # Slash (3 frames)
    for fi in range(3):
        img = make(32, 16); d = ImageDraw.Draw(img)
        cx, cy = 16, 8
        for i in range(14):
            ang = math.pi * 0.7 - i * math.pi * 0.7 / 14
            r = 12 - fi * 2
            x = int(cx + r * math.cos(ang))
            y = int(cy + r * math.sin(ang) * 0.7)
            px(d, (x, y), fc("energy_light", 200 - fi * 30))
        save(img, f"{base}/slash_{fi}.png")

    # Hit spark (4 frames)
    for fi in range(4):
        img = make(16, 16); d = ImageDraw.Draw(img)
        cx, cy = 8, 8
        for i in range(6):
            ang = i * math.pi * 2 / 6 + fi * 0.3
            r = 4 + fi * 2
            px(d, (int(cx + r * math.cos(ang)), int(cy + r * math.sin(ang))), fc("energy_light", 180 - fi * 40))
        save(img, f"{base}/hit_spark_{fi}.png")

    # Blast (5 frames)
    for fi in range(5):
        img = make(48, 48); d = ImageDraw.Draw(img)
        cx, cy = 24, 24
        for i in range(12):
            ang = i * math.pi * 2 / 12 + fi * 0.5
            r = 6 + fi * 5
            px(d, (int(cx + r * math.cos(ang)), int(cy + r * math.sin(ang))), fc("energy_purple", 200 - fi * 35))
            px(d, (int(cx + r * math.cos(ang) + 1), int(cy + r * math.sin(ang))), fc("energy_blue", 200 - fi * 35))
            px(d, (int(cx + r * math.cos(ang) - 1), int(cy + r * math.sin(ang))), fc("energy_blue", 200 - fi * 35))
        save(img, f"{base}/blast_{fi}.png")


# =====================================================
# UI SPRITES
# =====================================================
def gen_ui():
    print("\n[UI]")
    base = os.path.join(OUT, "ui")

    # Health bar background
    img = make(120, 12); d = ImageDraw.Draw(img)
    for y in range(12):
        for x in range(120):
            if y < 2 or y > 9: px(d, (x, y), fc("ui_border"))
            elif x < 2 or x > 117: px(d, (x, y), fc("ui_border"))
            else: px(d, (x, y), fc("ui_health"))
    save(img, f"{base}/health_bar_bg.png")

    # Energy bar
    img = make(120, 8); d = ImageDraw.Draw(img)
    for y in range(8):
        for x in range(120):
            if y < 1 or y > 6: px(d, (x, y), fc("ui_border"))
            elif x < 1 or x > 118: px(d, (x, y), fc("ui_border"))
            else: px(d, (x, y), fc("ui_energy"))
    save(img, f"{base}/energy_bar.png")

    # Skill icons (24x24)
    for si, sn in enumerate(["skill_mech_blast", "skill_void_slash"]):
        img = make(24, 24); d = ImageDraw.Draw(img)
        for y in range(24):
            for x in range(24):
                if y == 0 or y == 23 or x == 0 or x == 23: px(d, (x, y), fc("ui_border"))
                elif y < 2 or y > 21 or x < 2 or x > 21: px(d, (x, y), fc("dark_gray"))
                else: px(d, (x, y), fc("ui_bg"))
        cx = 12
        if si == 0:
            for r in [4, 6, 8]:
                for i in range(8):
                    ang = i * math.pi * 2 / 8
                    px(d, (int(cx + r * math.cos(ang)), int(cx + r * math.sin(ang) * 0.5)), fc("energy_blue"))
        else:
            for i in range(7):
                px(d, (cx - 3 + i, cx - 3 + i), fc("energy_purple"))
                px(d, (cx + 3 - i, cx - 3 + i), fc("energy_purple"))
        save(img, f"{base}/{sn}.png")


# =====================================================
if __name__ == "__main__":
    print("=" * 50)
    print("  Void Hunter - Pixel Art Generator")
    print("=" * 50)
    gen_player()
    gen_enemies()
    gen_tiles()
    gen_effects()
    gen_ui()
    print("\nAll sprites generated!")
