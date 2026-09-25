class_name Rivalry
extends RefCounted
## Rivalidade emergente: clássicos que nascem da história do próprio save.
##
## Cada par de clubes que já viveu algo marcante ganha um registro em world.rivalries
## (chave "menor:maior"): um termômetro de 0 a 100, os confrontos desde que a rixa começou e os
## momentos que a alimentaram. Eliminações em copa, finais, título decidido no detalhe, goleadas,
## expulsões, gol no fim e jogadores importantes trocando de lado esquentam o termômetro; o tempo
## esfria. Passou de 50, o jogo trata como clássico (MatchEngine.is_derby): público, diretoria,
## torcida, imprensa e narração reagem como a um clássico de verdade.
##
## Não usa o RNG do mundo (as partidas sorteiam igual com ou sem rivalidades).
## Os momentos ficam em "ev" como {y, t, p, k} (ano, texto, pontos, tipo) para quem quiser
## contar a história do save depois.

const RIXA_AT := 25.0
const DERBY_AT := 50.0
const BIG_AT := 75.0
const STATIC_FLOOR := 55.0 # rivais de origem nunca esfriam abaixo disto
const DECAY := 0.88 # por temporada, em direção ao piso
const PRUNE_BELOW := 8.0 # abaixo disto (e sem nunca ter virado rixa) o par é esquecido na virada de ano
const MAX_EVENTS := 12
const LEVEL_NAMES: Array[String] = ["", "Rixa", "Clássico", "Grande clássico"]


static func key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


static func get_rec(world: GameWorld, a: int, b: int) -> Dictionary:
	return world.rivalries.get(key(a, b), {})


static func _is_static(world: GameWorld, a: int, b: int) -> bool:
	var ca := world.club(a)
	var cb := world.club(b)
	return ca != null and cb != null and (ca.is_rival(b) or cb.is_rival(a))


static func _floor(world: GameWorld, a: int, b: int) -> float:
	return STATIC_FLOOR if _is_static(world, a, b) else 0.0


static func _rec(world: GameWorld, a: int, b: int) -> Dictionary:
	var k := key(a, b)
	if not world.rivalries.has(k):
		var fl := _floor(world, a, b)
		world.rivalries[k] = {"a": mini(a, b), "b": maxi(a, b), "s": fl, "pk": fl, "y0": world.year,
			"g": 0, "wa": 0, "wb": 0, "d": 0, "lv": level_of(fl), "ev": []}
	return world.rivalries[k]


## Termômetro 0..100 do par (rivais de origem valem pelo menos o piso).
static func heat(world: GameWorld, a: int, b: int) -> float:
	var r := get_rec(world, a, b)
	var s := float(r.get("s", 0.0))
	return maxf(s, STATIC_FLOOR) if _is_static(world, a, b) else s


static func level_of(s: float) -> int:
	if s >= BIG_AT:
		return 3
	if s >= DERBY_AT:
		return 2
	if s >= RIXA_AT:
		return 1
	return 0


static func level_name(s: float) -> String:
	return LEVEL_NAMES[level_of(s)]


## Clássico que nasceu durante o save (não estava no mapa de rivais de origem).
static func is_emergent_derby(world: GameWorld, a: int, b: int) -> bool:
	return not _is_static(world, a, b) and float(get_rec(world, a, b).get("s", 0.0)) >= DERBY_AT


## Fator de público: rixas já enchem mais o estádio; clássicos muito quentes esgotam.
static func attendance_factor(world: GameWorld, a: int, b: int, derby: bool) -> float:
	var h := heat(world, a, b)
	if derby:
		return 1.0 + maxf(0.0, h - 60.0) * 0.003
	return 1.0 + clampf(h, 0.0, DERBY_AT) * 0.004


## Peso extra na importância do jogo (a diretoria dá mais valor à partida).
static func importance_bonus(world: GameWorld, a: int, b: int, derby: bool) -> float:
	var h := heat(world, a, b)
	if derby:
		return maxf(0.0, h - 60.0) * 0.002
	return clampf(h, 0.0, DERBY_AT) * 0.003


## Retrospecto do ponto de vista de `cid`: {w, d, l, g, since}.
static func record_for(world: GameWorld, cid: int, other: int) -> Dictionary:
	var r := get_rec(world, cid, other)
	if r.is_empty():
		return {"w": 0, "d": 0, "l": 0, "g": 0, "since": world.year}
	var mine_a := int(r["a"]) == cid
	return {"w": int(r["wa"] if mine_a else r["wb"]), "d": int(r["d"]), "l": int(r["wb"] if mine_a else r["wa"]),
		"g": int(r["g"]), "since": int(r["y0"])}


