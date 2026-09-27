shader_type spatial;
// Pele do busto 3D, pintada ponto a ponto pela posição na pose base (CUSTOM0, em decímetros):
// tom exato do jogador com variação regional (lábios, bochechas, nariz, orelhas, olheiras, pálpebras),
// microrrelevo de poros e rugas por idade (relevo por derivadas de tela, sem tangentes), sardas,
// pintas, manchas de idade, espinhas, cicatriz, sombra de barba, barba rala e cabelo raspado.
// A textura do MakeHuman entra só como modulação de baixa frequência (sombras naturais do rosto).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/ui/face3d/hairmask.gdshaderinc"

uniform sampler2D detail_tex : source_color, filter_linear_mipmap;
uniform sampler2D pores : filter_linear_mipmap, repeat_enable;
uniform vec3 detail_avg = vec3(0.6, 0.45, 0.4);
uniform float detail_k = 0.8;
uniform vec3 target = vec3(0.6, 0.45, 0.4);
uniform float dark = 0.0;         // 0 pele clara … 1 retinta (ajusta lábios, rubor, brilho)
uniform float rosy = 0.3;
uniform float age = 0.0;          // 0 jovem … 1 velho (rugas)
uniform float wr_fore = 0.0;
uniform float wr_eyes = 0.0;
uniform float wr_naso = 0.0;
uniform float eyebags = 0.0;
uniform float circles = 0.0;
uniform float freckles = 0.0;
uniform float spots = 0.0;
uniform float acne = 0.0;
uniform float oily = 0.5;
uniform float lip_dark = 0.0;
uniform vec4 mole1 = vec4(0.0);   // x, y (dm), tamanho, lado (-1/1)
uniform vec4 mole2 = vec4(0.0);
uniform vec4 scar = vec4(0.0);    // x, y, comprimento, ângulo
uniform float seed = 0.0;
// Cabelo raspado / sob as mechas
uniform vec3 hair_col : source_color = vec3(0.1, 0.07, 0.05);
uniform float scalp = 0.0;
// Barba pintada (rala, por fazer) e sombra de barba
uniform vec3 beard_col : source_color = vec3(0.1, 0.07, 0.05);
uniform float b_op = 0.0;
uniform float b_pt = 0.0;
uniform float shadow = 0.0;

varying vec3 pb;

