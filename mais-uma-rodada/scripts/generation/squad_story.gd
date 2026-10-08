class_name SquadStory
extends RefCounted
## O "roteiro" de um elenco inicial, para ele parecer montado ao longo de anos e não sorteado:
##   - hierarquia de titulares: um ou dois que decidem, um miolo forte e o elo fraco que o
##     torcedor quer ver substituído (a média do time continua a do clube: calibrate_xi);
##   - capitão: experiente, líder, anos de casa;
##   - ídolo veterano: no fim da carreira, quase sempre no banco, a torcida canta o nome dele;
##   - joia da base: o garoto de 17–18 anos de quem todo mundo fala;
##   - repatriado: cria do clube que rodou fora e voltou para casa (Brasil, Argentina...);
##   - astros estrangeiros onde a vida real tem (Arábia, Catar, Emirados, EUA, China).
## Tudo sai do RNG do mundo dentro de create_squad.

## Distância de cada titular, do melhor ao pior, até a média do time (11 titulares).
const RANK_OFFSETS: Array = [4.6, 3.1, 2.2, 1.4, 0.7, 0.0, -0.7, -1.4, -2.1, -2.9, -4.0]

## Ligas com astros estrangeiros veteranos (Arábia, Golfo) ou "jogadores designados" (EUA, China).
const MARQUEE := {"KSA": [30, 34], "QAT": [30, 35], "UAE": [29, 34], "USA": [28, 34], "CHN": [28, 33]}

## Quanto o estrangeiro chega mais velho (+) ou mais novo (−) que o local: vitrines que compram
## para revender (Portugal, Holanda, Bélgica...) e ligas que pagam pela experiência.
const IMPORT_AGE := {"POR": -2, "NED": -3, "BEL": -2, "AUT": -2, "SUI": -1, "DEN": -2, "SWE": -1, "NOR": -1,
	"FRA": -1, "CRO": -2, "SRB": -2, "CZE": -1, "UKR": -1, "SCO": 1, "TUR": 2, "GRE": 1, "MEX": 1,
	"KSA": 3, "QAT": 3, "UAE": 3, "USA": 1, "CHN": 2, "JPN": 1, "KOR": 1, "AUS": 1}

## Países onde é comum o craque formado em casa voltar depois de rodar o mundo.
const HOMECOMING := {"BRA": 0.65, "ARG": 0.65, "URU": 0.6, "COL": 0.5, "CHI": 0.45, "PAR": 0.5, "ECU": 0.45,
	"PER": 0.4, "BOL": 0.35, "VEN": 0.35, "MEX": 0.4, "POR": 0.35, "NED": 0.35, "BEL": 0.3, "SCO": 0.3,
	"DEN": 0.35, "SWE": 0.35, "NOR": 0.35, "CRO": 0.4, "SRB": 0.4, "TUR": 0.3, "GRE": 0.35, "USA": 0.3,
	"JPN": 0.35, "KOR": 0.35, "AUS": 0.35, "ESP": 0.2, "ITA": 0.2, "GER": 0.15, "FRA": 0.15, "ENG": 0.1}

## Papéis distribuídos na criação do mundo (id do jogador → papel). Só vale durante a geração:
## o passado (CareerBackfill) lê daqui para contar a história certa, e depois é limpo.
static var roles: Dictionary = {}
## Ferramentas (tools/squad_report.gd) guardam os papéis depois da geração.
static var keep := false


