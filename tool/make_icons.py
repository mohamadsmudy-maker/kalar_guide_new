#!/usr/bin/env python3
"""Generates every app icon from assets/branding/app_icon_1024.png (1024x1024, full-bleed art).

Usage:  python3 tool/make_icons.py
Needs Pillow. Outputs Android (legacy + adaptive), iOS, web and the Play Store icon.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
MASTER = Image.open(ROOT / 'assets/branding/app_icon_1024.png').convert('RGB')
RES = ROOT / 'android/app/src/main/res'


def art(size):
    return MASTER.resize((size, size), Image.LANCZOS)


def rounded(size, radius=0.18):
    """Legacy launcher icon: art with transparent rounded corners."""
    img = art(size).convert('RGBA')
    mask = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size * 4 - 1, size * 4 - 1), radius=int(size * 4 * radius), fill=255)
    img.putalpha(mask.resize((size, size), Image.LANCZOS))
    return img


def padded(size, scale):
    """Art at [scale] of the canvas, on a blurred, darkened copy of itself.

    For adaptive (Android) and maskable (web) icons: launchers crop the outer
    part, so the important art stays inside the safe zone and the edge blends.
    """
    bg = art(size).filter(ImageFilter.GaussianBlur(size * 0.06))
    bg = Image.blend(bg, Image.new('RGB', (size, size), (10, 30, 70)), 0.45)
    inner = int(size * scale)
    fg = art(inner).convert('RGBA')
    feather = Image.new('L', (inner, inner), 0)
    pad = max(2, inner // 40)
    ImageDraw.Draw(feather).rounded_rectangle(
        (pad, pad, inner - pad, inner - pad), radius=inner // 6, fill=255)
    fg.putalpha(feather.filter(ImageFilter.GaussianBlur(pad)))
    out = bg.convert('RGBA')
    off = (size - inner) // 2
    out.alpha_composite(fg, (off, off))
    return out.convert('RGB')


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


# Android: legacy mipmaps (48dp) and adaptive foregrounds (108dp)
for name, f in {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}.items():
    save(rounded(int(48 * f)), RES / f'mipmap-{name}/ic_launcher.png')
    save(padded(int(108 * f), 0.72), RES / f'drawable-{name}/ic_launcher_foreground.png')

# iOS: opaque, square (iOS applies its own corner mask)
ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for i in json.loads((ios / 'Contents.json').read_text())['images']:
    px = round(float(i['size'].split('x')[0]) * int(i['scale'][0]))
    save(art(px), ios / i['filename'])

# Web
web = ROOT / 'web'
save(art(192), web / 'icons/Icon-192.png')
save(art(512), web / 'icons/Icon-512.png')
save(padded(192, 0.8), web / 'icons/Icon-maskable-192.png')
save(padded(512, 0.8), web / 'icons/Icon-maskable-512.png')
save(art(32), web / 'favicon.png')

# Google Play: 512x512, square, no transparency (Play rounds the corners)
save(art(512), ROOT / 'assets/branding/play_icon_512.png')
print('icons generated')
