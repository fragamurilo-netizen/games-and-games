class_name Scouting
extends RefCounted
## Potencial escondido. O teto de cada lutador (`Fighter.potential`) nunca aparece como número:
## o que o jogador vê é uma faixa de estrelas, mais estreita quanto mais a equipe conhece o
## lutador (`Fighter.known`, de 0 a 1).
##
## De onde vem o conhecimento:
## - olheiro contratado: dá uma ideia de todo mundo (até 40%, pela qualidade dele);
## - observação: o olheiro viaja para ver um lutador (`assign`), leva de 2 a 4 semanas, custa a
##   viagem e fecha a faixa até o limite dele (`cap`: 65% com um olheiro fraco, 95% com um ótimo);
## - a casa: quem treina na equipe do jogador é conhecido um pouco mais a cada semana.
## Todo mês o olheiro também indica um ou dois nomes do mercado (`month`): olheiro fraco indica
## mais gente que não é o que parece.
##
## No papel de presidente a organização tem o departamento de olheiros dela (qualidade pela
## reputação) e também manda observar; só não recebe indicações de mercado.

## Observações em andamento ao mesmo tempo.
const MAX_JOBS := 2
## Semanas em que uma indicação fica na lista.
const FIND_WEEKS := 16


static func quality(w: GameWorld) -> float:
	var t := w.user_team()
	if t == null:
		return 0.0
	if w.is_president():
		return clampf(42.0 + t.reputation * 0.45, 42.0, 86.0)
	return t.staff_quality("olheiro")


## Quem assina os relatórios.
static func scout_name(w: GameWorld) -> String:
	var t := w.user_team()
	if t == null or w.is_president():
		return "Os olheiros da organização"
	var s := t.staff_of("olheiro")
	return String(s.get("name", "O olheiro"))


## Até onde uma observação deste olheiro fecha a faixa.
static func cap(w: GameWorld) -> float:
	return clampf(0.5 + quality(w) * 0.005, 0.5, 0.97)


## Quanto a equipe sabe do lutador (0–1). 0 = nada (sem olheiro e nunca observado).
static func knowledge(w: GameWorld, f: Fighter) -> float:
	var k := f.known
	if w.is_user_fighter(f):
		k = maxf(k, 0.45)
	var q := quality(w)
	if q > 0.0:
		k = maxf(k, q / 100.0 * 0.4)
	return clampf(k, 0.0, 1.0)


## Erro fixo por lutador, de -1 a 1 (o olheiro erra sempre para o mesmo lado).
static func _noise(f: Fighter, salt: String) -> float:
	return float(absi(hash([f.id, f.face_seed, salt])) % 2001) / 1000.0 - 1.0


## Faixa do potencial que a equipe enxerga: {known, lo, hi, mid, exact} ou {known: 0, none: true}.
static func estimate(w: GameWorld, f: Fighter) -> Dictionary:
	var k := knowledge(w, f)
	if k <= 0.0:
		return {"known": 0.0, "none": true}
	var u := 1.0 - k
	var mid := f.potential + _noise(f, "olheiro") * u * 9.0
	var spread := u * 11.0
	var lo := clampf(mid - spread, float(f.level()), 99.0)
	var hi := clampf(mid + spread, lo, 99.0)
	return {"known": k, "lo": lo, "hi": hi, "mid": (lo + hi) * 0.5, "exact": u < 0.04, "none": false}


## Idade do auge como a equipe a enxerga (só com conhecimento razoável). -1 = não sabe.
static func peak_guess(w: GameWorld, f: Fighter) -> int:
	var k := knowledge(w, f)
	if k < 0.5:
		return -1
	return f.peak_age + int(round(_noise(f, "auge") * (1.0 - k) * 4.0))


static func ceiling_text(v: float) -> String:
	if v >= 88.0:
		return "campeão mundial"
	if v >= 81.0:
		return "disputa de cinturão"
	if v >= 74.0:
		return "ranqueado na elite"
	if v >= 66.0:
		return "bom nome nacional"
	if v >= 57.0:
		return "circuito regional"
	return "preliminar de evento pequeno"


## O relatório em frases: teto, o quanto ainda cresce e quando chega o auge.
static func report_lines(w: GameWorld, f: Fighter) -> Array:
	var est := estimate(w, f)
	var out: Array = []
	if bool(est.get("none", false)):
		return out
	var k := float(est["known"])
	var c_lo := ceiling_text(float(est["lo"]))
	var c_hi := ceiling_text(float(est["hi"]))
	if c_lo == c_hi:
		out.append("Teto de %s." % c_hi)
	else:
		out.append("Teto entre %s e %s." % [c_lo, c_hi])
	var age := w.age_of(f)
	var gap := float(est["mid"]) - float(f.level())
	var fem := f.is_female()
	if f.retired:
		return out
	if age >= f.peak_age + 2 and k >= 0.5:
		out.append("Já passou do auge: daqui para a frente é manter.")
	elif gap >= 14.0:
		out.append("Tem muito para crescer.")
	elif gap >= 7.0:
		out.append("Ainda cresce bastante.")
	elif gap >= 3.0:
		out.append("Cresce mais um pouco.")
	else:
		out.append("Já é quase tudo o que vai ser.")
	var pk := peak_guess(w, f)
	if pk > 0 and age < pk:
		out.append("Auge perto dos %d anos." % pk)
	elif pk > 0 and age <= pk + 1:
		out.append("Está no auge.")
	if k < 0.5:
		out.append("É só uma primeira impressão: mande observar para fechar a faixa." if not w.is_user_fighter(f) else "A comissão ainda está conhecendo %s." % ("ela" if fem else "ele"))
	return out


