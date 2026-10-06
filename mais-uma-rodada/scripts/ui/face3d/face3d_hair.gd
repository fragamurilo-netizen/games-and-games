class_name Face3DHair
extends RefCounted
## Cabelo, barba e sobrancelhas procedurais do rosto 3D.
## Fios longos/médios: mechas (cartões com alfa) que nascem nas raízes sorteadas no couro cabeludo
## (roots_scalp.bin), seguem um campo de penteado (para trás, franja, risco, topete, black power…),
## caem com a gravidade, enrolam (ondulado/cacheado/crespo), se juntam em mechas e colidem com a
## cabeça. Curtos/crespos: camadas (shells) desenhadas pelo shell.gdshader com os mesmos parâmetros.
## As máscaras (linha do cabelo, degradê, barba) são as mesmas do hairmask.gdshaderinc.

## Catálogo de cortes. s = camadas (mm) [topo, frente, lateral, trás, nuca]; c = mechas (cm) idem;
## fade = altura do degradê (dm; 0 = sem), sharp = corte seco; dir = penteado; lift = quanto sobe;
## grav = gravidade; curl = [amplitude cm, voltas por 10 cm]; mess = bagunça; w = largura da mecha (mm);
## tex = textura dos fios; dens = densidade; coily = camadas crespas; flat = topo reto (high top);
## rows/waves/design/hawk/part = padrões; extra = coque/rabo/puffs; gloss = brilho.
const STYLES := {
	"bald": {"s": [0, 0, 0, 0, 0]},
	"shaved": {"s": [0.6, 0.6, 0.6, 0.6, 0.5], "dens": 0.75},
	"buzz_short": {"s": [2.5, 2.5, 2.0, 2.2, 1.6]},
	"buzz": {"s": [4.5, 4.5, 3.5, 4.0, 3.0]},
	"buzz_long": {"s": [7.0, 7.0, 5.0, 6.0, 4.0]},
	"buzz_fade": {"s": [3.5, 3.5, 3.0, 3.0, 2.0], "fade": 7.7},
	"buzz_skin_fade": {"s": [4.0, 4.0, 3.0, 3.0, 2.0], "fade": 8.2},
	"crew": {"s": [9, 8, 4, 5, 3], "c": [2.2, 2.0, 0, 0, 0], "dir": "back", "lift": 0.35, "tex": "straight", "mess": 0.3, "dens": 0.55},
	"crew_fade": {"s": [9, 8, 3, 3, 2], "c": [2.4, 2.2, 0, 0, 0], "fade": 7.8, "dir": "back", "lift": 0.35, "tex": "straight", "mess": 0.3, "dens": 0.55},
	"ivy": {"s": [8, 8, 3, 4, 2], "c": [3.5, 3.2, 0, 0, 0], "fade": 7.6, "dir": "side", "part": 0.28, "lift": 0.2, "tex": "straight", "dens": 0.6},
	"caesar": {"s": [8, 8, 4, 4, 3], "c": [2.0, 2.5, 0, 0, 0], "dir": "fwd", "lift": 0.1, "tex": "straight", "mess": 0.2, "dens": 0.6},
	"edgar": {"s": [8, 8, 2, 2, 1], "c": [2.5, 3.0, 0, 0, 0], "fade": 8.25, "sharp": 0.6, "dir": "fwd", "lift": 0.05, "tex": "straight", "dens": 0.75},
	"crop": {"s": [8, 8, 3, 3, 2], "c": [3.5, 3.5, 0, 0, 0], "fade": 7.9, "dir": "crop", "lift": 0.25, "tex": "wavy", "mess": 0.55, "dens": 0.7},
	"crop_fringe": {"s": [8, 8, 3, 3, 2], "c": [4.5, 5.0, 0, 0, 0], "fade": 7.9, "dir": "fwd", "lift": 0.15, "tex": "wavy", "mess": 0.4, "dens": 0.7},
	"french_crop": {"s": [8, 8, 2, 2, 1], "c": [3.5, 4.0, 0, 0, 0], "fade": 8.25, "dir": "fwd", "lift": 0.12, "tex": "straight", "mess": 0.3, "dens": 0.75},
	"short": {"s": [8, 8, 6, 6, 4], "c": [4.5, 4.0, 2.5, 3.0, 1.5], "dir": "side", "part": 0.3, "lift": 0.25, "tex": "straight", "mess": 0.35, "dens": 0.7},
	"short_messy": {"s": [8, 8, 6, 6, 4], "c": [5.0, 4.5, 3.0, 3.5, 2.0], "dir": "messy", "lift": 0.4, "tex": "wavy", "mess": 0.8, "dens": 0.7},
	"side_part": {"s": [8, 8, 5, 5, 3], "c": [6.0, 6.0, 2.5, 3.0, 1.5], "dir": "side", "part": 0.32, "lift": 0.2, "tex": "straight", "mess": 0.15, "dens": 0.75, "gloss": 0.7},
	"side_part_fade": {"s": [8, 8, 3, 3, 2], "c": [6.5, 6.5, 0, 0, 0], "fade": 7.9, "dir": "side", "part": 0.32, "lift": 0.25, "tex": "straight", "mess": 0.15, "dens": 0.75, "gloss": 0.7},
	"hard_part": {"s": [8, 8, 2, 2, 1], "c": [6.5, 6.5, 0, 0, 0], "fade": 8.1, "dir": "side", "part": 0.34, "design": 1, "lift": 0.25, "tex": "straight", "dens": 0.75, "gloss": 0.8},
	"comb_over": {"s": [8, 8, 2, 2, 1], "c": [8.0, 8.5, 0, 0, 0], "fade": 8.2, "dir": "side", "part": 0.36, "lift": 0.35, "tex": "straight", "dens": 0.8, "gloss": 0.8},
	"slick": {"s": [8, 8, 5, 6, 3], "c": [8.0, 8.5, 4.0, 6.0, 3.0], "dir": "back", "lift": 0.1, "tex": "straight", "dens": 0.8, "gloss": 1.1},
	"slick_fade": {"s": [8, 8, 2, 2, 1], "c": [8.0, 9.0, 0, 0, 0], "fade": 8.0, "dir": "back", "lift": 0.15, "tex": "straight", "dens": 0.8, "gloss": 1.1},
	"wet_back": {"s": [8, 8, 5, 5, 3], "c": [9.0, 10.0, 5.0, 7.0, 4.0], "dir": "back", "lift": 0.05, "tex": "straight", "dens": 0.85, "gloss": 1.4, "w": 7},
	"pompadour": {"s": [8, 8, 2, 2, 1], "c": [8.0, 11.0, 0, 0, 0], "fade": 8.1, "dir": "quiff", "lift": 0.55, "tex": "straight", "dens": 0.8, "gloss": 0.9},
	"quiff": {"s": [8, 8, 3, 4, 2], "c": [6.0, 8.0, 0, 0, 0], "fade": 7.8, "dir": "quiff", "lift": 0.5, "tex": "straight", "mess": 0.2, "dens": 0.75, "gloss": 0.7},
	"quiff_messy": {"s": [8, 8, 3, 4, 2], "c": [6.0, 7.5, 0, 0, 0], "fade": 7.8, "dir": "quiff", "lift": 0.5, "tex": "wavy", "mess": 0.6, "dens": 0.75},
	"high_quiff": {"s": [8, 8, 2, 2, 1], "c": [7.0, 10.0, 0, 0, 0], "fade": 8.2, "dir": "quiff", "lift": 0.7, "tex": "straight", "dens": 0.8, "gloss": 0.8},
	"spiky": {"s": [8, 8, 4, 4, 3], "c": [4.5, 4.0, 0, 0, 0], "fade": 7.6, "dir": "up", "lift": 0.8, "tex": "straight", "mess": 0.4, "dens": 0.65, "cross": true, "gloss": 0.9},
	"faux_hawk": {"s": [8, 8, 2, 2, 1], "c": [6.0, 5.0, 0, 0, 0], "fade": 8.2, "dir": "hawk", "hawk_c": 0.35, "lift": 0.75, "tex": "straight", "dens": 0.75, "cross": true},
	"mohawk": {"s": [8, 8, 0.6, 0.6, 0.5], "c": [9.0, 7.0, 0, 7.0, 0], "hawk": 0.2, "dir": "up", "lift": 0.9, "tex": "straight", "dens": 0.85, "cross": true, "gloss": 0.8},
	"curly_mohawk": {"s": [14, 12, 0.6, 0.6, 0.5], "hawk": 0.24, "coily": 0.7, "sflat": 0.0},
	"undercut": {"s": [8, 8, 0.5, 0.5, 0.4], "c": [10.0, 11.0, 0, 0, 0], "fade": 8.35, "sharp": 1.0, "dir": "back", "lift": 0.2, "tex": "straight", "dens": 0.85, "gloss": 0.9},
	"undercut_side": {"s": [8, 8, 0.5, 0.5, 0.4], "c": [11.0, 12.0, 0, 0, 0], "fade": 8.35, "sharp": 1.0, "dir": "side", "part": 0.3, "lift": 0.25, "tex": "straight", "dens": 0.85},
	"man_bun": {"s": [8, 8, 3, 3, 2], "c": [10.0, 11.0, 0, 8.0, 0], "fade": 8.1, "dir": "tobun", "lift": 0.05, "tex": "straight", "dens": 0.85, "extra": "bun"},
	"topknot": {"s": [8, 8, 0.6, 0.6, 0.5], "c": [10.0, 11.0, 0, 0, 0], "fade": 8.4, "sharp": 1.0, "dir": "toknot", "lift": 0.05, "tex": "straight", "dens": 0.85, "extra": "knot"},
	"low_bun": {"s": [8, 8, 5, 5, 3], "c": [12.0, 12.0, 9.0, 10.0, 6.0], "dir": "tolow", "lift": 0.05, "tex": "straight", "dens": 0.85, "extra": "lowbun"},
	"ponytail": {"s": [8, 8, 5, 5, 3], "c": [12.0, 12.0, 9.0, 10.0, 6.0], "dir": "tolow", "lift": 0.05, "tex": "straight", "dens": 0.85, "extra": "pony"},
	"half_up": {"s": [8, 8, 6, 6, 4], "c": [14.0, 14.0, 20.0, 22.0, 20.0], "dir": "halfup", "lift": 0.05, "grav": 0.8, "tex": "wavy", "dens": 0.85, "extra": "knot"},
	"long": {"s": [8, 8, 6, 6, 4], "c": [22.0, 20.0, 24.0, 26.0, 22.0], "dir": "mid", "lift": 0.05, "grav": 1.0, "tex": "straight", "dens": 0.9, "gloss": 0.9},
	"long_wavy": {"s": [8, 8, 6, 6, 4], "c": [20.0, 18.0, 22.0, 24.0, 20.0], "dir": "mid", "lift": 0.08, "grav": 0.9, "curl": [0.8, 1.2], "tex": "wavy", "mess": 0.3, "dens": 0.9},
	"long_curly": {"s": [12, 12, 10, 10, 6], "c": [16.0, 14.0, 17.0, 18.0, 15.0], "dir": "down", "lift": 0.3, "grav": 0.6, "curl": [1.6, 3.0], "tex": "curly", "mess": 0.5, "dens": 0.95, "cross": true},
	"shoulder": {"s": [8, 8, 6, 6, 4], "c": [14.0, 13.0, 15.0, 16.0, 14.0], "dir": "side", "part": 0.25, "lift": 0.05, "grav": 0.9, "tex": "straight", "dens": 0.9},
	"surfer": {"s": [8, 8, 6, 6, 4], "c": [12.0, 11.0, 12.0, 13.0, 11.0], "dir": "messy", "lift": 0.15, "grav": 0.6, "curl": [0.8, 1.5], "tex": "wavy", "mess": 0.6, "dens": 0.85},
	"flow": {"s": [8, 8, 6, 6, 4], "c": [11.0, 12.0, 10.0, 12.0, 10.0], "dir": "back", "lift": 0.15, "grav": 0.5, "curl": [0.5, 1.0], "tex": "wavy", "mess": 0.25, "dens": 0.85, "gloss": 0.8},
	"curtains": {"s": [8, 8, 6, 6, 4], "c": [9.0, 10.0, 7.0, 7.0, 4.0], "dir": "curtain", "lift": 0.1, "grav": 0.4, "tex": "straight", "mess": 0.2, "dens": 0.85},
	"curtain_fringe": {"s": [8, 8, 3, 3, 2], "c": [7.0, 8.0, 0, 0, 0], "fade": 7.8, "dir": "curtain", "lift": 0.12, "grav": 0.3, "tex": "wavy", "mess": 0.3, "dens": 0.8},
	"bowl": {"s": [8, 8, 6, 6, 4], "c": [6.0, 6.5, 5.5, 5.5, 3.5], "dir": "fwd", "lift": 0.05, "grav": 0.5, "tex": "straight", "dens": 0.9},
	"fringe": {"s": [8, 8, 5, 5, 3], "c": [6.0, 7.0, 3.5, 4.0, 2.0], "dir": "fwd", "lift": 0.1, "grav": 0.3, "tex": "straight", "mess": 0.35, "dens": 0.8},
	"side_fringe": {"s": [8, 8, 4, 4, 3], "c": [8.0, 9.0, 3.0, 3.5, 2.0], "dir": "swoop", "lift": 0.1, "grav": 0.3, "tex": "straight", "mess": 0.2, "dens": 0.85},
	"textured_fringe": {"s": [8, 8, 3, 3, 2], "c": [5.0, 6.0, 0, 0, 0], "fade": 7.9, "dir": "fwd", "lift": 0.25, "tex": "wavy", "mess": 0.7, "dens": 0.8},
	"mullet": {"s": [8, 8, 5, 6, 4], "c": [5.0, 5.0, 3.0, 12.0, 14.0], "dir": "back", "lift": 0.25, "grav": 0.7, "tex": "wavy", "mess": 0.4, "dens": 0.85},
	"mullet_fade": {"s": [8, 8, 2, 6, 4], "c": [5.0, 5.0, 0, 11.0, 13.0], "fade": 7.9, "dir": "back", "lift": 0.25, "grav": 0.7, "tex": "wavy", "mess": 0.4, "dens": 0.85},
	"mullet_curly": {"s": [14, 14, 6, 10, 8], "c": [4.0, 4.0, 0, 10.0, 12.0], "dir": "down", "lift": 0.4, "grav": 0.4, "curl": [1.2, 3.5], "tex": "curly", "mess": 0.5, "dens": 0.85, "coily": 0.4},
	"wavy_medium": {"s": [8, 8, 6, 6, 4], "c": [8.0, 8.0, 5.0, 6.0, 3.5], "dir": "side", "part": 0.25, "lift": 0.2, "curl": [0.7, 1.6], "tex": "wavy", "mess": 0.35, "dens": 0.85},
	"wavy_back": {"s": [8, 8, 5, 5, 3], "c": [8.0, 9.0, 5.0, 6.0, 3.0], "dir": "back", "lift": 0.25, "curl": [0.6, 1.5], "tex": "wavy", "mess": 0.3, "dens": 0.85, "gloss": 0.8},
	"wavy_messy": {"s": [8, 8, 6, 6, 4], "c": [8.0, 8.0, 5.0, 6.0, 4.0], "dir": "messy", "lift": 0.3, "curl": [0.9, 1.8], "tex": "wavy", "mess": 0.8, "dens": 0.85},
	"blowout": {"s": [8, 8, 3, 3, 2], "c": [8.0, 9.0, 0, 0, 0], "fade": 7.8, "dir": "quiff", "lift": 0.65, "tex": "wavy", "mess": 0.35, "dens": 0.85, "cross": true},
	"curly_short": {"s": [16, 16, 9, 10, 6], "coily": 0.55, "c": [3.0, 3.0, 0, 0, 0], "dir": "out", "lift": 0.6, "curl": [0.8, 5.0], "tex": "curly", "mess": 0.6, "dens": 0.5, "cross": true},
	"curly_top_fade": {"s": [18, 16, 3, 3, 2], "fade": 7.9, "coily": 0.6, "c": [3.5, 3.5, 0, 0, 0], "dir": "out", "lift": 0.6, "curl": [0.9, 5.0], "tex": "curly", "mess": 0.6, "dens": 0.55, "cross": true},
	"curly_medium": {"s": [20, 20, 14, 14, 8], "coily": 0.6, "c": [5.5, 5.5, 4.0, 4.0, 2.0], "dir": "out", "lift": 0.5, "grav": 0.2, "curl": [1.1, 4.0], "tex": "curly", "mess": 0.6, "dens": 0.65, "cross": true},
	"curly_fringe": {"s": [16, 16, 6, 6, 4], "coily": 0.6, "fade": 7.8, "c": [5.0, 6.5, 0, 0, 0], "dir": "fwd", "lift": 0.35, "grav": 0.3, "curl": [1.0, 4.0], "tex": "curly", "mess": 0.5, "dens": 0.65, "cross": true},
	"curly_quiff": {"s": [18, 16, 3, 3, 2], "coily": 0.6, "fade": 8.0, "c": [5.0, 6.5, 0, 0, 0], "dir": "quiff", "lift": 0.6, "curl": [1.0, 4.0], "tex": "curly", "mess": 0.5, "dens": 0.65, "cross": true},
	"curly_long_fringe": {"s": [18, 18, 14, 14, 8], "coily": 0.5, "c": [9.0, 9.0, 8.0, 9.0, 6.0], "dir": "fwd", "lift": 0.35, "grav": 0.5, "curl": [1.3, 3.5], "tex": "curly", "mess": 0.5, "dens": 0.75, "cross": true},
	"afro_short": {"s": [22, 22, 18, 18, 10], "coily": 1.0},
	"afro_taper": {"s": [30, 28, 6, 8, 3], "coily": 1.0, "fade": 7.7},
	"afro": {"s": [55, 50, 45, 45, 25], "coily": 1.0},
	"afro_big": {"s": [80, 72, 65, 65, 35], "coily": 1.0},
	"afro_part": {"s": [25, 24, 5, 6, 3], "coily": 1.0, "fade": 7.8, "part": 0.3, "design": 1},
	"high_top": {"s": [75, 60, 4, 6, 3], "coily": 1.0, "fade": 8.0, "flat": 1.0},
	"sponge": {"s": [28, 26, 8, 10, 4], "coily": 1.0, "fade": 7.8, "c": [2.5, 2.5, 0, 0, 0], "dir": "out", "lift": 0.8, "tex": "locs", "w": 5, "dens": 0.35, "cross": true},
	"burst_curly": {"s": [24, 22, 18, 5, 3], "coily": 1.0, "fade": 7.6},
	"twists": {"s": [12, 12, 5, 6, 3], "coily": 0.8, "fade": 7.8, "c": [5.5, 5.5, 0, 0, 0], "dir": "out", "lift": 0.7, "grav": 0.2, "tex": "locs", "w": 6, "dens": 0.45, "cross": true},
	"twists_long": {"s": [12, 12, 10, 10, 6], "coily": 0.8, "c": [14.0, 13.0, 14.0, 15.0, 13.0], "dir": "down", "lift": 0.4, "grav": 0.8, "tex": "locs", "w": 6, "dens": 0.55, "cross": true},
	"twist_out": {"s": [30, 28, 24, 24, 14], "coily": 1.0, "c": [5.0, 5.0, 4.0, 4.0, 2.0], "dir": "out", "lift": 0.7, "curl": [1.0, 6.0], "tex": "coily", "dens": 0.35, "cross": true},
	"locs_short": {"s": [10, 10, 6, 6, 4], "coily": 0.8, "c": [8.0, 8.0, 6.0, 7.0, 5.0], "dir": "out", "lift": 0.55, "grav": 0.4, "tex": "locs", "w": 8, "dens": 0.5, "cross": true},
	"locs_fade": {"s": [10, 10, 3, 3, 2], "coily": 0.8, "fade": 7.9, "c": [9.0, 9.0, 0, 0, 0], "dir": "out", "lift": 0.55, "grav": 0.5, "tex": "locs", "w": 8, "dens": 0.55, "cross": true},
	"dreads": {"s": [10, 10, 8, 8, 5], "coily": 0.8, "c": [20.0, 18.0, 22.0, 24.0, 22.0], "dir": "down", "lift": 0.35, "grav": 1.0, "tex": "locs", "w": 9, "dens": 0.6, "cross": true},
	"dreads_pony": {"s": [10, 10, 8, 8, 5], "coily": 0.8, "c": [12.0, 12.0, 9.0, 10.0, 8.0], "dir": "tolow", "lift": 0.1, "tex": "locs", "w": 9, "dens": 0.6, "extra": "pony_locs"},
	"dreads_bun": {"s": [10, 10, 8, 8, 5], "coily": 0.8, "c": [12.0, 12.0, 9.0, 10.0, 8.0], "dir": "tobun", "lift": 0.1, "tex": "locs", "w": 9, "dens": 0.6, "extra": "bun_locs"},
	"dread_hawk": {"s": [10, 10, 0.6, 0.6, 0.5], "hawk": 0.24, "coily": 0.8, "c": [14.0, 12.0, 0, 14.0, 0], "dir": "up", "lift": 0.5, "grav": 0.6, "tex": "locs", "w": 9, "dens": 0.7, "cross": true},
	"freeform": {"s": [12, 12, 10, 10, 6], "coily": 0.9, "c": [9.0, 8.0, 8.0, 9.0, 6.0], "dir": "messy", "lift": 0.5, "grav": 0.4, "curl": [1.0, 1.5], "tex": "locs", "w": 10, "mess": 0.8, "dens": 0.45, "cross": true},
	"cornrows": {"s": [5, 5, 4, 4, 3], "rows": 1, "gloss": 0.8},
	"cornrows_zigzag": {"s": [5, 5, 4, 4, 3], "rows": 2, "gloss": 0.8},
	"cornrows_fade": {"s": [5, 5, 3, 3, 2], "rows": 1, "fade": 7.9},
	"cornrows_pony": {"s": [5, 5, 4, 4, 3], "rows": 1, "extra": "pony_braid"},
	"box_braids": {"s": [5, 5, 4, 4, 3], "rows": 1, "c": [22.0, 20.0, 22.0, 24.0, 22.0], "dir": "down", "lift": 0.15, "grav": 1.0, "tex": "braid", "w": 9, "dens": 0.5, "cross": true},
	"braids_fade": {"s": [5, 5, 2, 2, 1], "rows": 1, "fade": 8.0, "c": [18.0, 16.0, 0, 20.0, 0], "dir": "down", "lift": 0.15, "grav": 1.0, "tex": "braid", "w": 9, "dens": 0.5, "cross": true},
	"braid_bun": {"s": [5, 5, 4, 4, 3], "rows": 1, "extra": "bun_braid"},
	"braid_hawk": {"s": [5, 5, 0.6, 0.6, 0.5], "rows": 1, "hawk": 0.24},
	"waves": {"s": [4.0, 4.0, 3.5, 3.5, 2.5], "waves": 1, "gloss": 1.0, "coily": 0.3},
	"waves_fade": {"s": [4.0, 4.0, 2.5, 2.5, 1.5], "waves": 1, "fade": 7.9, "gloss": 1.0, "coily": 0.3},
	"buzz_design": {"s": [3.5, 3.5, 3.0, 3.0, 2.0], "design": 2, "fade": 7.7},
	"buzz_part": {"s": [4.0, 4.0, 3.0, 3.0, 2.0], "design": 1, "part": 0.3, "fade": 7.8},
	"puffs": {"s": [6, 6, 5, 5, 3], "coily": 1.0, "extra": "puffs"},
	"afro_puff": {"s": [6, 6, 5, 5, 3], "coily": 1.0, "extra": "puff"},
}

