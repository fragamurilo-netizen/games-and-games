class_name GameModels
extends RefCounted
## Modelos de jogo: táticas completas prontas (data/gameplay/game_models.json) e as táticas que o
## usuário salva com nome próprio (world.stats["my_tac"]). Aplicar um modelo troca formação,
## plano, instruções de equipe e as instruções individuais das vagas; o time é reorganizado na
## formação nova (os mesmos critérios da escolha de formação na tela de tática).

const PATH := "res://data/gameplay/game_models.json"
const MAX_SAVED := 10
## Campos táticos do TeamSheet.to_dict que um modelo define (o resto é escalação).
const KEYS: Array[String] = ["m", "st", "i", "l", "p", "wd", "tp", "pa", "mk", "tr", "fo", "tw", "cr", "pl", "pw", "pm"]
const DEFAULTS := {"m": 2, "st": 0, "i": 1, "l": 1, "p": 1, "wd": 1, "tp": 1, "pa": 1, "mk": 0, "tr": 1, "fo": 1, "tw": 0, "cr": 0, "pl": -1, "pw": -1, "pm": 70}

static var _db: Dictionary = {}


static func db() -> Dictionary:
	if _db.is_empty():
		var d: Variant = DatabaseManager.read_json(PATH)
		_db = d if d is Dictionary else {"groups": [], "models": []}
	return _db


static func all() -> Array:
	return db().get("models", [])


static func groups() -> Array:
	return db().get("groups", [])


static func find(id: String) -> Dictionary:
	for m: Dictionary in all():
		if String(m["id"]) == id:
			return m
	return {}


## Valores táticos completos do modelo (com os padrões preenchidos).
static func values(model: Dictionary) -> Dictionary:
	var out := {}
	for k in KEYS:
		out[k] = int(model.get(k, DEFAULTS[k]))
	return out


## Aplica o modelo na escalação: formação (time reorganizado), plano e instruções.
static func apply(world: GameWorld, club: Club, sheet: TeamSheet, model: Dictionary) -> void:
	var fname := String(model.get("f", sheet.formation))
	if DatabaseManager.has_formation(fname) and fname != sheet.formation:
		reshape(world, club, sheet, fname)
	var v := values(model)
	sheet.mentality = v["m"]
	sheet.style = v["st"]
	sheet.intensity = v["i"]
	sheet.line = v["l"]
	sheet.pressing = v["p"]
	sheet.width = v["wd"]
	sheet.tempo = v["tp"]
	sheet.passing = v["pa"]
	sheet.marking = v["mk"]
	sheet.transition = v["tr"]
	sheet.focus = v["fo"]
	sheet.time_waste = v["tw"]
	sheet.corners = v["cr"]
	sheet.plan_losing = v["pl"]
	sheet.plan_winning = v["pw"]
	sheet.plan_minute = v["pm"]
	# Instruções individuais: por posição da vaga (modelo pronto) ou por vaga (tática salva).
	sheet.instr = {}
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	var by_pos: Dictionary = model.get("ins", {})
	var by_slot: Dictionary = model.get("ins_slot", {})
	for i in mini(slots.size(), sheet.starters.size()):
		var pid := int(sheet.starters[i])
		if pid < 0:
			continue
		var key := String(by_slot.get(str(i), by_pos.get(Pos.code(int(slots[i]["pos"])), "")))
		if key != "" and TeamSheet.INSTRUCTIONS.has(key):
			sheet.instr[pid] = key


## Troca a formação mantendo o critério da tela de tática: melhores na forma nova, banco e
## cobradores refeitos.
static func reshape(world: GameWorld, club: Club, sheet: TeamSheet, fname: String) -> void:
	sheet.formation = fname
	sheet.starters = Array(ClubAI.best_eleven(world, club, fname)).duplicate()
	sheet.bench = ClubAI.pick_bench(world, club, sheet.starters)
	for key in ["captain", "penalty_taker", "freekick_taker", "corner_taker"]:
		if not sheet.starters.has(sheet.get(key)):
			ClubAI.pick_set_pieces(world, sheet)
			break


## O modelo (pronto ou salvo) que a escalação está usando, ou {} se for uma tática própria.
static func current(world: GameWorld, sheet: TeamSheet) -> Dictionary:
	var d := sheet.to_dict()
	var base := DatabaseManager.formation_base(sheet.formation)
	for m: Dictionary in saved(world) + all():
		if String(m.get("f", "")) != base and String(m.get("f", "")) != sheet.formation:
			continue
		var v := values(m)
		var same := true
		for k in KEYS:
			if int(d.get(k, DEFAULTS[k])) != int(v[k]):
				same = false
				break
		if same:
			return m
	return {}


# ---------------------------------------------------------------------------
# Táticas salvas pelo usuário
# ---------------------------------------------------------------------------

static func saved(world: GameWorld) -> Array:
	return world.stats.get("my_tac", [])


## Guarda a tática atual com um nome (formação, plano, instruções de equipe e individuais por vaga).
static func save_current(world: GameWorld, sheet: TeamSheet, name: String) -> Dictionary:
	var list: Array = saved(world).duplicate()
	var d := sheet.to_dict()
	var m := {"id": "my_%d" % int(world.stats.get("my_tac_n", 0)), "name": name.strip_edges().left(28), "f": sheet.formation, "mine": true,
		"desc": "Sua tática: %s, %s." % [DatabaseManager.formation_base(sheet.formation), String(DatabaseManager.tactics()["styles"][sheet.style]["name"]).to_lower()]}
	if String(m["name"]) == "":
		m["name"] = "Tática %d" % (list.size() + 1)
	for k in KEYS:
		m[k] = int(d.get(k, DEFAULTS[k]))
	var ins := {}
	for i in sheet.starters.size():
		var key := String(sheet.instr.get(int(sheet.starters[i]), ""))
		if key != "":
			ins[str(i)] = key
	m["ins_slot"] = ins
	world.stats["my_tac_n"] = int(world.stats.get("my_tac_n", 0)) + 1
	list.push_front(m)
	while list.size() > MAX_SAVED:
		list.pop_back()
	world.stats["my_tac"] = list
	return m


static func delete_saved(world: GameWorld, id: String) -> void:
	world.stats["my_tac"] = saved(world).filter(func(m: Dictionary): return String(m["id"]) != id)
