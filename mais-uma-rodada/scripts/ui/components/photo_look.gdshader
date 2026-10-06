// Cara de foto sobre o retrato recortado (PhotoPortrait). Tradução do protótipo
// tools/cutout_photo_fx_r3.py: a partir do alfa do recorte estima o volume (normais), reacende o
// rosto com a luz de cada cenário, monta o fundo, faz o vazamento de luz na borda, a curva de foto,
// o grão e a vinheta. Roda uma vez (SubViewport UPDATE_ONCE); o resultado fica como textura.
shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D cut : filter_linear, repeat_disable;
// Onde fica o quadrado do retrato, em UV do quadro (x, y, largura, altura)
uniform vec4 cut_rect = vec4(0.0, 0.0, 1.0, 1.0);
// Tamanho do quadro em px (cantos arredondados e grão)
uniform vec2 size_px = vec2(400.0, 400.0);
uniform float corner_px = 6.0;
uniform int mood = 0;
uniform float seed = 0.0;
uniform vec4 club1 : source_color = vec4(0.06, 0.18, 0.45, 1.0);
uniform vec4 club2 : source_color = vec4(0.78, 0.12, 0.14, 1.0);
// 1 = recorte (fundo transparente, como os cutouts do FM): só o jogador, com a luz do cenário
uniform int cutout_mode = 0;

// 1 px do protótipo (quadros de 400 px), em UV do retrato
const float U = 1.0 / 400.0;

float h1(float n) {
	return fract(sin(n * 127.1 + seed * 0.731) * 43758.5453);
}

float h2(vec2 p) {
	p = fract(p * vec2(123.34, 456.21) + seed * 0.013);
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float alpha_at(vec2 q) {
	// Os ombros saem pela borda de baixo do quadro: abaixo dela conta como "dentro"
	if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0) {
		return 0.0;
	}
	return texture(cut, vec2(q.x, min(q.y, 0.998))).a;
}

vec4 cut_at(vec2 q) {
	if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) {
		return vec4(0.0);
	}
	vec4 c = texture(cut, q);
	if (c.a > 0.002) {
		c.rgb /= c.a;
	}
	return c;
}

// Desfoque barato do alfa: centro + dois anéis de 8 amostras
float blur_a(vec2 q, float r) {
	float s = alpha_at(q) * 0.2;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982 + 0.39;
		vec2 d = vec2(cos(ang), sin(ang));
		s += alpha_at(q + d * r) * 0.05;
		s += alpha_at(q + d * r * 0.5) * 0.05;
	}
	return s;
}

vec3 blur_c(vec2 q, float r) {
	vec3 s = vec3(0.0);
	float w = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7853982;
		vec4 c = cut_at(q + vec2(cos(ang), sin(ang)) * r);
		s += c.rgb * c.a;
		w += c.a;
	}
	return w > 0.01 ? s / w : vec3(0.0);
}

// Normal aproximada: cúpula pela borda do recorte (alfa desfocado) e relevo pela luminância
vec3 normal_at(vec2 q, float relief) {
	float d = 9.0 * U;
	float R = 34.0 * U;
	float gx = blur_a(q + vec2(d, 0.0), R) - blur_a(q - vec2(d, 0.0), R);
	float gy = blur_a(q + vec2(0.0, d), R) - blur_a(q - vec2(0.0, d), R);
	vec2 g = vec2(gx, gy) * 3.6;
	float e = 2.0 * U;
	float lx = lum(cut_at(q + vec2(e, 0.0)).rgb) - lum(cut_at(q - vec2(e, 0.0)).rgb);
	float ly = lum(cut_at(q + vec2(0.0, e)).rgb) - lum(cut_at(q - vec2(0.0, e)).rgb);
	g += vec2(lx, ly) * relief * 0.25;
	return normalize(vec3(-g.x, -g.y, 1.0));
}

vec3 relight(vec3 c, vec3 N, vec3 L, float strength, float ambient) {
	vec3 l = normalize(L);
	float mult = ambient + (1.0 - ambient) * max(dot(N, l), 0.0);
	float mean = ambient + (1.0 - ambient) * l.z;
	return clamp(c * (1.0 + strength * (mult / mean - 1.0)), 0.0, 1.4);
}

float spec(vec3 N, vec3 L, float power) {
	vec3 hv = normalize(normalize(L) + vec3(0.0, 0.0, 1.0));
	return pow(max(dot(N, hv), 0.0), power);
}

