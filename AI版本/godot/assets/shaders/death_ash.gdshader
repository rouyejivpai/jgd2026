shader_type canvas_item;
// 击败灰化（2026-10-19 战斗打击感）：gray 0→1 去色变灰；cut 0→1 自上而下剔除（边缘参差、带一道余烬亮边），
// 剔除线由 UnitView 同步给灰烬粒子发射器。uv_top / uv_bottom = 人物可见区域在贴图上的纵向范围（进度均匀）。
uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform float cut : hint_range(0.0, 1.0) = 0.0;
uniform float uv_top = 0.0;
uniform float uv_bottom = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.92, 0.8, 1.0);
uniform float edge_energy = 3.0;
uniform float edge_width = 0.05;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	float a = hash(i), b = hash(i + vec2(1.0, 0.0)), c = hash(i + vec2(0.0, 1.0)), d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec4 c = COLOR;      // 片元输入 COLOR 已是 贴图 × 顶点色（Q-073）
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(lum * 0.8 + 0.06), gray);
	c.rgb = mix(c.rgb, vec3(1.0), flash * c.a);
	if (cut > 0.0) {
		float v = (UV.y - uv_top) / max(uv_bottom - uv_top, 0.001);
		float n = vnoise(UV * vec2(24.0, 14.0)) * 0.09 + vnoise(UV * 61.0) * 0.04;
		float d = v - (cut * (1.0 + edge_width + 0.13) - edge_width) - n;
		if (d < 0.0) {
			discard;
		}
		float e = 1.0 - smoothstep(0.0, edge_width, d);
		c.rgb = mix(c.rgb, edge_color.rgb * edge_energy, e);
	}
	COLOR = c;
}
