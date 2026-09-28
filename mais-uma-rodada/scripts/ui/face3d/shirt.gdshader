shader_type spatial;
// Camisa do busto 3D: a frente do uniforme (desenhada pelo KitView num SubViewport: estampa,
// patrocínio, fornecedor e escudo) é projetada de frente no tecido; gola com friso pela distância
// até a borda do pescoço; tricô sutil. Terno (técnico/dirigente): cor lisa escura com camisa clara.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D kit_tex : source_color, filter_linear_mipmap;
uniform bool use_kit = false;
uniform vec3 c1 : source_color = vec3(0.8, 0.1, 0.1);
uniform vec3 trim : source_color = vec3(1.0);
uniform float trim_w = 0.012;
uniform float kit_scale = 1.36;
uniform float collar_y = 0.655;
uniform float suit = 0.0;

varying vec3 obj;

void vertex() {
	obj = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec3 col = c1;
	if (use_kit) {
		vec2 kuv = vec2(0.5 + obj.x * kit_scale, 0.072 + (collar_y - obj.y) * kit_scale);
		// Atrás e nas laterais fundas repete a cor da borda (a estampa vale para a frente)
		vec4 k = texture(kit_tex, clamp(kuv, vec2(0.02), vec2(0.98)));
		col = mix(c1, k.rgb, k.a);
	}
	float d = UV2.x;
	float t = 1.0 - smoothstep(trim_w * 0.8, trim_w, d);
	if (suit > 0.5) {
		// Camisa social clara no "V" do colarinho, paletó escuro no resto
		float v = step(abs(obj.x), (collar_y - obj.y) * 0.55 + 0.03) * step(obj.z, 1.0) * step(0.0, obj.z);
		col = mix(c1, vec3(0.92), v * step(0.06, obj.z));
		t = 0.0;
	}
	col = mix(col, trim, t);
	// Tricô: pontinhos muito finos + leve variação
	vec2 g = obj.xy * 900.0;
	float knit = 0.96 + 0.04 * hash(floor(g));
	ALBEDO = col * knit;
	ROUGHNESS = 0.78;
	SPECULAR = 0.25;
}
