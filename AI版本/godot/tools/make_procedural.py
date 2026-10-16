#!/usr/bin/env python
"""Generate the project's small procedural RGBA sprites and simple line icons."""
from pathlib import Path
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "sprites"
BONE = (232, 220, 196, 255)
RED = (122, 30, 43, 255)
PURPLE = (176, 108, 255, 255)
GOLD = (201, 162, 74, 255)
DARK = (42, 20, 48, 217)
INK = (34, 24, 35, 255)


def canvas(size, color=(0, 0, 0, 0)):
    return Image.new("RGBA", size, color)


def save(im, rel):
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)
    print(f"PNG {rel} {im.size}")


def soft_radial(size, color, radius_scale=0.48, softness=0.22):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    cx, cy = (w - 1) / 2, (h - 1) / 2
    rx, ry = w * radius_scale, h * radius_scale
    d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    alpha = np.clip((1 - d) / softness, 0, 1) * 255
    arr = np.empty((h, w, 4), dtype=np.uint8)
    arr[..., :3] = color[:3]
    arr[..., 3] = alpha.astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def make_projectiles():
    im = canvas((64, 24))
    d = ImageDraw.Draw(im)
    d.polygon([(1, 12), (19, 5), (43, 8), (63, 12), (43, 16), (19, 19)], fill=(122, 30, 43, 170))
    d.polygon([(22, 12), (39, 5), (61, 12), (39, 19)], fill=(122, 30, 43, 210))
    d.polygon([(3, 12), (31, 4), (61, 12), (31, 20)], fill=(232, 220, 196, 255))
    d.line([(8, 12), (31, 5), (55, 12)], fill=(255, 248, 229, 255), width=2)
    d.polygon([(55, 12), (63, 12), (55, 13)], fill=(255, 255, 246, 255))
    save(im, "projectiles/bone_shard.png")

    w, h = 192, 16
    yy, xx = np.mgrid[0:h, 0:w]
    dy = np.abs(yy - (h - 1) / 2)
    width = np.maximum(0.5, 7.5 - (np.abs(xx - (w - 1) / 2) / 30))
    alpha = np.clip((width - dy + 1.5) * 90, 0, 255)
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    arr[..., 0] = 232 + (dy < 2) * 23
    arr[..., 1] = 220 + (dy < 2) * 28
    arr[..., 2] = 196 + (dy < 2) * 48
    arr[..., 3] = alpha.astype(np.uint8)
    beam = Image.fromarray(arr, "RGBA")
    ImageDraw.Draw(beam).line([(4, 8), (188, 8)], fill=(255, 255, 247, 240), width=2)
    save(beam, "projectiles/lance_beam.png")

    im = canvas((48, 48))
    d = ImageDraw.Draw(im)
    d.ellipse((4, 5, 44, 44), fill=(255, 122, 62, 235), outline=(255, 182, 103, 255), width=2)
    d.ellipse((14, 15, 34, 35), fill=(88, 34, 38, 245))
    d.ellipse((9, 9, 17, 16), fill=(255, 218, 151, 230))
    save(im, "projectiles/bone_spit.png")

    im = soft_radial((48, 48), PURPLE, 0.43, 0.32)
    d = ImageDraw.Draw(im)
    d.ellipse((10, 10, 38, 38), outline=(214, 181, 255, 185), width=1)
    d.ellipse((18, 18, 30, 30), fill=(210, 180, 255, 100))
    save(im, "projectiles/whisper_bolt.png")

    im = soft_radial((64, 64), (255, 166, 64), 0.45, 0.28)
    d = ImageDraw.Draw(im)
    # A few broad pollen sparks keep the orb legible without a grain field.
    for box in [(12, 19, 18, 25), (42, 15, 47, 20), (39, 41, 45, 47), (19, 43, 23, 47), (29, 10, 33, 14)]:
        d.ellipse(box, fill=(255, 211, 105, 220))
    save(im, "projectiles/pollen_orb.png")


