shader_type canvas_item;
// 死亡溶解（04 §2.8）：噪声阈值逐步剔除像素，剔除边缘暗红发光。noise_tex 缺省时使用程序噪声。
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.70, 0.19, 0.25, 1.0);
uniform float edge_width = 0.08;
uniform sampler2D noise_tex : hint_default_white;
uniform bool use_noise_tex = false;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec4 c = COLOR;      // 片元输入 COLOR 已是 贴图 × 顶点色；再乘一次贴图会让颜色变成平方（Q-073）
	float n = use_noise_tex ? texture(noise_tex, UV).r : (vnoise(UV * 12.0) * 0.65 + vnoise(UV * 31.0) * 0.35);
	float cut = progress * (1.0 + edge_width);
	if (n < cut - edge_width) {
		discard;
	}
	float e = 1.0 - smoothstep(cut - edge_width, cut, n);
	c.rgb = mix(c.rgb, edge_color.rgb * 2.0, e * step(0.001, progress));
	COLOR = c;
}
