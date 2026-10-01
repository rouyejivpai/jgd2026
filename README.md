# jgd2026 — Godot 4.7.2 2D jam 启动模板

从 Unity 过来的 2D 单机 jam 工程骨架。**内核、UI、插件、输入、音频总线、导出预设都已经配好并实测通过**，
jam 开始时直接从「玩法」那一层写起。

- 引擎：Godot **4.7.2** stable（标准版，非 .NET 版）
- 语言：**GDScript**（无 C#，无编译等待）
- 平台：先只配 Windows 导出

---

## 快速开始

```powershell
# 用编辑器打开
& "D:\Godot\GODOT\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path "D:\jgd2026\v0.0.1"

# 跑端到端冒烟测试（47 项检查，含 Phantom Camera 跟随）
& "D:\Godot\GODOT\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" `
    --headless --path "D:\jgd2026\v0.0.1" res://tools/smoke_test.tscn
```

冒烟测试输出 `全部通过 ✅` 即正常，退出码 0。它带 8 秒看门狗，不会把命令行挂死。
目前 52 项检查，包含**几何布局断言**（居中、HBox/VBox 生效、按钮尺寸），不依赖肉眼看图。

```powershell
# 想让眼睛也确认一下：真正渲染并截图到 .screens/（需要显卡，会短暂弹出窗口）
& "...\Godot_v4.7.2-stable_win64_console.exe" --path "D:\jgd2026\v0.0.1" `
    --resolution 1920x1080 res://tools/capture_screens.tscn
```

---

## 目录结构

```
autoload/            全局单例（内核）
  event_bus.gd         信号总线：跨节点通信不再写 get_node("../../X")
  game_state.gd        全局状态 + 顿帧 / 慢动作 / 暂停
  audio_manager.gd     音效池 + 音乐 + 程序化占位音（make_beep）
  save_manager.gd      存档(JSON) + 设置(ConfigFile) + 显示设置应用
  scene_loader.gd/.tscn 带淡入淡出的场景切换
scenes/
  ui/main_menu.tscn    主菜单（启动场景）
  ui/pause_menu.tscn   暂停菜单（PROCESS_MODE_ALWAYS）
  ui/settings_menu.tscn 设置菜单（被主菜单和暂停菜单各实例化一份）
  game/game_scene.tscn 玩法场景占位 —— 你的工作从这里开始
addons/
  phantom_camera/      相机插件（纯 GDScript，0.11.0.3）
  godot_state_charts/  状态机/状态图插件（0.22.5）
tools/
  setup_project.gd     一次性工程配置工具（写输入映射 + 生成音频总线）
  smoke_test.gd/.tscn  端到端冒烟测试
docs/                  玩法骨架备选等文档
default_bus_layout.tres  Master / SFX / Music 三条总线
export_presets.cfg       Windows Desktop 预设（已配好，见"导出"一节）
```

---

## 内核 API 速查

```gdscript
# 信号总线：谁发和谁收互不认识
EventBus.enemy_died.emit(pos, 10)
EventBus.score_changed.connect(_on_score_changed)

# 全局状态 / 手感
Game.new_run()                  # 开局，重置分数并随机种子
Game.add_score(10)              # 自动广播 score_changed
await Game.hitstop(0.07)        # 命中瞬间冻帧（时间缩放）
await Game.slowmo(0.25, 0.5)    # 慢动作演出
Game.pause_game(true)

# 音效
Audio.play(preload("res://assets/audio/jump.wav"))  # 自带随机音高，连打不单调
Audio.play_music(preload("res://assets/audio/bgm.ogg"))
Audio.play(Audio.make_beep())   # 没素材时的占位音，程序化生成
Audio.set_bus_volume("SFX", 0.8)

# 存档与设置（user:// = %APPDATA%\Godot\app_userdata\jgd2026\）
Save.data["level"] = 3
Save.save_data()
Save.has_save()
Save.clear_save()
Save.save_settings({"master": 0.8})
Save.get_setting("master", 0.8)

# 场景切换
SceneLoader.goto("res://scenes/game/game_scene.tscn")
SceneLoader.reload()
```

### 输入映射

| 动作 | 键盘 | 手柄 |
|---|---|---|
| move_left / right / up / down | A/D/W/S 或方向键 | 左摇杆 |
| jump | Space | A |
| attack | J 或鼠标左键 | X |
| dash | Shift | B |
| interact | E | Y |
| pause | ESC | Start |
| restart | R | Back |

改映射后需要重新跑一次 `tools/setup_project.gd` 才会写回 `project.godot`。

---

