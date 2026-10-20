"""音效 v2 构建：把对照表（游戏音效素材_v1/音效对照表_待校对.html）的主选落成 assets/audio/sfx/<id>.ogg。

处理：解码 → 去头部静音 → 可选裁剪 + 尾部淡出 → 可选叠层混音 → 峰值归一到指定 dBFS → 写 OGG Vorbis。
被替换的旧文件（同 id 任意扩展名）先移到 tools/_raw/sfx_replaced_v1/ 备份；来源记入 tools/_raw/sfx/source_manifest_v2.csv。
用法：python -I tools/build_sfx_v2.py
"""
import csv
import os
import shutil
import sys

import numpy as np
import soundfile as sf
from scipy.signal import bilinear_zpk, butter, sosfilt, zpk2sos

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
BGM = os.path.join(ROOT, "assets", "audio", "bgm")
KENNEY = os.path.join(ROOT, "tools", "_raw", "sfx")
FS_STORE = os.path.join(KENNEY, "freesound")          # 下载的 Freesound HQ 预览，留档
BACKUP = os.path.join(ROOT, "tools", "_raw", "sfx_replaced_v1")
LIB = r"C:\Users\Administrator\Downloads\游戏音效素材_v1"
FS_DL = os.path.join(LIB, "_校对", "audio", "Freesound")
RATE = 44100

# Freesound id -> (作者, 标题)，用于授权台账
FS_META = {}


def v1(p):
    return ("v1", os.path.join(LIB, p), "音效库 v1 / " + p)


def k(p):
    return ("kenney", os.path.join(KENNEY, p), "Kenney / " + p)


def fs(i, user, title):
    FS_META[i] = (user, title)
    return ("fs", os.path.join(FS_DL, "%d.mp3" % i), "Freesound %d / %s / %s" % (i, user, title))


