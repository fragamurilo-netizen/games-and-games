class_name TrainingManager
extends RefCounted
## Treino do clube do usuário: foco coletivo da semana, intensidade e foco individual
## (inclusive aprender uma nova posição). Os clubes da IA treinam no padrão equilibrado.
##
## Efeitos: direção e ritmo da evolução, recuperação física, risco de lesão, entrosamento
## e um pequeno ajuste de setor nas partidas (ataque/defesa).

const TEAM_FOCUS := {
	"equilibrado": {"name": "Equilibrado", "desc": "Um pouco de tudo. Sem pontos fracos, sem ênfase.", "attrs": [], "growth": 1.0, "recovery": 1.0, "injury": 1.0, "cohesion": 0.0, "att": 1.0, "def": 1.0},
	"fisico": {"name": "Físico", "desc": "Velocidade, força e resistência. Cansa mais, forma atletas.", "attrs": [Attr.VEL, Attr.FOR, Attr.RES], "growth": 1.0, "recovery": 0.92, "injury": 1.15, "cohesion": 0.0, "att": 1.0, "def": 1.0},
	"tecnico": {"name": "Técnico", "desc": "Passe, técnica, visão e cruzamento.", "attrs": [Attr.PAS, Attr.TEC, Attr.VIS, Attr.CRU], "growth": 1.0, "recovery": 1.0, "injury": 0.95, "cohesion": 0.0, "att": 1.0, "def": 1.0},
	"tatico": {"name": "Tático", "desc": "Posicionamento, inteligência e entrosamento do time.", "attrs": [Attr.POS, Attr.INT, Attr.DEC], "growth": 0.95, "recovery": 1.0, "injury": 0.9, "cohesion": 1.0, "att": 1.0, "def": 1.0},
	"ataque": {"name": "Ataque", "desc": "Finalização e jogadas ofensivas. Setor ofensivo +3% nos jogos.", "attrs": [Attr.FIN, Attr.CAB, Attr.TEC], "growth": 1.0, "recovery": 1.0, "injury": 1.0, "cohesion": 0.2, "att": 1.03, "def": 0.99},
	"defesa": {"name": "Defesa", "desc": "Marcação e cobertura. Setor defensivo +3% nos jogos.", "attrs": [Attr.MAR, Attr.POS, Attr.CAB], "growth": 1.0, "recovery": 1.0, "injury": 1.0, "cohesion": 0.2, "att": 0.99, "def": 1.03},
	"recuperacao": {"name": "Recuperação", "desc": "Treinos leves e fisioterapia. Recupera rápido, evolui menos.", "attrs": [], "growth": 0.65, "recovery": 1.3, "injury": 0.6, "cohesion": 0.0, "att": 1.0, "def": 1.0},
}
const FOCUS_ORDER: Array[String] = ["equilibrado", "fisico", "tecnico", "tatico", "ataque", "defesa", "recuperacao"]

const INTENSITY: Array = [
	{"name": "Leve", "growth": 0.85, "recovery": 1.12, "injury": 0.7, "morale": 0.4},
	{"name": "Normal", "growth": 1.0, "recovery": 1.0, "injury": 1.0, "morale": 0.0},
	{"name": "Intensa", "growth": 1.15, "recovery": 0.88, "injury": 1.4, "morale": -0.4},
]

const PLAYER_FOCUS := {
	"": {"name": "Sem foco", "attrs": []},
	"finalizacao": {"name": "Finalização", "attrs": [Attr.FIN, Attr.POS]},
	"armacao": {"name": "Armação", "attrs": [Attr.PAS, Attr.VIS, Attr.TEC]},
	"drible": {"name": "Drible e velocidade", "attrs": [Attr.TEC, Attr.VEL]},
	"cruzamento": {"name": "Cruzamento", "attrs": [Attr.CRU, Attr.PAS]},
	"bola_aerea": {"name": "Jogo aéreo", "attrs": [Attr.CAB, Attr.FOR]},
	"marcacao": {"name": "Marcação", "attrs": [Attr.MAR, Attr.POS]},
	"fisico": {"name": "Físico", "attrs": [Attr.VEL, Attr.FOR, Attr.RES]},
	"mental": {"name": "Mental", "attrs": [Attr.DEC, Attr.INT, Attr.DIS]},
	"goleiro": {"name": "Goleiro", "attrs": [Attr.GOL, Attr.POS]},
}
const PLAYER_FOCUS_ORDER: Array[String] = ["", "finalizacao", "armacao", "drible", "cruzamento", "bola_aerea", "marcacao", "fisico", "mental", "goleiro"]


