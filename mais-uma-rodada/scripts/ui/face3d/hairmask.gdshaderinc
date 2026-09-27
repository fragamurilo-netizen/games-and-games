// Funções compartilhadas (pele, camadas de cabelo e barba). p = posição na pose base em decímetros
// (boca y~7.4, olhos 8.03, testa até ~8.75, topo 9.12, orelha |x|~0.78 y~7.58 z~0.45).
// As mesmas contas existem em Face3DHair (GDScript) para decidir onde nascem os fios.

uniform float hairline = 8.72;
uniform float temples = 0.0;
uniform float crown = 0.0;
uniform float widow = 0.0;
uniform float fade_h = 0.0;     // altura do degradê (0 = sem); dm
uniform float fade_sharp = 0.0; // 1 = undercut (corte seco)
uniform float hawk_w = 0.0;     // moicano: meia largura da faixa (dm)
uniform float rows = 0.0;       // nagô: 1 retas, 2 zigue-zague
uniform float waves = 0.0;      // waves (ondas concêntricas)
uniform float design = 0.0;     // risco/desenho raspado
uniform float part_x = 0.0;     // risco lateral (dm; 0 = sem)

float hm_band(float x, float a, float b, float s) {
	return smoothstep(a - s, a + s, x) * (1.0 - smoothstep(b - s, b + s, x));
}

float scalp_mask(vec3 p) {
	float ax = abs(p.x);
	float hl_front = hairline + temples * smoothstep(0.15, 0.5, ax) * 0.4 - widow * 0.06 * (1.0 - smoothstep(0.0, 0.08, ax));
	float t = smoothstep(-0.7, 1.35, p.z);
	float hl = mix(7.05, hl_front, t);
	hl = mix(hl, 7.95, smoothstep(0.55, 0.72, ax) * hm_band(p.z, -0.2, 1.05, 0.12));
	float m = smoothstep(hl - 0.025, hl + 0.04, p.y);
	float ear = length(vec2((p.y - 7.58) / 0.44, (p.z - 0.45) / 0.37));
	m *= mix(1.0, smoothstep(0.92, 1.08, ear), smoothstep(0.64, 0.72, ax));
	m = max(m, smoothstep(0.62, 0.68, ax) * hm_band(p.z, 0.72, 0.98, 0.03) * hm_band(p.y, 7.62, 8.1, 0.03));
	float cr = length(vec2(p.x, p.z - 0.05) / 0.5) + (9.12 - p.y) * 0.9;
	m *= 1.0 - crown * (1.0 - smoothstep(0.3, 0.85, cr));
	return clamp(m, 0.0, 1.0);
}

// Degradê: 1 no alto, cai até 0 nas laterais/nuca abaixo de fade_h
float fade_mask(vec3 p) {
	if (fade_h <= 0.0) {
		return 1.0;
	}
	float ax = abs(p.x);
	float sides = clamp(smoothstep(0.38, 0.62, ax) + (1.0 - smoothstep(-0.45, 0.15, p.z)), 0.0, 1.0);
	float s = mix(0.45, 0.02, fade_sharp);
	float k = smoothstep(fade_h - s, fade_h + s * 0.4, p.y);
	return mix(1.0, k, sides);
}

// Padrões raspados (moicano, nagô, risco, desenho)
float pattern_mask(vec3 p) {
	float m = 1.0;
	if (hawk_w > 0.0) {
		m *= 1.0 - smoothstep(hawk_w - 0.03, hawk_w + 0.03, abs(p.x));
	}
	if (rows > 0.0) {
		float x = p.x + (rows > 1.5 ? sin(p.z * 9.0) * 0.08 : 0.0);
		m *= smoothstep(0.08, 0.35, abs(sin(x * 15.0)));
	}
	if (part_x != 0.0 && design > 0.0) {
		m *= smoothstep(0.008, 0.02, abs(p.x - part_x)) + (1.0 - smoothstep(0.6, 1.0, p.z)) * 0.0 + step(p.z, -0.2);
	}
	if (design > 1.5) {
		float zz = abs(p.x) - 0.5 - 0.04 * sin(p.z * 18.0);
		m *= smoothstep(0.006, 0.018, abs(zz)) + (1.0 - hm_band(p.y, 7.9, 8.4, 0.02));
	}
	return clamp(m, 0.0, 1.0);
}

