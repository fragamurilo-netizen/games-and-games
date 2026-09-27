shader_type canvas_item;
render_mode blend_mix, unshaded;

// Pele do retrato calculada pixel a pixel (PortraitView → camada da pele).
//
// As coordenadas do rosto chegam em UV: u = x / fw a partir do centro da cabeça (±1 nas maçãs),
// v = y / fh (0 na linha média da cabeça, ~1 no queixo, -1,02 no alto do crânio). Um relevo
// analítico (calota + arco das sobrancelhas, órbitas, nariz em partes, maçãs, filtro, boca e
// queixo) dá a normal de cada pixel; a luz é de estúdio: principal grande e macia no alto à
// esquerda, rebatedor fraco, ambiente com oclusão, espalhamento sob a pele na passagem para a
// sombra e brilho que depende do relevo e da oleosidade.
//
// O nariz não tem nenhuma faixa escura: narinas são duas regiões pequenas e separadas, a sombra
// projetada é pequena, macia, vai para o lado oposto à luz e é limitada (nose_shadow_max), e a
// pele logo abaixo da columela continua iluminada. Sombras usam a cor da própria pele, nunca preto.

// Geometria (FaceRenderer / PortraitView._skin_params)
uniform vec4 feat = vec4(0.0, 0.43, 0.42, 0.62);    // E (olhos), X (meia distância entre olhos), N (base do nariz), M (boca)
uniform vec4 feat2 = vec4(0.3, 0.07, 0.4, 0.0);     // NW (largura do nariz), BW (dorso), MW (meia boca), ND (desvio do nariz)
uniform vec4 shape = vec4(1.0, 0.94, 1.0, 0.64);    // cheek_w, forehead, vb (fundo do queixo), fw/fh
uniform vec4 mass = vec4(1.0, 0.2, 0.0, 0.0);       // cheekbone, fat, heavy, thin
uniform vec4 relief = vec4(0.8, 0.9, 1.0, 1.0);     // deep (olhos fundos), ridge (arco), bridge (dorso), nose_tip
uniform vec4 relief2 = vec4(0.0, 0.03, 0.05, 0.06); // aquiline, nasolabial, bochecha funda, lip_l
uniform vec4 relief3 = vec4(0.0);                   // chin_cleft, aging, eyebags, temple
uniform vec4 relief4 = vec4(0.0);                   // dark_circles, sorriso nas maçãs, jowl, skin_clear
uniform vec4 nose = vec4(1.0, 0.0, 0.0, 1.0);       // narina, nariz arrebitado, ponta caída, asas
uniform vec4 lips = vec4(0.04, 0.06, 0.6, 0.0);     // lip_u, lip_l, arco do cupido, sorriso
uniform vec4 eyes = vec4(0.23, 0.1, 0.0, 0.0);      // largura e altura do olho, inclinação, pálpebra caída

// Cor e pele de cada pessoa (FaceColorSystem)
uniform vec4 skin_col = vec4(0.8, 0.6, 0.5, 1.0);
uniform vec4 skin_p = vec4(0.5, 0.5, 0.5, 0.5);     // rubor, força das zonas de tom, oleosidade, poros
uniform vec4 skin_p2 = vec4(0.8, 0.0, 0.0, 0.0);    // brilho, sardas, semente da textura (x, y)
uniform vec4 shadow_col = vec4(0.3, 0.3, 0.35, 1.0); // barba feita vista por baixo da pele
uniform vec4 beard = vec4(0.0);                     // força da barba feita, linha das bochechas, pelo curto aparente, semente
uniform sampler2D beard_mask : filter_linear, repeat_disable; // densidade da barba (alfa) em coordenadas do rosto
uniform vec4 beard_rect = vec4(-1.4, -0.42, 2.8, 1.6);        // u0, v0, largura, altura da máscara
uniform vec4 beard2 = vec4(0.0);                    // usar máscara, cobertura, contraste dos pelos, -
uniform vec4 beard_col = vec4(0.12, 0.09, 0.07, 1.0);
uniform float hl[9];                                 // linha do cabelo (v) em u = -1, -0,75 … 1
uniform float hair_k = 0.0;                          // sombra do cabelo na testa (0 careca … 0,2 franja)
uniform vec4 bl[5];                                  // manchas de tom: u, v, raio, intensidade
uniform float rtab[128];                             // raio do contorno do rosto por ângulo (centro em u = v = 0)

