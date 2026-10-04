class_name Team
extends RefCounted
## 阵营常量。**用 const 而不是 enum**，原因见 tools/smoke_test.gd 顶部注释：
## 本工程沙箱禁止子进程写 .godot/，class_name 的全局类缓存无法更新，
## 跨文件引用一律走 preload + const 常量。
##
## 详细设计：[docs/design/04-单位与移动.md](../../docs/design/04-单位与移动.md)
## 状态：已实现（M0 建结构 · M1 落地）。

const TEAM_ALLY := 0
const TEAM_ENEMY := 1