def make_vfx():
    size = 128
    yy, xx = np.mgrid[0:size, 0:size]
    cx = cy = (size - 1) / 2
    radius = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size * 0.49)
    alpha = np.exp(-3.7 * radius ** 2) * 255
    arr = np.empty((size, size, 4), dtype=np.uint8)
    arr[..., :3] = 255
    arr[..., 3] = alpha.astype(np.uint8)
    save(Image.fromarray(arr, "RGBA"), "vfx/soft_circle.png")

    size = 256
    yy, xx = np.mgrid[0:size, 0:size]
    r = np.sqrt((xx - 127.5) ** 2 + (yy - 127.5) ** 2)
    ring = np.exp(-((r - 82) / 10) ** 2) * 255
    arr = np.zeros((size, size, 4), dtype=np.uint8)
    arr[..., :3] = 255
    arr[..., 3] = ring.astype(np.uint8)
    save(Image.fromarray(arr, "RGBA"), "vfx/ring_soft.png")

    im = canvas((32, 32))
    d = ImageDraw.Draw(im)
    d.polygon([(16, 1), (19, 12), (31, 16), (19, 19), (16, 31), (13, 19), (1, 16), (13, 13)], fill=(255, 255, 255, 245))
    d.ellipse((14, 14, 18, 18), fill=(255, 255, 255, 255))
    save(im, "vfx/spark.png")

    fragments = [
        [(2, 15), (6, 8), (10, 10), (18, 3), (22, 7), (18, 13), (22, 18), (14, 21), (8, 18)],
        [(2, 6), (9, 3), (13, 9), (21, 6), (23, 12), (16, 16), (12, 22), (6, 18)],
        [(2, 12), (7, 6), (12, 9), (17, 2), (22, 8), (18, 14), (21, 18), (11, 22), (7, 17)],
    ]
    for idx, points in enumerate(fragments, 1):
        im = canvas((24, 24))
        d = ImageDraw.Draw(im)
        d.polygon(points, fill=(232, 220, 196, 255), outline=(94, 75, 69, 255))
        d.line(points[1:4], fill=(255, 248, 231, 255), width=1)
        save(im, f"vfx/bone_fragment_{idx}.png")

    im = canvas((16, 24))
    d = ImageDraw.Draw(im)
    d.polygon([(8, 1), (13, 9), (14, 14), (12, 20), (8, 23), (4, 20), (2, 14), (3, 9)], fill=(122, 30, 43, 255))
    d.ellipse((5, 15, 8, 19), fill=(173, 52, 61, 230))
    save(im, "vfx/blood_drop.png")

    im = canvas((160, 96))
    d = ImageDraw.Draw(im)
    d.ellipse((9, 23, 151, 83), outline=(232, 220, 196, 255), width=6)
    save(im, "vfx/faction_base_ally.png")

    im = canvas((160, 96))
    d = ImageDraw.Draw(im)
    cx, cy = 80, 48
    pts = []
    for i in range(16):
        angle = -math.pi / 2 + math.pi * i / 8
        radius = 43 if i % 2 == 0 else 35
        pts.append((cx + math.cos(angle) * radius * 1.52, cy + math.sin(angle) * radius * 0.70))
    d.polygon(pts, outline=(255, 75, 62, 255), width=4)
    save(im, "vfx/faction_base_enemy.png")

    im = canvas((176, 112))
    d = ImageDraw.Draw(im)
    d.rectangle((16, 12, 160, 100), outline=GOLD, width=4)
    save(im, "vfx/faction_base_structure.png")

    shadow = soft_radial((128, 64), (0, 0, 0), 0.48, 0.20)
    save(shadow, "vfx/shadow_blob.png")


def rounded_button(name, fill, border, inner=None):
    im = canvas((192, 56))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((1, 1, 190, 54), radius=8, fill=fill, outline=border, width=2)
    if inner:
        d.rounded_rectangle((5, 5, 186, 50), radius=6, outline=inner, width=1)
    save(im, f"ui/button_{name}.png")


