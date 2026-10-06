shader_type spatial;
// Camadas (shells) de cabelo curto/crespo e de barba sobre a própria malha do busto: cada camada
// é a pele deslocada ao longo da normal; cada fio é um ponto do ruído que só "existe" até a sua
// altura. Dá volume de verdade a raspados, degradês, black power, high top, waves, nagô e barbas.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://scripts/ui/face3d/hairmask.gdshaderinc"

uniform sampler2D fur : filter_linear_mipmap, repeat_enable;
uniform float layer = 0.0;
uniform float mode = 0.0;       // 0 couro cabeludo, 1 barba
uniform vec4 len_a = vec4(0.004); // topo, frente, lateral, trás (m)
uniform float len_nape = 0.003;
uniform float beard_len = 0.004;
uniform float tile = 0.7;
uniform float coily = 0.0;
uniform float density = 1.0;
uniform float patchy = 0.0;
uniform float seed = 0.0;
uniform vec3 color : source_color = vec3(0.08, 0.06, 0.05);
uniform float lighten = 0.0;
uniform float gray = 0.0;
uniform float flat_top = 0.0;

varying vec3 pb;
varying float plen;

float region_len(vec3 p) {
	float ax = abs(p.x);
	float front = smoothstep(0.7, 1.2, p.z);
	float back = 1.0 - smoothstep(-0.5, 0.2, p.z);
	float side = smoothstep(0.45, 0.7, ax) * (1.0 - front);
	float top = smoothstep(8.75, 9.05, p.y);
	float nape = (1.0 - smoothstep(7.3, 7.9, p.y)) * back;
	float L = len_a.x;
	L = mix(L, len_a.y, front * (1.0 - top));
	L = mix(L, len_a.z, side * (1.0 - top));
	L = mix(L, len_a.w, back * (1.0 - top));
	L = mix(L, len_nape, nape);
	return L;
}

void vertex() {
	vec3 p = CUSTOM0.xyz;
	pb = p;
	float L;
	if (mode < 0.5) {
		L = region_len(p) * fade_mask(p);
		// high top: topo reto (quanto mais alto o ponto, menos cresce)
		L *= mix(1.0, 1.0 + smoothstep(8.4, 9.1, p.y) * 0.0 - (p.y - 8.9) * 1.6, flat_top);
	} else {
		L = beard_len;
	}
	plen = L;
	VERTEX += NORMAL * L * layer;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 p = pb;
	float m = mode < 0.5 ? scalp_mask(p) * pattern_mask(p) : beard_mask(p);
	if (mode < 0.5) {
		m *= step(0.0002, plen);
	}
	// projeção tripla pela posição base (sem depender do UV da pele)
	vec3 w = abs(normalize(pb - vec3(0.0, 8.1, 0.3)));
	w = pow(w, vec3(8.0));
	w /= (w.x + w.y + w.z);
	vec2 sd = vec2(seed * 0.37, seed * 0.11);
	vec4 f = texture(fur, pb.zy * tile + sd) * w.x + texture(fur, pb.xz * tile + sd) * w.y + texture(fur, pb.xy * tile + sd) * w.z;
	float h = f.r;
	if (coily > 0.0) {
		// crespo: tufos enrolados (canal A) em escala maior + fios finos
		float ct = tile * 0.3;
		float c2 = texture(fur, pb.zy * ct).a * w.x + texture(fur, pb.xz * ct).a * w.y + texture(fur, pb.xy * ct).a * w.z;
		h = mix(h, max(c2, f.r * 0.85), coily);
	}
	float pat = 1.0 - patchy * (1.0 - smoothstep(0.3, 0.7, texture(fur, pb.xy * 0.4 + seed).g));
	float need = layer / max(m * density * pat, 0.001);
	float a = smoothstep(need - 0.08, need + 0.02, h);
	if (m < 0.02) {
		a = 0.0;
	}
	// base quase opaca: a primeira camada cobre o couro cabeludo onde há cabelo
	if (layer < 0.001) {
		a = m * density * pat * 0.92;
	}
	vec3 c = color * (0.7 + 0.55 * f.g) * (0.55 + 0.5 * layer) * (0.92 + 0.16 * f.b);
	if (waves > 0.0 && mode < 0.5) {
		float d = length(vec2(p.x, p.z + 0.25)) + (9.2 - p.y) * 0.6;
		c *= 0.75 + 0.35 * smoothstep(-0.4, 0.8, sin(d * 38.0));
	}
	c = mix(c, vec3(0.93, 0.89, 0.8), lighten * smoothstep(0.3, 1.0, layer));
	c = mix(c, vec3(0.78, 0.77, 0.75) * (0.7 + 0.5 * f.g), gray * step(0.72 - gray * 0.3, f.b));
	ALBEDO = c;
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
}
