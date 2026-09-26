extends BaseScreen
## Elencos antigos de um clube, temporada por temporada: quem jogou, com que camisa, quantos
## jogos, gols e a nota. As temporadas jogadas na carreira vêm do arquivo do clube; as de antes
## do início do jogo saem da carreira de cada jogador. Toque num nome para abrir o perfil.

var _club_id := -1
var _year := 0


func _init() -> void:
	show_nav = false
	screen_title = "Elencos anteriores"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_club_id = int(p.get("id", -1))
	_year = int(p.get("year", 0))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _club_id < 0:
		_club_id = w.user_club_id
	var club := w.club(_club_id)
	screen_subtitle = club.short_name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var years := seasons_of(w, club)
	if years.is_empty():
		c.add_child(UIKit.label("Ainda não há temporadas encerradas para mostrar.", "Muted", true))
		return
	if _year == 0 or not years.has(_year):
		_year = years[0]
	var i := years.find(_year)
	# Seletor de temporada
	var nav := UIKit.hbox(10)
	var prev := UIKit.button("‹ %d" % years[i + 1] if i + 1 < years.size() else "‹", "GhostButton", func():
		if i + 1 < years.size():
			_year = years[i + 1]
			refresh())
	prev.disabled = i + 1 >= years.size()
	nav.add_child(prev)
	var yl := UIKit.label("Temporada %d" % _year, "Title")
	yl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(yl)
	var nxt := UIKit.button("%d ›" % years[i - 1] if i > 0 else "›", "GhostButton", func():
		if i > 0:
			_year = years[i - 1]
			refresh())
	nxt.disabled = i <= 0
	nav.add_child(nxt)
	c.add_child(nav)
	# Campanha e títulos daquele ano
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.crest(club, 64))
	for line in _campaign(w, club, _year):
		card.add_child(UIKit.label(line, "H3", true))
	c.add_child(UIKit.card_panel(card))
	# Elenco
	var rows := squad_of(w, club, _year)
	var list := UIKit.card("Card", 6)
	var hdr := UIKit.hbox(8)
	var hl := UIKit.label("Nº  Jogador", "Caps")
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hl)
	hdr.add_child(UIKit.label("J   G   A   NOTA", "Caps"))
	list.add_child(hdr)
	for r: Dictionary in rows:
		var line := UIKit.hbox(8)
		line.add_child(UIKit.pos_badge(int(r.get("pos", Pos.CM))))
		var sh := UIKit.label(str(int(r.get("sh", 0))) if int(r.get("sh", 0)) > 0 else "–", "Mono")
		sh.custom_minimum_size.x = 40
		line.add_child(sh)
		var nm := UIKit.label(String(r.get("n", "?")), "")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(nm)
		var rt := float(r.get("r", 0.0))
		line.add_child(UIKit.label("%2d  %2d  %2d  %s" % [int(r.get("a", 0)), int(r.get("g", 0)), int(r.get("as", 0)), Fmt.rating(rt) if rt > 0.0 else "—"], "Mono"))
		var pid := int(r.get("id", -1))
		if pid >= 0 and w.player(pid) != null:
			list.add_child(UIKit.tap_row(line, func(): UIManager.push("player", {"id": pid}), "CardFlat"))
		else:
			list.add_child(line)
	if rows.is_empty():
		list.add_child(UIKit.label("Sem registros dessa temporada.", "Muted", true))
	c.add_child(UIKit.card_panel(list))
	# Destaques
	var top_g: Dictionary = {}
	var top_a: Dictionary = {}
	for r: Dictionary in rows:
		if top_g.is_empty() or int(r.get("g", 0)) > int(top_g.get("g", 0)):
			top_g = r
		if top_a.is_empty() or int(r.get("a", 0)) > int(top_a.get("a", 0)):
			top_a = r
	if not top_g.is_empty() and int(top_g.get("g", 0)) > 0:
		var hi := UIKit.card("Card", 4)
		hi.add_child(UIKit.kv("Artilheiro", "%s (%d)" % [top_g["n"], int(top_g["g"])], UIColors.ACCENT))
		hi.add_child(UIKit.kv("Mais jogos", "%s (%d)" % [top_a["n"], int(top_a["a"])]))
		c.add_child(UIKit.card_panel(hi))


## Temporadas com registro (mais recente primeiro).
static func seasons_of(w: GameWorld, club: Club) -> Array:
	var ys := {}
	for k in club.squad_archive:
		ys[int(k)] = true
	for p: Player in w.players.values():
		for h: Dictionary in p.history:
			if int(h.get("c", -1)) == club.id:
				ys[int(h.get("y", 0))] = true
	var out: Array = ys.keys()
	out.sort()
	out.reverse()
	return out


## Elenco de um ano: o arquivo do clube, completado com a carreira de quem ainda está no jogo.
static func squad_of(w: GameWorld, club: Club, y: int) -> Array:
	var rows: Array = []
	var seen := {}
	for r: Dictionary in club.squad_archive.get(str(y), []):
		rows.append(r)
		seen[int(r.get("id", -1))] = true
	for p: Player in w.players.values():
		if seen.has(p.id):
			continue
		for h: Dictionary in p.history:
			if int(h.get("c", -1)) == club.id and int(h.get("y", 0)) == y:
				rows.append({"id": p.id, "n": p.display_name(), "pos": p.position, "sh": 0,
					"a": int(h.get("a", 0)) + int(h.get("ca", 0)), "g": int(h.get("g", 0)) + int(h.get("cg", 0)),
					"as": int(h.get("as", 0)) + int(h.get("cas", 0)), "r": float(h.get("r", 0.0))})
				break
	rows.sort_custom(func(a, b):
		var pa := Pos.DISPLAY_ORDER.find(int(a.get("pos", 0)))
		var pb := Pos.DISPLAY_ORDER.find(int(b.get("pos", 0)))
		return pa < pb if pa != pb else int(a.get("a", 0)) > int(b.get("a", 0)))
	return rows


## "Campeão da Premier League", "3º na Série A"...
static func _campaign(w: GameWorld, club: Club, y: int) -> Array:
	var out: Array = []
	for h: Dictionary in club.history:
		if int(h.get("y", 0)) == y:
			out.append("%dº lugar · %s · %d pts" % [int(h.get("p", 0)), w.league_short(String(h.get("l", ""))), int(h.get("pts", 0))])
	for s: Dictionary in w.history:
		if int(s.get("y", 0)) != y:
			continue
		for lid in s.get("leagues", {}):
			if int(s["leagues"][lid].get("champion", -1)) == club.id:
				out.append("Campeão · %s" % w.league_short(String(lid)))
		for cid in s.get("cups", {}):
			if int(s["cups"][cid].get("champion", -1)) == club.id:
				out.append("Campeão · %s" % CupManager.cup_name(String(cid)))
	if out.is_empty():
		out.append("Temporada %d" % y)
	return out
