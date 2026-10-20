shader_type canvas_item;
// 开场动画（2026-10-20）：全屏胶片噪点 + 偶发的竖向划痕，盖在最上层；不读屏幕纹理，只叠一层半透明噪声。
uniform float grain = 0.035;
uniform float scratches = 0.35;

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	float frame = floor(TIME * 18.0);
	float n = rand(UV * vec2(1920.0, 1080.0) + frame * 1.37);
	float a = abs(n - 0.5) * 2.0 * grain;
	// 划痕：每帧随机 0–2 条，很细、很淡
	float line = 0.0;
	for (int i = 0; i < 2; i++) {
		float seed = rand(vec2(frame, float(i) * 7.1));
		if (seed < scratches) {
			float x = rand(vec2(frame * 0.37, float(i) + 3.3));
			line += smoothstep(0.0012, 0.0, abs(UV.x - x)) * 0.12;
		}
	}
	COLOR = vec4(vec3(step(0.5, n)), clamp(a + line, 0.0, 1.0));
}
