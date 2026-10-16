# 第三阶段资源报告（R1/P5已通过 / R2–R5整图待用户统一审阅）

日期：2026-10-05。没有新建或切换分支。未打包客户端或exe。只修改资源、指定工具及资源规范；现有程序工作区改动保持原样。

## 1. 当前制作顺序与状态

按用户本轮追加指示：先清点控件 → 资源方重新布局 → 完整设计图交用户 → 用户确认后才拆分控件/导出素材和manifest → 程序方P5实机拼接diff → R1通过后扩展R2–R5。

| 阶段 | 交付 / 状态 |
|---|---|
| R0 | `../docs/UI_INVENTORY.md`（相对godot为`../docs`）：全部界面/控件/状态/建议尺寸、风格、公共件计划、manifest契约与审批顺序；cutout原生透明支持、总手册§2/§3、art_manifest措辞同步完成 |
| R1 | `assets/ui/main_menu/design.png`、`assets/ui/settings_overlay/design.png`：两张1920×1080已批准整图；错误态design_error.png一并保留。切片、四态、公共件、manifest、文字绑定和索引已完成，详见§11 |
| R2 | 20张HUD/侧栏整图已生成，未拆分；待批量审阅 |
| R3 | 5张章节界面状态整图及完整宽图已生成，未拆分 |
| R4 | 8关候选full/base、9张障碍切片与8份obstacles.json已生成至`assets/backdrops/review_r4/`；待用户审阅，运行关卡数据保持原样 |
| R5 | 综合反馈整图已生成，未拆分 |

用户已确认P5实机验收无误；apply_ui_manifest.py、ui_diff.py与三份实机报告已存在。R1已完成接入和验收，后续整图批次详见§12。后续若P5提出格式问题，更新UI_INVENTORY后重交。

## 2. 首版R1设计（历史记录，最终规格见§11）

主界面：左侧艺术字游戏名、Cinzel英文副标题、金色细分隔线、纵向开始/设置/退出；右侧人偶背影、腐土与哭墙/骨花温室远景。按钮用干净骨白角线，焦点用炼金金，低饱和紫黑底。没有独立Logo或水印。

设置浮窗：居中面板与暗遮罩，声音/显示/调试三段，主音量/音乐/音效、全屏、目标连线、字体大小、模拟日志和日志路径、关闭。数值100%/80%/85%与开关状态是设计样例，不写入玩家配置。

常规文字全部由现有`NotoSerifSC-Regular.otf`、`NotoSerifSC-Bold.otf`与`Cinzel-Regular.ttf`真实字体文件排版，内容读取现有strings（关闭文字例外为浮窗设计文案），不使用模型仿造字形。游戏名“人工神灵”使用原创艺术字，按独立素材登记；其原生透明源图仅保存在`tools/_raw/p3/title_art_native.png`作为整图源，不是正式切片。用户确认后它须有自己的file/id/rect。若后续采用融合Logo的标题，仍作为艺术字素材处理。

审阅稿实际布局（设计坐标，审批后再冻结）：

| 元素 | rect / 说明 |
|---|---|
| 游戏名艺术字 | [148,238,580,196]（实际等比高度按原图裁边，约196） |
| Cinzel副标题 | [164,452,600,44]，22px |
| 分隔线 | x164–564，y520 |
| 开始/设置/退出 | [164,576,400,88] / [164,696,400,88] / [164,816,400,88]；30px |
| 错误红条 | [0,1016,1920,64]；24px文字；开始禁用 |
| 设置面板 | [460,104,1000,872]；内容左x516/532 |
| 设置标题/关闭 | [516,140,640,68] 40px / [1280,144,120,56] 24px |
| 三段标题 | y242/474/708，26px |
| 音量行 | y296/350/404；轨x886宽382，标签26px；百分比Cinzel24px |
| 显示行 | y522/578/634；开关80×36；字体下拉230×52 |
| 调试行/提示 | y756 / y820，26px / 20px |

面板、控件本轮只画入整图布局层，未生产独立控件文件。后续切片应以用户确认整图为基准，不能改成另一套样式。程序字体反走样差异与动态值另行比对，不以整块屏蔽遮蔽布局错误。

## 3. 首版生成次数、来源与prompt（后续累计见§11）

全部使用内置image_gen（imagegen技能），外部绘图API调用0次。共3次原生生成：背景1次（采用）、带模型文字主界面草稿1次（未采用，后续用户明确指定实际字形）、艺术字1次（采用）。无调用失败，无重试。生成图经view_image目视检查；最终3张整图亦逐张目视检查。

选用原始背景保留`tools/_raw/p3/main_menu_background_native.png`，原始艺术字保留`tools/_raw/p3/title_art_native.png`。它们是生产源文件，非测试/临时文件。

最终采用prompt要点：

