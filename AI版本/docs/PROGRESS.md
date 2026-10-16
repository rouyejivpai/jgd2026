# 实施进度

## M0 项目骨架 —— 完成（2026-10-04）

### 完成标准核对
- [x] `--import` 无错误（缓存存在时输出干净；空缓存首次导入的主题引导报错见 QUESTIONS Q-006）
- [x] 运行到主菜单；`SceneRouter` 可在主菜单 ⇄ 选关 ⇄ 设置间切换（带黑幕淡入淡出），已用临时脚本实机切换并截图验证（脚本已删除）
- [x] GUT 冒烟测试通过（GUT 9.6.1，1/1）
- [x] `git init` 并提交（仓库根为 `人工神灵/`，见 Q-008）

### 改动文件
- `godot/icon.svg`：骨白圆环图标
- `godot/assets/fonts/`：NotoSerifSC-Regular/Bold.otf、NotoSansSC-Regular.otf（noto-cjk 官方 OTF，重命名）、Cinzel-Regular/Bold.ttf（由 google/fonts 可变字体实例化，见 Q-001）、两份 OFL 许可证；5 个字体的 `.import` 已开启 `multichannel_signed_distance_field=true`
- `godot/assets/themes/palette.gd`：`class_name Palette`，04 §1.1 全部色值 + 01 §8 的 CanvasModulate 色
- `godot/assets/themes/main_theme.tres`：由 `tools/make_theme.gd` 从 Palette 生成（默认 NotoSerifSC 18px；类型变体 TitleLabel 28px / SmallLabel 14px / NumberLabel Cinzel），见 Q-005
- `godot/tools/make_theme.gd`：主题生成脚本（新增）
- `godot/scripts/autoloads/`：`event_bus.gd`（01 §4.1 全部信号）、`data_registry.gd`（M0 仅加载 strings.json + `get_string`，其余签名为空桩，见 Q-004）、`save_manager.gd`、`game_state.gd`、`audio_manager.gd`（空实现）、`scene_router.gd`（三个文档方法 + 追加 `goto_settings()`，见 Q-003）
- `godot/scenes/autoloads/audio_manager.tscn`
- `godot/scenes/screens/main_menu.tscn` + `scripts/screens/main_menu.gd`：占位背景色、标题、开始/设置/退出、数据错误红条（`has_errors` 时显示并禁用开始）
- `godot/scenes/screens/level_select.tscn` + `.gd`：8 个占位按钮（点击调用 `goto_battle`，M2 前仅告警）+ 返回
- `godot/scenes/screens/settings.tscn` + `.gd`：标题 + 返回
- `godot/project.godot`：注册 6 个 autoload（01 §4 顺序）、启用 GUT 插件
- `godot/addons/gut/`：GUT 9.6.1
- `godot/tests/unit/test_smoke.gd`
- `godot/data/strings.json`：`ui` 追加 `game_title`（见 Q-002）
- `docs/QUESTIONS.md`：Q-001 – Q-008

### 测试输出摘要
`python tools/validate_data.py`：
```
数据校验通过（units / traits / presets / strings / levels）。
```
`--headless --path . --import`（缓存存在）：
```
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org
[ DONE ] first_scan_filesystem
[ DONE ] loading_editor_layout
WARNING: ObjectDB instances leaked at exit (run with --verbose for details).   ← 来自 GUT 编辑器插件，见 Q-007
```
GUT：
```
Godot version:  4.6.2
GUT version:  9.6.1
res://tests/unit/test_smoke.gd
* test_smoke
1/1 passed.
Scripts 1 / Tests 1 / Passing Tests 1 / Asserts 1
---- All tests passed! ----
```
运行游戏（`--headless --path . --quit-after 60`）：无任何错误/警告输出；项目脚本无 untyped 警告。

### 已知问题
- 空缓存首次 `--import` 会打印主题/字体加载 ERROR（Godot 引导顺序，Q-006），第二次起干净。
- `--import` 退出时 GUT 插件计时器泄漏警告（Q-007），非项目代码。
- `hdr_2d` 下 `get_texture().get_image()` 截图为线性色，比屏幕显示暗；M7 截图验收时需注意转换。
- 会话期间目录中出现了非本实施方创建的文件：`tasks/资源生产任务包_GPT.md`、`godot/tools/gen_music.py`、`godot/tools/music_manifest.json`。未纳入 M0 提交，保持未跟踪，待确认归属。

## M1 数据层 + 模拟核心 —— 完成（2026-10-04）

### 完成标准核对
- [x] 05 §2 全部单元测试通过（10 个测试文件，69 条 + 冒烟 1 条 = 70/70，274 个断言）
- [x] `test_all_shipped_data_loads_without_errors` 通过（autoload 启动加载 `has_errors == false`）
- [x] 无 untyped 警告：用 `tools/strict_warnings.cfg`（复制为 `override.cfg` 后把 30 类 GDScript 警告全部升级为错误）跑全量 GUT 同样 70/70 通过
- [x] `validate_data.py` 通过
- [x] 铁律 3 检查：`scripts/sim/`、`scripts/data/` 中无 `extends Node`/`get_node`/`$`/`await`/`randf`/`Time.get_ticks_*`/`get_frames_per_second`

### 改动文件
- `scripts/data/`（新增）：`data_reader.gd`（错误收集与字段读取）、`condition_def.gd`、`target_def.gd`、`action_def.gd`、`rule_def.gd`、`unit_definition.gd`、`trait_definition.gd`、`preset_def.gd`、`slot_def.gd`、`spawn_def.gd`、`route_def.gd`、`objective_def.gd`、`level_definition.gd`、`data_validator.gd`（D02–D06 交叉校验，与 Python 脚本语义一致，另检查敌方默认指令的路线引用）
- `scripts/sim/`（新增）：`sim_grid.gd`（AStarGrid2D 四方向 + BFS）、`sim_unit.gd`、`sim_snapshot.gd`、`sim_decision.gd`、`sim_clock.gd`、`sim_blast.gd`、`target_selector.gd`、`rule_evaluator.gd`、`movement.gd`、`combat.gd`、`blast_system.gd`、`trait_system.gd`、`objective_system.gd`、`sim_world.gd`（step() 严格按 01 §6.2 的 13 步）、`deployment_validator.gd`
- `scripts/autoloads/data_registry.gd`：全部 JSON 加载 + 校验，`get_unit/get_trait/get_level/get_level_list/get_string` 及 `get_units/get_traits/get_presets/get_initial_unlocks/get_initial_levels`
- `scripts/autoloads/save_manager.gd`：`new_save`、`load_from`、`save_to`（`.tmp` + 替换的原子写，含中断恢复）、`migrate`、`apply_rewards`（去重累加）、`validate_level_configs`（只标记不删除）
- `scripts/core/sim_types.gd`：for 循环变量补类型；追加 3 个常量（Q-011）
- `data/progression.json`（新增，Q-009）；`data/strings.json` 追加 2 个校验键（Q-013）；`tools/validate_data.py` 追加 progression 校验
- `tests/helpers/sim_factory.gd`；`tests/unit/test_{rule_evaluator,target_selector,combat,movement,blast,objectives,sim_world,data_registry,deployment_validator,save_manager}.gd`
- `tools/strict_warnings.cfg`（严格警告检查配置）；`.gitignore` 忽略 `override.cfg`

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / levels）。
--import：仅 GUT 插件的 ObjectDB 泄漏警告（Q-007），无错误
GUT：Scripts 11 / Tests 70 / Passing 70 / Asserts 274 / 2.27s —— All tests passed!
```
日志中的 6 条 ERROR 均为 test_data_registry 故意注入的错误数据（unknown 'fly'、route 'nowhere'、(99,99) 越界、障碍压部署格、hints 3 条、缺 fail_feedback 键），已在测试中断言并标记为已处理。

### 参考（非 M1 门槛，未入库）
临时脚本以"推荐部署 + 槽位初始指令"跑八关 60 秒：八关全部 WIN，且 1×/2× 的 state_hash 与结果一致。
用时：L1 4.5s、L2 11.7s（承伤剩 40）、L3 8.0s、L4 5.7s、L5 25.5s（基础攻击形态阵亡）、L6 8.1s、L7 20.0s（转运点满血）、L8 17.3s（承伤、远射阵亡）。单步约 0.5 ms。正式集成测试在 M2 起按关卡编写。

### 已知问题
- `Vector2` 为单精度，位置在路点处可能有 ~1e-6 的误差（不影响确定性；测试用容差比较）。
- `--check-only -s` 无法解析 autoload 名称，单独检查引用 `DataRegistry` 的脚本会报 Identifier not found；以 GUT 全量运行作为编译与警告检查的依据。

## M2 战斗表现最小可玩（第一关）—— 完成（2026-10-04）

### 完成标准核对
- [x] 能部署两名单位、开始、看到移动/攻击/死亡、胜负结算（简单弹窗）：用临时脚本在真实窗口中（1920×1080 设计分辨率，2560×1369 窗口）驱动 GUI 拖放回调完成——非法格红色反馈 → 侧栏拖到 (2,2)、(1,4) → 地图内移动 (1,4)→(2,4) → 拖出部署区收回 → 再放回 → 点击选中显示双环 → 开始 → 4.5 s 胜利弹窗 → 重试回到部署且保留部署。全部截图已目检。
- [x] 第一关 headless 胜（集成测试 `test_level_01_recommended_wins`：WIN @ 4.50 s）
- [x] 1×/2× hash 一致（经 BattleController 分别以 1×、2× 跑到结束：结果、步数、state_hash 相同）
- [x] 主菜单 → 选关 → 第 1 关 → 退出 → 选关 流程实测通过
- [ ] 真实鼠标拖拽手势：Godot 只在系统真实鼠标位于窗口内时处理 GUI 鼠标事件，脚本注入的鼠标事件会被丢弃；计算机操作工具也无法识别便携版 Godot 程序。真实手势经过的就是上面已验证的三个回调，但仍建议手动试一次（见下方命令）。

### 改动文件
- `scripts/battle/`（新增）：`battle_controller.gd`（阶段机 DEPLOY→RUNNING⇄PAUSED→ENDED、倍速、重置=丢弃重建、开始前校验、事件转发；部署阶段也持有一个不推进的世界用于显示初始局面）、`battle_root.gd`、`unit_view.gd`（占位：程序绘制阵营底座——己方骨白圆环/敌方荆棘八角/建筑金框；己方圆角、敌方尖角血条；前冲、受击白闪抖动、死亡淡出；物理插值）、`grid_overlay.gd`、`deploy_zone.gd`、`range_layer.gd`（射程 = 15% 填充 + 实线环；视野 = 虚线细环）、`camera_rig.gd`（适配 ≤1300×900 可视区并居中到三栏之间）、`fx_layer.gd`（占位弹道）
- `scripts/ui/`（新增）：`hud.gd`、`map_input.gd`、`slot_item.gd`、`side_panel.gd`
- `scenes/battle/battle_root.tscn`（01 §8 场景树）、`scenes/battle/unit_view.tscn`、`scenes/ui/hud.tscn`（顶栏 72 / 底栏 96 / 侧栏 560 / 地图输入层 / 结算弹窗）
- `scripts/sim/sim_world.gd`：己方 id 按槽位序号固定（Q-015）
- `scripts/autoloads/game_state.gd`：载入初始解锁（Q-015）
- `tests/integration/test_levels_headless.gd`（第一关 5 条）
- 快捷键：Space 开始、R 重置、F 切换倍速、P 暂停/继续（project.godot 已有的输入映射）

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / levels）。
--import：仅 GUT 插件的 ObjectDB 泄漏警告（Q-007），无错误
GUT：Scripts 12 / Tests 75 / Passing 75 / Asserts 330 —— All tests passed!
  test_levels_headless：推荐解 WIN @ 4.50s；禁用攻击指令 LOSE @ 15.17s；1×/2× 一致；重置恢复；不部署不能开始
```
所有新增脚本均在严格警告模式（tools/strict_warnings.cfg）下加载运行过（GUT + 实窗检查），无警告。

### 手动试玩命令
```
cd H:\其他\人工神灵\godot
H:\Godot_v4.6.2\Godot_v4.6.2-stable_win64.exe --path .
```
主菜单 → 开始 → 1 → 从右侧"单位"栏把两个"基础攻击形态"拖进左侧金色格 → 点击单位看双环 → 开始（或 Space）。

### 已知问题 / 留给后续里程碑
- 美术全部为占位（M7 接入精灵、着色器、背景、灯光、后期）。
- 校验问题提示为一行红字，`{what}` 显示枚举原文（M3 问题列表 UI）。
- 退出不保存配置（M3 SaveManager 接线）；单位面板、指令编辑、敌人面板、状态图标、目标连线在 M3。

## M3 完整 UI（第一、二关可按设计流程玩通）—— 完成，含 1 项待策划决定（2026-10-04）

### 完成标准核对
- [x] 05 §4.1 全局 UI 清单（占位美术），均在真实窗口中走查并截图：
  - 不部署无法开始，问题列表逐条指出缺失槽位（RuleText 拼文案，阻塞项红、提醒项灰）
  - 选中单位：视野虚线环 / 射程实心环
  - 敌人面板：公开规则一句话 + 规则整句列表 + 特性说明；运行中显示当前目标与当前执行规则（金色）
  - 指令列表：拖拽排序、启用开关、条件（含百分比 / 比较符+距离参数）、选敌、行为（含路线）下拉，整句预览即时更新；运行中禁用并提示
  - 运行中当前生效行金边；未成立行出现"为何不成立"，展开显示原因短句（720p 截图：射程内没有敌人）
  - 待机单位头顶状态图标（Zz / 禁止 / 靶心叉），悬浮显示原因
  - 1×/2× 一致（集成测试）；暂停时计时不走（实测）
  - 重置保留部署与指令，敌人 / 生命 / 计时恢复（集成测试；爆炸标记在 M5 接入）
  - 退出再进入：部署与指令从存档恢复（实测第二关）；失效指令显示"以下指令已失效，请修正"且保留（集成测试）
  - 结算面板：胜败、原因、时间、存活、奖励、重试 / 下一关 / 返回 / 导出记录（导出到 user://playtests/ 已实测）；保护目标被毁时显示"最后一次有效攻击来自…"（逻辑已实现，第七关实测在 M6）
  - 提示按钮逐层展开，第 4 层显示推荐部署幽灵；已看层数写入存档
  - F3 调试层可开关，默认不出现（Q-017）
  - 1920×1080 与 1280×720 窗口文字无乱码、无截断
- [x] 第一关集成测试全部通过；第二关推荐解胜、1×/2× 一致通过
- [ ] 第二关"前后排倒置应失败"：当前数值下倒置仍胜利（阵亡 1 名），测试标为 pending → **Q-016 待策划决定**
- [x] 存档往返测试通过（test_save_manager 3 条 + 控制器配置往返 + 失效指令保留）
- [x] 关卡解锁与奖励流程：通关第一关 → 存档 completed=[level_01]、开放 level_02、获得承伤形态；选关界面显示 可挑战 / 已完成 / 未解锁

### 改动文件
- 新增 `scripts/ui/`：`rule_text.gd`（整句 / 条件 / 选敌 / 目标 / 原因 / 问题 / 状态文案拼装）、`ui_kit.gd`、`rule_row.gd`、`rule_editor.gd`、`unit_panel.gd`、`enemy_panel.gd`、`objective_panel.gd`、`dialogue_overlay.gd`、`hint_panel.gd`、`mechanics_popup.gd`、`result_panel.gd`
- 新增场景 `scenes/ui/`：`rule_row.tscn`、`rule_editor.tscn`、`unit_panel.tscn`、`enemy_panel.tscn`、`objective_panel.tscn`、`dialogue_overlay.tscn`、`hint_panel.tscn`、`mechanics_popup.tscn`、`result_panel.tscn`；重写 `hud.tscn`（侧栏三页、问题列表、提示、结算、机制说明、悬浮、Toast、调试信息、对话浮层）
- 新增 `scripts/battle/`：`target_lines.gd`、`recommend_ghosts.gd`、`debug_layer.gd`；`battle_root.tscn` 增加 TargetLines / DebugLayer 节点
- 修改：`hud.gd`、`map_input.gd`（悬浮原因）、`battle_root.gd`、`unit_view.gd`（状态图标）、`battle_controller.gd`（读档恢复、config_to_raw、写存档、胜利发奖励、失败计数、persist 开关）、`save_manager.gd`（启动读档 / 新建、save、关卡配置、提示层数、complete_level）、`game_state.gd`（直接引用存档字典）、`data_registry.gd`（get_default_settings / get_string_list）、`deployment_validator.gd`（支持只有指令未部署的槽位）、`sim_world.gd`（跳过未部署条目）、`level_select.gd/.tscn`（真实状态）
- 数据：`strings.json`、`progression.json` 追加（Q-019）
- 新工具：`tools/check_ui_literals.py`（铁律 8 扫描）
- 测试：`test_levels_headless.gd` 增加第二关 3 条与存档往返 2 条

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / levels）。
界面脚本无中文字面量。
--import：仅 GUT 插件的 ObjectDB 泄漏警告（Q-007），无错误
GUT：Scripts 12 / Tests 80 / Passing 79 / Pending 1 / Asserts 356
  level_01 推荐解 WIN @ 4.50s；禁用攻击 LOSE @ 15.17s
  level_02 推荐解 WIN @ 11.73s（承伤剩 40）；前后排倒置 WIN @ 12.67s（阵亡 1）→ Pending Q-016
