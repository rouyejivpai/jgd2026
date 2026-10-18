"""区域局内地图底图后处理（2026-10-18）：降高频噪点 → 统一到 2048×1152 → 写入 assets/backdrops/regions/<区域>.png。

做法（不是整图模糊）：
1. 双边滤波得到保边的「底层」，原图 - 底层 = 细节层；
2. 细节层按位置衰减：整体保留 DETAIL_KEEP，中央玩法区域（游戏会叠格线的地方，椭圆软遮罩）只保留 DETAIL_KEEP_CENTER；
3. 再对细节层做一次小半径高斯，去掉单像素级的噪点闪点；
4. Lanczos 缩放到目标尺寸。

用法：python tools/region_map_post.py <原图> <区域id>   （可多对）
      python tools/region_map_post.py --all            （读 tools/_raw/region_maps/gen/<区域id>.png）
"""
import sys
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
RAW_DIR = ROOT / "tools" / "_raw" / "region_maps" / "gen"
OUT_DIR = ROOT / "assets" / "backdrops" / "regions"
REGIONS = ["bone_workshop", "withered_farm", "grey_thorn", "holy_bell", "flesh_swamp", "warped_corridor", "bone_greenhouse"]
SIZE = (2048, 1152)
DETAIL_KEEP = 0.4
DETAIL_KEEP_CENTER = 0.12
# 玩法区域在底图上的位置（cover 缩放、无横移时；见 map_background.gd / playfield.gd）：x 23%–77%，y 30%–67%
CENTER = (0.5, 0.485)
RADII = (0.36, 0.26)


def _read(path: Path) -> np.ndarray | None:
    """cv2.imread 不支持 Windows 非 ASCII 路径，改用 imdecode"""
    data = np.fromfile(str(path), dtype=np.uint8) if path.exists() else np.empty(0, np.uint8)
    return cv2.imdecode(data, cv2.IMREAD_COLOR) if data.size else None


def process(src: Path, region: str) -> Path:
    img = _read(src)
    if img is None:
        raise SystemExit(f"读不到图片：{src}")
    img = cv2.resize(img, SIZE, interpolation=cv2.INTER_LANCZOS4 if img.shape[1] < SIZE[0] else cv2.INTER_AREA)
    f = img.astype(np.float32)
    base = f
    for _ in range(3):
        base = cv2.bilateralFilter(base, d=9, sigmaColor=40, sigmaSpace=9)
    detail = cv2.GaussianBlur(f - base, (0, 0), 1.2)
    h, w = img.shape[:2]
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    d = np.sqrt(((xx / w - CENTER[0]) / RADII[0]) ** 2 + ((yy / h - CENTER[1]) / RADII[1]) ** 2)
    m = np.clip((d - 0.75) / 0.6, 0.0, 1.0)            # 0 = 玩法中心，1 = 外圈
    m = m * m * (3 - 2 * m)
    keep = (DETAIL_KEEP_CENTER + (DETAIL_KEEP - DETAIL_KEEP_CENTER) * m)[..., None]
    out = np.clip(base + detail * keep, 0, 255).astype(np.uint8)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dst = OUT_DIR / f"{region}.png"
    cv2.imencode(".png", out)[1].tofile(str(dst))
    return dst


def hf_energy(path: Path) -> float:
    """高频能量（灰度 Laplacian 绝对值均值），用于前后对比"""
    g = cv2.cvtColor(_read(path), cv2.COLOR_BGR2GRAY)
    g = cv2.resize(g, SIZE, interpolation=cv2.INTER_AREA)
    return float(np.abs(cv2.Laplacian(g.astype(np.float32), cv2.CV_32F)).mean())


def main(argv: list[str]) -> None:
    sys.stdout.reconfigure(encoding="utf-8")
    pairs = [(RAW_DIR / f"{r}.png", r) for r in REGIONS if (RAW_DIR / f"{r}.png").exists()] if argv == ["--all"] \
        else [(Path(argv[i]), argv[i + 1]) for i in range(0, len(argv), 2)]
    for src, region in pairs:
        dst = process(src, region)
        print(f"{region}: {src.name} -> {dst.relative_to(ROOT)}  高频能量 {hf_energy(src):.2f} -> {hf_energy(dst):.2f}")


if __name__ == "__main__":
    main(sys.argv[1:])