## Monta o plano do elenco: {índice da vaga: {"rank": n, "role": papel}}.
## `slots` segue PlayerGenerator.SQUAD_TEMPLATE ([posição, deslocamento, nível]).
static func plan(rng: RandomNumberGenerator, club: Club, slots: Array) -> Dictionary:
	var out := {}
	var starters: Array = []
	var bench: Array = []
	var kids: Array = []
	for i in slots.size():
		match int(slots[i][2]):
			0:
				starters.append(i)
			1:
				bench.append(i)
			_:
				kids.append(i)
	# Ordem de qualidade dos titulares: o craque puxa um pouco para o meio e o ataque, mas o
	# zagueiro ou o goleiro também podem ser o melhor do time (pender demais para o ataque
	# desequilibra o motor e infla os gols).
	var w: Array = []
	for i in starters:
		var p: int = slots[i][0]
		w.append(1.15 if p in [Pos.ST, Pos.AM, Pos.RW, Pos.LW] else (1.1 if p == Pos.CM else (0.8 if p in [Pos.RB, Pos.LB] else (0.9 if p == Pos.GK else 1.0))))
	for rank in starters.size():
		var j := RngUtil.weighted_index(rng, w)
		if j < 0:
			break
		out[starters[j]] = {"rank": rank}
		w[j] = 0.0
	var used := {}
	var nation := club.nation
	var big := club.reputation >= 74.0
	# Astros estrangeiros: 1 a 3 dos melhores titulares (só fora da regra de "só da casa")
	var pol := ClubPolicy.of(club)
	if MARQUEE.has(nation) and club.tier == 1 and not pol.has("only"):
		var n_mq := 1 + (1 if club.reputation >= 66.0 else 0) + (1 if club.reputation >= 74.0 else 0)
		for si in out:
			if int(out[si]["rank"]) < n_mq and int(slots[si][0]) != Pos.GK:
				out[si]["role"] = "astro"
				used[si] = true
	# Capitão: titular experiente do miolo do time (zagueiro, volante, meia ou goleiro)
	if rng.randf() < 0.85:
		var cands: Array = []
		for si in out:
			if not used.has(si) and int(out[si]["rank"]) in range(1, 8) and int(slots[si][0]) in [Pos.CB, Pos.DM, Pos.CM, Pos.GK, Pos.ST, Pos.RB, Pos.LB]:
				cands.append(si)
		if not cands.is_empty():
			var c: int = RngUtil.pick(rng, cands)
			out[c]["role"] = "capitao"
			used[c] = true
	# Ídolo veterano: no banco, anos de clube (clube tradicional quase sempre tem um)
	var idol_p := 0.5
	match club.archetype:
		"gigante_endividado", "tradicional_decadente", "tradicional_equilibrado":
			idol_p = 0.8
		"rico_promovido":
			idol_p = 0.2
	if pol.has("only"):
		idol_p = 0.9
	if rng.randf() < idol_p and not bench.is_empty():
		var b: int = RngUtil.pick(rng, bench)
		out[b] = {"rank": -1, "role": "idolo"}
		used[b] = true
	# Repatriado: cria do clube que jogou fora e voltou (titular ou banco, nunca goleiro)
	if rng.randf() < float(HOMECOMING.get(nation, 0.2)) * (1.0 if club.tier == 1 else 0.6):
		var cands2: Array = []
		for si in starters + bench:
			if not used.has(si) and int(slots[si][0]) != Pos.GK and int(out.get(si, {}).get("rank", 99)) >= 1:
				cands2.append(si)
		if not cands2.is_empty():
			var r: int = RngUtil.pick(rng, cands2)
			var d: Dictionary = out.get(r, {"rank": -1})
			d["role"] = "repatriado"
			out[r] = d
			used[r] = true
	# Joia da base: o garoto de quem todo mundo fala (clube formador às vezes tem dois)
	RngUtil.shuffle(rng, kids)
	var n_gems := 1 if rng.randf() < (0.75 if big else 0.55) else 0
	if club.archetype in ["formador", "vendedor"] or club.youth_level >= 80:
		n_gems += 1 if rng.randf() < 0.6 else 0
	for k in mini(n_gems, kids.size()):
		out[kids[k]] = {"rank": -1, "role": "joia"}
	return out


## Distância do titular de posição `rank` (0 = melhor) até a média do time, entre `n` titulares.
## Clube grande tem craques mais acima da média; o pequeno, um time mais parelho.
static func rank_offset(rank: int, n: int, club: Club) -> float:
	if rank < 0 or n <= 0:
		return 0.0
	var f := float(rank) / maxf(1.0, float(n - 1)) * float(RANK_OFFSETS.size() - 1)
	var i := mini(int(floor(f)), RANK_OFFSETS.size() - 2)
	var off := lerpf(float(RANK_OFFSETS[i]), float(RANK_OFFSETS[i + 1]), f - float(i))
	var rr: Array = club.league_cfg().get("rep", [40, 70])
	var t := clampf((club.reputation - float(rr[0])) / maxf(1.0, float(rr[1]) - float(rr[0])), 0.0, 1.0)
	var spread := (0.8 + 0.4 * t) * (1.0 if club.tier == 1 else 0.85)
	return off * spread


