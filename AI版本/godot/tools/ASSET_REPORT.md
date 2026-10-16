# 资源生产报告

## 第一阶段：验证管线

- 状态：通过（2026-10-04，棋盘精灵确认为 Q 版）。
- 验证图：`assets/sprites/units/striker.png`（256×256 RGBA）。棋盘格预览：`tools/_raw/units/striker_v6_checker_preview.png`。
- 选用原图：`tools/_raw/units/striker_v6.png`（1254×1254，内置 image_gen 直接生成透明背景）。原图 alpha 范围 0–255；有效主体框（alpha > 8）为 `(266, 18)–(997, 1240)`，左上角 alpha 为 0。
- Q 版检查：头部和眼睛明显放大，躯干紧凑、四肢短，整体约 2.5 头身；256 像素预览仍能辨认全身、双脚、短灰白发、灰玻璃眼、瓷裂纹、暗红破袍及右前臂恰好三根骨刺。
- 风格检查：日系 2D 线稿、深色清晰轮廓和硬边赛璐璐明暗色块；未见写实比例、品红边缘或背景残色。少量材质内阴影仍有柔和过渡，但缩小后主体色块和轮廓清楚。
- 透明度与排版：最终画布 alpha 范围 0–255，角落 alpha 为 0；主体缩放至 139×232，放置坐标 `(58, 0)`，水平居中，底部保留 24 px。使用原生 alpha 裁切，并以预乘 alpha 的 LANCZOS 缩放避免透明 RGB 渗色；棋盘格预览未见绿色或品红污染。
- 管线备注：已运行 `python tools/cutout.py --id striker --kind units --variant 6`。该脚本当前仍对所有输入强制应用品红键及半透明边缘颜色调整，会污染直接生成的透明图；因此正式输出按脚本相同的主体裁切、232 px 高度上限、水平居中和 24 px 底边留白规则，改为保留原生 alpha 处理。脚本、清单均未修改。运行时 `rembg` 不可用；直接 alpha 流程不依赖它。
- 候选记录：v4、v5 未采用；v6 通过。旧正常头身 `striker` 候选按任务包标记作废并保留在 `tools/_raw/units/`。内置 image_gen 共调用 3 次（两次生成、一次编辑）；PackyAPI 调用 0 次。
- `art_manifest.json` 和两个生产脚本均未改动。本阶段使用原生透明背景和下列风格/主体提示，未进入批量生成。

> Q-version full-body dark-fantasy game sprite on true transparent alpha. A pale porcelain doll girl, super-deformed about 2.5 heads tall: nearly half-height head, oversized simple grey glass eyes without pupils, tiny torso, short stubby legs, centered full body with both feet visible. Short ash-white bob, a few porcelain cracks, stitched neck and wrists, dark crimson ragged robe. Exactly three distinct curved ivory bone spikes grow from her anatomical right forearm. Clean hand-drawn Japanese 2D anime cel art, bold dark ink outlines, simple closed shapes, broad flat color regions, crisp hard-edged shadows with one darker shade per material; readable at 256 pixels. Restrained ash-white, ivory, steel-grey, wine-red and charcoal palette. No realistic/adult proportions, painterly rendering, airbrush, gradients, glossy 3D lighting, noise, extra limbs or weapons, text, watermark, colored/solid/checkerboard background, halo, glow, or floor shadow.

## 第二阶段：图像素材

- 已交付 53 张图像：棋盘单位 15（含第一阶段已通过的 striker）、正常头身立绘 6、头像 15（11 张生成 + 4 张由立绘裁切）、背景 8、场景道具 7、UI 主视觉 2。
- 本阶段生成 48 张新图并重生成 10 次；不含第一阶段。重生成分布：witch 1 次；raider、brute、warden 各 2 次；背景 2 次；章节地图 1 次。没有未解决的视觉缺陷。
- 使用原生透明背景生成棋盘单位、立绘和道具；对这些图保留生成 alpha，避免品红键造成边缘污染。已逐组查看缩略总览。角色轮廓和阴影按低频大形控制；地图、背景与 UI 不再加入密集装饰纹理。
- 图像风格提示变化：

| 原提示方向 | 批量生成收紧后的方向 |
|---|---|
| `painterly oil texture`、`subtle painterly shading`、`high detail`、服装细节密集 | 日系手绘线稿与赛璐璐平涂；大块封闭色面；每种材质只留少量明确阴影；缩至目标尺寸仍清晰 |
| 泛化的 `detailed costume`、骨骼/布料纹理可自由延展 | 保留角色识别点和大形；减少碎布、缝线、蕾丝、链条及零散骨片，不以微小装饰填满表面 |
| 未排除颗粒化表面细节 | 明确排除 grain/noise、stipple、hatching、scratches、woven texture、lace、filigree、micro-stitches、scattered specks 和 dense clutter；保留平滑底色与宽阔色块 |