def make_ui_rasters():
    im = canvas((96, 96), DARK)
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 95, 95), outline=(232, 220, 196, 217), width=1)
    save(im, "ui/panel_dark.png")

    im = canvas((96, 96))
    arr = np.zeros((96, 96, 4), dtype=np.uint8)
    yy, xx = np.mgrid[0:96, 0:96]
    broad_tone = np.clip(1 - np.sqrt(((xx - 48) / 74) ** 2 + ((yy - 40) / 74) ** 2), 0, 1)
    paper_wave = (1.8 * np.sin(xx * 2 * np.pi / 73)
                  + 1.1 * np.cos(yy * 2 * np.pi / 57)
                  + 1.0 * np.sin((xx + yy) * 2 * np.pi / 91))
    warm = 231 + broad_tone * 10 - yy * 0.018 + paper_wave
    arr[..., 0] = np.clip(warm + 6, 0, 255).astype(np.uint8)
    arr[..., 1] = np.clip(warm + 2, 0, 255).astype(np.uint8)
    arr[..., 2] = np.clip(warm - 8, 0, 255).astype(np.uint8)
    arr[..., 3] = 255
    im = Image.fromarray(arr, "RGBA")
    d = ImageDraw.Draw(im)
    d.rectangle((1, 1, 94, 94), outline=(119, 87, 66, 255), width=2)
    d.line((4, 7, 91, 7), fill=(255, 250, 229, 255), width=1)
    save(im, "ui/panel_bone.png")

    rounded_button("normal", (122, 30, 43, 255), BONE)
    rounded_button("hover", (122, 30, 43, 255), GOLD, (232, 220, 196, 180))
    rounded_button("pressed", (75, 22, 34, 255), (160, 128, 112, 255), (50, 18, 31, 255))
    rounded_button("disabled", (74, 51, 80, 210), (128, 116, 135, 180))

    for on in (False, True):
        im = canvas((48, 24))
        d = ImageDraw.Draw(im)
        bg = (62, 44, 73, 255) if not on else (89, 62, 37, 255)
        d.rounded_rectangle((1, 1, 46, 22), radius=11, fill=bg, outline=GOLD if on else BONE, width=1)
        cx = 35 if on else 12
        d.ellipse((cx - 8, 4, cx + 8, 20), fill=GOLD if on else BONE)
        if on:
            d.line((cx - 3, 12, cx, 15, cx + 4, 9), fill=(58, 42, 37, 255), width=1)
        else:
            d.line((cx - 3, 12, cx + 3, 12), fill=(82, 67, 74, 255), width=1)
        save(im, f"ui/toggle_{'on' if on else 'off'}.png")

    im = canvas((160, 40), DARK)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 159, 39), radius=4, outline=BONE, width=1)
    save(im, "ui/dropdown_bg.png")

    im = canvas((200, 8))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 1, 199, 6), radius=3, fill=(62, 44, 73, 255), outline=(140, 118, 139, 255), width=1)
    save(im, "ui/slider_track.png")
    im = canvas((20, 20))
    d = ImageDraw.Draw(im)
    d.ellipse((1, 1, 18, 18), fill=BONE, outline=(86, 63, 73, 255), width=1)
    d.ellipse((6, 6, 13, 13), fill=(255, 248, 228, 255))
    save(im, "ui/slider_grabber.png")

    row_styles = {
        "normal": ((42, 20, 48, 210), None),
        "active": ((42, 20, 48, 240), GOLD),
        "disabled": ((74, 51, 80, 145), None),
    }
    for name, (fill, marker) in row_styles.items():
        im = canvas((480, 56), fill)
        d = ImageDraw.Draw(im)
        d.line((0, 55, 479, 55), fill=(130, 106, 133, 170), width=1)
        if marker:
            d.rectangle((0, 0, 5, 55), fill=marker)
        save(im, f"ui/rule_row_bg_{name}.png")

    def hp_bar(name, shape):
        im = canvas((96, 10))
        d = ImageDraw.Draw(im)
        if shape == "rounded":
            d.rounded_rectangle((1, 1, 94, 8), radius=4, outline=(255, 255, 255, 255), width=1)
        elif shape == "pointed":
            d.polygon([(1, 5), (7, 1), (88, 1), (95, 5), (88, 9), (7, 9)], outline=(255, 255, 255, 255), fill=(0, 0, 0, 0))
        else:
            d.rectangle((1, 1, 94, 8), outline=(255, 255, 255, 255), width=1)
        save(im, f"ui/hp_bar_{name}.png")
    hp_bar("ally", "rounded")
    hp_bar("enemy", "pointed")
    hp_bar("structure", "square")

    im = canvas((512, 512))
    ImageDraw.Draw(im).ellipse((0, 0, 511, 511), fill=(255, 255, 255, 255))
    save(im, "ui/portrait_mask.png")

    im = canvas((32, 32))
    d = ImageDraw.Draw(im)
    d.polygon([(4, 2), (26, 19), (17, 20), (22, 29), (18, 31), (13, 22), (8, 28)], fill=BONE, outline=INK)
    save(im, "ui/cursor_default.png")
    im = canvas((32, 32))
    d = ImageDraw.Draw(im)
    d.polygon([(6, 14), (6, 7), (10, 5), (14, 10), (14, 3), (18, 3), (19, 10), (22, 5), (25, 7), (22, 15), (25, 19), (22, 27), (14, 28), (9, 22)], fill=BONE, outline=INK)
    save(im, "ui/cursor_drag.png")


