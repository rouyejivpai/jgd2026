shader_type canvas_item;
// 2026-10-21 剧情选择：下层画面高斯模糊（7×7 采样，取 mip 级 lod 再加一层核，成本低且无块状感）。铺满视口的 ColorRect 上用。
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float radius = 18.0;     // 采样半径（像素）
uniform float lod = 2.0;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 c = vec3(0.0);
	float w = 0.0;
	for (int i = -3; i <= 3; i++) {
		for (int j = -3; j <= 3; j++) {
			vec2 o = vec2(float(i), float(j)) / 3.0;
			float k = exp(-dot(o, o) * 2.0);
			c += textureLod(screen_tex, SCREEN_UV + o * px, lod).rgb * k;
			w += k;
		}
	}
	COLOR = vec4(c / w, 1.0);
}