## Formatos de sobrancelha: [grossura (dm), arco, inclinação, comprimento, afinamento, queda da cauda,
## densidade, distância do centro, altura]. Cada jogador ainda varia em cima disso.
const BROWS: Array = [
	[0.075, 0.03, 0.02, 0.62, 0.55, 0.03, 0.8, 0.07, 0.0], # comum
	[0.07, 0.0, 0.0, 0.62, 0.4, 0.0, 0.8, 0.07, 0.0], # reta
	[0.065, 0.07, 0.03, 0.6, 0.6, 0.05, 0.8, 0.07, 0.01], # arqueada
	[0.105, 0.03, 0.02, 0.64, 0.45, 0.03, 0.95, 0.06, 0.0], # grossa
	[0.045, 0.04, 0.02, 0.58, 0.6, 0.03, 0.7, 0.08, 0.01], # fina
	[0.075, 0.02, -0.03, 0.62, 0.5, 0.08, 0.8, 0.07, -0.01], # caída
	[0.1, 0.0, 0.0, 0.64, 0.3, 0.0, 0.95, 0.06, -0.01], # reta e grossa
	[0.07, 0.03, 0.02, 0.56, 0.6, 0.03, 0.45, 0.08, 0.0], # rala
	[0.075, 0.08, 0.05, 0.6, 0.55, 0.09, 0.85, 0.07, 0.01], # angulosa
	[0.1, 0.01, -0.01, 0.64, 0.35, 0.03, 0.95, 0.055, -0.04], # baixa e pesada
	[0.07, 0.05, 0.03, 0.6, 0.55, 0.04, 0.8, 0.07, 0.05], # alta
	[0.11, 0.03, 0.02, 0.66, 0.4, 0.03, 0.9, 0.05, 0.0], # desgrenhada
	[0.085, 0.05, 0.04, 0.63, 0.5, 0.06, 0.85, 0.065, 0.0], # masculina marcada
	[0.06, 0.015, 0.01, 0.55, 0.5, 0.02, 0.75, 0.085, 0.0], # curta
	[0.09, 0.06, 0.06, 0.66, 0.65, 0.1, 0.9, 0.06, 0.0], # asa
	[0.08, 0.025, -0.01, 0.6, 0.35, 0.02, 0.85, 0.04, -0.02], # quase juntas
	[0.055, 0.02, 0.0, 0.6, 0.3, 0.0, 0.6, 0.075, 0.0], # clara e fina
	[0.12, 0.02, 0.01, 0.68, 0.3, 0.02, 1.0, 0.045, -0.02], # cerrada
	[0.07, 0.09, 0.02, 0.58, 0.7, 0.02, 0.8, 0.075, 0.02], # arredondada
	[0.08, 0.04, 0.06, 0.62, 0.45, 0.0, 0.85, 0.07, 0.0], # subindo
	[0.075, 0.035, 0.02, 0.62, 0.55, 0.03, 0.8, 0.07, 0.0], # comum 2
	[0.065, 0.02, 0.0, 0.66, 0.6, 0.06, 0.65, 0.07, 0.0], # longa e rala
	[0.095, 0.04, 0.03, 0.6, 0.5, 0.04, 0.9, 0.065, 0.0], # cheia
	[0.085, 0.0, 0.03, 0.6, 0.45, 0.02, 0.85, 0.07, 0.0], # reta inclinada
]

