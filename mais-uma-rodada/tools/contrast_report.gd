extends SceneTree
## Relatório de contraste (WCAG) da paleta: modos claro e escuro, sem tingimento e com os dois
## níveis de tingimento, com o dourado e com cores de clube difíceis (branco, preto, amarelo,
## marinho, vermelho, verde). Lista só os pares abaixo do mínimo.
## Uso: godot --headless --path . --script res://tools/contrast_report.gd [-- --verbose]
## (--verbose lista também o destaque, o texto sobre ele e o fundo de cada caso)
##
## UIColors é carregada só depois do primeiro quadro (depende dos autoloads).

const CLUBS := [
	["dourado", null, null],
	["branco/preto", "#FFFFFF", "#111111"],
	["preto/branco", "#111111", "#FFFFFF"],
	["amarelo/verde", "#FFD100", "#006437"],
	["marinho/branco", "#0E2A5C", "#FFFFFF"],
	["vermelho/preto", "#C8102E", "#111111"],
	["verde/branco", "#006437", "#FFFFFF"],
	["branco/vermelho", "#FFFFFF", "#E30613"],
	["azul/preto", "#0D80BF", "#111111"],
]


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var uc: GDScript = load("res://scripts/ui/ui_colors.gd")
	var verbose := "--verbose" in OS.get_cmdline_user_args()
	var fails := 0
	var checks := 0
	for light in [false, true]:
		uc.call("set_light", light)
		for tint: float in [0.0, 0.35, 0.7]:
			for club: Array in CLUBS:
				if club[1] == null:
					if tint > 0.0:
						continue
					uc.call("apply_colors", null, null, 0.0)
				else:
					uc.call("apply_colors", Color(club[1]), Color(club[2]), tint)
				var g := func(k: String) -> Color: return uc.get(k)
				if verbose:
					print("%s tint %.2f %-16s destaque #%s texto #%s fundo #%s cartão #%s" % ["claro" if light else "escuro", tint, club[0],
						(g.call("ACCENT") as Color).to_html(false), (g.call("ON_ACCENT") as Color).to_html(false),
						(g.call("BG") as Color).to_html(false), (g.call("SURFACE") as Color).to_html(false)])
				var surfaces := ["BG", "SURFACE", "SURFACE_2"]
				# [texto, fundos, mínimo]
				var pairs := [
					["TEXT", surfaces + ["SURFACE_3"], 7.0],
					["MUTED", surfaces + ["SURFACE_3"], 4.5],
					["DIM", surfaces, 4.5],
					["DIM", ["SURFACE_3"], 3.0],
					["ACCENT", surfaces, 4.5],
					["ACCENT", ["SURFACE_3"], 3.0],
					["GREEN", surfaces, 4.5],
					["RED", surfaces, 4.5],
					["ORANGE", surfaces, 4.5],
					["BLUE", surfaces, 4.5],
					["GOLD", surfaces, 4.5],
					["ON_ACCENT", ["ACCENT"], 4.5],
					["ON_ACCENT", ["ACCENT_DARK"], 3.0],
				]
				for p: Array in pairs:
					for bg: String in p[1]:
						checks += 1
						var r: float = uc.call("contrast", g.call(p[0]), g.call(bg))
						if r < float(p[2]):
							fails += 1
							print("%s tint %.2f %-16s %-9s sobre %-11s %.2f (mín. %.1f)" % ["claro" if light else "escuro", tint, club[0], p[0], bg, r, p[2]])
				# Etiquetas/selos em cores de clube (UIKit.pill, RatingBadge com cor).
				if club[1] != null:
					for hexc: String in [club[1], club[2]]:
						checks += 1
						var col := Color(hexc)
						var under: Color = (g.call("SURFACE") as Color).lerp(col, 0.16)
						var fg: Color = uc.call("readable_on", col, [under], 4.5)
						var r2: float = uc.call("contrast", fg, under)
						if r2 < 4.5:
							fails += 1
							print("etiqueta %s sobre tingido: %.2f" % [hexc, r2])
					checks += 1
					var hov: Color = uc.call("hover_of", g.call("ACCENT"))
					var r3: float = uc.call("contrast", g.call("ON_ACCENT"), hov)
					if r3 < 4.5:
						fails += 1
						print("%s tint %.2f %-16s primário (hover) %.2f" % ["claro" if light else "escuro", tint, club[0], r3])
	print("contraste: %d pares, abaixo do mínimo: %d" % [checks, fails])
	quit()
