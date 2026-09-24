class_name League
extends RefCounted
## Competição de pontos corridos de uma divisão (turno e returno).

var division: int = 0
var name: String = ""
var club_ids: Array = []
var rounds: Array = [] # Array de rodadas; cada rodada é Array de Fixture
## Linhas da tabela: club_id -> {pl, w, d, l, gf, ga, pts, form, yc, rc}
var table: Dictionary = {}


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
	return club_ids.has(club_id)


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
	return {"div": division, "name": name, "clubs": club_ids, "rounds": rs, "table": tb}


static func from_dict(d: Dictionary) -> League:
	var l := League.new()
	l.division = int(d.get("div", 0))
	l.name = d.get("name", "")
	l.club_ids = Array(d.get("clubs", []))
	for r in d.get("rounds", []):
		var arr: Array = []
		for fd in r:
			arr.append(Fixture.from_dict(fd))
		l.rounds.append(arr)
	var tb: Dictionary = d.get("table", {})
	for k in tb:
		l.table[int(k)] = tb[k]
	return l
