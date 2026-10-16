# UI 回拼像素对照验收

1818 / 1818 个检查通过。统一在1672×941原生尺寸测量；1920×1080仅作同等比例展示。参考普通字形来自批准整图，实际字形使用项目游戏字体，未对字形宽高作非等比拉伸。

尺寸允许字形自然宽度残差3px和高度1.5px，定位误差限1px。语义不同的文字保留字段的左端或中心锚点，不强行拉伸成相同宽度。像素对照不等于每个像素完全相同，生成图字形和游戏字体的轮廓不同，完整残差见差异图。

## 每个测试用例与结果

| 用例 | 期望 | 结果 | 实测 |
|---|---|---|---|
| ui_01-load | 页面脚本、图片加载正常 | PASS |  |
| ui_01-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_01-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_01-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_01-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_01-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_01-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_01-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_01-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_01-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_01-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_01-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_01-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_01-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_01-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_01-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_01-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_01-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_01-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_01-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_01-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_01-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_01-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_01-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_01-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_01-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_01-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_01-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_01-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_01-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_01-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_01-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_01-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_01-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_01-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_01-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_01-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_01-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_01-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_01-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_01-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_01-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_01-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_01-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_01-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_01-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_01-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_01-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_01-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_01-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_01-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_01-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_01-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_01-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_01-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_01-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_01-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_01-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_01-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_01-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_01-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_01-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_01-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_01-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_01-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_01-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_01-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_01-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_02-load | 页面脚本、图片加载正常 | PASS |  |
| ui_02-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_02-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_02-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_02-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_02-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_02-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_02-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":-0.375,"actual":[817.25,67.75,37.75,15.75],"expected":[816,68,41,16],"text":"18.4"} |
| ui_02-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0,"actual":[894.5,71,33.75,11],"expected":[886,71,51,11],"text":"战斗中"} |
| ui_02-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_02-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_02-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_02-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_02-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_02-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_02-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_02-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_02-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_02-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_02-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_02-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_02-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_02-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_02-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_02-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_02-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_02-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_02-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_02-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_02-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_02-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_02-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_02-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_02-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_02-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_02-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_02-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_02-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_02-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_02-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_02-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_02-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_02-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_02-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_02-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_02-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_02-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_02-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_02-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_02-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_02-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_02-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_02-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_02-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_02-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_02-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_02-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_02-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_02-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_02-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_02-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_02-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_02-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_02-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_02-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_02-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_03-load | 页面脚本、图片加载正常 | PASS |  |
| ui_03-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_03-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_03-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_03-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_03-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_03-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_03-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.375,"actual":[817.25,68.5,37.5,15.75],"expected":[816,68,41,16],"text":"12.6"} |
| ui_03-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0,"actual":[894,71,34,11],"expected":[886,71,51,11],"text":"已暂停"} |
| ui_03-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_03-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_03-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_03-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_03-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_03-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_03-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1408.25,75.75,26,12.25],"expected":[1408,75,27,13],"text":"继续"} |
| ui_03-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_03-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_03-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_03-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_03-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_03-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_03-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_03-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_03-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_03-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_03-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_03-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_03-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_03-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_03-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_03-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_03-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_03-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_03-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_03-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_03-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_03-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_03-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_03-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_03-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_03-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_03-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_03-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_03-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_03-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_03-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_03-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_03-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_03-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_03-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_03-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_03-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_03-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_03-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_03-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_03-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_03-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_03-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_03-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_03-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_03-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_03-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_03-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_03-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_04-load | 页面脚本、图片加载正常 | PASS |  |
| ui_04-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_04-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_04-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[129.75,66,176.25,21],"expected":[130,66,137,21],"text":"第 7 关 · 守住归途"} |
| ui_04-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.125,"actual":[130.25,96,134.25,13.25],"expected":[130,96,164,13],"text":"保护转运点存活 20 秒"} |
| ui_04-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_04-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_04-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_04-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_04-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_04-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_04-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_04-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_04-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_04-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_04-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_04-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_04-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_04-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_04-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_04-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_04-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_04-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_04-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_04-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_04-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_04-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_04-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_04-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_04-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_04-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_04-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[426.25,851.5,58.5,13.75],"expected":[425,851,61,15],"text":"承伤形态"} |
| ui_04-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_04-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_04-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[488.5,880.25,15.25,23],"expected":[489,880,15,23],"text":"4"} |
| ui_04-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_04-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_04-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_04-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_04-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_04-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_04-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[807.25,851.5,58.5,13.75],"expected":[806,851,61,15],"text":"远射形态"} |
| ui_04-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_04-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_04-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_04-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_04-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1005.25,852,43,13.75],"expected":[996,852,62,14],"text":"未解锁"} |
| ui_04-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_04-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_04-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.375,"actual":[1054.75,890.5,26,1.75],"expected":[1059,879,17,24],"text":"—"} |
| ui_04-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_04-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_04-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_04-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_04-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_04-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_04-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_05-load | 页面脚本、图片加载正常 | PASS |  |
| ui_05-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_05-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_05-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_05-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_05-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_05-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_05-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_05-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_05-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_05-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_05-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_05-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_05-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_05-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_05-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_05-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_05-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_05-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_05-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_05-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_05-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_05-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_05-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_05-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_05-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_05-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_05-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_05-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_05-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_05-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_05-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_05-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_05-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.375,"actual":[151,857.5,52,21.25],"expected":[148,858,58,21],"text":"12 / 8"} |
| ui_05-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_05-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_05-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_05-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_05-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_05-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_05-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_05-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_05-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_05-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_05-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_05-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_05-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_05-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_05-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_05-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_05-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_05-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_05-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_05-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_05-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_05-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_05-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_05-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_05-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_05-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_05-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_05-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_05-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_05-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_05-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_05-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_05-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_06-load | 页面脚本、图片加载正常 | PASS |  |
| ui_06-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_06-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_06-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_06-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_06-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_06-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_06-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_06-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_06-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_06-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_06-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_06-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_06-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_06-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_06-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_06-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_06-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_06-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_06-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_06-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_06-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_06-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_06-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_06-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_06-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_06-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_06-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_06-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_06-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_06-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_06-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_06-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_06-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_06-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_06-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_06-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_06-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_06-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_06-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_06-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_06-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_06-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_06-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_06-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_06-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_06-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_06-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_06-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_06-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_06-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_06-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_06-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_06-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_06-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_06-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_06-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_06-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_06-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_06-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_06-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_06-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_06-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_06-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_06-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_06-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_06-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_06-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_07-load | 页面脚本、图片加载正常 | PASS |  |
| ui_07-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_07-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_07-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_07-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_07-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_07-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_07-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_07-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_07-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_07-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_07-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_07-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_07-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_07-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_07-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_07-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_07-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_07-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_07-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_07-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_07-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_07-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_07-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_07-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_07-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_07-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_07-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_07-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_07-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_07-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_07-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_07-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_07-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_07-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_07-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_07-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_07-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_07-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_07-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_07-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_07-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_07-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_07-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_07-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_07-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_07-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_07-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_07-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_07-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_07-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_07-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_07-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_07-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_07-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_07-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_07-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_07-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_07-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_07-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_07-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_07-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_07-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_07-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_07-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_07-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_07-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_07-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_08-load | 页面脚本、图片加载正常 | PASS |  |
| ui_08-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_08-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_08-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_08-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_08-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_08-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_08-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_08-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_08-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_08-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_08-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_08-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_08-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_08-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_08-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_08-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_08-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_08-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_08-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_08-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_08-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_08-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_08-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_08-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_08-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_08-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_08-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_08-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_08-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_08-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_08-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_08-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_08-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_08-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_08-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_08-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_08-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_08-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_08-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_08-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_08-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_08-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_08-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_08-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_08-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_08-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_08-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_08-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_08-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_08-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_08-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_08-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_08-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_08-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_08-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_08-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_08-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_08-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_08-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_08-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_08-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_08-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_08-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_08-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_08-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_08-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_08-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_09-load | 页面脚本、图片加载正常 | PASS |  |
| ui_09-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_09-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_09-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_09-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_09-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_09-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_09-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_09-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_09-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_09-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_09-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_09-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_09-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_09-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_09-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_09-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_09-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_09-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_09-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_09-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_09-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_09-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_09-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_09-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_09-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_09-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_09-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_09-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_09-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_09-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_09-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_09-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_09-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_09-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_09-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_09-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_09-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_09-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_09-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_09-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_09-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_09-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_09-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_09-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_09-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_09-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_09-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_09-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_09-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_09-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_09-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_09-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_09-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_09-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_09-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_09-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_09-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_09-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_09-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_09-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_09-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_09-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_09-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_09-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_09-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_09-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_09-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_10-load | 页面脚本、图片加载正常 | PASS |  |
| ui_10-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_10-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_10-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_10-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_10-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_10-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_10-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_10-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_10-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_10-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_10-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_10-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_10-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_10-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_10-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_10-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_10-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_10-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_10-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_10-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_10-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_10-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_10-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_10-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_10-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_10-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_10-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_10-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_10-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_10-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_10-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_10-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_10-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_10-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_10-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_10-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_10-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_10-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_10-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_10-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_10-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_10-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_10-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_10-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_10-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_10-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_10-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_10-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_10-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_10-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_10-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_10-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_10-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_10-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_10-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_10-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_10-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_10-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_10-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_10-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_10-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_10-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_10-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_10-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_10-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_10-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_10-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_11-load | 页面脚本、图片加载正常 | PASS |  |
| ui_11-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_11-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_11-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_11-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_11-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_11-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_11-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_11-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_11-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_11-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_11-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_11-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_11-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_11-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_11-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_11-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_11-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_11-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_11-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_11-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_11-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_11-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_11-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_11-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_11-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_11-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_11-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_11-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_11-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_11-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_11-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_11-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_11-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_11-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_11-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_11-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_11-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_11-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_11-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_11-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_11-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_11-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_11-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_11-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_11-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_11-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_11-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_11-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_11-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_11-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_11-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_11-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_11-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_11-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_11-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_11-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_11-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_11-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_11-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_11-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_11-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_11-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_11-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_11-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_11-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_11-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_11-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_12-load | 页面脚本、图片加载正常 | PASS |  |
| ui_12-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_12-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_12-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_12-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_12-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_12-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_12-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_12-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_12-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_12-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_12-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_12-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_12-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_12-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_12-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_12-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_12-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_12-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_12-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_12-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_12-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_12-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_12-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_12-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_12-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_12-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_12-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_12-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_12-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_12-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_12-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_12-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_12-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_12-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_12-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_12-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_12-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_12-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_12-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_12-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_12-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_12-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_12-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_12-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_12-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_12-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_12-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_12-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_12-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_12-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_12-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_12-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_12-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_12-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_12-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_12-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_12-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_12-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_12-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_12-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_12-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_12-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_12-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_12-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_12-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_12-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_12-detail-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[557.5,142.5,149.25,34.75],"expected":[557,142,150,35],"text":"快速形态"} |
| ui_12-detail-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.25} |
| ui_12-detail-close-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.125,"actual":[1212.5,152.75,29.25,15.75],"expected":[1212,152,31,17],"text":"关闭"} |
| ui_12-detail-close-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1.25} |
| ui_12-detail-description-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":1,"dy":0.25,"actual":[562,204.75,514,19],"expected":[561,204,516,20],"text":"四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。"} |
| ui_12-detail-description-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_12-detail-add-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[798.5,770.75,74.25,17],"expected":[799,770,74,18],"text":"添加指令"} |
| ui_12-detail-add-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1} |
| ui_12-detail-beacons-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.25,"actual":[772.5,811,127.5,16.5],"expected":[772,811,129,17],"text":"信标：尚无信标"} |
| ui_12-detail-beacons-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.5} |
| ui_12-stat-0-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.25,"actual":[441.5,278,37.25,17.5],"expected":[441,277,37,19],"text":"生命"} |
| ui_12-stat-0-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.5} |
| ui_12-stat-0-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[499,279.75,19.75,14.5],"expected":[499,279,21,15],"text":"60"} |
| ui_12-stat-0-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_12-stat-1-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[590.5,277.75,37,16.75],"expected":[590,277,38,18],"text":"攻击"} |
| ui_12-stat-1-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-1.25} |
| ui_12-stat-1-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[662,279.75,9,14.5],"expected":[662,279,9,15],"text":"6"} |
| ui_12-stat-1-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0,"dh":-0.5} |
| ui_12-stat-2-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[744.5,277.75,35,16.75],"expected":[744,277,37,18],"text":"攻速"} |
| ui_12-stat-2-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_12-stat-2-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[805.25,279.25,23.5,16],"expected":[805,279,25,16],"text":"1.0"} |
| ui_12-stat-2-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0} |
| ui_12-stat-3-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0,"actual":[902.25,277.5,36,17],"expected":[902,277,38,18],"text":"移速"} |
| ui_12-stat-3-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_12-stat-3-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.5,"actual":[958.5,279.75,26.25,14.5],"expected":[958,279,28,15],"text":"4.5"} |
| ui_12-stat-3-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_12-stat-4-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1058.25,277.75,36.5,18],"expected":[1058,277,37,19],"text":"视野"} |
| ui_12-stat-4-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1} |
| ui_12-stat-4-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1114,279.75,8.75,14.5],"expected":[1114,279,9,15],"text":"9"} |
| ui_12-stat-4-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.5} |
| ui_12-stat-5-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[1188.5,277.5,38.25,18.25],"expected":[1188,277,38,19],"text":"射程"} |
| ui_12-stat-5-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-0.75} |
| ui_12-stat-5-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1246.25,279.25,23.5,16],"expected":[1246,279,24,16],"text":"1.5"} |
| ui_12-stat-5-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":0} |
| ui_12-row-1-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0,"actual":[456.5,351,87,20],"expected":[456,351,88,20],"text":"优先级 1"} |
| ui_12-row-1-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0} |
| ui_12-row-1-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[587.5,352.25,34,16.25],"expected":[587,352,93,17],"text":"攻击"} |
| ui_12-row-1-delete-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[1172.5,354.5,33.25,17],"expected":[1172,354,35,18],"text":"删除"} |
| ui_12-row-1-delete-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_12-row-1-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":-0.375,"actual":[582.75,403.75,51.75,16.75],"expected":[582,404,54,17],"text":"条件一"} |
| ui_12-row-1-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.25} |
| ui_12-row-1-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[582.75,460.75,52.5,16.75],"expected":[583,460,53,18],"text":"条件二"} |
| ui_12-row-1-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_12-row-2-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[455.75,540.75,90.25,20.25],"expected":[456,541,91,20],"text":"优先级 2"} |
| ui_12-row-2-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":0.25} |
| ui_12-row-2-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":0,"actual":[588.75,543.25,33.25,17.5],"expected":[588,543,35,18],"text":"等待"} |
| ui_12-row-2-action-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_12-row-2-delete-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1172.25,545.25,34,16.25],"expected":[1172,545,35,17],"text":"删除"} |
| ui_12-row-2-delete-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_12-row-2-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[584.5,595.5,50,15.75],"expected":[584,595,52,17],"text":"条件一"} |
| ui_12-row-2-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_12-row-2-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[581.75,653.75,52.5,16.75],"expected":[582,653,54,18],"text":"条件二"} |
| ui_12-row-2-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_12-row-2-duration-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":-0.375,"actual":[826.25,542.75,69.75,15.75],"expected":[826,543,71,16],"text":"持续时间"} |
| ui_12-row-2-duration-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_12-row-2-duration-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[929,546.5,8.25,13.5],"expected":[929,546,9,14],"text":"2"} |
| ui_12-row-2-duration-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.5} |
| ui_12-row-2-duration-unit-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":-0.125,"actual":[1050.75,543.5,15.25,14.75],"expected":[1051,543,15,16],"text":"秒"} |
| ui_12-row-2-duration-unit-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.25} |
| ui_12-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_13-load | 页面脚本、图片加载正常 | PASS |  |
| ui_13-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_13-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_13-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_13-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_13-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_13-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_13-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":-0.375,"actual":[817.25,67.75,37.75,15.75],"expected":[816,68,41,16],"text":"18.4"} |
| ui_13-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0,"actual":[894.5,71,33.75,11],"expected":[886,71,51,11],"text":"战斗中"} |
| ui_13-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_13-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_13-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_13-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_13-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_13-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_13-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_13-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_13-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_13-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_13-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_13-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_13-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_13-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_13-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_13-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_13-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_13-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_13-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_13-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_13-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_13-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_13-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_13-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_13-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_13-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_13-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_13-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_13-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_13-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_13-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_13-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_13-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_13-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_13-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_13-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_13-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_13-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_13-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_13-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_13-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_13-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_13-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_13-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_13-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_13-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_13-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_13-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_13-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_13-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_13-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_13-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_13-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_13-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_13-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_13-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_13-detail-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[557.5,142.5,149.25,34.75],"expected":[557,142,150,35],"text":"快速形态"} |
| ui_13-detail-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.25} |
| ui_13-detail-close-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.125,"actual":[1212.5,152.75,29.25,15.75],"expected":[1212,152,31,17],"text":"关闭"} |
| ui_13-detail-close-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1.25} |
| ui_13-detail-description-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":0.25,"actual":[561.75,204.75,188.25,19],"expected":[561,204,516,20],"text":"战斗中无法编辑指令。"} |
| ui_13-detail-beacons-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":-0.25,"actual":[758.5,811,155.75,16.5],"expected":[772,811,129,17],"text":"战斗中无法编辑指令"} |
| ui_13-stat-0-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.25,"actual":[441.5,278,37.25,17.5],"expected":[441,277,37,19],"text":"生命"} |
| ui_13-stat-0-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.5} |
| ui_13-stat-0-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[499,279.75,19.75,14.5],"expected":[499,279,21,15],"text":"60"} |
| ui_13-stat-0-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_13-stat-1-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[590.5,277.75,37,16.75],"expected":[590,277,38,18],"text":"攻击"} |
| ui_13-stat-1-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-1.25} |
| ui_13-stat-1-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[662,279.75,9,14.5],"expected":[662,279,9,15],"text":"6"} |
| ui_13-stat-1-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0,"dh":-0.5} |
| ui_13-stat-2-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[744.5,277.75,35,16.75],"expected":[744,277,37,18],"text":"攻速"} |
| ui_13-stat-2-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_13-stat-2-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[805.25,279.25,23.5,16],"expected":[805,279,25,16],"text":"1.0"} |
| ui_13-stat-2-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0} |
| ui_13-stat-3-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0,"actual":[902.25,277.5,36,17],"expected":[902,277,38,18],"text":"移速"} |
| ui_13-stat-3-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_13-stat-3-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.5,"actual":[958.5,279.75,26.25,14.5],"expected":[958,279,28,15],"text":"4.5"} |
| ui_13-stat-3-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_13-stat-4-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1058.25,277.75,36.5,18],"expected":[1058,277,37,19],"text":"视野"} |
| ui_13-stat-4-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1} |
| ui_13-stat-4-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1114,279.75,8.75,14.5],"expected":[1114,279,9,15],"text":"9"} |
| ui_13-stat-4-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.5} |
| ui_13-stat-5-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[1188.5,277.5,38.25,18.25],"expected":[1188,277,38,19],"text":"射程"} |
| ui_13-stat-5-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-0.75} |
| ui_13-stat-5-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1246.25,279.25,23.5,16],"expected":[1246,279,24,16],"text":"1.5"} |
| ui_13-stat-5-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":0} |
| ui_13-row-1-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0,"actual":[456.5,351,87,20],"expected":[456,351,88,20],"text":"优先级 1"} |
| ui_13-row-1-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0} |
| ui_13-row-1-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[587.5,352.25,34,16.25],"expected":[587,352,93,17],"text":"攻击"} |
| ui_13-row-1-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":-0.375,"actual":[582.75,403.75,51.75,16.75],"expected":[582,404,54,17],"text":"条件一"} |
| ui_13-row-1-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.25} |
| ui_13-row-1-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[582.75,460.75,52.5,16.75],"expected":[583,460,53,18],"text":"条件二"} |
| ui_13-row-1-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_13-row-2-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[455.75,540.75,90.25,20.25],"expected":[456,541,91,20],"text":"优先级 2"} |
| ui_13-row-2-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":0.25} |
| ui_13-row-2-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":0,"actual":[588.75,543.25,33.25,17.5],"expected":[588,543,35,18],"text":"等待"} |
| ui_13-row-2-action-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_13-row-2-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[584.5,595.5,50,15.75],"expected":[584,595,52,17],"text":"条件一"} |
| ui_13-row-2-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_13-row-2-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[581.75,653.75,52.5,16.75],"expected":[582,653,54,18],"text":"条件二"} |
| ui_13-row-2-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_13-row-2-duration-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":-0.375,"actual":[826.25,542.75,69.75,15.75],"expected":[826,543,71,16],"text":"持续时间"} |
| ui_13-row-2-duration-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_13-row-2-duration-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[929,546.5,8.25,13.5],"expected":[929,546,9,14],"text":"2"} |
| ui_13-row-2-duration-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.5} |
| ui_13-row-2-duration-unit-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":-0.125,"actual":[1050.75,543.5,15.25,14.75],"expected":[1051,543,15,16],"text":"秒"} |
| ui_13-row-2-duration-unit-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.25} |
| ui_13-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_14-load | 页面脚本、图片加载正常 | PASS |  |
| ui_14-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_14-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_14-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_14-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_14-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_14-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_14-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_14-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_14-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_14-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_14-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_14-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_14-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_14-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_14-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_14-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_14-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_14-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_14-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_14-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_14-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_14-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_14-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_14-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_14-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_14-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_14-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_14-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_14-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_14-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_14-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_14-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_14-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_14-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_14-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_14-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_14-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_14-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_14-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_14-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_14-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_14-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_14-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_14-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_14-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_14-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_14-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_14-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_14-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_14-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_14-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_14-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_14-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_14-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_14-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_14-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_14-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_14-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_14-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_14-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_14-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_14-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_14-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_14-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_14-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_14-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_14-detail-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[559,142.5,146.25,34.5],"expected":[557,142,150,35],"text":"哭墙守卫"} |
| ui_14-detail-close-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.125,"actual":[1212.5,152.75,29.25,15.75],"expected":[1212,152,31,17],"text":"关闭"} |
| ui_14-detail-close-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1.25} |
| ui_14-detail-description-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":-0.25,"actual":[561.75,203.75,404.5,20],"expected":[561,204,516,20],"text":"敌方指令只读，从上到下执行第一条成立的指令。"} |
| ui_14-detail-beacons-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.25,"actual":[777,811,118.5,16.5],"expected":[772,811,129,17],"text":"敌方指令 · 只读"} |
| ui_14-stat-0-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.25,"actual":[441.5,278,37.25,17.5],"expected":[441,277,37,19],"text":"生命"} |
| ui_14-stat-0-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.5} |
| ui_14-stat-0-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[499,279.75,19.75,14.5],"expected":[499,279,21,15],"text":"90"} |
| ui_14-stat-1-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[590.5,277.75,37,16.75],"expected":[590,277,38,18],"text":"攻击"} |
| ui_14-stat-1-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-1.25} |
| ui_14-stat-1-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.5,"actual":[662.25,279.75,17.75,14.5],"expected":[662,279,9,15],"text":"10"} |
| ui_14-stat-2-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[744.5,277.75,35,16.75],"expected":[744,277,37,18],"text":"攻速"} |
| ui_14-stat-2-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_14-stat-2-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.25,"actual":[805,279.25,28.75,16],"expected":[805,279,25,16],"text":"0.8"} |
| ui_14-stat-3-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0,"actual":[902.25,277.5,36,17],"expected":[902,277,38,18],"text":"移速"} |
| ui_14-stat-3-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_14-stat-3-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.5,"actual":[958.25,279.75,24,14.5],"expected":[958,279,28,15],"text":"1.2"} |
| ui_14-stat-4-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1058.25,277.75,36.5,18],"expected":[1058,277,37,19],"text":"视野"} |
| ui_14-stat-4-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1} |
| ui_14-stat-4-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1114,279.75,9,14.5],"expected":[1114,279,9,15],"text":"6"} |
| ui_14-stat-5-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[1188.5,277.5,38.25,18.25],"expected":[1188,277,38,19],"text":"射程"} |
| ui_14-stat-5-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-0.75} |
| ui_14-stat-5-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.125,"actual":[1246.25,279.25,9.75,15.75],"expected":[1246,279,24,16],"text":"2"} |
| ui_14-row-1-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0,"actual":[456.5,351,87,20],"expected":[456,351,88,20],"text":"优先级 1"} |
| ui_14-row-1-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0} |
| ui_14-row-1-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[587.5,352.25,34,16.25],"expected":[587,352,93,17],"text":"攻击"} |
| ui_14-row-1-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":-0.375,"actual":[582.75,403.75,51.75,16.75],"expected":[582,404,54,17],"text":"条件一"} |
| ui_14-row-1-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.25} |
| ui_14-row-1-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[582.75,460.75,52.5,16.75],"expected":[583,460,53,18],"text":"条件二"} |
| ui_14-row-1-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_14-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_15-load | 页面脚本、图片加载正常 | PASS |  |
| ui_15-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_15-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_15-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_15-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_15-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_15-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_15-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_15-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_15-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_15-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_15-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_15-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_15-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_15-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_15-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_15-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_15-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_15-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_15-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_15-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_15-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_15-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_15-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_15-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_15-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_15-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_15-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_15-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_15-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_15-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_15-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_15-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_15-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_15-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_15-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_15-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_15-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_15-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_15-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_15-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_15-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_15-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_15-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_15-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_15-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_15-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_15-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_15-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_15-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_15-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_15-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_15-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_15-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_15-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_15-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_15-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_15-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_15-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_15-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_15-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_15-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_15-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_15-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_15-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_15-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_15-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_15-detail-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[557.5,142.5,149.25,34.75],"expected":[557,142,150,35],"text":"快速形态"} |
| ui_15-detail-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.25} |
| ui_15-detail-close-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.125,"actual":[1212.5,152.75,29.25,15.75],"expected":[1212,152,31,17],"text":"关闭"} |
| ui_15-detail-close-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1.25} |
| ui_15-detail-description-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":1,"dy":0.25,"actual":[562,204.75,514,19],"expected":[561,204,516,20],"text":"四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。"} |
| ui_15-detail-description-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_15-detail-add-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[798.5,770.75,74.25,17],"expected":[799,770,74,18],"text":"添加指令"} |
| ui_15-detail-add-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1} |
| ui_15-detail-beacons-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.25,"actual":[772.5,811,127.5,16.5],"expected":[772,811,129,17],"text":"信标：尚无信标"} |
| ui_15-detail-beacons-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.5} |
| ui_15-stat-0-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.25,"actual":[441.5,278,37.25,17.5],"expected":[441,277,37,19],"text":"生命"} |
| ui_15-stat-0-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.5} |
| ui_15-stat-0-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[499,279.75,19.75,14.5],"expected":[499,279,21,15],"text":"60"} |
| ui_15-stat-0-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_15-stat-1-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[590.5,277.75,37,16.75],"expected":[590,277,38,18],"text":"攻击"} |
| ui_15-stat-1-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-1.25} |
| ui_15-stat-1-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[662,279.75,9,14.5],"expected":[662,279,9,15],"text":"6"} |
| ui_15-stat-1-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0,"dh":-0.5} |
| ui_15-stat-2-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[744.5,277.75,35,16.75],"expected":[744,277,37,18],"text":"攻速"} |
| ui_15-stat-2-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_15-stat-2-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[805.25,279.25,23.5,16],"expected":[805,279,25,16],"text":"1.0"} |
| ui_15-stat-2-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0} |
| ui_15-stat-3-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0,"actual":[902.25,277.5,36,17],"expected":[902,277,38,18],"text":"移速"} |
| ui_15-stat-3-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_15-stat-3-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.5,"actual":[958.5,279.75,26.25,14.5],"expected":[958,279,28,15],"text":"4.5"} |
| ui_15-stat-3-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_15-stat-4-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1058.25,277.75,36.5,18],"expected":[1058,277,37,19],"text":"视野"} |
| ui_15-stat-4-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1} |
| ui_15-stat-4-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1114,279.75,8.75,14.5],"expected":[1114,279,9,15],"text":"9"} |
| ui_15-stat-4-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.5} |
| ui_15-stat-5-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[1188.5,277.5,38.25,18.25],"expected":[1188,277,38,19],"text":"射程"} |
| ui_15-stat-5-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-0.75} |
| ui_15-stat-5-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1246.25,279.25,23.5,16],"expected":[1246,279,24,16],"text":"1.5"} |
| ui_15-stat-5-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":0} |
| ui_15-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_16-load | 页面脚本、图片加载正常 | PASS |  |
| ui_16-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_16-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_16-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_16-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_16-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_16-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_16-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_16-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_16-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_16-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_16-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_16-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_16-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_16-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_16-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_16-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_16-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_16-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_16-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_16-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_16-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_16-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_16-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_16-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_16-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_16-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_16-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_16-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_16-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_16-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_16-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_16-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_16-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_16-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_16-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_16-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_16-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_16-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_16-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_16-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_16-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_16-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_16-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_16-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_16-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_16-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_16-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_16-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_16-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_16-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_16-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_16-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_16-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_16-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_16-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_16-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_16-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_16-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_16-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_16-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_16-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_16-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_16-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_16-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_16-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_16-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_16-detail-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[557.5,142.5,149.25,34.75],"expected":[557,142,150,35],"text":"快速形态"} |
| ui_16-detail-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.25} |
| ui_16-detail-close-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.125,"actual":[1212.5,152.75,29.25,15.75],"expected":[1212,152,31,17],"text":"关闭"} |
| ui_16-detail-close-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1.25} |
| ui_16-detail-description-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":1,"dy":0.25,"actual":[562,204.75,514,19],"expected":[561,204,516,20],"text":"四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。"} |
| ui_16-detail-description-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_16-detail-add-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[798.5,770.75,74.25,17],"expected":[799,770,74,18],"text":"添加指令"} |
| ui_16-detail-add-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1} |
| ui_16-detail-beacons-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.25,"actual":[772.5,811,127.5,16.5],"expected":[772,811,129,17],"text":"信标：尚无信标"} |
| ui_16-detail-beacons-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.5} |
| ui_16-stat-0-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.25,"actual":[441.5,278,37.25,17.5],"expected":[441,277,37,19],"text":"生命"} |
| ui_16-stat-0-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.5} |
| ui_16-stat-0-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[499,279.75,19.75,14.5],"expected":[499,279,21,15],"text":"60"} |
| ui_16-stat-0-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_16-stat-1-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[590.5,277.75,37,16.75],"expected":[590,277,38,18],"text":"攻击"} |
| ui_16-stat-1-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-1.25} |
| ui_16-stat-1-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[662,279.75,9,14.5],"expected":[662,279,9,15],"text":"6"} |
| ui_16-stat-1-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0,"dh":-0.5} |
| ui_16-stat-2-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[744.5,277.75,35,16.75],"expected":[744,277,37,18],"text":"攻速"} |
| ui_16-stat-2-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_16-stat-2-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[805.25,279.25,23.5,16],"expected":[805,279,25,16],"text":"1.0"} |
| ui_16-stat-2-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0} |
| ui_16-stat-3-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0,"actual":[902.25,277.5,36,17],"expected":[902,277,38,18],"text":"移速"} |
| ui_16-stat-3-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_16-stat-3-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.5,"actual":[958.5,279.75,26.25,14.5],"expected":[958,279,28,15],"text":"4.5"} |
| ui_16-stat-3-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_16-stat-4-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1058.25,277.75,36.5,18],"expected":[1058,277,37,19],"text":"视野"} |
| ui_16-stat-4-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1} |
| ui_16-stat-4-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1114,279.75,8.75,14.5],"expected":[1114,279,9,15],"text":"9"} |
| ui_16-stat-4-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.5} |
| ui_16-stat-5-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[1188.5,277.5,38.25,18.25],"expected":[1188,277,38,19],"text":"射程"} |
| ui_16-stat-5-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-0.75} |
| ui_16-stat-5-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1246.25,279.25,23.5,16],"expected":[1246,279,24,16],"text":"1.5"} |
| ui_16-stat-5-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":0} |
| ui_16-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_17-load | 页面脚本、图片加载正常 | PASS |  |
| ui_17-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_17-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_17-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_17-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_17-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_17-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_17-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_17-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_17-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_17-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_17-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_17-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_17-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_17-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_17-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_17-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_17-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_17-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_17-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_17-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_17-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_17-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_17-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_17-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_17-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_17-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_17-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_17-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_17-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_17-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_17-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_17-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_17-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_17-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_17-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_17-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_17-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_17-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_17-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_17-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_17-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_17-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_17-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_17-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_17-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_17-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_17-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_17-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_17-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_17-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_17-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_17-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_17-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_17-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_17-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_17-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_17-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_17-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_17-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_17-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_17-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_17-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_17-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_17-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_17-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_17-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_17-detail-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[557.5,142.5,149.25,34.75],"expected":[557,142,150,35],"text":"快速形态"} |
| ui_17-detail-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.25} |
| ui_17-detail-close-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.125,"actual":[1212.5,152.75,29.25,15.75],"expected":[1212,152,31,17],"text":"关闭"} |
| ui_17-detail-close-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1.25} |
| ui_17-detail-description-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":1,"dy":0.25,"actual":[562,204.75,514,19],"expected":[561,204,516,20],"text":"四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。"} |
| ui_17-detail-description-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_17-detail-add-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[798.5,770.75,74.25,17],"expected":[799,770,74,18],"text":"添加指令"} |
| ui_17-detail-add-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1} |
| ui_17-detail-beacons-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.25,"actual":[772.5,811,127.5,16.5],"expected":[772,811,129,17],"text":"信标：尚无信标"} |
| ui_17-detail-beacons-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.5} |
| ui_17-stat-0-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.25,"actual":[441.5,278,37.25,17.5],"expected":[441,277,37,19],"text":"生命"} |
| ui_17-stat-0-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.5} |
| ui_17-stat-0-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[499,279.75,19.75,14.5],"expected":[499,279,21,15],"text":"60"} |
| ui_17-stat-0-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_17-stat-1-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[590.5,277.75,37,16.75],"expected":[590,277,38,18],"text":"攻击"} |
| ui_17-stat-1-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-1.25} |
| ui_17-stat-1-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[662,279.75,9,14.5],"expected":[662,279,9,15],"text":"6"} |
| ui_17-stat-1-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0,"dh":-0.5} |
| ui_17-stat-2-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[744.5,277.75,35,16.75],"expected":[744,277,37,18],"text":"攻速"} |
| ui_17-stat-2-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_17-stat-2-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[805.25,279.25,23.5,16],"expected":[805,279,25,16],"text":"1.0"} |
| ui_17-stat-2-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0} |
| ui_17-stat-3-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0,"actual":[902.25,277.5,36,17],"expected":[902,277,38,18],"text":"移速"} |
| ui_17-stat-3-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_17-stat-3-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.5,"actual":[958.5,279.75,26.25,14.5],"expected":[958,279,28,15],"text":"4.5"} |
| ui_17-stat-3-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_17-stat-4-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1058.25,277.75,36.5,18],"expected":[1058,277,37,19],"text":"视野"} |
| ui_17-stat-4-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1} |
| ui_17-stat-4-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1114,279.75,8.75,14.5],"expected":[1114,279,9,15],"text":"9"} |
| ui_17-stat-4-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.5} |
| ui_17-stat-5-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[1188.5,277.5,38.25,18.25],"expected":[1188,277,38,19],"text":"射程"} |
| ui_17-stat-5-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-0.75} |
| ui_17-stat-5-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1246.25,279.25,23.5,16],"expected":[1246,279,24,16],"text":"1.5"} |
| ui_17-stat-5-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":0} |
| ui_17-row-1-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0,"actual":[456.5,351,87,20],"expected":[456,351,88,20],"text":"优先级 1"} |
| ui_17-row-1-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0} |
| ui_17-row-1-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[587.5,352.25,34,16.25],"expected":[587,352,93,17],"text":"攻击"} |
| ui_17-row-1-delete-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[1172.5,354.5,33.25,17],"expected":[1172,354,35,18],"text":"删除"} |
| ui_17-row-1-delete-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_17-row-1-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":-0.375,"actual":[582.75,403.75,51.75,16.75],"expected":[582,404,54,17],"text":"条件一"} |
| ui_17-row-1-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.25} |
| ui_17-row-1-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[582.75,460.75,52.5,16.75],"expected":[583,460,53,18],"text":"条件二"} |
| ui_17-row-1-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_17-row-2-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[455.75,540.75,90.25,20.25],"expected":[456,541,91,20],"text":"优先级 2"} |
| ui_17-row-2-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":0.25} |
| ui_17-row-2-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":0,"actual":[588.75,543.25,33.25,17.5],"expected":[588,543,35,18],"text":"等待"} |
| ui_17-row-2-action-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_17-row-2-delete-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1172.25,545.25,34,16.25],"expected":[1172,545,35,17],"text":"删除"} |
| ui_17-row-2-delete-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_17-row-2-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[584.5,595.5,50,15.75],"expected":[584,595,52,17],"text":"条件一"} |
| ui_17-row-2-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_17-row-2-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[581.75,653.75,52.5,16.75],"expected":[582,653,54,18],"text":"条件二"} |
| ui_17-row-2-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_17-row-2-duration-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":-0.375,"actual":[826.25,542.75,69.75,15.75],"expected":[826,543,71,16],"text":"持续时间"} |
| ui_17-row-2-duration-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_17-row-2-duration-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[929,546.5,8.25,13.5],"expected":[929,546,9,14],"text":"2"} |
| ui_17-row-2-duration-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.5} |
| ui_17-row-2-duration-unit-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":-0.125,"actual":[1050.75,543.5,15.25,14.75],"expected":[1051,543,15,16],"text":"秒"} |
| ui_17-row-2-duration-unit-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.25} |
| ui_17-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_18-load | 页面脚本、图片加载正常 | PASS |  |
| ui_18-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_18-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_18-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_18-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_18-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_18-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_18-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_18-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_18-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_18-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_18-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_18-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_18-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_18-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_18-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_18-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_18-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_18-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_18-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_18-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_18-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_18-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_18-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_18-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_18-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_18-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_18-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_18-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_18-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_18-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_18-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_18-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_18-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_18-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_18-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_18-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_18-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_18-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_18-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_18-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_18-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_18-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_18-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_18-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_18-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_18-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_18-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_18-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_18-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_18-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_18-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_18-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_18-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_18-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_18-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_18-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_18-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_18-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_18-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_18-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_18-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_18-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_18-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_18-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_18-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_18-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_18-detail-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[557.5,142.5,149.25,34.75],"expected":[557,142,150,35],"text":"快速形态"} |
| ui_18-detail-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.25} |
| ui_18-detail-close-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.125,"actual":[1212.5,152.75,29.25,15.75],"expected":[1212,152,31,17],"text":"关闭"} |
| ui_18-detail-close-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1.25} |
| ui_18-detail-description-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":1,"dy":0.25,"actual":[562,204.75,514,19],"expected":[561,204,516,20],"text":"四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。"} |
| ui_18-detail-description-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_18-detail-add-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[798.5,770.75,74.25,17],"expected":[799,770,74,18],"text":"添加指令"} |
| ui_18-detail-add-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1} |
| ui_18-detail-beacons-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.25,"actual":[772.5,811,127.5,16.5],"expected":[772,811,129,17],"text":"信标：尚无信标"} |
| ui_18-detail-beacons-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.5} |
| ui_18-stat-0-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.25,"actual":[441.5,278,37.25,17.5],"expected":[441,277,37,19],"text":"生命"} |
| ui_18-stat-0-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.5} |
| ui_18-stat-0-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[499,279.75,19.75,14.5],"expected":[499,279,21,15],"text":"60"} |
| ui_18-stat-0-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_18-stat-1-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[590.5,277.75,37,16.75],"expected":[590,277,38,18],"text":"攻击"} |
| ui_18-stat-1-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-1.25} |
| ui_18-stat-1-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[662,279.75,9,14.5],"expected":[662,279,9,15],"text":"6"} |
| ui_18-stat-1-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0,"dh":-0.5} |
| ui_18-stat-2-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[744.5,277.75,35,16.75],"expected":[744,277,37,18],"text":"攻速"} |
| ui_18-stat-2-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_18-stat-2-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[805.25,279.25,23.5,16],"expected":[805,279,25,16],"text":"1.0"} |
| ui_18-stat-2-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0} |
| ui_18-stat-3-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0,"actual":[902.25,277.5,36,17],"expected":[902,277,38,18],"text":"移速"} |
| ui_18-stat-3-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_18-stat-3-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.5,"actual":[958.5,279.75,26.25,14.5],"expected":[958,279,28,15],"text":"4.5"} |
| ui_18-stat-3-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_18-stat-4-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1058.25,277.75,36.5,18],"expected":[1058,277,37,19],"text":"视野"} |
| ui_18-stat-4-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1} |
| ui_18-stat-4-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1114,279.75,8.75,14.5],"expected":[1114,279,9,15],"text":"9"} |
| ui_18-stat-4-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.5} |
| ui_18-stat-5-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[1188.5,277.5,38.25,18.25],"expected":[1188,277,38,19],"text":"射程"} |
| ui_18-stat-5-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-0.75} |
| ui_18-stat-5-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1246.25,279.25,23.5,16],"expected":[1246,279,24,16],"text":"1.5"} |
| ui_18-stat-5-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":0} |
| ui_18-row-1-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0,"actual":[456.5,351,87,20],"expected":[456,351,88,20],"text":"优先级 1"} |
| ui_18-row-1-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0} |
| ui_18-row-1-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[587.5,352.25,34,16.25],"expected":[587,352,93,17],"text":"等待"} |
| ui_18-row-1-delete-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[1172.5,354.5,33.25,17],"expected":[1172,354,35,18],"text":"删除"} |
| ui_18-row-1-delete-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_18-row-1-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":-0.375,"actual":[582.75,403.75,51.75,16.75],"expected":[582,404,54,17],"text":"条件一"} |
| ui_18-row-1-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.25} |
| ui_18-row-1-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[582.75,460.75,52.5,16.75],"expected":[583,460,53,18],"text":"条件二"} |
| ui_18-row-1-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_18-row-2-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[455.75,540.75,90.25,20.25],"expected":[456,541,91,20],"text":"优先级 2"} |
| ui_18-row-2-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":0.25} |
| ui_18-row-2-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":0,"actual":[588.75,543.25,33.25,17.5],"expected":[588,543,35,18],"text":"等待"} |
| ui_18-row-2-action-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_18-row-2-delete-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1172.25,545.25,34,16.25],"expected":[1172,545,35,17],"text":"删除"} |
| ui_18-row-2-delete-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_18-row-2-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[584.5,595.5,50,15.75],"expected":[584,595,52,17],"text":"条件一"} |
| ui_18-row-2-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_18-row-2-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[581.75,653.75,52.5,16.75],"expected":[582,653,54,18],"text":"条件二"} |
| ui_18-row-2-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_18-row-2-duration-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":-0.375,"actual":[826.25,542.75,69.75,15.75],"expected":[826,543,71,16],"text":"持续时间"} |
| ui_18-row-2-duration-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_18-row-2-duration-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[929,546.5,8.25,13.5],"expected":[929,546,9,14],"text":"2"} |
| ui_18-row-2-duration-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.5} |
| ui_18-row-2-duration-unit-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":-0.125,"actual":[1050.75,543.5,15.25,14.75],"expected":[1051,543,15,16],"text":"秒"} |
| ui_18-row-2-duration-unit-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.25} |
| ui_18-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_19-load | 页面脚本、图片加载正常 | PASS |  |
| ui_19-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_19-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_19-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_19-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_19-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_19-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_19-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_19-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_19-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_19-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_19-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_19-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_19-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_19-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_19-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_19-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_19-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_19-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_19-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_19-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_19-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_19-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_19-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_19-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_19-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_19-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_19-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_19-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_19-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_19-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_19-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_19-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_19-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_19-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_19-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_19-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_19-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_19-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_19-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_19-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_19-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_19-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_19-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_19-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_19-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_19-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_19-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_19-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_19-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_19-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_19-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_19-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_19-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_19-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_19-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_19-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_19-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_19-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_19-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_19-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_19-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_19-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_19-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_19-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_19-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_19-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_19-detail-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[557.5,142.5,149.25,34.75],"expected":[557,142,150,35],"text":"快速形态"} |
| ui_19-detail-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.25} |
| ui_19-detail-close-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.125,"actual":[1212.5,152.75,29.25,15.75],"expected":[1212,152,31,17],"text":"关闭"} |
| ui_19-detail-close-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1.25} |
| ui_19-detail-description-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":1,"dy":0.25,"actual":[562,204.75,514,19],"expected":[561,204,516,20],"text":"四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。"} |
| ui_19-detail-description-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_19-detail-add-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[798.5,770.75,74.25,17],"expected":[799,770,74,18],"text":"添加指令"} |
| ui_19-detail-add-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1} |
| ui_19-detail-beacons-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.25,"actual":[772.5,811,127.5,16.5],"expected":[772,811,129,17],"text":"信标：尚无信标"} |
| ui_19-detail-beacons-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.5} |
| ui_19-stat-0-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.25,"actual":[441.5,278,37.25,17.5],"expected":[441,277,37,19],"text":"生命"} |
| ui_19-stat-0-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.5} |
| ui_19-stat-0-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[499,279.75,19.75,14.5],"expected":[499,279,21,15],"text":"60"} |
| ui_19-stat-0-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_19-stat-1-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[590.5,277.75,37,16.75],"expected":[590,277,38,18],"text":"攻击"} |
| ui_19-stat-1-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-1.25} |
| ui_19-stat-1-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[662,279.75,9,14.5],"expected":[662,279,9,15],"text":"6"} |
| ui_19-stat-1-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0,"dh":-0.5} |
| ui_19-stat-2-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[744.5,277.75,35,16.75],"expected":[744,277,37,18],"text":"攻速"} |
| ui_19-stat-2-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_19-stat-2-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[805.25,279.25,23.5,16],"expected":[805,279,25,16],"text":"1.0"} |
| ui_19-stat-2-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0} |
| ui_19-stat-3-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0,"actual":[902.25,277.5,36,17],"expected":[902,277,38,18],"text":"移速"} |
| ui_19-stat-3-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_19-stat-3-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.5,"actual":[958.5,279.75,26.25,14.5],"expected":[958,279,28,15],"text":"4.5"} |
| ui_19-stat-3-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_19-stat-4-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1058.25,277.75,36.5,18],"expected":[1058,277,37,19],"text":"视野"} |
| ui_19-stat-4-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1} |
| ui_19-stat-4-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1114,279.75,8.75,14.5],"expected":[1114,279,9,15],"text":"9"} |
| ui_19-stat-4-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.5} |
| ui_19-stat-5-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[1188.5,277.5,38.25,18.25],"expected":[1188,277,38,19],"text":"射程"} |
| ui_19-stat-5-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-0.75} |
| ui_19-stat-5-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1246.25,279.25,23.5,16],"expected":[1246,279,24,16],"text":"1.5"} |
| ui_19-stat-5-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":0} |
| ui_19-row-1-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0,"actual":[456.5,351,87,20],"expected":[456,351,88,20],"text":"优先级 1"} |
| ui_19-row-1-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0} |
| ui_19-row-1-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.25,"actual":[587.5,352,91.5,16.5],"expected":[587,352,93,17],"text":"沿我的信标"} |
| ui_19-row-1-action-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.5} |
| ui_19-row-1-delete-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[1172.5,354.5,33.25,17],"expected":[1172,354,35,18],"text":"删除"} |
| ui_19-row-1-delete-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_19-row-1-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":-0.375,"actual":[582.75,403.75,51.75,16.75],"expected":[582,404,54,17],"text":"条件一"} |
| ui_19-row-1-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.25} |
| ui_19-row-1-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[582.75,460.75,52.5,16.75],"expected":[583,460,53,18],"text":"条件二"} |
| ui_19-row-1-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_19-row-2-priority-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[455.75,540.75,90.25,20.25],"expected":[456,541,91,20],"text":"优先级 2"} |
| ui_19-row-2-priority-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":0.25} |
| ui_19-row-2-action-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":0,"actual":[588.75,543.25,33.25,17.5],"expected":[588,543,35,18],"text":"等待"} |
| ui_19-row-2-action-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-0.5} |
| ui_19-row-2-delete-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1172.25,545.25,34,16.25],"expected":[1172,545,35,17],"text":"删除"} |
| ui_19-row-2-delete-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_19-row-2-condition-one-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":-0.125,"actual":[584.5,595.5,50,15.75],"expected":[584,595,52,17],"text":"条件一"} |
| ui_19-row-2-condition-one-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_19-row-2-condition-two-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.125,"actual":[581.75,653.75,52.5,16.75],"expected":[582,653,54,18],"text":"条件二"} |
| ui_19-row-2-condition-two-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_19-row-2-duration-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":-0.375,"actual":[826.25,542.75,69.75,15.75],"expected":[826,543,71,16],"text":"持续时间"} |
| ui_19-row-2-duration-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_19-row-2-duration-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[929,546.5,8.25,13.5],"expected":[929,546,9,14],"text":"2"} |
| ui_19-row-2-duration-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.5} |
| ui_19-row-2-duration-unit-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":-0.125,"actual":[1050.75,543.5,15.25,14.75],"expected":[1051,543,15,16],"text":"秒"} |
| ui_19-row-2-duration-unit-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.25} |
| ui_19-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_20-load | 页面脚本、图片加载正常 | PASS |  |
| ui_20-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_20-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_20-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_20-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_20-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_20-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_20-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":-0.375,"actual":[817.25,67.75,37.75,15.75],"expected":[816,68,41,16],"text":"18.4"} |
| ui_20-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0,"actual":[894.5,71,33.75,11],"expected":[886,71,51,11],"text":"战斗中"} |
| ui_20-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_20-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_20-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_20-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_20-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_20-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_20-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_20-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_20-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_20-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_20-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_20-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_20-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_20-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_20-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_20-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_20-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_20-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_20-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_20-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_20-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_20-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_20-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_20-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_20-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_20-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_20-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_20-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_20-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_20-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_20-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_20-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_20-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_20-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_20-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_20-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_20-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_20-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_20-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_20-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_20-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_20-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_20-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_20-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_20-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_20-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_20-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_20-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_20-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_20-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_20-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_20-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_20-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_20-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_20-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_20-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_20-detail-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[596,142.75,71.25,34.25],"expected":[557,142,150,35],"text":"骨喉"} |
| ui_20-detail-close-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.125,"actual":[1212.5,152.75,29.25,15.75],"expected":[1212,152,31,17],"text":"关闭"} |
| ui_20-detail-close-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1.25} |
| ui_20-detail-description-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":0.25,"actual":[561.75,204.75,251,19],"expected":[561,204,516,20],"text":"敌方特性与公开规则（只读）"} |
| ui_20-detail-beacons-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.25,"actual":[777,811,118.5,16.5],"expected":[772,811,129,17],"text":"敌方指令 · 只读"} |
| ui_20-stat-0-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.25,"actual":[441.5,278,37.25,17.5],"expected":[441,277,37,19],"text":"生命"} |
| ui_20-stat-0-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-1.5} |
| ui_20-stat-0-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[499,279.75,19.75,14.5],"expected":[499,279,21,15],"text":"60"} |
| ui_20-stat-0-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_20-stat-1-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[590.5,277.75,37,16.75],"expected":[590,277,38,18],"text":"攻击"} |
| ui_20-stat-1-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-1.25} |
| ui_20-stat-1-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":0.5,"actual":[662.75,279.75,9.25,14.5],"expected":[662,279,9,15],"text":"0"} |
| ui_20-stat-2-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[744.5,277.75,35,16.75],"expected":[744,277,37,18],"text":"攻速"} |
| ui_20-stat-2-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1.25} |
| ui_20-stat-2-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.25,"actual":[805,279.25,10,16],"expected":[805,279,25,16],"text":"0"} |
| ui_20-stat-3-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0,"actual":[902.25,277.5,36,17],"expected":[902,277,38,18],"text":"移速"} |
| ui_20-stat-3-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2,"dh":-1} |
| ui_20-stat-3-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.75,"dy":0.5,"actual":[958.75,279.75,9.25,14.5],"expected":[958,279,28,15],"text":"0"} |
| ui_20-stat-4-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.25,"actual":[1058.25,277.75,36.5,18],"expected":[1058,277,37,19],"text":"视野"} |
| ui_20-stat-4-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1} |
| ui_20-stat-4-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":0.375,"actual":[1114.25,279.75,17.75,14.25],"expected":[1114,279,9,15],"text":"12"} |
| ui_20-stat-5-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.5,"dy":0.125,"actual":[1188.5,277.5,38.25,18.25],"expected":[1188,277,38,19],"text":"射程"} |
| ui_20-stat-5-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":0.25,"dh":-0.75} |
| ui_20-stat-5-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.25,"actual":[1246,279.25,10,16],"expected":[1246,279,24,16],"text":"0"} |
| ui_20-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| ui_21-load | 页面脚本、图片加载正常 | PASS |  |
| ui_21-common | 公共控件仍共用唯一坐标 | PASS |  |
| ui_21-and-or | 与或符号位于两个条件之间 | PASS |  |
| ui_21-quest-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[129.75,66,136.5,20.75],"expected":[130,66,137,21],"text":"第 3 关 · 墙缝"} |
| ui_21-quest-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.25} |
| ui_21-quest-objective-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.25,"dy":-0.375,"actual":[130.25,95.5,162.5,13.25],"expected":[130,96,164,13],"text":"摧毁哭墙后方的回响骸柱"} |
| ui_21-quest-objective-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_21-timer-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.375,"actual":[816.75,68.5,39.75,15.75],"expected":[816,68,41,16],"text":"00.0"} |
| ui_21-timer-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_21-timer-phase-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[886.5,71,49.25,11],"expected":[886,71,51,11],"text":"部署阶段"} |
| ui_21-timer-phase-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":0} |
| ui_21-retry-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1206.5,75.75,24.5,13.25],"expected":[1206,75,26,14],"text":"重试"} |
| ui_21-retry-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-0.75} |
| ui_21-speed1-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.375,"actual":[1275,75.75,18.25,12.25],"expected":[1275,75,19,13],"text":"1×"} |
| ui_21-speed1-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-0.75} |
| ui_21-speed2-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1343,75.75,17.75,12.25],"expected":[1342,75,20,13],"text":"2×"} |
| ui_21-speed2-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.75} |
| ui_21-pause-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.5,"actual":[1408.25,75.75,26.5,12.5],"expected":[1408,75,27,13],"text":"暂停"} |
| ui_21-pause-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_21-settings-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1483,75.75,26.5,12.25],"expected":[1483,75,27,13],"text":"设置"} |
| ui_21-settings-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.75} |
| ui_21-exit-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.25,"actual":[1560.25,75.5,25.75,12.5],"expected":[1559,75,28,13],"text":"退出"} |
| ui_21-exit-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.25,"dh":-0.5} |
| ui_21-task-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0.375,"actual":[1457.25,137.75,24,11.25],"expected":[1457,137,25,12],"text":"任务"} |
| ui_21-task-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":-0.75} |
| ui_21-mechanics-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1559.25,137.5,51.75,11.5],"expected":[1559,137,53,12],"text":"机制说明"} |
| ui_21-mechanics-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.5} |
| ui_21-clear-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1419.5,770.5,28.5,13.75],"expected":[1419,770,30,15],"text":"清空"} |
| ui_21-clear-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":-1.25} |
| ui_21-hint-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":-0.125,"actual":[1558,770.5,28.5,13.75],"expected":[1557,770,31,15],"text":"提示"} |
| ui_21-hint-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.25} |
| ui_21-budget-title-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.25,"dy":0,"actual":[165,833.75,28.5,13.5],"expected":[164,833,31,15],"text":"预算"} |
| ui_21-budget-title-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-1.5} |
| ui_21-budget-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":-0.375,"actual":[148,857.5,57,21.25],"expected":[148,858,58,21],"text":"6 / 8"} |
| ui_21-budget-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1,"dh":0.25} |
| ui_21-start-label-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.25,"actual":[1467.75,835.5,71.5,34.5],"expected":[1467,835,74,35],"text":"开始"} |
| ui_21-start-label-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-2.5,"dh":-0.5} |
| ui_21-card-swift-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[426,851.25,59.25,14],"expected":[425,851,61,15],"text":"快速形态"} |
| ui_21-card-swift-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_21-card-swift-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[438,886.5,32.75,9.75],"expected":[438,886,33,10],"text":"COST"} |
| ui_21-card-swift-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_21-card-swift-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[489.75,880.5,13.75,23],"expected":[489,880,15,23],"text":"3"} |
| ui_21-card-swift-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_21-card-striker-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":-0.25,"actual":[601.5,851.25,91.25,14],"expected":[601,851,92,15],"text":"基础攻击形态"} |
| ui_21-card-striker-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.75,"dh":-1} |
| ui_21-card-striker-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[628,886.5,32.75,9.75],"expected":[628,886,33,10],"text":"COST"} |
| ui_21-card-striker-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_21-card-striker-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0.125,"dy":0.5,"actual":[679.75,880.5,13.75,23],"expected":[679,880,15,23],"text":"3"} |
| ui_21-card-striker-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":0} |
| ui_21-card-bulwark-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.125,"actual":[806.25,851.5,60.5,13.75],"expected":[806,851,61,15],"text":"承伤形态"} |
| ui_21-card-bulwark-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-1.25} |
| ui_21-card-bulwark-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[819.5,886.5,30.75,9.75],"expected":[819,886,32,10],"text":"COST"} |
| ui_21-card-bulwark-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_21-card-bulwark-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0,"actual":[870.25,880.5,14.75,22],"expected":[870,880,16,23],"text":"4"} |
| ui_21-card-bulwark-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-1} |
| ui_21-card-spitter-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":-0.5,"actual":[996.25,851.75,61.5,13.5],"expected":[996,852,62,14],"text":"远射形态"} |
| ui_21-card-spitter-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.5,"dh":-0.5} |
| ui_21-card-spitter-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1008,886.5,32.75,9.75],"expected":[1008,886,33,10],"text":"COST"} |
| ui_21-card-spitter-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-0.25,"dh":-0.25} |
| ui_21-card-spitter-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.375,"dy":0.25,"actual":[1059.5,879.75,15.25,23],"expected":[1059,879,17,24],"text":"4"} |
| ui_21-card-spitter-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.75,"dh":-1} |
| ui_21-card-locked-name-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":0,"dy":0.125,"actual":[1194.75,852,41.5,13.25],"expected":[1194,852,43,13],"text":"未解锁"} |
| ui_21-card-locked-name-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.5,"dh":0.25} |
| ui_21-card-locked-cost-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.125,"dy":0.375,"actual":[1198.5,886.5,30.75,9.75],"expected":[1198,886,32,10],"text":"COST"} |
| ui_21-card-locked-cost-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":-1.25,"dh":-0.25} |
| ui_21-card-locked-value-position | 字形可见边界位置对照（≤1px） | PASS | {"dx":-0.5,"dy":0.125,"actual":[1246,891.5,19,1.25],"expected":[1247,891,18,2],"text":"—"} |
| ui_21-card-locked-value-size | 同文字尺寸对照（高≤1.5px，宽≤3px） | PASS | {"dw":1,"dh":-0.75} |
| ui_21-whole-pixel-diff | 逐像素差异图与50%叠图已输出 | PASS |  |
| scroll-only-commands | 滚动指令区，标题保持固定 | PASS |  |