ICONS = {
    "stat_hp": '<path d="M12 21 3.5 12.8C-1 6.8 7 2.2 12 7c5-4.8 13-0.2 8.5 5.8Z"/><path d="m13 7-3 6 3 1-2 5"/>',
    "stat_attack": '<path d="M12 2 9 8l3 2 3-2-3-6Z"/><path d="m9 8-2 9 5 5 5-5-2-9"/><path d="M7 17h10"/>',
    "stat_aps": '<path d="M5 3h14l-5 7 5 11H5l5-11Z"/><path d="M8 6h8M8 18h8"/>',
    "stat_speed": '<path d="M3 7h10M1 12h14M4 17h9"/><path d="m17 7 4 5-4 5"/>',
    "stat_vision": '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6Z"/><circle cx="12" cy="12" r="2.5"/>',
    "stat_range": '<circle cx="11" cy="13" r="7"/><circle cx="11" cy="13" r="3"/><path d="M11 13 20 4m-5 0h5v5"/>',
    "cond_always": '<path d="M12 12c-2-4-4-6-6-6a5 5 0 0 0 0 10c2 0 4-2 6-6Zm0 0c2-4 4-6 6-6a5 5 0 0 1 0 10c-2 0-4-2-6-6Z"/>',
    "cond_hp_below": '<path d="M12 21 3.5 12.8C-1 6.8 7 2.2 12 7c5-4.8 13-.2 8.5 5.8Z"/><path d="M5 13h14v5.5L12 21l-7-2.5Z"/>',
    "cond_visible": '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6Z"/><circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="1"/>',
    "cond_in_range": '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><path d="M12 1v4M12 19v4M1 12h4M19 12h4"/>',
    "cond_distance": '<path d="M3 12h18M3 12l4-4m-4 4 4 4m14-4-4-4m4 4-4 4"/><path d="M8 8v8m8-8v8"/>',
    "cond_retreat_possible": '<path d="M5 22V3h14v19M5 22h15"/><path d="M8 7 15 5v14l-7 2Z"/><circle cx="12" cy="12" r=".65"/>',
    "sel_nearest": '<path d="M2 2l7 7m13-7-7 7M2 22l7-7m13 7-7-7"/><path d="M5 9h4V5m10 4h-4V5M5 15h4v4m10-4h-4v4"/><circle cx="12" cy="12" r="2"/>',
    "sel_farthest": '<path d="m9 9-6-6m12 6 6-6M9 15l-6 6m12-6 6 6"/><path d="M8 3H3v5m13-5h5v5M8 21H3v-5m13 5h5v-5"/><circle cx="12" cy="12" r="2"/>',
    "sel_lowest_hp": '<path d="M12 17 5 10c-3-4 2-8 7-4 5-4 10 0 7 4Z"/><path d="M12 12v10m-4-4 4 4 4-4"/>',
    "sel_first_seen": '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6Z"/><path d="M11 10h2v6m-2 0h4"/>',
    "act_idle": '<rect x="5" y="5" width="14" height="14" rx="2"/><path d="M9 9h6v6H9z"/>',
    "act_attack": '<path d="m4 4 16 16M20 4 4 20"/><path d="m2 2 4 1 1 4-4 1-2-2ZM22 2l-4 1-1 4 4 1 2-2ZM2 22l4-1 1-4-4-1-2 2ZM22 22l-4-1-1-4 4-1 2 2Z"/>',
    "act_chase_attack": '<path d="M3.8 20c-2.1 0-3.1-1.8-2.3-4l1.5-4c.6-1.5 2.4-1.5 3.1-.1l1.7 4C8.6 18.1 7 20 3.8 20Zm8-8c-2.1 0-3.1-1.8-2.3-4L11 4c.6-1.5 2.4-1.5 3.1-.1l1.7 4c.8 2.2-.8 4.1-4 4.1Z"/><circle cx="2.8" cy="10" r=".7"/><circle cx="5" cy="9.6" r=".7"/><circle cx="7.1" cy="10.5" r=".7"/><circle cx="10.8" cy="2.8" r=".7"/><circle cx="13" cy="2.5" r=".7"/><circle cx="15.1" cy="3.3" r=".7"/><path d="m17 13 1.3 1.3 1.3-1.3 2 2-1.3 1.3 1.3 1.3-2 2-1.3-1.3-1.3 1.3-2-2 1.3-1.3-1.3-1.3Z"/>',
    "act_chase": '<path d="M5 21c-2.5 0-3.8-2-2.8-4.6l1.6-4.2c.7-1.8 2.8-1.8 3.6-.1l1.8 4.2C10.2 18.9 8.3 21 5 21Zm10-9c-2.5 0-3.8-2-2.8-4.6l1.6-4.2c.7-1.8 2.8-1.8 3.6-.1l1.8 4.2c1 2.6-.9 4.7-4.2 4.7Z"/><circle cx="3.7" cy="10.5" r=".65"/><circle cx="5.8" cy="10" r=".65"/><circle cx="7.9" cy="10.9" r=".65"/><circle cx="13.7" cy="1.5" r=".65"/><circle cx="15.8" cy="1.3" r=".65"/><circle cx="17.9" cy="2" r=".65"/>',
    "act_retreat": '<path d="M21 10h-8m0 0 4-4m-4 4 4 4"/><path d="M3 18c3 0 3-4 6-4"/><circle cx="5" cy="7" r="1.5"/><circle cx="9" cy="10" r="1.5"/>',
    "act_route": '<path d="M4 19V5h7v7h9"/><circle cx="4" cy="19" r="2"/><circle cx="20" cy="12" r="2"/><circle cx="4" cy="5" r="2"/>',
    "form_striker": '<circle cx="12" cy="5" r="3"/><path d="M12 8v8m-5-4h10m-7 4-2 6m4-6 2 6"/>',
    "form_bulwark": '<circle cx="12" cy="5" r="3"/><path d="M7 9 3 12l3 4m11-7 4 3-3 4M7 9h10v8H7zm2 8-2 5m8-5 2 5"/>',
    "form_swift": '<circle cx="14" cy="5" r="3"/><path d="m11 8-5 5 6 2 3 6m-6-8 8-2m-9 4-4 5"/>',
    "form_lancer": '<circle cx="10" cy="5" r="3"/><path d="M10 8v8m-5-4h9m-6 4-2 6m5-6 2 6M17 2l4 20"/>',
    "play": '<path d="m6 4 13 8-13 8Z"/>',
    "reset": '<path d="M4 10a8 8 0 1 1 1 7"/><path d="M4 4v6h6"/>',
    "pause": '<path d="M8 5v14M16 5v14"/>',
    "speed_1x": '<path d="M3 8 6 5h2v14M13 8l7 8m0-8-7 8"/>',
    "speed_2x": '<path d="M2 8c0-4 8-4 8 0 0 3-8 4-8 10h8m3-10 7 8m0-8-7 8"/>',
    "hint": '<path d="M12 3c-2.3 2.3-3.6 4.7-2.4 7.2L8 16h8l-1.6-5.8C15.6 7.7 14.3 5.3 12 3Z"/><path d="M9 16v2h6v-2m-5 4h4"/><path d="M18 7c1-1 1.5-2.2 1.3-3.3M6 7C5 6 4.5 4.8 4.7 3.7"/>',
    "mechanics": '<path d="M12 6c-3-2-6-2-9-1v14c3-1 6-1 9 1 3-2 6-2 9-1V5c-3-1-6-1-9 1Z"/><path d="M12 6v14"/>',
    "exit": '<path d="M5 21V3h10v18M5 21h15"/><path d="M9 12h11m-4-4 4 4-4 4"/>',
    "export": '<path d="M12 3v13m-5-5 5 5 5-5M4 20h16"/>',
    "state_idle": '<path d="M3 6h6l-6 5h6m4 2h5l-5 4h5"/>',
    "state_blocked": '<circle cx="12" cy="12" r="9"/><path d="m6 6 12 12"/>',
    "state_out_of_range": '<circle cx="12" cy="12" r="8"/><path d="M12 1v3m0 16v3M1 12h3m16 0h3m-4-10v4m-2-2h4M4 18v3m-2-2h4"/><path d="m10.5 10.5 3 3m0-3-3 3"/>',
    "state_cooldown": '<path d="M6 3h12M6 21h12M7 4c0 5 5 5 5 8s-5 3-5 8m10-16c0 5-5 5-5 8s5 3 5 8"/>',
    "state_locked": '<rect x="5" y="10" width="14" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3m-4 4v3"/>',
    "trait_blast": '<circle cx="12" cy="12" r="4"/><path d="M12 1v4m0 14v4M1 12h4m14 0h4M4 4l3 3m10 10 3 3M20 4l-3 3M7 17l-3 3"/>',
    "trait_flee": '<path d="M12 12 4 4m8 8 8-8m-8 8-8 8m8-8 8 8"/><path d="m4 4 5 1M4 4l1 5m15-5-5 1m5-1-1 5"/>',
    "trait_lock": '<path d="M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6Z"/><circle cx="12" cy="12" r="2.5"/><rect x="15" y="14" width="6" height="6" rx="1"/><path d="M17 14v-1a1.5 1.5 0 0 1 3 0v1"/>',
}