1. 背景：original dark fantasy main menu background only；16:9；painterly oil texture；right-third back-view porcelain doll with short ash-white bob, dark crimson tattered robe and articulated joints；rotten plain, distant wailing ruin and bone greenhouse；left45% dark quiet negative space；palette #120A10/#2A1430/#4A3350/#7A1E2B/#E8DCC4, faint #C9A24A horizon；no text/UI/logo/watermark/signature/existing game references。
2. 未采用主界面：以背景作输入，左侧“人工神灵”和ARTIFICIAL DIVINITY、开始/设置/退出控件；因模型字形无法保证游戏字体，未采用该整图，常规文字改用实际字体文件。
3. 艺术字：genuinely transparent background/native alpha；exact four Chinese characters “人工神灵”, one horizontal line；correct radicals, readable；carved bone-white strokes, fine porcelain cracks, restrained dried crimson seams and tiny antique gold accents；no extra emblem/symbol substitutions/subtitle/Latin/watermark/signature；transparent output保留alpha，不走色键。

控件遵循原有程序化UI资源制作方式，直接在布局图层绘制边框与控件、字体排版，最后与原生美术合成；未修改既有美术背景内容。

## 4. R0管线变更

`cutout.py`新增`--native-alpha`，units/props/illustrations原生路径跳过chroma_key与rembg，保留RGBA，只裁边/等比缩放/居中/底部留白；units/props底部24px，illustrations沿原规格脚底贴底。缺少alpha、完全不透明或空图给出错误。UI透明prompt含transparent时原生裁边，不透明UI仍cover到1920×1080。旧路径保留以兼容旧源。

