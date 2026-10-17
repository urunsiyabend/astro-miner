"""Round UI pieces drawn at 4x and downsampled, so their edges are smooth at any size (the
engine's draw_circle anti-aliases only ~1 px and small discs stair-step). Run again after
changing a colour:

    python3 tools/art/badges.py

Writes assets/ui/badge_level.png, badge_red.png, badge_grey.png (glossy jelly discs that a
number is drawn on) and bubble_round.png (the colony's booster bubble: a round speech bubble
with its tail down). Import with mipmaps on.
"""
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UI = os.path.join(ROOT, "assets", "ui")
SS = 4  # supersampling


def lerp(a, b, t):
	return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def disc(size, rim_top, rim_bot, face_top, face_bot, outline):
	"""A jelly disc: soft drop shadow, dark outline, a rim lit from the top, a darker inset face
	with a vertical gradient, and a gloss crescent near the top."""
	S = size * SS
	img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	c = S / 2
	r = S * 0.43
	# drop shadow
	sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	ImageDraw.Draw(sh).ellipse((c - r, c - r + S * 0.05, c + r, c + r + S * 0.05), fill=(10, 0, 30, 120))
	sh = sh.filter(ImageFilter.GaussianBlur(S * 0.02))
	img.alpha_composite(sh)
	d = ImageDraw.Draw(img)
	d.ellipse((c - r, c - r, c + r, c + r), fill=outline)
	# rim: vertical gradient, drawn as stacked rows clipped to a circle
	rr = r * 0.9
	rim = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	rd = ImageDraw.Draw(rim)
	for y in range(int(c - rr), int(c + rr) + 1):
		t = (y - (c - rr)) / (2 * rr)
		rd.line((0, y, S, y), fill=lerp(rim_top, rim_bot, t) + (255,))
	mask = Image.new("L", (S, S), 0)
	ImageDraw.Draw(mask).ellipse((c - rr, c - rr, c + rr, c + rr), fill=255)
	img.paste(rim, (0, 0), mask)
	# face
	fr = r * 0.7
	face = Image.new("RGBA", (S, S), (0, 0, 0, 0))
	fd = ImageDraw.Draw(face)
	for y in range(int(c - fr), int(c + fr) + 1):
		t = (y - (c - fr)) / (2 * fr)
		fd.line((0, y, S, y), fill=lerp(face_top, face_bot, t) + (255,))
	fmask = Image.new("L", (S, S), 0)
	ImageDraw.Draw(fmask).ellipse((c - fr, c - fr, c + fr, c + fr), fill=255)
	# inner shadow along the face's top edge
	inner = Image.new("L", (S, S), 0)
	ImageDraw.Draw(inner).ellipse((c - fr, c - fr + S * 0.03, c + fr, c + fr + S * 0.03), fill=255)
	img.paste(face, (0, 0), fmask)
	shade = Image.new("RGBA", (S, S), (0, 0, 0, 70))
	sm = Image.new("L", (S, S), 0)
	sm.paste(fmask, (0, 0))
	sm = Image.composite(Image.new("L", (S, S), 0), sm, inner)
	sm = sm.filter(ImageFilter.GaussianBlur(S * 0.008))
	img.paste(shade, (0, 0), sm)
	# gloss crescent on the rim's top
	gl = Image.new("L", (S, S), 0)
	gd = ImageDraw.Draw(gl)
	gd.ellipse((c - rr * 0.72, c - rr * 0.95, c + rr * 0.72, c - rr * 0.35), fill=150)
	gd.ellipse((c - rr * 0.8, c - rr * 0.78, c + rr * 0.8, c - rr * 0.2), fill=0)
	gl = gl.filter(ImageFilter.GaussianBlur(S * 0.006))
	img.paste(Image.new("RGBA", (S, S), (255, 255, 255, 255)), (0, 0), gl)
	return img.resize((size, size), Image.LANCZOS)


def bubble(w, h):
	"""The booster bubble: a round cream bubble with a dark outline and a short tail down."""
	W, H = w * SS, h * SS
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	c = (W / 2, W / 2)
	r = W * 0.44
	ol = W * 0.035
	tail = [(c[0] - r * 0.3, c[1] + r * 0.8), (c[0] + r * 0.3, c[1] + r * 0.8), (c[0], H - W * 0.04)]
	sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	sd = ImageDraw.Draw(sh)
	sd.ellipse((c[0] - r, c[1] - r + W * 0.05, c[0] + r, c[1] + r + W * 0.05), fill=(10, 0, 30, 110))
	sh = sh.filter(ImageFilter.GaussianBlur(W * 0.02))
	img.alpha_composite(sh)
	d = ImageDraw.Draw(img)
	dark = (40, 14, 76, 255)
	d.ellipse((c[0] - r, c[1] - r, c[0] + r, c[1] + r), fill=dark)
	d.polygon([(x, y + (ol if i < 2 else 0)) for i, (x, y) in enumerate(tail)], fill=dark)
	ri = r - ol
	cream_top, cream_bot = (255, 252, 240), (238, 226, 205)
	fill = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	fd = ImageDraw.Draw(fill)
	for y in range(H):
		t = min(1.0, max(0.0, (y - (c[1] - ri)) / (2 * ri)))
		fd.line((0, y, W, y), fill=lerp(cream_top, cream_bot, t) + (255,))
	m = Image.new("L", (W, H), 0)
	md = ImageDraw.Draw(m)
	md.ellipse((c[0] - ri, c[1] - ri, c[0] + ri, c[1] + ri), fill=255)
	inner_tail = [(c[0] - r * 0.3 + ol * 1.2, c[1] + r * 0.7), (c[0] + r * 0.3 - ol * 1.2, c[1] + r * 0.7),
			(c[0], H - W * 0.04 - ol * 2.0)]
	md.polygon(inner_tail, fill=255)
	img.paste(fill, (0, 0), m)
	gl = Image.new("L", (W, H), 0)
	gd = ImageDraw.Draw(gl)
	gd.ellipse((c[0] - ri * 0.62, c[1] - ri * 0.86, c[0] - ri * 0.18, c[1] - ri * 0.5), fill=230)
	gl = gl.filter(ImageFilter.GaussianBlur(W * 0.01))
	img.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), gl)
	return img.resize((w, h), Image.LANCZOS)


def main():
	disc(256, (240, 234, 255), (178, 160, 230), (78, 52, 140), (44, 24, 92), (24, 8, 52, 255)).save(
		os.path.join(UI, "badge_level.png"))
	disc(256, (255, 150, 140), (214, 52, 46), (232, 66, 58), (176, 30, 30), (90, 12, 14, 255)).save(
		os.path.join(UI, "badge_red.png"))
	disc(256, (200, 196, 214), (140, 134, 160), (128, 122, 150), (96, 90, 118), (40, 34, 56, 255)).save(
		os.path.join(UI, "badge_grey.png"))
	bubble(256, 300).save(os.path.join(UI, "bubble_round.png"))
	print("wrote badge_level, badge_red, badge_grey, bubble_round")


main()
