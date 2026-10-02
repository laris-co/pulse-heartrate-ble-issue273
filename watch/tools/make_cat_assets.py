"""Make the watch's cat sprites from the Oracle Voice app icon (cat in a glowing orb).

Writes two files into watch/resources/drawables/:
  oracle_cat.png      1254 x 1254 RGBA, the orb cut out on transparency, same canvas size as
                      cartoon_heart.png so drawables.xml's existing scale percentages still give
                      the same on-watch size (about 92 px on fr245m)
  launcher_icon.png   40 x 40, the Connect IQ launcher size for fr245m

usage: python watch/tools/make_cat_assets.py <path to the Oracle Voice AppIcon.png>
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

src = Image.open(sys.argv[1]).convert("RGBA")
out = Path(__file__).resolve().parent.parent / "resources" / "drawables"

# The orb in the 1024 icon: centre and radius measured by eye on the icon, glow included.
cx, cy, r = 512, 488, 430
orb = src.crop((cx - r, cy - r, cx + r, cy + r))
mask = Image.new("L", orb.size, 0)
ImageDraw.Draw(mask).ellipse((4, 4, orb.size[0] - 4, orb.size[1] - 4), fill=255)
mask = mask.filter(ImageFilter.GaussianBlur(3))
orb.putalpha(mask)

canvas = Image.new("RGBA", (1254, 1254), (0, 0, 0, 0))
big = orb.resize((1254, 1254), Image.LANCZOS)
canvas.alpha_composite(big)
canvas.save(out / "oracle_cat.png")

icon = Image.new("RGBA", (40, 40), (0, 0, 0, 255))
icon.alpha_composite(orb.resize((40, 40), Image.LANCZOS))
icon.convert("RGB").save(out / "launcher_icon.png")
print("wrote", out / "oracle_cat.png", canvas.size)
print("wrote", out / "launcher_icon.png", icon.size)