# id: (源, 选项)。选项：db=峰值 dBFS（默认 -8），dur=裁剪到秒，fade=淡出秒，layer=[(源, 偏移秒, 增益)]，bgm=写到 bgm 目录
UI_DB = -10.0
SOFT_DB = -16.0
SPEC = {
    # 通用 UI
    "ui_select": (k("interface-sounds/Audio/select_002.ogg"), {"db": UI_DB}),
    "ui_value_tick": (k("interface-sounds/Audio/tick_004.ogg"), {"db": SOFT_DB}),
    "ui_panel_open": (fs(496188, "JonasTisell", "Whoosh (Clothing Drag)"), {"db": -13.0}),
    "ui_panel_close": (k("interface-sounds/Audio/minimize_003.ogg"), {"db": -13.0}),
    "ui_back": (k("interface-sounds/Audio/back_002.ogg"), {"db": UI_DB}),
    "ui_confirm_major": (k("interface-sounds/Audio/confirmation_002.ogg"), {"db": -9.0}),
    "ui_skip": (fs(324660, "uEffects", "Brush Streak"), {"db": -12.0}),
    "text_blip": (fs(380137, "yottasounds", "Typewriter - single key - type 2"), {"db": -22.0, "dur": 0.12}),
    # 局外动画
    "logo_ring": (fs(517877, "The_Real_Not_Important", "Swoosh_Low"), {"db": -12.0}),
    "logo_string": (fs(352929, "Dalesome", "string pluck (ukulele)"), {"db": -14.0}),
    "logo_heart": (fs(276578, "MickBoere", "Heavy Heartbeat"), {"db": -6.0}),
    "logo_decode": (fs(416777, "Sky_Motion", "digital_typing"), {"db": -16.0}),
    "logo_out": (fs(683183, "NearTheAtmoshphere", "Magic Depleted 2"), {"db": -14.0}),
    "transition_shatter": (v1("09_玻璃破碎/大玻璃破碎_Glass_Break_221528.mp3"), {"db": -12.0, "dur": 0.7, "fade": 0.25}),
    "transition_fade": (fs(71852, "ludvique", "digital_whoosh_soft"), {"db": -15.0}),
    "unlock_shake": (fs(164650, "deleted_user_2104797", "Lock rattle 2"), {"db": -10.0, "dur": 1.1, "fade": 0.1}),
    "unlock_open": (v1("02_开锁/门锁开启_Door_Unlocking_422852.mp3"), {"db": -8.0}),
    "unlock_reveal": (fs(360948, "marcusgar", "Little bell"), {"db": -11.0}),
    "locked_click": (k("rpg-audio/Audio/metalLatch.ogg"), {"db": -10.0}),
    "node_select": (k("interface-sounds/Audio/select_004.ogg"), {"db": UI_DB}),
    "map_swish": (fs(816261, "Sadiquecat", "Broomstick whoosh 2 - Soft low"), {"db": -18.0}),
    "cg_fade": (fs(774635, "loganzsound", "Reverse Cymbal Shiny"), {"db": -16.0}),
    "tip_card": (k("interface-sounds/Audio/bong_001.ogg"), {"db": -11.0}),
    "tutorial_done": (fs(442943, "qubodup", "Level Up"), {"db": -10.0}),
    "result_count": (k("interface-sounds/Audio/tick_002.ogg"), {"db": -16.0}),
    "result_stamp": (fs(470710, "I.fekry", "traditional stamp"), {"db": -6.0}),
    "result_record": (fs(715067, "SkySpeira", "achievement-sparkle"), {"db": -9.0}),
    "sting_victory": (v1("07_胜利/电影感_sting_Victory_(short_sting)_706753.mp3"), {"db": -6.0, "dur": 3.4, "fade": 0.8, "bgm": True}),
    "sting_defeat": (v1("08_失败/定音鼓_1_Failure_Drum_Sound_Effect_1_456962.mp3"), {"db": -6.0, "bgm": True}),
    # 局内 UI / 物品移动
    "drag_snap": (k("ui-audio/Audio/switch2.ogg"), {"db": -20.0}),
    "drag_cancel": (k("interface-sounds/Audio/back_004.ogg"), {"db": UI_DB}),
    "deploy_place": (v1("10_物品放置/物品放置_put_item_335751.mp3"), {"db": -8.0}),
    "deploy_remove": (k("rpg-audio/Audio/handleSmallLeather.ogg"), {"db": -9.0}),
    "deploy_clear": (fs(171255, "qubodup", "Sliding Trailer Woosh"), {"db": -11.0}),
    "formation_apply": (k("impact-sounds/Audio/impactWood_heavy_003.ogg"), {"db": -8.0}),
    "relic_pick": (k("rpg-audio/Audio/metalClick.ogg"), {"db": UI_DB}),
    "relic_place": (fs(743246, "qubodup", "Move Stone Rune 4"), {"db": -8.0}),
    "relic_arm": (k("interface-sounds/Audio/switch_003.ogg"), {"db": UI_DB}),
    "relic_disarm": (k("interface-sounds/Audio/switch_004.ogg"), {"db": UI_DB}),
    "beacon_place": (k("impact-sounds/Audio/impactMetal_light_001.ogg"), {"db": -10.0}),
    "beacon_remove": (k("impact-sounds/Audio/impactGeneric_light_002.ogg"), {"db": -10.0}),
    "rule_add": (k("rpg-audio/Audio/bookPlace1.ogg"), {"db": -9.0}),
    "rule_remove": (fs(710163, "omgitsjo", "Paper Rip 4"), {"db": -10.0}),
    "unit_select_ally": (k("interface-sounds/Audio/select_006.ogg"), {"db": UI_DB}),
    "unit_select_enemy": (k("interface-sounds/Audio/select_008.ogg"), {"db": UI_DB}),
    "soul_spend": (fs(802472, "Sadiquecat", "Whoosh - Magic disappear"), {"db": -14.0}),
    "soul_refund": (fs(562196, "gristi", "snd_fragment_retrieve"), {"db": -14.0, "dur": 0.9, "fade": 0.3}),
    "budget_over": (k("interface-sounds/Audio/error_006.ogg"), {"db": UI_DB}),
    # 战斗流程
    "battle_start": (fs(633208, "igroglaz", "Old Church Bell (no noise)"), {"db": -5.0, "dur": 3.6, "fade": 1.2}),
    "battle_resume": (k("impact-sounds/Audio/impactBell_heavy_002.ogg"), {"db": -9.0}),
    "game_pause": (k("interface-sounds/Audio/switch_006.ogg"), {"db": UI_DB}),
    "game_unpause": (k("interface-sounds/Audio/switch_007.ogg"), {"db": UI_DB}),
    "battle_reset": (fs(842582, "loganzsound", "Vinyl Rewind Dark 01"), {"db": -10.0}),
    "objective_clear": (fs(333629, "jgreer", "Chime sound"), {"db": -9.0}),
    "protect_alert": (k("impact-sounds/Audio/impactBell_heavy_001.ogg"), {"db": -10.0}),
    "boss_warn": (fs(561207, "Rizzard", "Riser"), {"db": -10.0}),
    "boss_phase": (fs(592041, "XHALE303", "BRAAMS and TIMPANI"), {"db": -5.0}),
    "unit_summon": (fs(491911, "JT07412", "Summoning sound"), {"db": -9.0}),
    "boss_death": (fs(856173, "brktkrgll", "Apocalyptic Cinematic Brass Braam Impact"), {"db": -5.0}),
    # 行走（每区域 3 个变体，见 FOOTSTEPS）
    "retreat_swish": (fs(59995, "qubodup", "swosh-08 stick cutting air"), {"db": -14.0}),
    # 攻击
    "attack_swift": (fs(370204, "nekoninja", "samurai slash"), {"db": -9.0}),
    "attack_striker": (fs(196563, "kylepyke", "Knife throw 2"), {"db": -11.0, "dur": 0.45, "fade": 0.12}),
    "attack_lancer": (v1("03_射击/光球发射_Energy_magic_shot_519414.mp3"), {"db": -10.0, "dur": 0.9, "fade": 0.35}),
    "attack_binder": (fs(536737, "egomassive", "Chain.ogg"), {"db": -10.0}),
    "priest_whisper": (fs(447092, "Sol5", "Susurro conjuro"), {"db": -11.0}),
    "enemy_bite": (fs(445987, "Breviceps", "Horror / Zombie - Biting on bones"), {"db": -10.0}),
    "spitter_charge": (fs(403705, "pabloperez", "HUM 12"), {"db": -9.0, "dur": 1.6, "fade": 0.4}),
    "core_pulse": (fs(209943, "Logicogonist", "bass 16b"), {"db": -7.0}),
    "witch_attack": (fs(442774, "qubodup", "Magic Spell"), {"db": -10.0}),
    # 2026-10-21 Boss 放招：女鬼尖啸——幽灵哀嚎（颤音 + 长混响尾）打底，叠一层真人女声尖叫做刺耳的起音
    "boss_scream": (fs(469141, "onderwish", "Ghost Scream"),
                    {"db": -6.0, "dur": 2.8, "fade": 1.1, "lp": 7500.0, "hp": 180.0,
                     "layer": [(fs(844114, "perspektywa_tn", "scream_female_reverb"), 0.0, 0.5, {"lp": 7000.0, "hp": 200.0})]}),
    "blast_detonate": (fs(431174, "Blankened", "Fireball Explosion"), {"db": -5.0}),
    "blast_land": (k("impact-sounds/Audio/impactSoft_heavy_001.ogg"), {"db": -14.0}),
    "attack_fizzle": (fs(619803, "Teh_Bucket", "Error fizzle"), {"db": -13.0}),
    # 受击
    "hit_flesh": (v1("05_受击/轻肉体_Light_Body_thud_(on_clothing)_496187.mp3"), {"db": -10.0}),
    "hit_bone": (v1("05_受击/骨_骨甲_Skeleton_bones_(game)_381859.mp3"), {"db": -10.0, "dur": 0.5, "fade": 0.15}),
    "hit_heavy": (v1("05_受击/血肉重击_Meaty_Damage_Impact_779805.mp3"), {"db": -8.0}),
    "heal": (v1("12_正面BUFF/施法_buff_高音_Spell_Cast_Buff_High_Tone_420676.mp3"), {"db": -10.0}),
    # 死亡
    "death_enemy": (v1("06_死亡/崩解成灰_Crumble_#9_348954.mp3"), {"db": -9.0, "dur": 1.2, "fade": 0.4}),
    "death_ally": (v1("11_物品破坏/木材断裂_Wood_Break_443293.mp3"), {"db": -8.0}),
    "death_priest": (v1("06_死亡/崩解成灰_Crumble_#9_348954.mp3"),
                     {"db": -8.0, "dur": 1.5, "fade": 0.4, "layer": [(fs(368615, "Nightflame", "breath_01"), 0.0, 0.8)]}),
    "death_core": (v1("06_死亡/崩解成灰_Crumble_#9_348954.mp3"),
                   {"db": -7.0, "dur": 1.5, "fade": 0.4, "layer": [(fs(578874, "samueleunimancer", "BoneSnaping"), 0.0, 1.0)]}),
    "structure_destroyed": (v1("11_物品破坏/木箱破坏_Crate_Break_4_66780.mp3"), {"db": -8.0}),
    # 状态
    "status_vulnerable": (v1("13_负面BUFF/低频不祥_Ominous_Bass_546683.mp3"), {"db": -12.0}),
    "status_paralysis": (fs(512471, "michael_grinnell", "Electric zap"), {"db": -12.0}),
    "status_slow": (fs(433840, "Archos", "Slime 27"), {"db": -12.0}),
    "status_expire": (fs(683183, "NearTheAtmoshphere", "Magic Depleted 2"), {"db": -18.0}),
    "shrine_cleanse": (fs(545238, "Mr._Fritz_", "Item Sparkle"), {"db": -11.0}),
}

