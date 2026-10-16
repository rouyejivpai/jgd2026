shader_type canvas_item;
// 待机呼吸（04 §2.8）：顶点级轻微缩放 + 低频蠕动（血肉感）。同一材质兼容受击白闪与选中描边参数。
uniform float amplitude = 0.015;
uniform float speed = 1.2;
uniform float seed = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.95, 0.9, 1.0);

void vertex() {
	float t = TIME * speed + seed * 6.2831;
	// 以脚底（局部原点附近，精灵偏移后在下方）为轴，上半身起伏更明显
	float k = clamp(-VERTEX.y / 200.0, 0.0, 1.0);
	VERTEX.y *= 1.0 + amplitude * sin(t) * k;
	VERTEX.x += amplitude * 40.0 * sin(t * 0.7 + VERTEX.y * 0.05) * k;
}

void fragment() {
	vec4 c = COLOR;      // 片元输入 COLOR 已是 贴图 × 顶点色；再乘一次贴图会让颜色变成平方（Q-073）
	c.rgb = mix(c.rgb, flash_color.rgb, flash * c.a);
	COLOR = c;
}
