"""特殊地块标志切图（2026-10-18）：把 gpt-image 生成的 3×2 黑白标志图集切成 6 张 256×256 白色剪影 + alpha，
写入 assets/sprites/tile_marks/<名>.png；游戏里按地块类型着色、半透明叠到格上（grid_overlay.gd）。

用法：python tools/slice_tile_marks.py [图集路径]   默认 tools/_raw/region_maps/gen/tile_emblems.png
      python tools/slice_tile_marks.py --single spawn tools/_raw/region_maps/gen/tile_spawn.png   （单个标志，如出生点）
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tools" / "_raw" / "region_maps" / "gen" / "tile_emblems.png"
OUT_DIR = ROOT / "assets" / "sprites" / "tile_marks"
NAMES = [["hazard", "mire", "shrine"], ["blocked", "goal", "escape"]]
SIZE = 256
PAD = 0.06          # 标志四周留白（占边长）


def save_mark(cell: np.ndarray, name: str) -> None:
    """cell：墨量图（黑 = 1）。取标志外接框、补成正方形留白，转白色剪影 + alpha"""
    ys, xs = np.nonzero(cell > 0.5)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    side = int(max(y1 - y0, x1 - x0) * (1 + 2 * PAD))
    cy, cx = (y0 + y1) // 2, (x0 + x1) // 2
    sq = np.zeros((side, side), np.float32)
    ty, tx = cy - side // 2, cx - side // 2
    sy0, sx0 = max(ty, 0), max(tx, 0)
    sy1, sx1 = min(ty + side, cell.shape[0]), min(tx + side, cell.shape[1])
    sq[sy0 - ty:sy1 - ty, sx0 - tx:sx1 - tx] = cell[sy0:sy1, sx0:sx1]
    alpha = np.clip((sq - 0.08) / 0.84, 0.0, 1.0)  # 去掉白底的轻微灰噪，保留抗锯齿边
    a = Image.fromarray((alpha * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.LANCZOS)
    img = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    img.putalpha(a)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dst = OUT_DIR / f"{name}.png"
    img.save(dst)
    print(f"{name}: bbox {x1 - x0}×{y1 - y0} -> {dst.relative_to(ROOT)}")


def ink_of(path: Path) -> np.ndarray:
    return 1.0 - np.asarray(Image.open(path).convert("L"), dtype=np.float32) / 255.0


def main(argv: list[str]) -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    if argv[:1] == ["--single"]:                     # 单个标志：--single <名> <图>
        save_mark(ink_of(Path(argv[2])), argv[1])
        return
    ink = ink_of(Path(argv[0]) if argv else SRC)
    h, w = ink.shape
    for r, row in enumerate(NAMES):
        for c, name in enumerate(row):
            save_mark(ink[r * h // 2:(r + 1) * h // 2, c * w // 3:(c + 1) * w // 3], name)


if __name__ == "__main__":
    main(sys.argv[1:])
