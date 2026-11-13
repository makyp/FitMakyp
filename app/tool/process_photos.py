"""Convierte las fotos descargadas de Free Exercise DB (dominio público) en fotogramas de la app.

Uso (desde la carpeta app):
    python -I tool/process_photos.py <carpeta_descargas> [--sheet salida.png]

<carpeta_descargas>/<id>/0.jpg y 1.jpg  ->  assets/exercises/frames/<id>_start.jpg, <id>_end.jpg
Fuente: https://github.com/yuhonas/free-exercise-db (Unlicense / dominio público)
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

OUT = Path('assets/exercises/frames')
OUT_H = 480
# Ejercicios en los que el orden de las fotos del catálogo está invertido (final primero).
SWAP: set[str] = {'press_de_hombros', 'remo_al_menton'}


def load(p: Path) -> Image.Image:
    with Image.open(p) as im:
        im.verify()  # valida que es una imagen real
    im = Image.open(p)
    im = ImageOps.exif_transpose(im).convert('RGB')
    if im.width > 4000 or im.height > 4000:
        raise ValueError(f'imagen sospechosamente grande: {p}')
    return im


def main():
    src = Path(sys.argv[1])
    sheet_path = sys.argv[sys.argv.index('--sheet') + 1] if '--sheet' in sys.argv else None
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    for d in sorted(p for p in src.iterdir() if p.is_dir()):
        a, b = load(d / '0.jpg'), load(d / '1.jpg')
        if d.name in SWAP:
            a, b = b, a
        h = max(a.height, b.height)
        frames = []
        for im, tag in ((a, 'start'), (b, 'end')):
            r = OUT_H / im.height
            im = im.resize((round(im.width * r), OUT_H), Image.LANCZOS)
            im.save(OUT / f'{d.name}_{tag}.jpg', quality=84, optimize=True, progressive=True)
            frames.append(im)
        rows.append((d.name, frames))
        print(d.name, frames[0].size)

    if sheet_path:
        th, cols = 110, 3
        cw = 2 * 170 + 160
        sheet = Image.new('RGB', (cw * cols, th * ((len(rows) + cols - 1) // cols)), 'white')
        dr = ImageDraw.Draw(sheet)
        for i, (name, frames) in enumerate(rows):
            x0, y0 = (i % cols) * cw, (i // cols) * th
            dr.text((x0 + 2, y0 + 4), name[:24], fill='black')
            x = x0 + 4
            for f in frames:
                sm = f.resize((int(f.width * (th - 18) / f.height), th - 18))
                sheet.paste(sm, (x, y0 + 16))
                x += sm.width + 4
        sheet.save(sheet_path)


if __name__ == '__main__':
    main()
