class_name ClubEvents
extends RefCounted
## Acontecimentos institucionais que mudam clubes pelo mundo, sempre pela realidade de cada país:
##   dedução de pontos por regra financeira (PSR inglês) ou escândalo, transfer ban da FIFA por
##   dívida, portões fechados por briga de torcida (Brasil, Argentina, Turquia...), salários
##   atrasados e patrocinador master que chega ou vai embora. Compras de clube, SAF, presidentes e
##   recuperação judicial ficam no WorldEvents (que usa daqui quem compra onde e as punições).
## Estado em club.affairs: {ban (ano até quando está punido, exclusivo), closed (jogos com portões
##   fechados), psr_<ano>}.
## Probabilidades são por temporada e divididas pelas datas do calendário.


## Quem compra clube em cada canto: fundos do Golfo e americanos na Inglaterra e na França,
## grupos multiclubes e americanos pela Europa, grupos e empresários locais nas SAFs e na América.
const INVESTORS := {
	"gulf": ["Fundo Soberano do Golfo", "Sahara Investment Authority", "Falcão Capital", "Oásis Sports Holding"],
	"us": ["Blue Harbor Partners", "Northstar Sports Group", "Meridian Football Partners", "Titan Ventures", "Eagle Bay Football"],
	"multi": ["Atlas Capital", "Aurora Global", "Lionheart Equity", "Sunrise Sports & Media", "Dragão Dourado Holdings"],
	"latam": ["Grupo Horizonte", "Grupo Vértice", "Tríade Capital", "Sete Estrelas Partners", "Rede Andina de Investimentos", "Consórcio Pacífico"],
}
const INVESTOR_MIX := {
	"ENG": {"us": 0.45, "gulf": 0.25, "multi": 0.3}, "FRA": {"gulf": 0.3, "us": 0.35, "multi": 0.35},
	"ITA": {"us": 0.6, "multi": 0.4}, "ESP": {"us": 0.4, "multi": 0.6}, "POR": {"multi": 0.6, "us": 0.4},
	"BEL": {"multi": 0.7, "us": 0.3}, "SCO": {"us": 0.7, "multi": 0.3}, "BRA": {"latam": 0.55, "us": 0.35, "multi": 0.1},
	"USA": {"us": 1.0},
}
const SPONSORS := ["Nexa Tech", "Vortex Bet", "Aurum Bank", "Vela Airways", "Solaris Energia", "Orbit Telecom",
	"Pampa Bank", "Kestrel Motors", "Bravo Apostas", "Horizon Air", "Nova Seguros", "Quasar Mobile"]
## Portões fechados por temporada (briga, rojões, invasão) por país.
const CLOSED_P := {"BRA": 0.12, "ARG": 0.16, "TUR": 0.14, "GRE": 0.12, "SRB": 0.12, "CRO": 0.08, "ITA": 0.05,
	"MEX": 0.05, "COL": 0.08, "CHI": 0.07, "PER": 0.06, "POL": 0.06, "RUS": 0.06, "UKR": 0.05}
## Salário atrasado quando o caixa está no vermelho: bem mais comum nesses países.
const LATE_WAGES_P := {"BRA": 0.3, "ARG": 0.3, "TUR": 0.3, "GRE": 0.3, "SRB": 0.25, "ROU": 0.25, "BUL": 0.25,
	"COL": 0.2, "PER": 0.2, "CHI": 0.15, "ECU": 0.2, "MEX": 0.1}
## Onde investidor estrangeiro compra clube com frequência.
const TAKEOVER_P := {"ENG": 0.03, "FRA": 0.018, "ITA": 0.018, "ESP": 0.01, "POR": 0.015, "BEL": 0.015, "SCO": 0.012,
	"USA": 0.01, "NED": 0.008, "GER": 0.002, "TUR": 0.006}


static func banned(world: GameWorld, c: Club) -> bool:
	return c != null and int(c.affairs.get("ban", 0)) > world.year


