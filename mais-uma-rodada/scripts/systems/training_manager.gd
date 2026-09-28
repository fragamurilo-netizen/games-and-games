class_name TrainingManager
extends RefCounted
## Treino do clube do usuário: foco coletivo da semana, intensidade, sessão de preparação para o
## jogo e, por jogador, foco de atributos, carga, posição nova e estilo de jogo a desenvolver.
## Os clubes da IA treinam no padrão equilibrado (nenhum custo extra na simulação deles).
##
## Efeitos: direção e ritmo da evolução, recuperação física, risco de lesão (nos jogos e no
## próprio treino), entrosamento, um pequeno ajuste de setor nas partidas (ataque/defesa) e,
## com a preparação, bola parada mais perigosa ou estudo melhor do adversário.
## A qualidade do treino (CT + auxiliar + preparador) acelera o aprendizado e a preparação.
##
## Campos salvos (novos têm padrão; saves antigos carregam): club.training {focus, int, prep, wk};
## player.train {f, pos, prog, st, sg0, ld, last, log, oh}.

const TEAM_FOCUS := {
	"equilibrado": {"name": "Equilibrado", "desc": "Um pouco de tudo. Sem pontos fracos, sem ênfase.", "attrs": [], "growth": 1.0, "recovery": 1.0, "injury": 1.0, "cohesion": 0.0, "att": 1.0, "def": 1.0},
	"fisico": {"name": "Físico", "desc": "Velocidade, força e resistência. Cansa mais, forma atletas.", "attrs": [Attr.VEL, Attr.ACE, Attr.FOR, Attr.RES], "growth": 1.0, "recovery": 0.92, "injury": 1.15, "cohesion": 0.0, "att": 1.0, "def": 1.0},
	"tecnico": {"name": "Técnico", "desc": "Passe, técnica, visão e cruzamento.", "attrs": [Attr.PAS, Attr.TEC, Attr.DRI, Attr.VIS, Attr.CRU], "growth": 1.0, "recovery": 1.0, "injury": 0.95, "cohesion": 0.0, "att": 1.0, "def": 1.0},
	"tatico": {"name": "Tático", "desc": "Posicionamento, inteligência e entrosamento do time.", "attrs": [Attr.POS, Attr.INT, Attr.DEC, Attr.FRI], "growth": 0.95, "recovery": 1.0, "injury": 0.9, "cohesion": 1.0, "att": 1.0, "def": 1.0},
	"ataque": {"name": "Ataque", "desc": "Finalização e jogadas ofensivas. Setor ofensivo +3% nos jogos.", "attrs": [Attr.FIN, Attr.CHL, Attr.CAB, Attr.TEC], "growth": 1.0, "recovery": 1.0, "injury": 1.0, "cohesion": 0.2, "att": 1.03, "def": 0.99},
	"defesa": {"name": "Defesa", "desc": "Marcação e cobertura. Setor defensivo +3% nos jogos.", "attrs": [Attr.MAR, Attr.DES, Attr.POS, Attr.CAB], "growth": 1.0, "recovery": 1.0, "injury": 1.0, "cohesion": 0.2, "att": 0.99, "def": 1.03},
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
	"finalizacao": {"name": "Finalização", "attrs": [Attr.FIN, Attr.FRI, Attr.POS]},
	"chute": {"name": "Chute de longe", "attrs": [Attr.CHL, Attr.TEC]},
	"desarme": {"name": "Desarme e marcação", "attrs": [Attr.DES, Attr.MAR]},
	"armacao": {"name": "Armação", "attrs": [Attr.PAS, Attr.VIS, Attr.TEC]},
	"drible": {"name": "Drible e arranque", "attrs": [Attr.DRI, Attr.ACE, Attr.TEC]},
	"cruzamento": {"name": "Cruzamento", "attrs": [Attr.CRU, Attr.PAS]},
	"bola_aerea": {"name": "Jogo aéreo", "attrs": [Attr.CAB, Attr.FOR]},
	"marcacao": {"name": "Marcação", "attrs": [Attr.MAR, Attr.POS]},
	"fisico": {"name": "Físico", "attrs": [Attr.VEL, Attr.ACE, Attr.FOR, Attr.RES]},
	"mental": {"name": "Mental", "attrs": [Attr.DEC, Attr.INT, Attr.DIS]},
	"goleiro": {"name": "Goleiro", "attrs": [Attr.GOL, Attr.REF, Attr.POS]},
}
const PLAYER_FOCUS_ORDER: Array[String] = ["", "finalizacao", "chute", "armacao", "drible", "cruzamento", "bola_aerea", "marcacao", "desarme", "fisico", "mental", "goleiro"]

