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
		var mine := w.is_user_fighter(f)
		if mine:
			Camp.week(w, f, team)
		elif not f.camp.is_empty():
			f.camp = {}
		if f.injury.is_empty() and not fight_week and int(f.training.get("off", -1)) != w.week:
			_train(w, f, team, f.age(y, m), 0.75 if mine and Camp.in_window(w, f) else 1.0)
		Morale.week(w, f)
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


static func _train(w: GameWorld, f: Fighter, team: Team, age: int, camp_k: float = 1.0) -> void:
	var intensity := int(f.training.get("intensity", 1)) if w.is_user_fighter(f) else 1
	var focus: Dictionary = (FOCUS.get(String(f.training.get("focus", "equilibrado")), FOCUS["equilibrado"]) as Dictionary)["w"]
	var age_k := 1.5 if age < 21 else (1.25 if age < 25 else (1.0 if age < 29 else (0.55 if age < 32 else 0.2)))
	var gap := clampf((f.potential - f.level()) / 8.0, 0.0, 1.6)
	var base: float = 0.16 * age_k * gap * [0.6, 1.0, 1.4][intensity] * camp_k * Morale.train_k(w, f)
	for k: String in Fighter.ATTRS:
		var g := String(GROUP_OF[k])
		if k in ["queixo", "coracao"]:
			continue # não se treina queixo
		var coach := team.staff_quality(String(COACH_OF[g])) if team != null else 20.0
		var amount := base * float(focus[g]) * (0.6 + coach / 100.0) * w.rng.randf_range(0.4, 1.6) * Persona.train_k(f)
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
		injure(w, f, String(inj[0]), w.rng.randi_range(int(inj[1]), int(inj[2])), "no treino")


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


static func injure(w: GameWorld, f: Fighter, name: String, weeks: int, where: String) -> void:
	f.injury = {"name": name, "weeks": weeks}
	f.condition = minf(f.condition, 70.0)
	Morale.bump(w, f, -4.0, "Lesão %s" % where)
	var b := w.bout(f.bout_id)
	var ev := w.event(b.event_id) if b != null else null
	if b != null and b.status == "marcada" and b.week - w.week < weeks + 1 and w.is_president() and ev != null and ev.tier == 2 and not ev.closed:
		if not FightWeek.has_incident(w, b.id):
			FightWeek.injury(w, b, f, name, where)
	elif b != null and b.status == "marcada" and b.week - w.week < weeks + 1:
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


## Mensal: aposentadorias, troca de categoria e a nova safra de amadores.
static func month(w: GameWorld) -> void:
	var y := w.year()
	var m := w.month()
	var active := {}
	for f: Fighter in w.fighters.values():
		if f.retired:
			continue
		if f.bout_id >= 0:
			active[f.division] = int(active.get(f.division, 0)) + 1
			continue
		var age := f.age(y, m)
		var idle := w.week - f.last_fight_week
		var p := 0.0
		if age >= 33:
			p = (age - 33) * 0.018 + (0.04 if f.streak <= -3 else 0.0) + (0.03 if f.level() < 55 else 0.0)
		if age >= 42:
			p = 0.6
		# Quem parou de lutar e não tem academia acaba largando.
		if f.is_pro() and idle > 78 and f.team_id < 0 and age >= 26:
			p = maxf(p, 0.12)
		elif not f.is_pro() and f.team_id < 0 and age >= 27:
			p = maxf(p, 0.05)
		if p > 0.0 and w.rng.randf() < p:
			retire(w, f)
			continue
		_maybe_change_division(w, f, age)
		active[f.division] = int(active.get(f.division, 0)) + 1
	# Safra nova: cada categoria repõe o que perdeu (o mundo não incha nem esvazia).
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var target := int(d.get("count", 60)) + maxi(4, int(int(d.get("count", 60)) * 0.14))
		var gap := float(target - int(active.get(div, 0)))
		var n := clampi(int(round(gap * 0.2 + w.rng.randf_range(-0.3, 1.0))), 0, 5)
		for _i in n:
			var f := FighterGenerator.make(w, div, w.rng.randf_range(36.0, 56.0), 0, true)
			w.fighters[f.id] = f
			# Metade vai direto para uma academia rival; a outra metade fica no mercado.
			if w.rng.randf() < 0.5:
				var teams: Array = w.teams.values().filter(func(t: Team) -> bool: return not t.is_user)
				var t: Team = teams[w.rng.randi_range(0, teams.size() - 1)]
				f.team_id = t.id
				f.contract = {"cut": 0.2, "fights": 4}


