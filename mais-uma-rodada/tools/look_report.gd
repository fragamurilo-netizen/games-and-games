extends SceneTree
## Distribuição de penteados e barbas dos jogadores gerados (para comparar com o futebol real).


const FLASHY_H := ["Moicano", "Nevou (descolorido)", "Espetado descolorido", "Descolorido com desenho", "Moicano espetado",
	"Moicano trançado", "Moicano de dreads", "Moicano cacheado", "Mullet", "Mullet com degradê", "Mullet cacheado",
	"Tigela", "Samurai", "High top", "Black power alto", "Dois puffs", "Afro puff", "Espetado com gel", "Máquina com desenho",
	"Cachos com luzes", "Chanel", "Faux hawk", "Sidecut", "Nagô em zigue-zague", "Arrepiado"]
const LONG_H := ["Longo", "Coque", "Rabo de cavalo", "Surfista", "Cacheado longo", "Meio preso", "Longo para trás",
	"Longo ondulado", "Coque baixo", "Longo com franja", "Coque com undercut", "Undercut com coque baixo", "Coque alto com degradê",
	"Cacheado longo com franja", "Flow para trás"]
const BRAID_H := ["Dreads", "Tranças nagô", "Twists", "Box braids", "Locs curtos", "Nagô com degradê", "Freeform",
	"Dreads com degradê", "Tranças com coque", "Dreads presos", "Tranças longas com degradê", "Twists longos", "Dreads em rabo",
	"Nagô com rabo", "Freeform com degradê"]


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var hs := {}
	var cat := {"comum": 0, "raspado/careca": 0, "longo/coque": 0, "tranças/dreads": 0, "afro": 0, "chamativo": 0}
	var bd := {}
	var bcat := {"sem": 0, "por fazer": 0, "barba": 0, "cavanhaque/bigode": 0, "exótica": 0}
	var n := 0
	var na := 0
	for p: Player in w.players.values():
		var age := p.age(w.year)
		var f := FaceGen.features(p.face_seed, p.eth, age, p.look)
		var s: String = FaceGen.HAIR_STYLES[int(f["style"])]
		hs[s] = int(hs.get(s, 0)) + 1
		n += 1
		if s in FLASHY_H:
			cat["chamativo"] += 1
		elif s in LONG_H:
			cat["longo/coque"] += 1
		elif s in BRAID_H:
			cat["tranças/dreads"] += 1
		elif s.begins_with("Black power") or s.begins_with("Afro"):
			cat["afro"] += 1
		elif s in ["Raspado", "Careca", "Máquina 2", "Buzz com degradê", "Militar"]:
			cat["raspado/careca"] += 1
		else:
			cat["comum"] += 1
		if age >= 24 and age <= 34:
			na += 1
			var b: String = FaceGen.BEARDS[int(f["beard"])]
			bd[b] = int(bd.get(b, 0)) + 1
			var bi := int(f["beard"])
			if bi == FaceGen.B_NONE or bi == FaceGen.B_WISPY or bi == FaceGen.B_PEACH:
				bcat["sem"] += 1
			elif bi in [FaceGen.B_STUBBLE, FaceGen.B_HEAVY_STUBBLE, FaceGen.B_DENSE_STUBBLE, FaceGen.B_WEEK, FaceGen.B_FADED]:
				bcat["por fazer"] += 1
			elif bi in [FaceGen.B_SHORT, FaceGen.B_FULL, FaceGen.B_BOXED, FaceGen.B_MEDIUM, FaceGen.B_TRIMMED, FaceGen.B_SQUARE, FaceGen.B_ROUNDED, FaceGen.B_SHORT_SHARP, FaceGen.B_LINE_CUT, FaceGen.B_PATCHY]:
				bcat["barba"] += 1
			elif bi in [FaceGen.B_GOATEE, FaceGen.B_MUSTACHE, FaceGen.B_VANDYKE, FaceGen.B_CHINSTRAP, FaceGen.B_SOUL, FaceGen.B_CIRCLE, FaceGen.B_BALBO, FaceGen.B_ANCHOR]:
				bcat["cavanhaque/bigode"] += 1
			else:
				bcat["exótica"] += 1
	print("PENTEADOS (%d jogadores)" % n)
	for k in cat:
		print("  %-16s %5.1f%%" % [k, 100.0 * cat[k] / n])
	var ks := hs.keys()
	ks.sort_custom(func(a, b): return hs[a] > hs[b])
	var line := ""
	for k in ks.slice(0, 30):
		line += "%s %.1f%% · " % [k, 100.0 * hs[k] / n]
	print("  top: ", line)
	print("BARBAS 24-34 anos (%d)" % na)
	for k in bcat:
		print("  %-18s %5.1f%%" % [k, 100.0 * bcat[k] / na])
	var bks := bd.keys()
	bks.sort_custom(func(a, b): return bd[a] > bd[b])
	line = ""
	for k in bks.slice(0, 25):
		line += "%s %.1f%% · " % [k, 100.0 * bd[k] / na]
	print("  top: ", line)
	quit()
