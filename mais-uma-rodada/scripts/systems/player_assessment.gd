class_name PlayerAssessment
extends RefCounted
## Staff opinion, never a public conversion of hidden CA/PA. Attribute evidence,
## positional requirements, squad context and observation determine the range.

static var _frame := -1
static var _references: Dictionary = {}

static func confidence(w: GameWorld, p: Player) -> float:
	if w == null: return 0.35
	var own := w.is_user_club(p.club_id) or w.academy.has(p.id)
	var skill := People.staff_level(w, "olheiro")
	if own: return clampf(0.76 + skill * 0.2, 0.78, 0.95)
	var c := w.club(p.club_id)
	var base := 0.5 if c != null and c.league_id == w.user_league_id() else 0.28
	# Relatório de olheiro: quanto mais rodadas de observação, mais perto do teto do olheiro.
	var know := Scouting.knowledge(w, p)
	if know > 0: return lerpf(base, clampf(0.72 + skill * 0.2, 0.74, 0.92), know / 100.0)
	return base

static func confidence_name(w: GameWorld, p: Player) -> String:
	var c := confidence(w,p)
	return "Boa observação" if c >= 0.8 else "Observação parcial" if c >= 0.5 else "Pouco observado"

static func attribute(w: GameWorld, p: Player, a: int) -> int:
	if w != null and (w.is_user_club(p.club_id) or w.academy.has(p.id)): return int(p.attrs[a])
	var uncertainty := (1.0 - confidence(w,p)) * 13.0
	return clampi(int(round(float(p.attrs[a]) + RngUtil.noise(p.id, a + 62930, w.world_seed if w != null else 7) * uncertainty)), 1, 99)

static func attribute_text(w: GameWorld, p: Player, a: int) -> String:
	var v := attribute(w,p,a)
	if w != null and (w.is_user_club(p.club_id) or w.academy.has(p.id)): return str(v)
	var margin := maxi(1, int(ceil((1.0-confidence(w,p))*8.0)))
	return "%d–%d" % [maxi(1,v-margin),mini(99,v+margin)]

static func score(w: GameWorld, p: Player, position: int = -1) -> float:
	var pos := p.position if position < 0 else position
	var value := 0.0
	var key_values: Array = []
	var own := w != null and (w.is_user_club(p.club_id) or w.academy.has(p.id))
	var uncertainty := (1.0-confidence(w,p))*13.0 if not own else 0.0
	for a in Attr.COUNT:
		var weight := float(Pos.WEIGHTS[pos][a])
		if weight <= 0.0: continue
		var observed := clampf(roundf(float(p.attrs[a])+RngUtil.noise(p.id,a+62930,w.world_seed if w != null else 7)*uncertainty),1.0,99.0)
		value += observed * weight
		if weight >= 0.09: key_values.append(observed)
	# A serious gap in an essential attribute cannot disappear inside an average.
	if not key_values.is_empty():
		key_values.sort()
		value -= maxf(0.0,value-float(key_values[0])-12.0)*0.14
	return value * Pos.familiarity(p.position,p.secondary,pos)

static func squad_reference(w: GameWorld, pos: int) -> float:
	if w == null or not w.has_user(): return 65.0
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_references.clear()
	var key := "%d:%d:%d:%d:%d" % [w.get_instance_id(),w.year,w.current_turn(),w.user_club_id,pos]
	if _references.has(key): return float(_references[key])
	var peers: Array = []
	for q: Player in w.squad(w.user_club()):
		if Pos.group(q.position) == Pos.group(pos): peers.append(score(w,q,pos))
	if peers.is_empty():
		for q: Player in w.squad(w.user_club()): peers.append(score(w,q))
	peers.sort()
	var value := float(peers[int(peers.size()*0.65)]) if not peers.is_empty() else 65.0
	_references[key] = value
	return value

static func invalidate() -> void:
	_references.clear()

static func _stars(value: float, baseline: float) -> float:
	return clampf(3.0+(value-baseline)/10.0,0.5,5.0)

static func report(w: GameWorld, p: Player, position: int = -1) -> Dictionary:
	var pos := p.position if position < 0 else position
	var now := score(w,p,pos)
	var base := squad_reference(w,pos)
	var trust := confidence(w,p)
	var error := (1.0-trust)*10.0
	var low := clampf(floorf(_stars(now-error,base)*2.0)/2.0,0.5,5.0)
	var high := clampf(ceilf(_stars(now+error,base)*2.0)/2.0,low,5.0)
	var age := p.age(w.year) if w != null else 25
	# Forecast uses observable age, attribute balance and recent development, not p.potential.
	var growth := maxf(0.0,26.0-age)*1.25
	var momentum := 0.0
	if w != null and w.is_user_club(p.club_id):
		for change in TrainingManager.recent_changes(p): momentum += float(change[2])*float(Pos.WEIGHTS[pos][int(change[1])])
	momentum = clampf(momentum,-3.0,4.0)
	var future := now + growth + maxf(0.0,momentum)*0.5
	var future_error := (4.0+maxf(0.0,23.0-age)*1.3+(1.0-trust)*8.0) if age < 29 else error
	var projected_low := maxf(low,floorf(_stars(future-future_error,base)*2.0)/2.0)
	var projected_high := maxf(high,ceilf(_stars(future+future_error,base)*2.0)/2.0)
	return {"low":low,"high":high,"future_low":clampf(projected_low,0.5,5.0),"future_high":clampf(projected_high,0.5,5.0),"confidence":trust,"position":pos}

static func stars(w: GameWorld, p: Player, position: int = -1, future: bool = false) -> float:
	var r := report(w,p,position)
	return (float(r["future_low"])+float(r["future_high"]))*0.5 if future else (float(r["low"])+float(r["high"]))*0.5

static func range_text(low: float, high: float) -> String:
	return "%s ★" % ("%.1f" % low).replace(".",",") if is_equal_approx(low,high) else "%s–%s ★" % [("%.1f" % low).replace(".",","),("%.1f" % high).replace(".",",")]

static func summary(w: GameWorld, p: Player, future: bool = false) -> String:
	var r := report(w,p)
	return range_text(r["future_low"],r["future_high"]) if future else range_text(r["low"],r["high"])

static func standout(w: GameWorld, p: Player, position: int = -1, weakness: bool = false) -> String:
	var pos := p.position if position < 0 else position
	var candidates: Array = []
	for a in Attr.COUNT:
		if float(Pos.WEIGHTS[pos][a]) >= 0.035: candidates.append(a)
	candidates.sort_custom(func(a,b): return attribute(w,p,a)<attribute(w,p,b) if weakness else attribute(w,p,a)>attribute(w,p,b))
	var names: Array = []
	for a in candidates.slice(0,2): names.append("%s %s" % [Attr.name_of(a),attribute_text(w,p,a)])
	return " · ".join(names)

static func fit_text(w: GameWorld, p: Player) -> String:
	var r := report(w,p)
	if float(r["low"]) >= 3.5: return "Pode elevar o nível do setor"
	if float(r["high"]) < 2.5: return "Precisa evoluir para disputar espaço"
	return "Disputa espaço conforme a função"
