# 部署HUD · 悬浮方案 V2

用户已确认上一批场景素材无误。本轮仅重新设计部署HUD；其他界面继续等待重新设计和统一审阅。

[查看1920×1080整图](../godot/assets/ui/hud/design_deploy_floating_v2.png) · [打开完整设计源](../godot/assets/ui/hud/design_deploy_floating_v2.html)

采用独立悬浮组件、半透明纹样、头像与宝石出框、功能色。开始为最大操作控件，预算与角色卡放大。场景、角色图像和普通字体复用现有资源；炼金结晶代表Cost。

使用原生image_gen生成无字装饰，普通文字用游戏NotoSerifSC与Cinzel排版。只交付整图，没有导出单控件切片或接入游戏。

[每项检查结果与制作说明](../godot/tools/_raw/p3/hud_floating_v2/DESIGN_NOTES.md)：画布、三种字体加载、透明像素、浏览器绘制、24条文字宽度检查通过。运行时缺少Chromium导致首次渲染失败，改用本机Edge成功；临时脚本已删除。未进行本轮游戏实机测试。