## Rivalidades de um clube, da mais quente para a mais fria: [{club, heat, level, rec}].
## Inclui os rivais de origem mesmo que ainda não tenham se enfrentado no save.
static func of_club(world: GameWorld, cid: int, min_heat: float = RIXA_AT) -> Array:
	var out: Array = []
	var seen := {}
	var c := world.club(cid)
	if c == null:
		return out
	for rid in c.rivals:
		var o := int(rid)
		if o >= 0 and not seen.has(o) and world.club(o) != null:
			seen[o] = true
			out.append({"club": o, "heat": heat(world, cid, o), "rec": get_rec(world, cid, o)})
	for k: String in world.rivalries:
		var r: Dictionary = world.rivalries[k]
		var o := -1
		if int(r["a"]) == cid:
			o = int(r["b"])
		elif int(r["b"]) == cid:
			o = int(r["a"])
		if o < 0 or seen.has(o):
			continue
		var h := heat(world, cid, o)
		if h >= min_heat:
			seen[o] = true
			out.append({"club": o, "heat": h, "rec": r})
	out.sort_custom(func(x, y): return float(x["heat"]) > float(y["heat"]) or (float(x["heat"]) == float(y["heat"]) and int(x["club"]) < int(y["club"])))
	for e in out:
		e["level"] = level_of(float(e["heat"]))
	return out


## Momento mais recente em que `other` levou a melhor sobre `cid` (para "revanche"), ou {}.
static func last_grudge(world: GameWorld, cid: int, other: int) -> Dictionary:
	var ev: Array = get_rec(world, cid, other).get("ev", [])
	for i in range(ev.size() - 1, -1, -1):
		var e: Dictionary = ev[i]
		if int(e.get("w", -1)) == other and float(e.get("p", 0.0)) >= 5.0:
			return e
	return {}


# ---------------------------------------------------------------------------
# O que esquenta
# ---------------------------------------------------------------------------

## Soma pontos ao par e guarda o momento (se for marcante). `winner` = quem levou a melhor (-1 = ninguém).
static func add(world: GameWorld, a: int, b: int, pts: float, text: String = "", kind: String = "", winner: int = -1) -> void:
	if a == b or a < 0 or b < 0 or pts <= 0.0:
		return
	var r := _rec(world, a, b)
	var s := minf(100.0, float(r["s"]) + pts)
	r["s"] = snappedf(s, 0.1)
	r["pk"] = maxf(float(r.get("pk", 0.0)), float(r["s"]))
	if text != "" and pts >= 3.0:
		var ev: Array = r["ev"]
		ev.append({"y": world.year, "t": text, "p": snappedf(pts, 0.1), "k": kind, "w": winner})
		if ev.size() > MAX_EVENTS:
			# Esquece o momento menos marcante (os grandes ficam para sempre)
			var worst := 0
			for i in ev.size() - 1:
				if float(ev[i]["p"]) < float(ev[worst]["p"]):
					worst = i
			ev.remove_at(worst)
	_check_level(world, r)


## Cada jogo oficial da data. entries: [{f, res}].
static func after_matchday(world: GameWorld, entries: Array) -> void:
	if world.season == null:
		return
	for e in entries:
		var f: Fixture = e["f"]
		if not f.played:
			continue
		var cup: Cup = world.season.cups.get(f.comp, null)
		var league := world.league(f.comp)
		if cup == null and league == null:
			continue # amistosos não contam
		_after_match(world, f, league, cup, e.get("res", {}))