# --- Observações --------------------------------------------------------------------------

static func jobs(w: GameWorld) -> Array:
	return w.scouting.get("jobs", [])


static func job_of(w: GameWorld, f: Fighter) -> Dictionary:
	for j: Dictionary in jobs(w):
		if int(j["id"]) == f.id:
			return j
	return {}


static func weeks_for(w: GameWorld, f: Fighter) -> int:
	var t := w.user_team()
	var n := 2 if t != null and f.nation == t.nation else 3
	if quality(w) < 50.0:
		n += 1
	return n


static func cost_for(w: GameWorld, f: Fighter) -> float:
	var t := w.user_team()
	var away := t == null or f.nation != t.nation
	return snappedf(500.0 + f.level() * 20.0 + (900.0 if away else 0.0), 50.0)


## Por que não dá para mandar observar (vazio = pode).
static func block_reason(w: GameWorld, f: Fighter) -> String:
	if quality(w) <= 0.0:
		return "Contrate um olheiro no Mercado."
	if w.is_user_fighter(f):
		return "Treina na sua equipe: a comissão conhece mais a cada semana."
	if f.retired:
		return "Aposentado."
	if not job_of(w, f).is_empty():
		return "O olheiro já está observando."
	if f.known >= cap(w) - 0.01:
		return "O olheiro já disse tudo o que consegue ver."
	if jobs(w).size() >= MAX_JOBS:
		return "Já há %d observações em andamento." % MAX_JOBS
	var t := w.user_team()
	if t != null and t.balance < cost_for(w, f):
		return "Caixa curto para a viagem do olheiro."
	return ""


## Manda observar. Devolve o erro ou "".
static func assign(w: GameWorld, f: Fighter) -> String:
	var why := block_reason(w, f)
	if why != "":
		return why
	var n := weeks_for(w, f)
	var t := w.user_team()
	t.add_money(w.week, "Olheiro: viagem para ver %s" % f.short_name(), -cost_for(w, f))
	var lst: Array = jobs(w)
	lst.append({"id": f.id, "left": n, "total": n})
	w.scouting["jobs"] = lst
	return ""


static func week(w: GameWorld) -> void:
	# A casa conhece os seus um pouco mais a cada semana (perto de oito meses para saber tudo).
	var t := w.user_team()
	if t != null and not w.is_president():
		var q := Morale.gym_quality(w, t)
		for f: Fighter in w.user_fighters():
			f.known = minf(1.0, maxf(f.known, 0.45) + 0.012 + q / 6000.0)
	var keep: Array = []
	for j: Dictionary in jobs(w):
		var f := w.fighter(int(j["id"]))
		if f == null or f.retired:
			continue
		if quality(w) <= 0.0:
			continue # o olheiro foi embora no meio da viagem
		j["left"] = int(j["left"]) - 1
		if int(j["left"]) > 0:
			keep.append(j)
			continue
		f.known = maxf(f.known, cap(w))
		var lines := report_lines(w, f)
		w.add_news("olheiro", "Relatório do olheiro sobre %s (%s, %d anos): %s" % [f.display_name(), Matchmaker.division_short(f.division), w.age_of(f), " ".join(lines.slice(0, 2))], [f.id], true)
	w.scouting["jobs"] = keep


## Indicações do mês: o olheiro vê uma amostra do mercado e traz quem achou melhor.
static func month(w: GameWorld) -> void:
	var finds: Array = (w.scouting.get("finds", []) as Array).filter(func(x: Dictionary) -> bool:
		var f := w.fighter(int(x["id"]))
		return f != null and not f.retired and f.team_id < 0 and w.week - int(x["week"]) <= FIND_WEEKS)
	w.scouting["finds"] = finds
	var q := quality(w)
	if w.is_president() or q <= 0.0:
		return
	var have := {}
	for x: Dictionary in finds:
		have[int(x["id"])] = true
	var pool: Array = w.fighters.values().filter(func(f: Fighter) -> bool:
		return not f.retired and f.team_id < 0 and w.age_of(f) <= 26 and not have.has(f.id))
	if pool.is_empty():
		return
	var seen: Array = []
	for _i in clampi(8 + int(q / 6.0), 8, 24):
		seen.append(pool[w.rng.randi_range(0, pool.size() - 1)])
	var u := 1.0 - (0.3 + q * 0.003)
	var view := func(f: Fighter) -> float:
		return f.potential + _noise(f, "olheiro") * u * 9.0
	seen.sort_custom(func(a: Fighter, b: Fighter) -> bool: return float(view.call(a)) > float(view.call(b)))
	var n := 2 if q >= 70.0 else 1
	var picked := {}
	for f: Fighter in seen:
		if n <= 0:
			break
		if picked.has(f.id) or float(view.call(f)) - float(f.level()) < 6.0:
			continue
		picked[f.id] = true
		n -= 1
		f.known = maxf(f.known, 0.3 + q * 0.003)
		finds.append({"id": f.id, "week": w.week})
		w.add_news("olheiro", "%s indica %s (%s, %d anos): %s" % [scout_name(w), f.display_name(), Matchmaker.division_short(f.division), w.age_of(f), String(report_lines(w, f)[0]).to_lower()], [f.id], true)
	w.scouting["finds"] = finds


static func finds(w: GameWorld) -> Array:
	var out: Array = []
	for x: Dictionary in w.scouting.get("finds", []):
		var f := w.fighter(int(x["id"]))
		if f != null and not f.retired and f.team_id < 0:
			out.append([f, int(x["week"])])
	return out
