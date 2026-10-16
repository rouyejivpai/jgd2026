shader_type canvas_item;
// 选中描边（04 §2.8）：在透明像素处检测邻域 alpha，输出外描边颜色（本体像素不绘制，叠放在本体之后使用）。
uniform float width = 3.0;
uniform vec4 color : source_color = vec4(0.79, 0.64, 0.29, 1.0);

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	float a = texture(TEXTURE, UV).a;
	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV + px * 0.707).a);
	n = max(n, texture(TEXTURE, UV - px * 0.707).a);
	n = max(n, texture(TEXTURE, UV + vec2(px.x, -px.y) * 0.707).a);
	n = max(n, texture(TEXTURE, UV + vec2(-px.x, px.y) * 0.707).a);
	float o = clamp(n - a, 0.0, 1.0);
	COLOR = vec4(color.rgb, color.a * o);
}