- 背景的 level_01、level_03 和章节地图各保留 v1/v2 候选；采用较清楚的 v2。魔女立绘 v1 保留作比较，当前版本简化了骨偶、衣料花边与细碎装饰。
- 视觉 QA 联系表：`tools/_raw/units/units_contact.png`、`tools/_raw/illustrations/illustrations_contact.png`、`tools/_raw/portraits/portraits_contact.png`、`tools/_raw/backgrounds/backgrounds_contact.png`、`tools/_raw/props/props_contact.png`、`tools/_raw/procedural_contact.png`。

## 第三阶段：音乐

- 首轮（Python）：本地缺少 `requests`；改用标准库适配器后在 TLS 握手处以 `[SSL: UNEXPECTED_EOF_WHILE_READING]` 失败，无任务号。
- 补做（2026-10-04，PowerShell `Invoke-RestMethod`，TLS 正常）：7 段全部生成，纯器乐（`instrumental: true`，`custom_mode: false`），提示与 tags 取自 `music_manifest.json`。服务端已不接受 `chirp-fenix`（返回“mv 不支持，可选：v6 / v6-wild / v6-mini”），改用 `v6`；清单与 `gen_music.py` 默认值已同步改为 `v6`。
- 每次提交返回 2 个候选，共 14 个，全部 `success`，保存在 `tools/_raw/music/`（`<id>_a/b.mp3`，已加 `.gdignore`）；任务查询原始响应：`suno_tasks_bgm.json`、`suno_tasks_stings.json`。
- **未试听。** 选用依据仅为客观指标（soundfile 解码）：时长、首尾静音（-40 dB 门限）、首/尾 2 秒 RMS 是否接近（循环接缝）。是否真无人声、风格是否贴合、循环是否顺滑需人工试听确认。

| 输出 | 采用任务号 | 实际时长 | 备选任务号（时长） | 备注 |
|---|---|---:|---|---|
| `menu_theme.mp3` | 2106734891176562688 | 119.96 s | …562689（119.60 s） | 首尾静音 ≤0.6 s；备选末尾 2.4 s 静音并淡出 |
| `battle_01.mp3` | 2106734900143984640 | 89.81 s | …984641（88.56 s） | **两个候选均略短于 90 s**；首 1.2 s、尾 2.0 s 近静音且末尾淡出，循环处会有约 3 s 空隙 |
| `battle_02.mp3` | 2106734908817805312 | 193.21 s | …805313（24.76 s，过短） | 开头渐入（首 2 s 约 -37 dB，尾 2 s 约 -17 dB），接缝响度跳变较大 |
| `battle_03.mp3` | 2106734918783471617 | 170.01 s | …471616（149.96 s） | 首/尾 2 s 响度几乎相同（-33.6 / -34.2 dB） |
| `boss_01.mp3` | 2106734935095119872 | 214.93 s | …119873（223.20 s） | 首尾无静音 |
| `sting_victory.mp3` | 2106735427959394304 | 7.97 s | …394305（8.61 s） | 末尾淡至近静音；整体较轻（RMS -27 dB，峰值 -11 dBFS） |
| `sting_defeat.mp3` | 2106735454358343680 | 7.97 s | …343681（7.21 s） | 峰值 -6.9 dBFS |

- 首轮 5 段 BGM 提交后，两段 sting 因并发上限（“尚有 10 个未完成的任务”，HTTP 429 / “请勿频繁操作”）被拒，待 BGM 完成后再提交成功。

## 第四阶段：字体与音效原料

