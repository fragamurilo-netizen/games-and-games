class_name Hype
extends RefCounted
## Termômetro de hype: quanto uma luta (e uma noite inteira) interessa ao público, de 0 a 100, e
## POR QUÊ. Cada motivo entra com os pontos que soma ou tira, para o jogador ler o que vende e
## o que esfria: fama dos dois, cinturão em jogo, rivalidade, revanche, duelo de ranqueados,
## sequência, invicto, falastrão, lutar em casa.
##
## A noite (`event`) é a luta principal inteira, mais uma parte da co-principal e do resto do
## card principal, mais o que cerca o evento (numerado, semana agitada, TV aberta). Card
## incompleto esfria. É este número que enche a arena, vende pay-per-view e faz a audiência
## (ver Venue, Org.projection e TVDeal).

const LEVELS := [[85.0, "Pegando fogo"], [70.0, "Quente"], [52.0, "Aquecendo"], [35.0, "Morno"], [0.0, "Frio"]]


static func label(v: float) -> String:
	for lv: Array in LEVELS:
		if v >= float(lv[0]):
			return String(lv[1])
	return "Frio"


## 0 (frio) a 4 (pegando fogo).
static func tone(v: float) -> int:
	for i in LEVELS.size():
		if v >= float((LEVELS[i] as Array)[0]):
			return LEVELS.size() - 1 - i
	return 0


## Quanto a fama de um lutador puxa o público. A curva é de propósito: nome mediano vende
## pouco, estrela vende muito (fama 55 vale 38, fama 75 vale 63, fama 95 vale 92). Na conta da
## luta entra 30% do nome maior e 22% do menor: campeão contra desafiante conhecido dá uns 45
## pontos só de fama, dois nomes medianos dão 20. A escada que se quer: card de desconhecidos é
## frio, duelo de top 10 é morno, duelo de top 5 aquece, cinturão com campeão famoso é quente, e
## só superluta ou rivalidade de verdade pega fogo.
static func fame_pull(popularity: float) -> float:
	return pow(clampf(popularity, 0.0, 100.0) / 100.0, 1.6) * 100.0


static func _ranked(r: int, top: int) -> bool:
	return r >= 0 and r <= top


## Hype de uma luta entre os dois: {value, reasons: [[texto, pontos], ...]}.
## `nation` é o país da noite (quem luta em casa vende mais).
static func pair(w: GameWorld, fa: Fighter, fb: Fighter, title: bool = false, interim: bool = false, nation: String = "") -> Dictionary:
	var rs: Array = []
	if fa == null or fb == null:
		return {"value": 0.0, "reasons": rs}
	var hi := maxf(fa.popularity, fb.popularity)
	var lo := minf(fa.popularity, fb.popularity)
	var star := fa if fa.popularity >= fb.popularity else fb
	var v := fame_pull(hi) * 0.3 + fame_pull(lo) * 0.22
	var fame := "Pouca gente conhece os dois"
	if lo >= 80.0:
		fame = "Duas estrelas"
	elif hi >= 85.0:
		fame = "%s é estrela" % star.short_name()
	elif lo >= 62.0:
		fame = "Dois nomes conhecidos"
	elif hi >= 62.0:
		fame = "%s tem nome" % star.short_name()
	elif hi >= 40.0:
		fame = "Nomes conhecidos de quem acompanha"
	rs.append([fame, v])
	if lo >= 85.0:
		rs.append(["Superluta: os dois lotam arena sozinhos", 6.0])
	# Cinturão.
	var it := int(w.interim.get(fa.division, -1))
	var champ := int(w.champions.get(fa.division, -1))
	if title:
		if it >= 0 and (fa.id == it or fb.id == it) and (fa.id == champ or fb.id == champ):
			rs.append(["Unificação: campeão contra o interino", 16.0])
		else:
			rs.append(["Vale o cinturão", 12.0])
	elif interim:
		rs.append(["Vale o cinturão interino", 7.0])
	# Rivalidade e revanche.
	var e := Rivalry.entry(w, fa.id, fb.id)
	var heat := float(e.get("heat", 0.0))
	if heat >= 12.0:
		rs.append(["%s: %s" % [Rivalry.label(heat), String(e.get("why", "eles têm história"))], heat * 0.14])
	var kind := Rivalry.rematch_kind(fa, fb)
	if kind != "":
		var close := Rivalry.last_was_close(fa, fb)
		rs.append(["%s%s" % [kind, ": a última foi apertada" if close else " (%s para %s)" % [Rivalry.h2h_text(fa, fb.id), fa.short_name()]], 7.0 if close else 4.0])
		var seen := Rivalry.meetings(fa, fb.id)
		if seen >= 3:
			rs.append(["O público já viu essa luta %d vezes" % seen, -4.0 * float(mini(seen - 2, 3))])
	# Ranking.
	var ra := w.rank_of(fa)
	var rb := w.rank_of(fb)
	if _ranked(ra, 5) and _ranked(rb, 5):
		rs.append(["Duelo de top 5", 5.0])
	elif _ranked(ra, 15) and _ranked(rb, 15):
		rs.append(["Os dois no top 15", 2.5])
	if not title and not interim:
		var na := ra if ra >= 0 else 60
		var nb := rb if rb >= 0 else 60
		if absi(na - nb) >= 12 and mini(na, nb) <= 15:
			rs.append(["Luta desigual no ranking", -4.0])
	# Sequência e invencibilidade.
	if fa.streak >= 3 and fb.streak >= 3:
		rs.append(["Os dois vêm embalados", 4.0])
	elif fa.streak <= -2 and fb.streak <= -2:
		rs.append(["Os dois vêm de derrota", -4.0])
	for f: Fighter in [fa, fb]:
		if int(f.record.get("l", 0)) == 0 and int(f.record.get("w", 0)) >= 7:
			rs.append(["%s está invict%s (%s)" % [f.short_name(), "a" if f.is_female() else "o", f.record_text()], 3.0])
	# Jeito de lutar e de falar.
	if _finisher(fa) and _finisher(fb):
		rs.append(["Dois que não deixam para os juízes", 3.0])
	var loud: Fighter = fa if Persona.hothead(fa) else (fb if Persona.hothead(fb) else null)
	if loud != null:
		rs.append(["%s vende a luta falando" % loud.short_name(), 2.5])
	if nation != "":
		var home: Fighter = fa if fa.nation == nation else (fb if fb.nation == nation else null)
		if home != null:
			rs.append(["%s luta em casa" % home.short_name(), 2.5])
	var total := 0.0
	for r: Array in rs:
		total += float(r[1])
	return {"value": clampf(total, 0.0, 100.0), "reasons": rs}


