class_name ClubPhilosophy
extends RefCounted
## Filosofia de jogo de cada clube (data/gameplay/philosophies.json): formações preferidas,
## estilo principal e alternativo, mentalidade, pressão, linha, intensidade e pragmatismo.
## Fica guardada no clube (`Club.philosophy`) para que outros sistemas (ex.: o técnico)
## possam ler ou trocar. A escolha é estável: sai do perfil do clube e da escola do país,
## sem consumir o RNG do mundo.

const PATH := "res://data/gameplay/philosophies.json"

static var _data: Dictionary = {}


static func _db() -> Dictionary:
	if _data.is_empty():
		var d: Variant = DatabaseManager.read_json(PATH)
		_data = d if d is Dictionary else {"philosophies": {}}
	return _data


static func ids() -> Array:
	return _db()["philosophies"].keys()


static func info(id: String) -> Dictionary:
	var all: Dictionary = _db()["philosophies"]
	return all.get(id, all.get("pragmatico", {}))


## Id da filosofia do clube (escolhe e guarda na primeira consulta).
static func id_of(club: Club) -> String:
	if club.philosophy == "" or not _db()["philosophies"].has(club.philosophy):
		club.philosophy = pick_for(club)
	return club.philosophy


static func of(club: Club) -> Dictionary:
	return info(id_of(club))


## Sorteio ponderado e determinístico pela identidade do clube.
static func pick_for(club: Club) -> String:
	var db := _db()
	var base: Dictionary = db.get("base", {})
	var ab: Dictionary = db.get("archetype_bias", {}).get(club.archetype, {})
	var nb: Dictionary = db.get("nation_bias", {}).get(club.nation, {})
	var keys: Array = db["philosophies"].keys()
	keys.sort()
	var weights: Array = []
	var total := 0.0
	for k in keys:
		var w := float(base.get(k, 1.0)) * float(ab.get(k, 1.0)) * float(nb.get(k, 1.0))
		weights.append(w)
		total += w
	var rng := RandomNumberGenerator.new()
	rng.seed = hash((club.key if club.key != "" else "id%d" % club.id) + "|filosofia")
	var r := rng.randf() * total
	for i in keys.size():
		r -= float(weights[i])
		if r <= 0.0:
			return keys[i]
	return keys[keys.size() - 1]


static func formations(club: Club) -> Array:
	var f: Array = of(club).get("formations", [])
	var out: Array = []
	for fname in f:
		if DatabaseManager.has_formation(fname):
			out.append(fname)
	if out.is_empty():
		out = club.arch().get("formations", ["4-4-2"])
	return out


## Tática da IA para um jogo, a partir da filosofia. Clubes pragmáticos leem o adversário;
## os idealistas mudam pouco (no máximo baixam um pouco a mentalidade contra gigantes).
## Não usa o RNG do mundo: a variação vem do dia e do clube, então tudo segue determinístico.
static func apply_match_plan(world: GameWorld, club: Club, opponent: Club, is_home: bool, sheet: TeamSheet) -> void:
	var ph := of(club)
	var adapt := float(ph.get("adapt", 0.3))
	var day := world.season.day if world.season != null else 0
	var roll := float(absi(club.id * 7919 + day * 104729 + (opponent.id if opponent != null else 0) * 31) % 1000) / 1000.0
	var style := int(ph.get("style", 0))
	var style2 := int(ph.get("style2", style))
	var m := int(ph.get("mentality", 2))
	var mine := ClubAI.team_strength(world, club)
	var theirs := ClubAI.team_strength(world, opponent) if opponent != null else mine
	var diff := mine - theirs + (1.5 if is_home else -1.5)
	var opp_ph := of(opponent) if opponent != null else {}
	if diff <= -6.0:
		# Azarão: o pragmático se fecha e sai no contra-ataque; o idealista só se protege um pouco.
		if roll < adapt:
			m = mini(m, 1 if diff <= -10.0 else 2)
			if style != TeamSheet.STYLE_CONTRA:
				style = TeamSheet.STYLE_CONTRA if style2 != TeamSheet.STYLE_LONGA else style2
		else:
			m = maxi(1, mini(m, 2) if diff <= -10.0 else m - (1 if m >= 3 else 0))
	elif diff >= 6.0:
		# Favorito: vai para cima. Contra quem se fecha, o pragmático troca para amplitude/posse.
		m = maxi(m, 3)
		if roll < adapt and int(opp_ph.get("mentality", 2)) <= 1:
			style = TeamSheet.STYLE_LADOS if style == TeamSheet.STYLE_CONTRA else style
	elif not is_home and roll < adapt * 0.6:
		# Fora de casa em jogo equilibrado: às vezes usa o plano alternativo.
		style = style2
	# Mesma filosofia contra mesma filosofia: o pragmático tenta o antídoto.
	if roll < adapt and opponent != null and int(opp_ph.get("style", -1)) == TeamSheet.STYLE_PRESSAO and style == TeamSheet.STYLE_POSSE:
		style = TeamSheet.STYLE_LONGA if adapt >= 0.8 else style2
	sheet.style = clampi(style, 0, 5)
	sheet.mentality = clampi(m, 0, 4)
	var pressing := int(ph.get("pressing", 1))
	var line := int(ph.get("line", 1))
	var intensity := int(ph.get("intensity", 1))
	if sheet.mentality <= 1:
		line = 0
		pressing = mini(pressing, 1)
	# Elenco cansado não aguenta pressão alta o jogo inteiro.
	if pressing == 2 and _avg_condition(world, sheet) < 82.0:
		pressing = 1
		intensity = mini(intensity, 1)
	sheet.pressing = clampi(pressing, 0, 2)
	sheet.line = clampi(line, 0, 2)
	sheet.intensity = clampi(intensity, 0, 2)


static func _avg_condition(world: GameWorld, sheet: TeamSheet) -> float:
	var s := 0.0
	var n := 0
	for pid in sheet.starters:
		var p := world.player(pid)
		if p != null:
			s += p.condition
			n += 1
	return s / n if n > 0 else 100.0


## Uma linha para a interface: "Pressão sufocante · pragmatismo baixo".
static func summary(club: Club) -> String:
	var ph := of(club)
	var adapt := float(ph.get("adapt", 0.3))
	var how := "muda muito conforme o rival" if adapt >= 0.7 else ("adapta-se às vezes" if adapt >= 0.4 else "fiel às suas ideias")
	return "%s · %s" % [String(ph.get("name", "")), how]
