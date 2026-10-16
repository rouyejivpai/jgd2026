shader_type canvas_item;
// ScrollText 遮罩两端渐隐（P6）：内容超出遮罩时，可见窗口两端各 fade 像素内淡出，提示还有内容。
// 按 label 局部坐标计算：窗口 = [window_start, window_start + window_len)；已滚到起点 / 末端的一侧不淡出。
uniform bool vertical = false;
uniform float window_start = 0.0;
uniform float window_len = 100.0;
uniform float fade = 12.0;
uniform bool fade_start = false;
uniform bool fade_end = true;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float p = (vertical ? local_pos.y : local_pos.x) - window_start;
	float a = 1.0;
	if (fade_start) {
		a *= smoothstep(0.0, fade, p);
	}
	if (fade_end) {
		a *= smoothstep(0.0, fade, window_len - p);
	}
	COLOR.a *= a;
}