static func _after_match(world: GameWorld, f: Fixture, league: League, cup: Cup, res: Dictionary) -> void:
	var home := world.club(f.home)
	var away := world.club(f.away)
	var diff := f.hg - f.ag
	var winner := f.home if diff > 0 else (f.away if diff < 0 else -1)
	var pts := 0.0
	var text := ""
	var kind := ""
	var is_ko := f.stage == Fixture.STAGE_KO
	if is_ko:
		pts += 1.0
	# Duelo direto no topo da tabela na reta final
	if league != null and f.stage != Fixture.STAGE_KO and league.rounds.size() > 1:
		var progress := float(f.round) / float(league.rounds.size() - 1)
		if progress >= 0.5:
			var ph := CompetitionManager.position_of(league, f.home)
			var pa := CompetitionManager.position_of(league, f.away)
			if ph <= 3 and pa <= 3:
				pts += 2.0
	# Goleada
	if absi(diff) >= 4:
		var w := world.club(winner)
		var l := away if winner == f.home else home
		pts += 3.0 + minf(3.0, float(absi(diff) - 4))
		if absi(diff) >= 5:
			text = "%s %d x %d %s: goleada do %s que o %s não esquece" % [home.short_name, f.hg, f.ag, away.short_name, w.short_name, l.short_name]
		else:
			text = "%s %d x %d %s: goleada do %s" % [home.short_name, f.hg, f.ag, away.short_name, w.short_name]
		kind = "goleada"
	# Expulsões
	var rc: Array = res.get("rc", [0, 0])
	var reds := int(rc[0]) + int(rc[1]) if rc.size() == 2 else 0
	if reds > 0:
		pts += 1.5 * reds
		if text == "" and reds >= 2:
			text = "%s x %s termina com %d expulsos" % [home.short_name, away.short_name, reds]
			kind = "expulsoes"
	# Gol decisivo no fim
	if not f.goals.is_empty() and absi(diff) <= 1:
		var last: Array = f.goals[f.goals.size() - 1]
		var minute := int(last[0])
		var side := int(last[1])
		var scorer_club := f.home if side == 0 else f.away
		if minute >= 88 and (winner == scorer_club or winner == -1):
			pts += 2.0
			if text == "":
				var sp := world.player(int(last[2]))
				var who := sp.display_name() if sp != null else world.club(scorer_club).short_name
				if winner == scorer_club:
					text = "%s decide %s x %s aos %d'" % [who, home.short_name, away.short_name, minute]
				else:
					text = "%s empata %s x %s aos %d'" % [who, home.short_name, away.short_name, minute]
				kind = "gol_fim"
	# Só um momento marcante abre um registro novo (jogo comum entre clubes sem história não é guardado).
	var rec_exists := world.rivalries.has(key(f.home, f.away))
	if pts >= 3.0 or rec_exists or _is_static(world, f.home, f.away):
		var r := _rec(world, f.home, f.away)
		r["g"] = int(r["g"]) + 1
		if winner < 0:
			r["d"] = int(r["d"]) + 1
		elif winner == int(r["a"]):
			r["wa"] = int(r["wa"]) + 1
		else:
			r["wb"] = int(r["wb"]) + 1
		# Pares que já têm história esquentam um pouco a cada reencontro.
		if float(r["s"]) >= RIXA_AT:
			pts += 1.0
		add(world, f.home, f.away, pts, text, kind, winner)


## Eventos de copa da data (CupManager.after_slot): eliminações e finais.
static func on_cup_events(world: GameWorld, events: Array) -> void:
	for ev: Dictionary in events:
		if String(ev.get("t", "")) != "out" or not ev.has("by"):
			continue
		var cup: Cup = world.season.cups.get(String(ev["cup"]), null) if world.season != null else null
		if cup == null:
			continue
		var loser := int(ev["club"])
		var winner := int(ev["by"])
		var stage := String(ev.get("stage", ""))
		var depth := cup.round_names.size() - 1 - cup.round_names.find(stage)
		var pts := 14.0 if depth == 0 else (10.0 if depth == 1 else (7.0 if depth == 2 else 5.0))
		if CupManager.is_international(cup.id):
			pts += 2.0
		# Eliminar o mesmo clube de novo dói mais
		var prev := 0
		for e: Dictionary in get_rec(world, loser, winner).get("ev", []):
			if String(e.get("k", "")) in ["elim", "final"] and int(e.get("w", -1)) == winner:
				prev += 1
		pts += 3.0 * mini(prev, 3)
		var w := world.club(winner)
		var l := world.club(loser)
		var cname := CupManager.cup_short(cup.id)
		var text := ""
		if depth == 0 and prev >= 1:
			text = "%s vence o %s na final da %s %d: %dª vez" % [w.short_name, l.short_name, cname, world.year, prev + 1]
		elif depth == 0:
			text = "%s vence o %s na final da %s %d" % [w.short_name, l.short_name, cname, world.year]
		elif prev >= 1:
			text = "%s elimina o %s (%s, %s %d): %dª vez" % [w.short_name, l.short_name, stage, cname, world.year, prev + 1]
		else:
			text = "%s elimina o %s (%s, %s %d)" % [w.short_name, l.short_name, stage, cname, world.year]
		add(world, winner, loser, pts, text, "final" if depth == 0 else "elim", winner)