float rim(vec3 N, float side, float width, float yy) {
	float edge = pow(clamp(1.0 - N.z, 0.0, 1.0), 1.4 / width);
	if (side != 0.0) {
		edge *= clamp(N.x * side * 1.6, 0.0, 1.0);
	}
	return edge * clamp(1.3 - yy * 0.9, 0.0, 1.0);
}

vec3 tone(vec3 c, float exposure, float contrast, float shoulder) {
	vec3 x = max(c * exposure, vec3(0.0));
	vec3 over = shoulder + (1.0 - shoulder) * (1.0 - exp(-(x - shoulder) / (1.0 - shoulder)));
	x = mix(x, over, step(vec3(shoulder), x));
	vec3 s = x * x * (3.0 - 2.0 * x);
	return clamp(x + (s - x) * contrast, 0.0, 1.0);
}

vec3 saturate_c(vec3 c, float k) {
	float l = lum(c);
	return clamp(vec3(l) + (c - vec3(l)) * k, 0.0, 1.0);
}

vec3 grad(vec3 top, vec3 bottom, float curve, float yy) {
	return mix(top, bottom, pow(clamp(yy, 0.0, 1.0), curve));
}

vec3 glow(vec2 q, vec2 c, float r, vec3 col, float amt) {
	float d = distance(q, c);
	float k = clamp(1.0 - d / r, 0.0, 1.0);
	return col * k * k * amt;
}

// Luzes desfocadas (bokeh) em posições fixas pela semente
vec3 bokeh(vec2 q, int n, vec3 c1, vec3 c2, float rmin, float rmax, float ymin, float ymax, float alpha, float salt, float ring) {
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 40; i++) {
		if (i >= n) {
			break;
		}
		float fi = float(i) + salt * 31.0;
		vec2 c = vec2(mix(-0.05, 1.05, h1(fi * 1.7 + 1.0)), mix(ymin, ymax, h1(fi * 2.3 + 2.0)));
		float rr = mix(rmin, rmax, h1(fi * 3.1 + 3.0));
		float d = distance(q, c) / rr;
		float m = clamp((1.0 - d) * 3.0, 0.0, 1.0) * (1.0 - ring + ring * clamp(d * 1.3, 0.0, 1.0));
		m *= alpha * mix(0.35, 1.0, h1(fi * 4.7 + 4.0));
		acc += m * (h1(fi * 5.9 + 5.0) > 0.5 ? c1 : c2);
	}
	return acc;
}

// Gotas riscando: linhas inclinadas em faixas, cada faixa com sua gota
float rain(vec2 q, float spacing, float len, float thick, float density, float salt) {
	vec2 dir = normalize(vec2(0.28, 1.0));
	vec2 perp = vec2(dir.y, -dir.x);
	float s = dot(q, perp) / spacing;
	float cell = floor(s);
	float f = fract(s) - 0.5;
	float along = dot(q, dir);
	float acc = 0.0;
	for (int k = 0; k < 3; k++) {
		float id = cell * 7.0 + float(k) * 131.0 + salt;
		if (h1(id) > density) {
			continue;
		}
		float off = h1(id + 0.5) * 1.6 - 0.3;
		float l = len * mix(0.4, 1.0, h1(id + 0.9));
		float t = (along - off) / l;
		float body = step(0.0, t) * step(t, 1.0) * sin(clamp(t, 0.0, 1.0) * 3.14159);
		float cx = (h1(id + 0.3) - 0.5) * 0.6;
		float w = clamp(1.0 - abs(f - cx) * spacing / thick, 0.0, 1.0);
		acc = max(acc, body * w * mix(0.4, 1.0, h1(id + 0.7)));
	}
	return acc;
}

vec3 light_wrap(vec3 fg, vec3 bg, float a, float ab, float k) {
	float e = clamp(a * clamp(1.0 - ab, 0.0, 1.0) * 2.2, 0.0, 1.0);
	return fg * (1.0 - k * e) + bg * k * e;
}

vec3 micro(vec3 c, vec2 q, float a, float amt) {
	float n = h2(floor(q * 400.0)) - 0.5 + (h2(floor(q * 180.0) + 17.0) - 0.5) * 0.6;
	float l = lum(c);
	float w = a * clamp(4.0 * l * (1.0 - l), 0.0, 1.0);
	return clamp(c * (1.0 + amt * 3.0 * n * w), 0.0, 1.0);
}

