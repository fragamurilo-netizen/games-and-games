shader_type canvas_item;
render_mode blend_mix, unshaded;

// Calota do cabelo pixel a pixel (PortraitView → camada do cabelo).
//
// UV da faixa: t = posição ao longo da calota (0 costeleta esquerda … 1 costeleta direita),
// w = da raiz (linha do cabelo, 0) até a silhueta (1) e um pouco além (pontas que quebram o
// contorno). O alfa do vértice traz os degradês do corte (laterais raspadas, coroa rala).
//
// Liso/ondulado: fios finos agrupados em mechas, faixa de brilho anisotrópica (quebrada pelas
// mechas), raiz mais escura, pontas afinando na silhueta — nada de capacete liso.
// Cacheado: cachos com volume (célula iluminada do lado da luz). Crespo: grão fosco e borda
// felpuda. Raspado: couro aparecendo entre pelos curtos. Trançado/waves/dreads: base com
// variação; o desenho estruturado vem por cima.

uniform vec4 hair_col = vec4(0.1, 0.07, 0.05, 1.0);
uniform vec4 hair_p = vec4(0.4, 0.0, 0.0, 0.5);      // brilho, textura (0 liso 1 ondulado 2 cacheado 3 crespo 4 raspado 5 estruturado), fluxo, repartição
uniform vec4 hair_p2 = vec4(0.0);                    // pontas claras, luzes, grisalho, semente
uniform vec4 hair_p3 = vec4(0.0);                    // volume atrás (borda some), escuro (0/1), -, -
uniform vec4 head = vec4(0.0, 0.0, 1.0, 1.0);        // centro da cabeça (px), fw, fh
uniform vec4 tips_col = vec4(0.89, 0.79, 0.55, 1.0);
uniform vec4 streak_col = vec4(0.85, 0.7, 0.42, 1.0);
uniform vec4 scalp_col = vec4(0.6, 0.45, 0.35, 1.0);
uniform vec3 key_dir = vec3(-0.35, -0.65, 1.0);

varying vec2 pos;

float g1(float x, float s) {
	return exp(-(x * x) / (s * s));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 w = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, w.x), mix(c, d, w.x), w.y);
}

// Célula mais próxima (Worley): distância e deslocamento até o centro do cacho
vec3 worley(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 8.0;
	vec2 off = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash22(i + g) * 0.8 + 0.1;
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < best) {
				best = d;
				off = r;
			}
		}
	}
	return vec3(sqrt(best), off);
}

void vertex() {
	pos = VERTEX;
}

