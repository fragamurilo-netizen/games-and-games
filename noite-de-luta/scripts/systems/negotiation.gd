class_name Negotiation
extends RefCounted
## Empresário: negociar a proposta de luta antes de assinar. A proposta (`GameWorld.offers`)
## chega com bolsa, data, adversário e lugar no card; o empresário pode aceitar, recusar ou
## pedir (`ask`):
## - mais dinheiro (15%, 30% ou 50% a mais);
## - outro formato de bolsa: mais garantido e menos bônus de vitória, ou o contrário;
## - outra data, mais para a frente, para fazer o camp inteiro;
## - um lugar melhor no card (mais fama para o lutador).
## A organização responde pela força que o lutador tem na mesa (`leverage`): fama, ranking,
## sequência, o hype da luta, aviso curto (precisam dele) e a reputação da academia. Ela pode
## aceitar, chegar no meio do caminho, manter a proposta ou perder a paciência e retirar tudo
## (`patience`). Cada tipo de pedido só pode ser feito uma vez.

const ASKS := {
	"bolsa15": {"group": "bolsa", "name": "Pedir 15% a mais", "help": "Bolsa e bônus de vitória 15% maiores.", "cost": 0.2, "k": 0.15},
	"bolsa30": {"group": "bolsa", "name": "Pedir 30% a mais", "help": "Bolsa e bônus de vitória 30% maiores.", "cost": 0.38, "k": 0.3},
	"bolsa50": {"group": "bolsa", "name": "Pedir 50% a mais", "help": "Só com muita força na mesa.", "cost": 0.6, "k": 0.5},
	"garantia": {"group": "formato", "name": "Mais garantido, menos bônus", "help": "25% a mais para lutar e metade do bônus de vitória. Para quando a luta é dura.", "cost": 0.05},
	"aposta": {"group": "formato", "name": "Apostar na vitória", "help": "20% a menos para lutar e 70% a mais de bônus de vitória.", "cost": 0.0},
	"data": {"group": "data", "name": "Pedir uma data mais para a frente", "help": "Outra noite da mesma organização, para fazer o camp inteiro.", "cost": 0.15},
	"card": {"group": "card", "name": "Pedir um lugar melhor no card", "help": "Sobe um degrau: mais gente vê, a fama cresce mais.", "cost": 0.3},
}
const ORDER := ["bolsa15", "bolsa30", "bolsa50", "garantia", "aposta", "data", "card"]
const PATIENCE := 3
## Fama que se espera de quem luta em cada camada (abaixo disso pesa contra, acima pesa a favor).
const TIER_FAME := [12.0, 30.0, 52.0]


static func patience(o: Dictionary) -> int:
	return int(o.get("patience", PATIENCE))


static func asked(o: Dictionary, group: String) -> bool:
	return (o.get("asked", []) as Array).has(group)


## Força na mesa: {value (-0,4 a 0,6), reasons: [[texto, pontos]]}.
static func leverage(w: GameWorld, o: Dictionary) -> Dictionary:
	var f := w.fighter(int(o["fighter"]))
	var opp := w.fighter(int(o["opp"]))
	var ev := w.event(int(o["event"]))
	var rs: Array = []
	if f == null or opp == null or ev == null:
		return {"value": 0.0, "reasons": rs}
	var tier := clampi(ev.tier, 0, 2)
	var fame := clampf((f.popularity - float(TIER_FAME[tier])) / 100.0, -0.2, 0.3)
	if absf(fame) >= 0.03:
		rs.append(["%s tem nome para esse evento" % f.short_name() if fame > 0.0 else "%s ainda é pouco conhecid%s para esse evento" % [f.short_name(), "a" if f.is_female() else "o"], fame])
	var r := w.rank_of(f)
	var rank := 0.0
	if r == 0:
		rank = 0.25
		rs.append(["É a campeã" if f.is_female() else "É o campeão", rank])
	elif w.is_interim(f):
		rank = 0.18
		rs.append(["É a campeã interina" if f.is_female() else "É o campeão interino", rank])
	elif r > 0 and r <= 5:
		rank = 0.15
		rs.append(["Está no top 5", rank])
	elif r > 0 and r <= 15:
		rank = 0.07
		rs.append(["Está no top 15", rank])
	var streak := 0.0
	if f.streak >= 3:
		streak = 0.08
		rs.append(["Vem de %d vitórias seguidas" % f.streak, streak])
	elif f.streak <= -2:
		streak = -0.1
		rs.append(["Vem de %d derrotas seguidas" % -f.streak, streak])
	var hv := float(Hype.pair(w, f, opp, bool(o.get("title", false)), bool(o.get("interim", false)), ev.nation)["value"])
	var hype := clampf((hv - 35.0) / 250.0, -0.06, 0.2)
	if absf(hype) >= 0.03:
		rs.append(["A luta interessa ao público" if hype > 0.0 else "A luta interessa pouco ao público", hype])
	var notice := 0.0
	if int(o["week"]) - w.week <= 3:
		notice = 0.2
		rs.append(["É em cima da hora: precisam de alguém", notice])
	var star := 0.0
	if opp.popularity >= f.popularity + 20.0:
		star = -0.12
		rs.append(["Quem vende a luta é %s" % opp.short_name(), star])
	var t := w.user_team()
	var rep := (t.reputation if t != null else 30.0) / 400.0
	if rep >= 0.1:
		rs.append(["A academia é respeitada", rep])
	# A chance de cinturão é o prêmio: quem desafia tem menos força para exigir.
	var shot := 0.0
	if (bool(o.get("title", false)) or bool(o.get("interim", false))) and r != 0 and not w.is_interim(f):
		shot = -0.14
		rs.append(["Chance de cinturão ninguém recusa: a organização sabe disso", shot])
	return {"value": clampf(fame + rank + streak + hype + notice + star + rep, -0.4, 0.6) + shot, "reasons": rs}