vec3 grain(vec3 c, vec2 px, float amt, float colored) {
	float l = lum(c);
	float w = 0.55 + 1.8 * l * (1.0 - l);
	float n = (h2(px) + h2(px + 13.7) - 1.0) * 1.7;
	vec3 o = c + vec3(n * amt * w);
	if (colored > 0.0) {
		o += (vec3(h2(px + 3.1), h2(px + 5.3), h2(px + 7.9)) - 0.5) * amt * colored * 2.0;
	}
	return clamp(o, 0.0, 1.0);
}

void fragment() {
	vec2 q = (UV - cut_rect.xy) / cut_rect.zw;
	float xx = q.x;
	float yy = q.y;
	vec2 cuv = UV - vec2(0.5, 0.45);
	cuv.x *= size_px.x / size_px.y;
	float vd = dot(cuv, cuv);
	vec2 px = floor(UV * size_px);

	vec4 base = cut_at(q);
	float a = base.a;
	vec3 c = base.rgb;
	if (a > 0.002) {
		// Nitidez leve (o desenho vetorial fica macio quando ampliado)
		vec3 bl = blur_c(q, 1.2 * U);
		c = clamp(c + 0.45 * (c - bl), 0.0, 1.0);
	}
	float ab = blur_a(q, 4.0 * U);
	vec3 o = vec3(0.0);

	if (mood == 0) {
		// Estúdio: luz macia de frente-esquerda, rebatedor, fundo cinza-azulado de ficha
		vec3 L = vec3(-0.45, -0.55, 0.75);
		vec3 N = normal_at(q, 5.0);
		vec3 fg = relight(c, N, L, 0.35, 0.45);
		fg += spec(N, L, 18.0) * step(0.25, lum(c)) * 0.06;
		fg = micro(saturate_c(fg, 0.9), q, a, 0.018);
		vec3 bg = grad(vec3(0.17, 0.19, 0.22), vec3(0.09, 0.10, 0.12), 0.8, yy) + glow(q, vec2(0.42, 0.32), 0.75, vec3(0.16, 0.17, 0.19), 1.0);
		bg *= 1.0 - blur_a(q - vec2(9.0, 7.0) * U, 12.0 * U) * 0.35;
		fg = light_wrap(fg, bg, a, ab, 0.12);
		o = mix(bg, fg, a);
		o = tone(o, 1.0, 0.18, 0.82);
		o = grain(o, px, 0.012, 0.0);
	} else if (mood == 1) {
		// Coletiva: flash de frente e parede de patrocinadores desfocada atrás
		vec3 L = vec3(0.05, -0.15, 1.0);
		vec3 N = normal_at(q, 3.0);
		vec3 fg = relight(c * 1.02 + 0.01, N, L, 0.2, 0.6);
		float l = lum(c);
		fg += spec(N, vec3(0.05, -0.2, 1.0), 30.0) * clamp((l - 0.35) * 2.5, 0.0, 1.0) * 0.1;
		fg = saturate_c(fg, 1.05) * vec3(1.03, 1.0, 0.97);
		fg = micro(fg, q, a, 0.016);
		vec3 bg = vec3(0.86, 0.87, 0.89);
		float cell = 0.25;
		vec2 g = floor(vec2((xx + 0.07) / cell, (yy + 0.03) / (cell * 0.62)));
		vec2 f = vec2(fract((xx + 0.07) / cell), fract((yy + 0.03) / (cell * 0.62))) - 0.5;
		bool alt = mod(g.x + g.y, 2.0) < 0.5;
		float soft = 0.2; // a parede fica desfocada atrás do jogador
		float logo1 = smoothstep(0.3 + soft, 0.3 - soft, abs(f.x)) * smoothstep(0.12 + soft, 0.12 - soft, abs(f.y));
		float er = length(f / vec2(0.6, 0.75));
		float logo2 = smoothstep(0.3 + soft * 0.6, 0.3 - soft * 0.6, er);
		float dot2 = smoothstep(0.15 + soft * 0.5, 0.15 - soft * 0.5, er);
		if (alt) {
			bg = mix(bg, club1.rgb, logo1 * 0.7);
		} else {
			bg = mix(bg, club2.rgb, logo2 * 0.7);
			bg = mix(bg, vec3(0.94), dot2 * 0.7);
		}
		bg *= 1.08 - 0.5 * distance(q, vec2(0.5, 0.42));
		bg *= 1.0 - blur_a(q - vec2(16.0, 9.0) * U, 3.0 * U) * 0.55;
		o = mix(bg, clamp(fg, 0.0, 1.0), a);
		o = tone(o, 1.0, 0.12, 0.82);
		o = grain(o, px, 0.018, 0.2);
	} else if (mood == 2) {
		// Túnel: luz fria de cima, corredor escuro com as lâmpadas fugindo para a saída clara
		vec3 L = vec3(0.0, -1.0, 0.6);
		vec3 N = normal_at(q, 1.5);
		vec3 fg = relight(c, N, L, 0.35, 0.35);
		fg *= clamp(1.1 - yy * 0.4, 0.6, 1.1);
		fg = fg * vec3(0.93, 1.0, 1.03) + vec3(-0.01, 0.005, 0.015);
		fg += spec(N, vec3(0.0, -1.0, 0.5), 24.0) * step(0.2, lum(c)) * vec3(0.75, 0.9, 1.0) * 0.12;
		fg += rim(N, 0.0, 0.8, yy) * vec3(0.55, 0.75, 0.9) * 0.35;
		fg = micro(fg, q, a, 0.018);
		vec3 bg = grad(vec3(0.05, 0.07, 0.08), vec3(0.03, 0.035, 0.04), 1.2, yy);
		vec2 vp = vec2(0.5, 0.4);
		for (int k = 0; k < 2; k++) {
			float side = k == 0 ? -1.0 : 1.0;
			vec2 p0 = vec2(0.5 + side * 0.75, -0.08);
			vec2 dv = vp - p0;
			float t = clamp(dot(q - p0, dv) / dot(dv, dv), 0.0, 1.0);
			float d = distance(q, p0 + t * dv);
			float thick = 0.022 * (1.0 - t) + 0.006;
			float dash = smoothstep(-0.45, 0.05, sin(t * 60.0 * (1.0 + 0.6 * t)));
			float m = clamp(1.0 - d / thick, 0.0, 1.0) * dash * (1.0 - 0.6 * t);
			float bloom = clamp(1.0 - d / (thick * 4.0), 0.0, 1.0) * (1.0 - t) * 0.25;
			bg += (m * 0.8 + bloom) * vec3(0.8, 0.95, 1.0);
		}
		bg += glow(q, vp, 0.5, vec3(0.55, 0.65, 0.7), 1.3);
		fg = light_wrap(fg, bg, a, ab, 0.2);
		o = mix(bg, clamp(fg, 0.0, 1.0), a);
		o = tone(o, 1.0, 0.25, 0.82);
		o *= clamp(1.0 - 0.35 * vd * 2.2, 0.0, 1.0);
		o = grain(o, px, 0.028, 0.25);
	} else if (mood == 3) {
		// Filme 35 mm: dia nublado, pretos levantados, pele quente, verde contido, halo e grão
		vec3 L = vec3(-0.3, -0.6, 0.8);
		vec3 N = normal_at(q, 5.0);
		// Aberração da lente: vermelho um pouco maior, azul um pouco menor
		vec2 cq = vec2(0.5);
		float ar = cut_at(cq + (q - cq) / (1.0 + 1.2 * U)).r;
		float abl = cut_at(cq + (q - cq) / (1.0 - 1.2 * U)).b;
		vec3 cc = vec3(mix(c.r, ar, 0.7), c.g, mix(c.b, abl, 0.7));
		vec3 fg = relight(cc, N, L, 0.25, 0.55);
		fg = micro(fg, q, a, 0.016);
		vec3 bg = grad(vec3(0.62, 0.68, 0.62), vec3(0.28, 0.42, 0.25), 1.6, yy) + glow(q, vec2(0.2, 0.15), 0.6, vec3(0.25, 0.22, 0.15), 1.0);
		bg += bokeh(q, 30, vec3(0.9, 0.95, 0.85), vec3(0.4, 0.55, 0.32), 0.03, 0.09, 0.0, 0.55, 0.3, 21.0, 0.0);
		fg = light_wrap(fg, bg, a, ab, 0.18);
		o = mix(clamp(bg, 0.0, 1.0), clamp(fg, 0.0, 1.0), a);
		o = tone(o, 1.0, 0.1, 0.82);
		o = o * 0.92 + 0.045;
		o *= vec3(1.04, 1.0, 0.92);
		float gg = o.g - (o.r + o.b) * 0.5;
		o.g -= clamp(gg, 0.0, 1.0) * 0.25;
		o = saturate_c(o, 0.88);
		vec3 hal = clamp(blur_c(q, 5.0 * U) - 0.72, 0.0, 1.0) * vec3(1.0, 0.42, 0.22) * 0.9 * ab;
		o = clamp(o + hal, 0.0, 1.0);
		o *= clamp(1.0 - 0.28 * vd * 2.2, 0.0, 1.0);
		o = grain(o, px, 0.04, 0.35);
	} else if (mood == 4) {
		// Noite de chuva: refletores atrás, pele e cabelo molhados, cor fria e gotas
		vec3 L = vec3(0.2, -0.5, 0.8);
		vec3 N = normal_at(q, 6.0);
		vec3 fg = relight(c, N, L, 0.4, 0.3) * 0.82 * vec3(0.9, 0.97, 1.08);
		float l = lum(c);
		float wet = clamp((l - lum(blur_c(q, 4.0 * U))) * 3.0, 0.0, 1.0) * clamp((l - 0.3) * 3.0, 0.0, 1.0);
		fg += (wet * 0.16 + spec(N, vec3(0.3, -0.6, 0.7), 40.0) * clamp((l - 0.2) * 3.0, 0.0, 1.0) * 0.25) * vec3(0.85, 0.92, 1.0);
		fg += rim(N, 0.0, 1.0, yy) * vec3(0.8, 0.9, 1.0) * 0.4;
		fg = micro(fg, q, a, 0.016);
		vec3 bg = grad(vec3(0.06, 0.08, 0.12), vec3(0.02, 0.03, 0.05), 0.9, yy);
		bg += bokeh(q, 10, vec3(1.0, 0.98, 0.92), vec3(0.8, 0.9, 1.0), 0.04, 0.08, 0.0, 0.25, 0.9, 31.0, 0.3);
		bg += glow(q, vec2(0.5, -0.05), 0.7, vec3(0.5, 0.62, 0.8), 0.5);
		bg += rain(q, 0.018, 0.09, 0.0045, 0.55, 41.0) * vec3(0.7, 0.8, 0.95) * (0.4 + 0.8 * (1.0 - clamp(yy, 0.0, 1.0))) * 0.9;
		o = mix(bg, clamp(fg, 0.0, 1.0), a);
		o += rain(q + vec2(0.31, 0.17), 0.05, 0.1, 0.007, 0.35, 43.0) * vec3(0.75, 0.85, 1.0) * 0.5;
		o += clamp(o - 0.6, 0.0, 1.0) * 0.5;
		o = tone(o, 1.0, 0.25, 0.82);
		o *= clamp(1.0 - 0.45 * vd * 2.2, 0.0, 1.0);
		o = grain(o, px, 0.035, 0.3);
	} else {
		// Treino ao sol: sol duro de cima à direita, sombra marcada, céu e gramado
		vec3 Ls = vec3(0.55, -0.75, 0.45);
		vec3 N = normal_at(q, 0.5);
		float sh = dot(N, normalize(Ls));
		float hard = clamp((sh + 0.1) / 0.45, 0.0, 1.0);
		hard = hard * hard * (3.0 - 2.0 * hard);
		float k = 0.66 + 0.5 * hard;
		float mean = 0.66 + 0.5 * 0.55;
		vec3 fg = c * (1.0 + 0.6 * (k / mean - 1.0));
		fg += (1.0 - hard) * vec3(-0.02, 0.0, 0.035);
		fg *= 1.0 + hard * vec3(0.04, 0.02, -0.03);
		fg += spec(N, Ls, 22.0) * step(0.25, lum(c)) * 0.12;
		fg = micro(saturate_c(fg, 1.12), q, a, 0.016);
		vec3 bg = grad(vec3(0.33, 0.56, 0.86), vec3(0.62, 0.76, 0.9), 1.0, yy);
		float grass = smoothstep(0.655, 0.67, yy);
		bg = mix(bg, vec3(0.24, 0.5, 0.2) * (1.1 - (yy - 0.66)), grass);
		bg = mix(bg, vec3(0.85, 0.9, 0.85), smoothstep(0.012, 0.003, abs(yy - 0.8)));
		bg += bokeh(q, 8, vec3(0.95), vec3(0.9, 0.85, 0.3), 0.02, 0.05, 0.58, 0.68, 0.5, 51.0, 0.0);
		fg = light_wrap(fg, bg, a, ab, 0.12);
		o = mix(bg, clamp(fg, 0.0, 1.2), a);
		o = tone(o, 1.0, 0.22, 0.82);
		o = grain(o, px, 0.014, 0.0);
	}
	// Cantos arredondados (raio sm do DESIGN.md)
	vec2 pp = UV * size_px;
	vec2 dq = max(vec2(corner_px) - pp, vec2(0.0)) + max(pp - (size_px - vec2(corner_px)), vec2(0.0));
	float inside = clamp(corner_px + 0.5 - length(dq), 0.0, 1.0);
	COLOR = cutout_mode == 1 ? vec4(o, a) : vec4(o, inside);
}
