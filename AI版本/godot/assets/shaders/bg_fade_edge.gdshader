shader_type canvas_item;
// 背景四周渐隐（04 §2.8）：距离地图边缘 fade_px 内逐渐混合到 BG_DEEP。
// 按顶点局部坐标计算（兼容 Sprite2D 区域裁切）：rect_px = 精灵局部尺寸（区域大小），fade_px 也用局部单位。
uniform float fade_px = 96.0;
uniform vec2 rect_px = vec2(1248.0, 864.0);
uniform vec4 fade_color : source_color = vec4(0.071, 0.039, 0.063, 1.0);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 c = COLOR;      // 片元输入 COLOR 已是 贴图 × 顶点色；再乘一次贴图会让颜色变成平方（Q-073）
	float d = min(min(local_pos.x, rect_px.x - local_pos.x), min(local_pos.y, rect_px.y - local_pos.y));
	float k = smoothstep(0.0, fade_px, d);
	COLOR = vec4(mix(fade_color.rgb, c.rgb, k), 1.0);
}