static func leverage_label(v: float) -> String:
	if v >= 0.35:
		return "forte"
	if v >= 0.18:
		return "boa"
	if v >= 0.02:
		return "razoável"
	return "fraca"


## Dá para fazer este pedido? ("" = dá)
static func block_reason(w: GameWorld, o: Dictionary, key: String) -> String:
	var a: Dictionary = ASKS.get(key, {})
	if a.is_empty():
		return "Pedido desconhecido."
	if patience(o) <= 0:
		return "A organização não quer mais conversa: é aceitar ou recusar."
	if asked(o, String(a["group"])):
		return "Esse assunto já foi discutido."
	if key == "data" and later_event(w, o) == null:
		return "Não há outra noite com vaga mais para a frente."
	if key == "card":
		var s := slot_of(w, o)
		if s == "principal":
			return "Já é a luta principal."
		if bool(o.get("title", false)) or bool(o.get("interim", false)):
			return "Disputa de cinturão já é a luta principal."
	return ""


static func chance(w: GameWorld, o: Dictionary, key: String) -> float:
	var a: Dictionary = ASKS.get(key, {})
	var cost := float(a.get("cost", 0.3))
	if key == "card":
		# Subir para a principal ou a co-principal custa mais do que sair das preliminares.
		cost += {"prelim": 0.0, "card": 0.15, "co": 0.3}.get(slot_of(w, o), 0.0) as float
	return clampf(0.5 + float(leverage(w, o)["value"]) - cost, 0.03, 0.97)


## Outra noite da mesma camada, de 2 a 6 semanas depois da proposta, com vaga.
static func later_event(w: GameWorld, o: Dictionary) -> FightEvent:
	var ev := w.event(int(o["event"]))
	if ev == null:
		return null
	var opp := w.fighter(int(o["opp"]))
	for e: FightEvent in Calendar.open_events(w, ev.tier, ev.week + 2, ev.week + 6):
		if e.id == ev.id:
			continue
		if (bool(o.get("title", false)) or bool(o.get("interim", false))) and Card.has_belt(w, e):
			continue
		if opp != null and opp.suspension <= e.week - w.week:
			return e
	return null


## Lugar no card que a proposta promete.
static func slot_of(w: GameWorld, o: Dictionary) -> String:
	var f := w.fighter(int(o["fighter"]))
	var opp := w.fighter(int(o["opp"]))
	var ev := w.event(int(o["event"]))
	if f == null or opp == null or ev == null:
		return "card"
	if bool(o.get("title", false)) or bool(o.get("interim", false)):
		return "principal"
	return Card.slot_guess(w, ev, f, opp, false, int(o.get("billing", 0)))


static func _apply(w: GameWorld, o: Dictionary, key: String, part: float) -> String:
	var a: Dictionary = ASKS[key]
	match key:
		"bolsa15", "bolsa30", "bolsa50":
			var k := float(a["k"]) * part
			o["show"] = snappedf(float(o["show"]) * (1.0 + k), 100.0)
			o["win"] = snappedf(float(o["win"]) * (1.0 + k), 100.0)
			return "%d%% a mais" % int(round(k * 100.0))
		"garantia":
			o["show"] = snappedf(float(o["show"]) * 1.25, 100.0)
			o["win"] = snappedf(float(o["win"]) * 0.5, 100.0)
			return "mais garantido e menos bônus"
		"aposta":
			o["show"] = snappedf(float(o["show"]) * 0.8, 100.0)
			o["win"] = snappedf(float(o["win"]) * 1.7, 100.0)
			return "menos garantido e bônus de vitória maior"
		"data":
			var e := later_event(w, o)
			if e != null:
				o["event"] = e.id
				o["week"] = e.week
				o["expires"] = maxi(int(o["expires"]), w.week + 1)
				return "a luta passa para a %s, %s" % [e.name, GameWorld.fight_date_text(e.week)]
		"card":
			var before := slot_of(w, o)
			var guard := 0
			while slot_of(w, o) == before and int(o.get("billing", 0)) < 3 and guard < 4:
				guard += 1
				o["billing"] = int(o.get("billing", 0)) + 1
			return "o lugar no card passa a ser %s" % Card.slot_name(slot_of(w, o)).to_lower()
	return ""


## Faz o pedido. {ok, text, gone (a proposta foi retirada)}
static func ask(w: GameWorld, o: Dictionary, key: String) -> Dictionary:
	var why := block_reason(w, o, key)
	if why != "":
		return {"ok": false, "gone": false, "text": why}
	var a: Dictionary = ASKS[key]
	var p := chance(w, o, key)
	var lst: Array = o.get("asked", [])
	lst.append(String(a["group"]))
	o["asked"] = lst
	var roll := w.rng.randf()
	if roll < p:
		return {"ok": true, "gone": false, "text": "Os organizadores aceitaram: %s." % _apply(w, o, key, 1.0)}
	o["patience"] = patience(o) - 1
	if String(a["group"]) == "bolsa" and roll < p + 0.28:
		return {"ok": true, "gone": false, "text": "Chegaram no meio do caminho: %s." % _apply(w, o, key, 0.5)}
	if patience(o) <= 0 or roll > 0.93:
		w.offers.erase(o)
		return {"ok": false, "gone": true, "text": "Os organizadores perderam a paciência, retiraram a proposta e vão chamar outro lutador."}
	return {"ok": false, "gone": false, "text": "Não aceitaram. A proposta continua na mesa como estava."}