## 字形可见边界记录

| 页面 / 字段 | 文字 | 原图 x,y,w,h | 实际 x,y,w,h | 字号 | 字间距 |
|---|---|---|---|---|---|
| ui_01 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_01 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_01 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_01 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_01 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_01 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_01 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_01 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_01 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_01 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_01 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_01 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_01 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_01 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_01 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_01 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_01 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_01 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_01 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_01 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_01 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_01 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_01 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_01 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_01 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_01 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_01 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_01 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_01 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_01 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_01 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_01 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_02 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_02 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_02 / timer-value | 18.4 | 816, 68, 41, 16 | 817.25, 67.75, 37.75, 15.75 | 20.5 | 0.000 |
| ui_02 / timer-phase | 战斗中 | 886, 71, 51, 11 | 894.5, 71, 33.75, 11 | 11.75 | 0.000 |
| ui_02 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_02 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_02 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_02 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_02 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_02 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_02 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_02 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_02 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_02 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_02 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_02 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_02 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_02 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_02 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_02 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_02 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_02 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_02 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_02 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_02 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_02 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_02 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_02 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_02 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_02 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_02 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_02 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_03 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_03 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_03 / timer-value | 12.6 | 816, 68, 41, 16 | 817.25, 68.5, 37.5, 15.75 | 20.75 | 0.000 |
| ui_03 / timer-phase | 已暂停 | 886, 71, 51, 11 | 894, 71, 34, 11 | 11.75 | 0.000 |
| ui_03 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_03 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_03 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_03 / pause-label | 继续 | 1408, 75, 27, 13 | 1408.25, 75.75, 26, 12.25 | 13.375 | 0.000 |
| ui_03 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_03 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_03 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_03 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_03 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_03 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_03 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_03 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_03 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_03 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_03 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_03 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_03 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_03 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_03 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_03 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_03 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_03 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_03 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_03 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_03 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_03 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_03 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_03 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_04 / quest-title | 第 7 关 · 守住归途 | 130, 66, 137, 21 | 129.75, 66, 176.25, 21 | 22.5 | 0.000 |
| ui_04 / quest-objective | 保护转运点存活 20 秒 | 130, 96, 164, 13 | 130.25, 96, 134.25, 13.25 | 14 | 0.000 |
| ui_04 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_04 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_04 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_04 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_04 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_04 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_04 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_04 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_04 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_04 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_04 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_04 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_04 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_04 / card-swift-name | 承伤形态 | 425, 851, 61, 15 | 426.25, 851.5, 58.5, 13.75 | 14.75 | 0.000 |
| ui_04 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_04 / card-swift-value | 4 | 489, 880, 15, 23 | 488.5, 880.25, 15.25, 23 | 30.25 | 0.000 |
| ui_04 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_04 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_04 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_04 / card-bulwark-name | 远射形态 | 806, 851, 61, 15 | 807.25, 851.5, 58.5, 13.75 | 14.75 | 0.000 |
| ui_04 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_04 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_04 / card-spitter-name | 未解锁 | 996, 852, 62, 14 | 1005.25, 852, 43, 13.75 | 14.5 | 0.000 |
| ui_04 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_04 / card-spitter-value | — | 1059, 879, 17, 24 | 1054.75, 890.5, 26, 1.75 | 32 | 0.000 |
| ui_04 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_04 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_04 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_05 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_05 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_05 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_05 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_05 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_05 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_05 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_05 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_05 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_05 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_05 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_05 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_05 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_05 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_05 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_05 / budget-value | 12 / 8 | 148, 858, 58, 21 | 151, 857.5, 52, 21.25 | 22.25 | 0.000 |
| ui_05 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_05 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_05 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_05 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_05 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_05 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_05 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_05 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_05 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_05 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_05 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_05 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_05 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_05 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_05 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_05 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_06 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_06 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_06 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_06 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_06 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_06 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_06 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_06 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_06 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_06 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_06 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_06 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_06 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_06 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_06 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_06 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_06 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_06 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_06 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_06 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_06 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_06 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_06 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_06 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_06 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_06 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_06 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_06 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_06 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_06 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_06 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_06 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_07 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_07 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_07 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_07 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_07 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_07 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_07 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_07 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_07 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_07 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_07 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_07 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_07 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_07 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_07 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_07 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_07 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_07 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_07 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_07 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_07 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_07 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_07 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_07 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_07 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_07 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_07 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_07 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_07 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_07 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_07 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_07 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_08 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_08 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_08 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_08 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_08 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_08 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_08 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_08 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_08 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_08 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_08 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_08 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_08 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_08 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_08 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_08 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_08 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_08 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_08 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_08 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_08 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_08 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_08 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_08 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_08 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_08 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_08 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_08 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_08 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_08 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_08 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_08 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_09 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_09 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_09 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_09 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_09 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_09 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_09 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_09 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_09 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_09 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_09 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_09 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_09 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_09 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_09 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_09 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_09 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_09 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_09 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_09 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_09 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_09 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_09 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_09 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_09 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_09 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_09 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_09 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_09 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_09 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_09 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_09 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_10 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_10 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_10 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_10 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_10 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_10 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_10 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_10 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_10 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_10 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_10 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_10 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_10 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_10 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_10 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_10 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_10 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_10 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_10 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_10 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_10 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_10 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_10 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_10 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_10 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_10 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_10 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_10 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_10 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_10 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_10 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_10 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_11 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_11 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_11 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_11 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_11 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_11 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_11 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_11 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_11 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_11 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_11 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_11 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_11 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_11 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_11 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_11 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_11 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_11 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_11 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_11 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_11 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_11 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_11 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_11 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_11 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_11 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_11 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_11 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_11 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_11 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_11 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_11 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_12 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_12 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_12 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_12 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_12 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_12 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_12 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_12 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_12 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_12 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_12 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_12 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_12 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_12 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_12 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_12 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_12 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_12 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_12 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_12 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_12 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_12 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_12 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_12 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_12 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_12 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_12 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_12 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_12 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_12 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_12 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_12 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_12 / detail-title | 快速形态 | 557, 142, 150, 35 | 557.5, 142.5, 149.25, 34.75 | 37.25 | 1.000 |
| ui_12 / detail-close | 关闭 | 1212, 152, 31, 17 | 1212.5, 152.75, 29.25, 15.75 | 16.75 | -3.000 |
| ui_12 / detail-description | 四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。 | 561, 204, 516, 20 | 562, 204.75, 514, 19 | 20.375 | 0.000 |
| ui_12 / detail-add | 添加指令 | 799, 770, 74, 18 | 798.5, 770.75, 74.25, 17 | 18 | 1.000 |
| ui_12 / detail-beacons | 信标：尚无信标 | 772, 811, 129, 17 | 772.5, 811, 127.5, 16.5 | 17.5 | 1.000 |
| ui_12 / stat-0-name | 生命 | 441, 277, 37, 19 | 441.5, 278, 37.25, 17.5 | 19 | 0.000 |
| ui_12 / stat-0-value | 60 | 499, 279, 21, 15 | 499, 279.75, 19.75, 14.5 | 19.25 | 0.000 |
| ui_12 / stat-1-name | 攻击 | 590, 277, 38, 18 | 590.5, 277.75, 37, 16.75 | 18 | 2.000 |
| ui_12 / stat-1-value | 6 | 662, 279, 9, 15 | 662, 279.75, 9, 14.5 | 19.25 | 0.000 |
| ui_12 / stat-2-name | 攻速 | 744, 277, 37, 18 | 744.5, 277.75, 35, 16.75 | 18 | 0.000 |
| ui_12 / stat-2-value | 1.0 | 805, 279, 25, 16 | 805.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_12 / stat-3-name | 移速 | 902, 277, 38, 18 | 902.25, 277.5, 36, 17 | 18.375 | 0.000 |
| ui_12 / stat-3-value | 4.5 | 958, 279, 28, 15 | 958.5, 279.75, 26.25, 14.5 | 19.25 | 0.000 |
| ui_12 / stat-4-name | 视野 | 1058, 277, 37, 19 | 1058.25, 277.75, 36.5, 18 | 19.5 | -2.000 |
| ui_12 / stat-4-value | 9 | 1114, 279, 9, 15 | 1114, 279.75, 8.75, 14.5 | 19.25 | 0.000 |
| ui_12 / stat-5-name | 射程 | 1188, 277, 38, 19 | 1188.5, 277.5, 38.25, 18.25 | 19.5 | 0.000 |
| ui_12 / stat-5-value | 1.5 | 1246, 279, 24, 16 | 1246.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_12 / row-1-priority | 优先级 1 | 456, 351, 88, 20 | 456.5, 351, 87, 20 | 21.25 | 2.250 |
| ui_12 / row-1-action | 攻击 | 587, 352, 93, 17 | 587.5, 352.25, 34, 16.25 | 17.5 | 0.000 |
| ui_12 / row-1-delete | 删除 | 1172, 354, 35, 18 | 1172.5, 354.5, 33.25, 17 | 18.5 | -3.000 |
| ui_12 / row-1-condition-one | 条件一 | 582, 404, 54, 17 | 582.75, 403.75, 51.75, 16.75 | 17.75 | 0.000 |
| ui_12 / row-1-condition-two | 条件二 | 583, 460, 53, 18 | 582.75, 460.75, 52.5, 16.75 | 18 | 0.000 |
| ui_12 / row-2-priority | 优先级 2 | 456, 541, 91, 20 | 455.75, 540.75, 90.25, 20.25 | 21.5 | 2.500 |
| ui_12 / row-2-action | 等待 | 588, 543, 35, 18 | 588.75, 543.25, 33.25, 17.5 | 18.75 | -3.000 |
| ui_12 / row-2-delete | 删除 | 1172, 545, 35, 17 | 1172.25, 545.25, 34, 16.25 | 17.25 | 0.000 |
| ui_12 / row-2-condition-one | 条件一 | 584, 595, 52, 17 | 584.5, 595.5, 50, 15.75 | 17 | 0.000 |
| ui_12 / row-2-condition-two | 条件二 | 582, 653, 54, 18 | 581.75, 653.75, 52.5, 16.75 | 18 | 0.000 |
| ui_12 / row-2-duration-label | 持续时间 | 826, 543, 71, 16 | 826.25, 542.75, 69.75, 15.75 | 16.75 | 1.333 |
| ui_12 / row-2-duration-value | 2 | 929, 546, 9, 14 | 929, 546.5, 8.25, 13.5 | 18 | 0.000 |
| ui_12 / row-2-duration-unit | 秒 | 1051, 543, 15, 16 | 1050.75, 543.5, 15.25, 14.75 | 16 | 0.000 |
| ui_13 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_13 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_13 / timer-value | 18.4 | 816, 68, 41, 16 | 817.25, 67.75, 37.75, 15.75 | 20.5 | 0.000 |
| ui_13 / timer-phase | 战斗中 | 886, 71, 51, 11 | 894.5, 71, 33.75, 11 | 11.75 | 0.000 |
| ui_13 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_13 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_13 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_13 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_13 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_13 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_13 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_13 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_13 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_13 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_13 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_13 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_13 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_13 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_13 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_13 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_13 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_13 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_13 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_13 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_13 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_13 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_13 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_13 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_13 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_13 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_13 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_13 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_13 / detail-title | 快速形态 | 557, 142, 150, 35 | 557.5, 142.5, 149.25, 34.75 | 37.25 | 1.000 |
| ui_13 / detail-close | 关闭 | 1212, 152, 31, 17 | 1212.5, 152.75, 29.25, 15.75 | 16.75 | -3.000 |
| ui_13 / detail-description | 战斗中无法编辑指令。 | 561, 204, 516, 20 | 561.75, 204.75, 188.25, 19 | 20.375 | 0.000 |
| ui_13 / detail-beacons | 战斗中无法编辑指令 | 772, 811, 129, 17 | 758.5, 811, 155.75, 16.5 | 17.5 | 0.000 |
| ui_13 / stat-0-name | 生命 | 441, 277, 37, 19 | 441.5, 278, 37.25, 17.5 | 19 | 0.000 |
| ui_13 / stat-0-value | 60 | 499, 279, 21, 15 | 499, 279.75, 19.75, 14.5 | 19.25 | 0.000 |
| ui_13 / stat-1-name | 攻击 | 590, 277, 38, 18 | 590.5, 277.75, 37, 16.75 | 18 | 2.000 |
| ui_13 / stat-1-value | 6 | 662, 279, 9, 15 | 662, 279.75, 9, 14.5 | 19.25 | 0.000 |
| ui_13 / stat-2-name | 攻速 | 744, 277, 37, 18 | 744.5, 277.75, 35, 16.75 | 18 | 0.000 |
| ui_13 / stat-2-value | 1.0 | 805, 279, 25, 16 | 805.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_13 / stat-3-name | 移速 | 902, 277, 38, 18 | 902.25, 277.5, 36, 17 | 18.375 | 0.000 |
| ui_13 / stat-3-value | 4.5 | 958, 279, 28, 15 | 958.5, 279.75, 26.25, 14.5 | 19.25 | 0.000 |
| ui_13 / stat-4-name | 视野 | 1058, 277, 37, 19 | 1058.25, 277.75, 36.5, 18 | 19.5 | -2.000 |
| ui_13 / stat-4-value | 9 | 1114, 279, 9, 15 | 1114, 279.75, 8.75, 14.5 | 19.25 | 0.000 |
| ui_13 / stat-5-name | 射程 | 1188, 277, 38, 19 | 1188.5, 277.5, 38.25, 18.25 | 19.5 | 0.000 |
| ui_13 / stat-5-value | 1.5 | 1246, 279, 24, 16 | 1246.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_13 / row-1-priority | 优先级 1 | 456, 351, 88, 20 | 456.5, 351, 87, 20 | 21.25 | 2.250 |
| ui_13 / row-1-action | 攻击 | 587, 352, 93, 17 | 587.5, 352.25, 34, 16.25 | 17.5 | 0.000 |
| ui_13 / row-1-condition-one | 条件一 | 582, 404, 54, 17 | 582.75, 403.75, 51.75, 16.75 | 17.75 | 0.000 |
| ui_13 / row-1-condition-two | 条件二 | 583, 460, 53, 18 | 582.75, 460.75, 52.5, 16.75 | 18 | 0.000 |
| ui_13 / row-2-priority | 优先级 2 | 456, 541, 91, 20 | 455.75, 540.75, 90.25, 20.25 | 21.5 | 2.500 |
| ui_13 / row-2-action | 等待 | 588, 543, 35, 18 | 588.75, 543.25, 33.25, 17.5 | 18.75 | -3.000 |
| ui_13 / row-2-condition-one | 条件一 | 584, 595, 52, 17 | 584.5, 595.5, 50, 15.75 | 17 | 0.000 |
| ui_13 / row-2-condition-two | 条件二 | 582, 653, 54, 18 | 581.75, 653.75, 52.5, 16.75 | 18 | 0.000 |
| ui_13 / row-2-duration-label | 持续时间 | 826, 543, 71, 16 | 826.25, 542.75, 69.75, 15.75 | 16.75 | 1.333 |
| ui_13 / row-2-duration-value | 2 | 929, 546, 9, 14 | 929, 546.5, 8.25, 13.5 | 18 | 0.000 |
| ui_13 / row-2-duration-unit | 秒 | 1051, 543, 15, 16 | 1050.75, 543.5, 15.25, 14.75 | 16 | 0.000 |
| ui_14 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_14 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_14 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_14 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_14 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_14 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_14 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_14 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_14 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_14 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_14 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_14 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_14 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_14 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_14 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_14 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_14 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_14 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_14 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_14 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_14 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_14 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_14 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_14 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_14 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_14 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_14 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_14 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_14 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_14 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_14 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_14 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_14 / detail-title | 哭墙守卫 | 557, 142, 150, 35 | 559, 142.5, 146.25, 34.5 | 37.25 | 0.000 |
| ui_14 / detail-close | 关闭 | 1212, 152, 31, 17 | 1212.5, 152.75, 29.25, 15.75 | 16.75 | -3.000 |
| ui_14 / detail-description | 敌方指令只读，从上到下执行第一条成立的指令。 | 561, 204, 516, 20 | 561.75, 203.75, 404.5, 20 | 19 | 0.000 |
| ui_14 / detail-beacons | 敌方指令 · 只读 | 772, 811, 129, 17 | 777, 811, 118.5, 16.5 | 17.5 | 0.000 |
| ui_14 / stat-0-name | 生命 | 441, 277, 37, 19 | 441.5, 278, 37.25, 17.5 | 19 | 0.000 |
| ui_14 / stat-0-value | 90 | 499, 279, 21, 15 | 499, 279.75, 19.75, 14.5 | 19.25 | 0.000 |
| ui_14 / stat-1-name | 攻击 | 590, 277, 38, 18 | 590.5, 277.75, 37, 16.75 | 18 | 2.000 |
| ui_14 / stat-1-value | 10 | 662, 279, 9, 15 | 662.25, 279.75, 17.75, 14.5 | 19.25 | 0.000 |
| ui_14 / stat-2-name | 攻速 | 744, 277, 37, 18 | 744.5, 277.75, 35, 16.75 | 18 | 0.000 |
| ui_14 / stat-2-value | 0.8 | 805, 279, 25, 16 | 805, 279.25, 28.75, 16 | 21.25 | 0.000 |
| ui_14 / stat-3-name | 移速 | 902, 277, 38, 18 | 902.25, 277.5, 36, 17 | 18.375 | 0.000 |
| ui_14 / stat-3-value | 1.2 | 958, 279, 28, 15 | 958.25, 279.75, 24, 14.5 | 19.25 | 0.000 |
| ui_14 / stat-4-name | 视野 | 1058, 277, 37, 19 | 1058.25, 277.75, 36.5, 18 | 19.5 | -2.000 |
| ui_14 / stat-4-value | 6 | 1114, 279, 9, 15 | 1114, 279.75, 9, 14.5 | 19.25 | 0.000 |
| ui_14 / stat-5-name | 射程 | 1188, 277, 38, 19 | 1188.5, 277.5, 38.25, 18.25 | 19.5 | 0.000 |
| ui_14 / stat-5-value | 2 | 1246, 279, 24, 16 | 1246.25, 279.25, 9.75, 15.75 | 21.25 | 0.000 |
| ui_14 / row-1-priority | 优先级 1 | 456, 351, 88, 20 | 456.5, 351, 87, 20 | 21.25 | 2.250 |
| ui_14 / row-1-action | 攻击 | 587, 352, 93, 17 | 587.5, 352.25, 34, 16.25 | 17.5 | 0.000 |
| ui_14 / row-1-condition-one | 条件一 | 582, 404, 54, 17 | 582.75, 403.75, 51.75, 16.75 | 17.75 | 0.000 |
| ui_14 / row-1-condition-two | 条件二 | 583, 460, 53, 18 | 582.75, 460.75, 52.5, 16.75 | 18 | 0.000 |
| ui_15 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_15 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_15 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_15 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_15 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_15 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_15 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_15 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_15 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_15 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_15 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_15 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_15 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_15 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_15 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_15 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_15 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_15 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_15 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_15 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_15 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_15 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_15 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_15 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_15 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_15 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_15 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_15 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_15 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_15 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_15 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_15 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_15 / detail-title | 快速形态 | 557, 142, 150, 35 | 557.5, 142.5, 149.25, 34.75 | 37.25 | 1.000 |
| ui_15 / detail-close | 关闭 | 1212, 152, 31, 17 | 1212.5, 152.75, 29.25, 15.75 | 16.75 | -3.000 |
| ui_15 / detail-description | 四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。 | 561, 204, 516, 20 | 562, 204.75, 514, 19 | 20.375 | 0.000 |
| ui_15 / detail-add | 添加指令 | 799, 770, 74, 18 | 798.5, 770.75, 74.25, 17 | 18 | 1.000 |
| ui_15 / detail-beacons | 信标：尚无信标 | 772, 811, 129, 17 | 772.5, 811, 127.5, 16.5 | 17.5 | 1.000 |
| ui_15 / stat-0-name | 生命 | 441, 277, 37, 19 | 441.5, 278, 37.25, 17.5 | 19 | 0.000 |
| ui_15 / stat-0-value | 60 | 499, 279, 21, 15 | 499, 279.75, 19.75, 14.5 | 19.25 | 0.000 |
| ui_15 / stat-1-name | 攻击 | 590, 277, 38, 18 | 590.5, 277.75, 37, 16.75 | 18 | 2.000 |
| ui_15 / stat-1-value | 6 | 662, 279, 9, 15 | 662, 279.75, 9, 14.5 | 19.25 | 0.000 |
| ui_15 / stat-2-name | 攻速 | 744, 277, 37, 18 | 744.5, 277.75, 35, 16.75 | 18 | 0.000 |
| ui_15 / stat-2-value | 1.0 | 805, 279, 25, 16 | 805.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_15 / stat-3-name | 移速 | 902, 277, 38, 18 | 902.25, 277.5, 36, 17 | 18.375 | 0.000 |
| ui_15 / stat-3-value | 4.5 | 958, 279, 28, 15 | 958.5, 279.75, 26.25, 14.5 | 19.25 | 0.000 |
| ui_15 / stat-4-name | 视野 | 1058, 277, 37, 19 | 1058.25, 277.75, 36.5, 18 | 19.5 | -2.000 |
| ui_15 / stat-4-value | 9 | 1114, 279, 9, 15 | 1114, 279.75, 8.75, 14.5 | 19.25 | 0.000 |
| ui_15 / stat-5-name | 射程 | 1188, 277, 38, 19 | 1188.5, 277.5, 38.25, 18.25 | 19.5 | 0.000 |
| ui_15 / stat-5-value | 1.5 | 1246, 279, 24, 16 | 1246.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_16 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_16 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_16 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_16 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_16 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_16 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_16 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_16 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_16 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_16 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_16 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_16 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_16 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_16 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_16 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_16 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_16 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_16 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_16 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_16 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_16 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_16 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_16 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_16 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_16 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_16 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_16 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_16 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_16 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_16 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_16 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_16 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_16 / detail-title | 快速形态 | 557, 142, 150, 35 | 557.5, 142.5, 149.25, 34.75 | 37.25 | 1.000 |
| ui_16 / detail-close | 关闭 | 1212, 152, 31, 17 | 1212.5, 152.75, 29.25, 15.75 | 16.75 | -3.000 |
| ui_16 / detail-description | 四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。 | 561, 204, 516, 20 | 562, 204.75, 514, 19 | 20.375 | 0.000 |
| ui_16 / detail-add | 添加指令 | 799, 770, 74, 18 | 798.5, 770.75, 74.25, 17 | 18 | 1.000 |
| ui_16 / detail-beacons | 信标：尚无信标 | 772, 811, 129, 17 | 772.5, 811, 127.5, 16.5 | 17.5 | 1.000 |
| ui_16 / stat-0-name | 生命 | 441, 277, 37, 19 | 441.5, 278, 37.25, 17.5 | 19 | 0.000 |
| ui_16 / stat-0-value | 60 | 499, 279, 21, 15 | 499, 279.75, 19.75, 14.5 | 19.25 | 0.000 |
| ui_16 / stat-1-name | 攻击 | 590, 277, 38, 18 | 590.5, 277.75, 37, 16.75 | 18 | 2.000 |
| ui_16 / stat-1-value | 6 | 662, 279, 9, 15 | 662, 279.75, 9, 14.5 | 19.25 | 0.000 |
| ui_16 / stat-2-name | 攻速 | 744, 277, 37, 18 | 744.5, 277.75, 35, 16.75 | 18 | 0.000 |
| ui_16 / stat-2-value | 1.0 | 805, 279, 25, 16 | 805.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_16 / stat-3-name | 移速 | 902, 277, 38, 18 | 902.25, 277.5, 36, 17 | 18.375 | 0.000 |
| ui_16 / stat-3-value | 4.5 | 958, 279, 28, 15 | 958.5, 279.75, 26.25, 14.5 | 19.25 | 0.000 |
| ui_16 / stat-4-name | 视野 | 1058, 277, 37, 19 | 1058.25, 277.75, 36.5, 18 | 19.5 | -2.000 |
| ui_16 / stat-4-value | 9 | 1114, 279, 9, 15 | 1114, 279.75, 8.75, 14.5 | 19.25 | 0.000 |
| ui_16 / stat-5-name | 射程 | 1188, 277, 38, 19 | 1188.5, 277.5, 38.25, 18.25 | 19.5 | 0.000 |
| ui_16 / stat-5-value | 1.5 | 1246, 279, 24, 16 | 1246.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_17 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_17 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_17 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_17 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_17 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_17 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_17 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_17 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_17 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_17 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_17 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_17 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_17 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_17 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_17 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_17 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_17 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_17 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_17 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_17 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_17 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_17 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_17 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_17 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_17 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_17 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_17 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_17 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_17 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_17 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_17 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_17 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_17 / detail-title | 快速形态 | 557, 142, 150, 35 | 557.5, 142.5, 149.25, 34.75 | 37.25 | 1.000 |
| ui_17 / detail-close | 关闭 | 1212, 152, 31, 17 | 1212.5, 152.75, 29.25, 15.75 | 16.75 | -3.000 |
| ui_17 / detail-description | 四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。 | 561, 204, 516, 20 | 562, 204.75, 514, 19 | 20.375 | 0.000 |
| ui_17 / detail-add | 添加指令 | 799, 770, 74, 18 | 798.5, 770.75, 74.25, 17 | 18 | 1.000 |
| ui_17 / detail-beacons | 信标：尚无信标 | 772, 811, 129, 17 | 772.5, 811, 127.5, 16.5 | 17.5 | 1.000 |
| ui_17 / stat-0-name | 生命 | 441, 277, 37, 19 | 441.5, 278, 37.25, 17.5 | 19 | 0.000 |
| ui_17 / stat-0-value | 60 | 499, 279, 21, 15 | 499, 279.75, 19.75, 14.5 | 19.25 | 0.000 |
| ui_17 / stat-1-name | 攻击 | 590, 277, 38, 18 | 590.5, 277.75, 37, 16.75 | 18 | 2.000 |
| ui_17 / stat-1-value | 6 | 662, 279, 9, 15 | 662, 279.75, 9, 14.5 | 19.25 | 0.000 |
| ui_17 / stat-2-name | 攻速 | 744, 277, 37, 18 | 744.5, 277.75, 35, 16.75 | 18 | 0.000 |
| ui_17 / stat-2-value | 1.0 | 805, 279, 25, 16 | 805.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_17 / stat-3-name | 移速 | 902, 277, 38, 18 | 902.25, 277.5, 36, 17 | 18.375 | 0.000 |
| ui_17 / stat-3-value | 4.5 | 958, 279, 28, 15 | 958.5, 279.75, 26.25, 14.5 | 19.25 | 0.000 |
| ui_17 / stat-4-name | 视野 | 1058, 277, 37, 19 | 1058.25, 277.75, 36.5, 18 | 19.5 | -2.000 |
| ui_17 / stat-4-value | 9 | 1114, 279, 9, 15 | 1114, 279.75, 8.75, 14.5 | 19.25 | 0.000 |
| ui_17 / stat-5-name | 射程 | 1188, 277, 38, 19 | 1188.5, 277.5, 38.25, 18.25 | 19.5 | 0.000 |
| ui_17 / stat-5-value | 1.5 | 1246, 279, 24, 16 | 1246.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_17 / row-1-priority | 优先级 1 | 456, 351, 88, 20 | 456.5, 351, 87, 20 | 21.25 | 2.250 |
| ui_17 / row-1-action | 攻击 | 587, 352, 93, 17 | 587.5, 352.25, 34, 16.25 | 17.5 | 0.000 |
| ui_17 / row-1-delete | 删除 | 1172, 354, 35, 18 | 1172.5, 354.5, 33.25, 17 | 18.5 | -3.000 |
| ui_17 / row-1-condition-one | 条件一 | 582, 404, 54, 17 | 582.75, 403.75, 51.75, 16.75 | 17.75 | 0.000 |
| ui_17 / row-1-condition-two | 条件二 | 583, 460, 53, 18 | 582.75, 460.75, 52.5, 16.75 | 18 | 0.000 |
| ui_17 / row-2-priority | 优先级 2 | 456, 541, 91, 20 | 455.75, 540.75, 90.25, 20.25 | 21.5 | 2.500 |
| ui_17 / row-2-action | 等待 | 588, 543, 35, 18 | 588.75, 543.25, 33.25, 17.5 | 18.75 | -3.000 |
| ui_17 / row-2-delete | 删除 | 1172, 545, 35, 17 | 1172.25, 545.25, 34, 16.25 | 17.25 | 0.000 |
| ui_17 / row-2-condition-one | 条件一 | 584, 595, 52, 17 | 584.5, 595.5, 50, 15.75 | 17 | 0.000 |
| ui_17 / row-2-condition-two | 条件二 | 582, 653, 54, 18 | 581.75, 653.75, 52.5, 16.75 | 18 | 0.000 |
| ui_17 / row-2-duration-label | 持续时间 | 826, 543, 71, 16 | 826.25, 542.75, 69.75, 15.75 | 16.75 | 1.333 |
| ui_17 / row-2-duration-value | 2 | 929, 546, 9, 14 | 929, 546.5, 8.25, 13.5 | 18 | 0.000 |
| ui_17 / row-2-duration-unit | 秒 | 1051, 543, 15, 16 | 1050.75, 543.5, 15.25, 14.75 | 16 | 0.000 |
| ui_18 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_18 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_18 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_18 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_18 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_18 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_18 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_18 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_18 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_18 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_18 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_18 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_18 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_18 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_18 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_18 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_18 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_18 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_18 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_18 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_18 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_18 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_18 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_18 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_18 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_18 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_18 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_18 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_18 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_18 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_18 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_18 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_18 / detail-title | 快速形态 | 557, 142, 150, 35 | 557.5, 142.5, 149.25, 34.75 | 37.25 | 1.000 |
| ui_18 / detail-close | 关闭 | 1212, 152, 31, 17 | 1212.5, 152.75, 29.25, 15.75 | 16.75 | -3.000 |
| ui_18 / detail-description | 四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。 | 561, 204, 516, 20 | 562, 204.75, 514, 19 | 20.375 | 0.000 |
| ui_18 / detail-add | 添加指令 | 799, 770, 74, 18 | 798.5, 770.75, 74.25, 17 | 18 | 1.000 |
| ui_18 / detail-beacons | 信标：尚无信标 | 772, 811, 129, 17 | 772.5, 811, 127.5, 16.5 | 17.5 | 1.000 |
| ui_18 / stat-0-name | 生命 | 441, 277, 37, 19 | 441.5, 278, 37.25, 17.5 | 19 | 0.000 |
| ui_18 / stat-0-value | 60 | 499, 279, 21, 15 | 499, 279.75, 19.75, 14.5 | 19.25 | 0.000 |
| ui_18 / stat-1-name | 攻击 | 590, 277, 38, 18 | 590.5, 277.75, 37, 16.75 | 18 | 2.000 |
| ui_18 / stat-1-value | 6 | 662, 279, 9, 15 | 662, 279.75, 9, 14.5 | 19.25 | 0.000 |
| ui_18 / stat-2-name | 攻速 | 744, 277, 37, 18 | 744.5, 277.75, 35, 16.75 | 18 | 0.000 |
| ui_18 / stat-2-value | 1.0 | 805, 279, 25, 16 | 805.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_18 / stat-3-name | 移速 | 902, 277, 38, 18 | 902.25, 277.5, 36, 17 | 18.375 | 0.000 |
| ui_18 / stat-3-value | 4.5 | 958, 279, 28, 15 | 958.5, 279.75, 26.25, 14.5 | 19.25 | 0.000 |
| ui_18 / stat-4-name | 视野 | 1058, 277, 37, 19 | 1058.25, 277.75, 36.5, 18 | 19.5 | -2.000 |
| ui_18 / stat-4-value | 9 | 1114, 279, 9, 15 | 1114, 279.75, 8.75, 14.5 | 19.25 | 0.000 |
| ui_18 / stat-5-name | 射程 | 1188, 277, 38, 19 | 1188.5, 277.5, 38.25, 18.25 | 19.5 | 0.000 |
| ui_18 / stat-5-value | 1.5 | 1246, 279, 24, 16 | 1246.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_18 / row-1-priority | 优先级 1 | 456, 351, 88, 20 | 456.5, 351, 87, 20 | 21.25 | 2.250 |
| ui_18 / row-1-action | 等待 | 587, 352, 93, 17 | 587.5, 352.25, 34, 16.25 | 17.5 | 0.000 |
| ui_18 / row-1-delete | 删除 | 1172, 354, 35, 18 | 1172.5, 354.5, 33.25, 17 | 18.5 | -3.000 |
| ui_18 / row-1-condition-one | 条件一 | 582, 404, 54, 17 | 582.75, 403.75, 51.75, 16.75 | 17.75 | 0.000 |
| ui_18 / row-1-condition-two | 条件二 | 583, 460, 53, 18 | 582.75, 460.75, 52.5, 16.75 | 18 | 0.000 |
| ui_18 / row-2-priority | 优先级 2 | 456, 541, 91, 20 | 455.75, 540.75, 90.25, 20.25 | 21.5 | 2.500 |
| ui_18 / row-2-action | 等待 | 588, 543, 35, 18 | 588.75, 543.25, 33.25, 17.5 | 18.75 | -3.000 |
| ui_18 / row-2-delete | 删除 | 1172, 545, 35, 17 | 1172.25, 545.25, 34, 16.25 | 17.25 | 0.000 |
| ui_18 / row-2-condition-one | 条件一 | 584, 595, 52, 17 | 584.5, 595.5, 50, 15.75 | 17 | 0.000 |
| ui_18 / row-2-condition-two | 条件二 | 582, 653, 54, 18 | 581.75, 653.75, 52.5, 16.75 | 18 | 0.000 |
| ui_18 / row-2-duration-label | 持续时间 | 826, 543, 71, 16 | 826.25, 542.75, 69.75, 15.75 | 16.75 | 1.333 |
| ui_18 / row-2-duration-value | 2 | 929, 546, 9, 14 | 929, 546.5, 8.25, 13.5 | 18 | 0.000 |
| ui_18 / row-2-duration-unit | 秒 | 1051, 543, 15, 16 | 1050.75, 543.5, 15.25, 14.75 | 16 | 0.000 |
| ui_19 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_19 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_19 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_19 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_19 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_19 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_19 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_19 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_19 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_19 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_19 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_19 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_19 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_19 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_19 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_19 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_19 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_19 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_19 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_19 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_19 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_19 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_19 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_19 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_19 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_19 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_19 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_19 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_19 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_19 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_19 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_19 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_19 / detail-title | 快速形态 | 557, 142, 150, 35 | 557.5, 142.5, 149.25, 34.75 | 37.25 | 1.000 |
| ui_19 / detail-close | 关闭 | 1212, 152, 31, 17 | 1212.5, 152.75, 29.25, 15.75 | 16.75 | -3.000 |
| ui_19 / detail-description | 四肢拉长、脊骨外露的轻捷形态。用来诱敌、牵制与撤离。 | 561, 204, 516, 20 | 562, 204.75, 514, 19 | 20.375 | 0.000 |
| ui_19 / detail-add | 添加指令 | 799, 770, 74, 18 | 798.5, 770.75, 74.25, 17 | 18 | 1.000 |
| ui_19 / detail-beacons | 信标：尚无信标 | 772, 811, 129, 17 | 772.5, 811, 127.5, 16.5 | 17.5 | 1.000 |
| ui_19 / stat-0-name | 生命 | 441, 277, 37, 19 | 441.5, 278, 37.25, 17.5 | 19 | 0.000 |
| ui_19 / stat-0-value | 60 | 499, 279, 21, 15 | 499, 279.75, 19.75, 14.5 | 19.25 | 0.000 |
| ui_19 / stat-1-name | 攻击 | 590, 277, 38, 18 | 590.5, 277.75, 37, 16.75 | 18 | 2.000 |
| ui_19 / stat-1-value | 6 | 662, 279, 9, 15 | 662, 279.75, 9, 14.5 | 19.25 | 0.000 |
| ui_19 / stat-2-name | 攻速 | 744, 277, 37, 18 | 744.5, 277.75, 35, 16.75 | 18 | 0.000 |
| ui_19 / stat-2-value | 1.0 | 805, 279, 25, 16 | 805.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_19 / stat-3-name | 移速 | 902, 277, 38, 18 | 902.25, 277.5, 36, 17 | 18.375 | 0.000 |
| ui_19 / stat-3-value | 4.5 | 958, 279, 28, 15 | 958.5, 279.75, 26.25, 14.5 | 19.25 | 0.000 |
| ui_19 / stat-4-name | 视野 | 1058, 277, 37, 19 | 1058.25, 277.75, 36.5, 18 | 19.5 | -2.000 |
| ui_19 / stat-4-value | 9 | 1114, 279, 9, 15 | 1114, 279.75, 8.75, 14.5 | 19.25 | 0.000 |
| ui_19 / stat-5-name | 射程 | 1188, 277, 38, 19 | 1188.5, 277.5, 38.25, 18.25 | 19.5 | 0.000 |
| ui_19 / stat-5-value | 1.5 | 1246, 279, 24, 16 | 1246.25, 279.25, 23.5, 16 | 21.25 | -1.500 |
| ui_19 / row-1-priority | 优先级 1 | 456, 351, 88, 20 | 456.5, 351, 87, 20 | 21.25 | 2.250 |
| ui_19 / row-1-action | 沿我的信标 | 587, 352, 93, 17 | 587.5, 352, 91.5, 16.5 | 17.5 | 1.250 |
| ui_19 / row-1-delete | 删除 | 1172, 354, 35, 18 | 1172.5, 354.5, 33.25, 17 | 18.5 | -3.000 |
| ui_19 / row-1-condition-one | 条件一 | 582, 404, 54, 17 | 582.75, 403.75, 51.75, 16.75 | 17.75 | 0.000 |
| ui_19 / row-1-condition-two | 条件二 | 583, 460, 53, 18 | 582.75, 460.75, 52.5, 16.75 | 18 | 0.000 |
| ui_19 / row-2-priority | 优先级 2 | 456, 541, 91, 20 | 455.75, 540.75, 90.25, 20.25 | 21.5 | 2.500 |
| ui_19 / row-2-action | 等待 | 588, 543, 35, 18 | 588.75, 543.25, 33.25, 17.5 | 18.75 | -3.000 |
| ui_19 / row-2-delete | 删除 | 1172, 545, 35, 17 | 1172.25, 545.25, 34, 16.25 | 17.25 | 0.000 |
| ui_19 / row-2-condition-one | 条件一 | 584, 595, 52, 17 | 584.5, 595.5, 50, 15.75 | 17 | 0.000 |
| ui_19 / row-2-condition-two | 条件二 | 582, 653, 54, 18 | 581.75, 653.75, 52.5, 16.75 | 18 | 0.000 |
| ui_19 / row-2-duration-label | 持续时间 | 826, 543, 71, 16 | 826.25, 542.75, 69.75, 15.75 | 16.75 | 1.333 |
| ui_19 / row-2-duration-value | 2 | 929, 546, 9, 14 | 929, 546.5, 8.25, 13.5 | 18 | 0.000 |
| ui_19 / row-2-duration-unit | 秒 | 1051, 543, 15, 16 | 1050.75, 543.5, 15.25, 14.75 | 16 | 0.000 |
| ui_20 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_20 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_20 / timer-value | 18.4 | 816, 68, 41, 16 | 817.25, 67.75, 37.75, 15.75 | 20.5 | 0.000 |
| ui_20 / timer-phase | 战斗中 | 886, 71, 51, 11 | 894.5, 71, 33.75, 11 | 11.75 | 0.000 |
| ui_20 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_20 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_20 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_20 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_20 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_20 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_20 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_20 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_20 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_20 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_20 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_20 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_20 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_20 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_20 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_20 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_20 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_20 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_20 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_20 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_20 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_20 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_20 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_20 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_20 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_20 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_20 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_20 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
| ui_20 / detail-title | 骨喉 | 557, 142, 150, 35 | 596, 142.75, 71.25, 34.25 | 37.25 | 0.000 |
| ui_20 / detail-close | 关闭 | 1212, 152, 31, 17 | 1212.5, 152.75, 29.25, 15.75 | 16.75 | -3.000 |
| ui_20 / detail-description | 敌方特性与公开规则（只读） | 561, 204, 516, 20 | 561.75, 204.75, 251, 19 | 20.375 | 0.000 |
| ui_20 / detail-beacons | 敌方指令 · 只读 | 772, 811, 129, 17 | 777, 811, 118.5, 16.5 | 17.5 | 0.000 |
| ui_20 / stat-0-name | 生命 | 441, 277, 37, 19 | 441.5, 278, 37.25, 17.5 | 19 | 0.000 |
| ui_20 / stat-0-value | 60 | 499, 279, 21, 15 | 499, 279.75, 19.75, 14.5 | 19.25 | 0.000 |
| ui_20 / stat-1-name | 攻击 | 590, 277, 38, 18 | 590.5, 277.75, 37, 16.75 | 18 | 2.000 |
| ui_20 / stat-1-value | 0 | 662, 279, 9, 15 | 662.75, 279.75, 9.25, 14.5 | 19.25 | 0.000 |
| ui_20 / stat-2-name | 攻速 | 744, 277, 37, 18 | 744.5, 277.75, 35, 16.75 | 18 | 0.000 |
| ui_20 / stat-2-value | 0 | 805, 279, 25, 16 | 805, 279.25, 10, 16 | 21.25 | 0.000 |
| ui_20 / stat-3-name | 移速 | 902, 277, 38, 18 | 902.25, 277.5, 36, 17 | 18.375 | 0.000 |
| ui_20 / stat-3-value | 0 | 958, 279, 28, 15 | 958.75, 279.75, 9.25, 14.5 | 19.25 | 0.000 |
| ui_20 / stat-4-name | 视野 | 1058, 277, 37, 19 | 1058.25, 277.75, 36.5, 18 | 19.5 | -2.000 |
| ui_20 / stat-4-value | 12 | 1114, 279, 9, 15 | 1114.25, 279.75, 17.75, 14.25 | 19.25 | 0.000 |
| ui_20 / stat-5-name | 射程 | 1188, 277, 38, 19 | 1188.5, 277.5, 38.25, 18.25 | 19.5 | 0.000 |
| ui_20 / stat-5-value | 0 | 1246, 279, 24, 16 | 1246, 279.25, 10, 16 | 21.25 | 0.000 |
| ui_21 / quest-title | 第 3 关 · 墙缝 | 130, 66, 137, 21 | 129.75, 66, 136.5, 20.75 | 22.5 | 0.556 |
| ui_21 / quest-objective | 摧毁哭墙后方的回响骸柱 | 130, 96, 164, 13 | 130.25, 95.5, 162.5, 13.25 | 14 | 0.900 |
| ui_21 / timer-value | 00.0 | 816, 68, 41, 16 | 816.75, 68.5, 39.75, 15.75 | 20.75 | 0.000 |
| ui_21 / timer-phase | 部署阶段 | 886, 71, 51, 11 | 886.5, 71, 49.25, 11 | 11.75 | 1.000 |
| ui_21 / retry-label | 重试 | 1206, 75, 26, 14 | 1206.5, 75.75, 24.5, 13.25 | 14.625 | -4.000 |
| ui_21 / speed1-label | 1× | 1275, 75, 19, 13 | 1275, 75.75, 18.25, 12.25 | 16.5 | -2.000 |
| ui_21 / speed2-label | 2× | 1342, 75, 20, 13 | 1343, 75.75, 17.75, 12.25 | 16.5 | -4.000 |
| ui_21 / pause-label | 暂停 | 1408, 75, 27, 13 | 1408.25, 75.75, 26.5, 12.5 | 13.375 | 0.000 |
| ui_21 / settings-label | 设置 | 1483, 75, 27, 13 | 1483, 75.75, 26.5, 12.25 | 13.625 | 0.000 |
| ui_21 / exit-label | 退出 | 1559, 75, 28, 13 | 1560.25, 75.5, 25.75, 12.5 | 13.75 | 0.000 |
| ui_21 / task-label | 任务 | 1457, 137, 25, 12 | 1457.25, 137.75, 24, 11.25 | 12.25 | 0.000 |
| ui_21 / mechanics-label | 机制说明 | 1559, 137, 53, 12 | 1559.25, 137.5, 51.75, 11.5 | 12.375 | 1.000 |
| ui_21 / clear-label | 清空 | 1419, 770, 30, 15 | 1419.5, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_21 / hint-label | 提示 | 1557, 770, 31, 15 | 1558, 770.5, 28.5, 13.75 | 14.75 | 0.000 |
| ui_21 / budget-title | 预算 | 164, 833, 31, 15 | 165, 833.75, 28.5, 13.5 | 14.75 | 0.000 |
| ui_21 / budget-value | 6 / 8 | 148, 858, 58, 21 | 148, 857.5, 57, 21.25 | 22.25 | 3.750 |
| ui_21 / start-label | 开始 | 1467, 835, 74, 35 | 1467.75, 835.5, 71.5, 34.5 | 37.125 | 0.000 |
| ui_21 / card-swift-name | 快速形态 | 425, 851, 61, 15 | 426, 851.25, 59.25, 14 | 15 | 0.000 |
| ui_21 / card-swift-cost | COST | 438, 886, 33, 10 | 438, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_21 / card-swift-value | 3 | 489, 880, 15, 23 | 489.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_21 / card-striker-name | 基础攻击形态 | 601, 851, 92, 15 | 601.5, 851.25, 91.25, 14 | 15 | 0.400 |
| ui_21 / card-striker-cost | COST | 628, 886, 33, 10 | 628, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_21 / card-striker-value | 3 | 679, 880, 15, 23 | 679.75, 880.5, 13.75, 23 | 30.25 | 0.000 |
| ui_21 / card-bulwark-name | 承伤形态 | 806, 851, 61, 15 | 806.25, 851.5, 60.5, 13.75 | 14.75 | 0.667 |
| ui_21 / card-bulwark-cost | COST | 819, 886, 32, 10 | 819.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_21 / card-bulwark-value | 4 | 870, 880, 16, 23 | 870.25, 880.5, 14.75, 22 | 29 | 0.000 |
| ui_21 / card-spitter-name | 远射形态 | 996, 852, 62, 14 | 996.25, 851.75, 61.5, 13.5 | 14.5 | 1.333 |
| ui_21 / card-spitter-cost | COST | 1008, 886, 33, 10 | 1008, 886.5, 32.75, 9.75 | 12.5 | 0.000 |
| ui_21 / card-spitter-value | 4 | 1059, 879, 17, 24 | 1059.5, 879.75, 15.25, 23 | 30.25 | 0.000 |
| ui_21 / card-locked-name | 未解锁 | 1194, 852, 43, 13 | 1194.75, 852, 41.5, 13.25 | 14 | 0.000 |
| ui_21 / card-locked-cost | COST | 1198, 886, 32, 10 | 1198.5, 886.5, 30.75, 9.75 | 12.5 | -0.667 |
| ui_21 / card-locked-value | — | 1247, 891, 18, 2 | 1246, 891.5, 19, 1.25 | 23.5 | 0.000 |
