shader_type canvas_item;
// 头像圆形遮罩（04 §2.3"UI 用圆形遮罩显示"）：柔边圆外透明，外圈细描边。
uniform vec4 ring_color : source_color = vec4(0.79, 0.64, 0.29, 1.0);
uniform float ring_width = 0.03;

void fragment() {
	vec4 c = COLOR;      // 片元输入 COLOR 已是 贴图 × 顶点色；再乘一次贴图会让颜色变成平方（Q-073）
	float d = length(UV - 0.5) * 2.0;
	float inside = 1.0 - smoothstep(0.97, 1.0, d);
	float ring = smoothstep(1.0 - ring_width * 2.0, 1.0 - ring_width, d) * inside;
	COLOR = vec4(mix(c.rgb, ring_color.rgb, ring), c.a * inside);
}