static var _field_cache := {}


# ---------------------------------------------------------------------------------------------
# Máscaras (mesmas contas do hairmask.gdshaderinc)
# ---------------------------------------------------------------------------------------------

static func _ss(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _band(x: float, a: float, b: float, s: float) -> float:
	return _ss(a - s, a + s, x) * (1.0 - _ss(b - s, b + s, x))


static func scalp_mask(p: Vector3, hp: Dictionary) -> float:
	var ax := absf(p.x)
	var hl_front: float = float(hp.get("hairline", 8.72)) + float(hp.get("temples", 0.0)) * _ss(0.15, 0.5, ax) * 0.4
	var t := _ss(-0.7, 1.35, p.z)
	var hl := lerpf(7.05, hl_front, t)
	hl = lerpf(hl, 7.95, _ss(0.55, 0.72, ax) * _band(p.z, -0.2, 1.05, 0.12))
	var m := _ss(hl - 0.025, hl + 0.04, p.y)
	var ear := Vector2((p.y - 7.58) / 0.44, (p.z - 0.45) / 0.37).length()
	m *= lerpf(1.0, _ss(0.92, 1.08, ear), _ss(0.64, 0.72, ax))
	var cr := Vector2(p.x, p.z - 0.05).length() / 0.5 + (9.12 - p.y) * 0.9
	m *= 1.0 - float(hp.get("crown", 0.0)) * (1.0 - _ss(0.3, 0.85, cr))
	var hw := float(hp.get("hawk", 0.0))
	if hw > 0.0:
		m *= 1.0 - _ss(hw - 0.03, hw + 0.03, ax)
	return clampf(m, 0.0, 1.0)


static func fade_mask(p: Vector3, st: Dictionary) -> float:
	var fh := float(st.get("fade", 0.0))
	if fh <= 0.0:
		return 1.0
	var ax := absf(p.x)
	var sides := clampf(_ss(0.38, 0.62, ax) + (1.0 - _ss(-0.45, 0.15, p.z)), 0.0, 1.0)
	var s := lerpf(0.45, 0.02, float(st.get("sharp", 0.0)))
	return lerpf(1.0, _ss(fh - s, fh + s * 0.4, p.y), sides)


static func region_w(p: Vector3) -> Array:
	var ax := absf(p.x)
	var front := _ss(0.7, 1.2, p.z)
	var back := 1.0 - _ss(-0.5, 0.2, p.z)
	var side := _ss(0.45, 0.7, ax) * (1.0 - front)
	var top := _ss(8.75, 9.05, p.y)
	var nape := (1.0 - _ss(7.3, 7.9, p.y)) * back
	return [top, front, side, back, nape]


static func region_len(p: Vector3, arr: Array) -> float:
	var r := region_w(p)
	var L := float(arr[0])
	L = lerpf(L, float(arr[1]), float(r[1]) * (1.0 - float(r[0])))
	L = lerpf(L, float(arr[2]), float(r[2]) * (1.0 - float(r[0])))
	L = lerpf(L, float(arr[3]), float(r[3]) * (1.0 - float(r[0])))
	L = lerpf(L, float(arr[4]), float(r[4]))
	return L


static func beard_mask(p: Vector3, b: Dictionary) -> float:
	var ax := absf(p.x)
	var soft := lerpf(0.06, 0.018, float(b.get("sh", 0.0)))
	var front := _ss(-0.1, 0.35, p.z)
	var lip := Vector2(p.x / 0.25, (p.y - 7.39) / 0.085).length()
	var nolip := clampf(_ss(0.95, 1.2, lip) + (1.0 - _ss(1.2, 1.35, p.z)), 0.0, 1.0)
	var d := 0.0
	var ch := float(b.get("ch", 0.0))
	if ch > 0.0:
		var top := lerpf(7.52, 8.0 - ch * 1.1, _ss(0.22, 0.62, ax))
		var c := (1.0 - _ss(top - soft, top + soft, p.y)) * _ss(6.95, 7.1, p.y + (1.0 - _ss(0.3, 0.7, ax)) * 0.3)
		c *= _ss(0.1, 0.45, p.z) * (1.0 - _ss(0.7, 0.8, ax) * (1.0 - _ss(0.55, 0.9, p.z)))
		d = maxf(d, c)
	var sd := float(b.get("sd", 0.0))
	if sd > 0.0:
		d = maxf(d, sd * _ss(0.58, 0.66, ax) * _band(p.z, 0.62, 1.05, 0.05) * _band(p.y, 7.35, 8.05, 0.04))
	var jw := float(b.get("jw", 0.0))
	if jw > 0.0:
		var jaw_y := lerpf(6.95, 7.35, _ss(0.15, 0.7, ax))
		var jb := _band(p.y, jaw_y - 0.18, jaw_y + 0.16, soft) * _ss(0.0, 0.3, p.z)
		if jw < 0.8:
			jb *= 1.0 - _ss(jw * 0.7 + 0.05, jw * 0.7 + 0.15, ax)
		d = maxf(d, jb)
	var cn := float(b.get("cn", 0.0))
	if cn > 0.0:
		var w := (0.12 + cn * 0.2) * float(b.get("cnw", 1.0))
		d = maxf(d, (1.0 - _ss(w - soft, w + soft, ax)) * _band(p.y, 6.78, 7.3, soft) * _ss(0.7, 1.0, p.z))
	var mu := float(b.get("mu", 0.0))
	if mu > 0.0:
		var thin := mu > 1.5 and mu < 2.5
		var th := 0.035 if thin else 0.075
		var mm := _band(p.y, 7.46, 7.46 + th, 0.015) * (1.0 - _ss(0.25, 0.3, ax)) * _ss(1.3, 1.45, p.z)
		if not thin:
			mm = maxf(mm, _band(ax, 0.19, 0.29, 0.02) * _band(p.y, 7.34, 7.5, 0.02) * _ss(1.2, 1.35, p.z))
		if mu > 2.5:
			mm = maxf(mm, _band(ax, 0.2, 0.3, 0.02) * _band(p.y, 6.95, 7.5, 0.02) * _ss(1.0, 1.2, p.z))
		d = maxf(d, mm)
	var so := float(b.get("so", 0.0))
	if so > 0.0:
		d = maxf(d, so * (1.0 - _ss(0.06, 0.09, ax)) * _band(p.y, 7.12, 7.29, 0.02) * _ss(1.3, 1.45, p.z))
	var nk := float(b.get("nk", 0.0))
	if nk > 0.0:
		d = maxf(d, nk * _band(p.y, 6.55, 6.95, 0.08) * _ss(0.35, 0.8, p.z) * (1.0 - _ss(0.55, 0.7, ax)))
	return d * nolip * front


# ---------------------------------------------------------------------------------------------
# Campo da cabeça (colisão): raio máximo da cabeça por direção, a partir do busto deformado
# ---------------------------------------------------------------------------------------------

const AZ := 40
const EL := 20


static var _body_ids := PackedInt32Array()


## Vértices que são da pele do busto (sem as malhas auxiliares do MakeHuman, como o casco de cabelo).
static func body_ids() -> PackedInt32Array:
	if _body_ids.is_empty():
		var b := Face3DKit.load_bin("body")
		var orig: PackedInt32Array = b["orig"]
		var seen := {}
		for o in orig:
			seen[o] = true
		var ids := PackedInt32Array()
		for k in seen:
			ids.append(int(k))
		_body_ids = ids
	return _body_ids


static func head_field(bp: PackedVector3Array) -> Dictionary:
	var b := Face3DKit.load_bin("body")
	var base: PackedFloat32Array = b["pos"]
	var ids := body_ids()
	var c := Vector3.ZERO
	var cnt := 0
	for i in ids:
		if base[i * 3 + 1] > 0.8:
			c += bp[i]
			cnt += 1
	c /= maxf(1.0, cnt)
	c.y -= 0.005
	var tab := PackedFloat32Array()
	tab.resize(AZ * EL)
	for i in ids:
		if base[i * 3 + 1] < 0.64:
			continue
		var v := bp[i] - c
		var r := v.length()
		if r < 0.001:
			continue
		var k := _bin(v / r)
		tab[k] = maxf(tab[k], r)
	# preenche direções vazias com as vizinhas
	for _it in 6:
		var t2 := tab.duplicate()
		for e in EL:
			for a in AZ:
				var k := e * AZ + a
				if tab[k] > 0.0:
					continue
				var best := 0.0
				for d in [[0, 1], [0, -1], [1, 0], [-1, 0]]:
					var ee := clampi(e + int(d[0]), 0, EL - 1)
					var aa := posmod(a + int(d[1]), AZ)
					best = maxf(best, tab[ee * AZ + aa])
				t2[k] = best
		tab = t2
	return {"c": c, "t": tab}


static func _bin(d: Vector3) -> int:
	var az := atan2(d.x, d.z)
	var el := asin(clampf(d.y, -1.0, 1.0))
	var a := clampi(int((az + PI) / TAU * AZ), 0, AZ - 1)
	var e := clampi(int((el + PI * 0.5) / PI * EL), 0, EL - 1)
	return e * AZ + a


static func _collide(field: Dictionary, p: Vector3, margin: float) -> Vector3:
	var c: Vector3 = field["c"]
	var v := p - c
	var r := v.length()
	if r < 0.0001:
		return p
	var d := v / r
	var rr: float = (field["t"] as PackedFloat32Array)[_bin(d)] + margin
	if r < rr:
		return c + d * rr
	return p


# ---------------------------------------------------------------------------------------------
# Construção das mechas
# ---------------------------------------------------------------------------------------------

## Monta o cabelo (mechas) do estilo `st` já com as variações do jogador. Retorna null se o corte
## for só de camadas. hp: parâmetros da linha do cabelo (hairline, temples, crown, hawk).
static func build_hair(st: Dictionary, bp: PackedVector3Array, field: Dictionary, hp: Dictionary, seed_v: int, quality: float) -> ArrayMesh:
	var c_len: Array = st.get("c", [])
	var extra := String(st.get("extra", ""))
	if c_len.is_empty() and extra == "":
		return null
	var rs := Face3DKit.load_bin("roots_scalp")
	var ids: PackedInt32Array = rs["ids"]
	var bc: PackedFloat32Array = rs["bc"]
	var pbase: PackedFloat32Array = rs["p"]
	var n := bc.size() / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := _MeshBuf.new()
	var dens: float = float(st.get("dens", 0.7)) * quality
	var tex_cols := 8
	var width := float(st.get("w", 4.0)) * 0.00075 * (1.0 / sqrt(maxf(quality, 0.3)))
	var dir_mode := String(st.get("dir", "back"))
	var lift := float(st.get("lift", 0.2))
	if not String(st.get("dir", "")) in ["up", "out", "hawk"]:
		lift *= 0.6
	var grav := float(st.get("grav", 0.0 if String(st.get("dir", "")) in ["up", "out", "quiff", "hawk"] else 0.12))
	var curl: Array = st.get("curl", [0.0, 0.0])
	var mess := float(st.get("mess", 0.0)) * 0.6
	var cross := bool(st.get("cross", false))
	var part := float(st.get("part", 0.0)) * float(hp.get("part_side", 1.0))
	var c: Vector3 = field["c"]
	var hmask := hp.duplicate()
	hmask["hawk"] = float(st.get("hawk", 0.0))
	var knot := c + Vector3(0.0, 0.1, -0.04)
	var low := c + Vector3(0.0, -0.03, -0.1)
	if not c_len.is_empty():
		for i in n:
			if rng.randf() > dens:
				continue
			var pb := Vector3(pbase[i * 3], pbase[i * 3 + 1], pbase[i * 3 + 2])
			var m := scalp_mask(pb, hmask)
			if m < 0.35 or rng.randf() > m:
				continue
			var fm := fade_mask(pb, st)
			var L := region_len(pb, c_len) * 0.01 * fm * rng.randf_range(0.82, 1.12)
			if dir_mode == "hawk":
				L *= 1.0 - _ss(float(st.get("hawk_c", 0.35)) - 0.08, float(st.get("hawk_c", 0.35)) + 0.12, absf(pb.x)) * 0.8
			if L < 0.012:
				continue
			var j := i * 3
			var a := bp[ids[j]]
			var b := bp[ids[j + 1]]
			var cc := bp[ids[j + 2]]
			var u := bc[i * 2]
			var v := bc[i * 2 + 1]
			var p := a * (1.0 - u - v) + b * u + cc * v
			var nrm := (b - a).cross(cc - a).normalized()
			if nrm.dot(p - c) < 0.0:
				nrm = -nrm
			# mechas: raízes próximas compartilham a mesma bagunça/fase de cacho
			var cl := Vector3i(int(floor(pb.x * 9.0)), int(floor(pb.y * 9.0)), int(floor(pb.z * 9.0)))
			var ch := hash([cl, seed_v])
			var crng := RandomNumberGenerator.new()
			crng.seed = ch
			var jit := Vector3(crng.randf_range(-1, 1), crng.randf_range(-1, 1), crng.randf_range(-1, 1)) * mess
			var comb := _comb(dir_mode, pb, p, nrm, c, part, knot, low)
			var d0 := (nrm * lift + comb * (1.0 - lift) + jit * 0.6 + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.08).normalized()
			var gv := grav
			if dir_mode in ["tobun", "toknot", "tolow", "halfup"]:
				gv = 0.0
			var col := clampf(0.5 + (crng.randf() - 0.5) * 0.6 + (rng.randf() - 0.5) * 0.3, 0.0, 1.0)
			var tcol := rng.randi_range(0, tex_cols - 1)
			var pts := _grow(p, d0, L, gv, curl, crng.randf() * TAU, field, c, nrm, dir_mode, knot, low, pb)
			mb.card(pts, width * rng.randf_range(0.85, 1.2), c, tcol, tex_cols, col, cross, 0.0)
	# Coque, rabo, puffs
	match extra:
		"bun", "knot", "bun_locs", "bun_braid":
			var at := knot if extra == "knot" else c + Vector3(0.0, 0.045, -0.085)
			_bun(mb, at, 0.042 if extra != "knot" else 0.034, rng, tex_cols, width)
		"lowbun":
			_bun(mb, low + Vector3(0, 0, -0.01), 0.04, rng, tex_cols, width)
		"pony", "pony_locs", "pony_braid":
			_tail(mb, low + Vector3(0, 0, -0.012), rng, tex_cols, width * (1.6 if extra != "pony" else 1.0), 0.2 if extra != "pony_braid" else 0.24, field)
		"puff":
			_puff(mb, c + Vector3(0.0, 0.1, -0.03), 0.07, rng, tex_cols, width)
		"puffs":
			_puff(mb, c + Vector3(0.06, 0.08, -0.01), 0.05, rng, tex_cols, width)
			_puff(mb, c + Vector3(-0.06, 0.08, -0.01), 0.05, rng, tex_cols, width)
	return mb.mesh()


static func _comb(mode: String, pb: Vector3, p: Vector3, n: Vector3, c: Vector3, part: float, knot: Vector3, low: Vector3) -> Vector3:
	var r := region_w(pb)
	var side_w: float = r[2]
	var back_w: float = r[3]
	var v := Vector3(0, -0.2, -1)
	var sx := signf(pb.x) if pb.x != 0.0 else 1.0
	match mode:
		"back":
			v = Vector3(0, -0.15, -1)
		"fwd":
			v = Vector3(0, -0.45, 1)
		"crop":
			v = Vector3(sx * 0.1, -0.55, 1)
		"side":
			var s := 1.0 if pb.x > part else -1.0
			v = Vector3(s, -0.25, -0.25 if pb.z < 1.0 else 0.15)
		"swoop":
			v = Vector3(1, -0.35, 0.6)
		"curtain":
			v = Vector3(sx, -0.6, 0.5 if pb.z > 0.8 else -0.2)
		"up", "hawk":
			v = n + Vector3(0, 0.2, -0.25)
		"quiff":
			v = Vector3(0, 0.55, -0.85) if pb.z > 0.9 else Vector3(0, -0.1, -1)
		"out":
			v = n
		"down", "mid":
			v = Vector3(sx * 0.6, -1.0, 0.1 if pb.z > 0.8 else -0.3)
		"messy":
			v = Vector3(sx * 0.4, -0.2, 0.5 if pb.z > 0.7 else -0.6)
		"tobun", "halfup":
			v = (c + Vector3(0.0, 0.045, -0.085) - p)
		"toknot":
			v = (knot - p)
		"tolow":
			v = (low - p)
	if mode in ["back", "fwd", "crop", "quiff", "swoop", "messy", "side"]:
		# laterais e nuca penteadas para baixo/trás
		v = v.lerp(Vector3(sx * 0.2, -1.0, -0.4), maxf(side_w, back_w) * 0.7)
	v = v - n * v.dot(n) * (0.0 if mode in ["up", "out", "hawk"] else 0.85)
	return v.normalized()


static func _grow(p0: Vector3, d0: Vector3, L: float, grav: float, curl: Array, ph0: float, field: Dictionary, c: Vector3, n: Vector3, mode: String, knot: Vector3, low: Vector3, pb: Vector3) -> PackedVector3Array:
	var segs := clampi(int(L / 0.011) + 2, 3, 14)
	var step := L / segs
	var pts := PackedVector3Array()
	var p := p0
	var d := d0
	var amp := float(curl[0]) * 0.01
	var freq := float(curl[1])
	var margin := 0.0025 + fposmod(p0.x * 1731.0 + p0.y * 977.0 + p0.z * 313.0, 1.0) * 0.004
	# quanto o fio pode se afastar da cabeça (volume do penteado)
	var allow := 0.004 + lift_of(d0, n) * L * 0.9
	var ear_y := c.y - 0.035
	pts.append(p)
	var target := Vector3.INF
	if mode in ["tobun", "halfup"]:
		target = c + Vector3(0.0, 0.045, -0.085)
	elif mode == "toknot":
		target = knot
	elif mode == "tolow":
		target = low
	for s in segs:
		var t := float(s + 1) / segs
		if target != Vector3.INF:
			d = d.lerp((target - p).normalized(), 0.35).normalized()
		d = (d + Vector3(0, -1, 0) * grav * step * 9.0).normalized()
		var np := p + d * step
		np = _collide(field, np, margin + t * 0.003)
		# abraça a cabeça enquanto estiver acima da orelha (o penteado acompanha o crânio); cabelo
		# curto abraça sempre
		if (np.y > ear_y or L < 0.09) and target == Vector3.INF:
			np = _hug(field, np, margin + t * 0.003 + allow * t)
		if target != Vector3.INF and np.distance_to(target) < 0.02:
			np = target
		if amp > 0.0:
			var out := (np - c).normalized()
			var side := d.cross(out).normalized()
			var ph := ph0 + t * L * freq * 10.0 * TAU
			np += (side * cos(ph) + out * sin(ph) * 0.6) * amp * minf(1.0, t * 3.0) * 0.35
		d = (np - p).normalized()
		p = np
		pts.append(p)
	return pts


static func lift_of(d0: Vector3, n: Vector3) -> float:
	return clampf(d0.dot(n), 0.0, 1.0)


static func _hug(field: Dictionary, p: Vector3, max_off: float) -> Vector3:
	var c: Vector3 = field["c"]
	var v := p - c
	var r := v.length()
	if r < 0.0001:
		return p
	var dv := v / r
	var rr: float = (field["t"] as PackedFloat32Array)[_bin(dv)]
	if r > rr + max_off:
		return c + dv * (rr + max_off)
	return p


static func _bun(mb: _MeshBuf, at: Vector3, r: float, rng: RandomNumberGenerator, cols: int, width: float) -> void:
	for i in 260:
		var y := rng.randf_range(-0.8, 0.9)
		var a := rng.randf() * TAU
		var pts := PackedVector3Array()
		var rr := sqrt(1.0 - y * y)
		var span := rng.randf_range(1.2, 2.4)
		for k in 7:
			var aa := a + span * k / 6.0
			var q := Vector3(cos(aa) * rr, y + sin(aa * 2.0) * 0.05, sin(aa) * rr) * r * rng.randf_range(0.92, 1.05)
			pts.append(at + q)
		mb.card(pts, width * 1.3, at, rng.randi_range(0, cols - 1), cols, rng.randf(), false, 0.0)


static func _puff(mb: _MeshBuf, at: Vector3, r: float, rng: RandomNumberGenerator, cols: int, width: float) -> void:
	for i in 700:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var pts := PackedVector3Array()
		var base := at + d * r * 0.3
		for k in 4:
			pts.append(base + d * r * (0.3 + 0.25 * k) + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r * 0.08)
		mb.card(pts, width * 1.6, at, rng.randi_range(0, cols - 1), cols, rng.randf(), true, 0.0)


static func _tail(mb: _MeshBuf, at: Vector3, rng: RandomNumberGenerator, cols: int, width: float, L: float, field: Dictionary) -> void:
	for i in 320:
		var off := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5)) * 0.012
		var p := at + off
		var d := Vector3(off.x * 8.0, -0.3, -1.0).normalized()
		var pts := PackedVector3Array([p])
		var segs := 10
		var ln := L * rng.randf_range(0.8, 1.1)
		for s in segs:
			d = (d + Vector3(0, -1, 0) * 0.35).normalized()
			p = _collide(field, p + d * ln / segs, 0.006)
			pts.append(p)
		mb.card(pts, width, at, rng.randi_range(0, cols - 1), cols, rng.randf(), true, 0.0)


