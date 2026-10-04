# 人工神灵

实时战术**解谜**：你**不操作单位**，而是给每个单位写一套「如果……则……」的指令，
按下开始后看它们严格按你的规则自己打。你设计的是**规则**，不是操作。

- 引擎：Godot **4.7.2** stable（标准版，非 .NET 版）
- 语言：**GDScript**（无 C#，无编译等待）
- 平台：Windows

## 当前状态

**MVP 已可完整游玩**：三关教学关全部可通关，关卡编辑器可用，两套自动化验收全绿。

| 验收 | 规模 | 命令 |
|---|---|---|
| 端到端冒烟 | **1123 项断言**，约 20 秒 | `res://tools/smoke_test.tscn`（无窗口） |
| 视觉回归 | **17 张截图 + 282 项像素断言** | `res://tools/capture_screens.tscn` + `tools/check_shots.py` |

逐项证据见 [`docs/验收证据.md`](docs/验收证据.md)，开发过程与踩坑记录见 [`docs/开发进度.md`](docs/开发进度.md)。

---

## 怎么玩

一关分三段：**编制期**（时间静止）→ **推演期**（时间流动）→ **结算期**。

1. **画路线**：用工具栏的「信标」在场地上依次点出路线（信标带序号 1、2、3…）。消耗信标配额。
2. **写指令**：点一个我方单位打开**指令面板**——一条指令是**左条件 / 右行为**两栏并排
   （左边写「如果」，右边写「则」）。同一单位的多条指令**从上往下**匹配，**下面的覆盖上面的**。
3. **开始**：按工具栏「开始」，单位开始按指令行动。倍速可切 1× / 2× / 3×。
4. **结算**：满足胜负条件即出结果，给出总分与「指令复杂度 / 信标成本 / 时间成本」三项明细。

游戏内按「机制说明」可以看完整规则（内容来自 `data/help/机制说明.md`）。

### 操作

| 操作 | 作用 |
|---|---|
| 左键点单位 | 打开指令面板 |
| 左键点空地 | 关闭指令面板（信标模式下则是放信标） |
| 右键 | 撤回最后一个信标 |
| 工具栏「**开始**」 | 开始推演（**没有键盘快捷键**） |
| 工具栏「倍速」 | 1× / 2× / 3× 循环切换 |
| `ESC` | 打开 / 关闭暂停菜单（继续、重置关卡、设置、返回主菜单） |
| `R` | 重置关卡（已写好的指令保留） |
| `F1` | 回到关卡编辑器编辑当前关卡 |

### 关卡编辑器

| 操作 | 作用 |
|---|---|
| 左栏「**打开关卡…**」 | 弹出关卡列表选一关编辑（列表显示**关卡名**，不是 id） |
| 左栏「**关卡全局设置**」 | 从格子/单位视图回到关卡全局面板（id、名称、信标配额、信号数、时长、介绍、胜负条件） |
| 工具：刷空地 / 刷障碍 / 刷目标区 / 放单位 / 擦除 / 选择查看 | 地形与单位编辑 |
| 「放单位时用」 | 先选阵营与单位类型，再点地图放置 |
| `Ctrl+Z` / `Ctrl+Y` | 撤销 / 重做 |
| 保存 | 写入 `data/levels/<id>.json`（受限沙箱下会失败并给出提示，见"已知限制"） |
| 一键试玩 | 有未保存改动会先存盘，然后进入玩法 |
| `F1` | 从编辑器进入玩法 / 从玩法回到编辑器 |

**打开另一关时若有未保存改动，会先弹确认框**——不会默默丢掉你的编辑。

---

## 快速开始

```powershell
# 用 Godot 编辑器打开项目
& "D:\Godot\GODOT\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path "D:\jgd2026\v0.0.1"

# 直接运行游戏
& "D:\Godot\GODOT\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
    --path "D:\jgd2026\v0.0.1"
```

