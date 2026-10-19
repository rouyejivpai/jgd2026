shader_type canvas_item;
render_mode unshaded;
// 延迟爆炸预警（04 §2.8；2026-10-19 打击感：按施放者阵营着色，己方金色 / 敌方红色）：
// 外环发光脉动（越临近爆炸越快）、外环内侧一圈旋转的符文虚线、内部填充半径随 t（剩余比例 1→0）收缩、
// 收缩前沿一道亮环、剩余时间沿外环顺时针扫过的倒计时弧。color 可为 HDR（触发辉光）。
uniform float t : hint_range(0.0, 1.0) = 1.0;
uniform float radius_px = 144.0;
uniform float quad_px = 152.0;
uniform vec4 color : source_color = vec4(1.0, 0.29, 0.24, 1.0);
uniform float energy = 1.6;
uniform float spin_dir = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * quad_px;
	float d = length(p);
	float ang = atan(p.y, p.x);
	float urgency = 1.0 - t;
	float pulse = 0.55 + 0.45 * sin(TIME * (6.0 + 14.0 * urgency * urgency));
	float inside = 1.0 - smoothstep(radius_px - 2.0, radius_px, d);
	// 外环：芯线 + 宽光晕
	float edge = 1.0 - smoothstep(1.5, 3.5, abs(d - radius_px));
	float halo = (1.0 - smoothstep(0.0, 16.0, abs(d - radius_px))) * 0.45;
	// 符文虚线环（外环内侧，旋转）
	float rr = radius_px * 0.86;
	float band = 1.0 - smoothstep(1.0, 3.0, abs(d - rr));
	float dash = step(0.45, fract((ang / 6.2831853) * 24.0 + TIME * 0.35 * spin_dir));
	// 倒计时弧：从正上方顺时针扫过已流逝的部分
	float a01 = fract(0.25 - ang / 6.2831853 + 1.0);
	float sweep = step(a01, urgency) * (1.0 - smoothstep(2.0, 6.0, abs(d - radius_px * 1.06)));
	// 收缩填充与前沿亮环
	float r_core = radius_px * t;
	float core = 1.0 - smoothstep(r_core - 2.0, r_core, d);
	float front = (1.0 - smoothstep(1.0, 5.0, abs(d - r_core))) * step(0.02, t);
	float fill = inside * (0.07 + 0.1 * urgency) + core * (0.14 + 0.1 * pulse);
	float a = fill + edge * (0.55 + 0.45 * pulse) + halo * pulse + band * dash * 0.7 + sweep * 0.9 + front * 0.85;
	vec3 rgb = color.rgb * energy * (0.6 + 0.4 * (edge + front + sweep)) ;
	COLOR = vec4(rgb, clamp(a, 0.0, 1.0));
}
