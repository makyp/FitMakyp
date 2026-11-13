"""Separa cada imagen de ejercicio (inicio -> flecha -> final) en dos fotogramas.

Uso:  python -I tool/split_exercise_images.py   (desde la carpeta app)

Entrada:  assets/exercises/<id>.png         (originales, no se modifican)
Salida:   assets/exercises/frames/<id>_start.png, <id>_end.png
          o <id>_hold.png si la imagen tiene una sola posición (sin flecha)
          tool/contact_sheet.png para revisar el resultado
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = Path('assets/exercises')
OUT = SRC / 'frames'
SCALE = 3          # ampliación
OUT_H = 360        # alto final de cada fotograma (px)

# Ajustes manuales por imagen si la detección automática no basta: (top, bottom) relativos 0..1
OVERRIDES: dict[str, dict] = {}

# Imágenes en las que asoma abajo el título de la tarjeta siguiente.
CUT_NEXT_TITLE = {'curl_de_biceps'}


def card_rows(a: np.ndarray) -> tuple[int, int]:
    """Filas de la tarjeta principal: descarta franjas de tarjetas vecinas separadas por bandas blancas."""
    h = a.shape[0]
    bright = a.mean(axis=2)
    # Fila "separador": casi blanca y uniforme
    sep = (bright.mean(axis=1) > 246) & (bright.std(axis=1) < 4)
    # Segmentos entre separadores; nos quedamos con el más alto
    segs, start = [], None
    for y in range(h):
        if not sep[y] and start is None:
            start = y
        if sep[y] and start is not None:
            segs.append((start, y)); start = None
    if start is not None:
        segs.append((start, h))
    segs = [s for s in segs if s[1] - s[0] > 8] or [(0, h)]
    return max(segs, key=lambda s: s[1] - s[0])


def arrow_cols(a: np.ndarray, top: int, bottom: int) -> tuple[int, int] | None:
    """Columnas de la flecha morada (#7041B8 aprox.) en la franja central."""
    r, g, b = a[top:bottom, :, 0], a[top:bottom, :, 1], a[top:bottom, :, 2]
    # Morado en cualquier tono (oscuro o lavanda), excluyendo el azul marino del texto (r bajo).
    purple = (r > 70) & (r < 200) & (b > 140) & (b - g > 55) & (b - r > 30)
    w = a.shape[1]
    cols = np.where(purple.sum(axis=0) >= 2)[0]
    cols = cols[(cols > w * 0.3) & (cols < w * 0.7)]
    if len(cols) < 3:
        return None
    # agrupa en el cluster más grande
    groups, cur = [], [cols[0]]
    for c in cols[1:]:
        if c - cur[-1] <= 2:
            cur.append(c)
        else:
            groups.append(cur); cur = [c]
    groups.append(cur)
    best = max(groups, key=len)
    if len(best) < 5:
        return None
    return best[0], best[-1]


def title_bottom(a: np.ndarray, top: int, bottom: int) -> int:
    """Última fila del título (texto azul marino) en la parte superior de la tarjeta."""
    limit = top + int((bottom - top) * 0.42)
    r, g, b = (a[top:limit, :, i].astype(int) for i in range(3))
    navy = (r < 90) & (g < 80) & (b > 70) & (b - r > 25)
    rows = np.where(navy.sum(axis=1) >= 3)[0]
    if len(rows) == 0:
        return top
    # Solo el primer bloque continuo de filas con texto (el pelo de la figura viene después).
    end = rows[0]
    for y in rows[1:]:
        if y - end > 6:
            break
        end = y
    return top + end + 3


def card_cols(a: np.ndarray) -> tuple[int, int]:
    """Igual que card_rows pero en horizontal (quita franjas de tarjetas a los lados)."""
    l, r = card_rows(a.transpose(1, 0, 2))
    return l, r


def next_title_top(a: np.ndarray, top: int, bottom: int) -> int:
    """Si asoma el título de la tarjeta siguiente abajo, corta por encima."""
    start = top + int((bottom - top) * 0.6)
    r, g, b = (a[start:bottom, :, i].astype(int) for i in range(3))
    navy = (r < 90) & (g < 80) & (b > 70) & (b - r > 25)
    rows = np.where(navy.sum(axis=1) >= 6)[0]
    if len(rows) == 0:
        return bottom
    return start + rows[0] - 6


def feather(im: Image.Image) -> Image.Image:
    """Bordes que se desvanecen a transparente para fundirse con el fondo de la app."""
    w, h = im.size
    fx, ft, fb = int(w * 0.06), int(h * 0.10), int(h * 0.04)
    xs = np.minimum(np.arange(w), np.arange(w)[::-1]).astype(float)
    ys = np.arange(h).astype(float)
    ax = np.clip(xs / max(fx, 1), 0, 1)
    ay = np.minimum(np.clip(ys / max(ft, 1), 0, 1), np.clip((h - 1 - ys) / max(fb, 1), 0, 1))
    alpha = (np.outer(ay, ax) ** 0.8 * 255).astype(np.uint8)
    rgba = im.convert('RGBA')
    rgba.putalpha(Image.fromarray(alpha))
    return rgba


def process(path: Path):
    a = np.asarray(Image.open(path).convert('RGB')).astype(int)
    h, w, _ = a.shape
    top, bottom = card_rows(a)
    cl, cr = card_cols(a)
    t = title_bottom(a, top, bottom)
    if path.stem in CUT_NEXT_TITLE:
        bottom = next_title_top(a, t, bottom)
    arrow = arrow_cols(a, t, bottom)
    ov = OVERRIDES.get(path.stem, {})
    t = int(ov.get('top', t / h) * h) if 'top' in ov else t
    bottom = int(ov['bottom'] * h) if 'bottom' in ov else bottom
    img = Image.open(path).convert('RGB')

    def finish(box):
        crop = img.crop(box)
        big = crop.resize((crop.width * SCALE, crop.height * SCALE), Image.LANCZOS)
        big = big.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
        ratio = OUT_H / big.height
        out = big.resize((max(1, int(big.width * ratio)), OUT_H), Image.LANCZOS)
        return feather(out)

    if arrow is None:
        return {'hold': finish((cl + 2, t, cr - 2, bottom - 1))}
    a0, a1 = arrow
    gap = 9
    lw, rw = a0 - gap - cl, (cr - 1) - (a1 + gap)
    half = max(lw, rw)
    left = (max(cl + 1, a0 - gap - half), t, a0 - gap, bottom - 1)
    right = (a1 + gap, t, min(cr - 1, a1 + gap + half), bottom - 1)
    return {'start': finish(left), 'end': finish(right)}


def main():
    OUT.mkdir(exist_ok=True)
    rows = []
    for p in sorted(SRC.glob('*.png')):
        frames = process(p)
        for k, im in frames.items():
            im.save(OUT / f'{p.stem}_{k}.png', optimize=True)
        rows.append((p.stem, frames))
        print(p.stem, {k: v.size for k, v in frames.items()})

    # Hoja de contactos para revisar
    th = 120
    sheet = Image.new('RGB', (900, th * len(rows) + 10), (239, 234, 247))
    d = ImageDraw.Draw(sheet)
    for i, (name, frames) in enumerate(rows):
        x = 230
        d.text((5, i * th + 50), name, fill='black')
        for k, im in frames.items():
            sm = im.resize((int(im.width * th / im.height * 0.95), int(th * 0.95)))
            sheet.paste(sm, (x, i * th + 3), sm if sm.mode == 'RGBA' else None)
            x += sm.width + 10
    sheet.save('tool/contact_sheet.png')


if __name__ == '__main__':
    main()