// Luz (FaceLighting)
uniform vec3 key_dir = vec3(-0.35, -0.65, 1.0);
uniform vec3 fill_dir = vec3(0.45, -0.15, 1.0);
uniform vec4 light_k = vec4(0.25, 0.72, 0.1, 0.3);  // ambiente, principal, rebatedor, "wrap" (maciez)
uniform vec4 light_k2 = vec4(0.11, 0.1, 1.0, 0.12); // sombra máx. do nariz, contraluz, contraste, sombra da borda/mandíbula

float g1(float x, float s) {
	return exp(-(x * x) / (s * s));
}

float g2(float x, float y, float sx, float sy) {
	return exp(-(x * x) / (sx * sx) - (y * y) / (sy * sy));
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
	return length(pa - ba * h);
}

// Hash sem seno (estável em GPU de celular)
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
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

// Distância normalizada ao contorno (1 exatamente na silhueta desenhada): raio do ponto dividido
// pelo raio do contorno no mesmo ângulo (tabela montada no CPU a partir do polígono do rosto).
// Assim o relevo termina na borda de verdade — antes ele "acabava" um pouco antes da silhueta e
// deixava uma faixa clara e chapada contornando a mandíbula.
float th_s(float u, float v) {
	float a = mod(atan(v, u) + TAU, TAU);
	float x = a / TAU * 128.0;
	int i0 = int(floor(x)) % 128;
	int i1 = (i0 + 1) % 128;
	float r = mix(rtab[i0], rtab[i1], fract(x));
	return length(vec2(u, v)) / max(r, 0.001);
}