## Sessão de preparação para o jogo (tira um pouco do tempo de treino normal).
const PREP := {
	"": {"name": "Nenhuma", "desc": "A semana inteira vai para o foco do treino.", "growth": 1.0},
	"bola_parada": {"name": "Bola parada", "desc": "Escanteios e faltas ensaiados: mais chances e finalizações melhores nas cobranças.", "growth": 0.94, "sp": 0.14},
	"rival": {"name": "Estudo do rival", "desc": "Vídeo e treino contra o sistema do próximo adversário: o time mira melhor nos pontos fracos dele.", "growth": 0.95, "study": 0.22},
}
const PREP_ORDER: Array[String] = ["", "bola_parada", "rival"]

## Carga individual (por jogador).
const LOAD: Array = [
	{"name": "Poupar", "desc": "Carga reduzida: recupera mais rápido e quase não se machuca, mas evolui menos.", "growth": 0.8, "recovery": 1.15, "injury": 0.65},
	{"name": "Normal", "desc": "Treina com o grupo.", "growth": 1.0, "recovery": 1.0, "injury": 1.0},
	{"name": "Carga extra", "desc": "Fica depois do coletivo: evolui mais, mas cansa e se machuca mais.", "growth": 1.15, "recovery": 0.9, "injury": 1.35},
]
## Semanas guardadas no histórico de overall e mudanças de atributo guardadas por jogador.
const HIST_WEEKS := 12
const LOG_MAX := 10
## Lesão no treino por jogador e semana, sobre a parte da carga acima do normal.
const TRAIN_INJURY := 0.004


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
	return float(focus_of(c)["growth"]) * float(intensity_of(c)["growth"]) * float(prep_of(c)["growth"]) * float(load_of(p)["growth"]) * People.growth_mult(world, p)


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
	var st := PlayStyle.find(p, String(p.train.get("st", "")))
	var sw: Dictionary = st.get("w", {})
	for a in sw:
		out.append([int(a), 1.5 + float(sw[a]) * 2.0])
	return out


static func recovery_mult(world: GameWorld, club_id: int, p: Player = null) -> float:
	if not _is_user(world, club_id):
		return 1.0
	var c := world.club(club_id)
	var m := float(focus_of(c)["recovery"]) * float(intensity_of(c)["recovery"]) * People.recovery_mult(world)
	return m * float(load_of(p)["recovery"]) if p != null else m


static func injury_mult(world: GameWorld, club_id: int) -> float:
	if not _is_user(world, club_id):
		return 1.0
	var c := world.club(club_id)
	return float(focus_of(c)["injury"]) * float(intensity_of(c)["injury"]) * People.injury_mult(world)


## Carga individual do jogador (só no clube do usuário; nos jogos entra no risco de lesão dele).
static func player_injury_mult(world: GameWorld, p: Player) -> float:
	if not _is_user(world, p.club_id):
		return 1.0
	return float(load_of(p)["injury"])


static func prep_of(club: Club) -> Dictionary:
	return PREP.get(String(club.training.get("prep", "")), PREP[""])


static func load_of(p: Player) -> Dictionary:
	return LOAD[clampi(int(p.train.get("ld", 1)), 0, 2)]


## Qualidade do treino (0..1): centro de treinamento, auxiliar técnico e preparador físico.
static func quality(world: GameWorld, club: Club) -> float:
	var parts := quality_parts(world, club)
	var q := 0.0
	for pt in parts:
		q += float(pt[1]) * float(pt[2])
	return clampf(q, 0.0, 1.0)


