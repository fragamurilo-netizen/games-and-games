class_name Development
extends RefCounted
## A semana de cada lutador fora do octógono: treino (foco e intensidade, staff), envelhecimento,
## condição física, lesões, aposentadoria e a nova safra de prospectos.

const FOCUS := {
	"equilibrado": {"name": "Equilibrado", "help": "Um pouco de tudo.", "w": {"st": 1.0, "wr": 1.0, "jj": 1.0, "ph": 1.0}},
	"em_pe": {"name": "Em pé", "help": "Mãos, chutes, clinch e defesa.", "w": {"st": 2.3, "wr": 0.4, "jj": 0.4, "ph": 0.7}},
	"wrestling": {"name": "Wrestling", "help": "Quedas, defesa de queda e jogo por cima.", "w": {"st": 0.4, "wr": 2.3, "jj": 0.6, "ph": 0.8}},
	"jiujitsu": {"name": "Jiu-jitsu", "help": "Jogo por baixo e finalizações.", "w": {"st": 0.4, "wr": 0.6, "jj": 2.3, "ph": 0.6}},
	"fisico": {"name": "Físico", "help": "Força, velocidade e cardio.", "w": {"st": 0.5, "wr": 0.5, "jj": 0.5, "ph": 2.4}},
}
const INTENSITY := ["Leve", "Normal", "Pesado"]
const GROUP_OF := {"maos": "st", "chutes": "st", "potencia": "st", "clinch": "st", "movimentacao": "st", "defesa": "st",
	"queda": "wr", "def_queda": "wr", "por_cima": "wr", "por_baixo": "jj", "finalizacao": "jj", "def_finalizacao": "jj",
	"forca": "ph", "velocidade": "ph", "cardio": "ph", "queixo": "ph", "coracao": "ph", "qi": "ph"}
const COACH_OF := {"st": "striking", "wr": "wrestling", "jj": "jiujitsu", "ph": "fisico"}
const INJURIES := [["Corte no supercílio", 2, 4], ["Nariz quebrado", 3, 6], ["Mão fraturada", 6, 10], ["Costela trincada", 4, 8],
	["Lesão no ombro", 6, 14], ["Lesão no joelho", 8, 24], ["Tornozelo torcido", 2, 5], ["Distensão muscular", 1, 3]]


static func week(w: GameWorld) -> void:
	var y := w.year()
	var m := w.month()
	for f: Fighter in w.fighters.values():
		if f.retired:
			continue
		var team := w.team(f.team_id)
		_recover(w, f, team)
		var bout := w.bout(f.bout_id)
		var fight_week := bout != null and bout.week == w.week
		if f.injury.is_empty() and not fight_week:
			_train(w, f, team, f.age(y, m))
		_age(w, f, f.age(y, m))
		if w.week - f.last_fight_week > 26:
			f.popularity = maxf(1.0, f.popularity - 0.15)


static func _recover(w: GameWorld, f: Fighter, team: Team) -> void:
	var physio := team.staff_quality("fisio") if team != null else 30.0
	var fisico := team.staff_quality("fisico") if team != null else 30.0
	var gain := 7.0 + (physio + fisico) / 40.0
	var cap := 100.0 if f.injury.is_empty() else 80.0
	f.condition = minf(cap, f.condition + gain)
	if f.suspension > 0:
		f.suspension -= 1
	if not f.injury.is_empty():
		var wk := int(f.injury["weeks"]) - 1
		if w.rng.randf() < physio / 250.0:
			wk -= 1
		if wk <= 0:
			if w.is_user_fighter(f):
				w.add_news("equipe", "%s está recuperado de: %s." % [f.display_name(), String(f.injury["name"]).to_lower()], [f.id])
			f.injury = {}
		else:
			f.injury["weeks"] = wk


static func _train(w: GameWorld, f: Fighter, team: Team, age: int) -> void:
	var intensity := int(f.training.get("intensity", 1)) if w.is_user_fighter(f) else 1
	var focus: Dictionary = (FOCUS.get(String(f.training.get("focus", "equilibrado")), FOCUS["equilibrado"]) as Dictionary)["w"]
	var age_k := 1.5 if age < 21 else (1.25 if age < 25 else (1.0 if age < 29 else (0.55 if age < 32 else 0.2)))
	var gap := clampf((f.potential - f.level()) / 8.0, 0.0, 1.6)
	var base: float = 0.16 * age_k * gap * [0.6, 1.0, 1.4][intensity]
	for k: String in Fighter.ATTRS:
		var g := String(GROUP_OF[k])
		if k in ["queixo", "coracao"]:
			continue # não se treina queixo
		var coach := team.staff_quality(String(COACH_OF[g])) if team != null else 20.0
		var amount := base * float(focus[g]) * (0.6 + coach / 100.0) * w.rng.randf_range(0.4, 1.6)
		var p := float(f.progress.get(k, 0.0)) + amount
		if p >= 1.0 and f.a(k) < 99.0:
			f.attrs[k] = f.a(k) + 1.0
			p -= 1.0
		f.progress[k] = p
	if intensity == 2:
		f.condition = maxf(55.0, f.condition - 3.0)
	# Lesão de treino
	var physio := team.staff_quality("fisio") if team != null else 30.0
	var risk: float = [0.0015, 0.004, 0.011][intensity] * (1.2 - physio / 150.0)
	if w.rng.randf() < risk:
		var inj: Array = INJURIES[[6, 7, 1, 3][w.rng.randi_range(0, 3)]]
		_injure(w, f, String(inj[0]), w.rng.randi_range(int(inj[1]), int(inj[2])), "no treino")


