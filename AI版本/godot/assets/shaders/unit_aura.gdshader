shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// 2026-10-19 单位背光：人物身后的柔光 + 缓慢旋转的放射光芒（画在精灵之后，被人物遮住中心，只从轮廓四周透出）。
// 预乘 alpha 输出：additive = 1 纯叠加发光（己方金光）；越小越接近普通混合（敌方暗红，既压暗底图又透出红光）。
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.35, 1.0);
uniform float energy = 2.0;                        // HDR 亮度倍数：透过 CanvasModulate 并触发辉光
uniform float additive : hint_range(0.0, 1.0) = 1.0;
uniform float core = 0.55;                         // 中心柔光强度
uniform float rays = 0.6;                          // 放射光芒强度
uniform float ray_count = 9.0;
uniform float ray_speed = 0.25;
uniform float pulse_speed = 1.3;
uniform float seed = 0.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

float ray_layer(float ang, float n, float t) {
	return pow(0.5 + 0.5 * sin(ang * n + t), 6.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);
	float t = TIME * ray_speed + seed * 6.2831;
	float glow = exp(-r * r * 3.5);
	float rr = ray_layer(ang, ray_count, t) * 0.6 + ray_layer(ang, floor(ray_count * 0.5) + 2.0, -t * 1.3 + 1.7) * 0.4;
	float fall = smoothstep(1.0, 0.2, r) * smoothstep(0.05, 0.3, r);
	float pulse = 0.85 + 0.15 * sin(TIME * pulse_speed + seed * 6.2831);
	float a = clamp((glow * core + rr * rays * fall) * pulse * smoothstep(1.0, 0.75, r) * opacity, 0.0, 1.0);
	COLOR = vec4(color.rgb * energy * a, a * (1.0 - additive) * color.a);
}
