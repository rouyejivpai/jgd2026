shader_type canvas_item;
// 视野/射程环（04 §2.8，策划已定两种样式不同）：style 0 = 视野虚线细环；style 1 = 射程 15% 填充 + 实线环；柔边。
// 用在边长 2×(radius_px+feather) 的正方形 ColorRect 上，UV 中心为圆心。
uniform float radius_px = 100.0;
uniform int style = 1;
uniform vec4 color : source_color = vec4(0.91, 0.86, 0.77, 1.0);
uniform float line_px = 2.5;
uniform float dashes = 48.0;
uniform float feather_px = 2.0;
uniform float quad_px = 104.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * quad_px;
	float d = length(p);
	float ring = 1.0 - smoothstep(line_px * 0.5, line_px * 0.5 + feather_px, abs(d - radius_px));
	float a = 0.0;
	if (style == 0) {
		float ang = atan(p.y, p.x) / 6.28318 + 0.5;
		float dash = step(0.5, fract(ang * dashes));
		a = ring * dash * 0.75;
	} else {
		float fill = (1.0 - smoothstep(radius_px - feather_px, radius_px, d)) * 0.15;
		a = max(fill, ring * 0.9);
	}
	COLOR = vec4(color.rgb, color.a * a);
}