- 初始资源包曾将同一份可变 Cinzel 字体分别命名为 Regular / Bold；评审修正后由 `Cinzel-Bold.tres` 基于 `Cinzel-Regular.ttf` 设置 `wght=700`，`blast_marker.gd` 已改用该资源。
- 许可证在 `assets/fonts/licenses/OFL-NotoCJK.txt` 与 `assets/fonts/licenses/OFL-Cinzel.txt`；原下载副本仍在 `assets/fonts/`。
- Unifont 是 `tools/gen_alchemy_phrase.py` 的离线字形生成字体，不供游戏运行时使用；评审修正后字体与许可证移到 `tools/assets/fonts/`，生成器默认路径已同步。
- Kenney 音效原料保存在 `tools/_raw/sfx/`：Impact Sounds 130 个、UI Audio 52 个、RPG Audio 52 个、Interface Sounds 100 个，共 334 个音频文件；四包均为 CC0。来源：[Impact Sounds](https://kenney.nl/assets/impact-sounds)、[UI Audio](https://kenney.nl/assets/ui-audio)、[RPG Audio](https://kenney.nl/assets/rpg-audio)、[Interface Sounds](https://kenney.nl/assets/interface-sounds)。
- 最终提供 33 条 SFX。17 条选自 Kenney，来源及处理如下：

| 输出 | 音源（包 / 文件） | 处理 |
|---|---|---|
| `ui_click.ogg` | Interface Sounds / `click_001.ogg` | 衰减，峰值 -8.16 dBFS |
| `ui_hover.ogg` | UI Audio / `rollover1.ogg` | 衰减，峰值 -8.04 dBFS |
| `ui_toggle.ogg` | Interface Sounds / `toggle_001.ogg` | 衰减，峰值 -7.92 dBFS |
| `ui_error.ogg` | Interface Sounds / `error_001.ogg` | 衰减，峰值 -7.67 dBFS |
| `ui_drag_pick.ogg` | Interface Sounds / `select_001.ogg` | 衰减，峰值 -8.27 dBFS |
| `ui_drag_drop.ogg` | Interface Sounds / `drop_001.ogg` | 衰减，峰值 -8.15 dBFS |
| `deploy_place.ogg` | Impact Sounds / `impactWood_heavy_000.ogg` | 衰减，峰值 -7.92 dBFS |
| `battle_start.ogg` | Impact Sounds / `impactBell_heavy_000.ogg` | 衰减，峰值 -7.88 dBFS |
| `attack_bulwark.ogg` | Impact Sounds / `impactPunch_heavy_000.ogg` | 衰减，峰值 -7.97 dBFS |
| `enemy_brute.ogg` | Impact Sounds / `impactPlate_heavy_000.ogg` | 衰减，峰值 -8.09 dBFS |
| `hit_flesh.ogg` | Impact Sounds / `impactSoft_medium_000.ogg` | 衰减，峰值 -7.94 dBFS |
| `hit_bone.ogg` | Impact Sounds / `impactGlass_medium_000.ogg` | 衰减，峰值 -7.97 dBFS |
| `structure_hit.ogg` | Impact Sounds / `impactMining_000.ogg` | 衰减，峰值 -7.82 dBFS |
| `blast_warn_tick.ogg` | Interface Sounds / `tick_001.ogg` | 衰减，峰值 -8.63 dBFS |
| `timer_tick.ogg` | Interface Sounds / `tick_002.ogg` | 衰减，峰值 -8.09 dBFS |
| `hint_open.ogg` | RPG Audio / `bookOpen.ogg` | 原样复制，峰值 -11.54 dBFS |
| `dialogue_advance.ogg` | RPG Audio / `bookFlip1.ogg` | 衰减，峰值 -8.00 dBFS |

- 其他 16 条为合成占位：`deploy_remove`、`attack_striker`、`attack_swift`、`attack_lancer`、`enemy_bite`、`spitter_charge`、`core_pulse`、`priest_whisper`、`blast_detonate`、`death_ally`、`death_enemy`、`death_priest`、`death_core`、`structure_destroyed`、`amb_wind`、`amb_greenhouse`。两个环境底噪分别为 25 秒和 30 秒，可循环。输出是 44.1 kHz、16-bit WAV，峰值低于 -6 dBFS。
- Kenney OGG 用 soundfile 解码取样峰值；超过 -6 dBFS 的文件经 numpy 衰减并重编码，再解码复核。峰值清单在 `tools/_raw/sfx/source_manifest.csv`。任务正文表格实际列出 33 个 ID，进度行写 32 条；本次按表格完成 33 条。

## 第五阶段：程序化素材

- `tools/make_procedural.py` 已运行：输出 36 张 RGBA PNG（5 projectile、11 VFX、20 UI）和 43 个 SVG 图标。PNG 尺寸按任务表生成；检查透明通道及 SVG XML 后均通过。
- `tools/make_sfx.py` 为找不到合适素材的条目提供可重现的 numpy 合成器；默认只生成无来源的 16 条 WAV，避免覆盖 17 条 Kenney 素材。
- 程序化贴图采用平滑渐层、简洁线框与宽阔纯色块；未使用颗粒、点描、排线或碎屑纹理。

## 调用与未完成项

- 图像生成：内置 image_gen 共 61 次（第一阶段 3 次、第二阶段 58 次）；PackyAPI 0 次。第二阶段 58 次包括 48 次首次生成与 10 次重生成，未超过 120 次预算。
- 音乐 API：首轮 1 次 TLS 失败。补做：账户查询 1 次；生成提交 16 次（7 次因 mv 失效被拒、2 次因并发上限被拒、7 次成功，共 14 个候选）；任务查询 2 次（各带 `wait=45`）。
- 未完成项：无缺失文件。音乐 7 段已交付但未经试听；`battle_01` 时长 89.81 s，略低于 90 s 要求。

## 评审修正（2026-10-04）

详见 [`ASSET_FIX_REPORT.md`](ASSET_FIX_REPORT.md)。除 `dialogue_advance.ogg` 开头 74ms 静音因当前环境无 OGG/Vorbis 解码器而未裁剪外，评审中可在本地直接修正的资源已更新。BGM 不在评审范围内。
