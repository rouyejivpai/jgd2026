shader_type canvas_item;
// 受击白闪（04 §2.8）：flash 0..1 时向 flash_color 混合，保留 alpha。
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 c = COLOR;      // 片元输入 COLOR 已是 贴图 × 顶点色；再乘一次贴图会让颜色变成平方（Q-073）
	c.rgb = mix(c.rgb, flash_color.rgb, flash * c.a);
	COLOR = c;
}
