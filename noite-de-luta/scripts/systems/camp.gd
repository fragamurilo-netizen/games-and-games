class_name Camp
extends RefCounted
## Camp: o campo de treino das semanas antes da luta. Começa oito semanas antes (ou quando a
## luta é marcada, se for em cima da hora) e vale só para aquela luta: junta pontos de forma
## toda semana (`week`) e, na noite, vira ajuste de atributo (`mods`) pelo foco escolhido.
##
## O que o jogador decide (aba Treino do perfil, enquanto houver luta marcada):
## - foco: estudar o adversário, afiar o ponto forte, fôlego ou corte de peso;
## - onde: em casa (os técnicos da academia) ou fora, numa academia grande (paga por semana);
## - sparring contratado: parceiros que imitam o adversário (pago, rende mais, risco de lesão);
## - a intensidade do treino é a mesma da aba: pesado junta mais forma e cansa. Chegar na semana
##   da luta com a condição física baixa cobra fôlego e queixo, então as últimas semanas pedem
##   treino leve.
## Durante o camp o treino normal rende 75% (o tempo vai para a luta, não para evoluir).
##
## Os lutadores das outras equipes fazem o camp sozinhos (`auto_points`): a qualidade vem da
## academia, do jeito do lutador e de um pouco de sorte.

## Semanas de camp antes da luta.
const WEEKS := 8
const AWAY_QUALITY := 80.0
const FOCUS := {
	"plano": {"name": "Estudar o adversário", "help": "Treina a resposta para a arma mais forte dele: rende QI de luta e a defesa certa."},
	"forte": {"name": "Afiar o ponto forte", "help": "Aposta no que o seu lutador faz de melhor."},
	"folego": {"name": "Fôlego", "help": "Gás para a luta longa. Vale mais em luta de cinco rounds."},
	"peso": {"name": "Corte de peso", "help": "Dieta desde cedo: bate o peso sem drama e sem perder o fôlego."},
}
const FOCUS_ORDER := ["plano", "forte", "folego", "peso"]


## A luta marcada para a qual o camp vale (ou null).
static func bout_of(w: GameWorld, f: Fighter) -> Bout:
	var b := w.bout(f.bout_id)
	return b if b != null and b.status == "marcada" else null


static func blank(b: Bout, week: int) -> Dictionary:
	return {"bout": b.id, "focus": "plano", "place": "casa", "spar": false, "weeks": 0, "pts": 0.0, "cost": 0.0, "start": week}


## Camp do lutador para a luta marcada (cria na primeira vez; vazio se não há luta).
static func ensure(w: GameWorld, f: Fighter) -> Dictionary:
	var b := bout_of(w, f)
	if b == null:
		if not f.camp.is_empty():
			f.camp = {}
		return {}
	if int(f.camp.get("bout", -1)) != b.id:
		var c := blank(b, w.week)
		# Mantém o jeito de trabalhar do camp anterior (onde e sparring), menos o foco.
		if not f.camp.is_empty():
			c["place"] = String(f.camp.get("place", "casa"))
			c["spar"] = bool(f.camp.get("spar", false))
		f.camp = c
	return f.camp


## Semanas de camp que ainda faltam (a semana da luta não conta: é só a pesagem).
static func weeks_left(w: GameWorld, f: Fighter) -> int:
	var b := bout_of(w, f)
	if b == null:
		return 0
	return clampi(b.week - w.week, 0, WEEKS)


## Semanas até o camp começar (0 = já começou).
static func starts_in(w: GameWorld, f: Fighter) -> int:
	var b := bout_of(w, f)
	if b == null:
		return 0
	return maxi(0, b.week - w.week - WEEKS)


static func in_window(w: GameWorld, f: Fighter) -> bool:
	var b := bout_of(w, f)
	return b != null and b.week > w.week and b.week - w.week <= WEEKS


# --- Custos -------------------------------------------------------------------------------

static func spar_cost(w: GameWorld, f: Fighter) -> float:
	var b := bout_of(w, f)
	var o := w.fighter(b.other(f.id)) if b != null else null
	return snappedf(350.0 + (o.level() if o != null else 50) * 22.0, 50.0)


static func away_cost(f: Fighter) -> float:
	return snappedf(1200.0 + f.level() * 35.0, 50.0)


static func weekly_cost(w: GameWorld, f: Fighter) -> float:
	var c := f.camp
	if c.is_empty():
		return 0.0
	return (away_cost(f) if String(c.get("place", "casa")) == "fora" else 0.0) + (spar_cost(w, f) if bool(c.get("spar", false)) else 0.0)


# --- Semana -------------------------------------------------------------------------------

## Qualidade dos técnicos que tocam o camp.
static func coach_quality(w: GameWorld, f: Fighter, team: Team) -> float:
	var home := Morale.gym_quality(w, team)
	if String(f.camp.get("place", "casa")) == "fora":
		return maxf(home, AWAY_QUALITY)
	return home


## Pontos de forma que uma semana de camp rende hoje (para a prévia na tela).
static func week_gain(w: GameWorld, f: Fighter, team: Team) -> float:
	if not f.injury.is_empty() or int(f.training.get("off", -1)) == w.week:
		return 0.0
	var intensity := clampi(int(f.training.get("intensity", 1)), 0, 2)
	var g: float = (4.0 + coach_quality(w, f, team) * 0.13) * [0.72, 1.0, 1.22][intensity]
	if f.condition < 70.0:
		g *= 0.75
	if bool(f.camp.get("spar", false)):
		g *= 1.2
	return g * Persona.train_k(f) * Morale.train_k(w, f)


