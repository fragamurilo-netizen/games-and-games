shader_type spatial;
// Olho: esclera da textura do MakeHuman + íris procedural única por jogador (fibras radiais,
// criptas, colarete âmbar, anel limbal, pupila) e córnea molhada com reflexo forte.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 iris_col : source_color = vec3(0.3, 0.18, 0.1);
uniform vec3 iris_in : source_color = vec3(0.55, 0.36, 0.14);
uniform vec3 iris_b : source_color = vec3(0.3, 0.18, 0.1);
uniform float ring = 0.3;
uniform float limbal = 0.7;
uniform float pupil = 0.3;
uniform float hetero = 0.0;
uniform float seed = 0.0;
uniform float sclera_tint = 0.0;

const vec2 C1 = vec2(0.289, 0.707);
const vec2 C2 = vec2(0.707, 0.297);
const float R = 0.113;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec4 t = texture(tex, UV);
	vec3 col = t.rgb;
	// esclera: um pouco mais quente/avermelhada em alguns
	col = mix(col, col * vec3(1.02, 0.94, 0.9), sclera_tint);
	float d1 = length(UV - C1);
	float d2 = length(UV - C2);
	bool first = d1 < d2;
	vec2 dv = first ? UV - C1 : UV - C2;
	float r = length(dv) / R;
	if (r < 1.08) {
		float ang = atan(dv.y, dv.x);
		vec3 base = (hetero > 0.5 && !first) ? iris_b : iris_col;
		// fibras radiais e criptas
		float fib = vnoise(vec2(ang * 22.0 + seed, r * 3.0)) * 0.6 + vnoise(vec2(ang * 60.0 + seed * 2.0, r * 8.0)) * 0.4;
		float crypt = smoothstep(0.62, 0.8, vnoise(vec2(ang * 9.0 + seed * 3.0, r * 5.0))) * smoothstep(0.35, 0.6, r) * (1.0 - smoothstep(0.75, 0.9, r));
		vec3 ic = base * (0.7 + 0.6 * fib);
		ic = mix(ic, iris_in * (0.8 + 0.4 * fib), ring * (1.0 - smoothstep(0.3, 0.55, r)));
		ic *= 1.0 - crypt * 0.35;
		ic *= mix(1.0, 0.35, limbal * smoothstep(0.78, 1.0, r));
		float pr = pupil * 0.45 + 0.18;
		ic = mix(vec3(0.02), ic, smoothstep(pr - 0.02, pr + 0.03, r));
		col = mix(ic, col, smoothstep(0.98, 1.06, r));
	}
	ALBEDO = col;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
}
