shader_type canvas_item;
// 艺术字光晕层（R6a motion.md）：screen 混合 result = 1 − (1 − dst) × (1 − src × opacity)，不可换成 Add。
// src = 光晕贴图颜色 × 自身 alpha；opacity 由 ArtText 每帧写入（0.95 × envelope）。

uniform float opacity = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 g = texture(TEXTURE, UV);
	vec3 dst = texture(screen_tex, SCREEN_UV).rgb;
	vec3 src = g.rgb * g.a * opacity;
	COLOR = vec4(vec3(1.0) - (vec3(1.0) - dst) * (vec3(1.0) - src), 1.0);
}
