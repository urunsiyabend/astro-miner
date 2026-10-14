## Key a generated tile sheet (2x2 tiles on pure #00FF00) into four cropped RGBA sprites.
##   python3 key.py sheet.png outdir
import sys
from PIL import Image
import numpy as np
src, outdir = sys.argv[1], sys.argv[2]
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
r, g, b = im[..., 0], im[..., 1], im[..., 2]
# green-ness: how far green exceeds the other channels
gx = g - np.maximum(r, b)
alpha = np.clip(1.0 - (gx - 40) / 80.0, 0, 1)
# despill: pull green down to max(r,b) on edge pixels
g2 = np.where(gx > 0, np.maximum(r, b), g)
rgba = np.dstack([r, g2, b, alpha * 255]).astype(np.uint8)
H, W = alpha.shape
names = ["soil_a", "soil_b", "pit", "rock"]
for k, (x0, y0) in enumerate([(0, 0), (W // 2, 0), (0, H // 2), (W // 2, H // 2)]):
    q = rgba[y0:y0 + H // 2, x0:x0 + W // 2]
    a = q[..., 3] > 128
    ys, xs = np.where(a)
    t = q[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    Image.fromarray(t).save(f"{outdir}/{names[k]}.png")
    # column at centre: report where the opaque area starts/ends, for measuring
    print(names[k], "bbox w,h", t.shape[1], t.shape[0])
