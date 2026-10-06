class_name Aftermath
extends RefCounted
## Marcas que ficam. Um título, uma final perdida para o rival, um rebaixamento ou o fim de um
## jejum não acabam na manchete do dia seguinte: a torcida carrega o momento por meses (o clima
## volta devagar para um patamar que a marca puxa para cima ou para baixo, e com ele público,
## camisas e paciência), o vestiário sente, a diretoria cobra o técnico na virada do ano, o
## presidente abre o cofre para dar a resposta, o rebaixado perde as estrelas para quem pode
## pagar e a imprensa volta ao assunto semanas e um ano depois.
##
## Estado em world.stats (vai no save; saves antigos começam sem marcas):
##   af     {"<club_id>": [[tipo, ano, data, semana, peso, outro clube, acompanhada]]}
##   af_wk  contador de semanas jogadas (as marcas esfriam por semana de temporada, não nas férias)
##   af_lt  {"<club_id>": ano do último título da liga principal} (refeito na virada do ano)

## Tipos: humor (quanto a marca puxa o clima da torcida, por peso 1), meia-vida em semanas, e se
## dói (as que doem pesam na diretoria, no vestiário e no mercado).
const KINDS := {
	"titulo": {"mood": 16.0, "hl": 22.0, "pain": false},
	"jejum": {"mood": 24.0, "hl": 34.0, "pain": false},
	"copa": {"mood": 10.0, "hl": 12.0, "pain": false},
	"acesso": {"mood": 12.0, "hl": 16.0, "pain": false},
	"vice": {"mood": -15.0, "hl": 18.0, "pain": true},
	"final": {"mood": -13.0, "hl": 13.0, "pain": true},
	"eliminado": {"mood": -9.0, "hl": 8.0, "pain": true},
	"queda": {"mood": -18.0, "hl": 22.0, "pain": true},
	"rival_campeao": {"mood": -8.0, "hl": 14.0, "pain": true},
	"goleada": {"mood": -8.0, "hl": 5.0, "pain": true},
}
const MAX_PER_CLUB := 8
const FORGET_BELOW := 0.06
## Jejum: só pesa em clube grande que já foi campeão, a partir de tantos anos.
const DROUGHT_FROM := 6
const DROUGHT_NEWS := [10, 15, 20, 25, 30, 35, 40, 50]

const I_K := 0
const I_Y := 1
const I_D := 2
const I_WK := 3
const I_W := 4
const I_O := 5
const I_F := 6


static func _all(world: GameWorld) -> Dictionary:
	if not world.stats.has("af"):
		world.stats["af"] = {}
	return world.stats["af"]


static func marks_of(world: GameWorld, cid: int) -> Array:
	return _all(world).get(str(cid), [])


static func week(world: GameWorld) -> int:
	return int(world.stats.get("af_wk", 0))