## Troca de categoria: quem perde corte de peso desce, quem cresceu sobe. Campeão não troca.
static func _maybe_change_division(w: GameWorld, f: Fighter, age: int) -> void:
	if int(w.champions.get(f.division, -1)) == f.id or not f.is_pro() or f.injury.size() > 0:
		return
	# O corpo cresce até perto dos 30 e pesa mais depois.
	if w.month() == 1 and w.week % 4 == 0:
		f.natural_kg = snappedf(f.natural_kg * (1.0 + (0.006 if age < 30 else 0.003)), 0.1)
	var divs := DataDB.divisions().filter(func(d: Dictionary) -> bool: return String(d.get("sex", "m")) == f.sex)
	var idx := -1
	for i in divs.size():
		if String(divs[i]["id"]) == f.division:
			idx = i
	if idx < 0:
		return
	var limit := float(divs[idx].get("limit_kg", 70.0))
	var recent: Array = f.history.slice(maxi(0, f.history.size() - 3))
	var losses := recent.filter(func(h: Dictionary) -> bool: return String(h["res"]) == "D").size()
	var to := -1
	var why := ""
	if idx < divs.size() - 1 and f.natural_kg > limit * 1.2 and w.rng.randf() < 0.12:
		to = idx + 1
		why = "não consegue mais bater o peso"
	elif idx > 0 and losses >= 2 and f.natural_kg < float(divs[idx - 1].get("limit_kg", 0.0)) * 1.17 and age < 33 and w.rng.randf() < 0.1:
		to = idx - 1
		why = "depois de %d derrotas, tenta a sorte numa categoria abaixo" % losses
	elif idx < divs.size() - 1 and losses >= 2 and age >= 30 and w.rng.randf() < 0.05:
		to = idx + 1
		why = "cansado de cortar peso depois de %d derrotas" % losses
	elif idx < divs.size() - 1 and f.title_defenses >= 3 and f.streak >= 4 and w.rng.randf() < 0.04:
		to = idx + 1
		why = "busca um segundo cinturão numa categoria acima"
	if to < 0:
		return
	var nd: Dictionary = divs[to]
	var old := f.division
	f.division = String(nd["id"])
	f.look["wt"] = float(nd.get("wt", 0.5))
	f.rating -= 60.0 # recomeça um pouco abaixo no ranking novo
	if f.level() >= 66 or w.is_user_fighter(f) or w.is_followed(f):
		w.add_news("categoria", "%s sai dos %s para os %s: %s." % [f.display_name(), Matchmaker.division_name(old, true), Matchmaker.division_name(f.division, true), why], [f.id], w.is_user_fighter(f))