# ── 二版（用户 2026-10-20）：常用按钮一律低频、柔和、小声，点击比悬停略清脆；解锁 = 锁碎裂，要大而清脆 ──
# 按钮族用同一块木头敲击做底（Wood Hit，频谱重心 ~0.9 kHz）+ 一点木质 click 做清脆的起音，再低通压掉高频。
WOOD = fs(364691, "alegemaate", "Wood Hit")
WCLICK = fs(321083, "BenjaminNelan", "Wooden Click")
KNOCK = fs(442878, "qubodup", "Door Knock")
ELEGANT = fs(822568, "qubodup", "User Interface Elegant Wooden Confirmation Sound")
BLOCKS = fs(676457, "NearTheAtmoshphere", "Wooden Blocks")


def click(pitch=1.0, db=-17.0, crisp=0.45, lp=2600.0, dur=0.16):
    return (WOOD, {"db": db, "pitch": pitch, "lp": lp, "hp": 120.0, "dur": dur, "fade": 0.06,
                   "layer": [(WCLICK, 0.0, crisp, {"pitch": pitch, "lp": 6000.0})]})


def tap(pitch=1.0, db=-22.0, lp=1800.0, dur=0.1):
    return (WOOD, {"db": db, "pitch": pitch, "lp": lp, "hp": 120.0, "dur": dur, "fade": 0.05})