static func _finisher(f: Fighter) -> bool:
	var wins := int(f.record.get("w", 0))
	return wins >= 6 and float(int(f.record.get("ko_w", 0)) + int(f.record.get("sub_w", 0))) / float(wins) >= 0.7


static func bout(w: GameWorld, b: Bout) -> Dictionary:
	var ev := w.event(b.event_id)
	return pair(w, w.fighter(b.a), w.fighter(b.b), b.title, b.interim, ev.nation if ev != null else "")


static func bout_value(w: GameWorld, b: Bout) -> float:
	return float(bout(w, b)["value"])


static func _names(w: GameWorld, b: Bout) -> String:
	return "%s × %s" % [w.fighter(b.a).short_name(), w.fighter(b.b).short_name()]


## Hype da noite: {value, reasons, main: hype da luta principal (com os motivos dela)}.
static func event(w: GameWorld, ev: FightEvent) -> Dictionary:
	var lst := Card.bouts(w, ev)
	var rs: Array = []
	if lst.is_empty():
		return {"value": 0.0, "reasons": [["Card vazio", 0.0]], "main": {}}
	var main: Bout = lst.back()
	var mh := bout(w, main)
	var v := float(mh["value"])
	rs.append(["Luta principal: %s" % _names(w, main), v])
	if lst.size() > 1:
		var co: Bout = lst[lst.size() - 2]
		var cp := bout_value(w, co) * 0.12
		rs.append(["Co-principal: %s" % _names(w, co), cp])
		v += cp
	var n_main := Card.main_card_size(ev)
	var rest := 0.0
	for i in range(maxi(0, lst.size() - n_main), lst.size() - 2):
		rest += bout_value(w, lst[i])
	if rest * 0.02 >= 0.5:
		rs.append(["Resto do card principal", rest * 0.02])
		v += rest * 0.02
	var belts := 0
	for i in lst.size() - 1:
		var b: Bout = lst[i]
		if b.title or b.interim:
			belts += 1
	if belts > 0:
		rs.append(["Mais um cinturão em jogo" if belts == 1 else "Mais %d cinturões em jogo" % belts, 3.0 * belts])
		v += 3.0 * belts
	if ev.ppv:
		rs.append(["Evento numerado", 3.0])
		v += 3.0
	if ev.hype > 0.0:
		rs.append(["Semana agitada: provocação na coletiva", ev.hype])
		v += ev.hype
	if w.is_president() and ev.tier == 2:
		var tvb := TVDeal.hype_bonus(w)
		if float(tvb[1]) != 0.0:
			rs.append(tvb)
			v += float(tvb[1])
	var k := minf(1.0, 0.55 + lst.size() / float(maxi(1, ev.slots)) * 0.45)
	if k < 0.995:
		rs.append(["Card incompleto (%d de %d lutas)" % [lst.size(), ev.slots], v * (k - 1.0)])
		v *= k
	return {"value": clampf(v, 0.0, 100.0), "reasons": rs, "main": mh}


static func event_value(w: GameWorld, ev: FightEvent) -> float:
	return float(event(w, ev)["value"])
