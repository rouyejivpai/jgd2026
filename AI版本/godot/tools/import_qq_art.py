#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""2026-10-19：用美术交付的 Q 版人物（QQ人 / QQ人2）、人偶立绘、物件替换游戏图。敌我双方单位精灵都用 Q 版人物。
源目录：AI版本/work/美术资源_20261019/（QQ人、QQ人2、人偶立绘、守火立绘、物件、精英战）。源图已是透明底。
对应关系（按设定图标注与单位描述）：
  己方六形态 ← QQ人2 三版 Q 版人偶（完好发饰 / 破损发饰 / 魔女帽）；美术尚未给每个形态单独出图，暂时三版轮用
  hound 骸猎犬 ← 坐姿红犬；brute 正面袭击者 ← 直立红色狼人（与精英关「猎犬头目」同一设定，届时可复用）
  raider 袭击者 ← 多爪畸形体（设定「愤怒」）；bone_weaver 织骨者 ← 骨足蜘蛛花
  husk 残骸行者 ← 蜷伏的苍白幽灵少女；priest 低语祭司 ← 手捧光球的高帽幽灵
  hex_priest 咒缚祭司 ← 带面具的兜帽少年（设定「恐惧」）；spitter 骨喉 ← 倾倒罐中骨浆的白袍女
  warden 哭墙守卫 ← 拄杖蒙面的白发老妪；bone_guard 骨花护卫 ← 持矛白甲骑士
  bone_core 骨花核心 / bone_witch 骨花魔女 ← 彼岸花魔女
  剧情立绘 doll ← 人偶立绘完好发饰版（另存破损版 doll_worn、魔女帽版 doll_witch_hat）；keeper 守火 ← 守火立绘
  地形效果格物件（tile_objects/）：hazard 危险区 ← 裂甲菌簇；mire 缓滞带 ← 僵骨地刺；shrine 净化台 ← 静息祭坛（蓝）
  暂无对应位置、只入库备用（props/）：守火魂灯 ×3（精英关火种）、畸变母核 ×3
