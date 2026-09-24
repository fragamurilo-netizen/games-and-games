class_name League
extends RefCounted
## Liga nacional de pontos corridos de uma temporada: clubes, rodadas, datas e classificação.

var id: String = ""
var nation: String = ""
var tier: int = 1
var name: String = ""
var short_name: String = ""
var club_ids: Array = []
var rounds: Array = [] # Array de rodadas; cada rodada é Array de Fixture
var round_slots: Array = [] # data do calendário de cada rodada
## Linhas da tabela: club_id -> {pl, w, d, l, gf, ga, pts, form, yc, rc}
var table: Dictionary = {}


func cfg() -> Dictionary:
	return DatabaseManager.league_cfg(id)


func round_count() -> int:
	return rounds.size()


func fixtures_of_round(r: int) -> Array:
	if r < 0 or r >= rounds.size():
		return []
	return rounds[r]


func fixture_for(club_id: int, r: int) -> Fixture:
	for f in fixtures_of_round(r):
		if f.involves(club_id):
			return f
	return null


func row(club_id: int) -> Dictionary:
	return table.get(club_id, {})


func has_club(club_id: int) -> bool:
	return table.has(club_id)


## Rodada disputada na data `slot` (-1 se a liga folga nessa data).
func round_at_slot(slot: int) -> int:
	return round_slots.find(slot)


## Rodadas já disputadas por completo.
func rounds_played() -> int:
	var n := 0
	for r in rounds:
		if r.is_empty() or not r[0].played:
			break
		n += 1
	return n


func promoted_count() -> int:
	return int(cfg().get("up", 0))


func relegated_count() -> int:
	return int(cfg().get("down", 0))


func to_dict() -> Dictionary:
	var rs: Array = []
	for r in rounds:
		var arr: Array = []
		for f in r:
			arr.append(f.to_dict())
		rs.append(arr)
	var tb: Dictionary = {}
	for k in table:
		tb[str(k)] = table[k]
	return {"id": id, "nat": nation, "tier": tier, "name": name, "short": short_name, "clubs": club_ids, "rounds": rs,
		"slots": round_slots, "table": tb}


static func from_dict(d: Dictionary) -> League:
	var l := League.new()
	l.id = d.get("id", "")
	l.nation = d.get("nat", "")
	l.tier = int(d.get("tier", 1))
	l.name = d.get("name", "")
	l.short_name = d.get("short", l.name)
	l.club_ids = Array(d.get("clubs", []))
	for r in d.get("rounds", []):
		var arr: Array = []
		for fd in r:
			arr.append(Fixture.from_dict(fd))
		l.rounds.append(arr)
	l.round_slots = Array(d.get("slots", []))
	var tb: Dictionary = d.get("table", {})
	for k in tb:
		l.table[int(k)] = tb[k]
	return l
