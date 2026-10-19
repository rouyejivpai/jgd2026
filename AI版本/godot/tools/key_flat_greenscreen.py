"""半透明绿幕反混合抠图 + 按连通块切件：python key_flat.py <in.png> <out_prefix> [min_area]
模型：C = a·F + (1−a)·G，G = 边缘取样的背景绿；假设前景的绿通道 ≈ min(红, 蓝)（本套 UI 只有灰 / 紫 / 暗红，没有绿）：
  a = 1 − (Cg − min(Cr, Cb)) / Gg，F = (C − (1−a)·G) / a。保住半透明叠层与柔边，去掉绿溢色。
输出 <prefix>_<k>.png（从上到下、从左到右），打印尺寸与位置。"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

src = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(np.float32)
min_area = int(sys.argv[3]) if len(sys.argv) > 3 else 2500
h, w, _ = src.shape
border = np.concatenate([src[:8].reshape(-1, 3), src[-8:].reshape(-1, 3), src[:, :8].reshape(-1, 3), src[:, -8:].reshape(-1, 3)])
G = np.median(border, axis=0)
r, g, b = src[..., 0], src[..., 1], src[..., 2]
a = 1.0 - (g - np.minimum(r, b)) / max(G[1] - min(G[0], G[2]), 1.0)
a = np.clip(a, 0.0, 1.0)
a[a < 0.035] = 0.0
a[a > 0.97] = 1.0
safe = np.maximum(a, 1e-3)[..., None]
F = (src - (1.0 - a)[..., None] * G[None, None, :]) / safe
F[..., 1] = np.minimum(F[..., 1], np.minimum(F[..., 0], F[..., 2]) + 6.0)      # 去绿溢色
F = np.clip(F, 0, 255)
out = np.dstack([F, a * 255.0]).astype(np.uint8)
mask = ndimage.binary_dilation(a > 0.06, iterations=10)
lab, n = ndimage.label(mask)
parts = []
for sl in ndimage.find_objects(lab):
    hh = sl[0].stop - sl[0].start
    ww = sl[1].stop - sl[1].start
    if hh * ww >= min_area:
        parts.append((sl[0].start // 40, sl[1].start, sl))
parts.sort()
for k, (_, _, sl) in enumerate(parts):
    crop = Image.fromarray(out[sl]).copy()
    bb = crop.getchannel("A").point(lambda v: 255 if v > 6 else 0).getbbox()
    crop = crop.crop(bb)
    crop.save(f"{sys.argv[2]}_{k}.png")
    print(k, crop.size, (sl[1].start, sl[0].start))
print("bg", G.round(1))