`art_manifest.json`的units、props、illustrations三个style_suffix由“isolated on a flat solid pure magenta background (#FF00FF)”改为“isolated on a genuinely transparent background, native alpha channel”。items的id/kind、output目录/尺寸不变，全文件已无magenta。总资源手册§0.1同步修复状态，§2/§3改为内置生成+原生alpha处理；旧API批量命令明确标为工具索引而非当前工作流。

## 5. 逐项验证结果与结论

| # | 测试用例 | 结果 |
|---|---|---|
| 1 | 原生半透明品红前景：保持RGBA、绕过色键/rembg、居中与24px留白 | 通过 |
| 2 | 低占比原生透明图不被旧占比检查误拒 | 通过 |
| 3 | 缺失alpha的RGB输入报错 | 通过 |
| 4 | 完全不透明RGBA输入报错 | 通过 |
| 5 | 全透明空图报错 | 通过 |
| 6 | 立绘768×1152、脚底贴底、半透明颜色保留 | 通过 |
| 7 | 不透明UI大图缩放裁切1920×1080 | 通过 |
| 8 | art_manifest无magenta且id/kind/输出目录不变 | 通过 |
| 9 | cutout命令行--native-alpha参数可用 | 通过 |
| 10 | assets\ui\main_menu\design.png：尺寸1920×1080、有效PNG | 通过 |
| 11 | assets\ui\main_menu\design_error.png：尺寸1920×1080、有效PNG | 通过 |
| 12 | assets\ui\settings_overlay\design.png：尺寸1920×1080、有效PNG | 通过 |
| 13 | 全部非艺术字调用游戏内NotoSerifSC/Cinzel真实字体文件 | 通过 |
| 14 | 游戏名艺术字原图具有真实原生alpha，按独立素材登记 | 通过 |
| 15 | 审批前未创建manifest或控件切片 | 通过 |
| 16 | 主界面整图目视：艺术字四字可读、按钮齐全、人物未遮挡 | 通过 |
| 17 | 设置整图目视：三段标题、全部设置项、关闭、文字无溢出 | 通过 |
| 18 | 错误状态整图目视：红色错误条与开始禁用状态可辨 | 通过 |

立绘测试首次用RGB完全相等断言失败：Pillow对RGBA的Lanczos缩放有预乘量化，中心像素(201,162,74,192)成为(200,162,74,192)。按缩放允许RGB≤1字节误差、alpha仍须完全一致调整测试后通过；不是色键污染。不透明/缺alpha/空图的“通过”指按预期拒绝输入。

没有运行Godot游戏测试或P5实机像素diff：本轮为用户审阅整图，不改运行代码；接入验收仍待拆分后程序方执行。本轮不能代替用户艺术审阅。

首版文件SHA256（当前版见下方V2修订）：

| 文件 | SHA256 |
|---|---|
| `assets/ui/main_menu/design.png` | `4561ceb04c5de4c2b7119d777eb0d529de459a38bb3d08fce235af21a4879713` |
| `assets/ui/main_menu/design_error.png` | `cb51c0161d49c7bc2d463a3306c36331dcad1a8bd05a24d96722601c84ab18ed` |
| `assets/ui/settings_overlay/design.png` | `506687628f51a6a8c83d7083c45c5ce58b54a34b9f9e722b7dfb474792738272` |

## 6. 首版交付时的下一步（历史记录）

先由用户审阅主界面、设置浮窗和错误状态整图，提出布局/风格修改或确认。确认后拆分艺术字和控件，导出公共件、四态、九宫格与manifest，再交程序方P5。R1通过前保持R2–R5未开始。

本轮临时生产脚本、测试脚本和测试结果JSON在交付时删除；仅保留设计图、选用的生产原图、规范和本报告。


## 7. V2游戏名艺术字修订（2026-10-05）

用户反馈首版骨头感过重，要求突出炼金与圣器，血腥骨质只留在下半部甚至底部四分之一。本次采用更严格的底部20–25%限制：上部以银金金属、象牙色珐琅、炼金几何刻纹和圣器工艺为主，减少尖锐骨刺；底端少量暗红氧化与裂纹。仍是独立艺术字素材提案，不将常规文字改成艺术字。

原生image_gen编辑1次，累计4次生成/编辑，外部API仍0次。参考为首版title_art_native.png；新源保留title_art_native_v2.png（真实原生alpha）。prompt要点：exact 人工神灵；top75–80% pristine silver-gold metal, ivory vitreous enamel, alchemical circles/geometric filigree, sacred reliquary craftsmanship；no upper bone/blood/corpse cracks；bottom20–25% faint crimson oxidation and tiny bone-like cracks；no drips/gore/extra words/logo/watermark；native transparent。

仅重新合成主界面和错误态的标题区域、设置浮窗面板左侧可见标题区域。其余像素保持完全一致，因此常规字体和布局均保持不变。仍等待用户审阅整图，未拆分。

| 验证用例 | 结果 |
|---|---|
| design.png：艺术字区域外像素完全一致 | 通过 |
| design_error.png：艺术字区域外像素完全一致 | 通过 |
| 设置浮窗：仅标题可见部分更新，面板与其他像素完全一致 | 通过 |
| 新艺术字源图：原生alpha存在且内容非空 | 通过 |
| 三张整图保持1920×1080且有效PNG | 通过 |
| 审批前仍无manifest或控件slices | 通过 |

V2文件SHA256（当前版见下方V3修订）：

| 文件 | SHA256 |
|---|---|
| `assets/ui/main_menu/design.png` | `7ce34fb0985a5e417d4c4665a8480be268b6515251023f5ee00915bde1351eeb` |
| `assets/ui/main_menu/design_error.png` | `6325f16103ab9df20aa036f69843d7ec5a8ebe4fac4332599ab28c3bef4e1f8f` |
| `assets/ui/settings_overlay/design.png` | `aba9b6082825d8cbe6fcbbee764d12413ebd8aaad5531fa50fda55de019f7e21` |

本轮临时合成与验证脚本删除。选用美术源为生产原图，保留以便确认后导出艺术字素材。


## 8. V3游戏名艺术字精修（2026-10-05）

V2仍有上部裂纹和暗红细节，因此追加一次原生编辑精修：上部80%改为光洁珐琅和贵金属，保留炼金环纹与圣器镶嵌；底端15–20%仅少量暗红氧化和细裂纹。仍是独立艺术字素材提案，不将常规文字改成艺术字。

本轮艺术字共编辑2次，全部累计5次生成/编辑，外部API仍0次。V3参考为V2，源保留title_art_native_v3.png（真实原生alpha）。prompt要点：exact 人工神灵；top80% pristine SMOOTH white vitreous enamel, polished precious metal, pearls, alchemical circles；remove all cracks/brown flecks/bone weathering/red inlay including inside left leg of 人；bottom15–20% tiny crimson tarnish/fine fractures；no words/background/glow/watermark；native transparent。

仅重新合成主界面和错误态的标题区域、设置浮窗面板左侧可见标题区域。其余像素保持完全一致，因此常规字体和布局均保持不变。仍等待用户审阅整图，未拆分。

| 验证用例 | 结果 |
|---|---|
| design.png：艺术字区域外像素完全一致 | 通过 |
| design_error.png：艺术字区域外像素完全一致 | 通过 |
| 设置浮窗：仅标题可见部分更新，面板与其他像素完全一致 | 通过 |
| 新艺术字源图：原生alpha存在且内容非空 | 通过 |
| 三张整图保持1920×1080且有效PNG | 通过 |
| 审批前仍无manifest或控件slices | 通过 |

V3文件SHA256（当前版见下方V4）：

| 文件 | SHA256 |
|---|---|
| `assets/ui/main_menu/design.png` | `fbed7eee05ff9cdd20db853ce062348e76c138bc0935968a9d7f165aebf55480` |
| `assets/ui/main_menu/design_error.png` | `808fb381736885d9d97868f8fcce7e664ea8dd94e7ffdab00fbd71d5ce0bceaa` |
| `assets/ui/settings_overlay/design.png` | `6ef77ea87811dc4bf0f0c214c8f58744dc760e243a5fef07228c015b953bc24a` |

本轮临时合成与验证脚本删除。选用美术源为生产原图，保留以便确认后导出艺术字素材。


## 9. V4：简化标题、强化按钮（2026-10-05）

按用户要求去掉标题金属包边、宝珠与繁复饰纹，以清晰艺术字形和少量矢量感几何为主；按钮增加炼金圆纹、连续弧线、暗紫珐琅和层叠饰板。删除主菜单原有分隔线、短竖线焦点、直角角标。不使用ASCII字符画装饰。仍是整图审阅稿，未拆分。

内置image_gen生成2次，累计7次生成/编辑，外部API0次。新艺术字与无文字按钮饰板分别保存为tools/_raw/p3/title_art_native_v4.png、menu_button_concept_v4.png，只作为完整设计图的生产源。艺术字与按钮虽有矢量风格，当前原生生成输出仍为PNG，并非SVG矢量文件。

标题prompt：exact 人工神灵；minimalist flat vector graphic typography；clean ivory glyph silhouettes, customized calligraphic terminals, strong stroke contrast；sacred alchemical restrained geometry, small muted-gold negative-space detail；no border/outline/frame/metal wrapping/bevel/gems/pearls/filigree/rings/spikes/ASCII corners；muted crimson仅字脚15%；native transparent/no extra text。

按钮prompt：one single wide alchemical holy reliquary menu plate，无文字；约4.4:1；deep violet enamel ribbon, curved tapered ends, antique brass contour, circular instrument engravings at ends, flowing leaf-like arcs, subtle crimson lacquer；中央65%暗色留白供实际字体排版；no bones/gore/gems/ASCII brackets/dashes/terminal style；native transparent。

按钮文字仍用NotoSerifSC：开始Bold，设置/退出Regular，30px；副标题Cinzel22px。按钮容器[148,560,500,116]、[148,702,500,116]、[148,844,500,116]，具体透明饰板在容器居中等比绘制。标题在[148,238,580,196]容器中等比居中。设置浮窗仅更新背后的主菜单，面板及其常规字体保持像素一致。

| 验证用例 | 结果 |
|---|---|
| title_art_native_v4.png原生alpha、非空与等比规格化 | 通过 |
| menu_button_concept_v4.png原生alpha、非空与等比规格化 | 通过 |
| design.png：菜单范围外背景像素完全一致 | 通过 |
| design_error.png：菜单范围外背景像素完全一致 | 通过 |
| 设置浮窗面板及全部设置文字像素完全一致 | 通过 |
| 三张整图1920×1080有效PNG | 通过 |
| 全部常规文字由游戏字体文件渲染 | 通过 |
| 用户确认前未生成控件切片或manifest | 通过 |

V4文件SHA256（当前版见下方V5）：

| 文件 | SHA256 |
|---|---|
| `assets/ui/main_menu/design.png` | `77a162f38028d699e24f774c49c4de8ed06a4355b86738005e23dabed0f73642` |
| `assets/ui/main_menu/design_error.png` | `2b21e3dc8639805accebdfd7a5d4deae8a0cd0423e80c7316c18782ca4942768` |
| `assets/ui/settings_overlay/design.png` | `4ac8f6a6e8c2c4a69e8801de93c10bcc67fd65807997dbce6fd2d768bf753908` |

临时制作/验证脚本于本轮结束删除，生产源保留。整图仍须用户审阅后才进行素材拆分。


## 10. V5：按钮改为轻量矢量（2026-10-05）

用户要求下方边框也模仿标题，不要太重，以矢量和少量艺术化描边为主。本次直接制作真实SVG矢量源：一层半透明紫黑底，薄骨白/炼金金曲线轮廓，小月牙及两端少量艺术描边，底端一小段暗红点缀。移除V4厚金属饰板、复杂炼金仪表、纹理、立体包边。仍保持当前标题与常规游戏字形。

生产源：tools/_raw/p3/menu_button_vector_v5.svg，viewBox=0 0 500 116，五条路径，没有嵌入图片，也没有烘焙文字。整图预览用同一矢量几何6倍采样后Lanczos降采样合成。没有额外AI图生成或API调用，累计仍为7次内置生成/编辑、外部API0次。按用户指定矢量方向采用代码生成新矢量构形，没有处理或抠改旧PNG源。原SVG是整图设计生产源，不是正式控件切片。

按钮仍位于[148,560,500,116]、[148,702,500,116]、[148,844,500,116]，30px NotoSerifSC（开始Bold、其余Regular）。首项焦点为稍亮金边，错误态首项压暗。设置浮窗自身保持不变，仅更新它后面露出的菜单按钮。用户确认前不导出slices/manifest。

| 验证用例 | 结果 |
|---|---|
| SVG为500×116、五条真实矢量路径、不含嵌入栅格或文字 | 通过 |
| 矢量预览透明外沿、主体非空、中心具有深色底 | 通过 |
| design.png：仅三处按钮区域更新，标题/背景/副标题保持像素一致 | 通过 |
| design_error.png：仅三处按钮区域更新，标题/背景/副标题保持像素一致 | 通过 |
| 设置面板与全部设置项文字像素不变，仅更新背景按钮露出部分 | 通过 |
| 三张整图1920×1080有效PNG | 通过 |
| 按钮标签使用现有NotoSerifSC Regular/Bold真实字形 | 通过 |
| 尚未输出正式控件切片或manifest | 通过 |

当前V5文件SHA256：

| 文件 | SHA256 |
|---|---|
| `assets/ui/main_menu/design.png` | `48baa3018ba1e0225b27e105d0996dde0cbbacf81de9f6e38a425089aaba2c9d` |
| `assets/ui/main_menu/design_error.png` | `919a99293d21f4bcbe9e47f80dc6cf59f0103c6b3bfc25f11ee7ec9ea706bf35` |
| `assets/ui/settings_overlay/design.png` | `8b7e2eca43939cfd8dc8734301790d555c49a66a45ea92f902f095b702753df1` |
| `tools/_raw/p3/menu_button_vector_v5.svg` | `0c5a8a879980260731d28c5772c8e5bb73e1222cf22dcdd86ac0066103017ea6` |

临时制作与测试脚本本轮结束删除。矢量设计生产源保留，以便整图确认后导出素材。


## 11. 已批准V5素材拆分交付（2026-10-05）

用户明确回复“可以的，这样就没问题了，开始拆分素材吧”，据此拆分。批准的三张design SHA256保持§10数值，未修改画面。最终标题切片580×149，rect=[148,261,580,149]；菜单三按钮500×116，x148、y560/702/844，四态完整；其余精确坐标、状态、九宫格和字体以manifest及UI_INVENTORY 1.1为准。

| 交付目录 | 内容 |
|---|---|
| assets/ui/main_menu | 背景、独立艺术字、三个按钮各四态、错误条；manifest/error_manifest、preview、TEXT_BINDINGS |
| assets/ui/settings_overlay | 遮罩、面板、关闭四态、两条分隔线；manifest、preview、TEXT_BINDINGS |
| assets/ui/common | 面板、菜单PNG/SVG四态、紧凑按钮四态、下拉四态、轨/填充/把手四态、开关、箭头；asset_index、states_preview |

asset_index登记51个图像/矢量资产：46个RGBA运行PNG、1个RGB四态预览PNG、4个真实SVG。普通文字没有烧进运行切片，字体绑定使用项目NotoSerifSC Regular/Bold与Cinzel；艺术字是单独图像资产。preview.json仅是比对/交接元数据，不是臆造的运行API。原生生成累计7次，外部API0次，本次拆分新增生成0次。原美术和矢量生产源继续保留tools/_raw/p3。

回拼从已交付manifest和切片读取，采用标准alpha-over和九宫格，不改变整图，也不屏蔽面板或控件。字形AA豁免仅覆盖实际alpha为1–254的字形像素。

| 画面 | 严格任意通道不等 | 排除字形AA | 排除AA并允许通道1/255取整 | 最大非AA通道差 |
|---|---:|---:|---:|---:|
| 主界面正常 | 0.0717% | 0% | 0% | 0 |
| 主界面错误 | 0.1973% | 0% | 0% | 0 |
| 设置浮窗 | 2.6414% | 2.2206% | 0.2817% | 5/255 |

设置浮窗严格2%目标尚未达到；明确采用资源侧1/255容差后低于2%，不能当作P5通过。差异来自批准整图的旧底层半透明合成与文字直接绘制方式，切片独立alpha-over有量化差异；最大全图通道差8/255。程序侧仍须确认合成和实机diff。本次没有重画批准整图来掩盖差异。

第一次设置回拼发现关闭/下拉描边超出名义rect 1px，九宫格角端点被截或拉伸。已给切片加1px透明留白并改视觉rect，增加下拉保护边距，最终非AA最大差从154/192降至5；面板保留原整图裁边。该修复没有改变批准设计。

逐项验证：

| # | 测试用例 | 结果 |
|---|---|---|
| 1 | 主界面正常从manifest回拼：除字形抗锯齿像素外完全一致 | 通过 |
| 2 | 主界面错误从manifest回拼：除字形抗锯齿像素外完全一致 | 通过 |
| 3 | 设置浮窗从manifest回拼差异<2%（字形AA像素除外，alpha取整容差1/255） | 通过 |
| 4 | main_menu manifest合法、唯一id与1920设计坐标 | 通过 |
| 5 | main_menu 素材引用存在且限制在assets/ui内、按钮四态、九宫边距有效 | 通过 |
| 6 | main_menu_error manifest合法、唯一id与1920设计坐标 | 通过 |
| 7 | main_menu_error 素材引用存在且限制在assets/ui内、按钮四态、九宫边距有效 | 通过 |
| 8 | settings_overlay manifest合法、唯一id与1920设计坐标 | 通过 |
| 9 | settings_overlay 素材引用存在且限制在assets/ui内、按钮四态、九宫边距有效 | 通过 |
| 10 | 所有新切片为有效RGBA PNG，普通文字仅在字体绑定中 | 通过 |
| 11 | button_menu 四态图像互不相同 | 通过 |
| 12 | button_compact 四态图像互不相同 | 通过 |
| 13 | dropdown 四态图像互不相同 | 通过 |
| 14 | slider_grabber 四态图像互不相同 | 通过 |
| 15 | 用户批准的三张design文件SHA256未改变 | 通过 |
| 16 | 菜单按钮九宫格拉宽后两端艺术描边与月牙像素不变 | 通过 |
| 17 | 面板/下拉/关闭按钮九宫格保留四角，无描边截断 | 通过 |
| 18 | 全部文字绑定复用现有strings key与游戏字体文件 | 通过 |
| 19 | 四态/开关交付预览图1920×1080且使用实际游戏字体 | 通过 |
| 20 | 三张manifest回拼图逐张目视：布局、边框、艺术字、控件和文字无溢出 | 通过 |
| 21 | 四态预览目视：normal/hover/pressed/disabled与开关可辨 | 通过 |
| 22 | 临时制作/测试脚本、结果JSON、回拼测试图片删除；生产源保留 | 通过 |

结论：R1资源包完成，主界面非字形AA像素回拼一致；设置严格指标未过2%，1/255容差指标通过。未运行Godot实机/P5测试，未完成运行素材接入。按原资源任务包，P5验收前R2–R5不开始。前面§2–§10的“未拆分/待批准”均为相应历史版本记录。


## 12. P5验收与R2–R5统一整图批次（2026-10-05）

用户确认“P5实机验收无误”，解除R1门槛；新的明确顺序是先统一完成所有界面整图，待用户判断无误后实际拆分；制作时复用优先。本节是当前状态，前面的待P5描述是历史记录。

流程总结已保存docs/P3_ASSET_WORKFLOW.md，全部整图与画廊索引在docs/P3_REVIEW_BATCH.md。

| 阶段 | 当前交付 |
|---|---|
| R2 HUD | 11张整图：部署、运行、暂停、固定出场、超预算/校验、任务、机制、提示、推荐阵型、胜利、失败 |
| R2侧栏 | 9张整图：己方编辑、运行、敌方只读、添加行为、信标、双条件与或、等待参数、沿信标参数、敌方特性 |
| R3 | 5张整图：可挑战、锁定、已完成/回放、横移末端、Boss；3840×1080章节完整宽图 |
| R4 | 8张1920×1080完整场景提案，位于assets/backdrops/review_p3/；没有覆盖原运行背景 |
| R5 | 1张数字牌/三类血条/地格/提示整图，样例也放进HUD |

合计26张界面整图、8张场景整图、1张完整章节宽图；5张界面总览、2张场景总览和HTML审阅画廊。没有新R2/R3/R5运行manifest或切片、R4 base/障碍/obstacles.json；等待用户统一判断后再拆分。

复用43个现有素材来源，逐项清单见review_plan.json：R1公共框/按钮/下拉/遮罩，既有操作和六属性SVG、拖拽柄、指令行三态、头像/圆mask、角色精灵、三种血条轮廓。新结构只画入整图：节点矢量、角色卡/列表、数字牌和少量滚动/提示结构。普通文字全部来自游戏字体，示例文字取现有strings、关卡、单位和特性数据。等待/沿信标参数画面仅用于控件能力审阅，不声明这些示例已在该关解锁或可用，不写玩家配置。

本批内置image_gen新增9次（章节图1次、八场景各1次），累计16次；外部API0次，无生成失败。完整prompt与原生路径保留native_generation_log.json。原生场景/地图没有模型文字。源小于设计分辨率时采用等比cover放大，保留native原图，不声称细节为原生目标分辨率。界面用现有矢量/控件与真实字体合成，HUD按线性光、章节按sRGB；P6仍需实机确认HDR匹配。

问题与修复：九宫格目标尺寸等于边距总和时跳过零宽/高中心片；固定出场复用数据实际字段unit而非form；敌方长选敌文字加宽；双条件整句与敌方目标文案按控件同步并预留换行；移除结算设计中现有功能没有提供的关闭入口。最终文字测量无溢出。

首次“整个游戏脚本目录无Git差异”检查失败：共享工作区在本轮期间出现main_menu/ui_kit及菜单动效相关程序改动，它们不属于本轮资源操作。本轮未修改、覆盖或撤回这些文件；验收项改为核对本任务的既有玩法数据，并明确不把整个工作区无脚本差异当成测试结论。

场景目视已检查主题、开阔地面、低矮障碍和无UI文字。尚未验证精确障碍footprint/blocked落点或base回贴：原生绘图落点是提案，不能因prompt指定坐标就声称像素对齐通过。用户确认后逐块核对，再验证回贴<1%；章节地理美术与现有临时节点位置也在本次审阅范围内，数据未改。实机diff与模拟回归留给正式拆分和程序P6/P7阶段。

### 测试结论（每项用例与结果）

| # | 测试用例 | 结果 | 说明 |
|---|---|---|---|
| 1 | 整图01：局内HUD · 部署，有效1920×1080 PNG | 通过 |  |
| 2 | 整图02：局内HUD · 战斗，有效1920×1080 PNG | 通过 |  |
| 3 | 整图03：局内HUD · 暂停，有效1920×1080 PNG | 通过 |  |
| 4 | 整图04：局内HUD · 固定出场，有效1920×1080 PNG | 通过 |  |
| 5 | 整图05：预算超出与开始校验，有效1920×1080 PNG | 通过 |  |
| 6 | 整图06：任务弹窗，有效1920×1080 PNG | 通过 |  |
| 7 | 整图07：机制说明 · 可滚动正文，有效1920×1080 PNG | 通过 |  |
| 8 | 整图08：分层提示，有效1920×1080 PNG | 通过 |  |
| 9 | 整图09：推荐阵型确认，有效1920×1080 PNG | 通过 |  |
| 10 | 整图10：结算 · 胜利，有效1920×1080 PNG | 通过 |  |
| 11 | 整图11：结算 · 失败，有效1920×1080 PNG | 通过 |  |
| 12 | 整图12：角色详情与指令编辑，有效1920×1080 PNG | 通过 |  |
| 13 | 整图13：指令运行 · 生效与原因，有效1920×1080 PNG | 通过 |  |
| 14 | 整图14：敌方只读详情，有效1920×1080 PNG | 通过 |  |
| 15 | 整图15：添加行为列表，有效1920×1080 PNG | 通过 |  |
| 16 | 整图16：信标列表与操作，有效1920×1080 PNG | 通过 |  |
| 17 | 整图17：指令编辑 · 双条件与或，有效1920×1080 PNG | 通过 |  |
| 18 | 整图18：指令编辑 · 等待参数，有效1920×1080 PNG | 通过 |  |
| 19 | 整图19：指令编辑 · 信标模式与起点，有效1920×1080 PNG | 通过 |  |
| 20 | 整图20：敌方特性与公开规则，有效1920×1080 PNG | 通过 |  |
| 21 | 整图21：部署反馈 · 数字牌、三类血条、地格、提示，有效1920×1080 PNG | 通过 |  |
| 22 | 整图22：章节地图 · 可挑战，有效1920×1080 PNG | 通过 |  |
| 23 | 整图23：章节地图 · 锁定，有效1920×1080 PNG | 通过 |  |
| 24 | 整图24：章节地图 · 已完成与回放，有效1920×1080 PNG | 通过 |  |
| 25 | 整图25：章节地图 · 横移末端占位，有效1920×1080 PNG | 通过 |  |
| 26 | 整图26：章节地图 · 首领与后半区域，有效1920×1080 PNG | 通过 |  |
| 27 | 关卡01场景完整提案：有效1920×1080 PNG | 通过 |  |
| 28 | 关卡02场景完整提案：有效1920×1080 PNG | 通过 |  |
| 29 | 关卡03场景完整提案：有效1920×1080 PNG | 通过 |  |
| 30 | 关卡04场景完整提案：有效1920×1080 PNG | 通过 |  |
| 31 | 关卡05场景完整提案：有效1920×1080 PNG | 通过 |  |
| 32 | 关卡06场景完整提案：有效1920×1080 PNG | 通过 |  |
| 33 | 关卡07场景完整提案：有效1920×1080 PNG | 通过 |  |
| 34 | 关卡08场景完整提案：有效1920×1080 PNG | 通过 |  |
| 35 | 章节完整宽图3840×1080 | 通过 |  |
| 36 | 八关场景非重复文件 | 通过 |  |
| 37 | 全部复用素材引用存在 | 通过 | 43个来源 |
| 38 | 全部普通文字使用指定游戏字体 | 通过 | 887处文字 |
| 39 | 文字框测量无溢出 | 通过 | 整图生成脚本对每行宽度和换行高度断言通过 |
| 40 | R1全部51个交付资产SHA256保持一致 | 通过 |  |
| 41 | 三张已批准R1整图SHA256保持一致 | 通过 |  |
| 42 | 未提前创建R2/R3/R5新切片或运行manifest | 通过 |  |
| 43 | 未提前分离R4 base/障碍切片 | 通过 |  |
| 44 | 既有关卡/单位/章节/剧情/指令数据无差异 | 通过 | 共享工作区的其他程序改动保持原样；本轮没有写游戏脚本 |
| 45 | 原生生成记录齐全且外部API为0 | 通过 |  |
| 46 | P5三份已有报告通过 | 通过 |  |
| 47 | 设计矩形维持现有顶栏64/底栏120和侧栏520 | 通过 |  |
| 48 | 审阅画廊全部35张图片链接存在 | 通过 |  |
| 49 | 七张总览图均为有效PNG | 通过 |  |
| 50 | 全部临时脚本、SVG预览缓存与测试文件已删除 | 通过 |  |

目视检查记录：26张界面整图通过总览及主要复杂页面检查（文字/控件/边框无溢出）；八场景完整提案逐张通过主题与中心可读性审阅；全部五区域宽图通过连续性检查。目视检查不替代用户艺术判断，未将R2–R5标为最终完成。

## 统一窄边框、低噪音整图重绘（当前审阅批）

完成29个UI状态、10张背景及1张未切公共结构参考板，复用已有43个来源的内容与风格。全部由原生绘图工具生成，复制原生文件，无后期叠字或代码拼版。章节和主菜单二次简化环境碎纹，发现的按钮状态、最近字形和锁标记已交工具修正。

[整图图库](_raw/p3/low_noise_review/review_gallery.html) · [素材汇总与流程](../../docs/P3_LOW_NOISE_REVIEW.md) · [每个测试用例与结果](../../docs/P3_LOW_NOISE_VALIDATION.md)。状态：整批待用户判断，尚未拆分、实机接入或打包。


## 2026-10-05 详情弹窗与公共 HUD 统一

本次交付30张无字透明切片、21个局内状态1920×1080回拼。唯一坐标基准 ui_01；详情为覆盖全部HUD的可滚动弹窗，条件间采用∧/∨。清单 `assets/ui/unified_low_noise/layout.json`，画廊 `assets/ui/unified_low_noise/index.html`，报告 `docs/P3_UNIFIED_UI_DELIVERY.md`。运行场景尚未接入。


## 剩余资源生成审阅（2026-10-05）

原生生成 6 次：主标题金光动效最亮帧整图 1 张；关卡 03/04/05/06/08 去障碍底图 5 张。第 01/02/07 关无 blocked，复用已有整图。Prompt 保持原场景构图与外围内容，移除指定内场障碍、补齐平坦地面，避免高频噪声；标题保持已有人工神灵字形，仅增加克制金光。交付 `tools/_raw/p3/remaining_review/index.html`、标题循环预览及逐项检查记录。

自动检查 20/20、目视检查 5/5 通过，完整用例见 `docs/P3_REMAINING_RESOURCE_REVIEW.md`。静止预览与已确认主菜单逐像素一致，峰值标题作用区域外 0 差异；10 个已确认源文件 SHA-256 未变。原生生成整图只作视觉提案，准确字形循环复用已有资产。

未完成项：R6a 最终动效分层待目视判断，R6b 依赖主标题通过；R4 最终尺寸、透明障碍切片与回贴验收尚未交付。无运行时替换、无新 UI 切图，不将本轮提案标记为整包完成。


## R6a 已确认交付 / R6b 整图审阅（2026-10-06）

用户确认主标题新版扫光。正式交付 assets/ui/main_menu/art_text/title/：底字、光晕、扫光遮罩、108 帧、独立 art_text manifest 与 motion.md。8 项资源检查全部通过，底字 SHA 不变，交付图层回贴峰值像素差为 0。现行导入工具尚未注册 art_text，未改动运行时主菜单。

R6b 原生生成 8 次：章节/墙缝、章节/骨花母体、胜利、失败、战斗开始五张整图；八关字形稿三次。前两张透明稿边缘噪点拒绝交付，最终用纯色底字形整张审阅。统一审阅页 tools/_raw/p3/art_text_review/index.html。新图尚待视觉判断，未切片、未接入。完整逐项测试与剩余事项见 docs/P3_ART_TEXT_DELIVERY.md。


## R4 场景地图与障碍候选（2026-10-06）

输出 `assets/backdrops/review_r4/`：8关 full/base 各一张 1920×1080 PNG；01、02、07 无 blocked，full/base 相同；03、04、05、06、08 生成 9 张原生透明障碍切片与每关 obstacles.json。所有障碍格来自现行关卡 blocked 数据，切片按 `print_playfield_rects.py` 坐标放置。审阅总览和逐关资源链接见 `../../docs/R4_ASSET_REVIEW.md`。

内置 image_gen 调用 8 次：五类障碍各生成一张，石墙、根团、碎木堆各针对“低矮贴地”修订一次。最终 prompt 要点与来源分辨率限制见 R4 审阅说明。完整场景来自已有审阅图；素材只交候选目录，不覆盖正式运行背景或关卡 JSON。

| 测试用例 | 结果 |
|---|---|
| full/base尺寸与PNG读取 | 通过，8/8关均为1920×1080 |
| 无障碍关full/base像素一致 | 通过，01/02/07共3/3 |
| 障碍切片alpha | 通过，9/9张透明 |
| `cells` 与 `grid.blocked` 覆盖 | 通过，5关35/35个blocked格 |
| `obstacle_check.py` 回贴 | 通过，8/8关差异0.00%（要求<1%） |
| 隔离夹具 `validate_data.py` | 通过；真实关卡数据未接入或修改 |

待办：用户目视批准整图及障碍大小/位置；通过后再移动至正式路径并接入 `scene.obstacles`，随后做 Godot 实机截图验收。细项见 `../../docs/R4_ASSET_REVIEW.md`。
