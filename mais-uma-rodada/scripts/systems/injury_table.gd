class_name InjuryTable
extends RefCounted
## Duração e nome das lesões. A maioria é curta; poucas são graves (e viram histórias).

const TABLE: Array = [
	# [peso, semanas mín, semanas máx, nomes] — nomes e prazos como nos departamentos médicos de verdade
	[50.0, 1, 1, ["Pancada no tornozelo", "Desconforto muscular", "Contusão na coxa", "Pancada no joelho", "Concussão leve",
		"Dores nas costas", "Fratura no nariz", "Corte no supercílio"]],
	[22.0, 2, 3, ["Lesão na posterior da coxa (grau 1)", "Entorse no tornozelo", "Lesão na panturrilha (grau 1)",
		"Distensão no adutor", "Lesão no quadríceps (grau 1)", "Entorse no joelho", "Lesão na lombar"]],
	[14.0, 4, 6, ["Lesão na posterior da coxa (grau 2)", "Entorse grave no tornozelo", "Pubalgia", "Lesão no ligamento colateral do joelho",
		"Luxação no ombro", "Lesão no quadríceps (grau 2)", "Lesão na panturrilha (grau 2)"]],
	[9.0, 7, 12, ["Fratura no metatarso", "Lesão no menisco", "Lesão na posterior da coxa (grau 3)", "Fratura na clavícula",
		"Lesão no tendão patelar", "Fratura no tornozelo"]],
	[5.0, 13, 40, ["Ruptura do ligamento cruzado anterior", "Ruptura do tendão de Aquiles", "Fratura na tíbia e na fíbula",
		"Lesão no menisco com cirurgia"]],
]


## Sorteio sem acessar tabelas compartilhadas (seguro e rápido dentro de threads).
## A cauda longa é o cruzado/Aquiles: 6 a 9 meses parado.
static func roll_weeks(rng: RandomNumberGenerator) -> int:
	var r := rng.randf() * 100.0
	if r < 50.0:
		return 1
	if r < 72.0:
		return rng.randi_range(2, 3)
	if r < 86.0:
		return rng.randi_range(4, 6)
	if r < 95.0:
		return rng.randi_range(7, 12)
	if r < 98.2:
		return rng.randi_range(13, 22)
	return rng.randi_range(26, 38)


static func name_for(weeks: int, seed_value: int) -> String:
	if weeks >= 26:
		return ["Ruptura do ligamento cruzado anterior", "Ruptura do tendão de Aquiles"][absi(seed_value) % 2]
	if weeks >= 13:
		return ["Fratura na tíbia e na fíbula", "Lesão no menisco com cirurgia", "Lesão grave na posterior da coxa (tendão)"][absi(seed_value) % 3]
	for row in TABLE:
		if weeks <= int(row[2]):
			var names: Array = row[3]
			return names[absi(seed_value) % names.size()]
	return "Lesão grave"


static func severity_label(weeks: int) -> String:
	if weeks <= 1:
		return "leve"
	if weeks <= 3:
		return "moderada"
	if weeks <= 6:
		return "séria"
	if weeks <= 12:
		return "grave"
	return "gravíssima"
