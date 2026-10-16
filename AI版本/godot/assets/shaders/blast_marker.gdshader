shader_type canvas_item;
// 延迟爆炸预警（04 §2.8）：红色外环脉动，内部填充半径随 t（剩余比例 1→0）收缩。
uniform float t : hint_range(0.0, 1.0) = 1.0;
uniform float radius_px = 144.0;
uniform float quad_px = 152.0;
uniform vec4 color : source_color = vec4(1.0, 0.29, 0.24, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * quad_px;
	float d = length(p);
	float pulse = 0.6 + 0.4 * sin(TIME * 6.0);
	float edge = 1.0 - smoothstep(1.5, 3.5, abs(d - radius_px));
	float inside = 1.0 - smoothstep(radius_px - 2.0, radius_px, d);
	float core = 1.0 - smoothstep(radius_px * t - 2.0, radius_px * t, d);
	float a = inside * 0.08 + core * 0.22 + edge * pulse;
	COLOR = vec4(color.rgb * (1.0 + core * 0.4), clamp(a, 0.0, 1.0));
}
