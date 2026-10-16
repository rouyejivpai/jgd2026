shader_type canvas_item;
// 后期（04 §2.8）：暗角 + 胶片噪点 + 轻微色差。全屏 ColorRect 使用，读取屏幕纹理。
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.35;
uniform float grain = 0.05;
uniform float aberration = 0.002;

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - 0.5;
	float r = texture(screen_texture, uv + dir * aberration).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - dir * aberration).b;
	vec3 c = vec3(r, g, b);
	float v = 1.0 - vignette * smoothstep(0.25, 0.85, length(dir) * 1.25);
	// 噪点在感知空间（近似 sRGB）叠加，避免 HDR 线性空间里暗部噪点被放大
	vec3 p = pow(max(c * v, vec3(0.0)), vec3(1.0 / 2.2));
	float n = (rand(uv * vec2(1920.0, 1080.0) + fract(TIME) * 37.0) - 0.5) * grain;
	p = clamp(p + n, 0.0, 1.0);
	COLOR = vec4(pow(p, vec3(2.2)), 1.0);
}