## Portões fechados no próximo jogo em casa: consome um jogo da punição.
static func take_closed(c: Club) -> bool:
	var n := int(c.affairs.get("closed", 0))
	if n <= 0:
		return false
	c.affairs["closed"] = n - 1
	return true


## Chamado uma vez por data (depois dos jogos).
static func after_matchday(world: GameWorld, slot: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.year, slot, "clubes"])
	var first_day := slot <= 1
	TransferManager.ai_precontracts(world)
	var PER_SEASON := maxf(20.0, float(world.season.calendar.size()))
	for c: Club in world.clubs:
		if c.league_id == "" or world.league(c.league_id) == null:
			continue
		var league := world.league(c.league_id)
		var user := world.is_user_club(c.id)
		var rev := maxf(1.0, float(c.income_tv + c.income_sponsor))
		var broke := c.balance < 0 and c.debt > 0
		# PSR: prejuízo grande na Premier League custa pontos
		if c.nation == "ENG" and league.tier == 1 and c.balance < -int(rev * 0.35) and not c.affairs.has("psr_%d" % world.year) and rng.randf() < 0.3 / PER_SEASON:
			c.affairs["psr_%d" % world.year] = true
			var n := rng.randi_range(4, 8)
			_deduct(world, c, league, n)
			_news(world, c, "%s perde %d pontos por violar as regras financeiras" % [c.short_name, n],
				"A comissão independente puniu o %s pelo prejuízo acima do limite nas últimas três temporadas. O clube vai recorrer." % c.short_name, user, true, "financas")
			continue
		# Escândalo (manipulação, contabilidade): raríssimo, pesado
		if not user and league.tier == 1 and c.nation in ["ITA", "TUR", "GRE", "BRA", "POR", "ESP", "FRA", "RUS", "ARG"] and rng.randf() < 0.003 / PER_SEASON:
			var n2 := 15 if c.nation == "ITA" else 10
			_deduct(world, c, league, n2)
			c.board_confidence = maxf(10.0, c.board_confidence - 25.0)
			c.fan_mood = maxf(5.0, c.fan_mood - 20.0)
			_news(world, c, "Escândalo: %s punido com a perda de %d pontos" % [c.short_name, n2],
				"A justiça desportiva concluiu a investigação sobre as contas do %s. Dirigentes foram suspensos e o clube perde %d pontos na tabela." % [c.short_name, n2], user, true, "financas")
			continue
		# Transfer ban da FIFA por dívida com outro clube
		if broke and not banned(world, c) and rng.randf() < 0.05 / PER_SEASON:
			c.affairs["ban"] = world.year + 1
			_news(world, c, "FIFA proíbe o %s de registrar reforços" % c.short_name,
				"Por uma dívida não paga na compra de um jogador, o %s está proibido de inscrever reforços até o fim da temporada." % c.short_name, user, true, "financas")
			continue
		# Portões fechados
		var cp := float(CLOSED_P.get(c.nation, 0.01))
		if int(c.affairs.get("closed", 0)) == 0 and rng.randf() < cp / PER_SEASON:
			var games := 1 if rng.randf() < 0.7 else 2
			c.affairs["closed"] = games
			var why: String = ["briga entre torcedores na arquibancada", "rojões arremessados no gramado", "invasão de campo no último jogo", "cânticos discriminatórios"][rng.randi_range(0, 3)]
			_news(world, c, "%s jogará com portões fechados" % c.short_name,
				"Pela %s, o %s cumpre %s sem torcida em casa." % [why, c.short_name, "um jogo" if games == 1 else "dois jogos"], user, false, "torcida")
			continue
		# Salários atrasados
		if broke and rng.randf() < float(LATE_WAGES_P.get(c.nation, 0.05)) / PER_SEASON:
			for pid in c.player_ids:
				var p := world.player(int(pid))
				if p != null:
					p.morale = clampf(p.morale - 6.0, 0.0, 100.0)
			c.board_confidence = maxf(5.0, c.board_confidence - 4.0)
			_news(world, c, "Salários atrasados no %s" % c.short_name,
				"Jogadores do %s estão com dois meses de salário atrasado. O elenco cobrou a diretoria e o clamor da torcida aumenta." % c.short_name, user, user, "financas")
			continue
		# Patrocinador master
		if rng.randf() < 0.04 / PER_SEASON:
			var sp: String = SPONSORS[rng.randi_range(0, SPONSORS.size() - 1)]
			if rng.randf() < 0.6:
				var gain := int(c.income_sponsor * rng.randf_range(0.12, 0.3))
				c.income_sponsor += gain
				c.add_ledger("patrocinio", gain / 2)
				_news(world, c, "%s fecha com a %s" % [c.short_name, sp], "Novo patrocinador master: a %s passa a estampar a camisa do %s por %s por temporada." % [sp, c.short_name, Fmt.money(gain * 2)], user, false, "financas")
			else:
				var loss := int(c.income_sponsor * rng.randf_range(0.15, 0.3))
				c.income_sponsor = maxi(0, c.income_sponsor - loss)
				_news(world, c, "%s perde o patrocinador master" % c.short_name, "A %s encerrou o contrato com o %s. A diretoria corre atrás de um substituto." % [sp, c.short_name], user, user, "financas")


