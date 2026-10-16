# 《人工神灵》Demo 资源生产任务包

交付对象：负责资源生产的 AI（在本机运行、可执行命令）。本任务包自成一体，但 prompt 细节与规格表以仓库内文件为权威。
工作目录：`G:\人工神明-侧面开发\AI版本\godot\`（下文所有命令都在此目录执行；2026-10-05 换机后更新，原机为 `H:\其他\人工神灵\godot\`）。
你**不负责**任何 Godot 代码、场景、着色器；只负责把资源文件按规格放进 `assets/` 下指定位置。

> **本文的地位（2026-10-05 修订）**：这是第一阶段的资源生产手册，§0 环境表与 §1 规则是资源线的**总规则**，后续每个阶段的资源任务包（`第二阶段_资源任务包.md`、`第三阶段_资源任务包.md`）都只写增量并声明"规则沿用本文 §1"。§2–§6 是第一阶段的具体生产步骤，已全部完成（见 §8），只作流程参考。实际工具链与本文最初设想的差异见 §0.1，以 §0.1 为准。后续阶段索引见 §9。

---

## 0. 环境

| 项目 | 说明 |
|---|---|
| Python | 本机已装 PIL、numpy、requests；**rembg 未安装**（原生透明背景流程不需要它，见 §0.1）。所有脚本 UTF-8；PowerShell 先执行 `chcp 65001` |
| 绘图 | **实际使用：资源 AI 自带的原生图像生成工具（内置 image_gen，支持原生透明背景）**，见 §0.1。备用：`tools/gen_image.py` 调 PackyAPI gpt-image-2，Key 在环境变量 `PACKY_API_KEY` 或 `%USERPROFILE%\.claude\skills\packy-image\config.json`（本机 `C:\Users\1\`；**两者目前都未配置**，需用时先设置）。脚本会自动读取，**不要把 key 写进任何文件或输出** |
| 音乐 | Suno.cn（第一阶段已用它交付 7 段）。`tools/gen_music.py`，Key 在环境变量 `SUNO_CN_API_KEY` 或 `%USERPROFILE%\.claude\skills\suno-cn-music\config.json`（本机未配置） |
| 无 ffmpeg | 音乐直接用 mp3；音效用 wav 或 ogg 原文件 |
| 规格文档 | `../docs/04_资源需求.md`（完整清单与尺寸）；本文已把你要执行的部分摘录进来 |
| 脚本 | `tools/gen_image.py`、`tools/cutout.py`、`tools/gen_music.py`、清单 `tools/art_manifest.json`、`tools/music_manifest.json` |

### 0.1 工具链现状（2026-10-05，依据 `tools/ASSET_REPORT.md`、`ASSET_FIX_REPORT.md`、`ASSET_REPORT_P2.md`）

前两个阶段的实际做法与本文最初设想不同，以实际做法为准：

| 环节 | 本文最初设想 | 实际做法（沿用） |
|---|---|---|
| 生成 | `gen_image.py` → PackyAPI gpt-image-2，品红背景 | 资源 AI 内置 image_gen，**原生透明背景**；PackyAPI 两阶段累计 0 次调用。`art_manifest.json` 仍是 prompt 与规格的权威清单，生成时读它的 prompt；第三阶段 R0 已将透明素材风格后缀改为原生透明背景 |
| 透明素材规格化 | `cutout.py` 品红色键 → rembg 精修 | 保留原生 alpha，按 `cutout.py` 同样的裁边 / 232 px 高度上限 / 水平居中 / 底部 24 px 留白规则处理。**第三阶段 R0 已给 `cutout.py` 加 `--native-alpha`**；处理原生透明素材时必须传此选项，跳过品红键与 rembg |
| 背景 / UI 大图 | `cutout.py` 缩放裁切 | 可用（无抠图步骤），或自写脚本 Lanczos 规范导出 |
| 原图与中间文件 | `tools/_raw/<kind>/` | 同；第二阶段起按阶段分目录 `tools/_raw/p2/`、`tools/_raw/p3/`，仍不入库 |
| 校验 | 肉眼 + `cutout.py` 告警 | 肉眼 + 每阶段自写 `verify.py`（尺寸、亮度、接缝、alpha、SHA256 清单），结果附报告 |

## 1. 规则

1. 只写入 `assets/` 与 `tools/_raw/`（原图、下载包等中间文件）。不改动 `data/`、`scripts/`、`project.godot`、任何 `.md`（除本文末尾的进度表与 `tools/ASSET_REPORT.md`）。
2. 不改 `art_manifest.json` 的 `id`、`kind`、输出目录；可以微调 `prompt` 以修正生成问题，改了就在报告里记一行。
3. API 调用失败：原样记录 HTTP 状态码与响应体前 500 字符，**不重试超过 2 次、不编造结果、不用其他来源替代**。
4. 不使用任何现有游戏截图、来源不明的图片或音频。字体只用 SIL OFL 许可；音效只用 Kenney CC0 或自行合成。
5. 每张 AI 图生成后必须用肉眼（读图）检查一次再进入下一步；不要盲跑 `--all` 后直接宣布完成。
6. 不要把 base64 或图片 URL 打印到终端。

## 2. 第一阶段：验证管线（只花一张图）

```bash
# 使用内置 image_gen，读取 striker prompt，要求原生透明背景
# 原图保存为 tools/_raw/units/striker.png；不调用 API
```
```bash
python tools/cutout.py --id striker --kind units --native-alpha --native-alpha --native-alpha --native-alpha
```

检查 `assets/sprites/units/striker.png`：
- **必须是 Q 版（chibi）**：约 2.5 头身、大头大眼、小身体、清晰描边。正常头身的全身像不合格（之前生成的三张 striker 原图均为正常头身，已作废，请用 `--variant 4` 起继续编号或先删除 `tools/_raw/units/striker*.png`）；
- 背景为真实 alpha 透明，边缘无实色背景或白边；
- 角色脚底贴在画布底部约 24 px 处，整体居中；
- 外形符合"苍白瓷质人偶少女、短灰白发、灰玻璃眼、右前臂三根骨刺、暗红破袍"。

> 2026-10-04 需求更新：棋盘精灵改为 Q 版；新增"立绘"组（正常头身，6 张）；四个己方形态的头像改为从立绘自动裁切；UI 组去掉两张对白立绘。`art_manifest.json` 与两个脚本已同步更新。

若 `cutout.py --native-alpha` 报缺少 alpha、完全不透明或空图，使用内置 image_gen 重新生成原生透明图，下一候选以 `_v2` 命名，处理加 `--variant 2`。原生 alpha 路径不走色键、不调用 rembg，不使用旧8%–85%占比限制；连续3次失败停下，记录原图路径等待人工决定。
验证通过后，把 `striker.png` 的路径写入报告"验证图"一栏，再进入第二阶段。

## 3. 第二阶段：AI 图像批量生成（49 项）

逐项使用内置 image_gen，读取清单 prompt 与风格后缀，透明资源要求原生 alpha。下表顺序沿用第一阶段，命令列仅是旧 API 工具索引，不是现行生成方式；不要调用 gen_image.py。

| 顺序 | 命令 | 数量 | 检查要点 |
|---|---|---|---|
| 1 | `python tools/gen_image.py --group units --skip-existing` | 15 | 全部 **Q 版**。四个己方形态 `striker/bulwark/swift/lancer` 必须像同一个人偶（发型、脸、眼睛、袍色一致）。若不像，对不像的那个再跑 `--variant 2`、`--variant 3`，从候选里挑最一致的一套。敌人也是 Q 版，但要保留阴森感 |
| 2 | `python tools/gen_image.py --group illustrations --skip-existing` | 6 | **正常头身**全身立绘：`doll`（本体）、四形态、`witch`。四形态与 `doll` 必须是同一张脸、同一发型；与 Q 版精灵也要能认出是同一角色 |
| 3 | `python tools/gen_image.py --group portraits --skip-existing` | 11 | 只生成敌人与建筑的胸像（四个己方形态的头像由脚本从立绘裁切，不调用 API）；面部完整 |
| 4 | `python tools/gen_image.py --group backgrounds --skip-existing` | 8 | 画面里**不能有角色或生物**；`level_03` 的墙必须横贯画面下三分之一；`level_08` 上下各一道荆棘墙；整体亮度均匀，能叠网格 |
| 5 | `python tools/gen_image.py --group props --skip-existing` | 7 | 单个物体、原生透明背景；`wall_mid`、`thorn_mid` 左右边缘应能衔接 |
| 6 | `python tools/gen_image.py --group ui --skip-existing` | 2 | `key_art_menu` 左侧三分之一必须是留白暗部；`chapter_map_plain` 无任何文字 |

每组生成并检查后立刻处理（**先处理 illustrations，再处理 portraits**，因为四个头像要从立绘裁切）：

```bash
python tools/cutout.py --group units --native-alpha --native-alpha --native-alpha --native-alpha
```
（`illustrations` 与 `props` 同理，必须加 `--native-alpha`；`portraits` 和不透明背景/UI大图不抠图；透明 UI 控件prompt需含transparent并加此参数。）

选用非第一候选时：`python tools/cutout.py --id swift --kind units --variant 2 --native-alpha --native-alpha --native-alpha --native-alpha`。

处理后再检查输出：
- `assets/sprites/units/*.png` 与 `assets/sprites/props/*.png`：256×256，透明，无色晕；
- `assets/sprites/illustrations/*.png`：768×1152，透明，脚底贴底；
- `assets/sprites/portraits/*.png`：512×512；四个己方头像应是立绘的头部特写铺在深紫底上，若裁切位置偏了（例如只裁到头发），报告中记录并等待人工调整裁切参数；
- `assets/backgrounds/level_0X.png`：1536×1024；
- `assets/sprites/ui/key_art_menu.png`、`chapter_map_plain.png`：1920×1080。

重生成预算：背景与角色各预留三成额度；总调用超过 120 次时停下报告。

## 4. 第三阶段：音乐（7 段）

```bash
python tools/gen_music.py --all --skip-existing
```

- 每段提交后脚本会等待并下载到 `assets/audio/bgm/<id>.mp3`；通常会多下载一个 `<id>_alt1.mp3` 候选。
- 逐段试听（读取时长与文件大小即可，无法试听时记录"未试听"），保留一个，删除候选。要求：纯器乐；`sting_*` 时长 5 到 15 秒；其余 90 秒以上。
- 若脚本因等待超时退出，任务号已存在 `tools/_raw/music_tasks.json`，稍后用 `python tools/gen_music.py --status <任务号>` 续取。

## 5. 第四阶段：下载类资源

**字体**（放入 `assets/fonts/`，文件名必须与下表一致）

| 目标文件名 | 来源 |
|---|---|
| NotoSerifSC-Regular.otf、NotoSerifSC-Bold.otf | https://github.com/notofonts/noto-cjk → `Serif/OTF/SimplifiedChinese/NotoSerifCJKsc-Regular.otf` 与 `-Bold.otf`，下载后重命名 |
| NotoSansSC-Regular.otf | 同仓库 `Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf`，重命名 |
| Cinzel-Regular.ttf、Cinzel-Bold.ttf | https://github.com/google/fonts/tree/main/ofl/cinzel（若只有可变字体 `Cinzel[wght].ttf`，直接复制两份并按上述命名） |

把每个字体的 LICENSE/OFL.txt 一并放入 `assets/fonts/licenses/`。

**音效原料**（解压到 `tools/_raw/sfx/`，不要直接放进 assets）

从 https://kenney.nl/assets 下载 CC0 包：Impact Sounds、UI Audio、RPG Audio、Interface Sounds。然后按下表挑选、重命名并复制到 `assets/audio/sfx/`（wav 或 ogg 均可，保持原格式后缀；音量峰值不超过 -6 dBFS 的无需处理，过响的用 numpy 读写时乘以系数衰减）。找不到合适素材的条目，用 `tools/make_sfx.py`（你来写，numpy 合成，见 §6）生成占位，并在报告中标注"合成"。

| 文件名 | 需要的声音 |
|---|---|
| ui_click / ui_hover / ui_toggle / ui_error | 骨质轻叩 / 极轻擦音 / 开合咔哒 / 低沉否定音 |
| ui_drag_pick / ui_drag_drop | 拾起 / 放下 |
| deploy_place / deploy_remove | 沉重落地 / 轻微吸气 |
| battle_start | 低沉钟鸣（可叠一次心跳） |
| attack_striker / attack_bulwark / attack_swift / attack_lancer | 弹射"咔嗖" / 厚重挥击 / 迅捷划击 / 尖锐风声 |
| enemy_bite / enemy_brute | 撕咬 / 重击 |
| spitter_charge / core_pulse / priest_whisper | 吸气蓄力 / 低频搏动 / 群体低语 |
| blast_warn_tick / blast_detonate | 滴答 / 湿润爆裂 |
| hit_flesh / hit_bone | 肉体受击 / 骨质受击 |
| death_ally / death_enemy / death_priest / death_core | 四种死亡（人偶碎裂、怪物哀鸣、低语消散、巨物崩塌） |
| structure_hit / structure_destroyed | 石质受击 / 崩塌 |
| timer_tick / hint_open / dialogue_advance | 倒计时滴答 / 翻页 / 翻页轻 |
| amb_wind / amb_greenhouse | 环境底噪两种，各 20 到 40 秒可循环 |

## 6. 第五阶段：程序化贴图与合成音效（你来写脚本）

写 `tools/make_procedural.py`（PIL），运行一次生成全部，所有输出带 alpha：

| 输出 | 尺寸 | 形状 |
|---|---|---|
| assets/sprites/projectiles/bone_shard.png | 64×24 | 骨白 `#E8DCC4` 尖锐梭形，尾部暗红 `#7A1E2B` 拖影 |
| assets/sprites/projectiles/lance_beam.png | 192×16 | 骨白长矛光束，中心更亮 |
| assets/sprites/projectiles/bone_spit.png | 48×48 | 橙红 `#FF7A3E` 黏液球，暗色核心 |
| assets/sprites/projectiles/whisper_bolt.png | 48×48 | 紫 `#B06CFF` 模糊球，外圈细环 |
| assets/sprites/projectiles/pollen_orb.png | 64×64 | 橙色花粉团，颗粒感 |
| assets/sprites/vfx/soft_circle.png | 128×128 | 高斯软圆（白） |
| assets/sprites/vfx/ring_soft.png | 256×256 | 软边环（白） |
| assets/sprites/vfx/spark.png | 32×32 | 四角星芒（白） |
| assets/sprites/vfx/bone_fragment_1/2/3.png | 24×24 | 三种不规则骨片 |
| assets/sprites/vfx/blood_drop.png | 16×24 | 暗红水滴 |
| assets/sprites/vfx/faction_base_ally.png | 160×96 | 骨白圆环底座（椭圆透视，线宽 6） |
| assets/sprites/vfx/faction_base_enemy.png | 160×96 | 暗红 `#FF4B3E` 荆棘八角底座 |
| assets/sprites/vfx/faction_base_structure.png | 176×112 | 金 `#C9A24A` 方框底座 |
| assets/sprites/vfx/shadow_blob.png | 128×64 | 黑色软椭圆 |
| assets/sprites/ui/panel_dark.png | 96×96 | 深紫黑 `#2A1430` 85% 不透明，1px 骨白边线（9 宫格边距 24） |
| assets/sprites/ui/panel_bone.png | 96×96 | 骨白羊皮纸质感（加轻微噪点），暗边 |
| assets/sprites/ui/button_normal/hover/pressed/disabled.png | 192×56 | 暗红底骨白边；hover 金边；pressed 内凹变暗；disabled 灰紫 `#4A3350` |
| assets/sprites/ui/toggle_on/off.png | 48×24 | 符文开关，on 为金色 |
| assets/sprites/ui/dropdown_bg.png | 160×40 | 暗底骨白边 |
| assets/sprites/ui/slider_track.png / slider_grabber.png | 200×8 / 20×20 | 暗槽 / 骨白圆钮 |
| assets/sprites/ui/rule_row_bg_normal/active/disabled.png | 480×56 | 普通暗底 / 左侧 6px 金色竖条 / 半透明灰 |
| assets/sprites/ui/hp_bar_ally/enemy/structure.png | 96×10 | 圆角 / 两端尖角 / 方角 的空心框，白色 |
| assets/sprites/ui/portrait_mask.png | 512×512 | 实心白圆 |
| assets/sprites/ui/cursor_default.png / cursor_drag.png | 32×32 | 骨白箭头 / 抓手 |

写 `tools/make_sfx.py`（numpy 写 wav，44.1kHz 16bit）为 §5 中未找到素材的条目合成占位音：噗（低频短脉冲）、咔（白噪短爆）、嗡（低频正弦衰减）、滴（高频正弦 60ms）等组合即可，不追求音质。

**SVG 图标**（手写，`assets/sprites/ui/icons/<name>.svg`，24×24 viewBox，纯骨白 `#E8DCC4` 线条，线宽 2，`fill="none"` 为主）：

| 组 | 名称与字形 |
|---|---|
| 属性 | stat_hp 带一道裂纹的心 ｜ stat_attack 骨刺 ｜ stat_aps 沙漏 ｜ stat_speed 三道风线 ｜ stat_vision 眼睛 ｜ stat_range 同心圆加箭头 |
| 条件 | cond_always 无限符 ｜ cond_hp_below 下半实心的心 ｜ cond_visible 睁眼 ｜ cond_in_range 靶心 ｜ cond_distance 双箭头尺 ｜ cond_retreat_possible 半开的门 |
| 选敌 | sel_nearest 向内箭头 ｜ sel_farthest 向外箭头 ｜ sel_lowest_hp 心形下方小箭头 ｜ sel_first_seen 眼睛加数字 1 |
| 行为 | act_idle 方块 ｜ act_attack 交叉骨刺 ｜ act_chase_attack 脚印加骨刺 ｜ act_chase 脚印 ｜ act_retreat 反向脚印 ｜ act_route 折线路径带点 |
| 形态 | form_striker / form_bulwark / form_swift / form_lancer 四种简化剪影（直立、宽肩、前倾、持矛） |
| 控制 | play 三角 ｜ reset 环形箭头 ｜ pause 双竖线 ｜ speed_1x 文字"1×" ｜ speed_2x 文字"2×" ｜ hint 烛火 ｜ mechanics 打开的书 ｜ exit 门 ｜ export 向下箭头到横线 |
| 状态 | state_idle "Zz" ｜ state_blocked 圆加斜线 ｜ state_out_of_range 靶心加叉 ｜ state_cooldown 沙漏 ｜ state_locked 锁 |
| 特性 | trait_blast 爆炸环 ｜ trait_flee 分叉箭头 ｜ trait_lock 眼睛加锁 |

## 7. 完成标准与报告

全部完成后写 `tools/ASSET_REPORT.md`，包含：
1. 验证图路径与结论。
2. 每个资源组：数量、重生成次数、仍不满意的条目及原因。
3. 改动过的 prompt（原文 → 新文）。
4. 音乐：每段选用的任务号、时长；未试听的标注。
5. 音效：每个文件来源（Kenney 包名/文件名，或"合成"）。
6. 字体文件列表与许可证文件位置。
7. API 调用总次数与失败记录（状态码 + 响应体摘要）。
8. 未完成项与原因。

验收由人工按 `../docs/04_资源需求.md` §4.5 五条进行：四形态同源可辨、灰度下敌我可分、1080p 无白边伪影、各类反馈资源齐备、原图保留在 `tools/_raw/`。

## 8. 进度表（你每完成一阶段勾选一次）

- [x] 第一阶段 验证图通过（2026-10-04 Q 版重做完成；验证图见 `godot/assets/sprites/units/striker.png`）
- [x] 第二阶段 units 15 / illustrations 6 / portraits 11+4 / backgrounds 8 / props 7 / ui 2 全部处理完成
- [x] 第三阶段 音乐 7 段（`assets/audio/bgm/` 7 个 mp3 已交付，见 ASSET_REPORT.md；未经人工试听，`battle_01` 89.81 s 略短于 90 s）
- [x] 第四阶段 字体 5 文件 + 许可证；Kenney 包下载；音效 32 条到位
- [x] 第五阶段 make_procedural.py 输出全部贴图；make_sfx.py；SVG 图标全部
- [x] ASSET_REPORT.md 已写

## 9. 后续阶段索引

| 阶段 | 任务包 | 交付报告 | 范围 |
|---|---|---|---|
| 第一阶段（2026-10-04） | 本文 §2–§6 | `tools/ASSET_REPORT.md`、修正批次 `tools/ASSET_FIX_REPORT.md` | 全部初始资源 |
| 第二阶段（2026-10-05） | `tasks/第二阶段_资源任务包.md` | `tools/ASSET_REPORT_P2.md` | 三个怪重画、分层背景、地面、地面标识 |
| 第三阶段（2026-10-05 起） | `tasks/第三阶段_资源任务包.md` | `tools/ASSET_REPORT_P3.md` | UI 全部重绘（设计图→切图）、章节宽图、大地图与可分离障碍、反馈小件 |