> ⚠️ 注意路径里**多一层同名子目录**（`..._win64.exe\Godot_v4.7.2-stable_win64.exe`）。
> 这是本机 Godot 的安装形态，容易看成写错了，但去掉那一层就找不到可执行文件。

### 跑验收

```powershell
$godot = "D:\Godot\GODOT\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$proj  = "D:\jgd2026\v0.0.1"

# 1) 冒烟测试（无窗口，约 20 秒）
& $godot --headless --path $proj res://tools/smoke_test.tscn

#    通过标准是三条同时成立：
#      · 末行输出「全部通过 ✅」
#      · 退出码 0
#      · 日志里 SCRIPT ERROR == 0   ← 只看 PASS/FAIL 会漏掉脚本错误

# 2) 视觉回归：真渲染并截图（会短暂弹窗）
& $godot --path $proj --resolution 1920x1080 res://tools/capture_screens.tscn
#    截图写到 D:/jgd2026/_shots，同时把每张图的元数据（SHOTMETA 行）打进 stdout

# 3) 对截图做像素断言
python $proj\tools\check_shots.py --shots D:/jgd2026/_shots --meta <上一步的日志文件>
```

冒烟测试内置**停滞看门狗**：20 秒没有新进展就退出码 2，不会把命令行挂死。

想只快速检查某个脚本有没有语法错（约 10 秒）：

```powershell
& $godot --headless --path $proj --check-only --script res://src/ui/rule_panel.gd
```

---

## 目录结构

```
autoload/               全局单例
  event_bus.gd            信号总线（跨节点通信不写 get_node 路径）
  save_manager.gd         存档 + 设置 + 显示设置
  game_state.gd           全局状态
  audio_manager.gd        音频总线与音效池
  scene_loader.gd/.tscn   带淡入淡出的场景切换（切换途中的请求不会被丢弃）
scenes/
  ui/main_menu.tscn       主菜单（启动场景）
  ui/pause_menu.tscn      暂停菜单
  ui/settings_menu.tscn   设置菜单（主菜单与暂停菜单各实例化一份）
  game/game_scene.tscn    模板遗留的场景，不参与玩法（被冒烟测试用作场景切换检查）
src/
  core/                   与引擎无关的纯逻辑
    time/                   固定步长时钟（60 tick/秒）
    map/                    网格地图、信标层、战斗状态
    unit/                   单位、移动、受击盒
    combat/                 子弹
    rule/                   规则引擎：条件、行为、意图、规则、信号
    level/                  关卡数据校验、载入、会话
    score/                  统计、评分、结算数据
    data/                   数值表加载与校验
  play/                   玩法场景（编制期/推演期/结算期）
  ui/                     指令面板、HUD、结算、机制说明、选关
    rule_panel/             指令面板的字段工厂与规则行
  editor/                 关卡编辑器（三段式布局：工具 / 地图 / 属性面板）
data/
  units.json              单位数值表
  scoring.json            评分权重
  levels/manifest.json    关卡清单（选关列表按它来）
  levels/tutorial_*.json  关卡数据
  help/机制说明.md         游戏内「机制说明」的内容（必须是纯文本 Markdown）
tools/
  smoke_test.gd/.tscn     端到端冒烟测试
  capture_screens.gd/.tscn 截图工具
  check_shots.py          像素断言
  probe_write.gd/.tscn    探测 res:// 是否可写（诊断用）
  cleanup_stray_levels.gd/.tscn 删除 manifest 未登记的关卡文件（测试残留清理）
docs/                     需求、设计、进度、验收证据（见下）
```

---

## 关卡与数据

关卡是数据驱动的，**加一关不需要改代码**：在 `data/levels/` 放一个 `<id>.json`，
把 id 加进 `manifest.json` 的 `levels` 数组即可出现在选关列表里（编辑器「新建关卡」就是走这条路）。

单位数值改 `data/units.json`，评分权重改 `data/scoring.json`。三者都在载入时**校验**，
出错会在界面上给出明确提示（而不是静默失败）。

