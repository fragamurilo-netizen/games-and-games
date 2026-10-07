// Acabamento de foto sobre o retrato desenhado (teste). O desenho vetorial é nítido demais e é isso
// que mais denuncia o "desenho": uma foto de verdade tem a lente macia, o foco nos olhos (orelhas,
// cabelo e ombros um pouco fora de foco), textura e manchas de cor na pele, brilho que vaza nas
// luzes, grão do sensor, a curva de cor da câmera e a vinheta da lente. O retrato chega desenhado
// em 2x (SubViewport) e sai na metade, com alfa pré-multiplicado.
shader_type canvas_item;
render_mode blend_premul_alpha;

// Tamanho de um texel da textura de origem
uniform vec2 texel = vec2(0.0016667);
// Centro e raios do rosto em UV (foco)
uniform vec2 face_c = vec2(0.5, 0.48);
uniform vec2 face_r = vec2(0.25, 0.36);
uniform float seed = 0.0;
// Lente: maciez de base e desfoque fora do plano dos olhos (em texels da origem)
uniform float soft_px = 0.8;
uniform float dof_px = 3.0;
uniform float pores = 1.0;
uniform float mottle = 0.5;
uniform float grain_amt = 0.025;
uniform float bloom = 0.1;
uniform float clarity = 0.18;
uniform float vignette = 0.16;
uniform float aberration = 1.0;

const vec2 DISC[12] = vec2[](
	vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457), vec2(-0.203, 0.621),
	vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767), vec2(0.185, -0.893),
	vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598)
);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.0137);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Disco de 12 amostras + centro, raio em texels (cores pré-multiplicadas)
vec4 disc(sampler2D t, vec2 uv, float r) {
	vec4 s = texture(t, uv) * 0.16;
	float w = 0.16;
	for (int i = 0; i < 12; i++) {
		s += texture(t, uv + DISC[i] * r * texel) * 0.07;
		w += 0.07;
	}
	return s / w;
}

// Pele pela cor (YCbCr): tons de pele de claros a escuros, sem cabelo preto, roupa ou fundo
float skin_mask(vec3 c) {
	float y = lum(c);
	float cr = 0.5 + 0.5 * c.r - 0.4187 * c.g - 0.0813 * c.b;
	float cb = 0.5 - 0.1687 * c.r - 0.3313 * c.g + 0.5 * c.b;
	float m = smoothstep(0.515, 0.535, cr) * (1.0 - smoothstep(0.64, 0.68, cr));
	m *= smoothstep(0.30, 0.34, cb) * (1.0 - smoothstep(0.49, 0.52, cb));
	m *= smoothstep(0.06, 0.12, y) * (1.0 - smoothstep(0.92, 0.98, y));
	return m;
}

vec3 tone(vec3 x) {
	// Curva de filme: pé macio e ombro que não estoura
	x = max(x, vec3(0.0));
	vec3 a = x * (2.51 * x + 0.03);
	vec3 b = x * (2.43 * x + 0.59) + 0.14;
	vec3 aces = clamp(a / b, 0.0, 1.0);
	return mix(x, aces, 0.3);
}

void fragment() {
	vec2 uv = UV;
	// Foco nos olhos: o rosto fica nítido; orelhas, alto do cabelo e ombros saem do plano
	vec2 d = (uv - face_c) / face_r;
	float e = length(d * vec2(1.0, 0.82));
	float r = soft_px + dof_px * smoothstep(0.8, 1.7, e);
	vec4 c = disc(TEXTURE, uv, r);
	float a = c.a;
	vec3 col = a > 0.001 ? c.rgb / a : vec3(0.0);
	// Aberração da lente: vermelho e azul descolam um pouco perto das bordas do quadro
	vec2 fromc = uv - vec2(0.5);
	float ab = aberration * dot(fromc, fromc) * 2.2;
	if (a > 0.001 && ab > 0.0) {
		vec4 cr = disc(TEXTURE, uv + fromc * ab * texel * 6.0, r);
		vec4 cbb = disc(TEXTURE, uv - fromc * ab * texel * 6.0, r);
		col.r = cr.a > 0.001 ? mix(col.r, cr.r / cr.a, 0.8) : col.r;
		col.b = cbb.a > 0.001 ? mix(col.b, cbb.b / cbb.a, 0.8) : col.b;
	}
	// Microcontraste de foto (clareza) sem voltar a desenhar contornos
	vec4 big = disc(TEXTURE, uv, 9.0);
	vec3 bigc = big.a > 0.001 ? big.rgb / big.a : col;
	col += (col - bigc) * clarity * (1.0 - smoothstep(0.15, 0.35, abs(lum(col) - lum(bigc))));
	// Pele: manchas de cor (vermelho no nariz e nas maçãs, amarelado na testa) e poros
	float sk = skin_mask(col) * a;
	if (sk > 0.0) {
		vec2 p = uv / texel;
		float lowf = vnoise(p * 0.018 + 3.1) - 0.5;
		float lowf2 = vnoise(p * 0.031 + 11.7) - 0.5;
		col += sk * mottle * (vec3(0.05, -0.012, -0.02) * lowf + vec3(0.012, 0.02, -0.03) * lowf2);
		float pr = (vnoise(p * 0.55) - 0.5) * 0.6 + (vnoise(p * 1.3 + 7.0) - 0.5) * 0.4;
		float mid = clamp(4.0 * lum(col) * (1.0 - lum(col)), 0.0, 1.0);
		col *= 1.0 + sk * pores * pr * 0.09 * mid;
	}
	// Brilho que vaza das luzes fortes (pele oleosa, camisa branca)
	vec4 hb = disc(TEXTURE, uv, 7.0);
	vec3 hbc = hb.a > 0.001 ? hb.rgb / hb.a : vec3(0.0);
	col += max(hbc - 0.72, vec3(0.0)) * bloom * vec3(1.0, 0.93, 0.85) * hb.a;
	// Cor da câmera: pé quente, sombras um pouco frias, curva de filme
	float l = lum(col);
	col = mix(col, col * vec3(0.97, 1.0, 1.05), (1.0 - smoothstep(0.0, 0.45, l)) * 0.6);
	col = mix(col, col * vec3(1.04, 1.0, 0.95), smoothstep(0.5, 1.0, l) * 0.5);
	col = tone(col);
	// Vinheta da lente
	float vd = dot(fromc * vec2(1.0, 0.9), fromc * vec2(1.0, 0.9));
	col *= 1.0 - vignette * smoothstep(0.08, 0.5, vd);
	// Grão do sensor (mais nos meios-tons), um pouco de cor
	vec2 gp = floor(uv / texel * 0.5);
	float g = (hash(gp) + hash(gp + 17.3) - 1.0);
	float w = 0.45 + 2.0 * l * (1.0 - l);
	col += vec3(g) * grain_amt * w;
	col += (vec3(hash(gp + 3.1), hash(gp + 5.3), hash(gp + 7.9)) - 0.5) * grain_amt * 0.35;
	col = clamp(col, 0.0, 1.0);
	COLOR = vec4(col * a, a);
}
