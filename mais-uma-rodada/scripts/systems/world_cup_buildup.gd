class_name WorldCupBuildup
extends RefCounted
## O clima dos torneios de seleções ao longo da temporada que os antecede: "ano de Copa" na
## abertura, a contagem regressiva depois das eliminatórias, a lista final e o balanço da campanha
## da seleção do usuário (a do país do clube e a que ele comanda). Só notícias e mensagens: nada
## aqui mexe na simulação. As marcas de "já anunciado" ficam em world.stats["intl"]["hype"].


static func _done(world: GameWorld, key_: String) -> bool:
	var key := "%s:%d" % [key_, world.year]
	var d := NationalTeamManager.data(world)
	if not d.has("hype"):
		d["hype"] = {}
	var h: Dictionary = d["hype"]
	if h.has(key):
		return true
	h[key] = world.year
	# Só a temporada corrente importa.
	for k in h.keys():
		if int(h[k]) < world.year - 1:
			h.erase(k)
	return false


## Seleções que importam ao usuário (a que comanda primeiro).
static func _user_codes(world: GameWorld) -> Array:
	var out: Array = []
	if not world.has_user():
		return out
	for c in [NationalCoach.nation(world), world.user_nation()]:
		if c != "" and not out.has(c):
			out.append(c)
	return out


## Torneios disputados no verão que fecha esta temporada.
static func _summer_tours(world: GameWorld) -> Array:
	var out: Array = []
	for id in NationalTeamManager.tournament_ids():
		if NationalTeamManager.next_edition(id, world.year + 1) == world.year + 1:
			out.append(id)
	return out


## O torneio "da casa" do usuário: a Copa do Mundo, se houver; senão o continental da confederação dele.
static func _relevant(world: GameWorld, id: String) -> bool:
	if id == "WC":
		return true
	var entry: Dictionary = NationalTeamManager.tcfg(id).get("entry", {})
	var guests: Dictionary = NationalTeamManager.tcfg(id).get("guests", {})
	for c in _user_codes(world):
		var confed := String(DatabaseManager.nation(c).get("confed", ""))
		if entry.has(confed) or guests.has(confed):
			return true
	return false


static func _favorites(world: GameWorld, pool: Array, n: int) -> Array:
	var l := pool.duplicate()
	l.sort_custom(func(a, b): return NationalTeamManager.elo_of(world, a) > NationalTeamManager.elo_of(world, b))
	return l.slice(0, n)


static func _eligible_pool(id: String) -> Array:
	var out: Array = []
	var c := NationalTeamManager.tcfg(id)
	var confeds: Array = (c.get("entry", {}) as Dictionary).keys() + (c.get("guests", {}) as Dictionary).keys()
	for conf in confeds:
		out.append_array(NationalTeamManager.nations_of(String(conf)))
	return out


static func _status_line(world: GameWorld, id: String, y: int, code: String) -> String:
	var name := DatabaseManager.nation_name(code)
	if NationalTeamManager.host_of(id, y) == code:
		return "%s é a sede e está garantida." % name
	for camp in NationalTeamManager.data(world)["camps"]:
		if String(camp["t"]) != id or int(camp["y"]) != y or not NationalTeamManager._in_campaign(camp, code):
			continue
		if bool(camp["done"]):
			return ("%s já está classificada." % name) if (camp["q"] as Array).has(code) else ("%s ficou fora pelas eliminatórias." % name)
		for g in camp["groups"]:
			if g["teams"].has(code):
				var order := NationalTeamManager.sort_group(g)
				return "%s é a %dª do grupo %s nas eliminatórias (%d vaga(s) para a confederação)." % [name, order.find(code) + 1, g["n"], int(camp["spots"])]
	return "%s disputa a vaga pelo ranking." % name


## Abertura da temporada que termina com um torneio de seleções.
static func on_season_start(world: GameWorld) -> void:
	for id in _summer_tours(world):
		if not _relevant(world, id) or _done(world, "open:%s" % id):
			continue
		var y := world.year + 1
		var host := NationalTeamManager.host_of(id, y)
		var fav := _favorites(world, _eligible_pool(id), 4)
		var body := "%s recebe a %s %d, com %d seleções. Favoritas no ranking: %s." % [DatabaseManager.nation_name(host), NationalTeamManager.tournament_name(id), y,
			int(NationalTeamManager.tcfg(id).get("teams", 0)), NationalTeamManager._names(fav)]
		for c in _user_codes(world):
			body += " " + _status_line(world, id, y, c)
		var n := NewsManager.post_raw(world, "Ano de %s: a contagem regressiva começou" % NationalTeamManager.tournament_name(id), body, -1, -1,
			NewsEvent.IMP_HEADLINE if id == "WC" else NewsEvent.IMP_HIGH, "selecao")
		n.media = {"type": "nation", "code": host, "trophy": true}


