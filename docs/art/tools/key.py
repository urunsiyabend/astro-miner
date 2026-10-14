## Key a generated sheet (3x3 pieces on pure #00FF00) into cropped RGBA sprites.
##   python3 key.py sheet.png outdir name1,name2,...,name9   (needs Pillow, numpy, scipy)
import sys
from PIL import Image
import numpy as np
from scipy import ndimage
src, outdir = sys.argv[1], sys.argv[2]
names = sys.argv[3].split(",")
im = np.asarray(Image.open(src).convert("RGB")).astype(np.float32)
r, g, b = im[..., 0], im[..., 1], im[..., 2]
gx = g - np.maximum(r, b)
alpha = np.clip(1.0 - (gx - 40) / 80.0, 0, 1)
g2 = np.where(gx > 0, np.maximum(r, b), g)
rgba = np.dstack([r, g2, b, alpha * 255]).astype(np.uint8)
H, W = alpha.shape
n = 3
for k, name in enumerate(names):
    cx, cy = k % n, k // n
    q = rgba[cy * H // n:(cy + 1) * H // n, cx * W // n:(cx + 1) * W // n]
    a = q[..., 3] > 128
    # keep the largest blob plus anything close to it (dangling stones), drop stray specks
    lab, cnt = ndimage.label(ndimage.binary_dilation(a, iterations=6))
    sizes = ndimage.sum(a, lab, range(1, cnt + 1))
    keep = lab == (1 + int(np.argmax(sizes)))
    q = q.copy(); q[..., 3] = np.where(keep, q[..., 3], 0)
    ys, xs = np.where(q[..., 3] > 128)
    t = q[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    Image.fromarray(t).save(f"{outdir}/{name}.png")
    print(name, t.shape[1], t.shape[0])