## Chance relativa (0..1) de um clube desse país ser comprado (Inglaterra = 1).
static func takeover_appeal(c: Club) -> float:
	if c.nation == "BRA":
		return 1.0 # a onda das SAFs
	return clampf(float(TAKEOVER_P.get(c.nation, 0.004)) / 0.03, 0.08, 1.0)


## Comprador plausível para o clube: fundos do Golfo e americanos na Inglaterra, grupos locais,
## americanos e empresários nas SAFs brasileiras, multiclubes pela Europa.
static func investor_for(c: Club, rng: RandomNumberGenerator) -> String:
	var mix: Dictionary = INVESTOR_MIX.get(c.nation, {"latam": 0.5, "multi": 0.5} if c.nation in ["ARG", "URU", "CHI", "COL", "PAR", "PER", "ECU", "MEX"] else {"multi": 0.6, "us": 0.4})
	var group := String(RngUtil.weighted_key(rng, mix))
	var pool: Array = INVESTORS[group]
	if group == "latam" and rng.randf() < 0.35:
		var o := NameGenerator.pick_origin(rng, c.nation)
		var nm := NameGenerator.generate(rng, String(o["c"]), {}, {})
		return "o empresário %s %s" % [nm["first"], nm["last"]]
	return pool[rng.randi_range(0, pool.size() - 1)]


## Punição da liga na recuperação judicial/administração: pontos na Inglaterra e na Itália
## e transfer ban em todo lugar. Retorna os pontos tirados.
static func insolvency_penalty(world: GameWorld, c: Club) -> int:
	c.affairs["ban"] = world.year + 1
	var league := world.league(c.league_id)
	var pts := 0
	match c.nation:
		"ENG", "SCO", "WAL":
			pts = 12 if league != null and league.tier >= 2 else 9
		"ITA":
			pts = 8
	if pts > 0 and league != null:
		_deduct(world, c, league, pts)
	return pts


static func _deduct(world: GameWorld, c: Club, league: League, n: int) -> void:
	if not league.table.has(c.id):
		return
	var row: Dictionary = league.table[c.id]
	row["pts"] = int(row["pts"]) - n
	row["ded"] = int(row.get("ded", 0)) + n


static func _news(world: GameWorld, c: Club, title: String, body: String, user: bool, big: bool, cat: String) -> void:
	var near := user or world.is_user_club(c.id) or (world.has_user() and c.league_id == world.user_league_id())
	if not near and not big:
		return # o mundo não precisa saber de toda briga de torcida em outra liga
	var imp := NewsEvent.IMP_HIGH if (user or (big and near)) else NewsEvent.IMP_NORMAL
	NewsManager.post_raw(world, title, body, c.id, -1, imp, cat)
	if user:
		InboxManager.send(world, "diretoria", title, body)
