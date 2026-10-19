shader_type canvas_item;
// 场景转场「菱晶碎裂波」（2026-10-19）：TEXTURE = 切换前截下的旧画面。
// 画面被切成 45° 的菱形格；以 origin（点击处）为心，一圈圈依次收缩到各自格心消失（progress 0 → 1），露出下面的新界面。
// 收缩中的菱晶边缘先烧成 ember（暗红）、再亮成 rim（银白）；格子越靠外开始越晚（spread 控制波的拖尾）。

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 origin = vec2(0.5, 0.5);
uniform float cells = 14.0;              // 横向大约多少个菱晶
uniform float aspect = 1.7777778;
uniform float spread = 0.55;             // 0 = 全部同时；越大波越明显
uniform float rim = 0.09;                // 边缘发光宽度（格内归一化）
uniform vec4 rim_color : source_color = vec4(0.925, 0.9, 0.95, 1.0);
uniform vec4 ember_color : source_color = vec4(0.69, 0.11, 0.165, 1.0);

void fragment() {
	vec2 p = vec2(UV.x * aspect, UV.y) * cells;
	vec2 r = vec2(p.x + p.y, p.y - p.x) * 0.70710678;          // 旋转 45°：方格 → 屏幕上的菱形
	vec2 cell = floor(r) + 0.5;
	vec2 local = r - cell;                                       // -0.5 .. 0.5
	vec2 cc = vec2(cell.x - cell.y, cell.x + cell.y) * 0.70710678 / cells;   // 格心（aspect 空间）
	vec2 o = vec2(origin.x * aspect, origin.y);
	float far = max(max(distance(o, vec2(0.0)), distance(o, vec2(aspect, 0.0))), max(distance(o, vec2(0.0, 1.0)), distance(o, vec2(aspect, 1.0))));
	float d = distance(cc, o) / max(far, 0.001);
	float t = clamp((progress - d * spread) / max(1.0 - spread, 0.001), 0.0, 1.0);
	t = t * t * (3.0 - 2.0 * t);
	float half_size = 0.5 * (1.0 - t);
	float m = max(abs(local.x), abs(local.y));
	float inside = step(m, half_size);
	float edge = smoothstep(half_size - rim, half_size, m) * inside * smoothstep(0.0, 0.15, t);
	vec4 c = texture(TEXTURE, UV);
	vec3 glow = mix(ember_color.rgb, rim_color.rgb, smoothstep(0.25, 0.85, t));
	vec3 col = mix(c.rgb * (1.0 - 0.35 * t), glow, edge);       // 收缩中的菱晶略压暗，边缘发光
	COLOR = vec4(col, c.a * inside);
}