void vertex() {
	pb = CUSTOM0.xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vnoise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

// Pontinhos (sardas, pintas pequenas, espinhas): células 3D com um ponto aleatório cada
float dots(vec3 p, float cell, float thr, float rad) {
	vec3 c = floor(p / cell);
	float best = 0.0;
	for (int k = 0; k < 8; k++) {
		vec3 o = vec3(float(k & 1), float((k >> 1) & 1), float((k >> 2) & 1));
		vec3 cc = c + o - vec3(0.5);
		vec3 cr = floor(cc + 0.5);
		float h = hash3(cr + seed);
		if (h < thr) {
			vec3 pt = (cr + vec3(hash3(cr + 1.3), hash3(cr + 2.7), hash3(cr + 4.1))) * cell;
			float d = length(p - pt) / (cell * rad * (0.5 + h / thr));
			best = max(best, 1.0 - smoothstep(0.6, 1.0, d));
		}
	}
	return best;
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 v = b - a;
	float t = clamp(dot(p - a, v) / dot(v, v), 0.0, 1.0);
	return length(p - (a + t * v));
}

// Rugas e marcas de expressão (altura negativa = sulco)
float wrinkles(vec3 p) {
	float ax = abs(p.x);
	float h = 0.0;
	// testa
	float wav = 0.018 * sin(p.x * 7.0 + seed) + 0.012 * sin(p.x * 13.0 + 1.3);
	float ln = abs(sin((p.y + wav) * 26.0));
	h -= wr_fore * (1.0 - smoothstep(0.0, 0.22, ln)) * smoothstep(8.3, 8.45, p.y) * (1.0 - smoothstep(8.7, 8.85, p.y))
		* smoothstep(0.9, 1.25, p.z) * (1.0 - smoothstep(0.45, 0.62, ax));
	// entre as sobrancelhas
	h -= wr_fore * 0.8 * exp(-pow((ax - 0.055) / 0.016, 2.0)) * smoothstep(8.08, 8.18, p.y) * (1.0 - smoothstep(8.33, 8.42, p.y)) * smoothstep(1.3, 1.45, p.z);
	// pés de galinha
	vec2 e = vec2(ax - 0.56, p.y - 8.02);
	float ang = atan(e.y, e.x);
	float rad = length(e);
	h -= wr_eyes * (1.0 - smoothstep(0.0, 0.3, abs(sin(ang * 5.0 + seed * 0.1)))) * smoothstep(0.05, 0.09, rad) * (1.0 - smoothstep(0.2, 0.3, rad))
		* step(0.5, ax) * smoothstep(0.6, 0.9, p.z);
	// dobras sob os olhos
	h -= (wr_eyes * 0.7 + eyebags * 0.6) * exp(-pow((p.y - (7.9 - 0.2 * pow(ax - 0.3, 2.0))) / 0.02, 2.0)) * smoothstep(0.12, 0.2, ax) * (1.0 - smoothstep(0.45, 0.55, ax)) * smoothstep(1.1, 1.3, p.z);
	h += eyebags * 0.5 * exp(-pow((p.y - 7.94) / 0.04, 2.0)) * smoothstep(0.14, 0.22, ax) * (1.0 - smoothstep(0.42, 0.52, ax)) * smoothstep(1.1, 1.3, p.z);
	// sulco nasolabial e linhas de marionete
	h -= wr_naso * exp(-pow(seg_dist(vec2(ax, p.y), vec2(0.2, 7.64), vec2(0.33, 7.3)) / 0.028, 2.0)) * smoothstep(1.0, 1.25, p.z);
	h -= wr_naso * 0.6 * exp(-pow(seg_dist(vec2(ax, p.y), vec2(0.3, 7.3), vec2(0.34, 7.02)) / 0.024, 2.0)) * smoothstep(1.0, 1.25, p.z);
	// pescoço
	h -= age * 0.7 * (1.0 - smoothstep(0.0, 0.35, abs(sin(p.y * 18.0 + sin(p.x * 3.0) * 0.3)))) * smoothstep(6.3, 6.45, p.y) * (1.0 - smoothstep(6.75, 6.85, p.y)) * smoothstep(0.2, 0.7, p.z);
	return h;
}

void fragment() {
	vec3 p = pb;
	float ax = abs(p.x);
	// Cor base: tom do jogador × sombras naturais da textura (sem a saturação dela nos tons escuros)
	vec3 dt = texture(detail_tex, UV).rgb / max(detail_avg, vec3(0.02));
	float dl = dot(dt, vec3(0.3, 0.59, 0.11));
	dt = mix(dt, vec3(dl), 0.35 + dark * 0.5);
	dt = mix(vec3(1.0), clamp(dt, vec3(0.55), vec3(1.5)), detail_k);
	vec3 col = target * dt;
	// Variação regional
	float face = smoothstep(0.6, 1.1, p.z) * smoothstep(7.0, 7.3, p.y);
	float cheek = exp(-pow(length(vec2(ax - 0.42, p.y - 7.7) / vec2(0.22, 0.2)), 2.0)) * face;
	float nose = exp(-pow(length(vec2(p.x, p.y - 7.66) / vec2(0.13, 0.16)), 2.0)) * step(1.35, p.z);
	float ear = smoothstep(0.62, 0.72, ax) * exp(-pow(length(vec2((p.y - 7.58) / 0.45, (p.z - 0.45) / 0.35)), 2.0));
	vec3 red = mix(vec3(1.09, 0.86, 0.84), vec3(1.05, 0.92, 0.9), dark);
	col = mix(col, col * red, clamp((cheek * 0.45 + nose * 0.35 + ear * 0.4) * rosy, 0.0, 0.6));
	// Olheiras e pálpebras
	float under = exp(-pow(length(vec2(ax - 0.3, p.y - 7.92) / vec2(0.16, 0.06)), 2.0)) * step(1.05, p.z);
	col = mix(col, col * mix(vec3(0.82, 0.76, 0.8), vec3(0.8, 0.74, 0.74), dark), clamp(under * (circles + 0.25), 0.0, 1.0));
	float lid = exp(-pow(length(vec2(ax - 0.3, p.y - 8.1) / vec2(0.16, 0.05)), 2.0)) * step(1.0, p.z);
	col *= 1.0 - lid * 0.12;
	// Lábios
	float lipd = length(vec2(p.x / 0.25, (p.y - 7.39) / 0.09));
	float lips = (1.0 - smoothstep(0.75, 1.02, lipd)) * smoothstep(1.35, 1.5, p.z);
	vec3 lipc = mix(col * vec3(1.12, 0.78, 0.78), col * vec3(0.88, 0.72, 0.78), clamp(dark + lip_dark, 0.0, 1.0));
	col = mix(col, lipc, lips * 0.6);
	// Sardas, manchas de idade, espinhas
	float fr = dots(p, 0.035, 0.55, 0.45) * freckles * (cheek + nose * 1.4 + face * 0.3 + smoothstep(8.2, 8.7, p.y) * face * 0.4);
	col = mix(col, col * vec3(0.78, 0.62, 0.5), clamp(fr, 0.0, 0.85));
	float sp = dots(p, 0.16, 0.35, 0.5) * spots * (face + smoothstep(8.4, 9.0, p.y) * 0.8);
	col = mix(col, col * vec3(0.8, 0.68, 0.58), clamp(sp * 0.6, 0.0, 0.7));
	float ac = dots(p + 3.1, 0.06, 0.25, 0.3) * acne * face * (1.0 - lips);
	col = mix(col, col * vec3(1.12, 0.78, 0.76), clamp(ac, 0.0, 0.8));
	// Pintas
	for (int i = 0; i < 2; i++) {
		vec4 m = i == 0 ? mole1 : mole2;
		if (m.z > 0.0) {
			float d = length(vec2(p.x - m.x, p.y - m.y)) / m.z;
			col = mix(col, col * vec3(0.45, 0.33, 0.28), (1.0 - smoothstep(0.6, 1.0, d)) * step(0.9, p.z));
		}
	}
	// Cicatriz
	if (scar.z > 0.0) {
		vec2 dir = vec2(cos(scar.w), sin(scar.w));
		float d = seg_dist(p.xy, scar.xy - dir * scar.z * 0.5, scar.xy + dir * scar.z * 0.5);
		col = mix(col, col * vec3(1.1, 0.92, 0.9), (1.0 - smoothstep(0.004, 0.012, d)) * step(1.0, p.z) * 0.8);
	}
	// Microrrelevo (poros) + rugas → normal
	vec3 tri = abs(NORMAL);
	float pr = texture(pores, p.xy * 1.7).r * 0.5 + texture(pores, p.zy * 1.7 + 0.3).r * 0.5;
	float h = (pr - 0.5) * 0.35 * (0.6 + 0.4 * face) + wrinkles(p) * (0.4 + 0.6 * age + max(max(wr_fore, wr_eyes), wr_naso) * 0.2) + vnoise3(p * 14.0 + seed) * 0.06;
	float hs = h * 0.0022;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(hs);
	float dhy = dFdy(hs);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	vec3 n2 = normalize(abs(det) * NORMAL - grad);
	NORMAL = normalize(mix(NORMAL, n2, 0.9));
	col *= 1.0 + min(wrinkles(p), 0.0) * 0.12;
	float rough = mix(0.62, 0.7, dark);
	float tzone = (nose + exp(-pow(length(vec2(p.x, p.y - 8.45) / vec2(0.3, 0.2)), 2.0)) * face) * oily;
	rough -= tzone * 0.14 + lips * 0.12;
	// Sombra de barba (quem se barbeia) e barba rala pintada
	float bm = beard_mask(p);
	float cellh = hash(floor(UV * 2600.0) + seed);
	col = mix(col, col * mix(vec3(0.76, 0.77, 0.8), vec3(0.82, 0.8, 0.8), dark), clamp(shadow * bm * (0.35 + 0.35 * cellh), 0.0, 0.6));
	if (b_op > 0.0) {
		float patch = mix(1.0, smoothstep(0.35, 0.65, vnoise3(p * 6.0 + seed)), b_pt);
		float cov = clamp(bm * patch * b_op * (0.45 + 0.55 * cellh), 0.0, 1.0);
		col = mix(col, beard_col * (0.75 + 0.5 * cellh), cov * 0.9);
		rough = mix(rough, 0.75, cov);
	}
	// Couro cabeludo sob o cabelo / raspado
	if (scalp > 0.0) {
		float m = scalp_mask(p) * pattern_mask(p) * scalp;
		float hh = hash(floor(UV * 3000.0) + seed * 2.0);
		float cov = clamp(m * (0.6 + 0.4 * hh), 0.0, 1.0);
		col = mix(col, hair_col * (0.75 + 0.5 * hh), cov);
		rough = mix(rough, 0.7, cov);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(0.32, 0.26, dark) + tzone * 0.1;
	BACKLIGHT = vec3(0.45, 0.14, 0.08) * (ear + 0.15);
}
