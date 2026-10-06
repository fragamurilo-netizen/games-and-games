class_name KitPresentation
extends RefCounted
## Apresentação dos uniformes (só no lançamento, SocialPost.show_launch): cada camisa vestida por
## um jogador do elenco, em foto de estúdio (busto). Titular no melhor jogador, reserva no segundo,
## terceiro uniforme no terceiro e o de goleiro no goleiro titular.

const NAMES := {"home": "Titular", "away": "Reserva", "third": "Terceiro", "gk": "Goleiro"}


## Quem veste cada camisa: {"home": Player, "away": Player, "third": Player, "gk": Player}.
static func models(w: GameWorld, club: Club) -> Dictionary:
	var squad: Array = w.squad(club)
	var field: Array = squad.filter(func(p: Player): return p.position != Pos.GK)
	var gks: Array = squad.filter(func(p: Player): return p.position == Pos.GK)
	field.sort_custom(func(a: Player, b: Player): return a.ovr_f > b.ovr_f if a.ovr_f != b.ovr_f else a.id < b.id)
	gks.sort_custom(func(a: Player, b: Player): return a.ovr_f > b.ovr_f if a.ovr_f != b.ovr_f else a.id < b.id)
	var out := {}
	var keys := ["home", "away", "third"]
	for i in mini(3, field.size()):
		out[keys[i]] = field[i]
	if not gks.is_empty():
		out["gk"] = gks[0]
	return out


static func kit_of(club: Club, key: String) -> Dictionary:
	match key:
		"away":
			return club.kit_away
		"third":
			return club.third_kit()
		"gk":
			return club.gk_kit()
	return club.kit_home


## As quatro fotos em grade (`cols` colunas). `px` = largura de cada foto; com nomes embaixo.
static func grid(w: GameWorld, club: Club, px: float, cols: int = 2, with_names: bool = true) -> GridContainer:
	var h := GridContainer.new()
	h.columns = cols
	h.add_theme_constant_override(&"h_separation", UITokens.S2)
	h.add_theme_constant_override(&"v_separation", UITokens.S2)
	var who := models(w, club)
	for key in ["home", "away", "third", "gk"]:
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var p: Player = who.get(key)
		if p != null:
			var ph := PhotoPortrait.new()
			ph.custom_minimum_size = Vector2(px, px * 1.15)
			ph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ph.bust = true
			ph.mood = PhotoPortrait.for_moment("uniforme")
			ph.set_player(p, club, w.year, kit_of(club, key))
			v.add_child(ph)
		else:
			var kv := UIKit.kit(kit_of(club, key), int(px * 0.8), 0, club.crest)
			kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(kv)
		var l := UIKit.label(String(NAMES[key]), "Caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		if with_names and p != null:
			var n := UIKit.label(p.short_name(), "Small")
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			n.custom_minimum_size.x = 40
			v.add_child(n)
		h.add_child(v)
	return h