static func _rng(world: GameWorld, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = RngUtil.hash_i(world.world_seed, world.year * 977 + week(world) * 31 + salt, 4421)
	return r


## Força atual da marca (peso × esfriamento pela meia-vida).
static func strength(world: GameWorld, m: Array) -> float:
	var hl := float(KINDS.get(String(m[I_K]), {}).get("hl", 12.0))
	var age := maxi(0, week(world) - int(m[I_WK]))
	return float(m[I_W]) * pow(0.5, float(age) / hl)


## Registra uma marca. `kick` aplica já o choque no clima (no mata-mata o jogo já aplicou).
static func add(world: GameWorld, cid: int, kind: String, w: float, other: int = -1, kick: bool = true) -> void:
	var c := world.club(cid)
	if c == null or not KINDS.has(kind) or w <= 0.0:
		return
	var all := _all(world)
	var arr: Array = all.get(str(cid), [])
	# A mesma marca contra o mesmo clube na mesma temporada não se repete: fica a mais forte.
	for m: Array in arr:
		if String(m[I_K]) == kind and int(m[I_Y]) == world.year and int(m[I_O]) == other:
			m[I_W] = maxf(float(m[I_W]), w)
			return
	arr.append([kind, world.year, world.current_day(), week(world), snappedf(clampf(w, 0.05, 1.6), 0.01), other, 0])
	if arr.size() > MAX_PER_CLUB:
		arr.sort_custom(func(a, b): return strength(world, a) > strength(world, b))
		arr.resize(MAX_PER_CLUB)
	all[str(cid)] = arr
	if kick:
		var mood := float(KINDS[kind]["mood"]) * w * 0.6
		c.fan_mood = clampf(c.fan_mood + mood, 0.0, 100.0)
		if world.is_user_club(cid):
			People.add_support(world, mood * 0.35)


## Patamar para onde o clima da torcida volta, semana a semana (60 sem marcas). As marcas e o jejum
## de clube grande puxam o patamar; o clima chega lá devagar, então uma final perdida pesa meses.
static func mood_target(world: GameWorld, c: Club) -> float:
	var t := 60.0
	for m: Array in marks_of(world, c.id):
		t += float(KINDS.get(String(m[I_K]), {}).get("mood", 0.0)) * strength(world, m)
	t -= drought_pressure(world, c)
	return clampf(t, 22.0, 90.0)


## Quanto o jejum de liga pesa (0..10): clube grande que já foi campeão e está há anos na fila.
static func drought_pressure(world: GameWorld, c: Club) -> float:
	var yrs := drought_years(world, c)
	if yrs < DROUGHT_FROM or c.tier != 1:
		return 0.0
	var size := clampf((c.reputation - 55.0) / 30.0, 0.0, 1.0)
	return minf(10.0, float(yrs - DROUGHT_FROM + 1) * 0.7) * size


## Anos desde o último título da liga principal do país (-1 = nunca venceu).
static func drought_years(world: GameWorld, c: Club) -> int:
	var lt := last_title(world, c.id)
	return world.year - lt if lt > 0 else -1


static func last_title(world: GameWorld, cid: int) -> int:
	if not world.stats.has("af_lt"):
		_rebuild_last_titles(world)
	return int(world.stats["af_lt"].get(str(cid), 0))


## Último título da liga principal de cada clube, lendo a história do save (e o passado real).
static func _rebuild_last_titles(world: GameWorld) -> void:
	var lt := {}
	for e in world.history:
		var h: Dictionary = e
		var y := int(h.get("y", 0))
		var lgs: Dictionary = h.get("leagues", {})
		for lid in lgs:
			if int(DatabaseManager.league_cfg(String(lid)).get("tier", 9)) != 1:
				continue
			var ch := int((lgs[lid] as Dictionary).get("champion", -1))
			if ch >= 0 and y > int(lt.get(str(ch), 0)):
				lt[str(ch)] = y
	world.stats["af_lt"] = lt


# ---------------------------------------------------------------------------
# Durante a temporada
# ---------------------------------------------------------------------------

## Depois de cada jogo de clube: mata-mata decidido (final, eliminação para o rival) e goleada em clássico.
static func on_match(world: GameWorld, f: Fixture, stakes: Dictionary, derby: bool) -> void:
	if not stakes.is_empty():
		var wid := int(stakes["w"])
		var lid := int(stakes["l"])
		var sig := _comp_weight(world, f, lid)
		var wgt := float(stakes["weight"])
		if bool(stakes.get("title", false)):
			add(world, lid, "final", clampf(sig * (1.35 if derby else 1.0), 0.3, 1.5), wid, false)
			add(world, wid, "copa", clampf(_comp_weight(world, f, wid) * (1.3 if derby else 1.0), 0.3, 1.4), lid, false)
		elif bool(stakes.get("access", false)):
			add(world, wid, "acesso", 0.7 * wgt, lid, false)
		elif derby or (wgt >= 0.55 and sig >= 0.9):
			add(world, lid, "eliminado", clampf(wgt * sig * (1.6 if derby else 1.0), 0.2, 1.1), wid, false)
		return
	if not derby:
		return
	var diff := f.hg - f.ag
	if absi(diff) >= 4:
		var loser := f.away if diff > 0 else f.home
		add(world, loser, "goleada", 0.5 + 0.15 * (absi(diff) - 4), f.home if diff < 0 else f.away, false)


## Peso da competição para o clube: decisão continental pesa mais que estadual.
static func _comp_weight(world: GameWorld, f: Fixture, cid: int) -> float:
	var c := world.club(cid)
	var top := Reputation.top_league_of(c.nation) if c != null else ""
	var base := Reputation.league_rep(top) if top != "" else 50.0
	var rep := base
	if world.season.cups.has(f.comp):
		rep = Reputation.cup_rep(f.comp)
	elif world.league(f.comp) != null:
		rep = Reputation.league_rep(f.comp)
	return clampf(rep / maxf(30.0, base), 0.45, 1.3)


## Uma vez por semana de temporada: o clima volta para o patamar da marca, o vestiário sente e a
## imprensa volta ao assunto.
static func weekly(world: GameWorld) -> void:
	world.stats["af_wk"] = week(world) + 1
	var all := _all(world)
	for key in all.keys():
		var arr: Array = all[key]
		var c := world.club(int(key))
		if c == null:
			all.erase(key)
			continue
		var live: Array = []
		for m: Array in arr:
			if strength(world, m) >= FORGET_BELOW or (int(m[I_F]) < 2 and world.year - int(m[I_Y]) <= 1 and float(m[I_W]) >= 0.8):
				live.append(m)
		if live.is_empty():
			all.erase(key)
			continue
		all[key] = live
		_dressing_room(world, c, live)
		_follow_ups(world, c, live)


## Moral do elenco: a marca fresca pesa nos jogadores (quem viveu a final perdida treina pior por
## semanas; o título deixa todo mundo mais leve). Pouco por semana, mas constante.
static func _dressing_room(world: GameWorld, c: Club, live: Array) -> void:
	var push := 0.0
	for m: Array in live:
		var age := week(world) - int(m[I_WK])
		if age > 10:
			continue
		push += signf(float(KINDS[String(m[I_K])]["mood"])) * strength(world, m)
	if absf(push) < 0.1:
		return
	var d := clampf(push * 0.9, -1.2, 1.0)
	for p: Player in world.squad(c):
		if d < 0.0 and p.morale > 40.0:
			p.morale = maxf(40.0, p.morale + d * p.trait_mult("morale_volatility"))
		elif d > 0.0 and p.morale < 85.0:
			p.morale = minf(85.0, p.morale + d)


## A imprensa volta ao assunto: duas a quatro semanas depois (o clima, a resposta) e um ano depois.
static func _follow_ups(world: GameWorld, c: Club, live: Array) -> void:
	if not world.has_user():
		return
	var mine := world.is_user_club(c.id)
	if not mine and not _relevant(world, c):
		return
	for m: Array in live:
		var k := String(m[I_K])
		var age := week(world) - int(m[I_WK])
		var f := int(m[I_F])
		var o := world.club(int(m[I_O]))
		var y := int(m[I_Y])
		if f == 0 and age >= 3 and age <= 8 and float(m[I_W]) >= 0.5 and k in ["final", "vice", "queda", "jejum", "titulo", "eliminado"]:
			m[I_F] = 1
			if mine or float(m[I_W]) >= 0.8:
				_follow_story(world, c, k, o, y, mine)
		elif f <= 1 and world.year == y + 1 and world.current_day() >= int(m[I_D]) and float(m[I_W]) >= 0.8 and k in ["final", "vice", "queda", "jejum", "titulo"]:
			m[I_F] = 2
			if mine:
				_year_after(world, c, k, o, y)


static func _relevant(world: GameWorld, c: Club) -> bool:
	var u := world.user_club()
	return u.is_rival(c.id) or c.is_rival(u.id) or (c.league_id == u.league_id and c.reputation >= u.reputation - 5.0)


static func _mood_words(c: Club) -> String:
	if c.fan_mood < 30.0:
		return "a arquibancada está em pé de guerra"
	if c.fan_mood < 45.0:
		return "a torcida segue desconfiada"
	if c.fan_mood < 60.0:
		return "o ambiente melhorou, mas ninguém esqueceu"
	if c.fan_mood < 75.0:
		return "a torcida já virou a página"
	return "o clima é de festa permanente"


static func _follow_story(world: GameWorld, c: Club, k: String, o: Club, y: int, mine: bool) -> void:
	var on := o.short_name if o != null else "o adversário"
	var rival := o != null and (c.is_rival(o.id) or o.is_rival(c.id))
	var r := _rng(world, c.id)
	var title := ""
	var body := ""
	var att := _avg_attendance(world, c)
	var att_txt := (" A média de público nos últimos jogos em casa é de %s." % Fmt.thousands(att)) if att > 0 else ""
	match k:
		"final":
			title = "A final contra o %s ainda pesa no %s" % [on, c.short_name] if r.randf() < 0.5 else "%s: a ferida da final segue aberta" % c.short_name
			body = "Semanas depois da taça perdida%s, %s.%s" % [(" para o rival" if rival else ""), _mood_words(c), att_txt]
			if mine:
				body += " No vestiário, quem estava em campo ainda fala da decisão."
		"vice":
			title = "O vice que não sai da cabeça do %s" % c.short_name
			body = "O título ficou com o %s e, %s.%s" % [on, _mood_words(c), att_txt]
			if rival:
				body += " A provocação do rival virou rotina nas redes."
		"queda":
			title = "%s tenta se reerguer depois da queda" % c.short_name
			body = "O rebaixamento mudou o clube: a receita caiu, parte do elenco quer sair e %s.%s" % [_mood_words(c), att_txt]
		"jejum", "titulo":
			title = "O %s ainda vive o título" % c.short_name if k == "titulo" else "Fim da fila: o %s ainda celebra" % c.short_name
			body = "A camisa de campeão esgotou nas lojas do clube e %s.%s" % [_mood_words(c), att_txt]
		"eliminado":
			title = "A eliminação para o %s ainda repercute no %s" % [on, c.short_name]
			body = "A queda %s deixou marcas: %s.%s" % [("diante do rival" if rival else "no mata-mata"), _mood_words(c), att_txt]
	if title == "":
		return
	NewsManager.post_raw(world, title, body, c.id, -1, NewsEvent.IMP_NORMAL if mine else NewsEvent.IMP_LOW, "clube")


static func _year_after(world: GameWorld, c: Club, k: String, o: Club, y: int) -> void:
	var on := o.short_name if o != null else "o adversário"
	var title := ""
	var body := ""
	match k:
		"final":
			title = "Um ano depois da final perdida para o %s" % on
			body = "Em %d, o %s viu a taça escapar. A data foi lembrada pela torcida, que ainda cobra a revanche." % [y, c.short_name]
		"vice":
			title = "Um ano depois, o vice para o %s ainda é lembrado" % on
			body = "A temporada de %d terminou com o título nas mãos do %s. No clube, a lembrança virou cobrança." % [y, on]
		"queda":
			title = "Um ano depois do rebaixamento"
			body = "Em %d o %s caiu de divisão. A data volta como lembrete do que o clube não quer repetir." % [y, c.short_name]
		"jejum", "titulo":
			title = "Um ano do título de %d" % y
			body = "A torcida do %s relembrou a campanha campeã nas redes e o clube preparou homenagem ao elenco." % c.short_name
	if title != "":
		NewsManager.post_raw(world, title, body, c.id, -1, NewsEvent.IMP_NORMAL, "aniversario")


## Média de público dos últimos jogos em casa da temporada (0 se ainda não há).
static func _avg_attendance(world: GameWorld, c: Club) -> int:
	if world.season == null:
		return 0
	var lg := world.league_of(c.id)
	if lg == null:
		return 0
	var tot := 0
	var n := 0
	for i in range(lg.rounds.size() - 1, -1, -1):
		for f: Fixture in lg.rounds[i]:
			if f.played and f.home == c.id and f.attendance > 0:
				tot += f.attendance
				n += 1
		if n >= 3:
			break
	return tot / n if n > 0 else 0


# ---------------------------------------------------------------------------
# Virada do ano
# ---------------------------------------------------------------------------

## Fim de uma liga: título (e fim de jejum), vice doído, rival campeão, rebaixamento e acesso.
static func on_league_end(world: GameWorld, league: League, ids: Array, champ: Club, runner: int, promoted: Array, relegated: Array) -> void:
	var top := league.tier == 1
	var w_league := clampf(Reputation.league_rep(league.id) / maxf(30.0, Reputation.league_rep(Reputation.top_league_of(league.nation))), 0.4, 1.0)
	if top:
		var lt := last_title(world, champ.id)
		var first := champ.title_count("L:" + league.id) == 0
		var yrs := world.year - lt if lt > 0 else 0
		if first or yrs >= 8:
			add(world, champ.id, "jejum", clampf(0.9 + (0.5 if first else minf(0.5, float(yrs) / 40.0)), 0.9, 1.4), runner)
			_drought_broken(world, champ, league, yrs, first)
		else:
			add(world, champ.id, "titulo", 1.0, runner)
		world.stats["af_lt"][str(champ.id)] = world.year
		# Vice: dói mais quando o título fica com o rival ou escapa por pouco.
		var rc := world.club(runner)
		if rc != null and league.table.has(runner) and league.table.has(champ.id):
			var gap := int(league.table[champ.id]["pts"]) - int(league.table[runner]["pts"])
			var rival := rc.is_rival(champ.id) or champ.is_rival(runner)
			var w := 0.45 + (0.45 if rival else 0.0) + (0.25 if gap <= 1 else (0.12 if gap <= 3 else 0.0))
			if rival or gap <= 3:
				add(world, runner, "vice", w, champ.id)
		# A torcida rival sente o título do outro (o vice já carrega isso).
		for c: Club in _rivals_of(world, champ):
			if c.id != runner:
				add(world, c.id, "rival_campeao", 0.6, champ.id)
	else:
		add(world, champ.id, "titulo", 0.55 * w_league, runner)
	for cid in promoted:
		add(world, int(cid), "acesso", 0.8 if world.club(int(cid)).tier == 2 else 0.6)
	for cid in relegated:
		var c := world.club(int(cid))
		add(world, c.id, "queda", 1.0 if c.tier == 1 else 0.75)


static func _rivals_of(world: GameWorld, c: Club) -> Array:
	var out: Array = []
	for rid in c.rivals:
		var o := world.club(int(rid))
		if o != null and o.nation == c.nation:
			out.append(o)
	return out


static func _drought_broken(world: GameWorld, c: Club, league: League, yrs: int, first: bool) -> void:
	if not world.has_user():
		return
	var mine := world.is_user_club(c.id)
	if not mine and not _relevant(world, c) and not (c.nation == world.user_nation() and c.reputation >= 60.0):
		return
	var title := ""
	var body := ""
	if first:
		title = "%s é campeão pela primeira vez na história" % c.short_name
		body = "Fundado em %d, o %s nunca tinha vencido %s. A cidade de %s parou para receber o time." % [c.founded, c.name, league.name, c.city]
	else:
		title = "Fim da fila: %s volta a ser campeão depois de %d anos" % [c.short_name, yrs]
		body = "O último título do %s na liga tinha sido em %d. Foram %d temporadas de espera, e a festa tomou conta de %s." % [c.name, world.year - yrs, yrs, c.city]
	var n := NewsManager.post_raw(world, title, body, c.id, -1, NewsEvent.IMP_HEADLINE if mine else NewsEvent.IMP_HIGH, "campeao")
	n.media = {"type": "crest", "club": c.id, "trophy": true, "rc": league.name, "rv": ("1º título" if first else "%d anos" % yrs), "rx": str(world.year)}


## Quanto a temporada doeu para a diretoria (0..4, em "posições abaixo da meta"): perder o título
## para o rival, a final, o jejum que se arrasta. Entra na decisão de manter o técnico.
static func sting(world: GameWorld, c: Club) -> Dictionary:
	var v := 0.0
	var why := ""
	var best := 0.0
	for m: Array in marks_of(world, c.id):
		if int(m[I_Y]) != world.year or not bool(KINDS[String(m[I_K])]["pain"]):
			continue
		var k := String(m[I_K])
		var s: float = float(m[I_W]) * {"vice": 2.6, "final": 2.0, "eliminado": 1.2, "rival_campeao": 0.8, "goleada": 0.6, "queda": 0.0}.get(k, 0.0)
		v += s
		if s > best:
			best = s
			var o := world.club(int(m[I_O]))
			var on := o.short_name if o != null else ""
			why = {"vice": "perder o título para o %s" % on, "final": "perder a final para o %s" % on, "eliminado": "a eliminação diante do %s" % on,
				"rival_campeao": "ver o %s campeão" % on, "goleada": "a goleada no clássico"}.get(k, "")
	var dp := drought_pressure(world, c)
	if dp >= 4.0 and last_title(world, c.id) != world.year:
		v += dp * 0.12
		if why == "":
			why = "mais um ano sem título"
	return {"v": clampf(v, 0.0, 4.0), "why": why}


## Começo da temporada nova (orçamentos já definidos, antes do mercado das férias): presidente que
## quer resposta abre o cofre, o jejum vira assunto e o técnico do usuário ouve a cobrança.
static func season_open(world: GameWorld) -> void:
	_rebuild_last_titles(world)
	var r := _rng(world, 77)
	for c: Club in world.clubs:
		var ps := 0.0
		var hurt: Array = []
		for m: Array in marks_of(world, c.id):
			if int(m[I_Y]) == world.year - 1 and String(m[I_K]) in ["vice", "final", "eliminado", "rival_campeao"]:
				ps += float(m[I_W])
				if hurt.is_empty() or float(m[I_W]) > float(hurt[I_W]):
					hurt = m
		if world.is_user_club(c.id):
			_user_pressure(world, c, hurt)
			continue
		if ps < 0.8 or FinanceManager.in_trouble(c):
			continue
		var st := String(People.pres_style(world, c.id).get("st", "paciente")) if not People.pres_style(world, c.id).is_empty() else "paciente"
		var chance: float = {"vaidoso": 0.8, "exigente": 0.7, "populista": 0.65, "empresario": 0.25, "paciente": 0.35}.get(st, 0.4) * minf(1.0, ps)
		if r.randf() >= chance:
			continue
		var boost := 1.25 + 0.2 * minf(1.0, ps - 0.8)
		c.transfer_budget = int(c.transfer_budget * boost)
		var o := world.club(int(hurt[I_O])) if not hurt.is_empty() else null
		if world.has_user() and _relevant(world, c) and o != null:
			NewsManager.post_raw(world, "%s abre o cofre depois de %s" % [c.short_name, "perder para o %s" % o.short_name],
				"O presidente do %s prometeu resposta à torcida: a verba para reforços cresceu cerca de %d%% para a temporada." % [c.short_name, int(round((boost - 1.0) * 100.0))],
				c.id, -1, NewsEvent.IMP_NORMAL, "mercado")
	_drought_news(world)


static func _user_pressure(world: GameWorld, c: Club, hurt: Array) -> void:
	if hurt.is_empty() or float(hurt[I_W]) < 0.7:
		return
	var o := world.club(int(hurt[I_O]))
	if o == null:
		return
	var what: String = String({"vice": "o título que ficou com o %s", "final": "a final perdida para o %s", "eliminado": "a eliminação diante do %s", "rival_campeao": "a festa do %s"}.get(String(hurt[I_K]), "%s")) % o.short_name
	var pres := People.president(world, c.id)
	var pn := String(pres.get("n", "O presidente"))
	NewsManager.post_raw(world, "%s cobra resposta: \"Ninguém aqui esqueceu\"" % pn,
		"Na apresentação da temporada, o presidente do %s lembrou %s e disse que espera ver o time reagir. A torcida deve lotar a estreia." % [c.short_name, what],
		c.id, -1, NewsEvent.IMP_HIGH, "clube")


## Jejum que chega a uma marca redonda vira assunto (o do usuário, rivais e grandes do país).
static func _drought_news(world: GameWorld) -> void:
	if not world.has_user():
		return
	var u := world.user_club()
	var shown := 0
	for c: Club in world.clubs:
		if c.tier != 1 or c.nation != u.nation:
			continue
		var yrs := drought_years(world, c)
		if not DROUGHT_NEWS.has(yrs) or c.reputation < 58.0:
			continue
		var mine := world.is_user_club(c.id)
		if not mine and not (u.is_rival(c.id) or c.reputation >= 70.0):
			continue
		if not mine and shown >= 2:
			continue
		shown += 0 if mine else 1
		NewsManager.post_raw(world, "%s chega a %d anos sem título" % [c.short_name, yrs],
			"O último título do %s na liga foi em %d. A cada temporada a cobrança cresce, e a fila já virou tema de provocação dos rivais." % [c.name, world.year - yrs],
			c.id, -1, NewsEvent.IMP_HIGH if mine else NewsEvent.IMP_LOW, "clube")


# ---------------------------------------------------------------------------
# Mercado
# ---------------------------------------------------------------------------

## Rebaixado no ano que passou (o clube que acabou de cair desmancha o time).
static func fresh_relegated(world: GameWorld, c: Club) -> bool:
	if c == null:
		return false
	for m: Array in marks_of(world, c.id):
		if String(m[I_K]) == "queda" and world.year - int(m[I_Y]) <= 1 and strength(world, m) >= 0.35:
			return true
	return false


## Multiplicador do pedido do vendedor: o recém-rebaixado não segura quem está acima do nível.
static func sell_mult(world: GameWorld, seller: Club, p: Player) -> float:
	if not fresh_relegated(world, seller):
		return 1.0
	return 0.78 if p.ovr_f >= PlayerGenerator.club_level(seller) + 2.0 else 0.95


## Vontade a mais de sair: o jogador acima do nível de um rebaixado quer ir embora; o campeão atrai.
static func exit_pull(world: GameWorld, p: Player, buyer: Club) -> float:
	var v := 0.0
	var own := world.club(p.club_id) if p.club_id >= 0 else null
	if own != null and fresh_relegated(world, own) and p.ovr_f >= PlayerGenerator.club_level(own) + 2.0:
		v += 0.2
	for m: Array in marks_of(world, buyer.id):
		if String(m[I_K]) in ["titulo", "jejum"] and world.year - int(m[I_Y]) <= 1:
			v += 0.06
			break
	return v
