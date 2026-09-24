extends SceneTree
## Raio-x do mercado de transferências da IA (sem interface): quem compra de quem, quanto paga,
## quando as negociações acontecem e se o dinheiro está fluindo como no futebol real.
## Uso: godot --headless --path . --script res://tests/market_report.gd -- --seasons=3 --seed=123

const REGIONS := {
	"Big 5": ["ENG", "ESP", "GER", "ITA", "FRA"],
	"Europa média": ["POR", "NED", "TUR", "BEL", "SCO", "GRE", "AUT", "SUI", "UKR", "CRO", "SRB", "CZE", "DEN"],
	"Am. do Sul": ["BRA", "ARG", "URU", "COL", "CHI", "ECU", "PER", "PAR", "BOL", "VEN"],
	"Am. do Norte": ["MEX", "USA"],
	"Golfo/Ásia": ["KSA", "QAT", "UAE", "CHN", "JPN", "KOR", "AUS"],
	"África": ["EGY", "MAR", "TUN", "RSA", "NGA", "SEN"],
}
const ORDER := ["Big 5", "Europa média", "Am. do Sul", "Am. do Norte", "Golfo/Ásia", "África", "Livre"]


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var seasons := int(args.get("seasons", "3"))
	var seed_value := int(args.get("seed", str(WorldGenerator.DEFAULT_SEED)))
	var w := WorldGenerator.generate(seed_value, "padrao")
	var all: Array = []
	var loans := 0
	var t0 := Time.get_ticks_msec()
	for s in seasons:
		var loans_before := float(w.stats.get("loans", 0.0))
		while not w.season.finished:
			SeasonManager.play_matchday_instant(w)
		for t: Transfer in w.transfer_log:
			if t.year == w.year:
				all.append(t)
		SeasonManager.end_season(w)
		loans += int(float(w.stats.get("loans", 0.0)) - loans_before)
	# Transferências das férias ficam no ano novo: pega as que sobraram.
	for t: Transfer in w.transfer_log:
		if t.year == w.year:
			all.append(t)
	print("Mercado em %d temporada(s), seed %d — %.1f s" % [seasons, seed_value, (Time.get_ticks_msec() - t0) / 1000.0])
	_report(w, all, loans, seasons)
	quit(0)


func _region(w: GameWorld, club_id: int) -> String:
	if club_id < 0:
		return "Livre"
	var n := w.club(club_id).nation
	for r in REGIONS:
		if REGIONS[r].has(n):
			return r
	return "Livre"


func _report(w: GameWorld, all: Array, loans: int, seasons: int) -> void:
	var buys: Array = []
	var frees := 0
	var releases := 0
	var fees := 0.0
	var domestic := 0
	var by_day := {"férias e 1ª rodada": 0, "resto da janela de meio de ano": 0, "janela de inverno": 0}
	var flow := {}
	var ages := {}
	var vets_out := 0
	var young_sa_eu := 0
	for t: Transfer in all:
		if t.kind == Transfer.KIND_RELEASE:
			releases += 1
			continue
		if t.kind == Transfer.KIND_FREE:
			frees += 1
		else:
			buys.append(t)
			fees += t.fee
		var a := _region(w, t.from_id)
		var b := _region(w, t.to_id)
		var key := a + " → " + b
		if not flow.has(key):
			flow[key] = [0, 0.0]
		flow[key][0] += 1
		flow[key][1] += t.fee
		if not ages.has(b):
			ages[b] = [0, 0]
		ages[b][0] += 1
		ages[b][1] += t.age
		if t.from_id >= 0 and w.club(t.from_id).nation == w.club(t.to_id).nation:
			domestic += 1
		if t.kind == Transfer.KIND_BUY:
			if t.day <= 0:
				by_day["férias e 1ª rodada"] += 1
			elif t.day >= 20:
				by_day["janela de inverno"] += 1
			else:
				by_day["resto da janela de meio de ano"] += 1
		if t.age >= 30 and (a == "Big 5" or a == "Europa média") and (b == "Golfo/Ásia" or b == "Am. do Norte" or b == "Am. do Sul"):
			vets_out += 1
		if t.age <= 23 and a == "Am. do Sul" and (b == "Big 5" or b == "Europa média"):
			young_sa_eu += 1
	var moves := buys.size() + frees
	print("Por temporada: %d transferências (%d compras, %d sem custo), %d empréstimos, %d rescisões" % [moves / seasons, buys.size() / seasons, frees / seasons, loans / seasons, releases / seasons])
	print("Dinheiro movimentado por temporada: %s · mesmo país: %d%%" % [Fmt.money(int(fees / seasons)), int(100.0 * domestic / maxf(1.0, moves))])
	print("Quando (compras): %s" % str(by_day))
	print("Veteranos (30+) saindo da Europa para Golfo/Ásia/Américas: %d · jovens (≤23) sul-americanos indo para a Europa: %d" % [vets_out / seasons, young_sa_eu / seasons])
	print("")
	print("Maiores transferências:")
	buys.sort_custom(func(x, y): return x.fee > y.fee)
	for i in mini(15, buys.size()):
		var t: Transfer = buys[i]
		print("  %s  %s (%d, %d)  %s (%s) → %s (%s)" % [Fmt.money(t.fee), t.player_name, t.age, t.overall,
			w.club(t.from_id).short_name, w.club(t.from_id).nation, w.club(t.to_id).short_name, w.club(t.to_id).nation])
	print("")
	print("Fluxos entre regiões (por temporada: negócios · dinheiro):")
	var keys := flow.keys()
	keys.sort_custom(func(x, y): return flow[x][1] > flow[y][1] or (flow[x][1] == flow[y][1] and flow[x][0] > flow[y][0]))
	for k in keys:
		if flow[k][0] / seasons >= 3:
			print("  %-32s %5d · %s" % [k, flow[k][0] / seasons, Fmt.money(int(flow[k][1] / seasons))])
	print("")
	print("Idade média de quem chega:")
	for r in ORDER:
		if ages.has(r):
			print("  %-14s %.1f" % [r, float(ages[r][1]) / ages[r][0]])
	var red := 0
	var bal := 0.0
	for c: Club in w.clubs:
		bal += c.balance
		if c.balance < 0:
			red += 1
	print("")
	print("Caixa total dos clubes: %s · no vermelho: %d" % [Fmt.money(int(bal)), red])
