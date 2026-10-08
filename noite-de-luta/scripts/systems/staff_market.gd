class_name StaffMarket
extends RefCounted
## Staff da academia: quem melhora os lutadores. Mais velho e mais rodado custa mais e rende
## mais (como no LEATHER). Os candidatos do mercado mudam todo mês.

const ROLES := {
	"striking": {"name": "Técnico de striking", "help": "Treino de mãos, chutes, potência, clinch, movimentação e defesa."},
	"wrestling": {"name": "Técnico de wrestling", "help": "Quedas, defesa de queda e jogo por cima."},
	"jiujitsu": {"name": "Professor de jiu-jitsu", "help": "Jogo por baixo, finalização e defesa de finalização."},
	"fisico": {"name": "Preparador físico", "help": "Força, velocidade e cardio. Condição física volta mais rápido."},
	"fisio": {"name": "Fisioterapeuta", "help": "Lesões saram mais rápido e acontecem menos no treino."},
	"nutri": {"name": "Nutricionista", "help": "Corte de peso mais seguro: menos chance de errar o peso e menos fôlego perdido."},
	"olheiro": {"name": "Olheiro", "help": "Mostra o potencial dos lutadores fora da sua equipe."},
}
const ORDER := ["striking", "wrestling", "jiujitsu", "fisico", "fisio", "nutri", "olheiro"]


static func role_name(role: String) -> String:
	return String((ROLES.get(role, {}) as Dictionary).get("name", role))


static func wage_for(quality: float) -> float:
	return snappedf(250.0 + quality * quality * 0.32, 50.0)


static func make(w: GameWorld, role: String, quality: float) -> Dictionary:
	var nat := FighterGenerator.pick_nation(w.rng, false)
	var origin := NameGenerator.pick_origin(w.rng, nat)
	var fem := w.rng.randf() < 0.18
	var nm := NameGenerator.generate(w.rng, String(origin["c"]), {}, fem)
	var full := (String(nm["last"]) + " " + String(nm["first"])) if bool(nm.get("family_first", false)) else (String(nm["first"]) + " " + String(nm["last"]))
	var q := clampf(quality, 15.0, 95.0)
	var age := clampi(int(round(28.0 + q * 0.32 + w.rng.randfn(0.0, 6.0))), 26, 70)
	return {"id": w.new_id(), "name": full, "role": role, "quality": roundf(q), "age": age, "wage": wage_for(q), "nation": nat,
		"eth": int(origin["eth"]), "face": w.rng.randi(), "fem": fem}


static func refresh(w: GameWorld) -> void:
	w.staff_market = []
	for role: String in ORDER:
		for _i in 3:
			w.staff_market.append(make(w, role, w.rng.randf_range(28.0, 90.0)))


static func hire(w: GameWorld, cand: Dictionary) -> String:
	var t := w.user_team()
	if t == null:
		return "Sem equipe."
	if not t.staff_of(String(cand["role"])).is_empty():
		return "Você já tem um %s. Dispense o atual antes." % role_name(String(cand["role"])).to_lower()
	if t.balance < float(cand["wage"]) * 4.0:
		return "Caixa curto: contratar pede pelo menos quatro semanas de salário em caixa."
	var c := cand.duplicate()
	c["since"] = w.week
	t.staff.append(c)
	w.staff_market.erase(cand)
	w.add_news("equipe", "%s contrata %s como %s." % [t.name, String(c["name"]), role_name(String(c["role"])).to_lower()])
	return ""


static func fire(w: GameWorld, staff_id: int) -> void:
	var t := w.user_team()
	for s: Dictionary in t.staff:
		if int(s["id"]) == staff_id:
			# Multa: duas semanas de salário.
			t.add_money(w.week, "Rescisão de %s" % String(s["name"]), -float(s["wage"]) * 2.0)
			t.staff.erase(s)
			return
