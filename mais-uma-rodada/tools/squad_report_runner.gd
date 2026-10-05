extends Node
## Lógica de tools/squad_report.gd (carregada depois dos autoloads).

var opt_clubs := ""



func _ready() -> void:
	var names: Array = ["Flamengo", "Real Madrid", "Manchester City", "Boca Juniors", "Cuiabá", "Brentford", "Mirassol", "Al Hilal", "Inter Miami", "Athletic Club"]
	if opt_clubs != "":
		names = Array(opt_clubs.split(","))
	SquadStory.keep = true
	var t0 := Time.get_ticks_msec()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	print("mundo em %.1fs · %d jogadores" % [(Time.get_ticks_msec() - t0) / 1000.0, w.players.size()])
	for n in names:
		for c: Club in w.clubs:
			if c.name == n or c.short_name == n:
				_club(w, c)
				break
	_world(w)
	get_tree().quit()


func _club(w: GameWorld, c: Club) -> void:
	var sq := w.squad(c)
	sq.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	print("\n== %s (%s, rep %.0f, %s) · %d jogadores" % [c.name, c.league_id, c.reputation, c.archetype, sq.size()])
	for p: Player in sq:
		var top := _top_attrs(p)
		var role := String(SquadStory.roles.get(p.id, ""))
		print("  %-3s %-22s %2d %-3s ovr %2d pot %2d  %-9s %-12s %-10s %s anos %-28s %s" % [Pos.code(p.position), p.display_name().substr(0, 22),
			p.age(w.year), p.nationality, p.overall, p.potential, Player.STATUS_NAMES[p.squad_status], p.signature, role,
			"%d" % (w.year - p.joined_year), _spells(p, role != ""), top])


func _top_attrs(p: Player) -> String:
	var idx: Array = []
	for i in Attr.COUNT:
		idx.append(i)
	idx.sort_custom(func(a, b): return p.attrs[a] > p.attrs[b])
	var s := ""
	for k in 3:
		s += "%s %d " % [Attr.SHORT[idx[k]], p.attrs[idx[k]]]
	return s


func _world(w: GameWorld) -> void:
	var gaps: Array = []
	var spreads: Array = []
	var top1 := 0
	var roles := {}
	for c: Club in w.clubs:
		if c.tier != 1:
			continue
		var sq := w.squad(c)
		sq.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
		var avg := 0.0
		for i in mini(11, sq.size()):
			avg += sq[i].ovr_f
		avg /= maxf(1, mini(11, sq.size()))
		gaps.append(sq[0].ovr_f - avg)
		spreads.append(sq[0].ovr_f - sq[mini(10, sq.size() - 1)].ovr_f)
		for p: Player in sq:
			var r := String(SquadStory.roles.get(p.id, ""))
			if r != "":
				roles[r] = int(roles.get(r, 0)) + 1
	gaps.sort()
	spreads.sort()
	print("\n== 1ª divisão: craque − média do XI: p10 %.1f · med %.1f · p90 %.1f" % [gaps[gaps.size() / 10], gaps[gaps.size() / 2], gaps[gaps.size() * 9 / 10]])
	print("   melhor − 11º: p10 %.1f · med %.1f · p90 %.1f" % [spreads[spreads.size() / 10], spreads[spreads.size() / 2], spreads[spreads.size() * 9 / 10]])
	print("   papéis: %s" % str(roles))
	var hist := {}
	for p: Player in w.players.values():
		var b := int(p.overall / 5) * 5
		hist[b] = int(hist.get(b, 0)) + 1
	var ks := hist.keys()
	ks.sort()
	var line := ""
	for k in ks:
		line += "%d:%d " % [k, hist[k]]
	print("   overall: " + line)


func _spells(p: Player, full := false) -> String:
	var out: Array = []
	for sp: Dictionary in p.spells:
		out.append(String(sp.get("cn", "?")).substr(0, 8))
	var s := ">".join(out)
	return s if full else s.substr(maxi(0, s.length() - 28))
