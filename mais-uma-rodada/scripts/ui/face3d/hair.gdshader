shader_type spatial;
// Mechas de cabelo (cartões com alfa) com brilho anisotrópico de Kajiya-Kay: dois reflexos ao longo
// do fio (um branco deslocado para a raiz, outro tingido mais largo), raiz mais escura, pontas finas.
// A textura dá o desenho dos fios (luminância) e a cor vem do jogador; COLOR.r varia o tom por mecha.
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 color : source_color = vec3(0.1, 0.07, 0.05);
uniform float cutoff = 0.4;
uniform float shine = 0.55;
uniform float lighten = 0.0;
uniform float gray = 0.0;
uniform float tips = 0.0;

varying vec3 tang;
varying float vcol;

void vertex() {
	vcol = COLOR.r;
}

void fragment() {
	vec4 t = texture(tex, UV);
	float l = t.r;
	float along = UV.y;
	vec3 c = color * (0.55 + 0.9 * l) * mix(0.85, 1.15, vcol);
	c *= mix(0.62, 1.0, smoothstep(0.0, 0.3, along)); // raiz sombreada
	c = mix(c, vec3(0.93, 0.88, 0.76) * (0.7 + 0.4 * l), max(lighten * smoothstep(0.1, 0.8, along), tips * smoothstep(0.55, 0.95, along)));
	c = mix(c, vec3(0.8, 0.79, 0.77) * (0.7 + 0.5 * l), gray * step(1.0 - gray * 0.8, fract(vcol * 7.31)));
	ALBEDO = c;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = cutoff;
	ALPHA_ANTIALIASING_EDGE = cutoff * 0.7;
	tang = normalize(TANGENT);
	ROUGHNESS = 0.5;
}

void light() {
	vec3 T = normalize(tang);
	vec3 H = normalize(LIGHT + VIEW);
	float nl = dot(NORMAL, LIGHT);
	float diff = clamp(nl * 0.6 + 0.4, 0.0, 1.0);
	DIFFUSE_LIGHT += diff * ATTENUATION * LIGHT_COLOR / PI;
	vec3 T1 = normalize(T + NORMAL * 0.12);
	vec3 T2 = normalize(T - NORMAL * 0.18);
	float th1 = dot(T1, H);
	float th2 = dot(T2, H);
	float s1 = pow(sqrt(max(0.0, 1.0 - th1 * th1)), 90.0);
	float s2 = pow(sqrt(max(0.0, 1.0 - th2 * th2)), 22.0);
	float vis = smoothstep(-0.1, 0.3, nl);
	SPECULAR_LIGHT += (vec3(s1) * 0.35 + ALBEDO * s2 * 0.6) * shine * vis * ATTENUATION * LIGHT_COLOR / PI;
}
