shader_type canvas_item;
// 一级地图底光（2026-10-20）：暗紫黑底上，地图后方一团暗品红光（取自原选关详情面板的品红 #601050），按 period 秒缓慢亮暗循环；
// 另有一团较小的光在其中缓缓游移，让光芒不死板。全屏 ColorRect 使用，aspect = 宽 / 高。
uniform vec4 base_color : source_color = vec4(0.075, 0.050, 0.080, 1.0);
uniform vec4 glow_color : source_color = vec4(0.376, 0.063, 0.314, 1.0);
uniform vec2 center = vec2(0.5, 0.5);
uniform float aspect = 1.7778;
uniform float radius = 0.7;
uniform float period = 7.5;
uniform float low = 0.45;

void fragment() {
	vec2 p = (UV - center) * vec2(aspect, 1.0);
	float t = TIME * 6.2831853 / period;
	float pulse = mix(low, 1.0, 0.5 + 0.5 * sin(t));
	float g1 = exp(-dot(p, p) / (radius * radius));
	vec2 q = p - vec2(0.28 * sin(t * 0.37), 0.14 * cos(t * 0.29));
	float g2 = exp(-dot(q, q) / (radius * radius * 0.4));
	float g = g1 * pulse * 0.9 + g2 * 0.3 * (0.8 + 0.2 * sin(t * 0.6 + 1.7));
	COLOR = vec4(base_color.rgb + glow_color.rgb * g, 1.0);
}