SPEC.update({
    "ui_hover": tap(1.0, -27.0, 1500.0, 0.09),                  # 悬停：最轻、最闷
    "ui_click": click(1.0, -17.0, 0.75),                              # 点击：同底 + 一点清脆起音
    "ui_toggle": click(1.1, -18.0),
    "ui_select": click(1.18, -19.0, 0.35),
    "ui_back": click(0.86, -18.0, 0.3),
    "ui_panel_close": click(0.8, -19.0, 0.25),
    "unit_select_ally": click(1.05, -17.0),
    "unit_select_enemy": click(0.9, -17.0, 0.3),
    "game_pause": click(0.75, -16.0, 0.2, 2000.0),
    "game_unpause": click(1.0, -16.0, 0.4),
    "ui_value_tick": tap(1.35, -26.0, 2200.0, 0.05),
    "drag_snap": tap(1.5, -27.0, 2400.0, 0.045),
    "result_count": tap(1.4, -20.0, 3000.0, 0.05),
    "drag_cancel": tap(0.8, -19.0, 1800.0, 0.14),
    "ui_drag_pick": (BLOCKS, {"db": -18.0, "lp": 3000.0, "pitch": 0.9}),
    "ui_drag_drop": tap(0.9, -15.0, 2200.0, 0.16),
    "ui_error": (KNOCK, {"db": -14.0, "lp": 2600.0, "hp": 180.0, "pitch": 1.0, "dur": 0.42, "fade": 0.12}),   # 低沉的「咚咚」
    "budget_over": (KNOCK, {"db": -14.0, "lp": 2200.0, "hp": 150.0, "pitch": 0.9, "dur": 0.42, "fade": 0.12}),
    "ui_confirm_major": (WOOD, {"db": -12.0, "lp": 3000.0, "pitch": 0.8, "dur": 0.4, "fade": 0.2,
                                "layer": [(ELEGANT, 0.0, 0.6, {"lp": 6000.0, "pitch": 0.9})]}),
    "node_select": (ELEGANT, {"db": -16.0, "lp": 4500.0, "pitch": 0.85}),
    "relic_arm": (k("rpg-audio/Audio/metalClick.ogg"), {"db": -15.0, "lp": 4000.0}),
    "relic_disarm": (k("rpg-audio/Audio/metalClick.ogg"), {"db": -16.0, "lp": 3000.0, "pitch": 0.8}),
    "ui_skip": (fs(324660, "uEffects", "Brush Streak"), {"db": -18.0, "lp": 3000.0}),
    "tip_card": (k("interface-sounds/Audio/bong_001.ogg"), {"db": -15.0, "lp": 3000.0}),
    "timer_tick": (k("interface-sounds/Audio/tick_002.ogg"), {"db": -12.0, "lp": 4000.0, "pitch": 0.8}),
    "hint_open": (k("rpg-audio/Audio/bookOpen.ogg"), {"db": -14.0, "lp": 5000.0}),
    "dialogue_advance": (k("rpg-audio/Audio/bookFlip1.ogg"), {"db": -16.0, "lp": 5000.0, "dur": 0.45, "fade": 0.15}),
    # 解锁：锁颤抖（铁链轻响）→ 锁碎裂（水晶吊灯碎裂 + 玻璃砸碎 + 一记金属断裂，峰值拉满）→ 名字亮出（小铃）
    "unlock_shake": (fs(164650, "deleted_user_2104797", "Lock rattle 2"), {"db": -13.0, "dur": 1.1, "fade": 0.1, "lp": 6000.0}),
    "unlock_open": (fs(541601, "matt_ratz", "Shattering Chandelier"),
                    {"db": -1.5, "dur": 1.6, "fade": 0.6,
                     "layer": [(fs(244238, "chewiesmissus", "Glass Smash"), 0.0, 0.7),
                               (k("impact-sounds/Audio/impactMetal_heavy_002.ogg"), 0.0, 0.8)]}),
    "unlock_reveal": (fs(360948, "marcusgar", "Little bell"), {"db": -14.0}),
    "relic_ready": (fs(515643, "MashedTatoes2", "ding2"), {"db": -15.0, "lp": 6000.0}),
})