// Relevo do rosto em unidades da meia largura (0 na borda, ~0,9 no meio)
float face_h(vec2 p) {
	float u = p.x;
	float v = p.y;
	float eyv = feat.x;
	float eyx = feat.y;
	float nsv = feat.z;
	float mtv = feat.w;
	float nsw = feat2.x;
	float brw = feat2.y;
	float mtw = feat2.z;
	// Sem limitar em 1: além da borda (franja antisserrilhada) o relevo continua a inclinação, em
	// vez de ficar plano e virado para a câmera (isso deixava um fio claro em volta do rosto)
	float th = th_s(u, v);
	float h = 0.85 * (1.0 - pow(th, 2.4));
	float au = abs(u);
	float un = u - feat2.w * smoothstep(eyv - 0.05, nsv, v);
	// Arco das sobrancelhas, órbitas e o globo do olho dentro delas
	h += 0.05 * relief.y * g2(au - eyx, v - (eyv - 0.16), 0.3, 0.06);
	h -= 0.09 * relief.x * g2(au - eyx, v - eyv, 0.25, 0.1);
	h += 0.035 * g2(au - eyx, v - eyv, 0.13, 0.055);
	// Glabela entre as sobrancelhas
	h += 0.02 * relief.y * g2(u, v - (eyv - 0.14), 0.12, 0.07);
	// Nariz em partes: dorso que se projeta mais perto da ponta, ponta arredondada (lóbulo),
	// asas dos lados e o vão das narinas embaixo
	float along = smoothstep(eyv - 0.02, nsv, v);
	float nose_on = smoothstep(eyv - 0.1, eyv + 0.06, v) * (1.0 - smoothstep(nsv - 0.03, nsv + 0.02, v));
	float hump = relief2.x * 0.03 * g1(v - (eyv + nsv) * 0.5, 0.07);
	h += ((0.035 + 0.11 * along) * relief.z + hump) * g1(un, brw * 1.15 + 0.045 * along) * nose_on;
	float tip_v = nsv - 0.068 + nose.z * 0.018 - nose.y * 0.014;
	h += 0.062 * relief.w * g2(un, v - tip_v, nsw * 0.4, 0.052);
	h += 0.034 * nose.w * g2(abs(un) - nsw * 0.78, v - (nsv - 0.036), nsw * 0.27, 0.042);
	h -= 0.018 * g2(abs(un) - nsw * 0.37, v - (nsv - 0.002), nsw * 0.16, 0.016);
	// Maçãs e a parte funda logo abaixo delas
	float cheek_v = (eyv + nsv) * 0.5;
	h += 0.035 * mass.x * g2(au - 0.5, v - cheek_v + 0.03, 0.2, 0.1);
	h -= 0.03 * (1.0 - mass.y) * g2(au - 0.62, v - nsv - 0.1, 0.15, 0.12);
	// Filtro: duas colunas e o sulco no meio, da base do nariz ao lábio
	float lip_top = mtv - lips.x * 1.7;
	float band = smoothstep(nsv + 0.01, nsv + 0.05, v) * (1.0 - smoothstep(lip_top - 0.01, lip_top + 0.02, v));
	h += (0.009 * g1(au - 0.07, 0.03) - 0.006 * g1(u, 0.024)) * band;
	// Boca (o arco dos dentes empurra a região para frente), dobra sob o lábio e queixo
	h += 0.03 * g2(u / max(0.05, mtw * 1.4), (v - mtv) / 0.16, 1.0, 1.0);
	h -= 0.025 * g2(u, v - mtv - relief2.w * 2.0 - 0.07, 0.18, 0.03);
	h += 0.028 * g2(u, v - (shape.z - 0.1), 0.2, 0.09);
	// Borda da mandíbula: o osso marca a passagem do rosto para baixo do queixo
	h += 0.02 * g1(th - 0.9, 0.05) * smoothstep(0.35, 0.65, v);
	// Têmporas
	h -= (0.03 + 0.03 * relief3.w) * g2(au - 0.86, v + 0.3, 0.1, 0.18);
	return h;
}

// Altura da sombra projetada logo abaixo da ponta do nariz (ponta caída desce, arrebitada sobe)
float tip_shadow_v(float nsv) {
	return nsv + 0.012 + nose.z * 0.012 - nose.y * 0.01;
}