// Barba (partes do FaceGen.BEARD_PARTS)
uniform float b_ch = 0.0;
uniform float b_sd = 0.0;
uniform float b_jw = 0.0;
uniform float b_cn = 0.0;
uniform float b_mu = 0.0;
uniform float b_so = 0.0;
uniform float b_nk = 0.0;
uniform float b_sh = 0.0;
uniform float b_cnw = 1.0;

float beard_mask(vec3 p) {
	float ax = abs(p.x);
	float soft = mix(0.06, 0.018, b_sh);
	float front = smoothstep(-0.1, 0.35, p.z);
	float lip = length(vec2(p.x / 0.25, (p.y - 7.39) / 0.085));
	float nolip = clamp(smoothstep(0.95, 1.2, lip) + (1.0 - smoothstep(1.2, 1.35, p.z)), 0.0, 1.0);
	float d = 0.0;
	if (b_ch > 0.0) {
		float top = mix(7.52, 8.0 - b_ch * 1.1, smoothstep(0.22, 0.62, ax));
		float c = (1.0 - smoothstep(top - soft, top + soft, p.y)) * smoothstep(6.95, 7.1, p.y + (1.0 - smoothstep(0.3, 0.7, ax)) * 0.3);
		c *= smoothstep(0.1, 0.45, p.z) * (1.0 - smoothstep(0.7, 0.8, ax) * (1.0 - smoothstep(0.55, 0.9, p.z)));
		d = max(d, c);
	}
	if (b_sd > 0.0) {
		d = max(d, b_sd * smoothstep(0.58, 0.66, ax) * hm_band(p.z, 0.62, 1.05, 0.05) * hm_band(p.y, 7.35, 8.05, 0.04));
	}
	if (b_jw > 0.0) {
		float jaw_y = mix(6.95, 7.35, smoothstep(0.15, 0.7, ax));
		float jb = hm_band(p.y, jaw_y - 0.18, jaw_y + 0.16, soft) * smoothstep(0.0, 0.3, p.z);
		if (b_jw < 0.8) {
			jb *= 1.0 - smoothstep(b_jw * 0.7 + 0.05, b_jw * 0.7 + 0.15, ax);
		}
		d = max(d, jb);
	}
	if (b_cn > 0.0) {
		float w = (0.12 + b_cn * 0.2) * b_cnw;
		d = max(d, (1.0 - smoothstep(w - soft, w + soft, ax)) * hm_band(p.y, 6.78, 7.3, soft) * smoothstep(0.7, 1.0, p.z));
	}
	if (b_mu > 0.0) {
		bool thin = b_mu > 1.5 && b_mu < 2.5;
		float th = thin ? 0.035 : 0.075;
		float mu = hm_band(p.y, 7.46, 7.46 + th, 0.015) * (1.0 - smoothstep(0.25, 0.3, ax)) * smoothstep(1.3, 1.45, p.z);
		mu = max(mu, hm_band(ax, 0.19, 0.29, 0.02) * hm_band(p.y, 7.34, 7.5, 0.02) * smoothstep(1.2, 1.35, p.z) * (thin ? 0.0 : 1.0));
		if (b_mu > 2.5) {
			mu = max(mu, hm_band(ax, 0.2, 0.3, 0.02) * hm_band(p.y, 6.95, 7.5, 0.02) * smoothstep(1.0, 1.2, p.z));
		}
		d = max(d, mu);
	}
	if (b_so > 0.0) {
		d = max(d, b_so * (1.0 - smoothstep(0.06, 0.09, ax)) * hm_band(p.y, 7.12, 7.29, 0.02) * smoothstep(1.3, 1.45, p.z));
	}
	if (b_nk > 0.0) {
		d = max(d, b_nk * hm_band(p.y, 6.55, 6.95, 0.08) * smoothstep(0.35, 0.8, p.z) * (1.0 - smoothstep(0.55, 0.7, ax)));
	}
	return d * nolip * front;
}