## [nome, nível 0..1, peso] de cada parte da qualidade do treino.
static func quality_parts(world: GameWorld, club: Club) -> Array:
	var user := _is_user(world, club.id)
	return [
		["Centro de treinamento", clampf(club.facilities / 100.0, 0.0, 1.0), 0.5],
		["Auxiliar técnico", People.staff_level(world, "auxiliar") if user else 0.5, 0.3],
		["Preparador físico", People.staff_level(world, "preparador") if user else 0.5, 0.2],
	]


## Multiplicador de aprendizado (posição, estilo, preparação) pela qualidade do treino: 0,7 a 1,3.
static func learn_mult(world: GameWorld, club: Club) -> float:
	return 0.7 + 0.6 * quality(world, club)


## Bônus de bola parada da preparação (0 = nenhum): chance e qualidade de escanteios e faltas.
static func set_piece_bonus(world: GameWorld, club: Club) -> float:
	if club == null or not _is_user(world, club.id):
		return 0.0
	return float(prep_of(club).get("sp", 0.0)) * learn_mult(world, club)


## Estudo extra do adversário da preparação (soma ao TacticalScout.study do usuário).
static func study_bonus(world: GameWorld, club: Club) -> float:
	if club == null or not _is_user(world, club.id):
		return 0.0
	return float(prep_of(club).get("study", 0.0)) * learn_mult(world, club)


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
	club.cohesion = minf(95.0, club.cohesion + float(f["cohesion"]) * (0.6 + 0.2 * int(club.training.get("int", 1))) * ManagerProfile.cohesion_mult(world))
	var mdelta := float(inten["morale"])
	var wk := int(club.training.get("wk", 0)) + 1
	club.training["wk"] = wk
	var lm := learn_mult(world, club)
	var inj_base := float(f["injury"]) * float(inten["injury"]) * People.injury_mult(world)
	for p: Player in world.squad(club):
		if mdelta != 0.0:
			p.morale = clampf(p.morale + mdelta, 0.0, 100.0)
		_training_injury(world, club, p, inj_base)
		_style_week(world, club, p, lm)
		_record(p, wk)
		var target := int(p.train.get("pos", -1))
		if target < 0 or target == p.position or p.secondary.has(target):
			continue
		var rate := position_rate(world, club, p, target, lm)
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


## Progresso semanal ao aprender a posição `target` (1,0 = aprendida).
static func position_rate(world: GameWorld, club: Club, p: Player, target: int, lm: float = -1.0) -> float:
	if lm < 0.0:
		lm = learn_mult(world, club)
	var age := p.age(world.year)
	var rate := (0.07 if age <= 23 else (0.05 if age <= 29 else 0.035)) * (0.8 + 0.2 * int(club.training.get("int", 1))) * lm
	if Pos.group(target) == Pos.group(p.position):
		rate *= 1.6
	if target == Pos.GK or p.position == Pos.GK:
		rate *= 0.3
	return rate


## Posições que um jogador pode aprender (não é a dele nem uma secundária).
static func learnable_positions(p: Player) -> Array:
	var out: Array = []
	for i in Pos.COUNT:
		if i != p.position and not p.secondary.has(i):
			out.append(i)
	return out


## Lesão no próprio treino: só a parte da carga acima do normal (intensidade, foco físico, carga
## extra), mais provável em quem já está cansado ou tem histórico de lesões.
static func _training_injury(world: GameWorld, club: Club, p: Player, inj_base: float) -> void:
	if p.is_injured():
		return
	var m := inj_base * float(load_of(p)["injury"])
	var excess := m - 0.95
	if excess <= 0.0:
		return
	var cond_f := 1.0 + clampf((75.0 - p.condition) / 25.0, 0.0, 1.0)
	var prone_f := (1.0 + p.injury_prone / 10.0) * 0.5
	if world.rng.randf() >= TRAIN_INJURY * excess * cond_f * prone_f * (1.15 - 0.3 * quality(world, club)):
		return
	p.injury_weeks = world.rng.randi_range(1, 3)
	p.injury_name = RngUtil.pick(world.rng, ["Estiramento muscular (treino)", "Torção no tornozelo (treino)", "Dor na coxa (treino)", "Sobrecarga na panturrilha (treino)"])
	NewsManager.on_injury(world, p)
	InboxManager.on_injury(world, p)