# ── 三版（用户 2026-10-20：锁碎裂「清脆有余但过于吵闹」，按同一思路优化全部）──
# ① 去噪：嘶嘶声重（6 kHz 以上占比高、频谱平坦）的素材加低通；② 能量全在超低频（小音箱放不出）的素材升调 / 高通；
# ③ 音量不再按峰值，而是按听感响度（A 计权）分层对齐，见 LOUD。
TWEAK = {
    "unlock_shake": {"lp": 5500.0},
    "unlock_reveal": {"pitch": 0.8, "lp": 7000.0},
    "locked_click": {"lp": 5000.0},
    "death_enemy": {"lp": 4000.0, "dur": 0.8, "fade": 0.35},
    "death_ally": {"lp": 5000.0, "dur": 0.7, "fade": 0.3},
    "death_priest": {"lp": 4000.0},
    "death_core": {"lp": 4500.0},
    "enemy_bite": {"lp": 5000.0},
    "status_paralysis": {"lp": 6000.0},
    "status_slow": {"lp": 4000.0},
    "status_vulnerable": {"pitch": 1.6, "hp": 70.0},          # 原素材几乎全在 30 Hz 以下，升调到听得见的低音区
    "spitter_charge": {"pitch": 2.0, "hp": 60.0},             # 低沉蜂鸣：基频从 ~45 Hz 提到 ~90 Hz，仍然低沉但小音箱能放出
    "core_pulse": {"hp": 60.0},
    "blast_detonate": {"hp": 50.0, "lp": 9000.0},
    "boss_death": {"hp": 40.0},
    "soul_spend": {"hp": 150.0},
    "attack_fizzle": {"hp": 150.0},
    "shrine_cleanse": {"pitch": 0.8, "lp": 6500.0},
    "heal": {"lp": 7000.0},
    "unit_summon": {"lp": 7000.0},
    "relic_pick": {"lp": 5000.0},
    "relic_place": {"lp": 6000.0},
    "deploy_clear": {"lp": 4000.0},
    "attack_binder": {"lp": 5000.0},
    "hit_bone": {"lp": 6000.0},
    "logo_decode": {"lp": 5000.0},
}
TWEAK.update({                                              # 复测后第二轮：超低频仍多的再提高高通，仍偏嘶的再压
    "attack_lancer": {"sub_cut": 150.0, "lp": 5000.0},
    "rule_remove": {"sub_cut": 120.0}, "boss_death": {"sub_cut": 100.0}, "blast_detonate": {"sub_cut": 60.0},
    "status_vulnerable": {"pitch": 2.6, "sub_cut": 110.0},
    "death_core": {"post_lp": 4000.0}, "status_paralysis": {"lp": 4500.0, "pitch": 0.85},
    "unlock_shake": {"lp": 4500.0}, "unlock_reveal": {"pitch": 0.6, "lp": 6000.0},
})
for _sid, _extra in TWEAK.items():
    SPEC[_sid] = (SPEC[_sid][0], dict(SPEC[_sid][1], **_extra))
