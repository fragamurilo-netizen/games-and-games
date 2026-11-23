class_name Persona
extends RefCounted
## Personalidade do lutador: dois traços (`Fighter.traits`) que mexem no jogo e no rosto.
##
## Onde cada traço pesa:
## - balança (`weight_k`): disciplinado quase nunca erra o peso, preguiçoso erra o dobro;
## - treino (`train_k`): disciplinado evolui mais, preguiçoso menos;
## - fama (`fame_k`): falastrão, showman e encrenqueiro ganham nome mais rápido, humilde mais devagar;
## - aceitar luta (`accept_mod`): mercenário segue o dinheiro, guerreiro topa quase tudo, humilde não
##   se importa com adversário de ranking baixo, e o falastrão quer nome grande;
## - noite grande (`fight_mods`): frio cresce em luta principal e de cinturão, nervoso trava;
##   guerreiro aguenta mais (coração);
## - coletiva e semana da luta (FightWeek): falastrão e encrenqueiro arrumam confusão na coletiva
##   antes da luta (mais público, risco de multa); na pós-luta, humilde aceita conselho, os
##   esquentados se ofendem;
## - rosto: a expressão da foto segue o jeito dele (confiante, sério, sorriso tímido...).

const TRAITS := {
	"falastrao": {"name": "Falastrão", "desc": "Provoca todo mundo e vende a luta. A fama cresce rápido; quer adversário de nome.", "ex": [5, 2]},
	"humilde": {"name": "Humilde", "desc": "Respeita todo adversário e aceita conselho. Cresce devagar na mídia.", "ex": [1, 0]},
	"disciplinado": {"name": "Disciplinado", "desc": "Camp sério: evolui mais no treino e quase nunca erra o peso.", "ex": [3, 0]},
	"preguicoso": {"name": "Preguiçoso", "desc": "Treina no automático e sofre na balança.", "ex": [0, 1]},
	"encrenqueiro": {"name": "Encrenqueiro", "desc": "Briga na coletiva, rende manchete e às vezes multa.", "ex": [9, 3]},
	"frio": {"name": "Frio", "desc": "Não sente a pressão: rende mais em luta principal e de cinturão.", "ex": [0, 3]},
	"nervoso": {"name": "Nervoso", "desc": "Sente o peso das noites grandes e trava um pouco.", "ex": [8, 0]},
	"mercenario": {"name": "Mercenário", "desc": "Luta por dinheiro: bolsa maior convence, bolsa da tabela não.", "ex": [5, 8]},
	"guerreiro": {"name": "Guerreiro", "desc": "Gosta da guerra: topa quase qualquer luta e aguenta mais quando apanha.", "ex": [3, 5]},
	"showman": {"name": "Showman", "desc": "Luta para a plateia: nocaute bonito vira fama em dobro.", "ex": [2, 5]},
}
## Pares que não combinam no mesmo lutador.
const CLASH := [["falastrao", "humilde"], ["disciplinado", "preguicoso"], ["frio", "nervoso"], ["mercenario", "guerreiro"]]


static func make(f: Fighter, rng: RandomNumberGenerator, culture: String = "") -> void:
	var wts := {"falastrao": 1.0, "humilde": 1.2, "disciplinado": 1.3, "preguicoso": 0.7, "encrenqueiro": 0.6, "frio": 0.9,
		"nervoso": 0.6, "mercenario": 0.8, "guerreiro": 1.0, "showman": 0.7}
	for c: String in culture.split("+"):
		if c in ["dag", "chech", "kz", "uz", "tj", "jp", "kr"]:
			wts["humilde"] *= 2.0
			wts["disciplinado"] *= 1.8
			wts["falastrao"] *= 0.3
			wts["showman"] *= 0.4
	if f.nation in ["USA", "IRL", "GBR", "BRA", "MEX"]:
		wts["falastrao"] *= 1.5
		wts["showman"] *= 1.4
	if Styles.family(f.base) == "trocacao":
		wts["showman"] *= 1.3
		wts["guerreiro"] *= 1.2
	var out: Array = []
	for _i in 2:
		var pool := {}
		for k: String in wts:
			if out.has(k) or _clashes(k, out):
				continue
			pool[k] = wts[k]
		out.append(String(RngUtil.weighted_key(rng, pool)))
	f.traits = out
	# Expressão da foto pelo primeiro traço (a não ser que alguém já tenha escolhido no editor).
	if not f.look.has("ex"):
		var ex: Array = (TRAITS[out[0]] as Dictionary)["ex"]
		f.look["ex"] = int(ex[0] if rng.randf() < 0.65 else ex[1])


static func _clashes(k: String, have: Array) -> bool:
	for pair: Array in CLASH:
		if pair.has(k) and (have.has(pair[0]) or have.has(pair[1])):
			return true
	return false


static func has(f: Fighter, t: String) -> bool:
	return f != null and f.traits.has(t)


static func name_of(t: String) -> String:
	return String((TRAITS.get(t, {}) as Dictionary).get("name", t))


static func desc_of(t: String) -> String:
	return String((TRAITS.get(t, {}) as Dictionary).get("desc", ""))


static func label(f: Fighter) -> String:
	return " · ".join(f.traits.map(func(t: String) -> String: return name_of(t)))


static func weight_k(f: Fighter) -> float:
	var k := 1.0
	if has(f, "disciplinado"):
		k *= 0.3
	if has(f, "preguicoso"):
		k *= 2.0
	return k


static func train_k(f: Fighter) -> float:
	var k := 1.0
	if has(f, "disciplinado"):
		k *= 1.15
	if has(f, "preguicoso"):
		k *= 0.8
	return k


static func fame_k(f: Fighter, finish: bool) -> float:
	var k := 1.0
	if has(f, "falastrao"):
		k *= 1.5
	if has(f, "encrenqueiro"):
		k *= 1.25
	if has(f, "humilde"):
		k *= 0.8
	if has(f, "showman") and finish:
		k *= 2.0
	return k


## Ajuste na chance de aceitar uma luta (`rank_gap` > 0: adversário abaixo no ranking).
static func accept_mod(f: Fighter, rank_gap: int, mult: float, short_notice: bool) -> float:
	var p := 0.0
	if has(f, "mercenario"):
		p += (mult - 1.25) * 0.4
	if has(f, "guerreiro"):
		p += 0.12 + (0.1 if short_notice else 0.0)
	if has(f, "humilde") and rank_gap > 5:
		p += 0.15
	if has(f, "falastrao") and rank_gap > 5:
		p -= 0.1
	if has(f, "nervoso") and short_notice:
		p -= 0.1
	return p


## Modificadores de atributo na noite (somados aos da pesagem).
static func fight_mods(f: Fighter, big: bool) -> Dictionary:
	var m := {}
	if big and has(f, "frio"):
		m["qi"] = 5.0
		m["coracao"] = 3.0
	if big and has(f, "nervoso"):
		m["qi"] = -5.0
		m["cardio"] = -3.0
	if has(f, "guerreiro"):
		m["coracao"] = float(m.get("coracao", 0.0)) + 4.0
	return m


## Esquentado: arruma confusão na coletiva antes da luta.
static func hothead(f: Fighter) -> bool:
	return has(f, "falastrao") or has(f, "encrenqueiro")
