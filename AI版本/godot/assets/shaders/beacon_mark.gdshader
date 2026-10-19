shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// 2026-10-20 信标 / 路径点地面光圈（BeaconLayer 每个信标一块 ColorRect，节点 y 向压扁 0.6 成 3/4 视角椭圆，同角色脚下的阵营光圈紧贴地面）：
// 风格取现有材质——深底金边（信标数字牌 p6_beacon_badge）、外环芯线 + 宽光晕（blast_marker）、内圈旋转的炼金符文刻度（deploy_zone）、
// 中心柔光（unit_aura）。预乘 alpha 输出：深色底盘按普通混合压暗底图，金色光按纯叠加发光（HDR 触发辉光、不被 CanvasModulate 压暗）。
// glow：光效强度（0 = 只剩半透明印记，未激活的路径点）；blink：1 = 当前前往的目标点，整体闪烁并向外扩散光波。
uniform vec4 color : source_color = vec4(1.0, 0.74, 0.3, 1.0);
uniform vec4 base_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);   // 地面阴影（同角色脚下的黑色椭圆）
uniform float quad_px = 64.0;          // 半边长（本层单位）
uniform float ring_px = 34.0;          // 外环半径（本层单位）
uniform float line_px = 2.4;           // 芯线宽（本层单位，按屏幕像素换算后传入）
uniform float energy = 1.8;            // 发光 HDR 倍数
uniform float glow : hint_range(0.0, 1.0) = 1.0;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform float flash_phase = 0.0;       // 闪烁相位 0–1（BeaconLayer 每帧传入，与行动线闪烁同步）
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float seed = 0.0;

float band(float d, float r, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 1.5, abs(d - r));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * quad_px;
	float d = length(p);
	float ang = atan(p.y, p.x);
	float tm = TIME + seed * 7.13;
	float breathe = 0.5 + 0.5 * sin(tm * 2.2);
	// 闪烁：快速亮起、缓慢回落，叠在常亮的呼吸上
	float ph = flash_phase;
	float flash = mix(1.0, 0.35 + 0.65 * exp(-ph * 4.0), blink);
	float lit = glow * flash;

	// 地面阴影盘，外缘柔化
	float disc = 1.0 - smoothstep(ring_px - 1.0, ring_px + 1.0, d);
	// 外环芯线、外环光晕
	float rim = band(d, ring_px, line_px);
	float halo = exp(-pow(max(d - ring_px, 0.0) / (ring_px * 0.45), 2.0)) * step(ring_px, d)
		+ exp(-pow(max(ring_px - d, 0.0) / (ring_px * 0.25), 2.0)) * step(d, ring_px) * 0.6;
	// 内圈：旋转的符文刻度（deploy_zone）+ 一道细环
	float r_in = ring_px * 0.72;
	float inner = band(d, r_in, line_px * 0.55);
	float spin = ang + tm * 0.5;
	float ticks = step(0.78, fract(spin * 8.0 / 6.2831853)) * band(d, ring_px * 0.86, line_px * 1.6);
	// 四向菱形尖角（星盘刻度），环外侧
	float cross_ang = abs(fract((ang + 0.7853982) / 1.5707963) - 0.5) * 2.0;   // 正对四个方向时 = 1
	float spike = smoothstep(0.86, 1.0, cross_ang) * (1.0 - smoothstep(ring_px, ring_px * 1.32, d)) * step(ring_px, d);
	// 中心柔光
	float core = exp(-pow(d / (ring_px * 0.5), 2.0));
	// 目标点：向外扩散的光波
	float wave_r = ring_px * (1.0 + ph * 0.9);
	float wave = band(d, wave_r, line_px * 1.4) * (1.0 - ph) * blink;

	float shape = rim + inner * 0.7 + ticks * 0.85 + spike * 0.9;
	float light = shape * (0.55 + 0.45 * lit) + (halo * (0.35 + 0.25 * breathe) + core * 0.28 + wave * 0.9) * lit;
	float dark = disc * mix(0.55, 0.72, glow);

	float a_dark = clamp(dark, 0.0, 1.0) * opacity * base_color.a;
	vec3 add = color.rgb * mix(1.0, energy, lit) * clamp(light, 0.0, 1.6) * opacity;
	// 无光效时芯线按普通混合（半透明印记），有光效时纯叠加
	float a_line = clamp(shape, 0.0, 1.0) * opacity * (1.0 - glow) * 0.8;
	COLOR = vec4(base_color.rgb * a_dark * (1.0 - a_line) + add, clamp(a_dark + a_line, 0.0, 1.0));
}
