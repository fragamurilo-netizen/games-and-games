class_name Fame
extends RefCounted
## Fama dos lutadores (0 a 100) com teto pelo lugar no ranking. Sem teto, todo mundo que fica
## anos na elite vira estrela e o hype das noites (e a conta da liga) infla junto.
##
## - O teto sobe com o ranking: campeão recém-coroado 88 (e 4 por defesa, até 100), top 5 86,
##   top 10 78, top 15 70, até o 30º 62, até o 60º 52, o resto 42.
## - Perto do teto a fama sobe cada vez mais devagar (`room`); acima dele ainda sobe um pouco,
##   mas escorre de volta com o tempo (`week`): ex-campeão continua nome grande por uns anos.
## Todo ganho de fama passa por `add`.

const OVER := 12.0
const SPAN := 40.0


static func ceiling(w: GameWorld, f: Fighter) -> float:
	var r := w.rank_of(f)
	if r == 0:
		return minf(100.0, 88.0 + 4.0 * float(f.title_defenses))
	if w.is_interim(f):
		return 88.0
	if r < 0 or r > 60:
		return 42.0
	if r <= 5:
		return 86.0
	if r <= 10:
		return 78.0
	if r <= 15:
		return 70.0
	if r <= 30:
		return 62.0
	return 52.0


## Quanto de um ganho de fama entra de verdade (0,12 a 1): cheio para quem está longe do teto.
static func room(w: GameWorld, f: Fighter) -> float:
	return clampf((ceiling(w, f) + OVER - f.popularity) / SPAN, 0.12, 1.0)


static func add(w: GameWorld, f: Fighter, amount: float) -> void:
	if f == null:
		return
	if amount <= 0.0:
		f.popularity = maxf(1.0, f.popularity + amount)
		return
	f.popularity = minf(100.0, f.popularity + amount * room(w, f))


## Semana a semana: quem está acima do teto perde um pouco do que passa dele.
static func week(w: GameWorld, f: Fighter) -> void:
	var over := f.popularity - ceiling(w, f) - 3.0
	if over > 0.0:
		f.popularity -= 0.02 + over * 0.008