SPEC.update({
    # 锁碎裂：只留水晶吊灯碎裂的清脆部分（1 s）+ 一记轻的金属断裂；去掉玻璃砸碎那层嘈杂的碎渣，低通压掉嘶嘶声
    "unlock_open": (fs(541601, "matt_ratz", "Shattering Chandelier"),
                    {"dur": 1.0, "fade": 0.5, "lp": 7000.0,
                     "layer": [(k("impact-sounds/Audio/impactMetal_heavy_002.ogg"), 0.0, 0.5, {"lp": 5000.0})]}),
    "text_blip": tap(1.7, -30.0, 2800.0, 0.05),                # 打字音改用按钮同一块木头，去掉打字机的沙沙声
    "blast_warn_tick": (k("interface-sounds/Audio/tick_001.ogg"), {"lp": 6000.0}),
    # 一版直接沿用的项目文件，补回原始 Kenney 素材以便统一响度
    "attack_bulwark": (k("impact-sounds/Audio/impactPunch_heavy_000.ogg"), {"lp": 6000.0, "sub_cut": 170.0}),
    "enemy_brute": (k("impact-sounds/Audio/impactPlate_heavy_000.ogg"), {"lp": 5000.0, "sub_cut": 100.0}),
    "structure_hit": (k("impact-sounds/Audio/impactMining_000.ogg"), {"lp": 6000.0, "dur": 0.6, "fade": 0.25}),
})

# 听感响度分层（A 计权有效段 RMS，dBFS）。层与层之间约 3–4 dB：常用按钮最轻，大事件最响但只比按钮响约 9 dB
_TIERS = {
    -40.0: ["ui_hover", "drag_snap", "ui_value_tick", "text_blip", "result_count"],
    -38.0: ["status_expire"],
    -34.0: ["ui_click", "ui_toggle", "ui_select", "ui_back", "ui_panel_close", "unit_select_ally", "unit_select_enemy",
            "game_pause", "game_unpause", "ui_drag_pick", "ui_drag_drop", "drag_cancel", "relic_arm", "relic_disarm",
            "ui_skip", "dialogue_advance", "hint_open", "locked_click", "logo_decode"],
    -32.0: ["attack_swift", "attack_striker", "attack_lancer", "attack_bulwark", "attack_binder", "priest_whisper",
            "enemy_bite", "enemy_brute", "witch_attack", "hit_flesh", "hit_bone", "structure_hit", "blast_warn_tick",
            "retreat_swish", "attack_fizzle", "blast_land", "logo_ring", "logo_string", "logo_out"],
    -31.0: ["ui_error", "budget_over", "ui_confirm_major", "node_select", "tip_card", "relic_ready", "relic_pick",
            "rule_add", "rule_remove", "beacon_place", "beacon_remove", "deploy_place", "deploy_remove", "deploy_clear",
            "formation_apply", "relic_place", "soul_spend", "soul_refund", "timer_tick", "battle_reset", "unlock_shake",
            "status_vulnerable", "status_paralysis", "status_slow"],
    -30.0: ["death_enemy", "spitter_charge"],
    -29.0: ["hit_heavy", "heal", "shrine_cleanse", "death_ally", "death_priest", "structure_destroyed", "core_pulse",
            "protect_alert", "unlock_reveal"],
    -28.0: ["death_core", "unit_summon", "objective_clear", "battle_resume", "result_record", "tutorial_done"],
    -27.0: ["boss_warn", "logo_heart"],
    -26.0: ["blast_detonate", "result_stamp", "boss_scream"],
    -25.0: ["unlock_open"],
    -24.0: ["battle_start", "boss_phase", "boss_death"],
}
LOUD = {sid: lu for lu, ids in _TIERS.items() for sid in ids}
LOUD_FOOTSTEP = -38.0

