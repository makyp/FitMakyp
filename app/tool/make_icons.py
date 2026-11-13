"""Genera los iconos de FitMakyp (Android, web y notificación).

Uso:  python -I tool/make_icons.py   (desde la carpeta app)
"""
from pathlib import Path

from PIL import Image, ImageDraw

DEEP = (43, 27, 67)
PRIMARY = (112, 65, 184)
LAVENDER = (220, 203, 250)


def glyph(draw: ImageDraw.ImageDraw, s: int, color, accent):
    """Mancuerna estilizada + punto (la 'chispa' de progreso). s = lado del lienzo."""
    cy = s * 0.54
    bar_h = s * 0.075
    draw.rounded_rectangle((s * 0.30, cy - bar_h / 2, s * 0.70, cy + bar_h / 2), radius=bar_h / 2, fill=color)
    for x in (0.22, 0.70):
        draw.rounded_rectangle((s * x, cy - s * 0.17, s * (x + 0.08), cy + s * 0.17), radius=s * 0.03, fill=color)
    for x in (0.15, 0.79):
        draw.rounded_rectangle((s * x, cy - s * 0.11, s * (x + 0.06), cy + s * 0.11), radius=s * 0.025, fill=color)
    r = s * 0.06
    draw.ellipse((s * 0.5 - r, s * 0.24 - r, s * 0.5 + r, s * 0.24 + r), fill=accent)


def app_icon(size: int, rounded: bool = True, pad: float = 0.0) -> Image.Image:
    big = 1024
    im = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    # degradado diagonal
    grad = Image.new('RGBA', (big, big))
    gp = grad.load()
    for y in range(big):
        for x in range(big):
            t = (x + y) / (2 * big)
            gp[x, y] = tuple(int(DEEP[i] + (PRIMARY[i] - DEEP[i]) * t) for i in range(3)) + (255,)
    mask = Image.new('L', (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big, big), radius=big * 0.23 if rounded else 0, fill=255)
    im.paste(grad, (0, 0), mask)
    g = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    inner = int(big * (1 - 2 * pad))
    layer = Image.new('RGBA', (inner, inner), (0, 0, 0, 0))
    glyph(ImageDraw.Draw(layer), inner, (255, 255, 255, 255), LAVENDER + (255,))
    g.paste(layer, ((big - inner) // 2, (big - inner) // 2), layer)
    im.alpha_composite(g)
    return im.resize((size, size), Image.LANCZOS)


def notification_icon(size: int) -> Image.Image:
    big = 512
    im = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    glyph(ImageDraw.Draw(im), big, (255, 255, 255, 255), (255, 255, 255, 255))
    return im.resize((size, size), Image.LANCZOS)


def main():
    res = Path('android/app/src/main/res')
    for d, s in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        app_icon(s).save(res / f'mipmap-{d}' / 'ic_launcher.png')
    for d, s in {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96}.items():
        out = res / f'drawable-{d}'
        out.mkdir(exist_ok=True)
        notification_icon(s).save(out / 'ic_stat_fitmakyp.png')

    web = Path('web')
    app_icon(192).save(web / 'icons' / 'Icon-192.png')
    app_icon(512).save(web / 'icons' / 'Icon-512.png')
    app_icon(192, rounded=False, pad=0.1).save(web / 'icons' / 'Icon-maskable-192.png')
    app_icon(512, rounded=False, pad=0.1).save(web / 'icons' / 'Icon-maskable-512.png')
    app_icon(32).save(web / 'favicon.png')

    ios = Path('ios/Runner/Assets.xcassets/AppIcon.appiconset')
    for p in ios.glob('*.png'):
        w = Image.open(p).width
        app_icon(w, rounded=False).convert('RGB').save(p)  # iOS no admite transparencia
    app_icon(512).save('tool/icon_preview.png')


if __name__ == '__main__':
    main()