## Uma semana de camp (equipe do jogador). Chamado antes do treino da semana.
static func week(w: GameWorld, f: Fighter, team: Team) -> void:
	var c := ensure(w, f)
	if c.is_empty() or not in_window(w, f):
		return
	var cost := weekly_cost(w, f)
	if cost > 0.0 and team != null:
		if team.balance < cost:
			c["place"] = "casa"
			c["spar"] = false
			w.add_news("equipe", "Sem caixa para o camp de %s: voltou a treinar em casa, sem sparring contratado." % f.display_name(), [f.id], true)
		else:
			team.add_money(w.week, "Camp de %s" % f.short_name(), -cost)
			c["cost"] = float(c.get("cost", 0.0)) + cost
	c["weeks"] = int(c.get("weeks", 0)) + 1
	c["pts"] = minf(100.0, float(c.get("pts", 0.0)) + week_gain(w, f, team))
	# Sparring duro machuca de vez em quando.
	if bool(c.get("spar", false)) and f.injury.is_empty() and w.rng.randf() < 0.006:
		Development.injure(w, f, "Corte no supercílio", w.rng.randi_range(2, 4), "no sparring")


# --- Na noite -----------------------------------------------------------------------------

## Camp das outras equipes: pontos de forma pela academia, pelo jeito dele e pela sorte.
static func auto_points(w: GameWorld, f: Fighter, b: Bout) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([w.seed, b.id, f.id, "camp"])
	var team := w.team(f.team_id)
	var q := team.staff_quality("striking") if team != null else 22.0
	return clampf((4.0 + q * 0.13) * 5.5 * Persona.train_k(f) * lerpf(0.9, 1.08, f.morale / 100.0) * r.randf_range(0.75, 1.2), 8.0, 100.0)


static func auto_focus(f: Fighter, b: Bout) -> String:
	if b.rounds >= 5 and f.a("cardio") < 62.0:
		return "folego"
	return "plano" if f.a("qi") >= 58.0 else "forte"


static func has_own(w: GameWorld, f: Fighter, b: Bout) -> bool:
	return w.is_user_fighter(f) and int(f.camp.get("bout", -1)) == b.id


static func points(w: GameWorld, f: Fighter, b: Bout) -> float:
	if has_own(w, f, b):
		return float(f.camp.get("pts", 0.0))
	return auto_points(w, f, b)


static func focus_of(w: GameWorld, f: Fighter, b: Bout) -> String:
	if has_own(w, f, b):
		return String(f.camp.get("focus", "plano"))
	return auto_focus(f, b)


## A defesa que responde à arma mais forte do adversário.
static func counter_attr(opp: Fighter) -> String:
	var st := opp.avg(["maos", "chutes", "potencia"])
	var wr := opp.avg(["queda", "por_cima"])
	var jj := opp.avg(["finalizacao", "por_baixo"])
	if wr >= st and wr >= jj:
		return "def_queda"
	if jj > st:
		return "def_finalizacao"
	return "defesa"


## Os dois atributos do ponto forte dele.
static func strong_attrs(f: Fighter) -> Array:
	var st := f.avg(["maos", "chutes", "potencia"])
	var wr := f.avg(["queda", "por_cima"])
	var jj := f.avg(["finalizacao", "por_baixo"])
	if wr >= st and wr >= jj:
		return ["queda", "por_cima"]
	if jj > st:
		return ["finalizacao", "por_baixo"]
	return ["chutes" if f.a("chutes") > f.a("maos") else "maos", "movimentacao"]


## Ajustes de atributo que o camp dá na noite da luta.
static func mods(w: GameWorld, f: Fighter, opp: Fighter, b: Bout) -> Dictionary:
	return mods_for(points(w, f, b), focus_of(w, f, b), f, opp, b, has_own(w, f, b) and bool(f.camp.get("spar", false)))


static func mods_for(pts: float, focus: String, f: Fighter, opp: Fighter, b: Bout, spar: bool) -> Dictionary:
	var k := clampf(pts / 100.0, 0.0, 1.0)
	var m := {"cardio": 2.0 * k, "velocidade": 1.0 * k}
	match focus:
		"plano":
			var s := 1.25 if spar else 1.0
			m["qi"] = 4.0 * k * s
			var ca := counter_attr(opp)
			m[ca] = float(m.get(ca, 0.0)) + 4.0 * k * s
		"forte":
			for a: String in strong_attrs(f):
				m[a] = float(m.get(a, 0.0)) + 3.0 * k
		"folego":
			m["cardio"] = float(m["cardio"]) + (6.0 if b.rounds >= 5 else 4.0) * k
			m["coracao"] = 2.0 * k
		"peso":
			pass
	for a: String in m.keys():
		m[a] = snappedf(float(m[a]), 0.1)
		if absf(float(m[a])) < 0.05:
			m.erase(a)
	return m


## Quanto do sofrimento do corte de peso o camp tira (0–0,8). Só com o foco no peso.
static func cut_relief(w: GameWorld, f: Fighter, b: Bout) -> float:
	if focus_of(w, f, b) != "peso":
		return 0.0
	return clampf(points(w, f, b) / 100.0, 0.0, 1.0) * 0.8


static func label(pts: float) -> String:
	if pts >= 85.0:
		return "impecável"
	if pts >= 65.0:
		return "muito bom"
	if pts >= 45.0:
		return "bom"
	if pts >= 25.0:
		return "curto"
	return "quase sem camp"


## O que o camp rende na noite, em texto: ["+3 QI de luta", "+3 defesa de queda", ...].
static func gain_lines(m: Dictionary) -> Array:
	var keys := m.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return float(m[a]) > float(m[b]))
	var out: Array = []
	for a: String in keys:
		var v := int(round(float(m[a])))
		if v != 0:
			out.append("%s %s" % [Fmt.signed(v), String(Fighter.ATTR_NAMES.get(a, a)).to_lower().replace("qi de luta", "QI de luta")])
	return out