## Idade de quem cumpre um papel (ou -1 para seguir a idade sorteada).
static func role_age(rng: RandomNumberGenerator, role: String, pos: int, club: Club) -> int:
	match role:
		"capitao":
			return clampi(int(round(rng.randfn(29.5, 1.8))), 27, 33) + (1 if pos == Pos.GK else 0)
		"idolo":
			return clampi(int(round(rng.randfn(34.0, 1.4))), 32, 36) + (1 if pos == Pos.GK else 0)
		"repatriado":
			return clampi(int(round(rng.randfn(32.0, 1.5))), 29, 35)
		"joia":
			return rng.randi_range(17, 18)
		"astro":
			var r: Array = MARQUEE.get(club.nation, [29, 33])
			return rng.randi_range(int(r[0]), int(r[1]))
	return -1


## Nacionalidade de quem cumpre um papel ("" para seguir o sorteio normal).
static func role_nation(rng: RandomNumberGenerator, role: String, club: Club) -> String:
	match role:
		"idolo", "repatriado":
			return club.nation
		"capitao":
			return club.nation if rng.randf() < 0.7 else ""
		"astro":
			var nat := PlayerGenerator.pick_import(rng, club.nation)
			return nat if nat != club.nation else String(RngUtil.pick(rng, ["BRA", "FRA", "POR", "ESP", "ARG", "ENG", "BEL", "NED", "CRO", "ALG", "MAR", "SEN"]))
	return ""


## Ajuste do nível-alvo de quem cumpre um papel (antes da penalidade de idade).
static func role_target(role: String) -> float:
	match role:
		"idolo":
			return 3.0 # já foi muito bom: o banco é pela idade, não pela bola
		"repatriado":
			return 1.0
		"joia":
			return 4.0 # pronto antes da hora
		"astro":
			return 2.5
	return 0.0


## Depois de criado e contratado: tempo de casa, traços e o teto da joia.
static func apply(world: GameWorld, rng: RandomNumberGenerator, club: Club, p: Player, role: String, level: float) -> void:
	if role == "":
		return
	roles[p.id] = role
	var age := p.age(world.year)
	match role:
		"capitao":
			_add_trait(p, "lider")
			p.joined_year = world.year - rng.randi_range(mini(4, maxi(0, age - 18)), clampi(age - 19, 0, 10))
		"idolo":
			_add_trait(p, "idolo")
			if rng.randf() < 0.5:
				_add_trait(p, "leal")
			if rng.randf() < 0.55:
				p.joined_year = world.year - maxi(0, age - 18) # cria da casa, nunca saiu
			else:
				p.joined_year = world.year - rng.randi_range(8, clampi(age - 21, 8, 14))
			p.contract_end = world.year + rng.randi_range(0, 1) # renovação ano a ano
		"repatriado":
			p.joined_year = world.year - rng.randi_range(0, 1)
			if rng.randf() < 0.4:
				_add_trait(p, "idolo")
			if rng.randf() < 0.5:
				_add_trait(p, "caseiro")
		"joia":
			p.joined_year = world.year
			# Quanto maior o clube, mais alto o teto do garoto que ele segura na base.
			var top := level + 4.0 + rng.randf_range(0.0, 6.0) + club.youth_level * 0.02
			if top > 85.0:
				top = 85.0 + (top - 85.0) * 0.5
			p.potential = clampi(maxi(p.potential, int(round(top))), p.overall + 6, 94)
			p.squad_status = Player.STATUS_PROSPECT
		"astro":
			if rng.randf() < 0.5:
				_add_trait(p, "estrela")
			p.joined_year = world.year - rng.randi_range(0, 2)


static func _add_trait(p: Player, t: String) -> void:
	if p.traits.has(t):
		return
	var conflicts: Array = DatabaseManager.personalities().get("conflicts", [])
	for other in p.traits.duplicate():
		if PlayerGenerator._conflicts(conflicts, t, String(other)):
			p.traits.erase(other)
	if p.traits.size() >= 3:
		p.traits.remove_at(p.traits.size() - 1)
	p.traits.append(t)
	p.clear_trait_cache() # o salário e a ambição já lidos na geração mudam com o traço novo