## Estilo em desenvolvimento: jovens crescem na direção dele (bias_for); a cada semana também há
## uma pequena chance de "reorientar" um ponto (mais no atributo do estilo novo, menos num do
## estilo atual), o que vale para qualquer idade. Quando o estilo vira o principal, avisa.
static func _style_week(world: GameWorld, club: Club, p: Player, lm: float) -> void:
	var key := String(p.train.get("st", ""))
	if key == "":
		return
	var target := PlayStyle.find(p, key)
	if target.is_empty():
		p.train.erase("st")
		p.train.erase("sg0")
		return
	var cur := PlayStyle.primary(p)
	if String(cur["k"]) == key:
		p.train.erase("st")
		p.train.erase("sg0")
		NewsManager.post_raw(world, "%s ganhou um novo estilo" % p.display_name(),
			"O treino específico deu resultado: %s agora joga como %s." % [p.display_name(), String(target["n"]).to_lower()],
			club.id, p.id, NewsEvent.IMP_NORMAL)
		return
	var age := p.age(world.year)
	var chance := (0.16 if age <= 23 else (0.11 if age <= 29 else 0.07)) * lm * float(load_of(p)["growth"])
	if world.rng.randf() >= chance:
		return
	var up := -1
	for a in PlayStyle.attrs_of(target):
		if p.attrs[int(a)] < mini(95, p.overall + 15):
			up = int(a)
			break
	var down := -1
	var tw: Dictionary = target.get("w", {})
	for a in PlayStyle.attrs_of(cur):
		if not tw.has(a) and p.attrs[int(a)] > 30:
			down = int(a)
			break
	if up < 0 or down < 0:
		return
	p.attrs[up] = p.attrs[up] + 1
	p.attrs[down] = p.attrs[down] - 1
	p._pos_cache_dirty = true
	p.recompute_overall()


## Histórico que a tela de treino mostra: overall semana a semana e as últimas mudanças de atributo.
static func _record(p: Player, wk: int) -> void:
	var last: PackedByteArray = p.train.get("last", PackedByteArray())
	if last.size() == p.attrs.size():
		var lg: Array = p.train.get("log", [])
		for i in p.attrs.size():
			var d := int(p.attrs[i]) - int(last[i])
			if d != 0:
				lg.append([wk, i, d])
		if lg.size() > LOG_MAX:
			lg = lg.slice(lg.size() - LOG_MAX)
		if not lg.is_empty():
			p.train["log"] = lg
	p.train["last"] = p.attrs.duplicate()
	var oh: Array = p.train.get("oh", [])
	oh.append(snappedf(p.ovr_f, 0.1))
	if oh.size() > HIST_WEEKS:
		oh = oh.slice(oh.size() - HIST_WEEKS)
	p.train["oh"] = oh


## Variação de overall nas últimas `weeks` semanas registradas (0 sem histórico).
static func trend(p: Player, weeks: int = HIST_WEEKS) -> float:
	var oh: Array = p.train.get("oh", [])
	if oh.size() < 2:
		return 0.0
	var i0 := maxi(0, oh.size() - 1 - weeks)
	return float(oh[oh.size() - 1]) - float(oh[i0])


## Mudanças de atributo recentes, da mais nova para a mais velha: [[semana, atributo, delta]].
static func recent_changes(p: Player) -> Array:
	var lg: Array = p.train.get("log", [])
	var out := lg.duplicate()
	out.reverse()
	return out


## Começa (ou troca) o estilo a desenvolver ("" para parar).
static func set_style_target(p: Player, key: String) -> void:
	if key == "":
		p.train.erase("st")
		p.train.erase("sg0")
		return
	p.train["st"] = key
	p.train["sg0"] = maxf(0.5, PlayStyle.gap_to(p, key))


## Progresso até o estilo alvo (0..1).
static func style_progress(p: Player) -> float:
	var key := String(p.train.get("st", ""))
	if key == "":
		return 0.0
	var g0 := float(p.train.get("sg0", 1.0))
	return clampf(1.0 - PlayStyle.gap_to(p, key) / maxf(0.5, g0), 0.0, 1.0)
