# 数值 / 关卡数据问题交接（给数值调优 AI）

维护：实施方在每个里程碑追加；处理方完成一项后在"状态"栏注明并在 `docs/CHANGELOG.md` 记一行。
最后更新：M6 完成（2026-10-04）

## 处理规则（摘自 00 执行手册，必须遵守）
1. **第七关 `level_07.json` 不得改动**（带 `_comment` 标记，策划已定）。
2. 其他关卡与 `units.json` 中【建议】值可调；每次调整在 `docs/CHANGELOG.md` 记一行：改了什么、为什么、试玩结果。
3. 改任何 `data/*.json` 后运行 `python tools/validate_data.py`（在 `godot/` 目录）。
4. **不加随机**；撤离/选敌等算法问题优先调布局、半径等数据，不改模拟代码（模拟代码改动请回交实施方）。
5. 改完跑全量测试，pending 项若已满足应变为通过：
   ```
   cd H:\其他\人工神灵\godot
   H:\Godot_v4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
   ```
6. 调整后其他关卡的推荐解仍须胜利（`test_level_0X_recommended_wins`），1×/2× 仍须一致。

## 快速复现工具
- 8 关 × 推荐/替代/预期失败的一键复跑：`godot/tools/run_playtests.gd`（场景在 `tools/playtest_scenarios.json`，结果写 `docs/playtests/`，并打印汇总表与 1×/2× 复核）。汇总见 docs/PLAYTEST_REPORT.md。
- 推荐解与指定配置的 headless 结果：`tests/integration/test_levels_headless.gd`（每条测试用 `gut.p` 打印结果与用时）。
- 自定义配置探测：参考 `tests/helpers/sim_factory.gd` 的 `make_world(level_id, deploy, rules_override)` + `run_until_end(world, 60)`；单位数值可在测试中直接改 `SimUnit` 字段（如 `w.get_spawn("HOUND").move_speed = 5.0`）做扫描，确认后再改 JSON。
- 注意：`-s` 入口脚本不能直接引用 autoload（DataRegistry 等），需在运行时 `load()` 另一个脚本再调用（见 PROGRESS M1 已知问题）。

## 问题清单