## Sobrancelhas: pelos curtos deitados na pele, seguindo o formato escolhido.
static func build_brows(shape: Array, bp: PackedVector3Array, field: Dictionary, seed_v: int, var_k: Dictionary) -> ArrayMesh:
	var rs := Face3DKit.load_bin("roots_brow")
	var ids: PackedInt32Array = rs["ids"]
	var bc: PackedFloat32Array = rs["bc"]
	var pbase: PackedFloat32Array = rs["p"]
	var n := bc.size() / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := _MeshBuf.new()
	var thick: float = float(shape[0]) * float(var_k.get("thick", 1.0))
	var arch: float = float(shape[1]) + float(var_k.get("arch", 0.0))
	var tilt: float = float(shape[2]) + float(var_k.get("tilt", 0.0))
	var length: float = float(shape[3]) * float(var_k.get("len", 1.0))
	var taper: float = shape[4]
	var drop: float = shape[5]
	var dens: float = float(shape[6]) * float(var_k.get("dens", 1.0))
	var gap: float = float(shape[7]) + float(var_k.get("gap", 0.0))
	var y0: float = 8.16 + float(shape[8]) + float(var_k.get("y", 0.0))
	var uni := bool(var_k.get("uni", false))
	var slit := int(var_k.get("slit", 0))
	var c: Vector3 = field["c"]
	for i in n:
		var pb := Vector3(pbase[i * 3], pbase[i * 3 + 1], pbase[i * 3 + 2])
		var ax := absf(pb.x)
		var u := (ax - gap) / maxf(length, 0.1)
		if u < -0.12 or u > 1.0:
			continue
		if u < 0.0 and not uni:
			continue
		var uc := clampf(u, 0.0, 1.0)
		var yc := y0 + arch * sin(uc * PI * 0.85) + tilt * uc - drop * _ss(0.65, 1.0, uc) - 0.015 * (1.0 - _ss(0.0, 0.15, uc))
		var th := thick * (1.0 - taper * _ss(0.3, 1.0, uc)) * lerpf(0.75, 1.0, _ss(0.0, 0.12, uc))
		if u < 0.0:
			th *= 0.35
		var dy := pb.y - yc
		if absf(dy) > th * 0.5:
			continue
		var edge := absf(dy) / (th * 0.5)
		if rng.randf() > dens * (1.0 - edge * edge * 0.6):
			continue
		if slit > 0 and absf(uc - (0.55 if slit == 1 else 0.7)) < 0.045:
			continue
		var j := i * 3
		var a := bp[ids[j]]
		var b := bp[ids[j + 1]]
		var cc := bp[ids[j + 2]]
		var uu := bc[i * 2]
		var vv := bc[i * 2 + 1]
		var p := a * (1.0 - uu - vv) + b * uu + cc * vv
		var nrm := (b - a).cross(cc - a).normalized()
		if nrm.dot(p - c) < 0.0:
			nrm = -nrm
		var sx := signf(pb.x)
		var dir := Vector3(sx * 0.25, 1.0, 0.1) if uc < 0.18 else Vector3(sx, 0.35 - uc * 0.7 - dy * 3.0, 0.0)
		dir = (dir - nrm * dir.dot(nrm) * 0.85 + nrm * 0.12).normalized()
		var L := rng.randf_range(0.006, 0.01) * (1.15 if uc < 0.2 else 1.0) * float(var_k.get("hlen", 1.0))
		var pts := PackedVector3Array([p + nrm * 0.0004])
		var q := pts[0]
		for s in 3:
			var d2 := (dir + nrm * (0.04 - 0.05 * s)).normalized()
			q += d2 * L / 3.0
			pts.append(q)
		mb.card(pts, 0.0024, c, rng.randi_range(0, 7), 8, rng.randf(), false, 0.0)
	return mb.mesh()


