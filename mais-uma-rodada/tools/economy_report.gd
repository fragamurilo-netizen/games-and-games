extends SceneTree
## Economia do jogo × números reais (calibração). Para clubes de referência: receita do ano,
## folha, dívida, caixa, verba, valor do elenco e o jogador mais caro, ao lado da receita e da
## dívida reais (Deloitte Money League 2026; balanços 2025 dos clubes brasileiros, euro a R$ 5,60).
## godot --headless --path . --script res://tools/economy_report.gd -- [--seasons=N]

## nome curto no jogo → [receita real €M, dívida real €M (-1 = sem referência)]
const REAL := {
	"Real Madrid": [1161, -1], "Barcelona": [975, -1], "Bayern": [861, -1], "PSG": [837, -1], "Liverpool": [836, -1],
	"Man City": [829, -1], "Arsenal": [822, -1], "Man United": [793, -1], "Tottenham": [673, -1], "Chelsea": [584, -1],
	"Inter": [538, -1], "Dortmund": [531, -1], "Atlético": [455, -1], "Aston Villa": [450, -1], "Milan": [410, -1],
	"Juventus": [402, -1], "Newcastle": [398, -1], "Stuttgart": [296, -1], "Benfica": [283, -1], "West Ham": [276, -1],
	"Flamengo": [373, 84], "Palmeiras": [303, 205], "Botafogo": [248, 281], "São Paulo": [194, 153], "Fluminense": [183, 147],
	"Corinthians": [173, 437], "Grêmio": [132, 139], "Santos": [121, 159], "Cruzeiro": [121, 206], "Atlético-MG": [120, 409],
	"Internacional": [117, 166], "Bragantino": [114, 76], "Vasco": [102, 150], "Bahia": [100, 30], "Athletico": [78, 15],
	"Fortaleza": [54, 40], "Ceará": [46, 31], "Vitória": [36, 63], "Sport": [33, 68], "Mirassol": [32, 0],
	"River Plate": [125, -1], "Boca Juniors": [110, -1], "Al-Hilal": [230, -1], "Inter Miami": [180, -1], "América": [110, -1],
	"Porto": [220, -1], "Sporting": [230, -1], "Ajax": [190, -1],
}

var opt_seasons := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seasons="):
			opt_seasons = int(a.substr(10))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	_report(w, "início")
	for s in opt_seasons:
		var guard := 0
		while not w.season.finished and guard < 400:
			SeasonManager.play_matchday_instant(w)
			guard += 1
		SeasonManager.end_season(w)
		_report(w, "começo da temporada %d" % (s + 2))
	quit()


func _report(w: GameWorld, title: String) -> void:
	print("\n=== %s (valores em € milhões) ===" % title)
	print("%-14s %-5s %3s | receita jogo/real | dívida jogo/real | folha/ano  folha%% | caixa  verba | elenco  top valor/salário-ano" % ["clube", "liga", "rep"])
	var by_name := {}
	for c: Club in w.clubs:
		by_name[c.short_name] = c
	var err_rev := 0.0
	var n_rev := 0
	for nm in REAL:
		var c: Club = by_name.get(nm)
		if c == null:
			print("%-14s (não encontrado)" % nm)
			continue
		var real: Array = REAL[nm]
		var rev := float(FinanceManager.expected_revenue(c) + c.income_tv - FinanceManager.tv_income(c))
		var bill := float(FinanceManager.wage_bill(w, c)) * 12.0
		var sv := 0.0
		var top: Player = null
		for p: Player in w.squad(c):
			sv += p.value
			if top == null or p.value > top.value:
				top = p
		print("%-14s %-5s %3d | %6.0f / %4d | %5.0f / %4s | %7.0f  %3.0f%% | %5.0f %5.0f | %6.0f  %5.1f / %4.1f" % [nm, c.league_id, int(c.reputation),
			rev / 1e6, int(real[0]), c.debt / 1e6, str(real[1]) if int(real[1]) >= 0 else "-", bill / 1e6, 100.0 * bill / maxf(1.0, rev),
			c.balance / 1e6, c.transfer_budget / 1e6, sv / 1e6, (top.value / 1e6) if top != null else 0.0, (top.wage * 12.0 / 1e6) if top != null else 0.0])
		if rev > 0.0:
			err_rev += absf(log(rev / 1e6 / float(real[0])))
			n_rev += 1
	print("erro médio da receita (log): %.2f (0,10 ≈ 10%% de diferença)" % (err_rev / maxf(1.0, n_rev)))
	# Maiores valores e salários do mundo
	var all: Array = w.players.values().filter(func(p: Player): return p.club_id >= 0)
	all.sort_custom(func(a: Player, b: Player): return a.value > b.value)
	var parts: Array = []
	for p: Player in all.slice(0, 10):
		parts.append("%.0f" % (p.value / 1e6))
	print("10 maiores valores de mercado (€M): %s" % ", ".join(parts))
	all.sort_custom(func(a: Player, b: Player): return a.wage > b.wage)
	parts.clear()
	for p: Player in all.slice(0, 10):
		parts.append("%.1f" % (p.wage * 12.0 / 1e6))
	print("10 maiores salários (€M/ano): %s" % ", ".join(parts))
