class_name InjuryTable
extends RefCounted
## Duração e nome das lesões. A maioria é curta; poucas são graves (e viram histórias).

const TABLE: Array = [
	# [peso, semanas mín, semanas máx, nomes]
	[50.0, 1, 1, ["Pancada no tornozelo", "Dores musculares", "Contusão na coxa", "Pancada no joelho"]],
	[22.0, 2, 3, ["Estiramento na coxa", "Entorse no tornozelo", "Lesão leve na panturrilha"]],
	[14.0, 4, 6, ["Lesão muscular na coxa", "Entorse grave no tornozelo", "Lesão na virilha"]],
	[9.0, 7, 12, ["Lesão no menisco", "Fratura no pé", "Lesão no tendão"]],
	[5.0, 13, 30, ["Ruptura do ligamento do joelho", "Fratura na perna", "Lesão grave no tendão de Aquiles"]],
]


## Sorteio sem acessar tabelas compartilhadas (seguro e rápido dentro de threads).
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
	return rng.randi_range(13, 30)


static func name_for(weeks: int, seed_value: int) -> String:
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
