# key.py without scipy: same keying, largest blob kept via a BFS on a dilated mask
import sys
from collections import deque
from PIL import Image, ImageFilter
import numpy as np
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
    if name == "-":
        continue
    cx, cy = k % n, k // n
    q = rgba[cy * H // n:(cy + 1) * H // n, cx * W // n:(cx + 1) * W // n].copy()
    a = q[..., 3] > 128
    dil = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(13))) > 0
    lab = np.zeros(a.shape, np.int32); cur = 0; sizes = {}
    for y0, x0 in zip(*np.where(dil)):
        if lab[y0, x0]:
            continue
        cur += 1; cnt = 0; dq = deque([(y0, x0)]); lab[y0, x0] = cur
        while dq:
            y, x = dq.popleft(); cnt += a[y, x]
            for yy, xx in ((y+1,x),(y-1,x),(y,x+1),(y,x-1)):
                if 0 <= yy < a.shape[0] and 0 <= xx < a.shape[1] and dil[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = cur; dq.append((yy, xx))
        sizes[cur] = cnt
    best = max(sizes, key=sizes.get)
    q[..., 3] = np.where(lab == best, q[..., 3], 0)
    ys, xs = np.where(q[..., 3] > 128)
    t = q[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    Image.fromarray(t).save(f"{outdir}/{name}.png")
    print(name, t.shape[1], t.shape[0])
