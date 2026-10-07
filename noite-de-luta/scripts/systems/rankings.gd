class_name Rankings
extends RefCounted
## Ranking de cada categoria: sai do rating público (tipo Elo, só resultados e adversários),
## com desconto para quem está parado e um empurrão para a sequência. O campeão fica à parte.
## Os mais bem colocados lutam na Liga Global (camada 2); o meio, no circuito continental (1);
## o resto, nos eventos regionais (0).


static func score(w: GameWorld, f: Fighter) -> float:
	var sc := f.rating
	var idle := w.week - f.last_fight_week
	if idle > 40:
		sc -= (idle - 40) * 3.0
	sc += clampi(f.streak, -3, 5) * 6.0
	return sc


static func rebuild(w: GameWorld) -> void:
	var by_div := {}
	for f: Fighter in w.fighters.values():
		if f.retired or not f.is_pro():
			continue
		if int(w.champions.get(f.division, -1)) == f.id:
			continue
		if not by_div.has(f.division):
			by_div[f.division] = []
		by_div[f.division].append([score(w, f), f.id])
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var lst: Array = by_div.get(div, [])
		lst.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		w.rankings[div] = lst.map(func(x: Array) -> int: return int(x[1]))


## Quantos lutam na Liga Global por categoria (além do campeão).
static func lgc_size(div: String) -> int:
	var d := DataDB.division(div)
	return clampi(int(int(d.get("count", 60)) * 0.3), 10, 32)


static func tier_of(w: GameWorld, f: Fighter) -> int:
	var r := w.rank_of(f)
	if r == 0 or (r > 0 and r <= lgc_size(f.division)):
		return 2
	var n: int = (w.rankings.get(f.division, []) as Array).size()
	if r > 0 and r <= int(n * 0.62):
		return 1
	return 0


static func tier_name(tier: int) -> String:
	return String(((DataDB.mma()["promotions"] as Dictionary)[str(tier)] as Dictionary)["name"])


## Resultado de uma luta no rating, na sequência e no cinturão.
static func apply_result(w: GameWorld, b: Bout) -> void:
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	var win := int(b.result.get("winner_id", -1))
	var method := String(b.result.get("method", "DEC"))
	if method == "SR":
		return
	var ea := 1.0 / (1.0 + pow(10.0, (fb.rating - fa.rating) / 400.0))
	var sa := 0.5 if win < 0 else (1.0 if win == fa.id else 0.0)
	var k := 36.0 * (1.15 if method in ["KO", "TKO", "FIN"] else 1.0) * (1.2 if b.title else 1.0)
	fa.rating += k * (sa - ea)
	fb.rating += k * ((1.0 - sa) - (1.0 - ea))
	for f: Fighter in [fa, fb]:
		if win < 0:
			f.streak = 0
		elif win == f.id:
			f.streak = f.streak + 1 if f.streak >= 0 else 1
		else:
			f.streak = f.streak - 1 if f.streak <= 0 else -1
	if b.title and win >= 0:
		var champ_before := int(w.champions.get(b.division, -1))
		w.champions[b.division] = win
		var wf := w.fighter(win)
		if champ_before == win:
			wf.title_defenses += 1
		else:
			wf.titles_won += 1
			wf.title_defenses = 0
