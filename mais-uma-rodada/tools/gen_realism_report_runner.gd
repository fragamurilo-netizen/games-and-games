extends Node
## Lógica de tools/gen_realism_report.gd (carregada depois dos autoloads).

const PAIRS := [[Attr.VEL, Attr.ACE], [Attr.MAR, Attr.DES], [Attr.PAS, Attr.VIS], [Attr.FIN, Attr.FRI],
	[Attr.TEC, Attr.DRI], [Attr.INT, Attr.DEC], [Attr.GOL, Attr.REF], [Attr.FOR, Attr.CAB], [Attr.FIN, Attr.CHL]]
## Atributos "da posição": o ponto forte de um jogador deveria quase sempre estar aqui.
const OWN := {Pos.GK: [Attr.GOL, Attr.REF, Attr.POS], Pos.CB: [Attr.MAR, Attr.DES, Attr.CAB, Attr.FOR, Attr.POS],
	Pos.RB: [Attr.VEL, Attr.ACE, Attr.CRU, Attr.MAR, Attr.DES, Attr.RES], Pos.LB: [Attr.VEL, Attr.ACE, Attr.CRU, Attr.MAR, Attr.DES, Attr.RES],
	Pos.DM: [Attr.MAR, Attr.DES, Attr.POS, Attr.PAS, Attr.FOR, Attr.RES], Pos.CM: [Attr.PAS, Attr.VIS, Attr.TEC, Attr.RES, Attr.CHL, Attr.DEC],
	Pos.AM: [Attr.PAS, Attr.VIS, Attr.TEC, Attr.DRI, Attr.FIN, Attr.CHL], Pos.RM: [Attr.CRU, Attr.VEL, Attr.ACE, Attr.RES, Attr.TEC, Attr.DRI, Attr.PAS],
	Pos.LM: [Attr.CRU, Attr.VEL, Attr.ACE, Attr.RES, Attr.TEC, Attr.DRI, Attr.PAS], Pos.RW: [Attr.VEL, Attr.ACE, Attr.DRI, Attr.TEC, Attr.FIN, Attr.CRU],
	Pos.LW: [Attr.VEL, Attr.ACE, Attr.DRI, Attr.TEC, Attr.FIN, Attr.CRU], Pos.ST: [Attr.FIN, Attr.FRI, Attr.CAB, Attr.POS, Attr.VEL, Attr.ACE, Attr.FOR]}


func _ready() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var ps: Array = []
	for c: Club in w.clubs:
		for pid in c.player_ids:
			var p := w.player(pid)
			if p != null:
				ps.append(p)
	print("jogadores em clubes: %d" % ps.size())
	print("\n== Coerência entre atributos parecidos (correlação · |diferença| média · % com diferença > 15)")
	for pr in PAIRS:
		var xs: Array = []
		var ys: Array = []
		var diff := 0.0
		var big := 0
		for p: Player in ps:
			if (pr[0] == Attr.GOL) != (p.position == Pos.GK):
				continue
			# tira o nível do jogador: compara o desvio de cada atributo em relação ao overall
			xs.append(float(p.attrs[pr[0]]) - p.overall)
			ys.append(float(p.attrs[pr[1]]) - p.overall)
			var d := absf(float(p.attrs[pr[0]]) - float(p.attrs[pr[1]]))
			diff += d
			if d > 15.0:
				big += 1
		print("  %s x %s: r=%.2f · dif %.1f · %.1f%%" % [Attr.SHORT[pr[0]], Attr.SHORT[pr[1]], _corr(xs, ys), diff / xs.size(), 100.0 * big / xs.size()])
	print("\n== Ponto forte da posição (o maior atributo é da posição / sem contar DIS)")
	for pos in Pos.COUNT:
		var n := 0
		var own := 0
		var tops := {}
		for p: Player in ps:
			if p.position != pos:
				continue
			n += 1
			var order: Array = range(Attr.COUNT)
			order.sort_custom(func(a, b): return p.attrs[a] > p.attrs[b])
			order.erase(Attr.DIS)
			if (OWN[pos] as Array).has(order[0]):
				own += 1
			tops[Attr.SHORT[order[0]]] = int(tops.get(Attr.SHORT[order[0]], 0)) + 1
		var tl: Array = tops.keys()
		tl.sort_custom(func(a, b): return tops[a] > tops[b])
		var s := ""
		for k in tl.slice(0, 5):
			s += "%s %d%% " % [k, int(round(100.0 * tops[k] / n))]
		print("  %s n=%d · da posição %d%% · top: %s" % [Pos.CODES[pos], n, int(round(100.0 * own / n)), s])
	print("\n== Por divisão: idade média do elenco · % estrangeiros · tamanho do elenco · ovr médio XI")
	var by := {}
	for c: Club in w.clubs:
		var k := "tier %d" % c.tier
		if not by.has(k):
			by[k] = [0, 0.0, 0, 0, 0.0]
		var b: Array = by[k]
		b[0] += 1
		for pid in c.player_ids:
			var p := w.player(pid)
			b[1] += p.age(w.year)
			b[2] += 1
			if p.nationality != c.nation:
				b[3] += 1
		b[4] += PlayerGenerator.xi_average(w, c)
	var keys := by.keys()
	keys.sort()
	for k in keys:
		var b: Array = by[k]
		print("  %s: %d clubes · idade %.1f · estrangeiros %.0f%% · elenco %.1f · XI %.1f" % [k, b[0], b[1] / b[2], 100.0 * b[3] / b[2], float(b[2]) / b[0], b[4] / b[0]])
	print("\n== Idades (todos): ")
	var ages := {}
	for p: Player in ps:
		var a := p.age(w.year)
		ages[a] = int(ages.get(a, 0)) + 1
	var line := ""
	for a in range(16, 40):
		line += "%d:%d " % [a, ages.get(a, 0)]
	print("  " + line)
	ps.sort_custom(func(a, b): return a.overall > b.overall)
	for topn in [50, 200, 1000]:
		var cnt := {}
		for p: Player in ps.slice(0, topn):
			cnt[Pos.CODES[p.position]] = int(cnt.get(Pos.CODES[p.position], 0)) + 1
		print("\n== Posições no top %d: %s" % [topn, str(cnt)])
		var nat := {}
		for p: Player in ps.slice(0, topn):
			nat[p.nationality] = int(nat.get(p.nationality, 0)) + 1
		var nk: Array = nat.keys()
		nk.sort_custom(func(a, b): return nat[a] > nat[b])
		var ns := ""
		for k in nk.slice(0, 14):
			ns += "%s %d " % [k, nat[k]]
		print("   países: " + ns)
	print("\n== Top 15 do mundo")
	for p: Player in ps.slice(0, 15):
		var c := w.club(p.club_id)
		print("  %d %s %s %d anos %s (%s)" % [p.overall, Pos.CODES[p.position], p.display_name(), p.age(w.year), p.nationality, c.short_name])
	get_tree().quit()


func _corr(xs: Array, ys: Array) -> float:
	var n := float(xs.size())
	var mx := 0.0
	var my := 0.0
	for i in xs.size():
		mx += xs[i]
		my += ys[i]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in xs.size():
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	return sxy / sqrt(maxf(sxx * syy, 0.0001))
