shader_type canvas_item;
// 一级地图羊皮纸边缘羽化（2026-10-20）：羽化沿腐蚀线推进——越靠近图边，亮度门槛越高，烧焦变暗的地方先化开成透明，
// 露出底下的品红底光。亮度先做一次小范围模糊（blur_px），羽化边是柔和的一片，而不是逐像素的噪点。
// edge_uv = 左右 / 上下羽化区宽度（UV 比例；某轴为 0 = 该方向不羽化，如可横拖的区域地图只羽化左右）；
// lum_cut = 图边处的亮度门槛；soft = 羽化过渡宽度（亮度单位，越大越虚）。
uniform vec2 edge_uv = vec2(0.13, 0.13);
uniform float lum_cut = 0.98;
uniform float soft = 0.28;
uniform float blur_px = 9.0;
uniform vec4 char_color : source_color = vec4(0.16, 0.05, 0.10, 1.0);

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec4 c = COLOR;      // 片元输入 COLOR 已是 贴图 × 顶点色（Q-073）
	vec2 px = TEXTURE_PIXEL_SIZE * blur_px;
	float l = lum(c.rgb) * 0.2;
	l += lum(texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb) * 0.1;
	l += lum(texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb) * 0.1;
	l += lum(texture(TEXTURE, UV + vec2(0.0, px.y)).rgb) * 0.1;
	l += lum(texture(TEXTURE, UV - vec2(0.0, px.y)).rgb) * 0.1;
	l += lum(texture(TEXTURE, UV + px * 1.6).rgb) * 0.1;
	l += lum(texture(TEXTURE, UV - px * 1.6).rgb) * 0.1;
	l += lum(texture(TEXTURE, UV + vec2(px.x, -px.y) * 1.6).rgb) * 0.1;
	l += lum(texture(TEXTURE, UV + vec2(-px.x, px.y) * 1.6).rgb) * 0.1;
	vec2 d2 = min(UV, 1.0 - UV);
	float dx = edge_uv.x > 0.0 ? d2.x / edge_uv.x : 1e6;
	float dy = edge_uv.y > 0.0 ? d2.y / edge_uv.y : 1e6;
	float d = min(dx, dy);                                 // 到最近一条羽化边的距离（羽化宽 = 1）
	float near = 1.0 - smoothstep(0.0, 1.0, d);            // 图边 1 → 内部 0
	float th = near * lum_cut;
	float a = smoothstep(th - soft * 0.6, th + soft, l);
	a *= smoothstep(0.0, 0.45, d);                         // 最外一圈无论多亮都化开
	// 羽化边内侧略压一层暗品红，像烧痕的余温
	float rim = (1.0 - smoothstep(th, th + soft * 1.6, l)) * near;
	c.rgb = mix(c.rgb, char_color.rgb, clamp(rim * 0.3, 0.0, 1.0));
	COLOR = vec4(c.rgb, c.a * a);
}