# 区域 -> 音效库 v1 脚步文件夹；每个区域输出 footstep_<区域>_1..3
FOOTSTEPS = {
    "bone_workshop": "16_脚步声/01_工坊内部",
    "withered_farm": "16_脚步声/02_农田",
    "grey_thorn": "16_脚步声/03_森林",
    "holy_bell": "16_脚步声/04_城市废墟",
    "flesh_swamp": "16_脚步声/05_沼泽",
    "warped_corridor": "16_脚步声/06_肉质地面",
    "bone_greenhouse": "16_脚步声/07_大理石",
}


def load(path):
    data, rate = sf.read(path, always_2d=True, dtype="float32")
    data = data.mean(axis=1) if data.shape[1] > 1 else data[:, 0]   # 统一单声道（SFX 不做立体声定位）
    if rate != RATE:
        n = int(round(len(data) * RATE / rate))
        data = np.interp(np.linspace(0, len(data) - 1, n), np.arange(len(data)), data).astype("float32")
    return data


def trim_head(x, thresh_db=-45.0):
    thr = 10 ** (thresh_db / 20) * max(np.abs(x).max(), 1e-9)
    idx = np.argmax(np.abs(x) > thr)
    start = max(0, idx - int(0.004 * RATE))
    return x[start:]


def shape(x, pitch=1.0, lp=0.0, hp=0.0):
    """pitch：重采样变调（<1 更低更慢）；lp：二阶低通截止频率（Hz），把常用按钮压成低频、不刺耳；
    hp：高通，切掉素材里小音箱放不出的超低频轰鸣"""
    if pitch != 1.0:
        x = np.interp(np.arange(0, len(x) - 1, pitch), np.arange(len(x)), x).astype("float32")
    if lp > 0:
        sos = butter(2, lp, btype="low", fs=RATE, output="sos")
        x = sosfilt(sos, x).astype("float32")
    if hp > 0:
        sos = butter(2, hp, btype="high", fs=RATE, output="sos")
        x = sosfilt(sos, x).astype("float32")
    return x


def process(src, opts):
    x = shape(trim_head(load(src[1])), opts.get("pitch", 1.0), opts.get("lp", 0.0), opts.get("hp", 0.0))
    for layer in opts.get("layer", []):
        lsrc, off, gain = layer[:3]
        lo = layer[3] if len(layer) > 3 else {}
        y = shape(trim_head(load(lsrc[1])), lo.get("pitch", 1.0), lo.get("lp", 0.0), lo.get("hp", 0.0)) * gain
        o = int(off * RATE)
        n = max(len(x), o + len(y))
        z = np.zeros(n, dtype="float32")
        z[:len(x)] += x
        z[o:o + len(y)] += y
        x = z
    if "dur" in opts:
        x = x[:int(opts["dur"] * RATE)]
    fade = int(opts.get("fade", 0.01) * RATE)
    if fade and len(x) > fade:
        x[-fade:] *= np.linspace(1.0, 0.0, fade, dtype="float32")
    head = int(0.003 * RATE)
    x[:head] *= np.linspace(0.0, 1.0, head, dtype="float32")
    x = sosfilt(butter(2, opts.get("sub_cut", SUB_CUT_HZ), btype="high", fs=RATE, output="sos"), x).astype("float32")
    if opts.get("post_lp", 0.0) > 0:         # 叠层之后整体低通（叠进来的层也去嘶声）
        x = sosfilt(butter(2, opts["post_lp"], btype="low", fs=RATE, output="sos"), x).astype("float32")
    peak = max(np.abs(x).max(), 1e-9)
    if "lu" not in opts:
        return x * (10 ** (opts.get("db", -8.0) / 20) / peak)
    # 按听感响度（A 计权有效段 RMS）对齐到所属层级；瞬态尖峰超过 PEAK_CEIL 时用 tanh 软限幅圆滑压住，而不是整体调小
    ceil = 10 ** (PEAK_CEIL / 20)
    y = x * 10 ** ((opts["lu"] - loudness(x)) / 20)
    if np.abs(y).max() > ceil:
        y = (ceil * np.tanh(y / ceil)).astype("float32")
    return y


