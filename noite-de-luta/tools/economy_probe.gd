extends "res://tools/season_probe.gd"
## Sonda da economia: joga N anos sozinha e mostra, ano a ano, de onde o dinheiro veio e para
## onde foi (por categoria), o caixa, a reputação e o tempo gasto por semana. Serve para
## equilibrar a academia e a liga em carreiras longas.
## godot --headless --path . --script res://tools/economy_probe.gd -- --years=12 [--role=presidente] [--seed=2027] [--lazy] [--funds=0|1|2] [--csv=ARQ]

## Categoria de cada lançamento, pelo começo ou pelo miolo do rótulo (a primeira que casar).
const CATS := [
	["Caixa inicial", ""],
	["Mensalidades", "alunos"],
	["Juros da dívida", "juros"],
	["Investidor local", "socorro"],
	["Dividendos dos sócios", "dividendos"],
	["Aluguel", "aluguel"],
	["Salários do staff", "staff"],
	["Rescisão", "staff"],
	["Patrocínio do comércio", "patrocinio"],
	["Camp de", "camps"],
	["Luvas de", "luvas"],
	["Olheiro", "olheiro"],
	["Meta cumprida", "metas"],
	["Prêmio da prefeitura", "metas"],
	["Bônus dos sócios", "metas"],
	["Kit de boas-vindas", "metas"],
	["Intervenção dos sócios", "socios"],
	["Aporte dos novos", "socios"],
	["Saída dos antigos", "socios"],
	["Folha e estrutura", "folha"],
	["Multa da comissão", "multas"],
	[": bilheteria", "bilheteria"],
	[": pay-per-view", "ppv"],
	[": direitos de TV", "tv"],
	[": patrocínio", "patrocinio"],
	[": bolsa", "bolsas"],
	[": produção", "producao"],
	[": bônus", "bonus"],
	[" cancelada", "canceladas"],
	[" × ", "bolsas"],
]


func _initialize() -> void:
	var years := 12
	var role := "empresario"
	var seed_v := 2027
	var lazy := false
	var funds := 1
	var csv := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--years="):
			years = int(a.substr(8))
		elif a.begins_with("--role="):
			role = a.substr(7)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--funds="):
			funds = clampi(int(a.substr(8)), 0, 2)
		elif a.begins_with("--csv="):
			csv = a.substr(6)
		elif a == "--lazy":
			lazy = true
	var pres := role == "presidente"
	var w: GameWorld
	if pres:
		w = Org.new_career("Liga Teste", "LT", "USA", Color("#B3262E"), Color("#F1F0EC"), Org.START_FUNDS[funds], seed_v)
	else:
		w = Career.new_career("Equipe Teste", "TST", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), Career.START_FUNDS[funds], seed_v)
	print("papel %s, semente %d, %s, caixa inicial %s" % [role, seed_v, "jogador parado" if lazy else "jogador ativo", Fmt.money(w.user_team().balance)])
	var t := w.user_team()
	var flow := {}
	var count := {}
	var rows: Array = []
	var ms_sum := 0.0
	var ms_max := 0.0
	var low := t.balance
	var fights := 0
	var wins := 0
	var nights := 0
	for i in years * 52 + 2:
		t.ledger = []
		if pres:
			if not lazy:
				_president_turn(w)
		else:
			_manager_turn(w, lazy)
		var y0 := w.year()
		var c0: Dictionary = (w.goals.get("c", {}) as Dictionary).duplicate()
		var t0 := Time.get_ticks_usec()
		Career.advance_week(w, true)
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0
		ms_sum += ms
		ms_max = maxf(ms_max, ms)
		for l: Dictionary in t.ledger:
			var cat := _cat(String(l["label"]))
			if cat == "":
				continue
			flow[cat] = float(flow.get(cat, 0.0)) + float(l["value"])
			count[cat] = int(count.get(cat, 0)) + 1
		low = minf(low, t.balance)
		if w.year() == y0:
			continue
		var p: Dictionary = (w.goals["past"] as Array).back()
		var c: Dictionary = p["c"]
		var inc := 0.0
		var out := 0.0
		for k: String in flow:
			if float(flow[k]) >= 0.0:
				inc += float(flow[k])
			else:
				out += float(flow[k])
		print("\n== %d · caixa %s (mínimo %s) · entrou %s, saiu %s, saldo %s · rep %.1f · %s %.0f · metas %d de 3" % [int(p["year"]), Fmt.money(t.balance), Fmt.money(low),
			Fmt.money(inc), Fmt.money(-out), Fmt.money(inc + out), t.reputation, Season.meter_short(w), float(p["v1"]), int(p["met"])])
		var keys := flow.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return float(flow[a]) > float(flow[b]))
		for k: String in keys:
			print("   %-12s %14s  (%d lançamentos, média %s)" % [k, Fmt.money(float(flow[k])), int(count[k]), Fmt.money(float(flow[k]) / float(maxi(1, int(count[k]))))])
		if pres:
			print("   noites %s, lutas de cinturão %s, público %s, pay-per-view %s · elite: fama 75+ %d, 90+ %d · prestígio %.1f" % [str(c.get("events", c.get("nights", "?"))), str(c.get("title_bouts", "?")),
				str(c.get("crowd", "?")), str(c.get("ppv", "?")), Season.stars(w, 75.0), Season.stars(w, 90.0), t.reputation])
		else:
			var mine := w.user_fighters()
			print("   equipe (%d): %s" % [mine.size(), ", ".join(mine.map(func(f: Fighter) -> String: return "%s %s %s nv%d" % [f.short_name(), f.record_text(), w.rank_text(f), int(f.level())]))])
			print("   staff %d (folha %s por semana) · patrocínio %s por semana" % [t.staff.size(), Fmt.money(t.weekly_wages()), Fmt.money(Season.sponsor(w))])
		print("   ano: ", c)
		print("   tempo por semana: média %.0f ms, pior %.0f ms" % [ms_sum / 52.0, ms_max])
		var row := {"year": int(p["year"]), "cash": t.balance, "low": low, "in": inc, "out": -out, "rep": t.reputation, "v": float(p["v1"]), "met": int(p["met"])}
		for k: String in flow:
			row[k] = float(flow[k])
		rows.append(row)
		flow = {}
		count = {}
		ms_sum = 0.0
		ms_max = 0.0
		low = t.balance
	var js := JSON.stringify(w.to_dict())
	print("\nsave %d KB depois de %d anos · conquistas %d, %d pontos" % [js.length() / 1024, years, Achievements.count(w), Achievements.points(w)])
	if csv != "":
		var f := FileAccess.open(csv, FileAccess.WRITE)
		f.store_string(JSON.stringify(rows, "  "))
		f.close()
	quit()


func _cat(label: String) -> String:
	for c: Array in CATS:
		if label.contains(String(c[0])):
			return String(c[1])
	return "outros (%s)" % label
