#!/usr/bin/env python3
"""Draws the app icon (icon.png 1024 px, icon.ico for Windows, icon.icns for macOS) from the
Static Horizon logo - the artificial-horizon mark of the website
(website/images/favicon-dark.svg) on a dark rounded square in the menu's
palette. Run from the project root: python3 tools/make_icon.py"""
from PIL import Image, ImageDraw

N = 1024
SS = 4                       # supersampling for smooth edges
S = N * SS
BG_TOP, BG_BOTTOM = (0x24, 0x28, 0x2e), (0x10, 0x12, 0x16)
SKY, GROUND, LINE = (0x1f, 0x6f, 0xe0), (0xe8, 0x55, 0x1a), (0xff, 0xff, 0xff)

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
# Rounded square on the macOS icon grid (824 of 1024, radius ~22%).
side = 824 * SS
o = (S - side) // 2
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
for y in range(S):
	t = min(max((y - o) / side, 0.0), 1.0)
	gd.line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)) + (255,))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([o, o, o + side, o + side], radius=int(side * 0.225), fill=255)
img.paste(grad, (0, 0), mask)

# The logo: the favicon's 40-unit viewBox scaled so the dial fills ~74%.
u = side * 0.74 / 31.0       # one viewBox unit (dial diameter is 31)
cx = cy = S / 2
def P(x, y):
	return (cx + (x - 20) * u, cy + (y - 20) * u)
r = 15.5 * u
dial = Image.new("RGBA", (S, S), (0, 0, 0, 0))
dd = ImageDraw.Draw(dial)
dd.rectangle([0, 0, S, cy], fill=SKY + (255,))
dd.rectangle([0, cy, S, S], fill=GROUND + (255,))
dmask = Image.new("L", (S, S), 0)
ImageDraw.Draw(dmask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
img.paste(dial, (0, 0), dmask)
d = ImageDraw.Draw(img)
def line(x1, x2, w, round_caps):
	a, b = P(x1, 20), P(x2, 20)
	d.line([a, b], fill=LINE, width=int(w * u))
	if round_caps:
		for p in (a, b):
			d.ellipse([p[0] - w * u / 2, p[1] - w * u / 2, p[0] + w * u / 2, p[1] + w * u / 2], fill=LINE)
line(4.5, 35.5, 1.6, False)
d.ellipse([cx - r - u, cy - r - u, cx + r + u, cy + r + u], outline=LINE, width=int(2 * u))
d.ellipse([cx - 2 * u, cy - 2 * u, cx + 2 * u, cy + 2 * u], fill=LINE)
line(9, 16, 2.6, True)
line(24, 31, 2.6, True)

out = img.resize((N, N), Image.LANCZOS)
out.save("icon.png")
out.save("icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("icon.png, icon.ico written")
# macOS: icon.icns via iconutil (macOS only).
import os, shutil, subprocess, tempfile
if shutil.which("iconutil"):
	d = tempfile.mkdtemp() + "/icon.iconset"
	os.makedirs(d)
	for s in (16, 32, 128, 256, 512):
		out.resize((s, s), Image.LANCZOS).save(f"{d}/icon_{s}x{s}.png")
		out.resize((s * 2, s * 2), Image.LANCZOS).save(f"{d}/icon_{s}x{s}@2x.png")
	subprocess.run(["iconutil", "-c", "icns", d, "-o", "icon.icns"], check=True)
	print("icon.icns written")
