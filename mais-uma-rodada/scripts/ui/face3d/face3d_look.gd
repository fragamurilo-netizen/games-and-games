class_name Face3DLook
extends RefCounted
## Traduz os traços do FaceGen (os mesmos do retrato 2D) para o rosto 3D.
## Morfologia: cada jogador tem um vetor contínuo próprio nos ~220 alvos do MakeHuman (sorteado da
## semente): viés da etnia + os traços do FaceGen + ruído individual (maior em quem é "feio", menor
## em quem é bonito) + 2–4 traços marcantes + assimetria. Na prática, nenhum rosto se repete.
## Cabelo: os 113 penteados do jogo viram cortes do catálogo do Face3DHair, com variações.

const ETH_MIX: Array = [
	[1.0, 0.0, 0.0], [1.0, 0.0, 0.0], [0.86, 0.06, 0.08], [0.78, 0.12, 0.1], [0.62, 0.14, 0.24], [0.28, 0.04, 0.68],
	[0.42, 0.5, 0.08], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [0.55, 0.22, 0.23], [0.1, 0.9, 0.0], [0.2, 0.32, 0.48], [0.1, 0.06, 0.84],
]
## Traços típicos de cada grupo (somados aos da mistura de referência do MakeHuman).
const ETH_BIAS: Array = [
	{"nose-scale-horiz-decr": 0.3, "nose-scale-depth-incr": 0.25, "eyebrows-trans-depth-more": 0.35, "eye-push1-in": 0.3, "head-scale-vert-more": 0.2, "chin-prominent-more": 0.2, "mouth-upperlip-volume-deflate": 0.3, "cheek-volume-deflate": 0.2}, # nórdico
	{"nose-scale-depth-incr": 0.15, "eyebrows-trans-depth-more": 0.2, "mouth-upperlip-volume-deflate": 0.1}, # europeu
	{"nose-hump-morehump": 0.25, "eyebrows-trans-depth-more": 0.3, "mouth-lowerlip-volume-inflate": 0.15, "nose-scale-vert-incr": 0.1}, # mediterrâneo
	{"nose-hump-morehump": 0.45, "nose-scale-vert-incr": 0.3, "eyebrows-trans-depth-more": 0.4, "eye-push1-in": 0.25, "nose-point-down": 0.25, "chin-prominent-more": 0.1}, # árabe
	{"nose-scale-horiz-incr": 0.15, "cheek-bones-out": 0.2, "mouth-lowerlip-volume-inflate": 0.2, "head-scale-horiz-more": 0.1}, # latino
	{"cheek-bones-out": 0.5, "nose-hump-morehump": 0.3, "eye-epicanthus-in": 0.35, "head-scale-horiz-more": 0.25, "nose-scale-vert-incr": 0.2, "eye-height2-min": 0.2}, # andino
	{"nose-scale-horiz-incr": 0.35, "mouth-upperlip-volume-inflate": 0.35, "mouth-lowerlip-volume-inflate": 0.35, "nose-volume-potato": 0.2}, # miscigenado
	{"mouth-upperlip-volume-inflate": 0.3, "mouth-lowerlip-volume-inflate": 0.3, "forehead-nubian-more": 0.3, "nose-nostril-width-max": 0.2, "chin-prognathism-more": 0.15}, # africano
	{"eye-epicanthus-in": 0.6, "nose-scale-depth-decr": 0.4, "cheek-bones-out": 0.4, "eye-height2-min": 0.3, "eyebrows-trans-depth-less": 0.3, "head-scale-horiz-more": 0.15, "eye-eyefold-down": 0.3}, # leste asiático
	{"nose-scale-vert-incr": 0.25, "eye-size-big": 0.2, "mouth-lowerlip-volume-inflate": 0.1, "eyebrows-trans-depth-more": 0.2, "nose-point-down": 0.2}, # sul-asiático
	{"mouth-upperlip-volume-inflate": 0.35, "mouth-lowerlip-volume-inflate": 0.3, "nose-nostril-width-max": 0.3, "forehead-nubian-more": 0.2}, # caribenho
	{"head-scale-horiz-more": 0.3, "nose-scale-horiz-incr": 0.4, "mouth-lowerlip-volume-inflate": 0.3, "cheek-volume-inflate": 0.3, "chin-width-max": 0.3}, # pacífico
	{"eye-epicanthus-in": 0.45, "nose-scale-horiz-incr": 0.3, "nose-scale-depth-decr": 0.3, "cheek-bones-out": 0.25, "mouth-upperlip-volume-inflate": 0.15}, # sudeste asiático
]
## Penteado do FaceGen (índice) → corte do catálogo.
const STYLE_MAP: Array[String] = [
	"buzz_short", "short", "side_part", "quiff", "crew_fade", "curly_medium", "afro", "dreads", "long", "man_bun",
	"mohawk", "bald", "slick", "cornrows", "spiky", "fringe", "undercut", "buzz_long", "pompadour", "wavy_medium",
	"curtains", "mullet", "ponytail", "twists", "high_top", "waves", "crop", "surfer", "bowl", "box_braids",
	"afro_short", "topknot", "long_curly", "buzz_part", "wavy_back", "locs_short", "burst_curly", "afro_taper", "flow", "quiff_messy",
	"buzz_design", "cornrows_fade", "curly_mohawk", "shoulder", "side_fringe", "freeform", "side_part_fade", "curly_top_fade", "curly_short", "buzz_fade",
	"man_bun", "half_up", "mullet_fade", "edgar", "faux_hawk", "buzz", "locs_fade", "curly_fringe", "slick_fade", "braid_bun",
	"hard_part", "wet_back", "curtain_fringe", "spiky", "curly_medium", "braid_hawk", "undercut_side", "dreads_bun", "dread_hawk", "blowout",
	"textured_fringe", "twist_out", "afro_puff", "cornrows_zigzag", "braids_fade", "pompadour", "long_wavy", "spiky", "buzz_part", "sponge",
	"low_bun", "quiff_messy", "side_fringe", "curtain_fringe", "buzz", "buzz_skin_fade", "high_quiff", "curly_quiff", "caesar", "ivy",
	"wet_back", "burst_curly", "afro_big", "afro_part", "twists_long", "dreads_pony", "cornrows_pony", "topknot", "long", "shoulder",
	"mullet_curly", "mohawk", "buzz_design", "wavy_messy", "comb_over", "caesar", "quiff", "man_bun", "curly_long_fringe", "freeform",
	"waves_fade", "curly_medium", "puffs",
]
const BLEACH_STYLES := [55, 77, 102]
## Depuração: só etnia/idade/corpo, sem traços.
static var debug_plain := false


