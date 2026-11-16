#!/usr/bin/env python3
"""Builds every app icon / splash image from ONE source picture.

    python3 tool/make_app_icons.py path/to/icon.png

The source may be the finished "rounded square with a border" artwork. The
border and its rounded corners are cut away (INSET) so the art is a plain,
full-bleed square — the operating systems add their own mask.

Writes: Android launcher icons (legacy + adaptive foreground), the native
splash images (circle with a thin green ring), iOS app icons + launch images,
and assets/images/kalar.png + assets/branding/app_icon_1024.png.
Requires Pillow.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "android/app/src/main/res"
IOS = ROOT / "ios/Runner/Assets.xcassets"

# share of the source edge (in %) removed on every side: frame + rounded corners
INSET = 9.8
RING = (0x3D, 0xD6, 0x68)       # splash ring colour (same as splash_screen.dart)
SPLASH_BG = (30, 136, 229)      # splash background (#1E88E5)
DENSITY = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}


def load_art(path: str) -> Image.Image:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    side = min(w, h)
    im = im.crop(((w - side) // 2, (h - side) // 2, (w - side) // 2 + side, (h - side) // 2 + side))
    c = round(side * INSET / 100)
    art = im.crop((c, c, side - c, side - c))
    return art.resize((2048, 2048), Image.LANCZOS)


def save(img: Image.Image, path: Path, size: int | tuple | None = None) -> None:
    if size is not None:
        sz = (size, size) if isinstance(size, int) else size
        img = img.resize(sz, Image.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def adaptive_foreground(art: Image.Image, px: int, scale: float = 0.69) -> Image.Image:
    """Art at `scale` of the canvas; the rest is the same art, blurred, so there
    is no visible edge when a launcher shows a larger mask or parallax."""
    canvas = art.resize((px, px), Image.LANCZOS).filter(ImageFilter.GaussianBlur(px * 0.05))
    inner = max(2, round(px * scale))
    sharp = art.resize((inner, inner), Image.LANCZOS)
    feather = max(2, round(inner * 0.035))
    mask = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(mask).rectangle(
        (feather, feather, inner - feather, inner - feather), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(feather / 2))
    off = (px - inner) // 2
    canvas.paste(sharp, (off, off), mask)
    return canvas.convert("RGBA")


def circle_badge(art: Image.Image, diameter: int, ring_px: float, gap_px: float,
                 with_ring: bool = True) -> Image.Image:
    """Transparent square of `diameter`: green ring, small gap, circular art."""
    ss = 4  # supersample for clean edges
    d = diameter * ss
    out = Image.new("RGBA", (d, d), (0, 0, 0, 0))
    draw = ImageDraw.Draw(out)
    if with_ring:
        draw.ellipse((0, 0, d - 1, d - 1), fill=RING + (255,))
        gap_in = round((ring_px) * ss)
        draw.ellipse((gap_in, gap_in, d - 1 - gap_in, d - 1 - gap_in), fill=(0, 0, 0, 0))
    inset = round((ring_px + gap_px) * ss)
    inner = d - 2 * inset
    pic = art.resize((inner, inner), Image.LANCZOS).convert("RGBA")
    m = Image.new("L", (inner, inner), 0)
    ImageDraw.Draw(m).ellipse((0, 0, inner - 1, inner - 1), fill=255)
    out.paste(pic, (inset, inset), m)
    return out.resize((diameter, diameter), Image.LANCZOS)


def splash_canvas(badge: Image.Image, w: int, h: int) -> Image.Image:
    c = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    c.alpha_composite(badge, ((w - badge.width) // 2, (h - badge.height) // 2))
    return c


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    art = load_art(sys.argv[1])

    # ── shared assets ─────────────────────────────────────────
    save(art, ROOT / "assets/branding/app_icon_1024.png", 1024)
    save(art, ROOT / "assets/images/kalar.png", 1024)

    # ── Android launcher ──────────────────────────────────────
    for name, f in DENSITY.items():
        save(art, RES / f"mipmap-{name}/ic_launcher.png", round(48 * f))
        fg = adaptive_foreground(art, round(108 * f))
        save(fg, RES / f"drawable-{name}/ic_launcher_foreground.png")

    # ── native splash (day + night identical): ring 3dp, gap 4dp ──
    sizes = {"mdpi": (225, 400), "hdpi": (337, 600), "xhdpi": (450, 800),
             "xxhdpi": (675, 1200), "xxxhdpi": (901, 1600)}
    for name, (w, h) in sizes.items():
        f = DENSITY[name]
        big = circle_badge(art, round(200 * f), 3 * f, 4 * f)
        a12 = circle_badge(art, round(126.25 * f), 3 * f * 0.63, 4 * f * 0.63)
        for pre in ("drawable", "drawable-night"):
            save(splash_canvas(big, w, h), RES / f"{pre}-{name}/splash.png")
            save(splash_canvas(a12, w, h), RES / f"{pre}-{name}/android12splash.png")

    # ── iOS app icons: every file keeps its current pixel size ─────
    for p in sorted((IOS / "AppIcon.appiconset").glob("*.png")):
        size = Image.open(p).size
        save(art, p, size[0])

    # ── iOS launch images (badge on the splash colour) ──────────────
    for p in sorted((IOS / "LaunchImage.imageset").glob("*.png")):
        w, h = Image.open(p).size
        f = w / 225
        badge = circle_badge(art, round(200 * f), 3 * f, 4 * f)
        bg = Image.new("RGBA", (w, h), SPLASH_BG + (255,))
        bg.alpha_composite(badge, ((w - badge.width) // 2, (h - badge.height) // 2))
        bg.convert("RGB").save(p, optimize=True)

    # the adaptive-icon background shows through only if a launcher scales the
    # icon down; use the art's own edge colour
    edge = art.resize((1, 1), Image.BOX).getpixel((0, 0))
    print("average art colour:", "#%02X%02X%02X" % edge)


if __name__ == "__main__":
    main()
