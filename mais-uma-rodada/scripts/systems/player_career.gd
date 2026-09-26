class_name PlayerCareer
extends RefCounted
## Temporada a temporada do jogador como na vida real: quem troca de clube no meio do ano tem
## duas linhas no ano (os números de cada clube), empréstimos aparecem como empréstimo e as
## lesões graves ficam registradas na temporada em que aconteceram.
##
## Guarda em world.memory (vai no save):
##   split {pid: [recortes]} números acumulados na temporada no momento em que ele saiu de cada clube
##   injs  {pid: [[nome, semanas, clube]]} lesões de 6+ semanas na temporada

## Semanas a partir das quais a lesão entra na carreira.
const SERIOUS_WEEKS := 6


static func _mem(world: GameWorld, key: String) -> Dictionary:
	var m: Dictionary = world.memory
	if not m.has(key):
		m[key] = {}
	return m[key]


## Números acumulados da temporada até agora.
static func _snap(world: GameWorld, p: Player) -> Dictionary:
	var tot := p.season_totals()
	var club := world.club(p.club_id)
	return {"c": p.club_id, "cn": club.short_name if club != null else "", "l": club.league_id if club != null else "", "lo": not p.loan.is_empty(),
		"a": p.stats[Player.S_APPS], "g": p.stats[Player.S_GOALS], "as": p.stats[Player.S_ASSISTS], "st": p.stats[Player.S_STARTS],
		"mi": p.minutes_season, "mo": p.stats[Player.S_MOTM], "cs": p.stats[Player.S_CLEAN], "yc": p.stats[Player.S_YELLOWS],
		"rc": p.stats[Player.S_REDS], "rs": p.stats[Player.S_RATING_SUM], "ta": int(tot[0]), "tg": int(tot[1]), "tas": int(tot[2])}


## Jogador vai sair do clube (venda, empréstimo) com a temporada em andamento.
static func on_leave(world: GameWorld, p: Player) -> void:
	if p.club_id < 0 or world.season == null or world.season.finished:
		return
	if int(p.season_totals()[0]) <= 0:
		return
	var sp := _mem(world, "split")
	if not sp.has(p.id):
		sp[p.id] = []
	sp[p.id].append(_snap(world, p))


## Lesão nova: as graves entram na temporada dele.
static func on_injury(world: GameWorld, p: Player, weeks: int, name: String) -> void:
	if weeks < SERIOUS_WEEKS:
		return
	var inj := _mem(world, "injs")
	if not inj.has(p.id):
		inj[p.id] = []
	inj[p.id].append([name, weeks, p.club_id])


## Linhas do ano para o arquivo do jogador (uma por clube em que jogou na temporada).
static func season_rows(world: GameWorld, p: Player) -> Array:
	var cuts: Array = _mem(world, "split").get(p.id, [])
	var injs: Array = _mem(world, "injs").get(p.id, [])
	var rows: Array = []
	var prev := {}
	var parts: Array = cuts.duplicate()
	if p.club_id >= 0:
		parts.append(_snap(world, p))
	for s: Dictionary in parts:
		var row := _diff(world, s, prev)
		prev = s
		if int(row["a"]) + int(row["ca"]) > 0:
			rows.append(row)
	# Temporada inteira no departamento médico ainda conta como temporada (com zero jogos).
	if rows.is_empty() and not injs.is_empty() and p.club_id >= 0:
		rows.append(_diff(world, _snap(world, p), {}))
	if rows.is_empty():
		return rows
	for e: Array in injs:
		var target: Dictionary = rows.back()
		for row: Dictionary in rows:
			if int(row["c"]) == int(e[2]):
				target = row
		if not target.has("inj"):
			target["inj"] = []
		target["inj"].append([String(e[0]), int(e[1])])
	# O overall do ano fica na última linha (o gráfico de evolução usa uma por ano).
	var last: Dictionary = rows.back()
	last["o"] = p.overall
	last["o0"] = p.ovr_start if p.ovr_start >= 0 else p.overall
	return rows


static func _diff(world: GameWorld, s: Dictionary, prev: Dictionary) -> Dictionary:
	var d := func(k: String) -> int: return int(s.get(k, 0)) - int(prev.get(k, 0))
	var a: int = d.call("a")
	var rs: int = d.call("rs")
	var row := {"y": world.year, "c": int(s["c"]), "cn": String(s["cn"]), "l": String(s["l"]),
		"a": a, "g": d.call("g"), "as": d.call("as"), "r": snappedf(rs / 10.0 / a if a > 0 else 0.0, 0.01),
		"ca": d.call("ta") - a, "cg": d.call("tg") - int(d.call("g")), "cas": d.call("tas") - int(d.call("as")),
		"mi": d.call("mi"), "st": d.call("st"), "mo": d.call("mo"), "cs": d.call("cs"), "yc": d.call("yc"), "rc": d.call("rc")}
	if bool(s.get("lo", false)):
		row["lo"] = true
	return row


## Depois do arquivo do ano: os recortes da temporada não servem mais.
static func clear_season(world: GameWorld) -> void:
	world.memory["split"] = {}
	world.memory["injs"] = {}


# ---------------------------------------------------------------------------
# Passado (antes do primeiro ano do jogo)
# ---------------------------------------------------------------------------

## Lesão grave numa temporada do passado: quem tem tendência a lesão perde meses, e os jogos caem.
static func backfill_injury(rng: RandomNumberGenerator, p: Player, row: Dictionary, age: int) -> void:
	if age < 19 or int(row["a"]) <= 0:
		return
	var chance := 0.035 + (p.injury_prone - 10) * 0.006 + maxf(0.0, age - 30.0) * 0.006
	if rng.randf() >= chance:
		return
	var weeks := rng.randi_range(7, 30)
	var keep := clampf(1.0 - weeks / 44.0, 0.2, 0.9)
	for k in ["a", "g", "as", "mo", "cs"]:
		if row.has(k):
			row[k] = int(round(int(row[k]) * keep))
	row["inj"] = [[InjuryTable.name_for(weeks, p.id + int(row["y"])), weeks]]


## Transferência no meio do ano: parte da temporada fica com o clube antigo (duas linhas no ano).
static func backfill_splits(rng: RandomNumberGenerator, hist: Array) -> Array:
	var out: Array = []
	for i in hist.size():
		var row: Dictionary = hist[i]
		var prev: Dictionary = hist[i - 1] if i > 0 else {}
		if prev.is_empty() or int(prev["c"]) == int(row["c"]) or bool(row.get("lo", false)) or bool(prev.get("lo", false)) \
				or int(row["a"]) < 8 or rng.randf() >= 0.22:
			out.append(row)
			continue
		var f := rng.randf_range(0.3, 0.6)
		var part := {"y": row["y"], "c": prev["c"], "cn": prev["cn"], "r": row["r"], "pre": true}
		if prev.has("l"):
			part["l"] = prev["l"]
		for k in ["a", "g", "as", "ca", "cg", "cas", "mo", "cs"]:
			if row.has(k):
				var n := int(round(int(row[k]) * f))
				part[k] = n
				row[k] = int(row[k]) - n
		out.append(part)
		out.append(row)
	return out
