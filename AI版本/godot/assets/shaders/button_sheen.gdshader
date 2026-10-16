shader_type canvas_item;
// 按钮 hover 层（10 §1.5，P8）：只提亮切片里的金色描边 / 月牙（金色遮罩 = r − b 的平滑阶跃，取自贴图本身，不需要额外图层）。
// - 光带扫过：sweep ∈ [0, 1] 为进度（< 0 关闭），斜向光带从左外侧扫到右外侧，宽 band_px、斜率 slant（局部像素）
// - 常亮：hover 层非金色部分（底板）提亮 lift，金色加强 hover_boost（拉开选中与未选中的差别；分开作用避免金色被推到发白）
// - 呼吸：breathe_amp ·（0.5 + 0.5 · sin(2π · TIME / breathe_period)），amp = 0 时关闭
// 只用 TIME 与自身 uniform（约束 4）；全部参数由 ButtonMotion 从 data/ui_motion.json 写入。
uniform float sweep = -1.0;
uniform float width_px = 500.0;
uniform float band_px = 110.0;
uniform float slant = 0.45;
uniform float sweep_strength = 0.85;
uniform float breathe_amp = 0.0;
uniform float hover_boost = 0.0;
uniform float lift = 0.0;
uniform float breathe_period = 2.8;
uniform vec2 gold_mask = vec2(0.06, 0.22);

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec4 c = COLOR;      // 片元输入 COLOR 已是 贴图 × 顶点色（含 modulate）
	float gold = smoothstep(gold_mask.x, gold_mask.y, c.r - c.b);
	float boost = hover_boost + breathe_amp * (0.5 + 0.5 * sin(6.2831853 * TIME / breathe_period));
	if (sweep >= 0.0) {
		float x = local_pos.x - local_pos.y * slant;
		float center = mix(-band_px, width_px + band_px, sweep);
		boost += sweep_strength * (1.0 - smoothstep(0.0, band_px * 0.5, abs(x - center)));
	}
	c.rgb = min(c.rgb * (1.0 + lift * (1.0 - gold)) * (1.0 + gold * boost), vec3(1.0));
	COLOR = c;
}
