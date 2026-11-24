class_name Card
extends RefCounted
## A ordem do card de uma noite. `FightEvent.bouts` vai da luta de abertura até a principal (a
## última da lista). De trás para a frente: luta principal, co-principal, o resto do card
## principal e, antes disso, as preliminares.
##
## O lugar no card importa:
## - a principal e a co-principal são as que mais vendem a noite (`Hype.event`);
## - quem luta no alto do card ganha mais fama, quem luta nas preliminares ganha menos (`fame_k`);
## - nome grande nas preliminares fica contrariado (`Morale`, na hora da luta).
## A ordem sai sozinha pelo peso de cada luta (`weight`) até alguém mexer à mão (`move`,
## `set_main`): daí em diante o card é do presidente (`FightEvent.manual`).

## Lutas no card principal (contando principal e co-principal), por camada.
const MAIN_CARD := [3, 4, 5]
const SLOT_NAMES := {"principal": "Luta principal", "co": "Co-principal", "card": "Card principal", "prelim": "Preliminares"}
const SLOT_ORDER := ["principal", "co", "card", "prelim"]


static func bouts(w: GameWorld, ev: FightEvent) -> Array:
	var out: Array = []
	for bid: int in ev.bouts:
		var b := w.bout(bid)
		if b != null and b.status != "cancelada":
			out.append(b)
	return out


static func has_main(w: GameWorld, ev: FightEvent) -> bool:
	for b: Bout in bouts(w, ev):
		if b.main_event:
			return true
	return false


## Tem disputa de cinturão (ou de interino) marcada? Essa não sai do topo do card.
static func has_belt(w: GameWorld, ev: FightEvent) -> bool:
	for b: Bout in bouts(w, ev):
		if b.status == "marcada" and (b.title or b.interim):
			return true
	return false


static func main_card_size(ev: FightEvent) -> int:
	return int(MAIN_CARD[clampi(ev.tier, 0, 2)])


## Quanto a luta pesa para subir no card: fama dos dois, ranking, cinturão, rivalidade e o
## lugar combinado na negociação.
static func weight(w: GameWorld, b: Bout) -> float:
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	if fa == null or fb == null:
		return 0.0
	var s := (fa.popularity + fb.popularity) * 0.5
	for f: Fighter in [fa, fb]:
		var r := w.rank_of(f)
		if r == 0:
			s += 12.0
		elif r > 0 and r <= 15:
			s += (16.0 - r) * 0.5
	s += Rivalry.heat(w, fa, fb) * 0.15
	if b.interim:
		s += 150.0
	if b.title:
		s += 200.0
	if b.main_event:
		s += 400.0
	s += b.billing * 90.0
	return s


## Arruma o card depois de uma luta entrar ou sair: nas noites do presidente só reordena (a
## principal é escolha dele); nas outras a mais pesada vira a principal.
static func refresh(w: GameWorld, ev: FightEvent) -> void:
	if ev == null:
		return
	if w.is_president() and ev.tier == 2:
		sort(w, ev)
	else:
		auto_main(w, ev)


## Reordena pelo peso (a não ser que o card tenha sido mexido à mão).
static func sort(w: GameWorld, ev: FightEvent, force: bool = false) -> void:
	if ev == null or (ev.manual and not force):
		return
	var lst := bouts(w, ev)
	lst.sort_custom(func(x: Bout, y: Bout) -> bool: return weight(w, x) < weight(w, y))
	ev.bouts = lst.map(func(b: Bout) -> int: return b.id)


## Lugar da luta no card: "principal", "co", "card" ou "prelim".
static func slot(w: GameWorld, ev: FightEvent, b: Bout) -> String:
	if ev == null:
		return "card"
	var lst := bouts(w, ev)
	var i := lst.find(b)
	if i < 0:
		return "card"
	var from_top := lst.size() - 1 - i
	if from_top == 0:
		return "principal"
	if from_top == 1:
		return "co"
	return "card" if from_top < main_card_size(ev) else "prelim"


static func slot_of(w: GameWorld, b: Bout) -> String:
	return slot(w, w.event(b.event_id), b)


static func slot_name(s: String) -> String:
	return String(SLOT_NAMES.get(s, "Card principal"))


## Quanto da fama de uma vitória o lugar no card entrega.
static func fame_k(s: String) -> float:
	return {"principal": 1.3, "co": 1.15, "card": 1.0, "prelim": 0.8}.get(s, 1.0)