```
全部 66 个脚本在严格警告模式（tools/strict_warnings.cfg）下加载通过；实窗走查同样在严格模式下运行，无脚本错误。

### 已知问题
- Q-016（第二关数值）需策划决定。
- 美术仍为占位：立绘、头像、图标、精灵、背景在 M7 接入。
- 真实鼠标拖拽手势仍建议手动试一次（理由同 M2）。
- 走查期间写入的测试存档与导出记录已删除，用户目录保持干净。

## M4 第三、四关 —— 完成，含 1 项待策划决定（2026-10-04）

### 完成标准核对
- [x] retreat / follow_route / chase / target_distance / first_seen 在 UI 中可配置（实窗验证：第三关条件下拉 = 始终 / 可见敌人 / 射程内敌人 / 目标距离，目标距离带"< / >"与格数；行为含撤离、追击、沿路线；路线下拉取自本关 routes〔未选择 / 墙下通道 / 穿过庭院〕，改选后整句即时变为"始终，沿路线「穿过庭院」前进"；第六关选敌下拉含"首个入视野"，"添加指令"列出 12 条已解锁预设）
- [x] 两关 headless 推荐解胜：第三关 WIN @ 8.03 s，第四关 WIN @ 5.73 s；两关 1×/2× state_hash 一致
- [x] 第三关锁定专项通过：逐步检查 449 步，基础攻击形态处于守卫视野内 134 步，守卫目标从未偷换（Q-023 判定口径）
- [x] 第三关预期失败：正面硬冲 LOSE @ 9.73 s（配置取舍见 Q-022）
- [x] 第四关围堵算法三场景（角落停滞 / 方向抵消 / 绕障碍，另加角落被夹死、三面包围）脚本复现并记录：docs/playtests/level_04_retreat.md。发现"方向抵消"抖动（2.2 s 内反转 16 次），按 03 §5 调半径（不加随机）后降为 0，记入 docs/CHANGELOG.md
- [ ] 第四关预期失败"单向追击追不上"：快速形态比猎犬快，单向追击 WIN @ 16.3 s → pending，**Q-021 待策划决定**

### 改动文件
- `data/units.json`：猎犬撤离行为去掉 `threat_radius: 4`（= 视野，远离所有威胁）；条件仍为 4 格（CHANGELOG）
- `tests/integration/test_levels_headless.gd`：第三关 4 条（推荐解、正面硬冲、1×/2×、锁定专项）、第四关 3 条（推荐解、单向追击、1×/2×）；控制器测试临时使用"全部解锁"
- 新增 `tests/integration/test_level_04_retreat_scenarios.gd`（6 个场景，打印指标并断言确定性 / 不进障碍 / 反转 ≤ 10 / 夹死时反咬）
- 新增 `docs/CHANGELOG.md`、`docs/playtests/level_04_retreat.md`
- M4 的 UI 需求由 M3 的指令编辑器直接满足，未改界面代码

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / levels）。
GUT：Scripts 13 / Tests 93 / Passing 91 / Pending 2（Q-016、Q-021）
  level_03 推荐解 WIN @ 8.03s；正面硬冲 LOSE @ 9.73s；锁定专项 449 步 0 违规
  level_04 推荐解 WIN @ 5.73s；单向追击 WIN @ 16.30s → Pending Q-021
  撤离场景：方向抵消 反转 0；角落（远程）反转 0；角落（近战）反转 1；夹死 反咬 5；绕障碍 反转 0
```

### 已知问题
- Q-016（第二关）、Q-021（第四关）为数值层面的待决项，均未擅自改数。
- 地图上尚未绘制路线（第八关要求"路线在地图上可见"，留到 M6）。

## M5 第五、六关 —— 完成（2026-10-04）

### 完成标准核对
- [x] 两关集成测试与专项断言通过：
  - 第五关：推荐解 WIN @ 25.5 s；共放置爆炸 12 次，其中 8 次锁定快速形态，快速形态被炸 0 次；重新部署改变最远者 / 落点；诱饵不动 LOSE @ 23.0 s；1×/2× 一致
  - 第六关：推荐解 WIN @ 8.1 s；三具残骸首次锁定均为承伤（id 1）；远射曾以祭司为目标；承伤不前置 LOSE @ 14.5 s（祭司逃离）；1×/2× 一致；三类失败说明映射（前排未留住 / 未进射程 / 选错目标）各一组部署验证
- [x] 爆炸不追踪 / 不取消在画面上可见（实窗截图）：落点停在快速形态被锁定时的位置 (2.5,7.0)，1 秒后快速形态已到 (5.5,8.5)，标记仍在原处倒计时；标记只读模拟中的爆炸列表，目标死亡不影响（单元测试 test_blast_not_cancelled_on_target_death 同时覆盖）；到期闪光可见
- [x] BlastMarker：半径红环（脉动）、环内填充随剩余时间收缩、Cinzel 倒计时数字、到期扩散闪光；施放者前冲 + 弹道
- [x] delayed_blast 接入 HUD：敌人面板显示"延迟爆炸：x 秒后可再次释放"（Q-026）
- [x] reach_zone 逃离区显示（暗红斜纹 + 红框）；第六关失败按三类给出说明（Q-025）

### 改动文件
- 新增 `scripts/battle/blast_marker.gd`、`scripts/ui/fail_diagnosis.gd`
- 修改 `scripts/battle/fx_layer.gd`（标记生成/闪光）、`battle_root.gd`（BLAST 事件）、`grid_overlay.gd`（逃离区）、`scripts/ui/result_panel.gd`（使用 FailDiagnosis）、`scripts/ui/enemy_panel.gd`（特性冷却）
- 数据：`data/levels/level_06.json` 追加三条分类失败说明；`data/strings.json` 追加 `ui.trait_next`、`ui.trait_ready`、`names.traits`
- 测试：`test_levels_headless.gd` 增加第五关 5 条、第六关 5 条
- 文档：`docs/DATA_TUNING_HANDOFF.md`（新，数值问题交接，含 Q-016/021/022/024）

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / levels）。
界面脚本无中文字面量。
GUT：Scripts 13 / Tests 103 / Passing 101 / Pending 2（Q-016、Q-021，已转交数值 AI）
  level_05 推荐解 WIN @ 25.50s，爆炸 12 次，快速形态被炸 0 次；诱饵不动 LOSE @ 23.00s
  level_06 推荐解 WIN @ 8.10s；残骸首次锁定 {H1:1, H2:1, H3:1}；承伤不前置 LOSE @ 14.50s
  三类失败：front_not_held / out_of_range / wrong_target 各映射正确
```

### 已知问题
- 数值问题统一记录在 docs/DATA_TUNING_HANDOFF.md，交由数值 AI 处理（用户指示）。
- 爆炸标记、闪光为占位绘制；blast_marker.gdshader、粒子、PointLight2D 在 M7 接入。

## M6 第七、八关 —— 完成，含 2 项转交（2026-10-04）

### 完成标准核对
- [x] 第七关 05 §3 第 4 条专项通过：首次阵亡 5.1 s 之后重新选敌 8 次；敌人 9.1 s 全灭时 threat_cleared 为真，计时继续，20.0 s 胜利
- [x] 第八关正面与绕后两条路线各一份试玩记录：docs/playtests/level_08_routes.md、level_08_front.json（WIN 17.3 s）、level_08_bypass.json（WIN 25.7 s，护卫 G2 存活，核心被毁即胜）
- [x] 八关全部 headless 推荐解胜：L1 4.5 s | L2 11.7 s | L3 8.0 s | L4 5.7 s | L5 25.5 s | L6 8.1 s | L7 20.0 s | L8 17.3 s（test_all_eight_levels_recommended_win）
- [x] survive 计时 HUD：顶栏倒计时（Cinzel，最后 5 秒变红，模拟时间）、"转运点 生命 x/80"、"威胁已清除"（金色）；任务页同步显示
- [x] 最后一次攻击来源：第七关失败时结算显示"最后一次有效攻击来自 正面袭击者 C，发生在 9.8 秒"（实窗截图）
- [x] 第八关战后剧情占位文本卡：胜利后在结算面板上方逐字播放（Q-029）
- [x] 路线在地图上可见（第八关三条藤廊/花径；其余有路线的关卡同样显示，Q-030）
- [x] 第七关另一套实质不同的部署（承伤 (3,5) / 攻击 (3,3) / 远射 (1,3)）胜利；1×/2× 一致；第八关 1×/2× 一致
- [ ] 第七关预期失败（前排追击 + 全员 y=6）与第八关预期失败（全员正面）实测均胜利 → pending，Q-027（第七关数据冻结，仅记录）、Q-028（转交数值 AI）

### 改动文件
- 新增 `scripts/ui/playtest_record.gd`（试玩记录构建/保存，结算面板与脚本共用）、`scripts/battle/route_layer.gd`
- 修改 `scripts/ui/hud.gd`（生存倒计时、威胁已清除着色、胜利后播放剧情）、`scripts/ui/objective_panel.gd`（survive_time_left、progress_text 可选时间行）、`scripts/ui/result_panel.gd`（改用 PlaytestRecord）、`scripts/autoloads/data_registry.gd`（get_story）、`scripts/battle/battle_root.gd` 与 `scenes/battle/battle_root.tscn`（RouteLayer）
- 数据：`data/strings.json` 追加 `stories.ch1_boss_outro`（占位）
- 测试：`test_levels_headless.gd` 增加第七关 5 条、第八关 4 条、八关推荐解汇总 1 条
- 文档：`docs/playtests/level_08_routes.md` + 两份 JSON 记录；DATA_TUNING_HANDOFF 追加 Q-027、Q-028

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / levels）。
界面脚本无中文字面量。
GUT：Scripts 13 / Tests 113 / Passing 109 / Pending 4（Q-016、Q-021、Q-027、Q-028）
  level_07 推荐解 WIN @ 20.00s；专项：重新选敌 8 次、威胁已清除 @ 9.10s、20.00s 胜利
  level_08 推荐解 WIN @ 17.30s；绕后 WIN @ 25.73s（护卫存活 1，核心毁即胜）
  八关推荐解全部 WIN
```

### 已知问题
- 4 项 pending 均为数值/文档预期问题，已在 DATA_TUNING_HANDOFF.md 汇总（第七关仅记录不改）。
- 第八关战后剧情为占位文本；立绘、音效在 M7。

## M7 美术与音频整合 —— 程序侧整合完成，最终验收待资源方交付（2026-10-04）

资源生产（AI 出图、程序化贴图、SVG 图标、BGM/SFX）由独立的资源流程按 `tasks/资源生产任务包_GPT.md` 进行（用户指示，Q-031）。本里程碑只做程序侧：所有资源按约定路径"存在即用、缺失即回退占位"，资源到位后无需改代码。

### 完成标准核对（04 §4.5 + 00 M7）
- [x] 1080p 截图 8 关各一张：`docs/screenshots/level_01..08.png`（原生 1920×1080 窗口，运行中截取）
- [x] §4.5-1 同一人偶变体：四形态 Q 版精灵 + 立绘已接入（棋盘、单位面板头像、对白立绘），实窗截图核对一致
- [x] §4.5-2 灰度可辨：己方骨白圆环底座 + 圆角生命条；敌方荆棘八角底座（加 8 根外凸尖刺）+ 两端尖角生命条（加浅色轮廓）；建筑金色方框 + 方角条。灰度截图核对通过
- [x] §4.5-3 1080p 无白边：单位精灵 mipmap + 预乘边缘，放大检查无白边/色晕（屏幕边缘的轻微色散为后期 aberration 0.002，属有意效果）；背景 AI 伪影由资源方负责
- [x] §4.5-4 独立反馈：爆炸预警（blast_marker 着色器收缩环 + Cinzel 倒计时 + 红光脉冲 + 预警滴答加速）、受击（hit_flash 白闪 + 受击音）、死亡（dissolve 溶解 1 s + 光源熄灭 + 死亡音）、解锁（结算奖励列表 + 金色标注）、目标拾取（目标连线 + 状态图标）
- [ ] §4.5-5 原图保留于 tools/_raw/ —— 资源方职责
- [ ] BGM 7 段、SFX 32 条、程序化贴图、SVG 图标 —— 资源方尚未交付；接入点已全部就绪（Q-032）

### 改动文件
- 新增 `scripts/battle/art.gd`（贴图/着色器/材质缓存，缺失返回 null）、`map_background.gd`（背景居中裁切到地图比例 + 边缘渐隐）、`props_layer.gd`（按 biomes.json 给阻挡格放道具，端/中段变体）
- 新增着色器 `assets/shaders/`：breathing、hit_flash、dissolve、outline、range_ring、blast_marker、deploy_zone、post_vignette_grain、bg_fade_edge（04 列出的 9 个）+ circle_mask（头像圆形遮罩，Q-034）
- 新增数据 `data/biomes.json`（biome → 道具映射，Q-033）；`tools/validate_data.py` 校验 biomes；`tools/apply_import_presets.py`（04 §4.4 导入设置）
- 修改 `scenes/battle/battle_root.tscn`（Background、Props、CanvasModulate #5A4A5E、WorldEnvironment 辉光、PostFX 层；UI 层移到 layer 2）
- 修改 `unit_view.gd`（精灵 + 描边 + 呼吸材质、朝向、PointLight2D、受击闪白、溶解死亡、状态图标 SVG 优先）、`range_layer.gd`、`deploy_zone.gd`、`blast_marker.gd`、`fx_layer.gd`（弹道贴图）、`grid_overlay.gd`（有背景时不铺底色）、`battle_root.gd`（背景/道具/音频接线）
- 重写 `scripts/autoloads/audio_manager.gd`：Music/SFX/UI/Ambient 四总线、BGM 1 s 交叉淡入、结算 sting 压低 BGM、环境音、8 路 SFX 池 + 50 ms 去重、按钮自动挂点击/悬停音、音量取自设置
- UI：`ui_kit.gd`（圆形头像）、`unit_panel.gd`、`enemy_panel.gd`（头像）、`dialogue_overlay.gd`（立绘：默认人偶、魔女说话时切换，与更新后的 01 §9 一致）、`hud.gd`（倒计时滴答）、`slot_item.gd`/`map_input.gd`（拖放音）、`main_menu.gd`（关键视觉 + 菜单 BGM）、`level_select.gd`（章节地图底图）、`settings.gd`
- `tools/make_theme.gd`：button_*/panel_dark 贴图存在时用 9 宫格 StyleBoxTexture；补 PopupMenu/Tooltip/Tab/LineEdit/CheckBox 样式；已重新生成 main_theme.tres
- `data_registry.gd`：get_biome_prop / get_prop_variants

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels）。
界面脚本无中文字面量。
--import exit=0（仅 "ObjectDB instances leaked at exit" 退出警告）
GUT（严格告警模式）：Scripts 13 / Tests 113 / Passing 109 / Pending 4（Q-016、Q-021、Q-027、Q-028）/ Asserts 491 / exit 0
```

### 已知问题
- 背景图中的墙体/荆棘与阻挡格对不齐（第三关墙约高半格、第八关荆棘墙偏移）；当前以道具精灵覆盖阻挡格，背景本身需资源方按网格重出或微调（docs/ASSET_HANDOFF.md）。
- 背景偏亮、偏卡通，靠 CanvasModulate 压暗；灯光/辉光参数为目测值（Q-035）。
- 无 BGM/SFX 文件时静默运行（仅 verbose 日志）。

## M8 打磨与发布 —— 完成，2 项硬件条件待复测（2026-10-04）

### 完成标准核对（00 M8 / 05 §4.3 / 05 §5）
- [x] 设置页：主音量/音乐/音效滑条（即时生效）、全屏、目标连线、字体大小（100/115/130%）、模拟日志开关；返回时写存档；启动时应用全屏与字体（Q-037）
- [x] F3 调试层（M3 已有，默认隐藏）
- [x] 日志：`scripts/core/debug_log.gd` 把 SimEvent 逐条写入 `user://logs/sim_<时间戳>.log`（`t=12.433 | rule_changed | rule=1 unit=3`），正式战斗开始时开新文件、结束/重置/退出时关闭，只保留最近 30 份；设置中可关
- [x] 8 关 × 推荐解 + 替代解试玩记录（另附预期失败）：`docs/playtests/level_0X_{recommended,alternative,expected_fail}.json`，汇总与数值建议见 `docs/PLAYTEST_REPORT.md`；24 个场景 1×/2× 全部一致
- [ ] 第八关 2× 全程 ≥ 60 fps（集成显卡）：本机仅有 RTX 4060 Ti，实测平均约 520–540 fps、1% low 约 185 fps；掉到 60 fps 以下的只有开局第 1–2 帧与结算面板出现那一帧（≤ 53 ms）；PointLight2D 峰值 8（预算 16）。集成显卡待复测（Q-039）
- [x] 连续重置 20 次无内存增长：对象 3228→3228、节点 501→501、孤立节点 0、资源 118→118、显存 245.72→245.72 MB、静态内存 137.83→137.85 MB
- [x] Windows 导出：`export/ArtificialDeity_Demo.exe` + `.pck`（84 MB）；14 个数据 JSON 与字体许可证已打包，tests/、addons/gut/、tools/ 未打包；复制到项目外目录运行（headless 与真实窗口）无错误，日志/存档目录为 `%APPDATA%/Godot/app_userdata/人工神灵 Demo/`。干净机器待复测（Q-040）
- [x] 1920×1080 与 1280×720（含字体 130%）设置页、战斗界面文字无截断（实窗截图）

