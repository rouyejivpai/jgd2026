shader_type canvas_item;
render_mode blend_add, unshaded;
// 2026-10-19 人物边缘淡光：精灵的一份拷贝画在本体之后，按邻域 alpha 做软外扩，只在轮廓外透出一圈淡光。
// 顶点段与 breathing.gdshader 相同（参数同步），保证外光跟着呼吸起伏。
uniform float amplitude = 0.015;
uniform float speed = 1.2;
uniform float seed = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.35, 1.0);
uniform float energy = 1.5;
uniform float radius = 5.0;                        // 外扩半径（贴图像素）
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	float t = TIME * speed + seed * 6.2831;
	float k = clamp(-VERTEX.y / 200.0, 0.0, 1.0);
	VERTEX.y *= 1.0 + amplitude * sin(t) * k;
	VERTEX.x += amplitude * 40.0 * sin(t * 0.7 + VERTEX.y * 0.05) * k;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * radius;
	float a = texture(TEXTURE, UV).a;
	float s = 0.0;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5236;
		vec2 d = vec2(cos(ang), sin(ang));
		s += texture(TEXTURE, UV + d * px).a + texture(TEXTURE, UV + d * px * 0.5).a;
	}
	s /= 24.0;
	float edge = clamp(s * 1.4 - a * 0.7, 0.0, 1.0);
	COLOR = vec4(color.rgb * energy, edge * opacity * color.a);
}