SUB_CUT_HZ = 45.0       ## 所有音效都切掉 45 Hz 以下：小音箱放不出，耳机里只剩轰鸣，还白占峰值
PEAK_CEIL = -1.0


def _a_weight_sos():
    f1, f2, f3, f4 = 20.598997, 107.65265, 737.86223, 12194.217
    z = [0.0, 0.0, 0.0, 0.0]
    p = [-2 * np.pi * f4, -2 * np.pi * f4, -2 * np.pi * f1, -2 * np.pi * f1, -2 * np.pi * f3, -2 * np.pi * f2]
    k = (2 * np.pi * f4) ** 2 * 10 ** (1.9997 / 20)
    zd, pd, kd = bilinear_zpk(z, p, k, RATE)
    return zpk2sos(zd, pd, kd)


A_SOS = _a_weight_sos()


def loudness(x):
    """听感响度（dBFS）：A 计权后按 20 ms 分帧，取离最响帧 20 dB 以内的帧求平均功率（短音效不被尾巴稀释）"""
    y = sosfilt(A_SOS, x)
    n = int(0.02 * RATE)
    frames = [float(np.mean(y[i:i + n] ** 2)) for i in range(0, max(len(y) - n, 1), n)] or [float(np.mean(y ** 2))]
    e = np.array(frames) + 1e-20
    act = e[e > e.max() * 0.01]
    return 10 * np.log10(act.mean())


def backup_existing(directory, sid, keep_ext):
    for ext in (".ogg", ".wav", ".mp3"):
        p = os.path.join(directory, sid + ext)
        if os.path.exists(p):
            os.makedirs(BACKUP, exist_ok=True)
            dst = os.path.join(BACKUP, sid + ext)
            if not os.path.exists(dst):
                shutil.copy2(p, dst)
            if ext != keep_ext:
                os.remove(p)
                imp = p + ".import"
                if os.path.exists(imp):
                    os.remove(imp)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    for d in (FS_STORE, BACKUP):        # 留档目录不进 Godot 导入
        os.makedirs(d, exist_ok=True)
        open(os.path.join(d, ".gdignore"), "a").close()
    jobs = dict(SPEC)
    for region, folder in FOOTSTEPS.items():
        files = sorted(f for f in os.listdir(os.path.join(LIB, folder)) if f.endswith(".mp3"))
        for i, f in enumerate(files[:3]):
            jobs["footstep_%s_%d" % (region, i + 1)] = (v1(folder + "/" + f), {"lu": LOUD_FOOTSTEP, "lp": 6000.0, "sub_cut": 110.0, "dur": 0.45, "fade": 0.12})
    rows = []
    for sid, (src, opts) in jobs.items():
        is_bgm = opts.get("bgm", False)
        out_dir = BGM if is_bgm else SFX
        ext = ".mp3" if is_bgm else ".ogg"     # AudioManager 的短曲只认 bgm/<name>.mp3
        backup_existing(out_dir, sid, ext)
        if sid in LOUD:
            opts = dict(opts, lu=LOUD[sid])
        y = process(src, opts)
        out = os.path.join(out_dir, sid + ext)
        if is_bgm:
            sf.write(out, y, RATE, format="MP3")
        else:
            sf.write(out, y, RATE, format="OGG", subtype="VORBIS")
        for s in [src] + [l[0] for l in opts.get("layer", [])]:
            if s[0] == "fs":
                shutil.copy2(s[1], os.path.join(FS_STORE, os.path.basename(s[1])))
        rows.append([sid, os.path.relpath(out, ROOT).replace("\\", "/"), "%.2f" % (len(y) / RATE),
                     " + ".join([src[2]] + [l[0][2] for l in opts.get("layer", [])]), "CC0"])
        print("%-28s %5.2fs  %s" % (sid, len(y) / RATE, src[2]))
    with open(os.path.join(KENNEY, "source_manifest_v2.csv"), "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["id", "output", "seconds", "source", "license"])
        w.writerows(rows)
    print("total", len(rows))


if __name__ == "__main__":
    main()