| 编号 | 关卡 | 问题 | 当前测试 | 实测数据 | 建议方向 | 状态 |
|---|---|---|---|---|---|---|
| Q-016 | 第二关 谷仓前 | 文档预期"前后排倒置"失败，实测胜利 | `test_level_02_expected_fail_front_back_swapped`（pending） | 推荐 (3,3)/(1,2)/(1,4)：WIN 11.7 s，零阵亡，承伤剩 40。倒置 承伤 (1,3)、攻击 (3,2)(3,4)：WIN 12.7 s，阵亡 1，另一名剩 24。另 5 种错误部署（含全开追击）全部胜利。原因：四具袭击者分两批到达（x=10 两具、x=11 两具），攻击形态射程 4 在接触前逐个击杀 | 让袭击者更集中同时到达（起点同一列），或提高袭击者生命/攻速；须保证推荐解仍胜 | 待处理 |
| Q-021 | 第四关 围栏 | 文档预期"单向追击追不上"，实测能抓到 | `test_level_04_expected_fail_single_chaser`（pending） | 快速形态单独追：WIN 16.3 s（快速 4.5 > 猎犬 4.0）。三单位正面追：WIN 8.4 s。猎犬移速扫描（撤离半径 4、深度 3）：4.5/5.0/5.5/6.0 时单向追击 60 s 内不胜；推荐解 7.6/7.9/9.6/9.8 s 胜；两翼包夹 12.2/12.2/15.6/22.7 s 胜；三单位正面追 8.6–9.9 s 仍胜 | 猎犬移速 ≥ 4.5（或下调快速形态）；并请确认"三单位正面追击"是否仍算预期失败（三行同时压上本身构成包围，任何数值下都会胜） | 待处理 |
| Q-022 | 第三关 墙缝 | verification 的 expected_fail（两单位一起走庭院正面）与 alternatives（合力先杀守卫）互相矛盾 | `test_level_03_expected_fail_frontal_charge` 采用"走庭院、只在射程内停下攻击"→ LOSE 9.7 s（通过） | 走庭院且保持初始指令 WIN 7.0 s；默认"射程内攻击 + 视野内追击"合力 WIN 19.1 s；不放诱饵、攻击形态独走墙下通道 WIN 8.0 s（"必须诱敌"压力偏弱） | 修订 verification 文本；如需加强诱敌必要性，可考虑守卫视野/骸柱生命/通道长度 | 待处理（文本） |
| Q-024 | 第六关 祭司行列 | verification 预期"承伤不前置"会失败；实测承伤放 (2,2) 等多种"不前置"部署仍胜利（祭司 8.1 s 内在 x≈9.4 被击杀，残骸还没赶到） | `test_level_06_expected_fail_front_not_forward` 采用"承伤 (2,8)、攻击 (3,8)、远射 (7,7)"→ LOSE 14.5 s（通过） | 推荐 WIN 8.1 s；承伤 (2,2)/攻击 (4,2)/远射 (3,0) WIN 8.1 s；全员左下 WIN 9.1 s；承伤 (5,5) WIN 8.1 s；远射 (3,6) WIN 20.8 s。失败需要"远射放太靠上"或全员上排 | 祭司在推荐站位下很快进入远射射程并被击杀，前排是否"留住残骸"对结果影响小；如需让"承伤前置"成为必要条件，可考虑祭司更晚进入射程（起点更远 / 移速更低）或残骸更快 | 待处理（教学压力偏弱，非阻塞） |
| Q-027 | 第七关 守住归途（**数据冻结，不得改动**） | 05 §3 / verification 预期"前排开启追击并把全部单位放在 y=6"失败，实测胜利 | `test_level_07_expected_fail_chase_and_crowd`（pending） | 承伤 (3,6)、攻击 (2,6)、远射 (1,6)，全部指令开启：WIN 20.0 s，转运点剩 72；推荐解 WIN 20.0 s 满血（9.1 s 敌人已全灭）；另 3 种替代部署全部 WIN 20.0 s | **不可改第七关数据**；仅供策划复核关卡册 5.8 的失败预期是否需要更换配置描述（例如全员挤在 y=2 一侧）。如策划决定改数值，需策划书面确认后再动 | 待策划（数据冻结） |
| Q-028 | 第八关 骨花母体 | verification 预期"全员正面推进"失败、绕后为推荐；实测正面 WIN 17.3 s，绕后 WIN 25.7 s（更慢） | `test_level_08_frontal_route_expected_fail`（pending）；记录见 docs/playtests/level_08_routes.md 及两份 JSON | 两名护卫开局即锁定承伤（承伤 (3,5) 在护卫 7 格视野内）；四人集火约 10 s 击杀两名护卫。绕后时远射是开局"最远者"，2 次花粉（2×35）在它抵达 (12,9) 前将其炸死 | 提高护卫生命/伤害或核心生命使正面代价更高；减轻绕后单位途中受花粉的压力（如核心 first_delay 增大、藤廊更短）；须保证推荐解（绕后，当前 WIN 25.7 s）与"推荐部署 + 默认指令"仍胜。注意：本关默认指令就是"射程内攻击 + 视野内追击"，等同全员正面推进（M8 复跑 WIN 17.3 s） | 待处理 |
| Q-036 | 第五关 坡地 | 替代解"全员硬吃爆炸正面冲锋"（文档："也可能险胜"）实测 WIN 9.07 s 零损失，明显优于推荐解（WIN 25.5 s、攻击形态阵亡）；推荐解时长也超出 verification 预期 15–20 s | 无（记录见 docs/playtests/level_05_*.json） | 三单位 [射程内攻击, 视野内追击, 沿 advance 推进]：WIN 9.07 s；推荐 (2,4)/(1,4)/(2,8) + 默认指令：WIN 25.50 s，损失 slot_striker；快速形态不动：LOSE 23.0 s | 提高正面推进代价（骨喉爆炸伤害/半径、冷却、骨喉生命）；检查推荐解中攻击形态为何阵亡；保证推荐解与"诱饵不动失败"不变 | 待处理 |

## 已处理
| 编号 | 处理 | 记录 |
|---|---|---|
| — | 第四关猎犬撤离行为威胁半径 4 → 视野（方向抵消抖动 16 → 0） | CHANGELOG 2026-10-04；docs/playtests/level_04_retreat.md |
| — | 第六关 fail_feedback 追加三条分类说明（`lose_priest_escaped:front_not_held / out_of_range / wrong_target`，由原总说明拆分） | 文案，可由策划润色；分类判定见 `scripts/ui/fail_diagnosis.gd` |