### 改动文件
- 新增 `scripts/core/debug_log.gd`；`scripts/battle/battle_controller.gd`（开始/事件/结束/重置/退出接入日志）
- 重写 `scripts/screens/settings.gd`；`scripts/autoloads/game_state.gd`（apply_display_settings、apply_font_scale、setting_float）
- 数据：`progression.json` default_settings 追加 font_scale、sim_log；`strings.json` 追加设置页文案 7 条
- 工具：`tools/run_playtests.gd` + `_impl.gd` + `playtest_scenarios.json`（脚本化试玩）、`tools/perf_check.gd` + `_impl.gd`（帧率与重置内存）、`export_presets.cfg`（Windows Desktop）
- 测试：`tests/unit/test_debug_log.gd`（3 条）
- 文档：`docs/PLAYTEST_REPORT.md`、`docs/playtests/` 24 份记录；DATA_TUNING_HANDOFF 追加 Q-036；QUESTIONS Q-036～Q-040

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels）。
界面脚本无中文字面量。
--import exit=0
GUT（严格告警模式）：Scripts 14 / Tests 116 / Passing 112 / Pending 4（Q-016、Q-021、Q-027、Q-028）/ Asserts 500 / exit 0
run_playtests：24 scenarios, 0 problems（1×/2× 全部一致）
perf_check：level_08 2x avg≈530 fps，1% low≈185 fps；reset ×20 objects/nodes/resources/显存 delta 0
export：exit 0，ArtificialDeity_Demo.exe + .pck
```

### 已知问题
- 预期失败 4 项实测胜利（第 2、4、7、8 关）及第五关正面冲锋过强（Q-036），均为数值问题，已转交数值 AI；第七关数据未改动。
- 第二关"首败连线高亮"已实现但无自动化测试。
- BGM/SFX 与部分贴图仍待资源方（见 M7 / ASSET_HANDOFF.md）；导出版当前无声。
- 导出 exe 未嵌入图标（未配置 rcedit，`application/modify_resources=false`）。

## 引擎升级 4.6.2 → 4.7.2 —— 完成，导出模板待下载（2026-10-04）

### 改动
- 引擎：`H:\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe`（官方 Releases，SHA-512 已核对）；4.6.2 保留在 `H:\Godot_v4.6.2\`
- `project.godot`：`config/features` 由 `"4.6"` 改为 `"4.7"`
- `addons/gut/`：GUT 9.6.1 → **9.7.1**（4.7 兼容线，原样替换上游 `addons/gut`，消除 "This version of GUT may not be compatible" 提示；见 Q-007）
- 文档 / 工具注释中的命令与路径改为 4.7.2（00、01、05、DATA_TUNING_HANDOFF、PLAYTEST_REPORT、QUESTIONS、README、tools/make_theme.gd、perf_check.gd、run_playtests.gd）；项目根更新为 `H:\其他\人工神灵\AI版本\godot\`
- 游戏脚本、场景、数据**无需改动**：4.7.2 下导入、解析、严格告警全部干净
- `docs/playtests/*.json`：4.7.2 的 `JSON.stringify` 把空字典写成单行 `{}`，内容不变

### 测试输出摘要（4.7.2）
```
--import exit=0，无错误/警告
数据校验通过（units / traits / presets / strings / progression / biomes / levels）。
GUT（普通 + 严格告警模式）：Scripts 14 / Tests 116 / Passing 112 / Pending 4（Q-016、Q-021、Q-027、Q-028）/ Asserts 500 / exit 0（与 4.6.2 基线完全一致）
run_playtests：24 scenarios, 0 problems；胜负、时长、目标血量与 4.6.2 逐项一致
主菜单实窗 600 帧：无脚本/着色器错误
perf_check（同一资源版本对比）：4.6.2 avg 400 fps / 1% low 145；4.7.2（着色器缓存就绪）avg ≈500 fps / 1% low ≈189；reset ×20 nodes/resources/显存 delta 0
  注：4.7.2 首次运行（着色器缓存为空）有一次 102 ms 卡顿，之后消失
```

### 已知问题
- 4.7.2 导出模板未下载，暂不能导出 exe（4.6.2 模板不可混用）。
- 场景/资源文件未做"升级项目文件"批量重存：4.7.2 读取旧格式无报错，按需在编辑器 项目 → 工具 中执行。

---

# 第二阶段（程序任务包 2026-10-05）

## P0 收尾、直接修复、空指令与「推荐阵型」—— 完成（2026-10-05）

### 完成标准核对
- [x] GUT 全绿，pending 仅剩数值项（Q-016、Q-021、Q-027、Q-028）：普通与严格告警模式均 Scripts 18 / Tests 146 / Passing 142 / Pending 4 / Asserts 664 / exit 0
- [x] run_playtests 24 场景结果与哈希与 M8 一致：先在改动前跑出 M8 基线（runner 汇总行新增 state_hash 列），改动后逐行 diff **完全相同**（`tools/_work/playtests_m8_baseline.txt` vs `playtests_p0.txt`）
- [x] 导出版有声可运行：4.7.2 模板安装后 `--export-release` exit 0（exe + 121 MB pck，含 BGM/SFX），复制到项目外目录运行，菜单 BGM 加载、无脚本错误
- [x] PROGRESS / QUESTIONS（Q-041～Q-044）/ CHANGELOG 已记

### 逐项
1. CHANGELOG 补记 4.7.2 升级（并写明以后版本变更都记此表）；45 个文件 + GUT 9.7.1 新增的 gut_constants.gd、06/07/08 文档、任务包一并提交 `1649435 引擎升级 4.7.2 与文档同步`。
2. 4.7.2 导出模板：官方 tpz（1.28 GB，SHA-512 核对一致），只装 windows 模板；重新导出 `export/ArtificialDeity_Demo.exe`。CHANGELOG 记一行。
3. `docs/UI设计.pptx` → `docs/reference/`。
3b. 资源修正批次：`apply_import_presets.py`（43 个 .import）→ `--import` → `make_theme.gd`；实机联系表检查 43 个图标、7+2 个重画精灵、L2–L8 背景均正常显示；**Cinzel-Bold.tres 不加粗**（字符串键 `"wght"` 无效、整数 tag 有效），记 Q-041 交资源方；8 张截图用新工具 `tools/take_screenshots.gd` 重拍（线性→sRGB 转换后与 M7 截图的 UI 颜色一致）；assets 入库 `1e32a6f`。资源方 01:10 起在写的 `assets/backdrops/`（R1 进行中）未入库。
4. A01：RuleRow 增加「删除」按钮（部署阶段可用、运行中禁用）；新指令插末尾（已是 append，加注释与测试）；空列表允许开始，开始时把非阻塞提醒（EMPTY_RULES）以 Toast 显示（此前只在有阻塞问题时才看得到）。
5. 空指令与「推荐阵型」：
   - `SlotDef` 不再加载 `rules`，出现时 `DEPRECATED_FIELD` 提醒（`DataReader.warn`，不计错误）；`recommended_deploy` 出现时报 `DEPRECATED_FIELD` 错误；`initial_rules_for_slot` 删除，未给指令 = 空指令（SimWorld / DeploymentValidator / BattleController）。
   - 8 个关卡 JSON 迁移为 `recommended.units`（无损脚本迁移并核对；Q-043 第七关）；新增 `RecommendedUnitDef`；DataValidator 与 validate_data.py 同步（槽位/形态一致、部署区、重叠、推荐指令行为与路线、信标格）。
   - `BattleController.apply_recommended()`：覆盖部署与指令（未列出的槽位收回并清空）并校验一次。
   - HintPanel 重写：4 层前逐层揭示；第 4 层后按钮文字变「推荐阵型」，按下列出全部提示 + 确认区（"将覆盖当前部署与指令"），只在部署阶段可确认；`hints_seen`、新存档键 `recommend_used`（migrate 补齐）入存档，重置不清除；RecommendGhosts 节点与脚本删除。
   - 测试 `test_hint_recommend.gd`（8 条）；run_playtests 场景改为显式指令，runner 对缺指令的已部署槽位报错。
6. A02：复现结论见 Q-044（空格 + 按钮焦点、双击、浮层叠压）。修复：战斗快捷键移到 `_input` 先于 GUI；顶栏/底栏按钮 FOCUS_NONE；350 ms 揭示保护；提示面板与机制说明互斥、结算时收起提示面板；面板高度随内容收缩（宽度不变）。测试 `test_hint_panel.gd`（6 条，含真实输入管线空格用例、机制说明部署/运行/暂停/结算均可打开）。
7. A03：预设路线改为淡紫虚线、3 px、部署 0.85 / 运行 0.45；新增 `ObstacleHighlight`：任何携带 slot_id 的拖拽开始时障碍格叠红色斜纹（alpha 0.5），结束 0.3 s 淡回；特殊目标头顶常驻图标（骷髅/盾/裂纹，程序绘制）+ 底座金色脉动，顶栏任务句可点击使其闪烁（分类规则见 Q-042）。
8. A04：`FacingTracker`（纯逻辑，可单测）：背向一侧累计 ≥0.5 格或连续 ≥0.4 s（模拟时间）才翻转，不足时背步（后仰 6°，不翻转），翻转 0.12 s 横向缩放过渡；攻击时直接面向目标。只读 SimUnit。测试 `test_readability.gd`（8 条）；playtests 哈希不变。
9. 02 文档 1.1：删 `unlock_slots`；并入 biomes.json（§8）、progression.json（§9）；`recommended` 字段与 D04/D09 校验。

### 改动文件
- 新增：`scripts/data/recommended_unit_def.gd`、`scripts/battle/facing_tracker.gd`、`scripts/battle/obstacle_highlight.gd`、`tools/take_screenshots.gd` + `_impl.gd`、测试 `test_hint_recommend.gd`、`test_hint_panel.gd`、`test_rule_editor.gd`、`test_readability.gd`
- 删除：`scripts/battle/recommend_ghosts.gd`（及场景节点）
- 修改：`data/levels/level_01–08.json`、`data/strings.json`（ui 新增 10 条）、`scripts/data/{data_reader,data_validator,level_definition,slot_def}.gd`、`scripts/sim/{sim_world,deployment_validator}.gd`、`scripts/battle/{battle_controller,battle_root,unit_view,route_layer}.gd`、`scenes/battle/battle_root.tscn`、`scripts/ui/{hint_panel,hud,rule_editor,rule_row}.gd`、`scripts/autoloads/save_manager.gd`、`tools/{validate_data.py,run_playtests_impl.gd,perf_check_impl.gd,playtest_scenarios.json}`、`export_presets.cfg`、`tests/helpers/sim_factory.gd`、`tests/integration/test_levels_headless.gd`、`tests/unit/test_data_registry.gd`、`docs/02_数据规格.md`、`docs/screenshots/*.png`、`docs/playtests/level_0{1,2,8}_recommended.json`（仅 notes 措辞）

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels）。
界面脚本无中文字面量。
GUT（严格告警模式）：Scripts 18 / Tests 146 / Passing 142 / Pending 4 / Asserts 664 / exit 0
run_playtests：24 scenarios, 0 problems；胜负、时长、losses、objective_hp、state_hash 与 M8 基线逐行一致
export：exit 0；exe 在项目外目录运行正常
```

### 已知问题
- 删除 recommend_ghosts.gd 后第一次 `--import` 段错误退出一次（类缓存过期），再跑一次即 exit 0，之后稳定。
- GUT 报告中 HintPanel / RuleEditor 测试的 "Orphans" 为同一帧内 `queue_free` 尚未执行的旧标签，不是泄漏。
- 实机走查脚本会读写真实存档（`user://save.json`）；本阶段走查前已备份，走查后已恢复原文件。

## P1 场景分层（A17）—— 完成（2026-10-05）

### 完成标准核对
- [x] 8 关在占位资源下运行：`docs/screenshots/p1/1920x1080/level_01–08.png`（部署阶段，推荐阵型），另有 `1920x1200/`、`2560x1080/` 各 8 张
- [x] `tests/integration/test_playfield_input_clipping.gd` 通过（6 条：与 07 §1.2 表逐关一致、三种窗口比例下居中且 cell_px 不变、手动 playfield_rect、background 废弃报错、场景级变换/裁剪结构、矩形外点击/拖起/放下无效）
- [x] 三种窗口比例截图：玩法矩形外无格子（网格、部署区、路线、障碍红纹都在受裁剪的 MapLayer 下），backdrop 铺满窗口，玩法矩形在顶栏与底栏之间居中

### 逐项
1. `tools/print_playfield_rects.py`：打印 07 §1.2 表（输出与文档表格完全一致）；`--png` 输出 1920×1080 标线图（玩法矩形实线、外扩 0.5 格虚线、网格、障碍斜纹、部署区、UI 栏灰带）到 `tools/_raw/playfield_guides/level_01–08.png`（_raw 不入库，供资源方 R1 垫底）。
2. BattleRoot：`BackdropLayer`（全屏 Sprite2D，cover 等比铺满视口、居中裁边，随视口尺寸变化重算）；`MapLayer` 挂 `playfield_clip.gd`（画玩法矩形作遮罩，clip_children = 仅裁剪），其下 `GroundLayer`（新）→ GridOverlay → DeployZone → RouteLayer → ObstacleHighlight；`Playfield.compute()` 每关（及视口变化时）计算 `playfield_rect` / `cell_px`，地图类节点（MapLayer、UnitLayer、FXLayer、RangeLayer、TargetLines、DebugLayer）统一挂"位置 = 矩形左上、缩放 = cell_px / TILE_SIZE"的变换；**CameraRig 删除**（镜头不再缩放地图）。`screen_to_sim` 改用 MapLayer 的全局变换；新增 `in_playfield()`，`unit_at_screen` 矩形外恒为 -1；MapInput 矩形外拖起返回 null、侧栏单位不能放到矩形外、地图上拖出矩形 = 收回。网格线改为 1 像素细线（缩放后仍可见）。
   - 说明：`SimTypes.TILE_SIZE` 保留为地图类节点的**局部绘制单位**，屏幕上的每格像素由 `BattleRoot.cell_px` 决定；这样精灵、血条、射程圈、爆炸标记等全部随格子等比缩放，模拟层与所有绘制代码无需逐个改常量。
3. PropsLayer（竖立道具）停用：节点与 `props_layer.gd` 删除，DataRegistry 的道具查询函数删除（biomes.json 的 props 数据保留供美术参考）；障碍格改为 GroundLayer 的 `ground_marks` 贴片（按格坐标确定性挑选，缺失时程序绘制碎石占位）+ P0 的规划态红纹；GridOverlay 不再给障碍格叠暗纹。
4. 数据：关卡 `scene` 字段（backdrop / ground / ground_tint / playfield_rect）；旧 `background` 报 `DEPRECATED_FIELD` 错误；biomes.json 新增 `ground_textures`、`ground_marks`；LevelDefinition / DataRegistry（`get_ground_textures`、`get_ground_marks`、`_validate_biomes`）/ validate_data.py 同步（含 backdrop/ground 文件不存在时的提醒）。
5. 占位：`scene.backdrop` 暂指向第一阶段 8 张背景（cover 铺满）；`scene.ground` 为空 → ground_tint 纯色（Q-045）。资源方已在工作区放入 `assets/grounds/`、`assets/sprites/ground_marks/`、`assets/backdrops/`（R1 进行中，未入库、未在本里程碑验收）；其中 ground_marks 因按名称查找会被自动使用，backdrop / ground 等资源方交付报告后改数据切换。
6. 测试见上；P0 的 146 条全部保持通过。

### 改动文件
- 新增：`scripts/battle/playfield.gd`、`playfield_clip.gd`、`ground_layer.gd`、`tools/print_playfield_rects.py`、`tests/integration/test_playfield_input_clipping.gd`、`docs/screenshots/p1/**`
- 删除：`scripts/battle/camera_rig.gd`、`scripts/battle/props_layer.gd`
- 修改：`scenes/battle/battle_root.tscn`、`scripts/battle/{battle_root,map_background,grid_overlay}.gd`、`scripts/ui/map_input.gd`、`scripts/data/level_definition.gd`、`scripts/autoloads/data_registry.gd`、`data/levels/level_01–08.json`、`data/biomes.json`、`tools/validate_data.py`

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels）。
界面脚本无中文字面量。
GUT（严格告警模式）：Scripts 19 / Tests 152 / Passing 148 / Pending 4 / Asserts 723 / exit 0
run_playtests：24 scenarios, 0 problems；与 M8 基线逐行一致（含 state_hash）
print_playfield_rects：8 行与 07 §1.2 表一致
```

### 已知问题
- 旧 HUD 右侧固定侧栏盖住多数关卡玩法矩形的右侧几列，P3 HUD 重排时解决（Q-046）。
- 地面/标识的视觉强度（alpha 0.9 / 0.85）为占位参数，资源到位后统一调。

## P2 信标、等待、到点（A06）—— 完成（2026-10-05）

### 完成标准核对
- [x] `tests/integration/test_beacons_wait_scenario.gd`（9 条）与相关单元测试通过：07 §3.7 小场景（走到 A、等 2 s、到 B、到 C 停下，等待期间位移为 0、等待 2.00 s）、loop 顺序 A B C A B C A、pingpong 顺序 A B C B A B C、from 为中间信标、删除 B 后引用 B 的条件与行为被校验指出且阻止开始、没有信标 / 信标在障碍上、运行时信标缺失原地待机、抢占取消等待且不重计时、离开后再到达重新等待、第三关 1×/2× 一致
- [x] 在现有第三关用信标替代预设路线完成绕后并记录试玩：`docs/playtests/level_03_beacons.json`、PLAYTEST_REPORT 新增一节（WIN 8.03 s，哈希与原推荐解相同）

### 逐项
- 模拟核心：`SimTypes` 追加 `ConditionType.AT_BEACON`、`ActionType.FOLLOW_BEACONS / WAIT`、`BeaconMode`、`ReasonCode.WAITING / BEACON_MISSING / COND_NOT_AT_BEACON / WAIT_DONE`（后两个见 Q-048），预留 `Selector.LAST_ATTACKER`、`TraitType.ALERT_BROADCAST`（不可解析、未实现）；常量 AT_BEACON_RADIUS 0.35、MAX_BEACONS 8、WAIT 0.5–30。`SimUnit.beacons`、`beacon_index / beacon_dir`（游标，抢占时保留）、`wait_state`（每条 wait 规则的 armed / remaining）。`RuleEvaluator`：at_beacon 判定、wait 的 armed 边沿触发与抢占取消；`Movement.follow_beacons`（once / loop / pingpong，抵达 ARRIVE_EPS）。SimWorld 从配置读入信标。模拟层仍无 Node / 随机 / 实时时钟。
- 校验：`DeploymentValidator` 新增 `BEACON_MISSING`、`BEACON_ON_BLOCKED`、`BEACONS_EMPTY`（阻塞）；存档 `beacons` 解析；信标/到点/等待不受 allowed、解锁、形态限制（Q-047）；DataValidator / validate_data.py 同步（含 recommended 中的信标引用）。
- 控制器：`slot_beacons`；`add_beacon`（下一个字母 = 现有最大之后，删除不重排、不复用）、`remove_beacon`、`move_beacon`、`can_place_beacon`（可行走格、含部署区外、不重叠）、`copy_route_to_beacons`；仅部署阶段可改；存档与「推荐阵型」都带信标；修改后世界重建 = 游标重置。
- UI：`BeaconLayer`（受裁剪的 MapLayer 下）：选中单位信标 + 连线骨白 3 px（部署 0.85 / 运行 0.45）、其他单位小号 0.3、运行中当前前往的信标闪烁、拖动落点提示；MapInput 右键布点 / 删点、左键拖动信标（拖动时障碍红纹）；单位面板"信标"列表（逐个删除）+ 预设路线下拉 + "复制为我的信标"；RuleRow：到点条件的信标下拉、沿信标的模式 / 起点下拉、等待秒数，运行中生效的等待行显示"等待中 X 秒"；悬停提示同样显示剩余秒数；整句模板进 strings.json；新增两条预设（Q-047）。
- 测试：`test_beacon_ui.gd`（8 条：字母分配、上限与非法格、移动与复制路线、仅部署可改 + 存档往返、推荐阵型带信标、整句模板、任意关卡下拉都有信标类、地图右键 / 拖动 / 矩形外 / 运行中）。test_readability 的淡入淡出用例改为按空闲帧轮询（wait_seconds 按物理时间计，headless 下会跑在补间前面，曾导致偶发失败）。
- 02 文档：§3 补 at_beacon / follow_beacons / wait 与信标存档结构。

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels）。
界面脚本无中文字面量。
GUT（严格告警模式）：Scripts 21 / Tests 169 / Passing 165 / Pending 4 / Asserts 870 / exit 0
run_playtests：25 scenarios, 0 problems；原 24 场景与 M8 基线逐行一致；level_03 beacons WIN 8.03 s（1×/2× 一致）
```

### 已知问题
- 第三关信标 B、C 在 x=13–14 列，1920 宽窗口下被旧侧栏盖住（Q-046，P3 解决）。
- 运行中不允许改信标（07 §3.5），信标列表在运行中只读。

## P3 Cost、出场选择、新 UI（A07、A08）—— 完成（2026-10-05）

### 完成标准核对
- [x] 8 关在新 UI 下 `run_playtests` 全通过：场景文件改为单位列表格式；25 场景 0 problems；原 24 场景胜负、时长与 state_hash **仍与 M8 完全一致**（free 关按出场顺序分配 u1…，模拟 id 与第一阶段槽位序号相同）
- [x] 1280×720 无截断：`docs/screenshots/p3/1280x720/level_01–08.png`（部署阶段 + 选中单位的对侧面板）；正式截图 `docs/screenshots/level_01–08.png` 已按新 UI 重拍
- [x] 测试：预算校验、最少单位、形态可用、迁移（test_deployment_validator 新增 2 条、test_levels_headless 新增 1 条并改写存档往返）；UI 走查（test_hud_layout 4 条：面板切侧、不挡选中单位、宽 520 / 高 896、点击空地与 Esc 隐藏、运行中可看不可改、出场卡拖放扣费 / 预算不足禁用 / 收回返还、fixed 关槽位卡无预算、敌人面板只读 RuleEditor）

### 逐项
1. 数据与校验：`units.json` 己方形态 `cost`；关卡 `roster`（mode / budget / available_forms / max_units / min_units / fixed_slots），旧 `slots` 报 DEPRECATED_FIELD；第七关 fixed，其余 free（预算见 Q-049，可用形态与人数见 Q-050）；free 关 recommended 按 `form` 摆放；DataValidator / validate_data.py 同步（含推荐阵型放得进预算）；`progression.json` 删 `slots`。
2. 存档 v2：`level_configs[level] = { units: [ { uid, form, slot?, pos?, rules, beacons } ], next_uid }`；v1 迁移（fixed 直接改写，free 关推形态并分配 u1…，失败条目保留在 legacy_v1 并以 SAVE_MIGRATION_FAILED 标记 invalid，不删除）；`unlocks.slots` 删除。
3. 控制器：以 uid 为键（fixed 关 uid = 槽位 id）；`add_unit / remove_unit（free = 删除返还）/ card_forms / can_add_form / budget_used / label_of / recommended_uid`；SimWorld 与 DeploymentValidator 改读 uid 配置（缺 form/index 时按槽位或推荐条目名推出，旧格式与测试兼容）；新校验码 BUDGET_EXCEEDED、TOO_FEW_UNITS、FORM_NOT_AVAILABLE。
4. HUD 重排（07 §5 / 08 ⑥）：顶栏 64（任务句点击展开任务面板下拉 + 目标闪烁）；全屏战场；底栏 120（出场卡 RosterCard：free = 形态卡含头像图标 / 名称 / Cost，fixed = 槽位卡；已用 / 预算；开始 / 重置 / 1× / 2× / 暂停；提示 / 导出）；对侧浮动面板 520 宽、顶栏与底栏之间（1080 下 896 高），选中单位在左半屏 → 面板在右、反之在左，0.15 s 滑入，点击空地 / Esc 隐藏，运行中可查看；敌人面板改用 read_only RuleEditor（特性在规则上方）；SlotItem 删除。
5. 截图工具新增 `--select=ally|enemy|none`（默认选中第一名己方单位以展示面板）。

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels）。
界面脚本无中文字面量。
GUT（严格告警模式）：Scripts 22 / Tests 178 / Passing 174 / Pending 4 / Asserts 960 / exit 0
run_playtests：25 scenarios, 0 problems；原 24 场景与 M8 基线逐行一致（含 state_hash）
```

### 已知问题
- 对侧面板在选中左侧单位时位于右侧，会盖住右侧的敌人（按 07 §5 设计：保证不挡选中单位）；点击空地可随时收起。
- 1280×720 为 canvas_items 等比缩放，小字号（如面板说明文字）在小屏上偏小但无截断。

## P4 静态加成、新任务类型机制（A09、07 §9）—— 完成（2026-10-05）

只做机制、校验、单元测试与 `tests/fixtures/` 下的最小测试关，未改任何正式关卡。

- `ModifierDef`（新）：`modifiers`（spawn / form / faction × 六项属性，值 × mul + add，按列表顺序，构建 SimWorld 时一次性应用，max_hp 变化时生命同步）；`SpawnDef.overrides` 以覆盖型加成在其后应用；LevelDefinition 解析，DataValidator / validate_data.py 校验引用与取值。
- 目标：`ObjectiveType.ESCORT`；`reach_zone` 允许作为胜利（`target` = spawn 或 `any_ally`，`count`）；`escort` 胜利 = 被护送者存活到达区域，失败由同目标 `unit_dead` 表达（Q-051，校验强制）；ObjectiveDef 记 `is_win`，`referenced_ids` 不含 any_ally。
- 表现：面板六项属性显示有效值，与形态基础值不同时注明"（+N 关卡加成）"（己方 / 敌方面板共用 `RuleText.stat_values`）；任务句模板 `reach_zone_win`、`escort`；胜利目标区金色框；护送对象头顶盾形目标标记。
- 测试：`tests/unit/test_modifiers_objectives.gd`（8 条）+ `tests/fixtures/level_p4_fixture.json`（10×6 护送测试关）：测试关无数据错误、加成与覆盖值、运行中不变、面板文案、护送到达即胜、护送对象死亡即败、any_ally 计数（1 名不胜 / 2 名胜）、指定单位 reach_zone、各类校验错误。

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels）。
界面脚本无中文字面量。
GUT（严格告警模式）：Scripts 23 / Tests 186 / Passing 182 / Pending 4 / Asserts 995 / exit 0
run_playtests：25 scenarios, 0 problems；原 24 场景与 M8 基线逐行一致
```

## P5 章节框架、节点连线选关、剧情播放器（A12、A15）—— 完成（2026-10-05）

### 完成标准核对
- [x] 从主菜单经章节地图进入 8 关并通关解锁下一节点：选关界面改为章节地图节点连线（`data/chapters/chapter_01.json`，8 节点，编号不变）；解锁 = 存在一条已完成的前驱连线；`test_completing_levels_unlocks_next_nodes_in_order` 依次通关 8 关，每关解锁下一节点；实窗截图核对节点 / 连线三种状态
- [x] 每关开始、胜利、失败三处播放对应 story 文件：`<level_id>_intro / _win / _lose` 共 24 个（`tools/make_story_placeholders.py`），场景级测试覆盖开始 / 胜利 / 失败三处触发
- [x] 删除任一 story 文件后该处静默不触发（无弹窗、无告警）：`test_deleted_story_files_are_silently_skipped`（临时剧情目录只保留 _win：开始与失败均不显示任何界面、GUT 未捕获任何 error / warning，胜利照常播放）、`test_missing_or_empty_story_is_silent`（文件缺失 / scenes 为空）

### 逐项
- 数据：`ChapterDef`（区域、节点 pos / links / boss / story_on_unlock / legacy_ids，任意数量节点）与 `data/chapters/chapter_01.json`（区域名与坐标为临时值，Q-053）；`data/stories/*.json`（briefing 对白原样迁入 `_intro`、`ch1_boss_outro` 迁入 `level_08_win`，其余占位）；关卡删除 `briefing.dialogue`、`rewards.story_id`（出现即 DEPRECATED_FIELD），strings 删除 `stories` 占位；DataRegistry 加载 / 校验章节、`load_story()`；validate_data.py 同步章节与剧情格式校验；导出 include_filter 追加 chapters / stories。
- 运行：`GameState.is_level_unlocked` 按章节连线判断；存档 v3（`stories_seen`，迁移补齐）；`StoryPlayer`（由 DialogueOverlay 升级，同一场景与节点名）：说话人、立绘、背景、逐字文本，剧情后可接机制提示卡；缺失 / 空剧情返回 false 且只打印 verbose 日志；HUD 在开始 / 胜利 / 失败三处按固定命名调用；机制提示卡只跟在开始剧情之后，同时列入"机制说明"顶部（Q-052）；章节节点 story_on_unlock 首次解锁后进入地图播放一次。
- 选关界面：章节地图铺底、节点按 pos 摆放（宽屏居中）、连线已完成金 / 可挑战骨白 / 锁定暗紫，节点状态色、首领节点更大、悬浮显示关卡 / 区域 / 状态。
- 测试：`tests/integration/test_chapter_story.gd`（12 条）。导出版重新导出（pck 含 chapters / stories），项目外运行无错误。

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels / chapters / stories）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 24 / Tests 198 / Passing 194 / Pending 4（Q-016、Q-021、Q-027、Q-028，均为数值项）/ Asserts 1104 / exit 0
run_playtests：25 scenarios, 0 problems；原 24 场景胜负、时长与 state_hash 与 M8 基线逐行一致
export：exit 0，exe + 125 MB pck
```

### 第二阶段程序任务包小结
P0–P5 全部完成。暂缓项按任务包保持不动：关卡编辑器、数值调整、关卡内容（4 个数值 pending 测试保持 pending）。资源方并行工作中的 `assets/backdrops`、`assets/grounds`、`assets/sprites/ground_marks`、raider / warden / priest 重画未由程序侧入库；资源方交付报告后需改关卡 `scene` 数据切换 backdrop / ground，并重跑 `apply_import_presets.py`、`make_theme.gd`、重拍截图。新增问题见 QUESTIONS Q-041～Q-053。

## 接入资源方 P2 素材（换机开发指南 §5）—— 完成（2026-10-05）

换机后第一项工作。环境：Windows 10，Godot 4.7.2 stable，RTX 3060 Laptop，项目路径 `G:\人工神明-侧面开发\AI版本\`。

### 完成标准核对（ASSET_REPORT_P2「程序方仍需执行」）
- [x] Godot 导入：`--import` 无错误；`apply_import_presets.py` 补齐新目录规则后改动 22 个 .import，再导入无错误
- [x] 关卡 `scene` 切换：8 关 backdrop → `assets/backdrops/`，ground → `assets/grounds/<biome>_a.png`（`_b` 自动交替），ground_tint → `#ffffff`（Q-045）
- [x] 战场框与边缘景物核验：`print_playfield_rects.py` 算出的玩法矩形外扩半格，与报告中 8 张背景的安全区坐标逐关吻合；8 关实窗截图中玩法矩形内无竖立景物
- [x] 地面与标识接入后的显示：地面贴图铺在玩法矩形内，第 3、4、5、6、8 关障碍格显示 ground_marks 贴片
- [x] raider / warden / priest 重画贴图：第 1、3、6 关截图核对，均已非人偶脸（骨甲怪 / 骨冠 / 兜帽）
- [x] 对白推进音效：引擎内 `dialogue_advance.ogg` 时长 0.7001 s，与报告裁切后 0.700125 s 一致（未做人工试听）
- [x] Cinzel 700 运行时粗体：原 `.tres` 不加粗（Q-041），改整数 tag 后宽度 396 → 423，已加粗
- [x] `make_theme.gd` 重跑（主题内容无变化）；8 张截图重拍 `docs/screenshots/level_0X.png`

### 改动文件
- `godot/data/levels/level_01–08.json`（仅 `scene` 一行）
- `godot/tools/apply_import_presets.py`；`godot/assets/{backdrops,grounds,sprites/ground_marks}/*.import`（22 个）
- `godot/assets/fonts/Cinzel-Bold.tres`
- `godot/tools/take_screenshots_impl.gd`（截图期间临时全解锁，不依赖本机存档进度）
- `docs/screenshots/level_01–08.png`；`docs/CHANGELOG.md`、`docs/QUESTIONS.md`（Q-041 关闭、Q-045 结果）

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels / chapters / stories）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Tests 198 / Passing 194 / Pending 4（Q-016、Q-021、Q-027、Q-028）/ exit 0
run_playtests：25 scenarios, 0 problems；结果表与改动前逐行一致
```

### 已知问题
- 导出模板仍未在本机安装，导出版未重新导出（导出版暂为旧背景）。
- 对白音效未人工试听；Godot 把 `dialogue_advance.wav` 导入为 QOA，现行引用为 ogg，不受影响。

## 第三阶段 P0 收尾与直接删改 —— 完成（2026-10-05）

提交 `ce038b6`（代码）；导出模板在 P1 期间下载完成，导出验证记在下方 P1 段落之前的"导出"一节。

### 完成标准核对
- [x] GUT 全绿（pending 仅 4 数值项）：普通 + 严格告警均 Scripts 26 / Tests 210 / Passing 206 / Pending 4（Q-016、Q-021、Q-027、Q-028）/ exit 0
- [x] `run_playtests -- --check` 全等：25 场景与基线逐项一致；信标场景改数字编号后 `level_03 / beacons` 仍 3408529087
- [x] 导出版可运行：见下"导出"
- [x] 8 关截图重拍 `docs/screenshots/level_0X.png`（运行中 t=3：血条在脚下、无路线虚线）；部署阶段截图 `docs/screenshots/p3_0/level_03.png`、`level_08.png`（地板高亮、敌方初始位置红标、移除按钮与说明、清空 / 重试、角色卡头像）

### 逐项
1. 文档路径：00 §2、第二阶段两份任务包改 G:（CHANGELOG）。
2. 导出模板与导出：见下。对白音效：无法人工试听，波形检查发现开头 0.22 s 静音（Q-062）。
3. `run_playtests`：记录写 `state_hash`；`tools/playtest_baseline.json`；`-- --check` 比对（人为篡改两项 → 打印 2 处差异、exit 1；未改 → exit 0）；`-- --update-baseline` 重写基线。00 §2 加入命令。
4. 删除导出：HUD `ExportButton`、结算面板导出按钮、`export_record()`、`PlaytestRecord.save()`、`ui.export*`；`playtest_record.gd` 移到 `tools/`。
5. 血条移到脚下（`HP_OFFSET_Y = +10`，Q-057）；目标标记与状态图标用独立的头顶高度常量。
6. 删除 `RouteLayer`（及 BattleRoot 接线）；敌方初始位置红色地面标记画在 `FloorHighlight`（部署阶段）。
7. 信标：`BEACON_SOFT_CAP = 64`、数字 id、删除不重排、旧字母映射 + DEPRECATED_FIELD 提醒、存档 v4 迁移、试玩场景与 presets 中的字母改数字（8 关 recommended 本无信标）、validate 同步。
8. 拖拽虚影（`Art.unit_texture`，60%、cell_px × 1.6、脚底锚点、合法金 / 非法红）；角色卡头像 = portraits × portrait_mask 裁圆。
9. 「移除」按钮 + 小字说明（仅部署阶段已放置单位）；移除 / 拖出战场 / 清空后 BattleRoot 发 `unit_selected(-1)` 收起侧栏；`DeploymentValidator.place_problem()` 六种原因 + toast（Q-054、Q-055）。
10. 「清空」（`controller.clear_units()`，不弹确认，toast 人数，fixed 关见 Q-058）；「重置」→「重试」（部署阶段禁用）。
11. `FloorHighlight` 取代 `ObstacleHighlight`：部署阶段选中己方单位 / 拖拽单位 / 拖信标时可行走格骨白 0.18、障碍格红 0.45，运行中不显示。

### 测试
- 新增：`tests/integration/test_floor_highlight.gd`（选中显示 / 取消隐藏 / 选敌不显示 / 运行中隐藏 / 障碍格红 / 敌方初始位置标记）、`tests/integration/test_deploy_feedback.gd`（六种原因、与 can_place 逐格一致、非法放下 toast 且单位不动、拖出战场移除、虚影、移除后 unit_selected(-1)、清空后 placements 为空且预算归零、fixed 关清空）。
- 更新：`test_beacon_ui.gd`（数字编号、超 8 个到软上限、字母兼容）、`test_save_manager.gd`（v3→v4 迁移）、`test_hud_layout.gd`（无导出、有清空、重试文案与可用阶段）、`test_beacons_wait_scenario.gd`、`test_playfield_input_clipping.gd`；删除 `test_readability` 中针对 ObstacleHighlight 的用例。

### 测试输出摘要
```
数据校验通过（units / traits / presets / strings / progression / biomes / levels / chapters / stories）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 26 / Tests 210 / Passing 206 / Pending 4 / Asserts 1324 / exit 0
run_playtests -- --check：25 scenarios, 0 problems；all 25 scenarios identical to baseline
```

### 导出（P0-2，模板在 P1 期间到位，用 P1 末的代码导出）
- 官方 tpz SHA-512 与 SHA512-SUMS 一致，只装 Windows 模板（CHANGELOG）。
- `--export-release "Windows Desktop"`：exit 0，`export/ArtificialDeity_Demo.exe` 109 MB + `.pck` 122 MB。
- 复制到项目外目录 headless 运行 600 帧：无脚本错误（仅有编辑器同样会打印的退出时泄漏提示）。

### 已知问题
- 资源方正在 `assets/ui/` 放入 R1 设计图（`main_menu/design.png` 等，未入库、未经我改动）；导出的 pck 会一并打包这些设计图，P5 时应把 `assets/ui/*/design*.png` 加入 exclude_filter。

## 第三阶段 P1 指令编辑重构与 Cost 框架 —— 完成（2026-10-05）

### 完成标准核对
- [x] GUT 全绿：普通 + 严格告警均 Scripts 27 / Tests 226 / Passing 222 / Pending 4 / exit 0
- [x] `run_playtests -- --check` 全等
- [x] 8 关推荐阵型在新编辑器下可应用、可开始：`test_all_recommended_apply_and_start_in_new_editor`（每名单位的指令行全部建出，8 关均可 start）
- [x] 截图：侧栏指令编辑两条件状态 `docs/screenshots/p3_1/level_04.png`（行为在上；条件一「射程内敌人」、「或」、条件二「可见敌人」；整句"存在射程内敌人时，或视野内存在敌人时，攻击最近的敌方单位"；侧栏「形态 3 ＋ 指令 0」）

### 逐项
1. `data/commands.json`（§5.1 + `defaults`，Q-060）；`CommandCatalog`；`DataRegistry.get_commands()`；unlock_key 可追溯校验（加载 + validate_data.py）；presets.json / PresetDef 删除，02 §4 改写、07 补注、CHANGELOG。
2. `RuleRow` 重做：`[≡][行为▾][目标选择▾ 目标类型▾ | 模式▾ 起点▾ | 秒数 | 路线▾][删除]` / 条件一 / 「与|或」条件二（默认「无」）/ 整句 / 为何不成立；target_distance 在行为无目标时于条件行显示目标选择；下拉不按最长项撑宽（侧栏仍 520）。`RuleEditor` 添加流程 = 行为列表。敌人只读面板同布局、条件全显。
3. `enabled`：UI 恒写 true；读档 false → true；推荐阵型停用条目略去（Q-059）。
4. Cost 框架：`budget_used()` / 校验 / 放置判断含指令 Cost；HUD `已用 / 预算`（原有）；侧栏「形态 N ＋ 指令 M」（free 关）。commands.json 全 0。
5. 02 文档补丁：commands 字段、presets 删除、`summary` 预留、enabled / condition_mode 的 UI 语义、信标数字编号、存档 v4。
6. 结算面板"新指令"改为"新目标类型"（Q-061）；整句多条件按「且 / 或」连接。

### 测试
- 新增 `tests/unit/test_commands_catalog.gd`（目录顺序 = 默认项；解锁键与 allowed 过滤；player:false 不进菜单；cost 求和；全 0 时已用 = 第二阶段；正数 cost 计入预算并阻止开始；停用条目略去前后哈希相同；8 关推荐阵型可应用可开始）。
- 重写 `tests/unit/test_rule_editor.gd`（添加 → 条件始终、目标最近 / 任意、等待 0.5 s、信标起点 1；条件二后与 / 或可见并写 condition_mode；条件二改「无」回到 all；两条件上限；删除；拖拽排序；运行中禁用；敌人 3 条件只读全显；旧存档 enabled:false 读作 true 并写回）。
- `test_deployment_validator.gd` 增指令 Cost 超预算（fixture 把 attack cost 设为 3）。

### 测试输出摘要
```
数据校验通过（units / traits / commands / strings / progression / biomes / levels / chapters / stories）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 27 / Tests 226 / Passing 222 / Pending 4 / Asserts 1508 / exit 0
run_playtests -- --check：all 25 scenarios identical to baseline
```

## 第三阶段 P2 设置浮窗、任务弹窗、右上角功能组、底栏重排 —— 完成（2026-10-05）

### 完成标准核对
- [x] GUT 全绿：普通 + 严格告警均 Scripts 28 / Tests 233 / Passing 229 / Pending 4 / exit 0
- [x] `run_playtests -- --check` 全等
- [x] 四种分辨率截图 `docs/screenshots/p3_2/{1920x1080,1920x1200,2560x1080,1280x720}/level_03.png、level_08.png`（部署阶段，侧栏分别在右 / 右；无截断、无重叠，侧栏不被底栏覆盖）

### 逐项
1. `SettingsOverlay`（`scenes/ui/settings_overlay.tscn`）：SceneRouter 常驻，子 CanvasLayer 层 100（黑幕 128）；`open_settings / close_settings / is_settings_open`，`goto_settings()` 改为打开浮窗；半透明遮罩、点击遮罩不关闭、Esc 或「关闭」关闭；每次打开按当前设置重建；关闭写存档；切换场景时自动关闭。独立 `settings.tscn / settings.gd` 删除。入口：主界面「设置」、章节地图右上「设置」（P3 改版前先加在现有界面）、局内右上角「设置」。局内运行中打开 → `controller.pause()`，关闭保持暂停（决策 ⑦）；浮窗打开时战斗快捷键（空格等）无效。
2. 顶栏右上角：重试、1×、2×、暂停 / 继续、设置、退出；退出下方「任务」「机制说明」；「任务」悬浮弹窗（ObjectivePanel 内容不变，带标题与关闭），点击顶栏任务句同样打开并让特殊目标闪烁；任务 / 机制说明 / 提示面板三者互斥（Q-063）。
3. 底栏：开始左侧放大 240×96；角色卡 + 清空 + 提示 / 推荐阵型居中；预算最右。
4. 布局数字集中到 `UiKit` 常量；指令行 target_distance 的目标下拉另起一行（Q-064）；顺带修正 `main_menu.gd` 中严格模式下才暴露的变量名遮蔽（`tr`）。

### 测试
- 新增 `tests/integration/test_settings_overlay.gd`（常驻层级、goto_settings 兼容、点遮罩不关、Esc / 关闭、主界面 / 章节地图 / 局内三处打开、局内运行中打开暂停且关闭后仍暂停、浮窗打开时快捷键无效、即时生效、关闭写存档、再开显示当前值）。
- `test_hud_layout.gd`：右上角功能组节点与顺序、任务 / 机制说明在退出下方并右对齐、底栏顺序与开始尺寸、卡片组居中、任务弹窗开合与互斥；侧栏高度断言改为扣除右上角一行。

### 测试输出摘要
```
数据校验通过（units / traits / commands / strings / progression / biomes / levels / chapters / stories）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 28 / Tests 233 / Passing 229 / Pending 4 / Asserts 1567 / exit 0
run_playtests -- --check：all 25 scenarios identical to baseline
```

## 第三阶段 P3 章节地图改造 —— 完成（2026-10-05）

### 完成标准核对
- [x] GUT 全绿：普通 + 严格告警均 Scripts 29 / Tests 241 / Passing 237 / Pending 4 / exit 0
- [x] 主菜单 → 地图 → 选节点 → 详情 → 进入，8 关通关解锁下一节点：原有 `test_completing_levels_unlocks_next_nodes_in_order` 照旧通过；新测试覆盖选中 / 详情 / 进入按钮
- [x] 截图 `docs/screenshots/p3_3/`：`chapter_start.png`（前 3 关已通关，默认选中第 4 关并居中，详情面板）、`chapter_end.png`（滚到最右，第 25 节点选中）、`chapter_detail_completed.png`（已完成关卡，回放剧情可用）
- [x] `run_playtests -- --check` 全等

### 逐项
1. 数据：`chapter_01.json` 扩到 25 节点（9–25 占位）、`map_size`；`ChapterDef` 以 `id` 索引（缺省 = level）、`node_of(id)` / `node_of_level()`、占位节点恒锁定、指向占位节点的连线为锁定色；校验（加载 + validate_data.py）：占位节点不得有 level / boss / story_on_unlock，无 level 时 id 必填，map_size 合法；关卡可选 `summary`。
2. 界面（`level_select.tscn / .gd` 重写）：左地图视口（窗口宽 − 560）+ 右详情面板；左键按住空白拖动、滚轮横移，范围 clamp，6 px 点击阈值，无惯性；点击节点只选中（金框 + 名牌高亮）；默认选中最新可挑战节点并滚到中央。布局数字在 UiKit。
3. 详情：编号与名称、区域、summary（回退 subtitle）、任务一句话、状态；「进入」（锁定 / 占位禁用，锁定时列出前置关卡）；「回放剧情」下拉只列已看过的 `_intro / _win / _lose`，StoryPlayer 播放、不改 seen（Q-065）。
4. 节点表现：`node_art` 可选（`assets/ui/chapter/nodes/<id>.png`），缺省为程序化按钮；地图平铺占位（Q-066）。顶栏「设置」保留（P2）。
5. 截图工具 `--screen=chapter`。

### 测试
- `test_chapter_story.gd`：25 节点结构、占位节点锁定、`node_of(id)`、指向占位节点的连线锁定色、占位节点校验；地图界面节点状态 / 摆放（按缩放）/ 名牌。
- 新增 `tests/integration/test_level_select_ui.gd`：视口与详情布局、拖动与滚轮 clamp 与 6 px 阈值、能滚到第 25 节点、默认选中最新可挑战并居中、点击节点不进关、进入按钮触发、锁定时禁用并说明前置、占位节点不可进入、回放列表与 stories_seen 一致且播放不改 seen。

### 测试输出摘要
```
数据校验通过（units / traits / commands / strings / progression / biomes / levels / chapters / stories）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 29 / Tests 241 / Passing 237 / Pending 4 / Asserts 1679 / exit 0
run_playtests -- --check：all 25 scenarios identical to baseline
```

## 第三阶段 P4 鼠标触边横向移动 —— 完成（2026-10-05）

### 完成标准核对
- [x] GUT 全绿：普通 + 严格告警均 Scripts 30 / Tests 245 / Passing 241 / Pending 4 / exit 0
- [x] 哈希全等：`run_playtests -- --check` 25 场景与基线一致（镜头不碰模拟）
- [x] 截图：`docs/screenshots/p3_4/pan_max/level_03.png`（平移到最右，原先被右侧侧栏挡住的骸柱一列可见）、对照 `pan_0/level_03.png`；8 关运行截图重拍（Backdrop 加宽后的画面，Q-067）

### 逐项
- `BattleRoot.pan_x` + `set_pan()`（clamp ±PAN_MAX = 520）；MapLayer / TargetLines / UnitLayer / FX / Range / Debug 整体平移 −pan_x，只有横向；Backdrop 绘制宽 = 视口宽 + 2·PAN_MAX（cover、中心对齐）随偏移平移，上限处不露底。
- 坐标换算：`screen_to_sim / screen_to_cell / unit_at_screen / beacon_at_screen` 经地图层变换自动含偏移，`in_playfield` 用 `unpan()` 减去偏移；`unit_screen_pos` 为平移后的视图位置（侧栏切侧随之正确）。
- 触边条件：有选中单位且侧栏可见；鼠标 x < 24 或 > 窗口宽 − 24；600 px/s；取消选中或开始战斗 0.2 s 回正（Q-068）。常量在 UiKit。
- 截图工具 `--pan=max|min|<px>`。

### 测试
- `test_playfield_input_clipping.gd` 增 `test_coordinates_follow_camera_pan`（三种偏移下 screen_to_cell / unit_at_screen 正确、视图随镜头平移、平移后矩形外点击仍无效、clamp）。
- 新增 `tests/integration/test_camera_pan.gd`（无选中不平移；距边 ≥ 24 px 不触发；触边后 pan_x 单调增长到上限、速度 600 px/s、只横向、层同步平移、backdrop 不露底；取消选中回 0；左边缘反向；开始战斗回 0）。

### 测试输出摘要
```
数据校验通过（units / traits / commands / strings / progression / biomes / levels / chapters / stories）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 30 / Tests 245 / Passing 241 / Pending 4 / Asserts 1776 / exit 0
run_playtests -- --check：all 25 scenarios identical to baseline
```

## 第三阶段 P5–P7 —— 等待资源（2026-10-05）

- P5 依赖 R1（主界面 + 设置浮窗的 design.png + slices + manifest.json）。`godot/tools/ASSET_REPORT_P3.md`（V5）说明：R1 目前只有三张整图审阅稿（`assets/ui/main_menu/design.png`、`design_error.png`、`assets/ui/settings_overlay/design.png`），**待用户审阅确认**，尚未拆分切片、未出 manifest；R2–R5 未开始。
- 因此 P5（apply_ui_manifest / ui_diff / 拼接与 ≤ 2% 比对）、P6（R2 / R3 / R5 换皮）、P7（R4 大地图）本轮未开始；程序侧 P0–P4 已全部完成，SettingsOverlay 场景已就绪可供 R1 拼接。
- 资源方放入的 `assets/ui/` 设计图与 `tools/ASSET_REPORT_P3.md`、`docs/UI_INVENTORY.md` 未经程序方改动、未入库（由资源方 / 用户提交）。

## 第三阶段 P5 美术管线试做：主界面 + 设置浮窗 —— 完成，用户目视通过（2026-10-05）

资源：`godot/tools/ASSET_REPORT_P3.md` §11（用户已批准 V5 整图，R1 切片 / 四态 / 公共件 / manifest / 文字绑定已交付）。

### 完成标准核对
- [x] 两个界面与设计图比对 ≤ 2%（`tools/ui_diff.py`，比对图与报告在 `docs/screenshots/ui_diff/`）：

| 画面 | 严格（任一通道差 > 0） | 容差 2/255、排除动态区 | 再豁免文字反走样（±1 px） | 结论 |
|---|---:|---:|---:|---|
| main_menu | 0.4218% | 0.2394% | 0.1537% | 通过 |
| main_menu_error | 0.6794% | 0.4952% | 0.3192% | 通过 |
| settings_overlay | 3.4802% | 0.9786% | 0.6552% | 通过 |

  - 设置浮窗忽略区只有日志路径（动态值）；滑条、开关、字体下拉按设计样例数值截图。浮窗设计图下层的主菜单文字同样按文字区处理（`--context-manifest`）。
  - 非文字区域残差：主界面 0.003%（最大 14/255）；设置浮窗面板与关闭按钮 18 个像素（最大 5/255），其余全部为文字栅格化差异（Q-070-7）。严格指标 3.48% 主要来自遮罩下 1–2/255 的取整差，与资源方回拼报告一致。
- [x] 用户目视确认：拼接通过、管线无误（2026-10-05）
- [x] GUT 全绿：普通 + 严格告警均 Scripts 31 / Tests 249 / Passing 245 / Pending 4 / exit 0
- [x] 哈希全等：`run_playtests -- --check` 25 场景一致
- [x] 格式问题写入 QUESTIONS（Q-069 ~ Q-071）并补到 10 §1.2

### 逐项
1. `tools/apply_ui_manifest.py <screen>…`：校验 manifest（kind、id 唯一、rect 在设计尺寸内、文件存在且在 assets/ui 内、按钮四态、九宫格边距）→ 生成 `assets/themes/ui_<screen>.tres`（按钮 / 文字 / 九宫格面板 / 下拉及其弹出列表的类型变体）与 `data/ui_layout/<screen>.json`，并把引用贴图的 .import 设为 Lossless、无 mipmap；合并 error_manifest。
2. `tools/ui_diff.py`：严格 / 容差 / 文字豁免三档指标、可配置忽略区（元素 id 或矩形）、差异图（红 = 不同、黄 = 文字豁免、蓝 = 忽略）、JSON 报告、按阈值返回退出码。
3. `UiKit`：`ui_layout / layout_element / layout_rect（唯一的设计 → 屏幕换算：设计画布居中，铺满画布的元素 cover）/ layout_text_rect / build_from_layout / relayout`；`main_menu.gd` 与 `settings_overlay.gd` 改为按布局建节点，不含布局数字；节点名保持（StartButton、SettingsButton、CloseButton、Volume_*、Toggle_* 等），功能与第三阶段 P2 一致。
4. 渲染：菜单类界面关闭 HDR 2D（Q-069）。截图工具 `--screen=main_menu|main_menu_error|settings_overlay`（设置浮窗按设计样例数值，不写存档）。
5. 多分辨率：`docs/screenshots/ui_diff/{2560x1080,1920x1200,1280x720}/` 设计画布居中、背景 cover，无截断。
6. 导出：排除设计图 / 预览 / manifest 等非运行文件，显式包含 `data/ui_layout/*.json`；重新导出、项目外运行无错误。

### 测试
- 新增 `tests/integration/test_ui_layout.gd`（布局与 manifest 一一对应、主题含全部变体、错误态元素标记；layout_rect 在 1920×1080 / 21:9 / 16:10 的换算与 cover；主界面节点位置 = 布局、文字取 key、焦点复用 hover、错误条只在数据错误时出现；设置浮窗滑条 80% 时填充宽与把手位置 = 设计样例、0% 无填充）。
- `test_settings_overlay.gd` 开关改为 TextureButton；`test_level_select_ui.gd` 不再依赖本机存档里已看过的剧情。

### 测试输出摘要
```
数据校验通过（units / traits / commands / strings / progression / biomes / levels / chapters / stories）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 31 / Tests 249 / Passing 245 / Pending 4 / Asserts 1871 / exit 0
run_playtests -- --check：all 25 scenarios identical to baseline
ui_diff：main_menu 0.1537% / main_menu_error 0.3192% / settings_overlay 0.6552%（阈值 2%）
```

### 已知问题
- 局内打开设置浮窗时处于 HDR 2D，遮罩色与设计图略有差别（Q-069）；换皮界面不随字体大小设置缩放（Q-071）。
- 按任务包，用户目视确认通过前不开始 P6。

## 第三阶段 —— 挂起等待资源 R2–R5（2026-10-05）

- P0–P5 完成。拼接方法与流程沉淀为 `docs/12_UI拼接方法与流程.md`，P6 / P7 交给专门的拼接会话按该文档执行。
- 等待资源方 R2（局内 HUD、角色详情与指令编辑）、R3（章节地图）、R4（场景大地图）、R5（部署反馈小件）；资源报告更新后按 12 §1 开工。R2 开工前需先定 HDR 2D 下的局内 UI 比对方案（Q-069）。

## 第三阶段 P8 UI 动效 —— 第 1–3 条完成（按钮部分），用户目视通过（2026-10-05）

任务包 P8（10 §1.5，追加任务）：不依赖 R2–R5，与等待资源并行。本轮完成主界面三个按钮的动效与动效机制；标题艺术字（1b）等待资源 R6a。**用户目视通过前不做第 4 条（通用化）。**

### 完成标准核对（本轮范围）
- [x] 1a 主界面开始 / 设置 / 退出的按钮动效：自主设计，Tween + CanvasItem 着色器，只用 R1 现有四态切片，未画新素材
- [ ] 1b 标题艺术字动效：等资源 R6a（`assets/ui/main_menu/art_text/` + `motion.md`），尚未交付
- [x] 2 `UiKit.motion_enabled` 总闸；`take_screenshots --no-motion`、`ui_diff.py --no-motion`；参数在 `data/ui_motion.json`，代码里没有时长和幅度常量
- [x] 3 连续帧 + gif + 设计说明：`docs/screenshots/motion/main_menu/`（README.md 写明设计意图与参数）
- [x] 用户目视（2026-10-05）：通过，只要求加大选中与未选中的差别，已在第 4 条一并调整（第二版 gif 已替换）
- [x] `--no-motion` 静止态 diff ≤ 阈值：与 P5 相同，main_menu 0.1537% / main_menu_error 0.3192% / settings_overlay 0.6552%
- [x] GUT 全绿（普通 + 严格告警）；`run_playtests -- --check` 25 场景一致
- [x] 主界面 1080p 60 fps：见下方 perf 输出

### 逐项
1. `scripts/ui/button_motion.gd`（ButtonMotion）：作为按钮的内部子节点（`show_behind_parent`）挂载。按钮原有的六种样式换成内边距相同的空样式，背景改由三层面板绘制：底层（normal / disabled）、hover 层、pressed 层，各层不透明度 = 状态权重。每帧按按钮绘制状态求目标态（焦点按 hover 处理），状态变化时杀掉当前 Tween、从当前权重出发补间，所以可以随时打断、不残留。disabled、首帧、总闸关闭时直接落位。
2. `assets/shaders/button_sheen.gdshader`：从贴图本身取金色（r − b 平滑阶跃），叠加一次性斜向光带与 hover 呼吸；只用 `TIME` 与自身 uniform。
3. `data/ui_motion.json`：hover_in / hover_out / press / release（时长 ≤ 0.25 s）、按下缩放、文字提亮 / 压暗、光带、呼吸、金色阈值；`validate_data.py` 校验曲线名与时长（超过 0.25 s 给提醒）。
4. `UiKit.motion_enabled / motion_params / motion_trans / motion_ease / attach_button_motion`。`_focus_as_hover` 对挂了动效的按钮不再改样式。
5. `main_menu.gd`：三个按钮挂动效；悬停即取焦点（Q-072）。
6. `perf_check` 顺带修复：截图工具早已改用 `ALL_UNLOCKED`，perf_check 没跟着改，在新机器上第八关被"形态未解锁"校验挡住、开始失败（P8 之前就已失效）。现已同样临时使用 `ALL_UNLOCKED`，并等待战斗场景就绪。
7. 工具：`take_screenshots` 支持无值开关（`--no-motion`）和绝对路径 `--out`；`--screen=main_menu_motion`（需 `--fixed-fps 60`）用脚本化鼠标事件输出连续帧；截图旁写 `<png>.meta.json`。`ui_diff.py --no-motion` 读该文件，确认比对的是静止态。`perf_check` 在第八关之前先测主界面动效帧率。

### 测试
- 新增 `tests/integration/test_ui_motion.gd`（8 项）：
  - 参数来自数据，状态过渡 ≤ 0.25 s。
  - 总闸关闭时不挂节点、不建 Tween，位置 / 尺寸 / 缩放 = 布局。
  - 静止普通态与原样式一致（底层即原 normal 样式，空样式保留内边距）。
  - 焦点呈 hover，悬停取焦点后原焦点按钮回普通态。
  - hover / pressed / 回弹 / 移出均在 0.25 s 内收敛，缩放和文字提亮幅度来自数据。
  - disabled 不建 Tween、不放光带、底层换 disabled 样式。
  - 连续快速切换后无残留（权重、缩放、光带、文字颜色）。
  - 运行中关闭总闸立即落位。
- `test_ui_layout.gd` 的主界面静止态用例在总闸关闭下运行（验证 P5 的焦点复用 hover 约定）。

### 测试输出摘要
```
数据校验通过（units / traits / commands / strings / progression / biomes / levels / chapters / stories / ui_motion）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 32 / Tests 257 / Passing 253 / Pending 4 / Asserts 1948 / exit 0
run_playtests -- --check：all 25 scenarios identical to baseline
ui_diff --no-motion：main_menu 0.1537% / main_menu_error 0.3192% / settings_overlay 0.6552%（阈值 2%）
perf_check（RTX 3060 Laptop，1920×1080，关闭垂直同步）：
  main_menu motion: frames=7055 real=6.00s avg=1175.8 fps | 1% low=569.5 fps | worst=315.7 fps
  level_08 2x: WIN 17.30s | avg=261.3 fps | 1% low=97.7 fps；reset x20 nodes / orphan / resources delta 0
```

### 已知问题 / 待定
- Q-072：主界面焦点跟随鼠标（待架构方确认是否推广到菜单类界面）。
- Q-073：现有单位着色器可能把贴图颜色乘了两次（本轮未改）。
- 光带 0.55 s 长于 0.25 s：它是一次性点缀，不是状态过渡，不阻塞任何状态。

## 第三阶段 P8 第 4 条：按钮动效通用化 + 选中对比加大；Q-073 着色器修正 —— 完成（2026-10-05）

用户目视意见：选中与未选中差别太小，其余通过；Q-072、Q-073 按推荐处理；继续后续工作。艺术字部分（1b 主界面标题、4 中按决策 ⑭ 逐个接入）仍等资源 R6a / R6b。

### 完成标准核对
- [x] 选中对比加大：主界面 `button_menu` 档选中时底板提亮 30%、金色常亮加强 45%（底板与金色分开提亮，金色不发白）、文字明显提亮、整体右移 14 px；gif 与关键帧已换成第二版（`docs/screenshots/motion/main_menu/`）
- [x] 按钮动效经 `UiKit` 自动挂到全部按钮，不逐界面改：SceneRouter 启动时装 `node_added` 钩子，帧末挂通用档；程序化占位界面、设置浮窗、章节地图、HUD、侧栏指令编辑都生效
- [x] 每个界面一份 `--no-motion` 报告：`docs/screenshots/motion/static/REPORT.md`
  - 换皮三界面与设计图的比对和 P5 相同；
  - 章节地图三张、局内三关在"开启动效、不操作"时与不挂动效逐像素相同；
  - 主界面的差别只来自默认焦点的选中态。
- [x] Q-072 采纳：焦点跟随鼠标改为档开关，只有主界面档开启
- [x] Q-073 修正：五个着色器改用 `COLOR`；A/B 实测原写法亮度只有 68%（SDR）/ 55%（HDR）；局内前后对比在 `docs/screenshots/q073/`，**请目视单位外观**
- [x] GUT 全绿（普通 + 严格告警）；`run_playtests -- --check` 25 场景一致；1080p 帧率见下
- [ ] 艺术字：等 R6a / R6b

### 逐项
1. `data/ui_motion.json` 分档：通用 `button` 与主界面 `button_menu`（`extends` 浅合并）。新增 `hover_lift`、`hover_boost`、`hover_nudge_px`、`focus_follows_mouse`。`validate_data.py` 逐档校验（含 extends 指向）；格式写入 02 §12。
2. ButtonMotion：
   - 选中右移：背景层位移，文字靠空样式的左右内边距同步平移，内边距之和不变，所以最小尺寸不变。
   - 外部代码改按钮样式时（如章节地图节点按选中重设样式），下一帧检测到并重新接管，不会重复绘制。
   - 外部设的文字颜色在动效期间记下，结束后恢复。
   - 切换按钮（1× / 2× 等）的按下常态只换 pressed 样式，不缩放、不改文字；鼠标悬停时照常提亮。
3. `UiKit.install_button_motion_hook / wants_button_motion`：不挂的有 flat 按钮、CheckBox / CheckButton / MenuButton / ColorPickerButton、带 meta `no_motion` 的按钮。延迟挂载按实例 id 取回，按钮在同一帧被释放也不报错。
4. 着色器 `button_sheen`：底板提亮只作用于非金色部分。
5. 12 拼接流程文档：按钮动效已自动挂，界面脚本不用处理。

### 测试
- `test_ui_motion.gd` 增至 12 项：
  - 两档参数合法、合并后不留 extends；
  - 菜单档选中右移（背景与文字同步，内边距和不变，回普通态复位）；
  - 任何新按钮自动挂通用档，flat / 复选框 / no_motion / 总闸关闭不挂，同帧释放不报错；
  - 外部改样式与文字颜色后重新接管并在结束后恢复；
  - 切换按钮的按下常态不缩放、不改文字。

### 测试输出摘要
```
数据校验通过（units / traits / commands / strings / progression / biomes / levels / chapters / stories / ui_motion）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 32 / Tests 261 / Passing 257 / Pending 4 / Asserts 1983 / exit 0
run_playtests -- --check：all 25 scenarios identical to baseline
ui_diff --no-motion：main_menu 0.1537% / main_menu_error 0.3192% / settings_overlay 0.6552%（阈值 2%）
perf_check（RTX 3060 Laptop，1920×1080，关闭垂直同步，全部按钮挂动效）：
  main_menu motion: avg=1035.0 fps | 1% low=158.6 fps | worst=101.4 fps
  level_08 2x: WIN 17.30s | avg=357.9 fps | 1% low=127.5 fps | worst=22.1 fps（终局帧，与 P8 前相同）
  （着色器修改后的第一次运行有一次 201 ms 卡顿，在首个单位死亡、dissolve 重新编译时；第二次运行不再出现）
```

### 补丁：焦点离开后复原（2026-10-05，用户目视反馈）
- 现象：主界面最后悬停过的按钮会保留焦点，焦点按选中显示，所以鼠标移开后它一直亮着。
- 修正：焦点跟随鼠标档（`button_menu`）在鼠标离开时交还焦点，按钮淡回普通态。主界面没有焦点时，按上 / 下 / Tab 回到第一个可用按钮，键盘仍可用。
- gif 与关键帧已更新（`08_left_to_blank` 为移到空白处后的复原）。GUT、`--check` 见提交说明。

## 第三阶段 P6 局内 HUD · 第 1 张 ui_01（部署）—— 拼接完成，等待用户目视（2026-10-05）

资源：`assets/ui/unified_low_noise/`（30 张无字切片、layout.json、text_anchors.json）+ 批准整图 `assets/ui/hud/design_low_noise.png`。用户要求：以批准整图为准（交付回拼的高度与整图不一致，切片本身是对的）、一张一张拼；文字超框时遮罩 + 滚动（名字类自动、长文本滚轮 / 拖动，单行左右、多行上下），注意页边距并做堆叠内容检验。
R6 艺术字素材未找到（Q-080），P8 艺术字部分继续等待。

### 完成标准核对
- [x] **框体与整图一致**：`tools/ui_geom_check.py` 逐元素几何比对，19 个框体偏移全部 ≤ 1 px。卡位 3、4 在第 3 关是「未解锁」卡，内容与整图不同，另在第 8 关目视。
- [x] **文字位置与整图一致**：17 处文字的 ink 中心（左对齐为左缘）全部 ≤ 1 px。7 处字形比例差标 ⚠（Q-077）。
- [x] **文字溢出**：全部文字槽在框体内侧遮罩，名字类自动往返滚动，任务句滚轮 / 拖动；堆叠内容截图与 GUT 用例。
- [x] **战场让出 HUD 上下带**（用户选择缩小战场区）：玩法矩形表与标线工具同步（Q-078）。
- [x] **多分辨率**：21:9 / 16:10 / 1280×720 无截断、无重叠；超宽屏 HUD 不贴边（Q-079）。
- [x] GUT 全绿（普通 + 严格告警）；`run_playtests -- --check` 25 场景一致；validate、界面字面量检查通过。
- [ ] 用户目视（等待中）。通过后拼 ui_02（战斗中）。

### 交付（`docs/screenshots/ui_geom/battle_hud/`）
- `ui_01_compare.png`（上：批准整图缩放到 1920×1080；下：实机第 3 关部署）、`ui_01_overlay50.png`（50% 叠图）。
- `battle_hud_geom.md / .json / _geom_sheet.png`（逐元素几何报告与并排图）。
- `ui_01_overflow_stress_level_08.png`（全部文字槽填超长内容）、`ui_01_resolutions.png`（21:9 / 16:10 / 1280×720）。
- 拟合记录：`godot/assets/ui/battle_hud/FIT_REPORT.md`（每个元素的来源切片 / 锚点、拟合矩形、分数、字号、颜色）。

### 逐项
1. **新工具 `tools/ui_fit_reference.py`**：
   - 读 `fit_spec.json`；切片在批准整图里做边缘 + alpha 掩码的多尺度匹配（等比），文字按锚点 ink 拟合整数字号并反推 label 矩形；
   - 输出 manifest 与 FIT_REPORT；
   - `--calibrate` 用实机几何报告修正字号与位置（本界面 5 轮收敛）。
2. **新工具 `tools/ui_geom_check.py`**：框体用边缘 + 切片掩码平移搜索；文字用实机截图与 `--text-layer` 无文字截图之差取 ink，对照锚点。
3. **`apply_ui_manifest.py`**：按钮状态可为 `{"file","modulate"}`（单态切片调色）；透传 `reserved / overflow / data`；manifest 显式 `key / align`。
4. **`take_screenshots`**：`--text-layer`（另存隐藏文字的截图）、`--demo=overflow`（堆叠内容）。
5. **HUD 场景与脚本**：
   - `hud.tscn` 顶栏 / 底栏 / 行容器改为普通 Control，节点名全部保留；`hud.gd` 的 `_apply_skin / _relayout_skin` 按布局摆放；
   - 底栏 = 下方带内的拖放区（收回单位）；
   - 关卡名「第 N 关 · 关名」；计时 00.0；进度文字（生存关等）放在计时铭牌下方（整图未画，Q 待资源方补）。
6. **出场卡**：五个卡位，形态卡用该形态的卡片切片（头像已画在切片上），名称 / COST / 费用为子 Label；空余卡位为「未解锁」卡；fixed 关同样适用。
7. **`ScrollText`（新）**：包裹现有 Label 的遮罩滚动组件（AUTO / MANUAL、单行横向 / 多行纵向、两端渐隐、点击与拖动区分），参数在 `ui_motion.json` 的 `scroll_text`。按钮文字经 `UiKit.button_scroll_text` 代理绘制，按钮动效的文字颜色写到代理。
8. **`Playfield`** 读布局 `reserved` 计算可视区；`print_playfield_rects.py` 同步。

### 测试
- 新增 `tests/integration/test_scroll_text.gd`（7 项）：
  - 参数来自数据；不超出时不动；
  - 自动往返（起点停顿 → 末端 → 回起点）、总闸关闭不动；
  - 手动滚轮 / 拖动、点击与拖动区分；多行纵向；
  - HUD 堆叠内容：全部文字槽填超长内容后，框体 / 文字区不变、遮罩、可滚动，卡面三处文字在卡内。
- `test_hud_layout.gd`：右上角与底栏改为「位置 = 布局」、五个卡位、战场在上下带之间；补位卡不计入出场卡；任务句点击经 ScrollText。
- `test_playfield_input_clipping.gd`：新玩法矩形表。

### 测试输出摘要
```
数据校验通过（units / traits / commands / strings / progression / biomes / levels / chapters / stories / ui_motion）。
界面脚本无中文字面量。
GUT（普通 + 严格告警模式）：Scripts 33 / Tests 268 / Passing 264 / Pending 4 / Asserts 2111 / exit 0
run_playtests -- --check：all 25 scenarios identical to baseline
ui_geom_check battle_hud（level_03 部署）：共 36 项，未通过 0 项（7 处字形比例差 ⚠）
```

## 第三阶段 P6 局内 HUD ui_02～ui_21 —— 逐张拼接完成，等待用户目视（2026-10-06）

用户 2026-10-06：ui_01 的三处修正（圆按钮文字略右偏、提示按钮只显示「提示」、推荐阵型放宽不滚动）后继续依次拼合，拼好一张截一张图、不停下来问；缺少的素材记下来交资源侧补。

### 逐张
| 状态 | 内容 | 验收 |
|---|---|---|
| ui_02 战斗中 / ui_03 暂停 | 开始 / 清空 / 提示的禁用态按 ui_02 整图实测亮度、饱和度派生灰图；卡片禁用调色减轻 | 几何 35 / 34 项通过 |
| ui_04 固定出场 | 预算铭牌显示「固定出场」（从 ui_04 整图自动取 ink，搬到 ui_01 框体上） | 28 项通过 |
| ui_05 开始校验 | 问题面板：可见金框与整图对齐到 1 px，阻塞项在前，行多时向上长、超出滚动；超预算红色取整图 | 37 项通过 |
| ui_06 任务弹窗 | 框体 / 标题 / 关闭 / 分隔线 / 条件框版式取整图，正文滚动 | 42 项通过 |
| ui_07 机制说明 | 规则框、本关要点、规则区滚动条（scroll_track / scroll_thumb） | 39 项通过 |
| ui_08 提示 / ui_09 推荐阵型 | 段距、已看层数圆点、确认句与「摆放」「取消」；高度随内容、以整图框体中心居中 | 目视对照（高度随内容，位置按设计变化） |
| ui_10 胜利 / ui_11 失败 | 两套版式；奖励 / 原因区滚动 | 目视对照 |
| ui_12～ui_20 角色 / 敌人详情 | 对侧浮动面板改为覆盖 HUD 的居中弹窗（detail_modal_whole）；指令行按整图绝对定位；运行中、只读、添加行为列表、信标、双条件、等待、沿信标、敌方特性各状态 | ui_12 几何 13 项通过；其余目视 |
| ui_21 部署反馈 | 信标数字牌（深底金边圆角）；不可放置气泡锚在目标格上方 | 目视 |

截图：`docs/screenshots/ui_geom/battle_hud/ui_XX_compare.png`（上 = 批准整图，下 = 实机）与 `ui_XX_geom.md`。缺少的素材：`docs/P6_MISSING_ASSETS.md`（17 项）。新问题：Q-081～Q-083。

### 测试
- 新增 / 更新：`test_problems_panel_follows_reference`、`test_recommend_layout_fits_reference`、`test_detail_modal_follows_reference`；`test_rule_editor` 行为列表；`test_scroll_text` 提示按钮不滚动。
- GUT 270 / 266 / 4 pending（普通 + 严格见提交）；`run_playtests -- --check` 25 场景一致。

## 第三阶段 P6 章节地图 ui_22～ui_26 —— 拼接完成，等待用户目视（2026-10-06）

用户 2026-10-06：「先继续拼章节地图吧」。按 12 §8 逐张拼，以 ui_22 为几何基准（其余整图之间有几像素漂移）。

### 逐张
| 状态 | 内容 | 验收 |
|---|---|---|
| ui_22 默认（第 3 关可挑战） | 地图铺满窗口、详情两框浮在右侧；上框第 N 关 / 关名 / 区域，下框特征 / 任务 / 状态竖排，超出下框时滚轮 / 拖动上下滚动（遮罩下沿留底边距，文字不压金边）；关名、区域、章节名单行自动横滚 | ui_geom_check 20 项：文字全部 ±1 px 通过；未过 3 项为代用切片框体（返回 / 进入 / 下拉，与整图画法不同，已按可见外框目视对齐） |
| ui_23 锁定（第 4 关） | 「进入」禁用灰图；状态暗色；「需先通关：…」在下框里滚动 | 目视 |
| ui_24 已完成（第 2 关） | 状态金色「已完成」 | 文字全部通过 |
| ui_25 横移末端 · 占位节点 | **新增占位版式**：选中「未开放」节点时右侧换成标题牌 + 说明框「未解锁」+ 恒禁用的小「进入」，不显示区域与回放（布局 ph_*） | ph_title / ph_text 通过；框体目视 |
| ui_26 首领（第 8 关） | 关卡 7 / 8 重新配准到整图位置（以关卡 5 / 6 为锚）；特征两行时按词换行（不再把 Boss 拆开） | 目视 |

截图：`docs/screenshots/ui_geom/chapter/ui_XX_compare.png`（上 = 批准整图，下 = 实机）。缺少的素材：`docs/P6_MISSING_ASSETS.md` 第 18–28 项。

### 其他修正
- 地图节点与连线放进遮罩层（宽 = 详情面板左缘），不再从详情两框之间的空隙露出来。
- 拼合工具：`ui_fit_reference.py` 之前丢掉了 button 类元素的 `ninepatch`，切片一直被整体拉伸；已修（章节地图按钮已用上）。局内 HUD 有 16 个按钮受影响，试生成对照：下拉框金边 / 箭头不再变形（更接近整图）；「添加指令」需改为只保留左右端头 `[50, 0, 50, 0]`（已写进 fit_spec）。**HUD 的布局 / 主题本次未重新生成**，见下条。
- **资源侧已交付 P6 补充素材**（`docs/P6_ASSET_SUPPLEMENT.md`，2026-10-06 04:5x：结算胶囊按钮、纹章、月牙、描边关闭、摆放 / 取消、移除、footer tab、滚动箭头、信标牌、气泡等 21 张切片 + 3 个行为图标），并已改写 `assets/ui/battle_hud/fit_spec.json` 接入。新 PNG 尚未被 Godot 导入，直接重生成会让主题引用失败（试跑 34 项测试失败）。接入要导入素材后逐张重拼 HUD 21 个状态，留作下一步；本次提交保持 HUD 为用户已目视确认的版本；资源侧的 fit_spec 改动与其在 05:02 重新生成的 HUD 布局 / 主题（资源侧会话仍在进行）留在工作区未提交，程序侧未再改动。工作区当前状态下严格模式有 22 项因素材未导入而失败，与本次提交无关（提交内容在 HUD 为提交版本时普通 / 严格均通过，见上文）。
- 校准（`--calibrate`）不再自动搬偏移 > 3 px 的框体（多为代用切片，边缘匹配不可信），改为提示目视。
- `take_screenshots --screen=chapter --text-layer` 现在也输出无字截图（几何验收用）。
- 章节数据：关卡 7 / 8 与占位节点坐标、占位连线重排（node_25 为最右端），见 Q-084。

## 第三阶段 P6 局内 HUD 接入资源侧补充素材（P6 #1–17）—— 逐张重拼完成，等待用户目视（2026-10-06）

用户 2026-10-06：「P6 素材应该补充完了，继续拼接」。资源侧交付见 `docs/P6_ASSET_SUPPLEMENT.md`；接入状态与仍有的差异见 `docs/P6_MISSING_ASSETS.md` 开头的「接入状态」表。

### 做了什么
- 导入 21 张补充切片与 3 个行为图标（之前未导入，主题引用失败）；重新拟合、生成局内 HUD 布局与主题。
- 代码接入资源侧新增的元素（他们只改了 fit_spec）：
  - 结算：胜利纹章 / 左上月牙 / 两侧装饰线、失败罗盘 / 带菱形分隔线（`result_panel.gd`，按结果显隐）；
  - 任务弹窗：标题月牙、「关闭」右端宝石（`hud.gd`）；
  - 详情：底部凸出标签、滚动条两端箭头（可点击滚动一格，与滚动条同显隐；`DetailKit` / `ScrollText.attach_arrows`）；
  - 不可放置气泡：切片自带尖角时不再画程序三角。
- 按批准整图重量：资源侧给的胜利纹章（原在右侧）、左上月牙、失败罗盘（偏右约 80 px）、装饰线、滚动箭头（偏上 6～12 px）、关闭宝石的矩形与整图不符，已改；拟合工具新增 `fit_visible`（切片留白大时，按不透明区等比放进整图外框）。

### 逐张
| 状态 | 结果 |
|---|---|
| ui_01～ui_05 | 几何 37 / 35 / 34 / 28 / 37 项全部通过；任务 / 清空 / 开始的清理版切片生效 |
| ui_06～ui_09 | 几何 45（新增月牙、宝石按 ui_06 整图目视对齐）/ 39 / 37 / 31 项；描边关闭、摆放 / 取消切片 |
| ui_10 / ui_11 | 新装饰按整图对齐（目视；画法不同，边缘匹配仅作参考） |
| ui_12～ui_20 | 移除按钮、底部标签、滚动箭头；ui_12 几何 13 项（未过 2 项：添加指令与之前相同，删除按钮因九宫格生效偏 2 px） |
| ui_21 | 信标数字牌、气泡换切片，位置不变 |

截图：`docs/screenshots/ui_geom/battle_hud/ui_XX_compare.png`。

### 章节地图（P6 #18–28）—— 资源侧定稿后接入完成，等待用户目视
用户 2026-10-06：「资源侧已经定稿了，继续拼章节地图」。逐张 ui_22～ui_26：
- 节点：徽章按状态换图（锁定 / 可挑战 / 已完成 / 选中 / 首领）+ 区域图标（node_art）+ 锁 / 勾角标 + 名牌胶囊切片；连线中点菱形。
- 详情两框：边线小宝石、上框月牙刻纹、下框星盘刻纹（按整图拼装，交付的整框叠层太亮太满未用，见 P6_MISSING_ASSETS）；菱形分隔线（下框那条放进与文字列等宽的占位框，不撑宽竖排）。
- 返回 / 设置 / 进入 / 剧情下拉 / 回放 / 占位标题牌换切片；锁定态「进入」与回放控件的禁用样子按 ui_23 整图派生。
- 工具：`UiKit` 图片元素支持 `data.region`（裁切一块）与 `data.modulate`（调色半透明）；拟合工具新增 `slice_crop`（切片可见部分偏在大张透明图一角时裁出另存 derived/）。
- 截图：章节截图的已看剧情按整图设定（已通关与当前关的开场看过），不随本机存档变。
- ui_22 几何：文字全部 ±1 px（含 5 个按钮文字）；框体为新画法，目视对齐。测试新增 `test_node_badges_follow_state`。

## 第三阶段 P7 场景大地图接入 —— 程序侧完成，等待 R4 素材（2026-10-06）

用户 2026-10-06：「目视通过，继续 P7 场景大地图」。资源侧 R4 目前只有 8 张完整场景提案（`assets/backdrops/review_p3/`、`review_low_noise/`），**没有 base、障碍块切片与 obstacles.json**（ASSET_REPORT_P3：「R4 最终尺寸、透明障碍切片与回贴验收尚未交付」）。程序侧先完成接入，素材到后只改数据。

### 做了什么
- 数据：`scene.obstacles` = 障碍块清单路径；`LevelDefinition` 读清单（每块 file / cells / anchor_px / size_px），校验文件存在、cells 在网格内且 ⊆ `grid.blocked`；有清单时 `scene.ground` 提醒 DEPRECATED。`validate_data.py` 同步校验。坐标约定见 Q-085。
- `GroundLayer`：有清单时不再平铺地面贴图、不画地面标识，只画障碍块——按所占格锚定（整图像素按设计分辨率的格像素换算），按脚底从上到下排序；本层在地板高亮、网格、单位之下。无清单时沿用第二阶段占位（scene.ground / ground_marks，DEPRECATED）。
- `BackdropLayer`：有清单时底图按设计坐标 1:1 居中铺，与玩法矩形逐格对齐（不再放大 1.54 倍）。
- 工具：`tools/obstacle_check.py`（`anchor` 换算、`check` 回贴自检 < 1%），与运行时同一公式。
- 验证：
  - 合成例子（第 3 关提案整图挖掉墙段作 base、墙段作障碍块）：脚本回贴差异 0.00%；游戏内截图墙段严丝合缝补回原处；
  - 测试 `test_scene_obstacles_cells_must_be_blocked`、`test_obstacle_pieces_anchor_to_cells_and_sort_by_foot`（夹具 `tests/fixtures/obstacles/`）。
- GUT 普通 / 严格 273 / 269 / 4 pending；`run_playtests -- --check` 25 场景全等（表现层，不碰模拟）。

### 待 R4 到位后
- 8 关逐关：`scene.backdrop` 改指 `level_0X_base.png`、加 `scene.obstacles`；`obstacle_check.py check` 通过；截图核对障碍块与 blocked 对齐、单位不被遮挡。

### P7 接入 R4（2026-10-06）
用户 2026-10-06：「R4 修好了，接入吧」。
- 8 关 `scene.backdrop` 改指 `assets/backdrops/review_r4/level_0X_base.png`，新增 `scene.obstacles` 指向 `review_r4/obstacles/level_0X/obstacles.json`（第七关同样只改这一行表现字段，同 Q-043 处理）；`scene.ground / ground_marks` 保留为无资源占位（DEPRECATED 提醒）。
- `validate_data.py` 通过；`obstacle_check.py check` 8 关回贴 0.00%；GUT 普通 / 严格 273 / 269 / 4 pending；`--check` 25 场景全等。
- `test_camera_pan` 按关卡区分：R4 对齐底图 1:1 与地图层同步平移（Q-085），其余仍断言不露底。
- 截图：`docs/screenshots/p7/`（运行 3 秒）、`docs/screenshots/p7/deploy/` 与 `deploy_overview.png`（部署阶段）。
- **仍未解决（Q-086）**：接入时核对，第 3、8 关障碍切片文件仍是 12:37 的版本（两端格子没有画面），资源侧修复尚未落到文件。清单路径不变，资源侧原地替换 PNG 即可生效，无需再改数据。

### 章节地图补充素材核对 + R4 第 3、8 关修复（2026-10-06）
- 章节地图（资源侧 12:04 补交）：标题深色底牌（接入代码，放在章节名之下）、返回按钮与占位「进入」重导（去掉 `slice_crop`）、带 ▶ 的回放按钮（整体缩放不设九宫格，文字移到图标右侧）、重导的菱形分隔线（按新切片线位重量矩形）、九宫格滚动轨道。ui_22～26 重拍，文字几何除回放按钮（有意右移 20 px 让出图标）外不变。
- R4：资源侧 13:24 替换第 3、8 关障碍切片，8 关回贴 + 逐格覆盖全部通过，重拍 `docs/screenshots/p7/` 第 3、8 关与总览。Q-086 关闭。
- GUT 普通 / 严格 273 / 269 / 4 pending；`--check` 25 场景全等。

## 第三阶段 P8 艺术字接入（R6a / R6b）—— 等待用户目视（2026-10-06）

用户 2026-10-06：「继续 P8 艺术字接入」。
- 新组件 `ArtText`（`scripts/ui/art_text.gd`）+ `assets/shaders/art_text_screen.gdshader`：按素材包 manifest 叠底字 / 光晕（screen 混合，按 motion.md 公式）/ 扫光帧；静止态与 `motion_enabled = false` 时只有底字。
- 映射表 `data/art_text.json`：界面文字 → 素材包（文字一改自动回退普通文字）；`validate_data.py` 校验素材包文件齐全。
- 接入位置：
  - 主界面标题（R6a，3.6 s 光晕 + 扫光循环，帧图 `docs/screenshots/motion/art_text/main_title_frames.png`）；
  - 章节地图详情的 8 个关卡名；
  - 结算「战斗胜利 / 战斗失败」；
  - 新增开战提示「战斗开始」：部署 → 运行时在战场中央淡入、停留、淡出上浮（参数 `ui_motion.json` 的 `art_banner`，`docs/screenshots/motion/art_text/battle_start_banner.png`）。
- 字形大小与位置按布局 `ref_ink`（批准整图量出的字形外框）对齐；ui_10 / ui_11 几何 6 项通过。
- 章节名两款素材分辨率太低、有暗边，**未启用**（见 `docs/RESOURCE_PENDING.md` F 节）。
- 测试 `test_art_text.gd`（3 项）；GUT 普通 / 严格 276 / 272 / 4 pending；`--check` 25 场景全等。

## 第三阶段收尾自检 —— 完成（2026-10-06）
用户 2026-10-06：艺术字「目视通过，继续下一步」。P0–P8 全部完成，最终状态复跑数据校验、GUT（普通 + 严格）、`--check`、性能、导出，结果与遗留见 `docs/13_第三阶段验收报告.md`。修正导出过滤（艺术字清单被误排除）。



## 第四阶段（用户 2026-10-08 修改意见）—— 部署拖动 / 信标模式 / 覆盖指令 / 撤离残影 / Ctrl 镜头 / 侧栏详情 / 人物图替换，等待用户目视

### 1 部署拖动（`map_input.gd`、`battle_root.gd`、`deploy_zone.gd`、`roster_card.gd`）
- 部署阶段按下已放置的己方单位不再立即打开详情：松开且未拖动 = 选中；拖动 = 移动。
- 拖动中战场内不再显示跟手虚影，改为在**最近的地块**画吸附虚影（合法金 / 非法红）+ 格高亮；原位置单位变淡（0.35）；拖出战场仍为移除。
- 地图上移动后不弹出详情（出场卡 / 槽位卡首次放下仍打开详情，便于编辑指令）。

### 2 信标模式（`hud.gd` 信标边栏、`map_input.gd`、`battle_controller.gd`、`beacon_layer.gd`）
- 进入：按单位编号数字键（第 n 个已部署单位，主键盘 / 小键盘 1–9）或详情侧栏「信标」按钮；部署阶段每个已部署单位脚边显示编号圆牌（信标模式中的为金底）。
- 模式中：左键点地块依次追加信标，右键撤销最后一个；已有信标仍可按住拖动；信标模式中点另一个己方单位 = 切到该单位。
- 底部信标边栏（替换出场卡）：标题「信标模式 · N 号 名字」、操作说明、移动方式「沿路径 / 循环 / 往返」（写入该单位全部「沿我的信标」指令的方式；没有这类指令时在末尾追加「始终 → 沿我的信标（从 1 起）」），当前方式为按下态；「自动寻路」按需求标为待定，禁用并有提示；「完成」/ Esc 退出；开始战斗自动退出。
- `names.beacon_modes.once` 由「单程」改为「沿路径」（与需求用语一致）。

### 3 覆盖指令（`rule_def.gd`、`rule_evaluator.gd`、`movement.gd`、`sim_unit.gd`、`rule_row.gd`）
- `RuleDef.override`（JSON `"override": true`，缺省不写，旧存档 / 关卡数据不变）：求值顺序 = 勾选「覆盖」的指令（保持列表顺序）在前、其余在后；没有覆盖指令时与原顺序完全相同。wait 的"被更高优先级抢占"按求值顺序判断。
- 用户例子：1 始终 → 沿我的信标；2 有敌人 → 撤离（覆盖）= 先沿路线走，看到敌人撤离，敌人消失后继续沿路线。
- 恢复规则按用户"目前先定为回到离路径最近的一点"：沿信标被打断后恢复时，在信标折线（循环含末尾 → 起点的闭合段）上取离当前位置最近的点，先走到该点所在格，再前往该段终点信标（往返反向时为段起点）；未被打断时行为不变。
- UI：指令卡头部「覆盖」勾选（点文字也可切换）；敌人只读面板只在勾选时显示。
- `run_playtests -- --check`：25 场景全部与基线一致（已发布关卡没有覆盖指令；回归点只在打断后恢复时生效）。

### 4 撤离抽搐（`unit_view.gd`、`facing_tracker.gd`，只碰表现）
- 撤离中翻身阈值加大（1.2 格 / 0.9 秒，多数时候以后仰背步代替来回翻身）；显示位置做 0.09 s 时间常数的平滑；移动时每 0.06 s 留一个淡紫残影，0.3 s 渐隐。

### 5 Ctrl 镜头（`battle_root.gd`、`map_background.gd`、`map_input.gd`）
- Ctrl + 滚轮：以鼠标处为中心缩放（0.8–2.5 倍，每档 ×1.12），鼠标下的地图点不动；Ctrl + 左键拖动：两个方向平移（未缩放时横向 ±PAN_MAX、纵向 ±PAN_MAX/2，放大后加上多出的半幅）。
- 地图类各层与 Backdrop 同一视图变换；屏幕 → 格换算、玩法矩形判定、拖拽虚影尺寸随缩放；用过 Ctrl 镜头后取消选中 / 开战不再自动回正；触边横移在鼠标位于侧栏上时不触发。

### 6 详情侧栏（指令弹窗靠屏幕一侧）
流程按用户要求：生图 API 出整图 → 核对 → 图生图出透明组件 → 拼入游戏 → 像素级验证 → 堆叠检验。
- **整图**：`tools/make_side_panel_mockup.py` 以真实游戏截图为底画布局线框（文字用游戏实际字体 NotoSerifSC-Bold / Regular 渲染）+ 字形参考图 `glyphs.png`，与现有 HUD 风格截图一起作为参考输入，`tools/gen_image_ref.py`（`/v1/images/edits`，gpt-image-2.5-sunburst）出整图 → `assets/ui/side_detail/design.png`（批准整图，与线框逐元素对齐，叠图见 `ref/overlay_panel.png`）。
- **核对**：侧栏贴屏幕一侧上下铺满；单位在左半屏时侧栏在右、反之在左，不挡该单位；底部信标边栏在未被侧栏遮住的一侧。
- **透明组件**：`tools/make_side_component_sheets.py` 从整图裁出各组件排成两张组件表 → 图生图（`background=transparent`）重绘为无字透明组件（`ref/sheet_frames_v1.png`、`ref/sheet_widgets_v1.png`）。
- **拼接**：`tools/make_side_manifest.py` 切片（连通域取整件；大框体九宫格缩放保角；金边内缩实测）→ 按整图金边位置放置 → 文字 ink 在整图上实测、按字体度量反推 label → `assets/ui/side_detail/manifest.json` → `apply_ui_manifest.py side_detail` → `ui_side_detail.tres` + `data/ui_layout/side_detail.json`。`DetailKit` / `RuleRow` / `RuleEditor` 改读 side_detail（元素 id 沿用 det_*），HUD 侧栏去掉全屏遮罩（战场照常可点）。
- 侧栏新内容：3 × 2 属性、优先级说明一行、指令卡「覆盖」勾选与「行为」标题、目标距离合成为一个「< N」下拉 +「格」、「＋ 添加指令」与「信标」两个底部按钮、金色分隔线。
- **像素级验证**（`docs/screenshots/ui_geom/side_detail/`）：
  - `ui_geom_check.py`：67 项（框体 ±1 px + 文字位置 ±1 px）全部通过（`side_detail_geom.md`）；
  - 新工具 `tools/ui_border_check.py`（金色边线逐行 / 逐列扫描，弥补边缘相关在重复卡片上的误配）：88 条边全部 ±1 px（`side_detail_borders.md`）；指令卡内部各行横向金线与整图逐行一致（414/453/469/507/539/577，670/709/725/763/796/833）；
  - 对照图 `compare.png`（上整图下实机）、`overlay50.png`；多分辨率 `resolutions.png`（1920×1200 侧栏随之加高、2560×1080、1280×720）。
  - 修正过程中发现并修好：`RuleRow._place` 先设尺寸后入树导致下拉被默认主题撑到 51 px；侧栏主题挂得晚导致滚动条 / 分隔线被撑到 24 px；条件二行的基准偏移误用。
- **堆叠检验**（`overflow/level_03.png`，`--demo=side_overflow`）：7 条指令上下滚动并显示滚动条；超长形态名自动滚动、说明两行内滚轮 / 拖动滚动；信标边栏标题与说明遮罩滚动；其余文字槽同 HUD 规则。
- 截图：`take_screenshots --levels=level_03 --phase=deploy --demo=side_panel --no-motion --text-layer`。

### 7 人物图替换（`tools/import_character_designs.py`，原图备份在 `tools/_work/char_backup_20261008/`，`--restore` 可还原）
- 人偶（发饰版）→ 基础攻击形态单位精灵 / 头像 / 出场卡头像（合成进卡片切片头像圆窗）、剧情立绘 doll；魔女 → 剧情立绘 witch；红色猎犬（标注"猎犬"）→ 骸猎犬单位精灵 / 头像（翻转为默认朝右）；骨花主图 → 骨花核心（第八关首领）单位精灵 / 头像。截图 `docs/screenshots/p8_chars/`。
- 未使用：钟、蓝树、白衣女鬼、高帽人、恐惧、愤怒（第一章无对应单位）；承伤 / 快速 / 远射形态没有对应设定图，保持原图（见 Q-087）。

### 测试
- 新增 `tests/unit/test_override_rules.gd`（8）、`tests/integration/test_side_panel_beacon_mode.gd`（5）、`test_rule_editor.gd` +2（覆盖勾选、距离下拉）、`test_camera_pan.gd` 改写触边用例 + Ctrl 缩放 / 平移用例；`test_hud_layout.gd`、`test_deploy_feedback.gd` 按侧栏更新；`test_scroll_text.gd` 补存档隔离（本机已看提示层数曾使其失败）。
- GUT 普通 / 严格：292 / 288 / 4 pending，0 失败；`run_playtests -- --check` 25 场景全等；`validate_data.py`、`check_ui_literals.py` 通过。
- 已知：本机 `godot/export_presets.cfg` 在本阶段开始前已被改写（丢了 `data/ui_layout/*.json` 包含与设计稿排除），本阶段未动，导出前需恢复（见 Q-088）。