处理：去零星碎块 → 裁到不透明外框 → 朝左（含脸偏向画面左侧的 3/4 侧身）的角色水平翻转为默认朝右（游戏里向左走时再由程序翻转） → 等比放入 256 画布（脚底在底部 24 px 处）；
头像 = 头部方形裁切 + 深紫径向底（512）；出场卡切片的头像圆窗换成新头像。
原图备份到 tools/_work/char_backup_20261019/（不入库），可用 --restore 还原。
用法（godot/ 目录）：python tools/import_qq_art.py [--preview 输出图] [--restore]
"""
import io
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
GODOT = Path(__file__).resolve().parent.parent
SRC = GODOT.parent / "work" / "美术资源_20261019"
BACKUP = GODOT / "tools/_work/char_backup_20261019"
SPR = GODOT / "assets/sprites"
CARDS = GODOT / "assets/ui/unified_low_noise/slices"

UNIT_CANVAS = 256
UNIT_BOX = (12, 12, 244, 232)          # 04 §2.1：脚底在画布底部 24 px 处，左右上各留 12 px
ILLU_CANVAS = (768, 1152)
ILLU_BOX = (24, 0, 744, 1152)
OBJ_CANVAS = 256
OBJ_BOX = (8, 8, 248, 248)

DOLL_INTACT = "QQ人2/mmexport1792131299485.jpg"
DOLL_WORN = "QQ人2/mmexport1792131297265.jpg"
DOLL_HAT = "QQ人2/mmexport1792131261817.jpg"

# 名称 → (源文件, 是否水平翻转, 头像框（裁好的人物图上的比例 [x0, y0, x1, y1]）)
FIGURES = {
    "doll_intact": (DOLL_INTACT, True, [0.1, 0.1, 0.9, 0.6]),
    "doll_worn": (DOLL_WORN, True, [0.1, 0.1, 0.9, 0.6]),
    "doll_hat": (DOLL_HAT, True, [0.18, 0.12, 0.92, 0.62]),
    "hound": ("QQ人/Image_1792131747943_380.png", True, [0.35, 0.0, 1.0, 0.6]),
    "werewolf": ("QQ人/Image_1792131745967_110.png", True, [0.4, 0.0, 1.0, 0.55]),
    "anger": ("QQ人/Image_1792131756928_471.png", False, [0.1, 0.0, 0.9, 0.6]),
    "spider": ("QQ人/Image_1792131751278_56.png", False, [0.15, 0.1, 0.85, 0.65]),
    "ghost_girl": ("QQ人/Image_1792131749783_442.png", True, [0.35, 0.2, 0.95, 0.75]),
    "top_hat": ("QQ人/Image_1792131754079_982.png", True, [0.12, 0.14, 0.88, 0.52]),
    "old_witch": ("QQ人/Image_1792131755437_378.png", True, [0.15, 0.0, 0.95, 0.55]),
    "masked": ("QQ人2/mmexport1792131391485.jpg", True, [0.15, 0.0, 0.85, 0.55]),
    "jar_robe": ("QQ人2/mmexport1792131445067.jpg", False, [0.2, 0.0, 0.8, 0.5]),
    "knight": ("QQ人2/mmexport1792131393427.jpg", True, [0.15, 0.0, 0.85, 0.55]),
    "lily": ("QQ人2/mmexport1792131389731.jpg", False, [0.15, 0.0, 0.85, 0.6]),
    "bell_girl": ("QQ人2/mmexport1792131306396.jpg", True, [0.25, 0.08, 0.95, 0.65]),
}

# 单位 id → 人物。己方：完好 / 破损 / 魔女帽三版轮用
UNITS = {
    "striker": "doll_intact", "bulwark": "doll_worn", "swift": "doll_worn",
    "lancer": "doll_hat", "hexer": "doll_hat", "binder": "doll_intact",
    "hound": "hound", "brute": "werewolf", "raider": "anger", "bone_weaver": "spider",
    "husk": "ghost_girl", "priest": "top_hat", "hex_priest": "masked", "spitter": "jar_robe",
    "warden": "old_witch", "bone_guard": "knight", "bone_core": "lily",
    # 精英关备用（units.json 尚无这些单位）
    "hound_alpha": "werewolf", "bell_witch": "bell_girl",
}

# 出场卡切片（头像画在切片上）→ 形态
CARD_FORMS = {"card_striker": "striker", "card_bulwark": "bulwark", "card_swift": "swift", "card_spitter": "lancer"}

ILLUSTRATIONS = {
    "doll": "人偶立绘/5F830DB872041F42C69235C6EB7C7D04.png",
    "doll_worn": "人偶立绘/22803EF1F7639AE06131F81CA385208B.png",
    "doll_witch_hat": "人偶立绘/E6528727384DE799D04355DF1742E708.png",
    "keeper": "守火立绘/IMG_5254.png",              # 剧情说话人 keeper「守火」
}

# 物件 → 输出（相对 assets/sprites/）
OBJECTS = {
    "tile_objects/hazard.png": "物件/裂甲菌簇/a0d3c91d754b6af0a0c66aed1f161fdf.png",
    "tile_objects/mire.png": "物件/僵骨地刺/a66fa5fe53892163339dfce40a9eda2d.png",
    "tile_objects/shrine.png": "物件/静息祭坛/f37375f18d8883a778c869ff257a5e5b.png",
    "props/rest_altar_green.png": "物件/静息祭坛/6bbc58a172b6dfc9feb2a89b01fa1c91.png",
    "props/soul_lamp_lit.png": "物件/守火魂灯/0393f585c74bedfe9110f1b8ccd1fe2b.png",
    "props/soul_lamp_out.png": "物件/守火魂灯/772e348dcaaf269e5777ac7679216928.png",
    "props/soul_lamp_lit_b.png": "物件/守火魂灯/83838eb07982e62be6bb3e04be273ea7.png",
    "props/warped_core_a.png": "物件/畸变母核/615c9ecb9f885b5b65dbb0b574fa7e09.png",
    "props/warped_core_b.png": "物件/畸变母核/64d5f4c4cf9ac524ded0cfa8efc973ff.png",
    "props/warped_core_block.png": "物件/畸变母核/b5f6c27efa5ff6a4d00d25c8da9d79b5.png",
}


def clean(im: Image.Image, keep_ratio: float = 0.02) -> Image.Image:
    """去掉面积小于最大块 keep_ratio 的零星碎块，裁到不透明外框"""
    import cv2
    arr = np.array(im.convert("RGBA"))
    n, lab, st, _ = cv2.connectedComponentsWithStats((arr[..., 3] > 24).astype(np.uint8), 8)
    if n > 1:
        areas = st[1:, cv2.CC_STAT_AREA]
        keep = [i + 1 for i, a in enumerate(areas) if a >= areas.max() * keep_ratio]
        arr[..., 3] = np.where(np.isin(lab, keep), arr[..., 3], 0)
    out = Image.fromarray(arr)
    return out.crop(out.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox())


def figure(name: str) -> Image.Image:
    fname, flip, _ = FIGURES[name]
    im = clean(Image.open(SRC / fname))
    return im.transpose(Image.FLIP_LEFT_RIGHT) if flip else im


def fit_into(fig: Image.Image, canvas: tuple, box: tuple, bottom: bool = True) -> Image.Image:
    """等比缩放放入 box（x0, y0, x1, y1）；bottom = 底边对齐（否则竖直居中），水平居中"""
    x0, y0, x1, y1 = box
    k = min((x1 - x0) / fig.width, (y1 - y0) / fig.height)
    f = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    y = y1 - f.height if bottom else round((y0 + y1) / 2 - f.height / 2)
    out.alpha_composite(f, (round((x0 + x1) / 2 - f.width / 2), y))
    return out


def portrait(fig: Image.Image, head: list, size: int = 512) -> Image.Image:
    w, h = fig.size
    x0, y0, x1, y1 = head[0] * w, head[1] * h, head[2] * w, head[3] * h
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, y0 + side / 2
    crop = fig.crop((round(cx - side / 2), round(cy - side / 2), round(cx + side / 2), round(cy + side / 2))).resize((size, size), Image.LANCZOS)
    yy, xx = np.mgrid[0:size, 0:size]
    d = (np.sqrt((xx - size / 2) ** 2 + (yy - size * 0.42) ** 2) / (size * 0.75)).clip(0, 1)[..., None]
    inner, outer = np.array([62, 36, 82]), np.array([16, 9, 22])
    col = inner[None, None, :] * (1 - d) + outer[None, None, :] * d
    bg = Image.fromarray(np.dstack([col, np.full((size, size, 1), 255)]).astype(np.uint8), "RGBA")
    bg.alpha_composite(crop)
    return bg


def card_with_portrait(card_path: Path, portrait_img: Image.Image) -> Image.Image:
    """在卡片切片的头像圆窗内换上新头像：沿水平 / 竖直中线找金环内沿定圆心与半径，圆内贴新头像（金环与卡面不动）"""
    card = Image.open(card_path).convert("RGBA")
    a = np.array(card).astype(int)
    goldm = (a[..., 0] > 170) & (a[..., 1] > 120) & (a[..., 2] < 110)
    h, w = goldm.shape
    cx0 = w // 2
    col = np.nonzero(goldm[:, cx0])[0]
    top = col[(col > 20) & (col < h // 3)].min()
    bottom = col[(col > h // 4) & (col < h * 0.62)].max()
    cy = (top + bottom) / 2
    row = np.nonzero(goldm[int(cy), :])[0]
    left, right = row[(row < cx0) & (row > 20)].max(), row[(row > cx0) & (row < w - 20)].min()
    cx = (left + right) / 2
    r = min(right - left, bottom - top) / 2 - 2.5
    side = int(round(r * 2))
    p = portrait_img.resize((side, side), Image.LANCZOS)
    mask = Image.new("L", (side * 4, side * 4), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, side * 4 - 1, side * 4 - 1], fill=255)
    mask = mask.resize((side, side), Image.LANCZOS)
    out = card.copy()
    out.paste(p, (int(round(cx - side / 2)), int(round(cy - side / 2))), mask)
    return out


def save(img: Image.Image, dst: Path) -> None:
    """写出前先备份原图（只备份第一次）"""
    if dst.exists():
        bk = BACKUP / dst.relative_to(GODOT)
        if not bk.exists():
            bk.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dst, bk)
    dst.parent.mkdir(parents=True, exist_ok=True)
    img.save(dst)
    print("→", dst.relative_to(GODOT), img.size)


def original(dst: Path) -> Path:
    bk = BACKUP / dst.relative_to(GODOT)
    return bk if bk.exists() else dst


def preview(out: str) -> None:
    """人物裁切 + 头像框预览（核对头像框用）"""
    cw, ch = 300, 360
    names = list(FIGURES)
    cols = 5
    sheet = Image.new("RGB", (cols * cw, (len(names) + cols - 1) // cols * ch * 2), (70, 70, 90))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        fig = figure(n)
        t = fig.copy()
        t.thumbnail((cw - 10, ch - 30))
        x, y = (i % cols) * cw, (i // cols) * ch * 2
        sheet.paste(t, (x + 5, y + 5), t)
        k = t.width / fig.width
        hb = FIGURES[n][2]
        d.rectangle([x + 5 + hb[0] * t.width, y + 5 + hb[1] * t.height, x + 5 + hb[2] * t.width, y + 5 + hb[3] * t.height], outline=(255, 255, 0), width=2)
        d.text((x + 5, y + ch - 22), f"{n} {fig.size} k={k:.3f}", fill=(255, 255, 0))
        p = portrait(fig, hb, 256)
        sheet.paste(p, (x + 20, y + ch + 10))
    sheet.save(out)


def main() -> int:
    if "--restore" in sys.argv:
        for f in BACKUP.rglob("*.png"):
            shutil.copy2(f, GODOT / f.relative_to(BACKUP))
            print("restored", f.relative_to(BACKUP))
        return 0
    if "--preview" in sys.argv:
        preview(sys.argv[sys.argv.index("--preview") + 1])
        return 0
    figs = {n: figure(n) for n in FIGURES}
    for uid, fname in UNITS.items():
        fig = figs[fname]
        save(fit_into(fig, (UNIT_CANVAS, UNIT_CANVAS), UNIT_BOX), SPR / f"units/{uid}.png")
        save(portrait(fig, FIGURES[fname][2]), SPR / f"portraits/{uid}.png")
    for card, form in CARD_FORMS.items():
        dst = CARDS / f"{card}.png"
        save(card_with_portrait(original(dst), Image.open(SPR / f"portraits/{form}.png").convert("RGBA")), dst)
    for name, fname in ILLUSTRATIONS.items():
        save(fit_into(clean(Image.open(SRC / fname)), ILLU_CANVAS, ILLU_BOX), SPR / f"illustrations/{name}.png")
    for rel, fname in OBJECTS.items():
        save(fit_into(clean(Image.open(SRC / fname), 0.005), (OBJ_CANVAS, OBJ_CANVAS), OBJ_BOX, bottom=False), SPR / rel)
    return 0


if __name__ == "__main__":
    sys.exit(main())
