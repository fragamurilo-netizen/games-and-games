class_name Signing
extends RefCounted
## Contratar e dispensar. O lutador olha a reputação da academia contra o tamanho dele, a
## fatia da bolsa que a equipe quer, quantas lutas o contrato prende e as luvas (bônus de
## assinatura). Recusou, só volta a ouvir propostas daqui a quatro semanas.

const CUTS := [0.1, 0.15, 0.2, 0.25, 0.3]
const FIGHTS := [3, 5, 8]
const BONUS := [0.0, 5000.0, 15000.0, 40000.0, 100000.0]


static func status(f: Fighter) -> float:
	return f.level() * 0.75 + f.popularity * 0.25


static func chance(w: GameWorld, f: Fighter, cut: float, fights: int, bonus: float) -> float:
	var t := w.user_team()
	var st := status(f)
	var p := 0.55 + (t.reputation - (st - 28.0)) / 40.0
	p -= (cut - 0.18) * 2.4
	p += bonus / (3000.0 + st * st * 6.0) * 0.4
	p -= (fights - 4) * 0.03
	if f.history.is_empty() and not f.is_pro():
		p += 0.1 # amador quer uma chance
	return clampf(p, 0.02, 0.97)


static func chance_label(p: float) -> String:
	if p >= 0.75:
		return "Alta"
	if p >= 0.5:
		return "Boa"
	if p >= 0.3:
		return "Incerta"
	if p >= 0.12:
		return "Baixa"
	return "Quase nenhuma"


static func block_reason(w: GameWorld, f: Fighter) -> String:
	if f.retired:
		return "Aposentado."
	if f.team_id >= 0:
		return "Tem contrato com %s." % w.team(f.team_id).name
	if int(w.sign_block.get(f.id, -1)) > w.week:
		return "Recusou há pouco. Volta a ouvir propostas em %d semanas." % (int(w.sign_block[f.id]) - w.week)
	return ""


## {ok, text}
static func offer(w: GameWorld, f: Fighter, cut: float, fights: int, bonus: float) -> Dictionary:
	var why := block_reason(w, f)
	if why != "":
		return {"ok": false, "text": why}
	var t := w.user_team()
	if bonus > t.balance:
		return {"ok": false, "text": "Não há caixa para pagar essas luvas."}
	if w.rng.randf() >= chance(w, f, cut, fights, bonus):
		w.sign_block[f.id] = w.week + 4
		return {"ok": false, "text": "%s recusou a proposta." % f.display_name()}
	f.team_id = t.id
	f.contract = {"cut": cut, "fights": fights}
	f.training = {"focus": "equilibrado", "intensity": 1}
	if bonus > 0.0:
		t.add_money(w.week, "Luvas de %s" % f.display_name(), -bonus)
	w.add_news("equipe", "%s assina com %s: %d lutas, %d%% das bolsas para a equipe." % [f.display_name(), t.name, fights, int(round(cut * 100.0))], [f.id], true)
	return {"ok": true, "text": "%s agora é da %s!" % [f.display_name(), t.name]}


static func renew(w: GameWorld, f: Fighter, cut: float, fights: int) -> Dictionary:
	var t := w.user_team()
	var p := chance(w, f, cut, fights, 0.0) + 0.2 + clampf(f.streak, -2, 4) * 0.02
	if w.rng.randf() >= clampf(p, 0.05, 0.97):
		release(w, f, false)
		return {"ok": false, "text": "%s não renovou e saiu da equipe." % f.display_name()}
	f.contract = {"cut": cut, "fights": fights}
	return {"ok": true, "text": "%s renovou com a %s." % [f.display_name(), t.name]}


static func release(w: GameWorld, f: Fighter, by_user: bool = true) -> void:
	var b := w.bout(f.bout_id)
	if b != null and b.status == "marcada":
		Career.cancel_bout(w, b, "%s saiu da equipe" % f.display_name())
	f.team_id = -1
	f.contract = {}
	w.offers = w.offers.filter(func(o: Dictionary) -> bool: return int(o["fighter"]) != f.id)
	if by_user:
		w.add_news("equipe", "%s foi dispensado da equipe." % f.display_name(), [f.id])
	w.sign_block[f.id] = w.week + 8


## Mensal: as academias rivais contratam os melhores sem equipe.
static func cpu_signings(w: GameWorld) -> void:
	var free: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return not f.retired and f.team_id < 0)
	free.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	var teams: Array = w.teams.values().filter(func(t: Team) -> bool: return not t.is_user)
	for i in mini(6, free.size()):
		var f: Fighter = free[i]
		if w.rng.randf() < 0.55:
			var t: Team = teams[w.rng.randi_range(0, teams.size() - 1)]
			f.team_id = t.id
			f.contract = {"cut": 0.2, "fights": 4}
