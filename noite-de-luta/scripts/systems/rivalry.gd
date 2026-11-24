class_name Rivalry
extends RefCounted
## Rivalidades e revanches. Uma rivalidade é um par de lutadores com "calor" de 0 a 100 e o
## motivo que mais pesou (`GameWorld.rivalries`). Ela nasce de luta apertada (decisão dividida,
## empate), de disputa de cinturão, de zebra, de quem não bateu o peso, de provocação pública e de
## briga na coletiva; esfria sozinha com o tempo e quando um dos dois abre dois de vantagem.
##
## Para que serve:
## - vende a luta (entra no termômetro, `Hype`);
## - libera a revanche imediata, que sem isso ninguém aceita (`rematch_ok`);
## - mexe com a moral: ganhar do rival vale mais, perder dói mais;
## - as equipes aceitam mais fácil uma luta contra o rival.
## Só guarda rivalidade de quem importa (ranqueado até o 40º, da equipe do jogador ou seguido),
## para o save não inchar.

## Calor a partir do qual a revanche imediata sai.
const REMATCH_HEAT := 34.0
## Calor a partir do qual vira notícia e aparece como "Rivalidade".
const NAMED := 38.0
const LEVELS := [[70.0, "Guerra declarada"], [38.0, "Rivalidade"], [20.0, "Tem história"], [0.0, "Faísca"]]
const CALLOUTS := [
	"%s provoca %s: \"Ele sabe onde me encontrar. Assina logo.\"",
	"%s não perdoa %s: \"Está fugindo de mim há meses.\"",
	"%s manda recado para %s: \"Esse lugar no ranking é emprestado.\"",
	"%s chama %s para a luta: \"Um de nós dois está sobrando nessa categoria.\"",
	"%s debocha de %s nas redes: \"Ganhou de quem até hoje?\"",
]
const CALLOUTS_F := [
	"%s provoca %s: \"Ela sabe onde me encontrar. Assina logo.\"",
	"%s não perdoa %s: \"Está fugindo de mim há meses.\"",
	"%s manda recado para %s: \"Esse lugar no ranking é emprestado.\"",
	"%s chama %s para a luta: \"Uma de nós duas está sobrando nessa categoria.\"",
	"%s debocha de %s nas redes: \"Ganhou de quem até hoje?\"",
]


static func key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


static func entry(w: GameWorld, a: int, b: int) -> Dictionary:
	return w.rivalries.get(key(a, b), {})


static func heat(w: GameWorld, fa: Fighter, fb: Fighter) -> float:
	if fa == null or fb == null:
		return 0.0
	return float(entry(w, fa.id, fb.id).get("heat", 0.0))


static func label(h: float) -> String:
	for lv: Array in LEVELS:
		if h >= float(lv[0]):
			return String(lv[1])
	return "Faísca"


## Vale guardar? Só quando um dos dois é nome do ranking, da equipe do jogador ou seguido.
static func _matters(w: GameWorld, fa: Fighter, fb: Fighter) -> bool:
	for f: Fighter in [fa, fb]:
		if w.is_user_fighter(f) or w.is_followed(f):
			return true
		var r := w.rank_of(f)
		if r >= 0 and r <= 40:
			return true
	return false


## Esquenta (ou cria) a rivalidade. `why` vira o motivo quando é o maior empurrão até aqui.
## Devolve true quando ela passa a ter nome (cruzou `NAMED`).
static func add(w: GameWorld, fa: Fighter, fb: Fighter, amount: float, why: String) -> bool:
	if fa == null or fb == null or fa.id == fb.id or amount == 0.0:
		return false
	var k := key(fa.id, fb.id)
	var e: Dictionary = w.rivalries.get(k, {})
	if e.is_empty():
		if amount < 8.0 or not _matters(w, fa, fb):
			return false
		e = {"heat": 0.0, "why": why, "since": w.week, "last": w.week, "top": 0.0}
	var before := float(e["heat"])
	# Quanto mais quente, mais difícil esquentar: ninguém vive no 100.
	if amount > 0.0:
		amount *= clampf(1.0 - before / 125.0, 0.3, 1.0)
	e["heat"] = clampf(before + amount, 0.0, 100.0)
	e["last"] = w.week
	if amount >= float(e.get("top", 0.0)) and why != "":
		e["why"] = why
		e["top"] = amount
	if float(e["heat"]) < 4.0:
		w.rivalries.erase(k)
		return false
	w.rivalries[k] = e
	return before < NAMED and float(e["heat"]) >= NAMED