## Uma vez por ano: o visual muda (penteado, barba, careca assumida) e o corpo acompanha a idade
## (o veterano engorda um pouco, o aposentado bem mais, e perde músculo).
static func yearly_look(w: GameWorld) -> void:
	var y := w.year()
	var m := w.month()
	var rng := w.rng
	for f: Fighter in w.fighters.values():
		var age := f.age(y, m)
		var bf := float(f.look.get("bf", 0.15))
		var ms := float(f.look.get("ms", 0.5))
		if f.retired:
			bf += rng.randf_range(0.02, 0.07)
			ms -= rng.randf_range(0.02, 0.06)
		elif age >= 31:
			bf += rng.randf_range(0.0, 0.025)
			if age >= 35:
				ms -= rng.randf_range(0.0, 0.03)
		f.look["bf"] = snappedf(clampf(bf, 0.04, 0.7), 0.01)
		f.look["ms"] = snappedf(clampf(ms, 0.1, 1.0), 0.01)
		if f.is_female():
			continue # o penteado delas já muda por fase no gerador de rostos
		if f.look.has("ed"):
			continue # visual escolhido no editor: cabelo e barba ficam como o jogador deixou
		var note := ""
		# Careca assumida: quem está perdendo cabelo raspa de vez.
		if f.look.has("hs") and int(f.look["hs"]) not in [FaceGen.H_BALD, FaceGen.H_BUZZ] and age >= 29:
			var free := f.look.duplicate()
			free.erase("hs")
			var ff := FaceGen.features(f.face_seed, f.eth, age, free)
			if float(ff.get("crown", 0.0)) > 0.3 or int(ff.get("style", 0)) == FaceGen.H_BALD:
				if rng.randf() < 0.5:
					f.look["hs"] = FaceGen.H_BALD if rng.randf() < 0.55 else FaceGen.H_BUZZ
					note = "raspou a cabeça"
		if note == "" and rng.randf() < (0.1 if f.retired else 0.18):
			var t := FighterGenerator.grooming_table(rng, String(f.look.get("cu", _culture_guess(f))))
			var hw: Dictionary = t.get("hair", {})
			if not hw.is_empty() and rng.randf() < float(t.get("hair_p", 0.4)):
				var hs := int(RngUtil.weighted_key(rng, hw))
				if hs != int(f.look.get("hs", -1)):
					f.look["hs"] = hs
					note = "mudou o cabelo"
			elif f.look.has("hs"):
				f.look.erase("hs")
				note = "deixou o cabelo crescer"
		if rng.randf() < (0.08 if f.retired else 0.14):
			var t2 := FighterGenerator.grooming_table(rng, String(f.look.get("cu", _culture_guess(f))))
			var bw: Dictionary = t2.get("beard", {})
			if not bw.is_empty() and rng.randf() < float(t2.get("beard_p", 0.3)) + 0.2:
				var bd := int(RngUtil.weighted_key(rng, bw))
				if bd != int(f.look.get("bd", -1)):
					f.look["bd"] = bd
					note = "mudou a barba" if note == "" else note + " e a barba"
			elif f.look.has("bd"):
				f.look.erase("bd")
				note = "mudou a barba" if note == "" else note + " e a barba"
		if note != "" and not f.retired and (w.is_user_fighter(f) or w.is_followed(f)):
			w.add_news("visual", "Visual novo: %s %s." % [f.display_name(), note], [f.id])


static func _culture_guess(f: Fighter) -> String:
	return {"DAG": "dag", "CHE": "chech", "THA": "th", "JPN": "jp", "KOR": "kr", "CHN": "cn", "KAZ": "kz", "UZB": "uz",
		"KGZ": "kg", "TJK": "tj", "AZE": "az", "ARM": "am", "GEO": "ge", "IRN": "persian", "AFG": "afg", "RUS": "ru",
		"UKR": "ua", "PHI": "ph", "MAR": "maghreb", "ALG": "maghreb"}.get(f.nation, "*")


static func retire(w: GameWorld, f: Fighter) -> void:
	f.retired = true
	f.retired_week = w.week
	var was_champ := int(w.champions.get(f.division, -1)) == f.id
	if was_champ:
		w.champions[f.division] = -1
	var mine := w.is_user_fighter(f)
	if f.level() >= 70 or mine or was_champ:
		w.add_news("aposentadoria", "%s se aposenta aos %d anos, com cartel de %s%s." % [f.display_name(), w.age_of(f), f.record_text(), " e deixa o cinturão vago" if was_champ else ""], [f.id], mine or was_champ)
