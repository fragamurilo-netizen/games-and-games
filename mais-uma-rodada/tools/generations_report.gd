extends SceneTree
## Gerações dos países (Generations): avança só a base por N anos (sem jogar partidas) e mostra as
## gerações sorteadas, descobertas, quantas joias cada uma deu e como anda a base dos países.
## godot --headless --path . --script res://tools/generations_report.gd -- [--years=25]

var opt_years := 25


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--years="):
			opt_years = int(a.substr(8))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	for _y in opt_years:
		w.year += 1
		Generations.season_close(w)
		PlayerDevelopment.youth_intake(w)
	var st := Generations.state(w)
	print("Anos: %d  ·  gerações sorteadas: %d" % [opt_years, (st["waves"] as Array).size()])
	for wv: Dictionary in st["waves"]:
		var ps := Generations.members(w, wv)
		var gems := 0
		var kids := 0
		for p: Player in ps:
			kids += 1
			if p.potential >= 82:
				gems += 1
		# Comparação: mesma faixa de idade do país, fora da geração
		var ctrl := Generations.cohort(w, String(wv["n"]), int(wv["y0"]) - SPAN_OF(wv), int(wv["y0"]) - 1)
		var cg := 0
		for p: Player in ctrl:
			if p.potential >= 82:
				cg += 1
		var best: Array = []
		for p: Player in ps.slice(0, 4):
			best.append("%s %d" % [p.display_name(), p.potential])
		print("  %s %s (nasc. %d–%d, k=%.2f, sorteio %d, descoberta %s): %d garotos, %d com potencial 82+ (antes: %d) · %s" % [
			String(wv["n"]), Generations.name_of(wv), int(wv["y0"]), int(wv["y1"]), float(wv["k"]), int(wv["y"]),
			str(wv["d"]) if int(wv["d"]) > 0 else "—", kids, gems, cg, ", ".join(PackedStringArray(best))])
	var nb: Dictionary = st["nb"]
	var keys := nb.keys()
	keys.sort_custom(func(a, b): return float(nb[a]) > float(nb[b]))
	var line: Array = []
	for k in keys.slice(0, 8):
		line.append("%s %+.2f" % [k, float(nb[k])])
	print("Base em alta: ", ", ".join(PackedStringArray(line)))
	line.clear()
	for k in keys.slice(keys.size() - 5):
		line.append("%s %+.2f" % [k, float(nb[k])])
	print("Base em baixa: ", ", ".join(PackedStringArray(line)))
	var cat := Generations.category(w, "BRA", w.year - 18)
	print("Categoria %d do Brasil: %d entraram, %d ainda no futebol, %d profissionais" % [w.year - 18, int(cat["entered"]), int(cat["active"]), int(cat["pros"])])
	var news := 0
	for n: NewsEvent in w.news:
		if n.title.contains("geração") or n.title.contains("Geração"):
			news += 1
			if news <= 4:
				print("  notícia: ", n.title, " — ", n.body.left(140))
	quit()


func SPAN_OF(wv: Dictionary) -> int:
	return int(wv["y1"]) - int(wv["y0"]) + 1