## Campeão e vice da liga (virada de ano): título decidido no detalhe cria rixa.
static func on_league_end(world: GameWorld, league: League, champ: int, runner: int) -> void:
	if champ < 0 or runner < 0 or champ == runner or not league.table.has(champ) or not league.table.has(runner):
		return
	var gap := int(league.table[champ]["pts"]) - int(league.table[runner]["pts"])
	var c := world.club(champ)
	var r := world.club(runner)
	if gap <= 3:
		var text := "%s tira o título de %d do %s no saldo" % [c.short_name, world.year, r.short_name]
		if gap == 1:
			text = "%s tira o título de %d do %s por 1 ponto" % [c.short_name, world.year, r.short_name]
		elif gap > 1:
			text = "%s tira o título de %d do %s por %d pontos" % [c.short_name, world.year, r.short_name, gap]
		add(world, champ, runner, 10.0, text, "titulo", champ)
	elif gap <= 8 and league.tier == 1:
		add(world, champ, runner, 4.0, "%s e %s brigam pelo título de %d" % [c.short_name, r.short_name, world.year], "titulo", champ)


## Jogador importante trocando de lado (chamado antes de o jogador mudar de clube).
## Para quem estava livre, vale o último clube se ele saiu de lá há pouco tempo.
static func on_transfer(world: GameWorld, p: Player, seller: Club, buyer: Club) -> void:
	var from := seller
	if from == null and not p.spells.is_empty():
		var last: Dictionary = p.spells[p.spells.size() - 1]
		if int(last.get("to", 0)) >= world.year - 1:
			from = world.club(int(last.get("c", -1)))
	if from == null or buyer == null or from.id == buyer.id:
		return
	var pts := 0.0
	var why := ""
	if from.sheet != null and from.sheet.captain == p.id:
		pts += 8.0
		why = "o capitão"
	var years := 0
	var goals := 0
	for sp: Dictionary in p.spells:
		if int(sp.get("c", -1)) == from.id:
			var to := int(sp.get("to", 0))
			years += (to if to > 0 else world.year) - int(sp.get("from", world.year))
			goals += int(sp.get("g", 0))
	if years >= 5 or goals >= 50:
		pts += 6.0
		if why == "":
			why = "o ídolo"
	var better := 0
	for q: Player in world.squad(from):
		if q.id != p.id and q.ovr_f > p.ovr_f:
			better += 1
	if better < 3 and p.ovr_f >= 65.0:
		pts += 5.0
		if why == "":
			why = "a estrela"
	if pts <= 0.0:
		return
	var already := world.rivalries.has(key(from.id, buyer.id))
	if not already and pts < 8.0 and not _is_static(world, from.id, buyer.id):
		pts *= 0.6 # entre clubes sem história, uma venda sozinha não cria rixa
	var text := ""
	match why:
		"o capitão": text = "%s, capitão do %s, vai para o %s (%d)" % [p.display_name(), from.short_name, buyer.short_name, world.year]
		"o ídolo": text = "%s, ídolo do %s, vai para o %s (%d)" % [p.display_name(), from.short_name, buyer.short_name, world.year]
		_: text = "%s, estrela do %s, vai para o %s (%d)" % [p.display_name(), from.short_name, buyer.short_name, world.year]
	add(world, from.id, buyer.id, pts, text, "transferencia", buyer.id)


# ---------------------------------------------------------------------------
# O que esfria
# ---------------------------------------------------------------------------

## Virada de ano: o tempo esfria as rixas e esquece as pequenas.
static func season_close(world: GameWorld) -> void:
	var drop: Array = []
	for k: String in world.rivalries:
		var r: Dictionary = world.rivalries[k]
		var fl := _floor(world, int(r["a"]), int(r["b"]))
		var s := float(r["s"])
		s = fl + (s - fl) * DECAY if s > fl else fl
		r["s"] = snappedf(s, 0.1)
		# Nível anunciado desce junto (para anunciar de novo se voltar a esquentar)
		r["lv"] = mini(int(r.get("lv", 0)), level_of(s))
		if s < PRUNE_BELOW and fl <= 0.0 and float(r.get("pk", 0.0)) < RIXA_AT:
			drop.append(k)
	for k in drop:
		world.rivalries.erase(k)


# ---------------------------------------------------------------------------
# Imprensa e torcida
# ---------------------------------------------------------------------------