## Barba com volume (mechas) para barbas médias/longas; as curtas ficam nas camadas.
static func build_beard(b: Dictionary, bp: PackedVector3Array, field: Dictionary, seed_v: int, quality: float, curly: float) -> ArrayMesh:
	var ln := float(b.get("ln", 0.0))
	if ln < 0.3 or float(b.get("op", 0.0)) < 0.7:
		return null
	var rs := Face3DKit.load_bin("roots_beard")
	var ids: PackedInt32Array = rs["ids"]
	var bc: PackedFloat32Array = rs["bc"]
	var pbase: PackedFloat32Array = rs["p"]
	var n := bc.size() / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := _MeshBuf.new()
	var c: Vector3 = field["c"]
	var Lb := (1.0 + ln * 9.0) * 0.01
	for i in n:
		var pb := Vector3(pbase[i * 3], pbase[i * 3 + 1], pbase[i * 3 + 2])
		var m := beard_mask(pb, b)
		if m < 0.3 or rng.randf() > m * 0.8 * quality:
			continue
		var j := i * 3
		var a := bp[ids[j]]
		var bb := bp[ids[j + 1]]
		var cc := bp[ids[j + 2]]
		var uu := bc[i * 2]
		var vv := bc[i * 2 + 1]
		var p := a * (1.0 - uu - vv) + bb * uu + cc * vv
		var nrm := (bb - a).cross(cc - a).normalized()
		if nrm.dot(p - c) < 0.0:
			nrm = -nrm
		var mustache := pb.y > 7.44 and absf(pb.x) < 0.32 and pb.z > 1.2
		var L := Lb * rng.randf_range(0.7, 1.1)
		if mustache:
			L = minf(L, 0.012)
		# no queixo cresce mais; nas bochechas menos
		L *= lerpf(0.55, 1.0, 1.0 - _ss(7.2, 7.8, pb.y))
		var d := (Vector3(signf(pb.x) * 0.25, -1.0, 0.35) + nrm * 0.6).normalized()
		if mustache:
			d = (Vector3(signf(pb.x) * 0.8, -1.0, 0.3) + nrm * 0.3).normalized()
		var pts := _grow(p + nrm * 0.0005, d, L, 0.25 + ln, [0.25 + curly * 0.6, 3.0 + curly * 5.0], rng.randf() * TAU, field, c, nrm, "", Vector3.ZERO, Vector3.ZERO, pb)
		mb.card(pts, 0.004, c, rng.randi_range(0, 7), 8, rng.randf(), curly > 0.4, 0.0)
	return mb.mesh()