## Ao longo da temporada: fim das eliminatórias (quem está dentro) e "a um mês do torneio".
static func after_weekend(world: GameWorld, weekend_index: int, dates: Array) -> void:
	if world.season == null or dates.is_empty():
		return
	var last_fifa := int(dates.max())
	var weekends := 0
	for e in world.season.calendar:
		if e["t"] == "W":
			weekends += 1
	for id in _summer_tours(world):
		if not _relevant(world, id):
			continue
		var y := world.year + 1
		var tname := NationalTeamManager.tournament_name(id)
		if weekend_index == last_fifa + 1 and not _done(world, "quals:%s" % id):
			var q: Array = []
			var host := NationalTeamManager.host_of(id, y)
			if host != "":
				q.append(host)
			for camp in NationalTeamManager.data(world)["camps"]:
				if String(camp["t"]) == id and int(camp["y"]) == y and bool(camp["done"]):
					q.append_array(camp["q"])
			if not q.is_empty():
				var body := "Terminaram as eliminatórias: %d seleções já têm lugar na %s %d. Entre elas, as mais fortes: %s." % [q.size(), tname, y,
					NationalTeamManager._names(_favorites(world, q, 5))]
				var po := int(NationalTeamManager.tcfg(id).get("playoff", 0))
				if po > 0:
					body += " As últimas %d vagas saem da repescagem, às vésperas do torneio." % po
				for c in _user_codes(world):
					body += " " + _status_line(world, id, y, c)
				NewsManager.post_raw(world, "%s %d: quem já está dentro" % [tname, y], body, -1, -1, NewsEvent.IMP_HIGH, "selecao")
		if weekend_index == weekends - 4 and not _done(world, "month:%s" % id):
			_month_before(world, id, y)


## "A um mês": sede, favoritos e quem do elenco do usuário está cotado para a lista final.
static func _month_before(world: GameWorld, id: String, y: int) -> void:
	var tname := NationalTeamManager.tournament_name(id)
	var fav := _favorites(world, _eligible_pool(id), 3)
	var body := "Falta pouco para a %s %d em %s. Favoritas: %s." % [tname, y, DatabaseManager.nation_name(NationalTeamManager.host_of(id, y)), NationalTeamManager._names(fav)]
	var n := NewsManager.post_raw(world, "A um mês da %s" % tname, body, -1, -1, NewsEvent.IMP_HIGH if id == "WC" else NewsEvent.IMP_NORMAL, "selecao")
	n.media = {"type": "nation", "code": NationalTeamManager.host_of(id, y), "trophy": true}
	if not world.has_user():
		return
	# Cotados do elenco: estavam na última lista das suas seleções.
	var squads: Dictionary = NationalTeamManager.data(world)["squads"]
	var cotados: Array = []
	for p in world.squad(world.user_club()):
		if (squads.get(p.nationality, []) as Array).has(p.id) and _eligible_pool(id).has(p.nationality):
			cotados.append("%s (%s)" % [p.display_name(), DatabaseManager.nation_name(p.nationality)])
	if not cotados.is_empty():
		InboxManager.send(world, "imprensa", "Cotados para a %s" % tname,
			"Estes jogadores do elenco estiveram na última convocação e devem ir ao torneio no fim da temporada: %s.\n\nQuem joga o verão inteiro volta mais tarde para a pré-temporada." % ", ".join(cotados),
			{"k": "screen", "s": "national", "args": {"tab": "tours"}})


## Lista final das seleções do usuário para o torneio, e quem do clube vai.
static func final_lists(world: GameWorld, env: NationalTeamManager.Env, id: String, y: int, teams: Array) -> void:
	if not world.has_user():
		return
	var tname := NationalTeamManager.tournament_name(id)
	for c in _user_codes(world):
		if not teams.has(c):
			continue
		var ids: Array = env.squad(c).map(func(p: Player): return p.id)
		if ids.size() < 11:
			continue
		var mine: bool = c == NationalCoach.nation(world)
		var title := ("Sua lista final para a %s" % tname) if mine else ("%s anuncia a lista final para a %s" % [DatabaseManager.nation_name(c), tname])
		var n := NewsManager.post_raw(world, title, "Os %d nomes da %s para a %s %d: %s" % [ids.size(), DatabaseManager.nation_name(c), tname, y, NationalTeamManager.squad_text(world, ids)],
			-1, int(ids[0]), NewsEvent.IMP_HIGH, "selecao")
		n.media = {"type": "nation", "code": c}


## Balanço da campanha das seleções do usuário no torneio: grupo e mata-mata.
static func campaign_news(world: GameWorld, rec: Dictionary) -> void:
	if not world.has_user():
		return
	for c in _user_codes(world):
		if not (rec["teams"] as Array).has(c):
			continue
		var parts: Array = []
		for g in rec.get("groups", []):
			var order: Array = g["order"]
			var i := order.find(c)
			if i >= 0:
				var r: Dictionary = g["table"][c]
				parts.append("%dª no grupo %s (%d pontos, %d gols pró, %d contra)" % [i + 1, g["n"], int(r["pts"]), int(r["gf"]), int(r["ga"])])
		for rd in rec.get("ko", []):
			for m in rd["m"]:
				if m[0] == c or m[1] == c:
					var r := {"a": m[0], "b": m[1], "ga": m[2], "gb": m[3], "pa": m[4], "pb": m[5], "et": m[6]}
					parts.append("%s: %s" % [String(rd["n"]).to_lower(), NationalTeamManager.result_text(r)])
		var stage := String(rec.get("stage", {}).get(c, ""))
		var mine: bool = c == NationalCoach.nation(world)
		var head := "campeã" if stage == "Campeã" else ("vice-campeã" if stage == "Vice" else ("fora na fase de grupos" if stage == "Fase de grupos" else "parou na %s" % stage.to_lower()))
		var n := NewsManager.post_raw(world, "%s na %s: %s" % [DatabaseManager.nation_name(c), rec["name"], head],
			"%s%s." % ["Sua campanha no comando: " if mine else "A campanha: ", "; ".join(parts)], -1, -1,
			NewsEvent.IMP_HEADLINE if mine else NewsEvent.IMP_HIGH, "selecao")
		n.media = {"type": "nation", "code": c, "trophy": stage == "Campeã"}
