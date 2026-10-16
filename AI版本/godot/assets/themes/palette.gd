class_name Palette
## 全局调色板（代码与美术共用）。色值来源：04_资源需求.md §1.1、01_程序架构.md §8。

const BG_DEEP: Color = Color("#120A10")        ## 场景底色、清屏色
const FLESH: Color = Color("#7A1E2B")          ## 血肉主色、敌方面板边
const FLESH_HI: Color = Color("#B3313F")       ## 血肉高光、受击
const VIOLET_DEEP: Color = Color("#2A1430")    ## 面板底、紫黑
const VIOLET_MUTE: Color = Color("#4A3350")    ## 次级面板、禁用态
const BONE: Color = Color("#E8DCC4")           ## 己方识别、主文字、骨白
const BONE_DIM: Color = Color("#B8AA8E")       ## 次级文字、网格线
const ALCHEMY_GOLD: Color = Color("#C9A24A")   ## 选中、当前生效指令、奖励
const WARN_RED: Color = Color("#FF4B3E")       ## 敌方识别、爆炸预警、失败
const DIVINE_VIOLET: Color = Color("#B06CFF")  ## 神性/术法光、祭司
const GRID_LINE: Color = Color(0.9098, 0.8627, 0.7686, 0.12)  ## #E8DCC4 @ 12% alpha，网格
const CANVAS_MODULATE: Color = Color("#5A4A5E")  ## LightLayer 的 CanvasModulate（01 §8）