# ---------------------------------------------------------------------------------------------

class _MeshBuf:
	var v := PackedVector3Array()
	var nrm := PackedVector3Array()
	var tg := PackedFloat32Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	## Um cartão ao longo de `pts` (raiz → ponta). Normal = para fora da cabeça (luz de cabelo);
	## `cross` acrescenta um segundo cartão perpendicular (volume para mechas em pé/cachos).
	func card(pts: PackedVector3Array, w: float, center: Vector3, col_i: int, cols: int, tint: float, cross: bool, _twist: float) -> void:
		var passes := 2 if cross else 1
		var np := pts.size()
		for pass_i in passes:
			var base := v.size()
			for k in np:
				var p := pts[k]
				var d := (pts[mini(k + 1, np - 1)] - pts[maxi(k - 1, 0)]).normalized()
				var out := (p - center).normalized()
				var side := d.cross(out).normalized() if pass_i == 0 else out
				if pass_i == 1:
					side = (side - d * side.dot(d)).normalized()
				var t := float(k) / (np - 1)
				var hw := w * 0.5 * (1.0 - 0.35 * t)
				v.append(p - side * hw)
				v.append(p + side * hw)
				var nn := out if pass_i == 0 else d.cross(side).normalized()
				if nn.dot(out) < 0.0:
					nn = -nn
				nrm.append(nn)
				nrm.append(nn)
				for _r in 2:
					tg.append(d.x)
					tg.append(d.y)
					tg.append(d.z)
					tg.append(1.0)
				col.append(Color(tint, t, 0, 1))
				col.append(Color(tint, t, 0, 1))
				var u0 := float(col_i) / cols
				var u1 := float(col_i + 1) / cols
				uv.append(Vector2(u0, t))
				uv.append(Vector2(u1, t))
			for k in np - 1:
				var a := base + k * 2
				idx.append(a)
				idx.append(a + 1)
				idx.append(a + 2)
				idx.append(a + 1)
				idx.append(a + 3)
				idx.append(a + 2)

	func mesh() -> ArrayMesh:
		if v.is_empty():
			return null
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_TANGENT] = tg
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m
