shader_type canvas_item;
// 部署格脉动符文（04 §2.8）：每格一个 tile_px 大小的 ColorRect；网格对齐的内框 + 旋转的炼金符文圈 + 呼吸亮度。
uniform float tile_px = 96.0;
uniform float pulse_speed = 2.0;
uniform vec4 color : source_color = vec4(0.79, 0.64, 0.29, 1.0);

void fragment() {
	vec2 p = (UV - 0.5) * tile_px;
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed * 3.14159);
	vec2 q = abs(p);
	float frame = 1.0 - smoothstep(1.0, 2.5, abs(max(q.x, q.y) - (tile_px * 0.5 - 4.0)));
	float r = length(p);
	float circle = 1.0 - smoothstep(0.8, 2.0, abs(r - tile_px * 0.3));
	float ang = atan(p.y, p.x) + TIME * 0.4;
	float runes = step(0.82, fract(ang * 6.0 / 6.28318)) * (1.0 - smoothstep(1.0, 3.0, abs(r - tile_px * 0.36)));
	float fill = 0.10 + 0.08 * pulse;
	float a = fill + frame * 0.55 + (circle * 0.35 + runes * 0.5) * (0.5 + 0.5 * pulse);
	COLOR = vec4(color.rgb, color.a * clamp(a, 0.0, 1.0));
}