## 怎么开始做玩法

1. 打开 `scenes/game/game_scene.tscn`。
2. `Landmarks` 节点是占位参照物（一片网格方块），**删掉**。
3. `Player` 是个会移动的方块，替换成你的角色。
4. 把 `game_scene.gd` 里的 `_physics_process()`（方块移动）和 `_demo_hit()`（演示加分+顿帧+音效）换成你的逻辑。
5. **保留** `HUD`、`PauseMenu`、`PhantomCamera2D` 这三个接线，它们已经能用了。

新增一个场景（比如第二关）的做法：复制 `game_scene.tscn`，然后在 `SceneLoader.goto("res://scenes/game/level2.tscn")` 调用它。
场景之间不要互相 `get_node`，需要通信就加一条 `EventBus` 信号。

### 相机（Phantom Camera）

`game_scene.tscn` 里已经接好：

```
Camera2D
  └── PhantomCameraHost      ← 接管 Camera2D，插件必需
PhantomCamera2D              ← 跟随逻辑（follow_mode = 2 即 SIMPLE）
  follow_target → ../Player
```

**坑**：`follow_target` 这类「导出节点引用」必须写成节点头部属性
`[node name="..." type="Node2D" parent="." node_paths=PackedStringArray("follow_target")]`，
写成独立的属性行不会生效（会静默解析为 null，相机就不跟随了 —— 我在这里踩过一次）。

常用手段：`zoom` 缩放、`follow_damping` 平滑、`dead_zone_width/height` 死区、
`limit_left/top/right/bottom` 边界、`noise` 屏幕震动。

---

## 导出（Windows）

`export_presets.cfg` 已经写好并通过引擎校验，**唯一缺的是导出模板**。

**现状**：`%APPDATA%\Godot\export_templates\` 目录存在但是空的，
所以现在执行导出会报：

```
No export template found at the expected path:
.../export_templates/4.7.2.stable/windows_release_x86_64.exe
```

**你只需要做一次**：打开编辑器 → 顶部菜单「编辑器」→「管理导出模板」→
「下载并安装」（约 1GB，需要联网）。装完即可导出，不用再改任何配置：

```powershell
& "...\Godot_v4.7.2-stable_win64_console.exe" --headless --path "D:\jgd2026\v0.0.1" `
    --export-release "Windows Desktop" "build/windows/jgd2026.exe"
```

一键试玩也可以直接在编辑器里按 `F5`。

---

## 已装插件与版本风险

| 插件 | 版本 | 形态 | 4.7.2 状态 |
|---|---|---|---|
| Phantom Camera | 0.11.0.3 | **纯 GDScript**（无 GDExtension 二进制） | ✅ 实测跟随正常，残差 0 |
| Godot State Charts | 0.22.5 | 纯 GDScript | ✅ 72 个全局类注册成功 |

两个插件在 Godot 4.7.2 上导入、实例化、运行时行为都已验证。
Phantom Camera 的 `plugin.gd` 显式判断了 `Engine.get_version_info().minor >= 6` 走 `EditorDock` 分支，
是 4.7 感知的实现。

**注意**：Phantom Camera 靠 `_enable_plugin()` 注册 `PhantomCameraManager` autoload，
而编辑器启动时加载已启用插件不会触发该回调，所以这个 autoload 已经手写进 `project.godot`。别删。

插件源码另有一份完整克隆（含 examples）在 `D:\jgd2026\_addons_cache\`，工程里没装 examples 以保持干净。

---

## 已知的环境注意事项

- **autoload 顺序有硬约束**：`AudioManager._ready()` 要读 `Save` 的设置，所以 `Save` 必须排在 `Audio` 前面。
  顺序错了不会报错，只会静默表现为「设置好的音量下次启动失效」—— 这种 bug 很难查，所以别随意调序。
  冒烟测试里有一条专门断言守着它。
- `user://` 写入在受限沙箱里会失败并 `push_error`（存档/设置文件实际路径在 `%APPDATA%\Godot\app_userdata\jgd2026\`）。正常在编辑器里跑没有这个问题。
- 项目名目前是 `jgd2026`。改名会影响 `user://` 路径（旧存档找不到），在 `project.godot` 的 `application/config/name` 改。
- 分辨率策略：**1920×1080 视口 + canvas_items 拉伸 + expand 宽高比**。想做像素风就在
  `project.godot` 改 `window/stretch/scale_mode="integer"` 并把视口调成 640×360。
- `tools/capture_screens.gd` 是手动工具，不参与游戏运行；`.screens/` 已在 `.gitignore` 里。
