#!/usr/bin/env python3
"""Google Play feature graphic (1024x500) in Kurdish, Arabic and English.

Usage:  python3 tool/make_feature_graphic.py
Needs Pillow built with libraqm (for Arabic-script shaping).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
ICON = Image.open(ROOT / 'assets/branding/app_icon_1024.png').convert('RGB')
RABAR = str(ROOT / 'assets/fonts/Rabar.ttf')
LATIN = str(ROOT / 'assets/fonts/Roboto-Regular.ttf')
OUT = ROOT / 'docs/play-store'
W, H = 1024, 500
GOLD = (245, 200, 92)

VERSIONS = {
    'ku': ('ڕێبەری کەلار', 'هەموو شتێکی کەلار لە یەک ئەپدا',
           'شوێن  •  هەواڵ  •  نرخ  •  سکاڵا  •  نوێژ'),
    'ar': ('دليل كلار', 'كل ما تحتاجه في كلار في تطبيق واحد',
           'أماكن  •  أخبار  •  أسعار  •  شكاوى  •  صلاة'),
    'en': ('Kalar Guide', 'Everything in Kalar, in one app',
           'Places  •  News  •  Prices  •  Complaints  •  Prayer'),
}


def gradient():
    img = Image.new('RGB', (W, H))
    top, bottom = (11, 38, 68), (15, 70, 82)
    px = img.load()
    for y in range(H):
        for x in range(W):
            t = 0.65 * y / H + 0.35 * x / W
            px[x, y] = tuple(int(a + (b - a) * t) for a, b in zip(top, bottom))
    return img


def rounded_icon(size):
    icon = ICON.resize((size, size), Image.LANCZOS).convert('RGBA')
    mask = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size * 4, size * 4), radius=size * 4 // 5, fill=255)
    icon.putalpha(mask.resize((size, size), Image.LANCZOS))
    return icon


def make(lang, title, tagline, features):
    img = gradient().convert('RGBA')
    rtl = lang != 'en'
    size = 300
    icon = rounded_icon(size)
    # glow behind the icon
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ix = 70 if rtl else W - 70 - size
    iy = (H - size) // 2
    ImageDraw.Draw(glow).rounded_rectangle((ix - 10, iy - 10, ix + size + 10, iy + size + 10),
                                           radius=70, fill=(245, 200, 92, 110))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(28)))
    img.alpha_composite(icon, (ix, iy))

    d = ImageDraw.Draw(img)
    font = RABAR if rtl else LATIN
    kw = {'direction': 'rtl', 'language': lang} if rtl else {}
    text_right = W - 70 if rtl else ix - 50
    text_left = ix + size + 50 if rtl else 70
    box = text_right - text_left

    def fit(text, start, minimum=20):
        s = start
        while s > minimum:
            f = ImageFont.truetype(font, s, layout_engine=ImageFont.Layout.RAQM)
            if d.textlength(text, font=f, **kw) <= box:
                return f
            s -= 2
        return ImageFont.truetype(font, minimum, layout_engine=ImageFont.Layout.RAQM)

    def line(text, y, f, fill):
        w = d.textlength(text, font=f, **kw)
        x = text_right - w if rtl else text_left
        d.text((x, y), text, font=f, fill=fill, **kw)

    line(title, 110, fit(title, 96), (255, 255, 255))
    d.rounded_rectangle(((text_right - 120) if rtl else text_left, 240,
                         text_right if rtl else text_left + 120, 246), radius=3, fill=GOLD)
    line(tagline, 268, fit(tagline, 40), (225, 235, 245))
    line(features, 340, fit(features, 30), GOLD)
    img.convert('RGB').save(OUT / f'feature_graphic_{lang}.png', optimize=True)


OUT.mkdir(parents=True, exist_ok=True)
for lang, texts in VERSIONS.items():
    make(lang, *texts)
print('feature graphics generated')
