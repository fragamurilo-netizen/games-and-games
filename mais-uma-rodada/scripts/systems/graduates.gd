class_name Graduates
extends RefCounted
## Revelados pela base: o clube formador de cada jogador é o da primeira passagem da carreira,
## quando ela começou até os 19 anos e não foi empréstimo (vale para saves antigos também).

const MAX_AGE_DEBUT := 19


## Clube formador (primeira passagem até os 19 anos, sem ser empréstimo) ou -1.
static func origin_of(spells: Array, birth_year: int) -> int:
	if spells.is_empty():
		return -1
	var s: Dictionary = spells[0]
	if bool(s.get("lo", false)) or int(s.get("from", 0)) - birth_year > MAX_AGE_DEBUT:
		return -1
	return int(s.get("c", -1))


static func of_club(w: GameWorld, club_id: int) -> Array:
	var out: Array = []
	for p: Player in w.players.values():
		if origin_of(p.spells, p.birth_year) == club_id:
			out.append(p)
	out.sort_custom(func(a: Player, b: Player): return a.overall > b.overall if a.overall != b.overall else a.id < b.id)
	return out


static func retired_of(w: GameWorld, club_id: int) -> Array:
	var out: Array = []
	for r in w.retired:
		if origin_of(r.get("spells", []), int(r.get("by", 0))) == club_id:
			out.append(r)
	out.sort_custom(func(a, b): return int(a.get("apps", 0)) > int(b.get("apps", 0)))
	return out


static func count(w: GameWorld, club_id: int) -> int:
	var n := 0
	for p: Player in w.players.values():
		if origin_of(p.spells, p.birth_year) == club_id:
			n += 1
	return n