def make_icons():
    icon_dir = OUT / "ui" / "icons"
    icon_dir.mkdir(parents=True, exist_ok=True)
    for name, shapes in ICONS.items():
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
            '<g fill="none" stroke="#E8DCC4" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            f"{shapes}</g></svg>"
        )
        (icon_dir / f"{name}.svg").write_text(svg, encoding="utf-8")
        print(f"SVG ui/icons/{name}.svg")

    extras = {
        "dropdown_arrow": '<path d="m4 8 4 4 4-4"/>',
        "drag_handle": '<circle cx="8" cy="7" r="1.3"/><circle cx="16" cy="7" r="1.3"/><circle cx="8" cy="12" r="1.3"/><circle cx="16" cy="12" r="1.3"/><circle cx="8" cy="17" r="1.3"/><circle cx="16" cy="17" r="1.3"/>',
    }
    for name, shapes in extras.items():
        svg = (
            '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
            '<g fill="none" stroke="#E8DCC4" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
            f"{shapes}</g></svg>"
        )
        (OUT / "ui" / f"{name}.svg").write_text(svg, encoding="utf-8")
        print(f"SVG ui/{name}.svg")


def main():
    make_projectiles()
    make_vfx()
    make_ui_rasters()
    make_icons()
    print(f"Generated procedural RGBA PNGs and {len(ICONS)} icons + 2 UI SVGs.")


if __name__ == "__main__":
    main()