## Rivais de `f`, do mais quente para o mais frio: [[Fighter, entrada], ...].
static func of(w: GameWorld, f: Fighter, min_heat: float = 12.0) -> Array:
	var out: Array = []
	var me := str(f.id)
	for k: String in w.rivalries:
		var parts := k.split(":")
		if parts[0] != me and parts[1] != me:
			continue
		var e: Dictionary = w.rivalries[k]
		if float(e.get("heat", 0.0)) < min_heat:
			continue
		var o := w.fighter(int(parts[1] if parts[0] == me else parts[0]))
		if o != null:
			out.append([o, e])
	out.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]["heat"]) > float(y[1]["heat"]))
	return out


## Lutas no jogo entre os dois, do ponto de vista de `f`: [vitórias, derrotas, empates].
static func h2h(f: Fighter, opp_id: int) -> Array:
	var r := [0, 0, 0]
	for h: Dictionary in f.history:
		if int(h.get("opp", -1)) != opp_id:
			continue
		var res := String(h.get("res", ""))
		if res == "V":
			r[0] += 1
		elif res == "D":
			r[1] += 1
		else:
			r[2] += 1
	return r


static func meetings(f: Fighter, opp_id: int) -> int:
	var r := h2h(f, opp_id)
	return int(r[0]) + int(r[1]) + int(r[2])


## "2 a 1" (vitórias de `f` primeiro), com empate quando houve.
static func h2h_text(f: Fighter, opp_id: int) -> String:
	var r := h2h(f, opp_id)
	if int(r[0]) + int(r[1]) + int(r[2]) == 0:
		return ""
	var t := "%d a %d" % [int(r[0]), int(r[1])]
	if int(r[2]) > 0:
		t += " e %s" % Fmt.plural(int(r[2]), "empate", "empates")
	return t


## Como se chama o próximo encontro: "" (primeira vez), "Revanche", "Trilogia", "Quarta luta".
static func rematch_kind(fa: Fighter, fb: Fighter) -> String:
	var n := meetings(fa, fb.id)
	if n <= 0:
		return ""
	if n == 1:
		return "Revanche"
	if n == 2:
		return "Trilogia"
	return "%s luta" % ["Quarta", "Quinta", "Sexta"][mini(n - 3, 2)]


static func _last_between(fa: Fighter, fb: Fighter) -> Dictionary:
	for i in range(fa.history.size() - 1, -1, -1):
		var h: Dictionary = fa.history[i]
		if int(h.get("opp", -1)) == fb.id:
			return h
	return {}


## A última luta entre os dois foi apertada? (empate, decisão dividida ou majoritária)
static func last_was_close(fa: Fighter, fb: Fighter) -> bool:
	var h := _last_between(fa, fb)
	if h.is_empty():
		return false
	if String(h.get("res", "")) == "E":
		return true
	var d := String(h.get("detail", ""))
	return d.contains("dividida") or d.contains("majorit")


## Revanche imediata: só sai quando há motivo (luta apertada, rivalidade quente, ou o cinturão
## trocou de mão e o ex-campeão tinha defesas).
static func rematch_ok(w: GameWorld, fa: Fighter, fb: Fighter) -> bool:
	# Depois da trilogia o assunto está encerrado: só outra luta apertada pede a quarta, e a
	# quinta em seguida ninguém compra.
	var n := meetings(fa, fb.id)
	if n >= 4:
		return false
	if n >= 3:
		return last_was_close(fa, fb)
	if last_was_close(fa, fb) or heat(w, fa, fb) >= REMATCH_HEAT:
		return true
	var h := _last_between(fa, fb)
	return not h.is_empty() and bool(h.get("title", false)) and bool(h.get("dethroned", false))


