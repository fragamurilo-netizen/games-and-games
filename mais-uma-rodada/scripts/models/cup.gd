class_name Cup
extends RefCounted
## Copa de uma temporada (continental ou Mundial de Clubes): fase de grupos opcional e mata-mata
## (ida e volta ou jogo único). A lógica de sorteio e avanço fica em CupManager.

var id: String = "" # "UCL", "LIB", "CCC", "CAF", "AFC", "CWC"
var name: String = ""
var short_name: String = ""
var club_ids: Array = []
## Grupos: [{"n": "A", "clubs": [ids], "table": {club_id: linha}}]
var groups: Array = []
## Todos os jogos (grupos e mata-mata), com stage/round/leg/slot preenchidos.
var fixtures: Array = []
## Confrontos do mata-mata: [{"r": fase, "a": id, "b": id, "w": vencedor ou -1}]
var ties: Array = []
## Nome de cada fase do mata-mata (índice = Fixture.round).
var round_names: Array = []
var champion: int = -1
var runner_up: int = -1
var finished: bool = false


func fixtures_at(slot: int) -> Array:
	var out: Array = []
	for f in fixtures:
		if f.slot == slot:
			out.append(f)
	return out


func has_club(club_id: int) -> bool:
	return club_ids.has(club_id)


## Grupo do clube (ou {} se não estiver na fase de grupos).
func group_of(club_id: int) -> Dictionary:
	for g in groups:
		if g["clubs"].has(club_id):
			return g
	return {}


func ties_of_round(r: int) -> Array:
	var out: Array = []
	for t in ties:
		if int(t["r"]) == r:
			out.append(t)
	return out


func tie_of(club_id: int, r: int) -> Dictionary:
	for t in ties:
		if int(t["r"]) == r and (int(t["a"]) == club_id or int(t["b"]) == club_id):
			return t
	return {}


func fixtures_of_tie(t: Dictionary) -> Array:
	var out: Array = []
	for f in fixtures:
		if f.stage == Fixture.STAGE_KO and f.round == int(t["r"]) and ((f.home == int(t["a"]) and f.away == int(t["b"])) or (f.home == int(t["b"]) and f.away == int(t["a"]))):
			out.append(f)
	out.sort_custom(func(x, y): return x.leg < y.leg)
	return out


## O clube ainda está vivo (não eliminado) na copa.
func is_alive(club_id: int) -> bool:
	if finished or not club_ids.has(club_id):
		return false
	for t in ties:
		var w := int(t["w"])
		if w >= 0 and (int(t["a"]) == club_id or int(t["b"]) == club_id) and w != club_id:
			return false
	return true


func to_dict() -> Dictionary:
	var fx: Array = []
	for f in fixtures:
		fx.append(f.to_dict())
	var gs: Array = []
	for g in groups:
		var tb: Dictionary = {}
		for k in g["table"]:
			tb[str(k)] = g["table"][k]
		gs.append({"n": g["n"], "clubs": g["clubs"], "table": tb})
	return {"id": id, "name": name, "short": short_name, "clubs": club_ids, "groups": gs, "fx": fx, "ties": ties,
		"rn": round_names, "champ": champion, "ru": runner_up, "fin": finished}


static func from_dict(d: Dictionary) -> Cup:
	var c := Cup.new()
	c.id = d.get("id", "")
	c.name = d.get("name", "")
	c.short_name = d.get("short", c.name)
	c.club_ids = Array(d.get("clubs", []))
	for g in d.get("groups", []):
		var tb: Dictionary = {}
		var raw: Dictionary = g.get("table", {})
		for k in raw:
			tb[int(k)] = raw[k]
		c.groups.append({"n": g.get("n", ""), "clubs": Array(g.get("clubs", [])), "table": tb})
	for fd in d.get("fx", []):
		c.fixtures.append(Fixture.from_dict(fd))
	c.ties = Array(d.get("ties", []))
	c.round_names = Array(d.get("rn", []))
	c.champion = int(d.get("champ", -1))
	c.runner_up = int(d.get("ru", -1))
	c.finished = bool(d.get("fin", false))
	return c