static func build(f: Dictionary, seed_v: int) -> Dictionary:
	var out := {}
	var w := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_v, "rosto3d"])
	var e: int = clampi(int(f["eth"]), 0, ETH_MIX.size() - 1)
	var age: int = int(f["age"])
	var beauty := float(f.get("beauty", 0.5))
	# --- Etnia (mistura contínua) ---------------------------------------------------------
	var mx: Array = ETH_MIX[e]
	var em := [float(mx[0]) + rng.randf_range(-0.1, 0.1), float(mx[1]) + rng.randf_range(-0.07, 0.07), float(mx[2]) + rng.randf_range(-0.07, 0.07)]
	var tot := 0.0
	for i in 3:
		em[i] = maxf(0.0, em[i])
		tot += em[i]
	w["eth_eur"] = em[0] / tot
	w["eth_afr"] = em[1] / tot
	w["eth_asi"] = em[2] / tot
	# --- Idade e corpo --------------------------------------------------------------------
	w["age_old"] = clampf((age - 24.0) / 60.0, 0.0, 0.5) * float(f.get("age_gene", 1.0))
	w["age_child"] = clampf((20.0 - age) / 4.5, 0.0, 1.0) * 0.28
	var fat: float = f["fat"]
	w["fat"] = clampf((fat - 0.3) * 0.9, 0.0, 0.65)
	w["thin"] = clampf((0.25 - fat) * 1.6 + float(f.get("thin", 0.0)) * 0.5, 0.0, 0.6)
	w["muscle"] = clampf(float(f.get("build", 0.5)) - 0.3, 0.0, 0.6) * 0.6
	# --- Ruído individual em todos os alvos (morfologia única) -------------------------------
	var shapes: Array = Face3DKit.load_bin("body").get("meta", {}).get("shapes", [])
	var sd := 0.13 + (1.0 - beauty) * 0.12
	for s: String in shapes:
		if s.begins_with("eth_") or s.begins_with("age_") or s in ["fat", "thin", "muscle"] or s.begins_with("a:"):
			continue
		var g := rng.randfn(0.0, sd * (0.35 if _eyelid(s) else 1.0))
		if g > 0.0:
			w[s] = g
	# traços marcantes (nariz grande, queixo forte, orelhas de abano, olhos fundos…)
	var marks := rng.randi_range(2, 4)
	for i in marks:
		var s2: String = shapes[rng.randi_range(0, shapes.size() - 1)]
		if s2.begins_with("eth_") or s2.begins_with("age_") or s2.begins_with("a:") or s2 in ["fat", "thin", "muscle"] or _eyelid(s2):
			continue
		w[s2] = float(w.get(s2, 0.0)) + rng.randf_range(0.3, 0.6) * (1.2 - beauty * 0.5)
	# assimetria
	var asym := clampf(absf(float(f.get("asym", 0.0))) * 0.6 + 0.15, 0.0, 1.0)
	for s3: String in shapes:
		if s3.begins_with("a:"):
			w[s3] = maxf(0.0, rng.randfn(0.0, 0.18 * asym))
	# viés da etnia
	for k: String in ETH_BIAS[e]:
		_add(w, k, float(ETH_BIAS[e][k]) * rng.randf_range(0.6, 1.25))
	# --- Traços do FaceGen (mantêm a identidade do jogador) ---------------------------------
	var fw := float(f["fw"]) / 0.214 - 1.0
	var fh := float(f["fh"]) / 0.2925 - 1.0
	_pm(w, "head-scale-horiz", fw * 5.0)
	_pm(w, "head-scale-vert", fh * 5.0)
	match int(f.get("face_shape", 0)):
		0: _add(w, "head-oval", 0.5)
		1: _add(w, "head-round", 0.6)
		2: _add(w, "head-square", 0.6)
		3: _add(w, "head-invertedtriangular", 0.55)
		4: _add(w, "head-diamond", 0.55)
		5: _add(w, "head-scale-vert-more", 0.35)
		6: _add(w, "head-triangular", 0.5)
		7: _add(w, "head-rectangular", 0.6)
		8: _add(w, "head-scale-horiz-less", 0.35)
		9: _add(w, "head-scale-horiz-more", 0.35)
		10: _add(w, "chin-prominent-more", 0.6)
		11: _add(w, "chin-prominent-less", 0.6)
	_pm(w, "chin-bones", (float(f["jaw"]) - 0.79) * 6.0, "out", "in")
	_pm(w, "chin-width", (1.62 - float(f["chin_sq"])) * 1.4, "max", "min")
	if bool(f.get("chin_cleft", false)):
		_add(w, "chin-cleft-out", 0.8)
	_pm(w, "chin-height", float(f.get("chin_len", 0.0)) * 12.0, "max", "min")
	_pm(w, "forehead-scale-vert", (float(f["forehead"]) - 0.94) * 14.0)
	_pm(w, "cheek-bones", (float(f["cheekbone"]) - 0.95) * 2.2, "out", "in")
	_pm(w, "cheek-volume", (fat - 0.35) * 1.4 - float(f.get("temple", 0.0)) * 0.4, "inflate", "deflate")
	_add(w, "eyebrows-trans-depth-more", clampf((float(f["ridge"]) - 0.7) * 1.2, 0.0, 0.8))
	_add(w, "neck-double-more", clampf(float(f.get("jowl", 0.0)) * 0.5 + (fat - 0.6) * 0.8, 0.0, 0.7))
	_pm(w, "eye-size", (float(f["eye_w"]) / 0.232 - 1.0) * 4.0, "big", "small")
	_pm(w, "eye-height2", (float(f["eye_h"]) / 0.11 - 1.0) * 2.5, "max", "min")
	_pm(w, "eye-move", (float(f["eye_dx"]) - 0.435) * 14.0, "out", "in")
	_pm(w, "eye-corner1", float(f["eye_tilt"]) * 14.0, "up", "down")
	if bool(f.get("monolid", false)):
		_add(w, "eye-epicanthus-in", 0.8)
		_add(w, "eye-eyefold-down", 0.4)
	elif bool(f.get("hooded", false)):
		_add(w, "eye-eyefold-down", 0.45)
	_add(w, "eye-bag-max", clampf(float(f.get("eyebags", 0.0)) * 0.6, 0.0, 0.8))
	_pm(w, "eye-push1", (float(f["deep"]) - 0.9) * 1.5, "in", "out")
	var nw := float(f["nose_w"]) / 0.17 - 1.0
	_pm(w, "nose-scale-horiz", nw * 2.6, "incr", "decr")
	_pm(w, "nose-nostril-width", nw * 2.0, "max", "min")
	_pm(w, "nose-scale-vert", (float(f["nose_len"]) / 0.305 - 1.0) * 3.5, "incr", "decr")
	_pm(w, "nose-scale-depth", (float(f["bridge"]) - 0.8) * 1.4, "incr", "decr")
	_pm(w, "nose-width1", (float(f["bridge_w"]) - 0.07) * 30.0, "max", "min")
	_pm(w, "nose-point", (float(f["nose_tip"]) - 1.0) * 2.5, "up", "down")
	if bool(f.get("aquiline", false)):
		_add(w, "nose-hump-morehump", 0.7)
	match int(f.get("nose_type", 0)):
		1: _add(w, "nose-point-up", 0.5)
		2: _add(w, "nose-volume-potato", 0.7)
		3: _add(w, "nose-hump-morehump", 0.6)
		4: _add(w, "nose-scale-horiz-incr", 0.4)
		5: _add(w, "nose-scale-horiz-decr", 0.4)
		6: _add(w, "nose-compression-compress", 0.6)
		7: _add(w, "nose-greek-moregreek", 0.7)
		8: _add(w, "nose-point-down", 0.5)
		9: _add(w, "nose-curve-convex", 0.6)
		10: _add(w, "nose-volume-point", 0.7)
		11: _add(w, "nose-scale-vert-incr", 0.45)
		12: _add(w, "nose-scale-vert-decr", 0.35)
		13: _add(w, "nose-flaring-incr", 0.6)
	_pm(w, "mouth-scale-horiz", (float(f["mouth_w"]) / 0.315 - 1.0) * 3.5, "incr", "decr")
	_pm(w, "mouth-upperlip-volume", (float(f["lip_u"]) / 0.041 - 1.0) * 1.8, "inflate", "deflate")
	_pm(w, "mouth-lowerlip-volume", (float(f["lip_l"]) / 0.0625 - 1.0) * 1.8, "inflate", "deflate")
	_pm(w, "mouth-angles", (float(f.get("smile", 0.0)) - float(f.get("corner", 0.0))) * 0.45, "up", "down")
	match int(f.get("mouth_type", 0)):
		1: _add(w, "mouth-upperlip-volume-deflate", 0.5)
		2: _add(w, "mouth-lowerlip-volume-inflate", 0.4)
		3: _add(w, "mouth-scale-horiz-incr", 0.4)
		4: _add(w, "mouth-scale-horiz-decr", 0.4)
		5: _add(w, "mouth-lowerlip-volume-inflate", 0.6)
		6: _add(w, "mouth-angles-down", 0.5)
		7: _add(w, "mouth-cupidsbow-incr", 0.6)
		9: _add(w, "mouth-upperlip-volume-inflate", 0.7)
	_pm(w, "ear-size", (float(f["ear"]) - 1.0) * 4.0, "big", "small")
	_add(w, "ear-wing-out", clampf(float(f.get("ear_out", 0.0)) * 0.8, 0.0, 0.9))
	match int(f.get("ear_type", 0)):
		2: _add(w, "ear-size-big", 0.5)
		3: _add(w, "ear-wing-out", 0.8)
		4: _add(w, "ear-lobe-min", 0.8)
		5: _add(w, "ear-shape1-pointed", 0.6)
	match int(f.get("chin_type", 0)):
		2: _add(w, "chin-prominent-less", 0.6)
		3: _add(w, "chin-prominent-more", 0.6)
		4: _add(w, "chin-width-min", 0.6)
		5: _add(w, "chin-width-max", 0.6)
	# saturação suave (nada de extremos grotescos); quem é bonito fica mais perto da média
	var cap := lerpf(0.8, 0.6, beauty)
	for k: String in w.keys():
		if k.begins_with("eth_") or k.begins_with("age_") or k in ["fat", "thin", "muscle"]:
			continue
		var x := float(w[k]) * 0.75
		w[k] = cap * tanh(x / cap) * (0.6 if _eyelid(k) else 1.0)
	if debug_plain:
		for k: String in w.keys():
			if not (k.begins_with("eth_") or k.begins_with("age_") or k in ["fat", "thin", "muscle"]):
				w.erase(k)
	out["weights"] = w
	# --- Pele -----------------------------------------------------------------------------
	var sk: float = f["skin_i"]
	var skc: Color = f["skin"]
	out["skin"] = Color.from_hsv(skc.h, skc.s * 0.8, skc.v * 0.97)
	out["dark"] = clampf((sk - 2.0) / 8.0, 0.0, 1.0)
	out["detail"] = "light"
	out["rosy"] = float(f.get("rosy", 0.3))
	var wr := float(f.get("wrinkles", 0.0))
	out["age"] = clampf((age - 25.0) / 25.0, 0.0, 1.0)
	out["wr_fore"] = clampf(wr * rng.randf_range(0.6, 1.2), 0.0, 1.2)
	out["wr_eyes"] = clampf(wr * rng.randf_range(0.6, 1.2), 0.0, 1.2)
	out["wr_naso"] = clampf(wr * rng.randf_range(0.5, 1.1) + fat * 0.2, 0.0, 1.2)
	out["eyebags"] = clampf(float(f.get("eyebags", 0.0)) * 0.7, 0.0, 1.0)
	out["circles"] = clampf(float(f.get("dark_circles", 0.0)) + rng.randf_range(0.0, 0.35), 0.0, 1.0)
	out["freckles"] = (rng.randf_range(0.6, 1.0) if bool(f.get("freckles", false)) else (rng.randf_range(0.0, 0.25) if sk < 2.5 else 0.0))
	out["spots"] = float(f.get("age_spots", 0.0))
	out["acne"] = rng.randf_range(0.2, 0.7) if (age < 22 and rng.randf() < 0.35) else 0.0
	out["oily"] = rng.randf_range(0.2, 0.9)
	out["lip_dark"] = rng.randf_range(0.0, 0.3)
	out["mole1"] = Vector4.ZERO
	out["mole2"] = Vector4.ZERO
	if bool(f.get("mole", false)):
		var mp: Vector2 = f.get("mole_pos", Vector2.ZERO)
		out["mole1"] = Vector4(mp.x * 0.6, 7.3 + mp.y * 0.9, rng.randf_range(0.012, 0.022), 1)
	if rng.randf() < 0.3:
		out["mole2"] = Vector4(rng.randf_range(-0.55, 0.55), rng.randf_range(7.1, 8.5), rng.randf_range(0.008, 0.014), 1)
	out["scar"] = Vector4.ZERO
	if bool(f.get("scar", false)):
		var sp: Vector2 = f.get("scar_pos", Vector2.ZERO)
		out["scar"] = Vector4(sp.x * 0.6, 8.0 + sp.y * 0.6, rng.randf_range(0.06, 0.16), rng.randf_range(0.0, PI))
	# --- Olhos ------------------------------------------------------------------------------
	out["iris"] = f.get("eye", Color("#58381F"))
	out["iris_in"] = f.get("eye_in", Color("#8A5A26"))
	out["iris_b"] = f.get("eye_b", f.get("eye", Color("#58381F")))
	out["iris_ring"] = float(f.get("eye_ring", 0.3)) if f.get("eye_ring") is float else 0.35
	out["limbal"] = float(f.get("limbal", 0.6))
	out["hetero"] = int(f.get("hetero", 0))
	out["pupil"] = rng.randf_range(0.2, 0.5)
	out["sclera"] = rng.randf_range(0.0, 0.5) + out["age"] * 0.3
	# --- Sobrancelhas -------------------------------------------------------------------------
	var bt := clampi(int(f.get("brow_type", 0)), 0, 11)
	var bi: int = bt if rng.randf() < 0.55 else [bt, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23][rng.randi_range(0, 12)]
	if bi == 16 and float(f.get("brow_t", 0.07)) > 0.07:
		bi = bt
	out["brow_shape"] = Face3DHair.BROWS[bi]
	out["brow_var"] = {"thick": float(f.get("brow_t", 0.07)) / 0.07 * rng.randf_range(0.9, 1.1), "arch": float(f.get("brow_arch", 0.03)) * 0.6 - 0.02,
		"tilt": float(f.get("brow_tilt", 0.0)) * 0.8, "len": float(f.get("brow_len", 0.45)) / 0.45, "dens": float(f.get("brow_dens", 0.8)) / 0.8,
		"gap": (float(f.get("brow_gap", 0.2)) - 0.2) * 0.6, "uni": bool(f.get("unibrow", false)), "slit": int(f.get("brow_slit", 0)),
		"hlen": 1.0 + float(f.get("brow_messy", 0.0)) * 0.6 + out["age"] * 0.3}
	# --- Cabelo ---------------------------------------------------------------------------
	var hair: Color = f["hair"]
	out["hair_col"] = hair
	out["gray"] = float(f.get("gray", 0.0))
	out["tips"] = 1.0 if bool(f.get("tips", false)) else 0.0
	out["highlights"] = 1.0 if bool(f.get("highlights", false)) else 0.0
	out["brow_col"] = hair.darkened(0.1).lerp(Color("#BDB8AF"), out["gray"] * 0.5) if hair.get_luminance() > 0.14 else hair.lightened(0.02)
	var style := clampi(int(f.get("style", 0)), 0, STYLE_MAP.size() - 1)
	var st: Dictionary = (Face3DHair.STYLES[STYLE_MAP[style]] as Dictionary).duplicate(true)
	_vary_style(st, f, rng)
	out["style"] = st
	out["style_name"] = STYLE_MAP[style]
	out["lighten"] = 0.75 if style in BLEACH_STYLES else 0.0
	out["hp"] = {"hairline": 8.72 - (float(f.get("hairline", -0.55)) + 0.55) * 0.9,
		"temples": clampf(float(f.get("recession", 0.0)), 0.0, 1.0), "crown": float(f.get("crown", 0.0)),
		"part_side": float(f.get("part_side", 1.0)), "widow": 1.0 if bool(f.get("widow", false)) else 0.0}
	# --- Barba ----------------------------------------------------------------------------
	var bd: Dictionary = FaceGen.BEARD_PARTS[clampi(int(f.get("beard", 0)), 0, FaceGen.BEARD_PARTS.size() - 1)]
	out["beard"] = bd
	out["beard_col"] = f.get("beard_col", hair)
	out["beard_pt"] = clampf(float(bd.get("pt", 0.0)) + float(f.get("beard_patch", 0.0)), 0.0, 1.0)
	out["shadow"] = float(f.get("shadow", 0.0))
	out["beard_curly"] = clampf(float(int(f.get("texture", 0))) / 3.0, 0.0, 1.0)
	out["seed"] = float(seed_v % 997)
	return out