static func focus_of(club: Club) -> Dictionary:
	return TEAM_FOCUS.get(String(club.training.get("focus", "equilibrado")), TEAM_FOCUS["equilibrado"])


static func intensity_of(club: Club) -> Dictionary:
	return INTENSITY[clampi(int(club.training.get("int", 1)), 0, 2)]


static func _is_user(world: GameWorld, club_id: int) -> bool:
	return club_id >= 0 and club_id == world.user_club_id


## Multiplicador de evolução (foco e intensidade) para um jogador do usuário.
static func growth_mult(world: GameWorld, p: Player) -> float:
	if not _is_user(world, p.club_id):
		return 1.0
	var c := world.club(p.club_id)
	return float(focus_of(c)["growth"]) * float(intensity_of(c)["growth"]) * People.growth_mult(world, p)


## Atributos favorecidos na evolução: foco do time + foco individual.
static func bias_for(world: GameWorld, p: Player) -> Array:
	if not _is_user(world, p.club_id):
		return []
	var c := world.club(p.club_id)
	var out: Array = []
	for a in focus_of(c)["attrs"]:
		out.append([int(a), 1.8])
	var pf: Dictionary = PLAYER_FOCUS.get(String(p.train.get("f", "")), {})
	for a in pf.get("attrs", []):
		out.append([int(a), 3.0])
	return out


static func recovery_mult(world: GameWorld, club_id: int) -> float:
	if not _is_user(world, club_id):
		return 1.0
	var c := world.club(club_id)
	return float(focus_of(c)["recovery"]) * float(intensity_of(c)["recovery"]) * People.recovery_mult(world)


static func injury_mult(world: GameWorld, club_id: int) -> float:
	if not _is_user(world, club_id):
		return 1.0
	var c := world.club(club_id)
	return float(focus_of(c)["injury"]) * float(intensity_of(c)["injury"]) * People.injury_mult(world)


## [ataque, defesa] do foco da semana (só no clube do usuário).
static func unit_mults(world: GameWorld, club: Club) -> Array:
	if club == null or not _is_user(world, club.id):
		return [1.0, 1.0]
	var f := focus_of(club)
	return [float(f["att"]), float(f["def"])]


## Ritmo de evolução da base (o foco "recuperação" também alivia os garotos).
static func youth_mult(world: GameWorld) -> float:
	if not world.has_user():
		return 1.0
	var c := world.user_club()
	return float(intensity_of(c)["growth"]) * (0.8 if String(c.training.get("focus", "")) == "recuperacao" else 1.0) * People.youth_mult(world)


## Semana de treino do usuário: entrosamento, moral pela intensidade e aprendizado de posição.
static func weekly(world: GameWorld) -> void:
	if not world.has_user():
		return
	var club := world.user_club()
	var f := focus_of(club)
	var inten := intensity_of(club)
	club.cohesion = minf(95.0, club.cohesion + float(f["cohesion"]) * (0.6 + 0.2 * int(club.training.get("int", 1))))
	var mdelta := float(inten["morale"])
	for p: Player in world.squad(club):
		if mdelta != 0.0:
			p.morale = clampf(p.morale + mdelta, 0.0, 100.0)
		var target := int(p.train.get("pos", -1))
		if target < 0 or target == p.position or p.secondary.has(target):
			continue
		var age := p.age(world.year)
		var rate := (0.07 if age <= 23 else (0.05 if age <= 29 else 0.035)) * (0.8 + 0.2 * int(club.training.get("int", 1)))
		if Pos.group(target) == Pos.group(p.position):
			rate *= 1.6
		if target == Pos.GK or p.position == Pos.GK:
			rate *= 0.3
		var prog := float(p.train.get("prog", 0.0)) + rate
		if prog >= 1.0:
			p.secondary.append(target)
			p._pos_cache_dirty = true
			p.train.erase("pos")
			p.train.erase("prog")
			NewsManager.post_raw(world, "%s aprendeu uma nova posição" % p.display_name(),
				"Depois de semanas de treino específico, %s já pode atuar como %s." % [p.display_name(), Pos.name_of(target).to_lower()],
				club.id, p.id, NewsEvent.IMP_NORMAL)
		else:
			p.train["prog"] = prog


## Posições que um jogador pode aprender (não é a dele nem uma secundária).
static func learnable_positions(p: Player) -> Array:
	var out: Array = []
	for i in Pos.COUNT:
		if i != p.position and not p.secondary.has(i):
			out.append(i)
	return out