void fragment() {
	vec2 p = UV;
	if (p.x > -50.0) {
		float u = p.x;
		float v = p.y;
		float au = abs(u);
		float eyv = feat.x;
		float eyx = feat.y;
		float nsv = feat.z;
		float mtv = feat.w;
		float nsw = feat2.x;
		float brw = feat2.y;
		float mtw = feat2.z;
		float nsd = feat2.w;
		float un = u - nsd * smoothstep(eyv - 0.05, nsv, v);
		float cheek_v = (eyv + nsv) * 0.5;
		float th = th_s(u, v);

		// Normal do relevo (diferenças centrais)
		float e = 0.009;
		float dhu = (face_h(vec2(u + e, v)) - face_h(vec2(u - e, v))) / (2.0 * e);
		float dhv = (face_h(vec2(u, v + e)) - face_h(vec2(u, v - e))) / (2.0 * e);
		vec3 n = normalize(vec3(-dhu, -dhv * shape.w, 1.0));

		// Tamanho do pixel em unidades do rosto: detalhe fino só aparece quando cabe na tela
		float px = max(abs(dFdx(u)) + abs(dFdy(u)), 1e-5);
		float fine = 1.0 - smoothstep(0.008, 0.024, px);

		// ------------------------------------------------------------------
		// Cor de base da pele (albedo) com variação por região
		// ------------------------------------------------------------------
		vec3 base = skin_col.rgb;
		float zn = skin_p.y;
		float seed_x = skin_p2.z;
		float seed_y = skin_p2.w;
		// Testa mais amarelada
		float fore_m = 1.0 - smoothstep(eyv - 0.34, eyv - 0.12, v);
		base = mix(base, base * vec3(1.03, 1.0, 0.87), 0.24 * zn * fore_m);
		// Olheira levemente arroxeada
		float under_eye = g2(au - eyx, v - (eyv + 0.105), 0.15, 0.05);
		base = mix(base, base * vec3(0.9, 0.84, 0.93), clamp(0.28 * zn + 0.45 * relief4.x, 0.0, 0.6) * under_eye);
		// Região da barba um pouco mais fria
		float jaw_m = smoothstep(nsv - 0.02, nsv + 0.12, v) * (1.0 - g2(u / max(0.05, mtw * 1.1), (v - mtv) / 0.08, 1.0, 1.0));
		base = mix(base, base * vec3(0.95, 0.97, 1.0), 0.12 * zn * jaw_m);
		// Rubor: bochechas, ponta do nariz e queixo
		float blush = 0.55 * g2(au - 0.52, v - cheek_v - 0.1, 0.22, 0.13) + 0.45 * g2(un, v - (nsv - 0.06), nsw * 0.9, 0.07) + 0.2 * g2(u, v - 0.9, 0.2, 0.08);
		base = mix(base, base * vec3(1.1, 0.8, 0.78), clamp(blush * skin_p.x * (0.18 + 0.2 * zn), 0.0, 0.35));
		// Manchas de tom largas e mosqueado fino (pele bonita é mais uniforme)
		float clear_k = 1.0 - relief4.w * 0.65;
		for (int i = 0; i < 5; i++) {
			vec4 b = bl[i];
			base *= 1.0 + b.w * g2(u - b.x, v - b.y, max(b.z, 0.01), max(b.z, 0.01)) * clear_k;
		}
		float mott = vnoise(p * 6.5 + vec2(seed_x, seed_y)) * 0.6 + vnoise(p * 14.0 - vec2(seed_y, seed_x)) * 0.4;
		base *= 1.0 + (mott - 0.5) * 0.08 * (0.45 + zn) * clear_k;
		float redp = vnoise(p * 9.0 + vec2(seed_x * 0.7 + 11.0, 3.0 + seed_y));
		base = mix(base, base * vec3(1.04, 0.91, 0.9), smoothstep(0.66, 0.95, redp) * 0.12 * (0.35 + zn) * clear_k);
		// Sardas (nariz e maçãs)
		if (skin_p2.y > 0.0) {
			float fz = clamp(g2(au - 0.36, v - (nsv - 0.14), 0.34, 0.17) + g2(un, v - (nsv - 0.12), 0.18, 0.12), 0.0, 1.0);
			float fr = vnoise(p * 58.0 + vec2(seed_x * 3.0, 7.0 + seed_y));
			float spot = mix(smoothstep(0.76, 0.9, fr), 0.12, 1.0 - fine);
			base = mix(base, base * vec3(0.8, 0.64, 0.52), spot * fz * skin_p2.y * 0.55);
		}
		// Poros e grão fino (nariz e bochechas mais marcados)
		float pore_m = 0.45 + 0.55 * clamp(g2(un, v - (nsv - 0.1), 0.28, 0.2) + g2(au - 0.45, v - cheek_v - 0.05, 0.25, 0.18), 0.0, 1.0);
		float grain = vnoise(p * 36.0 + vec2(seed_y * 2.0, seed_x));
		float pore = vnoise(p * 74.0 - vec2(seed_x * 5.0, 1.0 + seed_y));
		base *= 1.0 + ((grain - 0.5) * 0.045 - smoothstep(0.68, 0.95, pore) * 0.07 * pore_m) * fine * (0.35 + 0.65 * skin_p.w) * clear_k;

		// Barba feita: sombra fria sob a pele com folículos (de longe vira um tom médio). A zona segue
		// onde o pelo nasce: linha da bochecha descendo da costeleta até o canto da boca, buço,
		// queixo e mandíbula — nunca as maçãs, nunca os lábios
		if (beard.x > 0.01 && v > nsv - 0.06) {
			float cheek_line = mix(mtv - 0.03, 0.12, smoothstep(0.28, 0.95, au));
			float dc = smoothstep(cheek_line - 0.14, cheek_line + 0.12, v);
			float must = smoothstep(nsv + 0.02, nsv + 0.08, v) * (1.0 - smoothstep(mtw * 0.95, mtw * 1.3, au));
			float dens = max(dc, must * 0.85);
			float le = length(vec2(u / mtw, (v - mtv) / (relief2.w * 2.2 + lips.x * 1.2 + 0.03)));
			dens *= smoothstep(0.9, 1.03, le);
			float fol = vnoise(p * 96.0 + vec2(beard.w, 17.0 + beard.w * 0.3));
			float stub = mix(0.55, smoothstep(0.42, 0.82, fol), fine);
			base = mix(base, shadow_col.rgb, clamp(dens * beard.x * (0.13 + 0.17 * stub) * (1.0 + beard.z), 0.0, 0.4));
		}

		// Barba pela máscara: pelos curtos nascendo na pele (de longe, um tom médio que acompanha a
		// densidade; de perto, folículos e fios curtos), iluminados junto com a pele
		if (beard2.x > 0.0) {
			vec2 bq = (p - beard_rect.xy) / beard_rect.zw;
			float dens = 0.0;
			if (bq.x > 0.0 && bq.x < 1.0 && bq.y > 0.0 && bq.y < 1.0) {
				dens = texture(beard_mask, bq).a;
			}
			if (dens > 0.001) {
				float f1 = vnoise(p * vec2(120.0, 70.0) + vec2(beard.w, 3.0));
				float f2 = vnoise(p * 58.0 + vec2(7.0, beard.w));
				float hairs = mix(0.5, smoothstep(0.3, 0.8, f1 * 0.65 + f2 * 0.35), fine);
				float cover = clamp(dens * beard2.y * mix(1.0, 0.45 + 0.9 * hairs, beard2.z), 0.0, 0.93);
				// Pelo curto e claro (loiro, ruivo claro, grisalho) quase não aparece na pele e nunca a
				// clareia: a cobertura cai conforme o pelo se aproxima do tom da pele
				vec3 bc = min(beard_col.rgb * mix(1.0, 0.7 + 0.5 * f2, fine), base * 0.92);
				float lb = dot(beard_col.rgb, vec3(0.3, 0.59, 0.11));
				float ls = dot(base, vec3(0.3, 0.59, 0.11));
				cover *= mix(1.0, 0.3, smoothstep(0.45, 0.85, lb / max(ls, 0.01)));
				base = mix(base, bc, cover);
			}
		}

		// ------------------------------------------------------------------
		// Luz
		// ------------------------------------------------------------------
		vec3 L = normalize(key_dir);
		vec3 F = normalize(fill_dir);
		float wrap = light_k.w;
		float ndl = dot(n, L);
		float diff = clamp((ndl + wrap) / (1.0 + wrap), 0.0, 1.0);
		diff = mix(diff, diff * diff * (3.0 - 2.0 * diff), 0.35);
		float fillv = max(dot(n, F), 0.0);

		float ao = 1.0;   // oclusão (ambiente e, em parte, a luz direta)
		float sh = 1.0;   // sombra projetada na luz principal
		// Borda: o rosto vira para longe da câmera
		ao *= 1.0 - light_k2.w * smoothstep(0.8, 1.0, th);
		// Órbitas (olhos fundos escurecem mais) e canto interno do olho junto ao nariz
		float ey = v - eyv + 0.01;
		ao *= 1.0 - 0.17 * relief.x * (g2(u - eyx, ey, 0.26, 0.105) + g2(u + eyx, ey, 0.26, 0.105));
		ao *= 1.0 - 0.1 * g2(au - 0.2, v - eyv, 0.08, 0.08);
		// O arco da sobrancelha faz sombra na pálpebra de cima
		sh *= 1.0 - 0.15 * relief.x * g2(au - eyx, v - (eyv - 0.055), 0.2, 0.04);
		// Olheiras, bolsas e têmporas com a idade
		ao *= 1.0 - 0.07 * relief3.y * g2(au - eyx, v - (eyv + 0.13), 0.18, 0.035);
		ao *= 1.0 - 0.07 * relief3.z * g2(au - eyx, v - (eyv + 0.17), 0.12, 0.022);
		ao *= 1.0 - 0.06 * relief3.w * g2(au - 0.86, v + 0.3, 0.1, 0.15);
		// Narinas: duas regiões pequenas e separadas (a columela no meio continua clara)
		float nost_y = nsv - 0.004 - nose.y * 0.01 + nose.z * 0.008;
		vec2 nq = vec2(abs(un) - nsw * 0.42, v - nost_y);
		float ca = 0.9;
		float sa = 0.44;
		vec2 nr = vec2(nq.x * ca + nq.y * sa, -nq.x * sa + nq.y * ca);
		float nost = g2(nr.x, nr.y, nsw * 0.13 * nose.x, 0.0135 * (1.0 + nose.y * 0.5));
		nost *= smoothstep(nsw * 0.16, nsw * 0.26, abs(un));
		// Vinco da asa do nariz (só a borda de fora e de baixo)
		vec2 ac = vec2(abs(un) - nsw * 0.8, v - (nsv - 0.036));
		float ring = length(ac / vec2(nsw * 0.33, 0.05)) - 1.0;
		float alar = g1(ring, 0.22) * smoothstep(-nsw * 0.05, nsw * 0.15, ac.x) * (1.0 - smoothstep(-0.01, 0.03, ac.y));
		ao *= 1.0 - 0.13 * nose.w * alar;
		// Sombra projetada do nariz: pequena, macia, deslocada para o lado oposto ao da luz e
		// limitada: nunca uma faixa entre as narinas
		vec2 away = normalize(-L.xy);
		vec2 cs = vec2(nsd + away.x * 0.06, tip_shadow_v(nsv) + away.y * 0.025);
		float cast = g2((u - cs.x) / max(nsw * 0.5, 0.05), (v - cs.y) / 0.03, 1.0, 1.0) * smoothstep(nsv - 0.02, nsv + 0.01, v);
		sh *= 1.0 - light_k2.x * cast;
		// Sulco nasolabial (mais marcado com a idade e o sorriso), mais visível do lado da sombra
		float nl = seg_dist(vec2(au, v), vec2(nsw * 1.2, nsv - 0.02), vec2(mtw * 1.12, mtv + 0.04)) / 0.045;
		ao *= 1.0 - relief2.y * (u > 0.0 ? 1.2 : 0.7) * exp(-nl * nl);
		// Bochecha funda (rosto magro) e maçãs no sorriso
		ao *= 1.0 - relief2.z * 0.9 * g2(au - 0.64, v - cheek_v - 0.28, 0.17, 0.13);
		ao *= 1.0 - 0.1 * mass.w * g2(au - 0.6, v - 0.43, 0.13, 0.13);
		// Boca: cantos, sombra sob o lábio de baixo (a luz vem de cima), covinha do queixo
		ao *= 1.0 - 0.1 * g2(au - mtw * 1.04, v - mtv, 0.045, 0.035);
		sh *= 1.0 - 0.14 * g2(u / max(0.05, mtw * 0.55), (v - (mtv + relief2.w * 2.0 + 0.06)) / 0.035, 1.0, 1.0);
		ao *= 1.0 - 0.08 * relief3.x * g2(u, v - (shape.z - 0.1), 0.025, 0.06);
		// Papada lateral e dobra do queixo duplo
		ao *= 1.0 - 0.09 * relief4.z * g2(au - mtw * 1.55, v - 0.84, 0.09, 0.07);
		ao *= 1.0 - 0.09 * mass.z * g2(u, v - shape.z, 0.36, 0.04);
		// Sombra de contato do cabelo na testa (acompanha a linha do cabelo de cada penteado)
		if (hair_k > 0.0 && v < eyv - 0.05) {
			float hx = clamp((u + 1.0) * 4.0, 0.0, 7.999);
			int i0 = int(floor(hx));
			float hlv = mix(hl[i0], hl[i0 + 1], hx - float(i0));
			ao *= 1.0 - hair_k * smoothstep(hlv + 0.13, hlv - 0.005, v);
		}

		// Luz rebatida de baixo (a pele do lábio e do queixo devolve luz): as superfícies viradas
		// para baixo — embaixo do nariz, do lábio, do queixo — ficam em meia-sombra, não pretas
		float bounce = max(n.y, 0.0) * 0.1;
		float l = light_k.x * ao + light_k.y * diff * sh * mix(1.0, ao, 0.6) + light_k.z * fillv * ao + bounce * ao;
		l = mix(0.95, l, light_k2.z);
		// Sombra mais quente (o vermelho some por último): nunca cinza, nunca preto
		vec3 col = vec3(base.r * pow(max(l, 0.0), 0.82), base.g * l, base.b * pow(max(l, 0.0), 1.12));
		// Espalhamento sob a pele: faixa mais saturada e avermelhada na passagem luz/sombra
		col += base * vec3(0.15, 0.035, 0.012) * g1(diff * sh - 0.42, 0.2);
		// Columela (entre as narinas) pega luz; narinas no tom da própria pele, escuras e macias
		col += base * 0.05 * g2(un, v - (nsv - 0.012), nsw * 0.1, 0.014);
		col = mix(col, base * vec3(0.32, 0.22, 0.19), clamp(nost * 0.8, 0.0, 0.8));
		// Contraluz fria e fraca no lado da sombra
		float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 2.5) * max(n.x, 0.0) * smoothstep(0.75, 1.0, th);
		col += vec3(0.75, 0.82, 0.95) * rim * light_k2.y;
		// Brilho: vem do relevo (dorso e ponta do nariz, testa, maçãs, queixo), mais forte na zona T
		// e em pele oleosa; pele seca fica fosca
		vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
		float ndh = max(dot(n, H), 0.0);
		float fore = g2(u + 0.2, v + 0.55, 0.38, 0.2);
		float ridge_hl = g1(un + 0.03, brw) * smoothstep(eyv - 0.06, eyv + 0.1, v) * (1.0 - smoothstep(nsv - 0.1, nsv - 0.01, v));
		float tip_hl = g2(un + 0.02, v - (nsv - 0.06), nsw * 0.35, 0.05);
		float tz = clamp(fore * 0.9 + ridge_hl * 0.8 + tip_hl + 0.45 * g2(u + 0.5, v - cheek_v, 0.2, 0.1) + 0.3 * g2(u + 0.04, v - 0.86, 0.16, 0.06), 0.0, 1.0);
		float oil = skin_p.z;
		float spec = pow(ndh, 18.0 + oil * 34.0) * (0.22 + 0.5 * oil) * (0.3 + 0.9 * tz) + pow(ndh, 6.0) * 0.045 * (0.4 + 0.6 * tz);
		col += vec3(1.0, 0.97, 0.93) * spec * sh * skin_p2.x * (1.0 - nost);
		COLOR = vec4(clamp(col, 0.0, 1.0), COLOR.a);
	}
}