## Depois da luta (chamado em Career.resolve, com o histórico já escrito).
static func after_fight(w: GameWorld, b: Bout, winner_id: int, champ_before: int, ra: int, rb: int) -> void:
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	if fa == null or fb == null:
		return
	var method := String(b.result.get("method", "DEC"))
	var n := meetings(fa, fb.id)
	var gain := 0.0
	var why := ""
	var close := last_was_close(fa, fb)
	if winner_id < 0:
		gain += 22.0
		why = "empate que não resolveu nada"
	elif close:
		gain += 26.0
		why = "decisão apertada que um dos lados não engoliu"
	if b.title or b.interim:
		gain += 12.0
		if why == "":
			why = "disputa de cinturão"
	if winner_id >= 0 and champ_before >= 0 and champ_before != winner_id and b.title:
		gain += 8.0
		why = "o cinturão trocou de mão entre os dois"
	var rw := ra if winner_id == b.a else rb
	var rl := rb if winner_id == b.a else ra
	if winner_id >= 0 and rl >= 1 and rl <= 15 and (rw < 0 or rw - rl >= 8):
		gain += 10.0
		if why == "":
			why = "zebra que o favorito quer apagar"
	if not (b.weigh.get("missed", []) as Array).is_empty():
		gain += 10.0
		if why == "":
			why = "um deles não bateu o peso"
	if Persona.hothead(fa) or Persona.hothead(fb):
		gain += 6.0
	if n >= 2:
		gain += 12.0
		if why == "":
			why = "já se enfrentaram %d vezes" % n
	gain = minf(gain, 34.0)
	# Quem abre dois de vantagem encerra o assunto, e a trilogia decidida também.
	var r := h2h(fa, fb.id)
	if absi(int(r[0]) - int(r[1])) >= 2:
		gain = -30.0
		why = ""
	elif n >= 3 and winner_id >= 0 and not close:
		gain = -22.0
		why = ""
	elif gain == 0.0 and not entry(w, fa.id, fb.id).is_empty():
		gain = 6.0 if method == "DEC" else -8.0
	if gain == 0.0:
		return
	if add(w, fa, fb, gain, why):
		_announce(w, fa, fb, why)


static func _announce(w: GameWorld, fa: Fighter, fb: Fighter, why: String) -> void:
	var mine := w.is_user_fighter(fa) or w.is_user_fighter(fb)
	var ra := w.rank_of(fa)
	var rb := w.rank_of(fb)
	if not mine and not ((ra >= 0 and ra <= 15) or (rb >= 0 and rb <= 15)):
		return
	w.add_news("rivalidade", "Nasce uma rivalidade nos %s: %s e %s. O motivo: %s." % [Matchmaker.division_name(fa.division, true), fa.display_name(), fb.display_name(), why], [fa.id, fb.id], mine)


## Semana a semana: as rivalidades esfriam devagar, somem quando alguém se aposenta ou muda de
## categoria, e de vez em quando um falastrão provoca alguém acima dele.
static func week(w: GameWorld) -> void:
	if w.week % 4 == 0:
		for k: String in w.rivalries.keys():
			var e: Dictionary = w.rivalries[k]
			var parts := k.split(":")
			var fa := w.fighter(int(parts[0]))
			var fb := w.fighter(int(parts[1]))
			if fa == null or fb == null or fa.retired or fb.retired or fa.division != fb.division:
				w.rivalries.erase(k)
				continue
			# Com luta marcada entre os dois não esfria.
			if fa.bout_id >= 0 and fa.bout_id == fb.bout_id:
				continue
			e["heat"] = float(e["heat"]) - (1.0 if w.week - int(e.get("last", 0)) > 16 else 0.4)
			if float(e["heat"]) < 4.0:
				w.rivalries.erase(k)
	_callouts(w)


static func _callouts(w: GameWorld) -> void:
	for d: Dictionary in DataDB.divisions():
		if w.rng.randf() >= 0.07:
			continue
		var div := String(d["id"])
		var lst: Array = w.rankings.get(div, [])
		var loud: Fighter = null
		for i in mini(20, lst.size()):
			var f := w.fighter(int(lst[i]))
			if f != null and Persona.hothead(f) and f.bout_id < 0 and f.injury.is_empty() and w.rng.randf() < 0.5:
				loud = f
				break
		if loud == null:
			continue
		var r := w.rank_of(loud)
		var target: Fighter = null
		if r <= 3 and w.rng.randf() < 0.5:
			target = w.fighter(int(w.champions.get(div, -1)))
		if target == null:
			var lo := maxi(0, r - 6)
			var opts: Array = []
			for i in range(lo, r - 1):
				var o := w.fighter(int(lst[i]))
				if o != null and Matchmaker.can_face(w, loud, o):
					opts.append(o)
			if opts.is_empty():
				continue
			target = opts[w.rng.randi_range(0, opts.size() - 1)]
		if target == null or target.id == loud.id:
			continue
		var named := add(w, loud, target, 16.0 + w.rng.randf_range(0.0, 8.0), "provocação pública")
		Fame.add(w, loud, 1.0)
		var lines: Array = CALLOUTS_F if loud.is_female() else CALLOUTS
		var mine := w.is_user_fighter(loud) or w.is_user_fighter(target)
		w.add_news("rivalidade", String(lines[w.rng.randi_range(0, lines.size() - 1)]) % [loud.display_name(), target.display_name()], [loud.id, target.id], mine)
		if named:
			_announce(w, loud, target, "provocação pública")