static func _check_level(world: GameWorld, r: Dictionary) -> void:
	var lv := level_of(float(r["s"]))
	if lv <= int(r.get("lv", 0)):
		return
	r["lv"] = lv
	if lv < 2 and not _involves_user(world, r):
		return
	if not _newsworthy(world, r):
		return
	var a := world.club(int(r["a"]))
	var b := world.club(int(r["b"]))
	var title := ""
	match lv:
		1: title = "Nasce uma rixa: %s x %s" % [a.short_name, b.short_name]
		2: title = "%s x %s agora é clássico" % [a.short_name, b.short_name]
		3: title = "%s x %s vira o grande clássico do país" % [a.short_name, b.short_name]
	# O texto sai no idioma do jogo (como as outras notícias); os momentos ficam em português no registro.
	title = I18n.t(title)
	var body := I18n.t("Termômetro da rivalidade em %d." % int(round(float(r["s"]))))
	var ev: Array = r["ev"]
	var bits: Array = []
	for i in range(ev.size() - 1, maxi(-1, ev.size() - 4), -1):
		bits.append(I18n.t(String(ev[i]["t"])))
	if not bits.is_empty():
		body += " " + ". ".join(bits) + "."
	var quote := _quote(world, r, lv)
	if quote != "":
		body += " " + I18n.t(quote)
	var uid := world.user_club_id
	var cid := uid if _involves_user(world, r) else int(r["a"])
	var imp := NewsEvent.IMP_HEADLINE if _involves_user(world, r) and lv >= 2 else (NewsEvent.IMP_HIGH if _involves_user(world, r) else NewsEvent.IMP_NORMAL)
	NewsManager.post_raw(world, title, body, cid, -1, imp, "rivalidade")
	if _involves_user(world, r) and lv >= 2:
		var user := world.user_club()
		user.fan_mood = clampf(user.fan_mood + 2.0, 0.0, 100.0) # a torcida abraça o novo clássico


static func _involves_user(world: GameWorld, r: Dictionary) -> bool:
	return world.has_user() and (world.is_user_club(int(r["a"])) or world.is_user_club(int(r["b"])))


static func _newsworthy(world: GameWorld, r: Dictionary) -> bool:
	if not world.has_user():
		return false
	if _involves_user(world, r):
		return true
	var nat := world.user_nation()
	var a := world.club(int(r["a"]))
	var b := world.club(int(r["b"]))
	var la := world.league(a.league_id)
	var lb := world.league(b.league_id)
	return (la != null and la.nation == nat and la.tier <= 2) or (lb != null and lb.nation == nat and lb.tier <= 2)


## Fala de um jogador do clube do usuário (ou do clube A) sobre o novo clássico. Escolha estável, sem RNG.
static func _quote(world: GameWorld, r: Dictionary, lv: int) -> String:
	var cid := world.user_club_id if _involves_user(world, r) else int(r["a"])
	var other := world.club(int(r["b"]) if int(r["a"]) == cid else int(r["a"]))
	var c := world.club(cid)
	if c == null or other == null:
		return ""
	var sq := world.squad(c)
	if sq.is_empty():
		return ""
	var who: Player = null
	if c.sheet != null:
		who = world.player(c.sheet.captain)
	if who == null or who.club_id != cid:
		sq.sort_custom(func(x, y): return x.ovr_f > y.ovr_f)
		who = sq[0]
	var lines := [
		"\"Contra o %s não existe jogo normal\", diz %s." % [other.short_name, who.display_name()],
		"\"A torcida cobra na rua. Esse jogo virou outra coisa\", admite %s." % who.display_name(),
		"\"Eles sabem o que fizeram. A gente também não esquece\", avisa %s." % who.display_name(),
	]
	if lv == 1:
		lines = ["\"Tem história mal resolvida com o %s\", diz %s." % [other.short_name, who.display_name()]]
	return lines[(int(r["a"]) * 7 + int(r["b"]) * 3 + lv) % lines.size()]


## Linha para ganchos e prévias: o último capítulo da rivalidade, do ponto de vista de `cid`.
static func memory_line(world: GameWorld, cid: int, other: int) -> String:
	var g := last_grudge(world, cid, other)
	if not g.is_empty():
		return "Revanche: %s" % String(g["t"])
	var ev: Array = get_rec(world, cid, other).get("ev", [])
	if not ev.is_empty():
		return "Último capítulo: %s" % String(ev[ev.size() - 1]["t"])
	return ""