void fragment() {
	float t = UV.x;
	float w = UV.y;
	vec2 q = (pos - head.xy) / head.zw;
	float seed = hair_p2.w;
	int tex = int(hair_p.y + 0.5);
	int flow = int(hair_p.z + 0.5);
	float part = hair_p.w;
	vec3 hair = hair_col.rgb;
	bool dark = hair_p3.y > 0.5;

	// Volume da cabeça: luz de cima à esquerda, raiz e borda mais escuras
	vec2 dn = normalize(vec2(q.x, q.y * 0.9) + vec2(1e-4, 0.0));
	vec2 L = normalize(key_dir.xy);
	float lam = dot(dn, L);
	float lum = 0.62 + 0.38 * lam;
	lum *= 0.76 + 0.24 * smoothstep(0.0, 0.45, w);
	lum *= 1.0 - 0.16 * smoothstep(0.85, 1.05, w) * (1.0 - hair_p3.x);
	// Detalhe fino só quando cabe na tela
	float px = max(abs(dFdx(q.x)) + abs(dFdy(q.x)), 1e-5);
	float fine = 1.0 - smoothstep(0.01, 0.03, px);

	vec3 col;
	float a = COLOR.a;
	float edge_n = 0.5;
	// Peças da frente (franja, mechas, tufos): sem fade de raiz nem de silhueta (o alfa do vértice
	// já faz as pontas); o verde traz o brilho da fileira
	bool piece = COLOR.r < 0.5;
	if (piece) {
		lum = (0.62 + 0.38 * lam) * (0.9 + 0.1 * w) * COLOR.g;
	}

	if (tex <= 1) {
		// Liso / ondulado: fios agrupados em mechas seguindo o fluxo do penteado
		float tt = t;
		if (flow == 1) {
			tt += (t - part) * 0.08 * w;
		} else if (flow == 3) {
			tt += (t - 0.5) * 0.12 * w;
		}
		if (tex == 1) {
			tt += 0.006 * sin(w * 7.0 + t * 23.0);
		}
		float n1 = vnoise(vec2(tt * 260.0, w * 5.0) + vec2(seed, 0.0));
		float n2 = vnoise(vec2(tt * 95.0, w * 2.4) + vec2(seed * 1.3, 4.0));
		float clump = vnoise(vec2(tt * 24.0, w * 1.3) + vec2(seed * 0.7, 9.0));
		float strand = mix(0.5, n1 * 0.4 + n2 * 0.35 + clump * 0.25, mix(0.55, 1.0, fine));
		col = hair * lum * (0.68 + 0.55 * strand);
		// Faixa de brilho anisotrópica: atravessa os fios, desloca com as mechas e se quebra
		float ang = atan(q.y, q.x);
		float band = g1(ang + 1.95, 0.6) * g1(w - 0.58 - (clump - 0.5) * 0.14, 0.15);
		float sheen = band * hair_p.x * (0.35 + 1.1 * n1 * n2);
		vec3 spec_c = dark ? mix(hair * 1.8 + 0.08, vec3(0.72, 0.76, 0.86), 0.35) : mix(hair * 1.45 + 0.1, vec3(1.0, 0.95, 0.86), 0.2);
		col = mix(col, spec_c, clamp(sheen, 0.0, 0.62));
		// Luzes (mechas claras) e fios brancos
		float streak = smoothstep(0.72, 0.9, vnoise(vec2(tt * 16.0, 0.5) + vec2(seed * 2.1, 1.0)));
		col = mix(col, streak_col.rgb * lum * (0.8 + 0.4 * n1), hair_p2.y * streak * 0.8);
		col = mix(col, vec3(0.86, 0.86, 0.84) * lum, hair_p2.z * smoothstep(0.62, 0.92, n1) * 0.75);
		edge_n = n1 * 0.6 + n2 * 0.4;
		// Raiz: o cabelo nasce ralo, fio a fio (linha do cabelo irregular)
		if (!piece) {
			a *= mix(1.0, smoothstep(0.15, 0.85, n1 * 0.7 + n2 * 0.3), 1.0 - smoothstep(0.02, 0.22, w));
		}
	} else if (tex == 2) {
		// Cacheado: cachos com volume
		vec3 c = worley(q * 13.0 + vec2(seed, seed * 0.7));
		float ball = 1.0 - smoothstep(0.1, 0.62, c.x);
		float lit_c = clamp(dot(normalize(-c.yz + vec2(1e-4, 0.0)), L), -1.0, 1.0);
		float n1 = vnoise(q * 90.0 + vec2(seed, 3.0));
		col = hair * lum * (0.55 + 0.35 * ball + 0.22 * lit_c * ball + 0.12 * (n1 - 0.5) * fine);
		col = mix(col, (dark ? vec3(0.62, 0.64, 0.7) : hair * 1.6 + 0.08) * lum, hair_p.x * 0.5 * smoothstep(0.55, 1.0, lit_c) * ball);
		col = mix(col, streak_col.rgb * lum, hair_p2.y * 0.6 * smoothstep(0.7, 0.9, vnoise(q * 6.0 + vec2(seed, 5.0))) * ball);
		col = mix(col, vec3(0.86, 0.86, 0.84) * lum, hair_p2.z * smoothstep(0.6, 0.9, n1) * 0.7);
		edge_n = ball;
	} else if (tex == 3) {
		// Crespo: grão fosco, micro-cachos
		float n1 = vnoise(q * 110.0 + vec2(seed, 2.0));
		float n2 = vnoise(q * 38.0 + vec2(7.0, seed));
		float grain = mix(0.5, n1 * 0.6 + n2 * 0.4, mix(0.5, 1.0, fine));
		col = hair * lum * (0.7 + 0.5 * grain);
		col = mix(col, (dark ? vec3(0.55, 0.57, 0.62) : hair * 1.5) * lum, hair_p.x * 0.35 * smoothstep(0.65, 0.95, n1) * smoothstep(0.2, 0.8, lam));
		col = mix(col, tips_col.rgb * lum, hair_p2.y * 0.5 * smoothstep(0.75, 0.9, n2));
		col = mix(col, vec3(0.86, 0.86, 0.84) * lum, hair_p2.z * smoothstep(0.6, 0.9, n1) * 0.7);
		edge_n = n1;
	} else if (tex == 4) {
		// Raspado / máquina: couro aparecendo entre os pelos curtos
		float n1 = vnoise(q * 140.0 + vec2(seed, 1.0));
		float n2 = vnoise(q * 45.0 + vec2(2.0, seed));
		float dens = clamp(0.55 + 0.35 * (n2 - 0.5), 0.0, 1.0);
		float hairs = mix(dens, step(1.0 - dens, n1), fine);
		vec3 scalp = scalp_col.rgb * (0.7 + 0.3 * lum);
		col = mix(scalp, hair * lum * 0.9, clamp(hairs, 0.0, 1.0));
		edge_n = 0.5;
	} else {
		// Trançado, waves, dreads: base com variação suave (o desenho vem por cima)
		float n2 = vnoise(q * 30.0 + vec2(seed, 6.0));
		col = hair * lum * (0.85 + 0.2 * n2);
		edge_n = 0.5;
	}

	// Pontas claras (frosted/nevou)
	col = mix(col, tips_col.rgb * mix(1.0, lum, 0.5), hair_p2.x * smoothstep(0.35, 0.95, w) * 0.85);
	// Silhueta: as pontas quebram o contorno (fios e cachos passam um pouco da linha)
	float edge = 1.0 - smoothstep(0.93 + 0.1 * (edge_n - 0.5), 1.05 + 0.08 * edge_n, w);
	if (tex >= 4) {
		edge = 1.0 - smoothstep(0.97, 1.02, w);
	}
	if (piece) {
		edge = 1.0;
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), a * edge);
}
