"""Render the NCG IT Consulting Chat icon set (PNG + ICO) with Pillow.

Usage: python3 render-branding.py <output-dir>

The design matches deploy/branding/favicon.svg: a navy-to-teal rounded square,
a white chat bubble and three connected nodes with an amber "spark" in the middle.
Requires Pillow (available inside the Open WebUI container).
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

NAVY = (11, 37, 69)
TEAL = (14, 138, 138)
WHITE = (255, 255, 255)
AMBER = (245, 166, 35)
SS = 4  # supersampling factor for smooth edges


def gradient(size):
    """Diagonal navy (top left) -> teal (bottom right) gradient: average of a vertical and a horizontal ramp."""
    vertical = Image.linear_gradient("L").resize((size, size))
    horizontal = vertical.transpose(Image.Transpose.TRANSPOSE)
    ramp = ImageChops.add(vertical, horizontal, scale=2)
    return Image.composite(Image.new("RGB", (size, size), TEAL),
                           Image.new("RGB", (size, size), NAVY), ramp)


def draw_glyph(img, scale=1.0):
    """Chat bubble with connected nodes, centered; scale < 1 shrinks it for maskable icons."""
    s = img.width
    d = ImageDraw.Draw(img)

    def p(x, y):
        return (s * (0.5 + (x - 0.5) * scale), s * (0.5 + (y - 0.5) * scale))

    def r(v):
        return s * v * scale

    # Bubble body and tail
    d.rounded_rectangle([p(0.19, 0.22), p(0.81, 0.68)], radius=r(0.12), fill=WHITE)
    d.polygon([p(0.29, 0.64), p(0.25, 0.82), p(0.47, 0.64)], fill=WHITE)

    # Network: three nodes connected by lines, amber node in the middle
    nodes = [p(0.34, 0.50), p(0.50, 0.38), p(0.66, 0.50)]
    d.line([nodes[0], nodes[1], nodes[2]], fill=NAVY, width=int(r(0.032)), joint="curve")
    for (x, y), radius, color in ((nodes[0], 0.050, NAVY), (nodes[2], 0.050, NAVY), (nodes[1], 0.064, AMBER)):
        d.ellipse([x - r(radius), y - r(radius), x + r(radius), y + r(radius)], fill=color)


def icon(size, full_bleed=False, scale=1.0):
    big = size * SS
    img = gradient(big).convert("RGBA")
    draw_glyph(img, scale)
    if not full_bleed:
        mask = Image.new("L", (big, big), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, big - 1, big - 1], radius=int(big * 0.22), fill=255)
        img.putalpha(mask)
    return img.resize((size, size), Image.LANCZOS)


def main(out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    rounded = {n: icon(n) for n in (16, 32, 48, 96, 500, 512)}
    rounded[512].save(out / "favicon.png")
    rounded[96].save(out / "favicon-96x96.png")
    for name in ("logo.png", "splash.png", "splash-dark.png"):
        rounded[500].save(out / name)
    # iOS rounds the corners itself, so the touch icon is full-bleed
    icon(180, full_bleed=True).save(out / "apple-touch-icon.png")
    # Maskable icons: full-bleed background, glyph inside the 80 % safe zone
    icon(192, full_bleed=True, scale=0.8).save(out / "web-app-manifest-192x192.png")
    icon(512, full_bleed=True, scale=0.8).save(out / "web-app-manifest-512x512.png")
    rounded[48].save(out / "favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)])
    print("rendered:", ", ".join(sorted(f.name for f in out.iterdir())))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "branding")