## Lugar que uma luta entre os dois teria numa noite, antes de existir (para a proposta).
static func slot_guess(w: GameWorld, ev: FightEvent, fa: Fighter, fb: Fighter, title: bool, billing: int = 0) -> String:
	var mine := (fa.popularity + fb.popularity) * 0.5 + (200.0 if title else 0.0) + billing * 90.0
	for f: Fighter in [fa, fb]:
		var r := w.rank_of(f)
		if r == 0:
			mine += 12.0
		elif r > 0 and r <= 15:
			mine += (16.0 - r) * 0.5
	# O card costuma encher: conta as lutas que já existem e as vagas que faltam como lutas médias.
	var above := 0
	for b: Bout in bouts(w, ev):
		if weight(w, b) > mine:
			above += 1
	if title or billing >= 3:
		return "principal"
	if above == 0:
		return "principal" if bouts(w, ev).size() >= ev.slots - 2 else "co"
	if above == 1:
		return "co"
	return "card" if above < main_card_size(ev) else "prelim"


# --- Na mão do presidente -------------------------------------------------------------------

## Sobe (`dir` = 1) ou desce (-1) a luta uma posição. A principal de cinturão não sai do topo.
static func move(w: GameWorld, ev: FightEvent, b: Bout, dir: int) -> String:
	var lst := bouts(w, ev)
	var i := lst.find(b)
	var j := i + dir
	if i < 0 or j < 0 or j >= lst.size():
		return "Não dá para mover mais."
	var top := lst.size() - 1
	var other: Bout = lst[j]
	if (i == top and (b.title or b.interim)) or (j == top and (other.title or other.interim)):
		return "Disputa de cinturão é sempre a luta principal."
	lst[i] = other
	lst[j] = b
	ev.bouts = lst.map(func(x: Bout) -> int: return x.id)
	ev.manual = true
	_fix_main(w, ev)
	return ""


## Põe a luta no topo do card.
static func set_main(w: GameWorld, ev: FightEvent, b: Bout) -> String:
	var lst := bouts(w, ev)
	if lst.is_empty() or not lst.has(b):
		return "A luta não está neste card."
	var top: Bout = lst.back()
	if top != b and (top.title or top.interim):
		return "Disputa de cinturão é sempre a luta principal."
	lst.erase(b)
	lst.append(b)
	ev.bouts = lst.map(func(x: Bout) -> int: return x.id)
	ev.manual = true
	_fix_main(w, ev)
	return ""


## A última da lista é a principal (cinco rounds); as outras voltam a três, menos as de cinturão.
static func _fix_main(w: GameWorld, ev: FightEvent) -> void:
	var lst := bouts(w, ev)
	for i in lst.size():
		var b: Bout = lst[i]
		var top := i == lst.size() - 1
		if b.status != "marcada":
			continue
		b.main_event = top or b.title or b.interim
		if b.title or b.interim:
			b.rounds = 5
		else:
			b.rounds = 5 if (top and ev.tier == 2) else 3


## Garante uma luta principal: sem nenhuma, a mais pesada vira a principal.
static func ensure_main(w: GameWorld, ev: FightEvent) -> void:
	var lst := bouts(w, ev)
	if lst.is_empty():
		return
	if ev.manual:
		_fix_main(w, ev)
		return
	if not has_main(w, ev):
		var best: Bout = lst[0]
		for b: Bout in lst:
			if weight(w, b) > weight(w, best):
				best = b
		best.main_event = true
		if ev.tier == 2:
			best.rounds = 5
	sort(w, ev)


## Mundo que anda sozinho: a luta mais pesada do card é a principal (cinco rounds na Liga
## Global). Disputa de cinturão é sempre principal. As lutas da equipe do jogador não mudam de
## número de rounds depois de assinadas.
static func auto_main(w: GameWorld, ev: FightEvent) -> void:
	if ev.manual:
		_fix_main(w, ev)
		return
	var lst := bouts(w, ev).filter(func(b: Bout) -> bool: return b.status == "marcada")
	if lst.is_empty():
		return
	var belt := false
	for b: Bout in lst:
		if b.title or b.interim:
			belt = true
			continue
		b.main_event = false
		if not _signed_by_user(w, b):
			b.rounds = 3
	if not belt:
		var best: Bout = lst[0]
		for b: Bout in lst:
			if weight(w, b) > weight(w, best):
				best = b
		best.main_event = true
		if ev.tier == 2 and not _signed_by_user(w, best):
			best.rounds = 5
	sort(w, ev)


static func _signed_by_user(w: GameWorld, b: Bout) -> bool:
	return not w.is_president() and (w.is_user_fighter(w.fighter(b.a)) or w.is_user_fighter(w.fighter(b.b)))