static func _age(w: GameWorld, f: Fighter, age: int) -> void:
	var over := age - f.peak_age - 1
	if over <= 0:
		return
	for k: String in ["velocidade", "cardio", "forca", "queixo", "potencia", "movimentacao"]:
		if w.rng.randf() < over * 0.012:
			f.attrs[k] = maxf(15.0, f.a(k) - 1.0)
	if over > 3:
		for k: String in ["maos", "chutes", "defesa", "def_queda", "queda"]:
			if w.rng.randf() < (over - 3) * 0.004:
				f.attrs[k] = maxf(15.0, f.a(k) - 1.0)


static func _injure(w: GameWorld, f: Fighter, name: String, weeks: int, where: String) -> void:
	f.injury = {"name": name, "weeks": weeks}
	f.condition = minf(f.condition, 70.0)
	var b := w.bout(f.bout_id)
	if b != null and b.status == "marcada" and b.week - w.week < weeks + 1:
		Career.cancel_bout(w, b, "%s se machucou %s (%s)" % [f.display_name(), where, name.to_lower()])
	elif w.is_user_fighter(f):
		w.add_news("equipe", "%s se machucou %s: %s, %d semanas fora." % [f.display_name(), where, name.to_lower(), weeks], [f.id], true)


## Lesão depois da luta, pelo dano que levou.
static func after_fight(w: GameWorld, f: Fighter, head: float, body: float, legs: float, cut: float, lost_by_ko: bool) -> void:
	var dmg := head + body * 0.6 + legs * 0.5
	f.condition = clampf(f.condition - 18.0 - dmg * 14.0, 20.0, 100.0)
	f.wear += head * 0.5
	if lost_by_ko:
		f.suspension = maxi(f.suspension, w.rng.randi_range(6, 10))
	var p := clampf(dmg * 0.12 + (0.3 if cut > 0.6 else 0.0), 0.0, 0.6)
	if w.rng.randf() < p:
		var pool := [0, 1, 3, 2, 6] if cut <= 0.6 else [0, 0, 1]
		var inj: Array = INJURIES[pool[w.rng.randi_range(0, pool.size() - 1)]]
		f.injury = {"name": inj[0], "weeks": w.rng.randi_range(int(inj[1]), int(inj[2]))}
		if w.is_user_fighter(f):
			w.add_news("equipe", "%s saiu da luta com %s: %d semanas de recuperação." % [f.display_name(), String(inj[0]).to_lower(), int(f.injury["weeks"])], [f.id])


## Mensal: aposentadorias e a nova safra de amadores.
static func month(w: GameWorld) -> void:
	var y := w.year()
	var m := w.month()
	for f: Fighter in w.fighters.values():
		if f.retired or f.bout_id >= 0:
			continue
		var age := f.age(y, m)
		if age < 33:
			continue
		var p := (age - 33) * 0.018 + (0.04 if f.streak <= -3 else 0.0) + (0.03 if f.level() < 55 else 0.0)
		if age >= 42:
			p = 0.6
		if w.rng.randf() < p:
			retire(w, f)
	var divs := DataDB.divisions()
	for _i in 9:
		var d: Dictionary = divs[w.rng.randi_range(0, divs.size() - 1)]
		var f := FighterGenerator.make(w, String(d["id"]), w.rng.randf_range(36.0, 56.0), 0, true)
		w.fighters[f.id] = f
		# Metade vai direto para uma academia rival; a outra metade fica no mercado.
		if w.rng.randf() < 0.5:
			var teams: Array = w.teams.values().filter(func(t: Team) -> bool: return not t.is_user)
			var t: Team = teams[w.rng.randi_range(0, teams.size() - 1)]
			f.team_id = t.id
			f.contract = {"cut": 0.2, "fights": 4}


static func retire(w: GameWorld, f: Fighter) -> void:
	f.retired = true
	var was_champ := int(w.champions.get(f.division, -1)) == f.id
	if was_champ:
		w.champions[f.division] = -1
	var mine := w.is_user_fighter(f)
	if f.level() >= 70 or mine or was_champ:
		w.add_news("aposentadoria", "%s se aposenta aos %d anos, com cartel de %s%s." % [f.display_name(), w.age_of(f), f.record_text(), " e deixa o cinturão vago" if was_champ else ""], [f.id], mine or was_champ)