**加完数据后跑一遍冒烟测试**：它包含一条"真实关卡文件不该被测试改写"的保险丝
（比对关卡内容、manifest 内容、`data/levels` 的文件清单），能挡住"测试把真实数据写坏"。

---

## 文档索引

| 文档 | 内容 |
|---|---|
| [`docs/需求文档.md`](docs/需求文档.md) | 69 条功能需求（FR-xxx，带优先级与验收标准）+ 20 条已定决策 |
| [`docs/概要设计.md`](docs/概要设计.md) | 总体架构与模块划分 |
| [`docs/design/`](docs/design) | 11 份分系统详细设计（时间、规则引擎、地图、单位、战斗、关卡、编辑器、结算、指令界面、UI、数据） |
| [`docs/策划案.md`](docs/策划案.md) | 原始策划案（`docs/《人工神灵》策划案.docx` 的文本版） |
| [`docs/开发进度.md`](docs/开发进度.md) | M0–M6 任务清单与状态、逐轮记录、**踩坑与教训** |
| [`docs/验收证据.md`](docs/验收证据.md) | 需求 → 测试 → 截图的逐项证据矩阵 |
| [`docs/待决策清单.md`](docs/待决策清单.md) | 尚未定稿的少数问题 |

---

## 改代码前先知道的约定

这些约定**代码里就是这么实现的**，改之前先看一眼对应详设，否则很容易写出"看起来对、实际反了"的逻辑：

- **坐标**：逻辑坐标是**瓦片中心的偏移**——瓦片 `(i, j)` 的中心在 `(i + 0.5, j + 0.5)`；
  `world_to_tile` / `logic_to_tile` 用 `floor`。
- **时间**：固定步长 `TICK_RATE = 60`，`TICK_DELTA = 1/60`。倍速是**自己的乘数**，
  **不用** `Engine.time_scale`（那是给演出用的）。
- **规则**：同一单位的多条指令从上往下匹配，**下面的覆盖上面的**；信号在一 tick 之后才生效。
- **碰撞层**：1 单位本体 / 2 障碍 / 3 我方子弹 / 4 敌方子弹 / 5 我方受击盒 / 6 敌方受击盒。
  子弹被障碍挡住。
- **视野**只是辅助显示（绿=我方、橙=敌方，只描边，不参与判定，墙不挡视野）。
- **跨文件引用**一律 `const X := preload(...)`，不要依赖 `class_name`。

---

## 已知限制与待办

- **编辑器保存**：在受限沙箱里 `res://` 可能不可写，保存会失败并提示。
  正常在 Godot 编辑器里跑没有这个问题。
- **`user://` 写入**：受限环境下会失败（存档/设置的实际路径是
  `%APPDATA%\Godot\app_userdata\人工神灵\`）。
- **底部信息栏**：需求里没写、详设里也没有依据，尚未实现（见待决策清单）。
- **`interact_device`（交互装置）行为**：策划案里有，MVP 明确不做（决策 D-13）。
- `data/levels/` 里可能残留一个 `new_level_1.json`（早期测试产物，功能无害）：
  用 `res://tools/cleanup_stray_levels.tscn` 或在资源管理器里删掉即可。

## 环境注意事项

- **autoload 顺序有硬约束**：`AudioManager._ready()` 要读 `Save` 的设置，
  所以 `Save` 必须排在 `Audio` 之前。顺序错了**不会报错**，只会静默表现为
  "设置好的音量下次启动失效"。冒烟测试里有一条专门断言守着它。
- 分辨率策略：**1920×1080 视口 + `canvas_items` 拉伸 + `expand` 宽高比**，窗口默认 1600×900。
- 两个插件都在用：Phantom Camera（相机，纯 GDScript）、Godot State Charts（状态机）。
  Phantom Camera 的 `PhantomCameraManager` autoload 是**手写进 `project.godot`** 的，别删。
- `tools/` 下的脚本不参与游戏运行。