## Variações individuais do corte: comprimento, degradê, volume, risco e textura natural do cabelo.
static func _vary_style(st: Dictionary, f: Dictionary, rng: RandomNumberGenerator) -> void:
	var k := rng.randf_range(0.85, 1.2)
	for key in ["c", "s"]:
		if st.has(key):
			var arr: Array = st[key]
			for i in arr.size():
				arr[i] = float(arr[i]) * (k if key == "c" else rng.randf_range(0.85, 1.15))
	if float(st.get("fade", 0.0)) > 0.0:
		st["fade"] = float(st["fade"]) + rng.randf_range(-0.15, 0.15)
	st["dens"] = float(st.get("dens", 0.7)) * rng.randf_range(0.9, 1.1)
	st["lift"] = clampf(float(st.get("lift", 0.2)) + rng.randf_range(-0.08, 0.08), 0.0, 1.0)
	st["mess"] = clampf(float(st.get("mess", 0.0)) + rng.randf_range(0.0, 0.15), 0.0, 1.0)
	var tex := int(f.get("texture", 0))
	var t := String(st.get("tex", "straight"))
	if t == "straight" and tex >= 1:
		st["tex"] = ["straight", "wavy", "curly", "coily"][tex]
		var ca: Array = st.get("curl", [0.0, 0.0])
		st["curl"] = [maxf(float(ca[0]), [0.0, 0.5, 1.0, 1.1][tex]), maxf(float(ca[1]), [0.0, 1.5, 3.5, 6.0][tex])]
		if tex == 3:
			st["coily"] = maxf(float(st.get("coily", 0.0)), 0.6)
			st["lift"] = maxf(float(st["lift"]), 0.5)
			st["cross"] = true
	var vol := float(f.get("vol", 0.5))
	if st.has("s") and float(st.get("coily", 0.0)) > 0.5:
		var s: Array = st["s"]
		for i in s.size():
			s[i] = float(s[i]) * lerpf(0.85, 1.15, vol)


static func _eyelid(s: String) -> bool:
	return s.begins_with("eye-height") or s.begins_with("eye-eyefold") or s.begins_with("eye-bag") or s.begins_with("a:l-eye-height") or s.begins_with("a:r-eye-height") or s.begins_with("eye-push")


static func _pm(w: Dictionary, base: String, v: float, pos := "more", neg := "less") -> void:
	v = clampf(v, -1.0, 1.0)
	if v >= 0.0:
		_add(w, "%s-%s" % [base, pos], v)
	else:
		_add(w, "%s-%s" % [base, neg], -v)


static func _add(w: Dictionary, k: String, v: float) -> void:
	w[k] = clampf(float(w.get(k, 0.0)) + v, -1.0, 1.2)
