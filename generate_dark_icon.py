from PIL import Image, ImageDraw, ImageFilter
import math, os

OUTPUT_DIR = "/home/user/ChefPro/CarTracker/CarTracker/Assets.xcassets/AppIconDark.appiconset"
os.makedirs(OUTPUT_DIR, exist_ok=True)

SIZE = 1024

def draw_icon(size):
    img = Image.new("RGB", (size, size), color=(28, 28, 46))
    draw = ImageDraw.Draw(img)

    s = size / 1024

    # --- Car silhouette (white/light) ---
    car_color = (230, 230, 245)

    # Car body - lower rectangle
    body_x1 = int(100 * s)
    body_y1 = int(520 * s)
    body_x2 = int(924 * s)
    body_y2 = int(720 * s)
    draw.rounded_rectangle([body_x1, body_y1, body_x2, body_y2], radius=int(30 * s), fill=car_color)

    # Car cabin - upper trapezoid
    cabin_points = [
        (int(270 * s), int(520 * s)),
        (int(390 * s), int(360 * s)),
        (int(700 * s), int(360 * s)),
        (int(800 * s), int(520 * s)),
    ]
    draw.polygon(cabin_points, fill=car_color)

    # Windows (dark)
    win_color = (28, 28, 46)
    # Left window
    left_win = [
        (int(295 * s), int(505 * s)),
        (int(390 * s), int(385 * s)),
        (int(510 * s), int(385 * s)),
        (int(510 * s), int(505 * s)),
    ]
    draw.polygon(left_win, fill=win_color)
    # Right window
    right_win = [
        (int(525 * s), int(505 * s)),
        (int(525 * s), int(385 * s)),
        (int(690 * s), int(385 * s)),
        (int(775 * s), int(505 * s)),
    ]
    draw.polygon(right_win, fill=win_color)

    # Wheels
    wheel_color = (40, 40, 60)
    rim_color = (180, 180, 200)
    wheel_radius = int(110 * s)
    rim_radius = int(60 * s)

    for wx in [int(270 * s), int(750 * s)]:
        wy = int(700 * s)
        draw.ellipse([wx - wheel_radius, wy - wheel_radius, wx + wheel_radius, wy + wheel_radius], fill=wheel_color)
        draw.ellipse([wx - rim_radius, wy - rim_radius, wx + rim_radius, wy + rim_radius], fill=rim_color)
        draw.ellipse([wx - int(30*s), wy - int(30*s), wx + int(30*s), wy + int(30*s)], fill=wheel_color)

    # Wheel arches (cutouts from body to look natural)
    arch_color = (28, 28, 46)
    arch_r = int(120 * s)
    for wx in [int(270 * s), int(750 * s)]:
        wy = int(685 * s)
        draw.ellipse([wx - arch_r, wy - arch_r, wx + arch_r, wy + arch_r], fill=arch_color)

    # Redraw wheel on top
    for wx in [int(270 * s), int(750 * s)]:
        wy = int(700 * s)
        draw.ellipse([wx - wheel_radius, wy - wheel_radius, wx + wheel_radius, wy + wheel_radius], fill=wheel_color)
        draw.ellipse([wx - rim_radius, wy - rim_radius, wx + rim_radius, wy + rim_radius], fill=rim_color)
        draw.ellipse([wx - int(30*s), wy - int(30*s), wx + int(30*s), wy + int(30*s)], fill=wheel_color)

    # Headlights
    draw.ellipse([int(890*s), int(560*s), int(940*s), int(600*s)], fill=(255, 255, 200))
    # Tail light
    draw.ellipse([int(84*s), int(560*s), int(120*s), int(600*s)], fill=(255, 80, 80))

    # --- Green coin with ruble symbol (bottom right) ---
    coin_cx = int(780 * s)
    coin_cy = int(820 * s)
    coin_r = int(160 * s)

    # Coin shadow/glow
    glow_color = (20, 80, 20)
    draw.ellipse([coin_cx - coin_r - int(8*s), coin_cy - coin_r - int(8*s),
                  coin_cx + coin_r + int(8*s), coin_cy + coin_r + int(8*s)], fill=glow_color)

    # Coin body gradient simulation (layered circles)
    for i, (r_off, col) in enumerate([
        (0, (34, 139, 34)),
        (-8*s, (50, 160, 50)),
        (-20*s, (60, 180, 60)),
    ]):
        r = coin_r + int(r_off)
        draw.ellipse([coin_cx - r, coin_cy - r, coin_cx + r, coin_cy + r], fill=col)

    # Coin edge highlight
    draw.arc([coin_cx - coin_r, coin_cy - coin_r, coin_cx + coin_r, coin_cy + coin_r],
             start=200, end=340, fill=(100, 220, 100), width=int(6*s))

    # Ruble symbol (₽) drawn manually
    rc = (255, 255, 255)
    lw = int(18 * s)
    # Vertical stem
    stem_x = int(coin_cx - 20 * s)
    stem_top = int(coin_cy - 80 * s)
    stem_bot = int(coin_cy + 80 * s)
    draw.rectangle([stem_x, stem_top, stem_x + lw, stem_bot], fill=rc)

    # Top horizontal bar (arch of P)
    arch_left = stem_x
    arch_right = int(coin_cx + 50 * s)
    arch_top = stem_top
    arch_bot = int(coin_cy - 10 * s)
    arch_mid_x = (arch_left + arch_right) // 2
    arch_mid_y = (arch_top + arch_bot) // 2

    # Draw the D shape of the ruble
    # Top bar
    draw.rectangle([arch_left, arch_top, arch_right, arch_top + lw], fill=rc)
    # Right arc using ellipse arc
    arc_box = [arch_left + int(10*s), arch_top, arch_right + int(10*s), arch_bot + lw]
    draw.arc(arc_box, start=270, end=90, fill=rc, width=lw)
    # Bottom bar of arch
    draw.rectangle([arch_left, arch_bot, arch_right, arch_bot + lw], fill=rc)

    # Two horizontal lines below arch (ruble style)
    line1_y = int(coin_cy + 5 * s)
    line2_y = int(coin_cy + 30 * s)
    line_left = int(coin_cx - 55 * s)
    line_right = int(coin_cx + 60 * s)
    draw.rectangle([line_left, line1_y, line_right, line1_y + lw], fill=rc)
    draw.rectangle([line_left, line2_y, line_right, line2_y + lw], fill=rc)

    return img

# Generate all sizes
sizes = [1024, 20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180]

for sz in sizes:
    img = draw_icon(sz)
    if sz == 1024:
        fname = "AppIcon-1024.png"
    else:
        fname = f"AppIcon-{sz}.png"
    path = os.path.join(OUTPUT_DIR, fname)
    img.save(path, "PNG")
    print(f"Saved {path} ({sz}x{sz})")

print("Done!")
