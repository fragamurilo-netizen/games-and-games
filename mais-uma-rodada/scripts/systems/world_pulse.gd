class_name WorldPulse
extends RefCounted
## Pulso do mundo: o que acontece com os outros clubes e jogadores entre uma rodada e outra.
## Renovações e impasses, atritos no vestiário, protestos, diretorias que abrem o cofre, projetos
## de estádio, posts dos jogadores, marcas de carreira, joias que aparecem, rumores que se
## confirmam (ou não) semanas depois, jogos de despedida, aniversários de títulos, a corrida pelo
## título e a luta contra a queda, prévias de clássico e o giro semanal pelas grandes ligas.
##
## Custo baixo por semana: sorteia poucos clubes e só olha o elenco deles; nada percorre todos os
## jogadores do mundo nem abre históricos compactados.
##
## Estado em world.stats (vai no save; tudo opcional, saves antigos começam vazios):
##   wp_wk   contador de semanas             wp_rum  rumores abertos [{id, p, f, to, w, due}]
##   wp_rid  próximo id de rumor              wp_fw   despedidas marcadas [{n, c, a, g, t, p, w}]
##   wp_tr   {liga:tipo → rodada da última narrativa}   wp_dp  {liga → rodada da última prévia}
##   wp_gr   {liga → [ano, marca de gols]}  wp_ub  {clube → marca de invencibilidade}
##   wp_ms   {jogador → marca de jogos/gols} wp_joia {jogador → ano}  wp_ann ano dos aniversários
##   wp_ru   soma das rodadas do último giro
## Nos clubes: affairs["proj"] = [ano de entrega, lugares, custo], affairs["inv"] = ano do aporte.

## Países com portal próprio na tela de notícias: a primeira divisão deles também tem vida.
const PORTAL_NATIONS := ["BRA", "ENG", "ESP", "ITA", "GER", "FRA", "POR", "ARG", "NED", "USA", "MEX", "KSA"]
const RUMOR_MAX := 10
const ANNIV := [50, 40, 30, 25, 20, 15, 10, 5]
## Status do rumor guardado na mídia da notícia ("rs").
const RS_OPEN := 0
const RS_TRUE := 1
const RS_FALSE := 2


# ---------------------------------------------------------------------------
# Semana a semana
# ---------------------------------------------------------------------------

static func weekly(world: GameWorld) -> void:
	if not world.has_user() or world.season == null:
		return
	var wk := int(world.stats.get("wp_wk", 0)) + 1
	world.stats["wp_wk"] = wk
	var rng := world.rng
	_resolve_rumors(world, wk)
	_farewells(world, wk)
	var pool := _pool(world)
	if pool.is_empty():
		return
	var want := rng.randi_range(2, 4)
	var done := 0
	var tries := 0
	while done < want and tries < want * 3:
		tries += 1
		if _club_story(world, _pick_club(pool, rng), rng, wk):
			done += 1
	var ahead := world.next_window_day() - world.current_day()
	var hot := world.transfer_window_open() or (ahead >= 1 and ahead <= 3)
	if rng.randf() < (0.75 if hot else 0.35):
		_new_rumor(world, pool, rng, wk)
	_records(world)
	_roundup(world)
	_anniversaries(world)


## Clubes com vida própria: 1ª e 2ª divisão do país do usuário e a elite dos países com portal.
static func _pool(world: GameWorld) -> Array:
	var out: Array = []
	var un := world.user_nation()
	for c: Club in world.clubs:
		if world.is_user_club(c.id) or c.player_ids.is_empty():
			continue
		if (c.nation == un and c.tier <= 2) or (c.tier == 1 and PORTAL_NATIONS.has(c.nation)):
			out.append(c)
	return out


## Sorteio que puxa para os clubes maiores (rendem mais assunto), sem esquecer os pequenos.
static func _pick_club(pool: Array, rng: RandomNumberGenerator) -> Club:
	var a: Club = RngUtil.pick(rng, pool)
	var b: Club = RngUtil.pick(rng, pool)
	if rng.randf() < 0.65:
		return a if a.reputation >= b.reputation else b
	return a


static func _club_story(world: GameWorld, c: Club, rng: RandomNumberGenerator, wk: int) -> bool:
	var kinds := ["renew", "fallout", "protest", "invest", "stadium", "social", "milestone", "joia"]
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: String = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = t
	for k: String in kinds:
		var ok := false
		match k:
			"renew":
				ok = _renew(world, c, rng, wk)
			"fallout":
				ok = _fallout(world, c, rng)
			"protest":
				ok = _protest(world, c, rng)
			"invest":
				ok = _invest(world, c, rng)
			"stadium":
				ok = _stadium(world, c, rng)
			"social":
				ok = _social(world, c, rng)
			"milestone":
				ok = _milestone(world, c)
			"joia":
				ok = _joia(world, c, rng)
		if ok:
			return true
	return false


static func _imp(world: GameWorld, c: Club) -> int:
	if world.has_user() and (c.league_id == world.user_league_id() or world.user_club().is_rival(c.id)):
		return NewsEvent.IMP_NORMAL
	return NewsEvent.IMP_LOW if c.reputation < 70.0 else NewsEvent.IMP_NORMAL


static func _outlet(world: GameWorld, c: Club, salt: int) -> String:
	var pool: Array = Array(People.OUTLETS_PT) if People._lang(c.nation) == "pt" else Array(People.OUTLETS_INT)
	return String(pool[absi(salt) % pool.size()])


static func _pos(world: GameWorld, c: Club) -> int:
	var lg := world.league(c.league_id)
	if lg == null or lg.rounds_played() < 3:
		return 0
	return CompetitionManager.sorted_ids(lg).find(c.id) + 1


static func _season_stats(p: Player) -> Array:
	var t := p.season_totals()
	return [int(t[0]), int(t[1]), int(t[2]), int(round(p.avg_rating() * 10.0))]


# ---------------------------------------------------------------------------
# Histórias de clube
# ---------------------------------------------------------------------------

## Renovação do titular com contrato no fim, ou o impasse que abre a porta para o mercado.
static func _renew(world: GameWorld, c: Club, rng: RandomNumberGenerator, wk: int) -> bool:
	var best: Player = null
	for p: Player in world.squad(c):
		if p.contract_end <= world.year + 1 and p.age(world.year) <= 32 and p.squad_status <= Player.STATUS_STARTER \
				and p.loan.is_empty() and not p.retiring:
			if best == null or p.overall > best.overall:
				best = p
	if best == null:
		return false
	var p := best
	var age := p.age(world.year)
	if rng.randf() < 0.65 and p.morale >= 40.0:
		var old := p.wage
		var years := rng.randi_range(2, 4) if age <= 29 else rng.randi_range(1, 2)
		var wage := Valuation.round_wage(maxf(float(old) * rng.randf_range(1.1, 1.45), float(old) + 500.0))
		TransferManager.apply_renewal(world, p, wage, years)
		var title: String = RngUtil.pick(rng, ["%s renova com o %s até %d", "%s assina renovação e fica no %s até %d", "Acertado: %s segue no %s até %d"]) % [p.display_name(), c.short_name, p.contract_end]
		var body := "Depois de semanas de conversa, %s (%d anos) estendeu o vínculo com o %s. O salário sobe de %s para %s." % [
			p.display_name(), age, c.short_name, Fmt.money_month(old), Fmt.money_month(wage)]
		if p.squad_status == Player.STATUS_STAR:
			body += " A diretoria tratou a renovação como prioridade: é a referência do elenco."
		var n := NewsManager.post_raw(world, title, body, c.id, p.id, _imp(world, c), "renovacao")
		n.media = {"type": "player", "player": p.id, "club": c.id, "wg": wage, "ow": old, "ce": p.contract_end}
		return true
	var suitor := MarketAI.realistic_suitor(world, p, c.reputation + 2.0, rng)
	p.morale = clampf(p.morale - 8.0, 0.0, 100.0)
	var body2 := "%s tem contrato só até %d e ainda não aceitou as propostas do %s. O estafe do jogador pede aumento e mais anos de vínculo." % [
		p.display_name(), p.contract_end, c.short_name]
	if suitor != null:
		body2 += " O %s acompanha a novela de perto." % suitor.short_name
	var title2: String = RngUtil.pick(rng, ["Impasse: %s trava renovação com o %s", "%s não renova e preocupa o %s", "Renovação de %s emperra no %s"]) % [p.display_name(), c.short_name]
	var n2 := NewsManager.post_raw(world, title2, body2, c.id, p.id, _imp(world, c), "impasse")
	n2.media = {"type": "player", "player": p.id, "club": c.id, "wg": p.wage, "ce": p.contract_end}
	if suitor != null:
		var rid := _register_rumor(world, p, suitor, wk, rng)
		if rid >= 0:
			n2.media["rid"] = rid
			n2.media["to"] = suitor.id
			n2.media["rs"] = RS_OPEN
	return true


## Atrito: titular insatisfeito bate de frente com o técnico (ou com um companheiro).
static func _fallout(world: GameWorld, c: Club, rng: RandomNumberGenerator) -> bool:
	if c.streak_winless < 3 and c.streak_losses < 2 and rng.randf() > 0.12:
		return false
	var cands: Array = []
	for p: Player in world.squad(c):
		if p.is_injured() or p.age(world.year) < 20:
			continue
		var hot := p.has_trait("temperamental") or p.has_trait("rebelde") or p.has_trait("estrela") or p.has_trait("provocador") or p.has_trait("vaidoso")
		if (p.squad_status <= Player.STATUS_ROTATION and p.morale < 52.0) or (hot and p.squad_status <= Player.STATUS_STARTER):
			cands.append(p)
	if cands.is_empty():
		return false
	var p: Player = RngUtil.pick(rng, cands)
	var coach := People.coach_name(world, c.id)
	p.morale = clampf(p.morale - 12.0, 0.0, 100.0)
	var listed := rng.randf() < 0.35 and p.squad_status > Player.STATUS_STAR
	if listed:
		p.transfer_listed = true
		p.asking_price = TransferManager.asking_price(world, p)
	var style := rng.randi_range(0, 2)
	var title := ""
	var body := ""
	match style:
		0:
			title = "Clima quente no %s: %s discute com %s" % [c.short_name, p.display_name(), coach]
			body = "O bate-boca aconteceu no treino desta semana e foi apartado pelos auxiliares. %s não gostou de ficar fora da atividade principal." % p.display_name()
		1:
			title = "%s deixa o campo irritado e vira problema no %s" % [p.display_name(), c.short_name]
			body = "Substituído no último jogo, %s passou direto por %s e foi para o vestiário. A diretoria vai conversar com o jogador." % [p.display_name(), coach]
		_:
			title = "Racha no vestiário do %s envolve %s" % [c.short_name, p.display_name()]
			body = "Companheiros reclamaram da postura de %s nos treinos. O ambiente pesou depois dos maus resultados." % p.display_name()
	if listed:
		body += " O clube já aceita ouvir propostas por ele."
	var n := NewsManager.post_raw(world, title, body, c.id, p.id, _imp(world, c), "atrito")
	n.media = {"type": "player", "player": p.id, "club": c.id}
	if rng.randf() < 0.5:
		var tx: String = RngUtil.pick(rng, ["Tem coisa que a gente guarda pra gente. Sigo trabalhando.", "Nem tudo que falam é verdade. Deus sabe de tudo.",
			"Respeito quem respeita. Ponto.", "Silêncio também é resposta."])
		_social_news(world, c, p, "Post enigmático de %s agita a torcida do %s" % [p.display_name(), c.short_name], tx)
	return true


## Protesto da torcida quando a fase é ruim.
static func _protest(world: GameWorld, c: Club, rng: RandomNumberGenerator) -> bool:
	var pos := _pos(world, c)
	var lg := world.league(c.league_id)
	var bottom := lg != null and pos > 0 and pos > lg.club_ids.size() - 3
	if c.streak_winless < 4 and c.fan_mood >= 32.0 and not bottom:
		return false
	c.board_confidence = clampf(c.board_confidence - 3.0, 0.0, 100.0)
	c.fan_mood = clampf(c.fan_mood - 2.0, 0.0, 100.0)
	var title: String = RngUtil.pick(rng, ["Torcida do %s protesta no CT", "Faixas e cobrança: organizada do %s cerca o treino", "Protesto no aeroporto: torcedores do %s cobram o elenco",
		"\"Time sem vergonha\": torcida do %s perde a paciência"]) % c.short_name
	var facts: Array = []
	if c.streak_winless >= 3:
		facts.append("%d jogos sem vencer" % c.streak_winless)
	if pos > 0:
		facts.append("%dº lugar na %s" % [pos, world.league_short(c.league_id)])
	var body := "Cerca de %s torcedores foram cobrar jogadores e diretoria. " % Fmt.thousands(int(clampf(c.fan_base * 0.004, 60.0, 2500.0)) / 10 * 10)
	body += ("O time soma %s. " % " e ".join(facts)) if not facts.is_empty() else ""
	body += "A pressão respinga em %s, que balança no cargo." % People.coach_name(world, c.id)
	var n := NewsManager.post_raw(world, title, body, c.id, -1, _imp(world, c), "protesto")
	n.media = {"type": "crest", "club": c.id}
	if c.streak_winless >= 3:
		n.media["rc"] = "Jogos sem vencer"
		n.media["rv"] = str(c.streak_winless)
	return true


## Diretoria (ou o dono) abre o cofre para reforços quando o time corresponde.
static func _invest(world: GameWorld, c: Club, rng: RandomNumberGenerator) -> bool:
	if int(c.affairs.get("inv", 0)) == world.year or c.balance < 0 or ClubEvents.banned(world, c):
		return false
	var pos := _pos(world, c)
	if not ((pos > 0 and pos <= 3) or c.streak_unbeaten >= 5) or rng.randf() > 0.6:
		return false
	var amount := Valuation.round_value(FinanceManager.expected_revenue(c) * rng.randf_range(0.06, 0.15))
	if amount <= 0:
		return false
	amount = FinanceManager.authorize_extra(world,c,amount,"sporting_review")
	if amount<=0:return false
	c.affairs["inv"] = world.year
	var own := WorldEvents.owner_of(world, c.id)
	var who := String(own.get("who", "")) if not own.is_empty() else "A diretoria"
	var title := "%s libera %s para reforços no %s" % [who if who != "A diretoria" else "Diretoria", Fmt.money(amount), c.short_name]
	var body := "Com o time %s, %s autorizou parte dos recursos disponíveis para o futebol. A verba vai para contratações%s." % [
		("em %dº" % pos) if pos > 0 else "embalado", who.to_lower() if who == "A diretoria" else who,
		" já nesta janela" if world.transfer_window_open() else " na próxima janela"]
	var n := NewsManager.post_raw(world, title, body, c.id, -1, _imp(world, c), "investimento")
	n.media = {"type": "crest", "club": c.id, "rc": "Verba extra", "rv": Fmt.money(amount)}
	return true


## Projeto de ampliação (ou estádio novo): anunciado agora, entregue numa virada de ano.
static func _stadium(world: GameWorld, c: Club, rng: RandomNumberGenerator) -> bool:
	if c.affairs.has("proj") or c.tier > 1 or c.fan_base < int(c.capacity * 1.25):
		return false
	var revenue := float(FinanceManager.expected_revenue(c))
	if c.balance < revenue * 0.4:
		return false
	var seats := int(minf(float(c.fan_base - c.capacity), c.capacity * 0.35) / 1000.0) * 1000
	if seats < 2000:
		return false
	var cost := WorldEvents.stadium_cost(c, seats)
	var due := world.year + rng.randi_range(1, 2)
	c.affairs["proj"] = [due, seats, cost]
	var big := seats >= c.capacity * 0.3
	var title := ("%s apresenta projeto de nova arena" if big else "%s anuncia ampliação do %s") % ([c.short_name] if big else [c.short_name, c.stadium])
	var body := "O projeto acrescenta %s lugares ao %s (hoje com %s) e custa %s. A entrega está prevista para %d." % [
		Fmt.thousands(seats), c.stadium, Fmt.thousands(c.capacity), Fmt.money(cost), due]
	var n := NewsManager.post_raw(world, title, body, c.id, -1, NewsEvent.IMP_LOW, "estadio")
	n.media = {"type": "crest", "club": c.id, "rc": "Lugares a mais", "rv": "+" + Fmt.thousands(seats), "rx": "Entrega prevista em %d" % due}
	return true


## Post de jogador nas redes, conforme o momento dele e do time.
static func _social(world: GameWorld, c: Club, rng: RandomNumberGenerator) -> bool:
	var sq: Array = world.squad(c)
	sq.sort_custom(func(a: Player, b: Player): return a.overall > b.overall)
	sq = sq.slice(0, 11)
	if sq.is_empty():
		return false
	var p: Player = RngUtil.pick(rng, sq)
	var title := ""
	var tx := ""
	if p.is_injured():
		title = "%s atualiza a torcida sobre a recuperação" % p.display_name()
		tx = RngUtil.pick(rng, ["Cada dia um passo. Volto mais forte.", "Fisioterapia em dia. Falta pouco!", "Obrigado pelas mensagens. Já já estou de volta."])
	elif p.form() >= 7.3:
		title = "%s comemora a fase nas redes" % p.display_name()
		tx = RngUtil.pick(rng, ["Semana perfeita. Obrigado, torcida!", "Trabalho, trabalho e mais trabalho. O resultado aparece.", "Que momento! Vamos por mais."])
	elif c.streak_losses >= 2:
		title = "%s pede união depois das derrotas" % p.display_name()
		tx = RngUtil.pick(rng, ["Momento difícil, mas a gente sai dessa junto.", "Ninguém está mais chateado do que nós. Vamos reagir.", "Cabeça erguida. Domingo tem mais."])
	elif p.morale < 40.0:
		title = "Post enigmático de %s agita a torcida do %s" % [p.display_name(), c.short_name]
		tx = RngUtil.pick(rng, ["Às vezes o silêncio diz tudo.", "Quem é de verdade sabe.", "Novos ares fazem bem pra alma."])
	else:
		title = "%s mostra os bastidores nas redes" % p.display_name()
		var town := p.hometown if p.hometown != "" else "minha cidade"
		tx = RngUtil.pick(rng, ["Dia de folga com a família.", "Treino pago. Foco no próximo jogo.", "Visita ao projeto social em %s. Isso não tem preço." % town,
			"Chuteira nova, mesma fome.", "Café da manhã de campeão. Bora!"])
	_social_news(world, c, p, title, tx)
	return true


static func _social_news(world: GameWorld, c: Club, p: Player, title: String, tx: String) -> void:
	var body := "Em post para os seguidores, %s escreveu: \"%s\"" % [p.display_name(), tx]
	var n := NewsManager.post_raw(world, title, body, c.id, p.id, NewsEvent.IMP_LOW, "social")
	n.media = {"type": "player", "player": p.id, "club": c.id, "tx": tx}


## Marcas de carreira (100, 200... jogos; 100, 150... gols) de quem está no elenco sorteado.
static func _milestone(world: GameWorld, c: Club) -> bool:
	var ms: Dictionary = world.stats.get("wp_ms", {})
	for p: Player in world.squad(c):
		var apps_m := (p.career_apps / 100) * 100
		var goals_m := (p.career_goals / 50) * 50
		var key := str(p.id)
		var last := int(ms.get(key, 0))
		var kind := ""
		var m := 0
		if goals_m >= 100 and p.career_goals - goals_m <= 3 and goals_m * 10 + 1 > last:
			kind = "g"
			m = goals_m
		elif apps_m >= 200 and p.career_apps - apps_m <= 4 and apps_m * 10 > last:
			kind = "a"
			m = apps_m
		if kind == "":
			continue
		ms[key] = m * 10 + (1 if kind == "g" else 0)
		if ms.size() > 400:
			ms.clear()
		world.stats["wp_ms"] = ms
		var title := ("%s chega a %d gols na carreira" if kind == "g" else "%s completa %d jogos como profissional") % [p.display_name(), m]
		var body := "Aos %d anos, o jogador do %s soma %d jogos e %d gols na carreira." % [p.age(world.year), c.short_name, p.career_apps, p.career_goals]
		var n := NewsManager.post_raw(world, title, body, c.id, p.id, _imp(world, c), "recorde")
		n.media = {"type": "player", "player": p.id, "club": c.id, "rc": "Gols na carreira" if kind == "g" else "Jogos na carreira", "rv": str(m),
			"cr": [p.career_apps, p.career_goals, p.titles]}
		return true
	return false


## Joia que desponta: garoto com números de gente grande nesta temporada.
static func _joia(world: GameWorld, c: Club, rng: RandomNumberGenerator) -> bool:
	var seen: Dictionary = world.stats.get("wp_joia", {})
	var best: Player = null
	for p: Player in world.squad(c):
		if p.age(world.year) > 20 or p.stats[Player.S_APPS] < 4 or p.avg_rating() < 6.9 or p.potential < 76:
			continue
		if int(seen.get(str(p.id), 0)) >= world.year - 1:
			continue
		if best == null or p.avg_rating() > best.avg_rating():
			best = p
	if best == null:
		return false
	seen[str(best.id)] = world.year
	if seen.size() > 300:
		seen.clear()
	world.stats["wp_joia"] = seen
	var p := best
	var st := _season_stats(p)
	var title: String = RngUtil.pick(rng, ["%s, %d anos, é a sensação do %s", "Aos %d anos, %s vira titular absoluto no %s", "Nasce uma estrela: %s brilha no %s"])
	if title.begins_with("Aos"):
		title = title % [p.age(world.year), p.display_name(), c.short_name]
	elif title.begins_with("Nasce"):
		title = title % [p.display_name(), c.short_name]
	else:
		title = title % [p.display_name(), p.age(world.year), c.short_name]
	var body := "%s tem %d jogos, %d gols e %d assistências na temporada, com nota média %.1f. Olheiros de clubes maiores já foram vê-lo." % [
		p.display_name(), int(st[0]), int(st[1]), int(st[2]), p.avg_rating()]
	var n := NewsManager.post_raw(world, title, body, c.id, p.id, _imp(world, c), "joia")
	n.media = {"type": "player", "player": p.id, "club": c.id, "st": st}
	return true


# ---------------------------------------------------------------------------
# Rumores que se resolvem depois
# ---------------------------------------------------------------------------

static func _new_rumor(world: GameWorld, pool: Array, rng: RandomNumberGenerator, wk: int) -> void:
	var c := _pick_club(pool, rng)
	var sq: Array = world.squad(c)
	sq.sort_custom(func(a: Player, b: Player): return a.overall > b.overall)
	var cands: Array = []
	for p: Player in sq.slice(0, 4):
		if p.loan.is_empty() and not p.retiring and p.age(world.year) <= 31:
			cands.append(p)
	if cands.is_empty():
		return
	var p: Player = RngUtil.pick(rng, cands)
	var suitor := MarketAI.realistic_suitor(world, p, maxf(c.reputation + 3.0, 50.0), rng)
	if suitor == null:
		return
	var rid := _register_rumor(world, p, suitor, wk, rng)
	if rid < 0:
		return
	var outlet := _outlet(world, suitor, rid * 7 + p.id)
	var title: String = RngUtil.pick(rng, ["%s está na mira do %s", "%s sonda a situação de %s", "Rumor: %s pode trocar o %s pelo %s"])
	if title.begins_with("Rumor"):
		title = title % [p.display_name(), c.short_name, suitor.short_name]
	elif title.contains("sonda"):
		title = title % [suitor.short_name, p.display_name()]
	else:
		title = title % [p.display_name(), suitor.short_name]
	var body := "Segundo o %s, o %s acompanha %s (%d anos, %s) e prepara uma proposta%s. O %s avalia o jogador em %s e não pretende facilitar." % [
		outlet, suitor.short_name, p.display_name(), p.age(world.year), Pos.name_of(p.position).to_lower(),
		"" if world.transfer_window_open() else " para a próxima janela", c.short_name, Fmt.money(p.value)]
	var n := NewsManager.post_raw(world, title, body, c.id, p.id, _imp(world, c), "rumor")
	n.media = {"type": "player", "player": p.id, "club": c.id, "rid": rid, "to": suitor.id, "rs": RS_OPEN, "vl": p.value}


static func _register_rumor(world: GameWorld, p: Player, suitor: Club, wk: int, rng: RandomNumberGenerator) -> int:
	var rum: Array = world.stats.get("wp_rum", [])
	for r: Dictionary in rum:
		if int(r.get("p", -1)) == p.id:
			return -1
	if rum.size() >= RUMOR_MAX:
		return -1
	var rid := int(world.stats.get("wp_rid", 1))
	world.stats["wp_rid"] = rid + 1
	rum.append({"id": rid, "p": p.id, "f": p.club_id, "to": suitor.id, "w": wk, "due": wk + rng.randi_range(2, 5), "y": world.year})
	world.stats["wp_rum"] = rum
	return rid


static func _resolve_rumors(world: GameWorld, wk: int) -> void:
	var rum: Array = world.stats.get("wp_rum", [])
	if rum.is_empty():
		return
	var keep: Array = []
	var window := world.transfer_window_open()
	for r: Dictionary in rum:
		var p := world.player(int(r.get("p", -1)))
		var to := world.club(int(r.get("to", -1)))
		var rid := int(r.get("id", -1))
		if p == null or to == null:
			_mark(world, rid, RS_FALSE)
			continue
		var from := world.club(int(r.get("f", -1)))
		var age := wk - int(r.get("w", wk))
		if p.club_id == to.id:
			_confirmed(world, p, to, from, rid, age, 0)
			continue
		if from == null or p.club_id != from.id:
			var now := world.club(p.club_id)
			_denied(world, p, to, from, rid, "%s acabou no %s" % [p.display_name(), now.short_name] if now != null else "%s deixou o %s" % [p.display_name(), from.short_name if from != null else "clube"])
			continue
		if wk < int(r.get("due", wk)):
			keep.append(r)
			continue
		if window and world.rng.randf() < 0.5:
			var t := _try_close(world, p, to)
			if t != null:
				_confirmed(world, p, to, from, rid, age, t.fee)
				continue
		var late := wk - int(r.get("due", wk))
		if (window and late >= 3) or (not window and late >= 6) or int(r.get("y", world.year)) < world.year - 1:
			_denied(world, p, to, from, rid, "")
			continue
		keep.append(r)
	world.stats["wp_rum"] = keep


static func _try_close(world: GameWorld, p: Player, buyer: Club) -> Transfer:
	var seller := world.club(p.club_id)
	if seller == null or world.is_user_club(seller.id) or ClubEvents.banned(world, buyer):
		return null
	if buyer.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
		return null
	if TransferManager.sale_block(world, seller, buyer, p) != "":
		return null
	var deal := MarketAI.negotiate(world, buyer, p, 0.8, false)
	if not deal.has("fee"):
		return null
	var fee := int(deal["fee"])
	if fee > buyer.transfer_budget or world.rng.randf() > MarketAI.player_interest(world, p, buyer):
		return null
	return TransferManager.complete_transfer(world, p, buyer, fee, TransferManager.wage_ask(world, p, buyer), TransferManager.preferred_years(world, p))


static func _mark(world: GameWorld, rid: int, status: int) -> void:
	if rid < 0:
		return
	for n: NewsEvent in world.news:
		if int(n.media.get("rid", -1)) == rid and n.category != "rumor_ok" and n.category != "rumor_nao":
			n.media["rs"] = status


static func _confirmed(world: GameWorld, p: Player, to: Club, from: Club, rid: int, weeks: int, fee: int) -> void:
	_mark(world, rid, RS_TRUE)
	var body := "O interesse foi noticiado há %d semana(s) e se confirmou: %s é jogador do %s%s." % [maxi(1, weeks), p.display_name(), to.short_name,
		(" por %s" % Fmt.money(fee)) if fee > 0 else ""]
	var n := NewsManager.post_raw(world, "Deu certo: rumor sobre %s se confirma" % p.display_name(), body, to.id, p.id, _imp(world, to), "rumor_ok")
	n.media = NewsManager.signing_media(p, to, fee, from.id if from != null else -1)
	n.media["rid"] = rid
	n.media["rs"] = RS_TRUE
	NewsManager.enrich_signing(world, n.media, p)


static func _denied(world: GameWorld, p: Player, to: Club, from: Club, rid: int, why: String) -> void:
	_mark(world, rid, RS_FALSE)
	var here := from if from != null else world.club(p.club_id)
	if here == null:
		return
	var title := "%s esfria e %s fica no %s" % ["Negociação com o " + to.short_name, p.display_name(), here.short_name] if why == "" else "Rumor não se confirma: " + why
	var body := "O %s chegou a sondar %s, mas as conversas não avançaram%s." % [to.short_name, p.display_name(),
		": os valores ficaram longe do que o clube pedia" if why == "" else ""]
	var n := NewsManager.post_raw(world, title, body, here.id, p.id, NewsEvent.IMP_LOW, "rumor_nao")
	n.media = {"type": "player", "player": p.id, "club": here.id, "rid": rid, "to": to.id, "rs": RS_FALSE}


# ---------------------------------------------------------------------------
# Despedidas
# ---------------------------------------------------------------------------

## Veterano que anunciou a aposentadoria: se for ídolo, ganha jogo de despedida semanas depois.
static func on_retirement(world: GameWorld, p: Player) -> void:
	if not world.has_user() or p.club_id < 0:
		return
	var c := world.club(p.club_id)
	if c == null or (p.career_apps < 380 and p.titles < 5 and p.overall < 80):
		return
	var fw: Array = world.stats.get("wp_fw", [])
	if fw.size() >= 8:
		return
	fw.append({"n": p.display_name(), "c": c.id, "a": p.career_apps, "g": p.career_goals, "t": p.titles, "p": p.id,
		"w": int(world.stats.get("wp_wk", 0)) + world.rng.randi_range(2, 4)})
	world.stats["wp_fw"] = fw


static func _farewells(world: GameWorld, wk: int) -> void:
	var fw: Array = world.stats.get("wp_fw", [])
	if fw.is_empty():
		return
	var keep: Array = []
	for e: Dictionary in fw:
		if int(e.get("w", 0)) > wk:
			keep.append(e)
			continue
		var c := world.club(int(e.get("c", -1)))
		if c == null:
			continue
		var name := String(e.get("n", ""))
		var crowd := mini(c.capacity, int(c.fan_base * world.rng.randf_range(0.5, 0.9)))
		var body := "%s torcedores foram ao %s para o último jogo de %s, com ex-companheiros e amigos em campo. Foram %d jogos e %d gols na carreira%s." % [
			Fmt.thousands(maxi(crowd, 1000)), c.stadium, name, int(e.get("a", 0)), int(e.get("g", 0)),
			(", com %d título(s)" % int(e.get("t", 0))) if int(e.get("t", 0)) > 0 else ""]
		var pid := int(e.get("p", -1))
		var n := NewsManager.post_raw(world, "Festa de despedida de %s lota o %s" % [name, c.stadium], body, c.id, pid if world.player(pid) != null else -1,
			_imp(world, c), "despedida")
		n.media = {"type": "crest", "club": c.id, "cr": [int(e.get("a", 0)), int(e.get("g", 0)), int(e.get("t", 0))], "pn": name}
		if world.player(pid) != null:
			n.media["type"] = "player"
			n.media["player"] = pid
	world.stats["wp_fw"] = keep


# ---------------------------------------------------------------------------
# Ligas: recordes, giro pelo mundo e aniversários
# ---------------------------------------------------------------------------

## Ligas acompanhadas: a do usuário, a principal do país dele e as grandes ligas estrangeiras.
static func _followed(world: GameWorld) -> Array:
	var out: Array = []
	var ul := world.league(world.user_league_id())
	if ul != null:
		out.append(ul)
	var top := world.league(Reputation.top_league_of(world.user_nation()))
	if top != null and not out.has(top):
		out.append(top)
	for lid in world.season.league_order:
		var lg: League = world.season.leagues[lid]
		if not out.has(lg) and SeasonManager._is_major(lg):
			out.append(lg)
	return out


## Tabela resumida para a matéria: [[clube, pts, jogos, saldo, posição]].
static func table_rows(lg: League, ids: Array, from: int, to: int) -> Array:
	var out: Array = []
	for i in range(maxi(0, from), mini(ids.size(), to)):
		var cid := int(ids[i])
		var r: Dictionary = lg.table.get(cid, {})
		out.append([cid, int(r.get("pts", 0)), int(r.get("pl", 0)), int(r.get("gf", 0)) - int(r.get("ga", 0)), i + 1])
	return out


static func _records(world: GameWorld) -> void:
	var posted := 0
	var gr: Dictionary = world.stats.get("wp_gr", {})
	var ub: Dictionary = world.stats.get("wp_ub", {})
	for lg: League in _followed(world):
		if posted >= 2:
			break
		if lg.rounds_played() < 5:
			continue
		# Artilheiro da liga passando de 15, 20, 25... gols
		var top := CompetitionManager.player_ranking(world, lg.id, Player.S_GOALS, 1)
		if not top.is_empty():
			var p: Player = top[0]
			var g := p.stats[Player.S_GOALS]
			var thr := (g / 5) * 5
			var prev: Array = gr.get(lg.id, [0, 0])
			var last := int(prev[1]) if int(prev[0]) == world.year else 0
			if thr >= 15 and thr > last:
				gr[lg.id] = [world.year, thr]
				var c := world.club(p.club_id)
				var n := NewsManager.post_raw(world, "%s chega a %d gols na %s" % [p.display_name(), g, lg.name],
					"O atacante do %s marcou %d vezes em %d jogos e lidera a artilharia com folga%s." % [c.short_name, g, p.stats[Player.S_APPS],
					"" if g < 25 else ". Já se fala em temporada histórica"], c.id, p.id, NewsEvent.IMP_NORMAL, "recorde")
				n.media = {"type": "player", "player": p.id, "club": c.id, "rc": "Gols na liga", "rv": str(g), "rx": "em %d jogos" % p.stats[Player.S_APPS],
					"tp": _scorers(world, lg.id, 5)}
				posted += 1
		# Invencibilidade: 10, 15, 20... jogos sem perder
		for id in lg.club_ids:
			var c := world.club(int(id))
			var key := str(c.id)
			if c.streak_unbeaten < 10:
				if ub.has(key):
					ub.erase(key)
				continue
			var mark := (c.streak_unbeaten / 5) * 5
			if mark > int(ub.get(key, 0)) and posted < 2:
				ub[key] = mark
				var n := NewsManager.post_raw(world, "%s chega a %d jogos sem perder" % [c.short_name, c.streak_unbeaten],
					"A última derrota do %s já tem %d partidas. Nos últimos cinco jogos: %s." % [c.short_name, c.streak_unbeaten, c.results.right(5)],
					c.id, -1, NewsEvent.IMP_HIGH if world.is_user_club(c.id) else NewsEvent.IMP_NORMAL, "recorde")
				n.media = {"type": "crest", "club": c.id, "rc": "Jogos sem perder", "rv": str(c.streak_unbeaten)}
				posted += 1
	world.stats["wp_gr"] = gr
	world.stats["wp_ub"] = ub


## Artilharia resumida: [[nome, clube, gols]].
static func _scorers(world: GameWorld, lid: String, n: int) -> Array:
	var out: Array = []
	for p: Player in CompetitionManager.player_ranking(world, lid, Player.S_GOALS, n):
		out.append([p.display_name(), p.club_id, p.stats[Player.S_GOALS]])
	return out


## Giro pelo mundo: líderes, vice e artilheiros das grandes ligas estrangeiras, uma vez por semana.
static func _roundup(world: GameWorld) -> void:
	var rows: Array = []
	var sum := 0
	var best_story := ""
	var best_score := -1
	var lead_club := -1
	for lid in world.season.league_order:
		var lg: League = world.season.leagues[lid]
		if lg.nation == world.user_nation() or not SeasonManager._is_major(lg):
			continue
		var rp := lg.rounds_played()
		if rp < 2:
			continue
		sum += rp
		var ids := CompetitionManager.sorted_ids(lg)
		if ids.size() < 2:
			continue
		var a := world.club(int(ids[0]))
		var b := world.club(int(ids[1]))
		var pa := int(lg.table[a.id]["pts"])
		var pb := int(lg.table[b.id]["pts"])
		var sc := CompetitionManager.player_ranking(world, lg.id, Player.S_GOALS, 1)
		var sp: Player = sc[0] if not sc.is_empty() else null
		rows.append([lg.id, a.id, pa, b.id, pb, sp.display_name() if sp != null else "", sp.stats[Player.S_GOALS] if sp != null else 0, sp.club_id if sp != null else -1])
		var gap := pa - pb
		var score := gap * 2 if gap >= 6 else (10 - gap * 3)
		score += int(a.reputation / 10.0)
		if score > best_score:
			best_score = score
			lead_club = a.id
			if gap >= 6:
				best_story = "%s dispara na %s" % [a.short_name, lg.short_name]
			elif gap <= 1:
				best_story = "%s e %s colados na %s" % [a.short_name, b.short_name, lg.short_name]
			else:
				best_story = "%s segue na frente na %s" % [a.short_name, lg.short_name]
	if rows.is_empty() or sum == int(world.stats.get("wp_ru", -1)):
		return
	world.stats["wp_ru"] = sum
	var parts: Array = []
	for r: Array in rows.slice(0, 4):
		parts.append("%s lidera a %s com %d pontos" % [world.club(int(r[1])).short_name, world.league_short(String(r[0])), int(r[2])])
	var n := NewsManager.post_raw(world, "Giro pelo mundo: " + best_story, "; ".join(parts) + ".", -1, -1, NewsEvent.IMP_NORMAL, "giro")
	n.media = {"type": "crest", "club": lead_club, "ru": rows}


## Aniversários de títulos (5, 10, 15... anos): uma vez por temporada, depois das primeiras rodadas.
static func _anniversaries(world: GameWorld) -> void:
	if int(world.stats.get("wp_ann", 0)) == world.year or world.current_day() < 4:
		return
	world.stats["wp_ann"] = world.year
	var user := world.user_club()
	var watch: Array = [Reputation.top_league_of(world.user_nation())]
	for lg: League in _followed(world):
		if not watch.has(lg.id):
			watch.append(lg.id)
	var mine: Array = []
	var others: Array = []
	for e in world.history:
		var h: Dictionary = e
		var k := world.year - int(h.get("y", 0))
		if not ANNIV.has(k):
			continue
		var lgs: Dictionary = h.get("leagues", {})
		for lid in lgs:
			var champ := int((lgs[lid] as Dictionary).get("champion", -1))
			if world.club(champ) == null:
				continue
			var item := [champ, world.league_name(String(lid)), int(h.get("y", 0)), k]
			if champ == user.id:
				mine.append(item)
			elif watch.has(String(lid)):
				others.append(item)
		var cups: Dictionary = h.get("cups", {})
		for cid in cups:
			var champ2 := int((cups[cid] as Dictionary).get("champion", -1))
			if champ2 == user.id and world.club(champ2) != null:
				mine.append([champ2, CupManager.cup_name(String(cid)), int(h.get("y", 0)), k])
	var picks: Array = mine.slice(0, 2)
	while picks.size() < 3 and not others.is_empty():
		var i := world.rng.randi_range(0, others.size() - 1)
		picks.append(others[i])
		others.remove_at(i)
	for it: Array in picks:
		var c := world.club(int(it[0]))
		var k := int(it[3])
		var body := "Em %d, o %s levantava a taça (%s). %s" % [int(it[2]), c.name, String(it[1]),
			"A torcida relembra a campanha nas redes e o clube prepara homenagem aos campeões." if world.is_user_club(c.id) else "A data foi lembrada pelo clube nas redes sociais."]
		var n := NewsManager.post_raw(world, "Há %d anos, o título do %s · %s" % [k, c.short_name, String(it[1])], body, c.id, -1,
			NewsEvent.IMP_HIGH if world.is_user_club(c.id) else NewsEvent.IMP_LOW, "aniversario")
		n.media = {"type": "crest", "club": c.id, "trophy": true, "rc": "Título de %d" % int(it[2]), "rv": "%d anos" % k, "rx": String(it[1])}


# ---------------------------------------------------------------------------
# Depois de cada data: corrida pelo título, luta contra a queda e prévias de clássico
# ---------------------------------------------------------------------------

static func after_matchday(world: GameWorld, entries: Array) -> void:
	if not world.has_user() or world.season == null:
		return
	var today: Dictionary = {}
	for r in entries:
		var f: Fixture = r["f"]
		if world.season.leagues.has(f.comp):
			today[f.comp] = true
	if today.is_empty():
		return
	var tr: Dictionary = world.stats.get("wp_tr", {})
	var dp: Dictionary = world.stats.get("wp_dp", {})
	var posted := 0
	var abroad := 0
	for lg: League in _followed(world):
		if not today.has(lg.id) or posted >= 3:
			continue
		var rp := lg.rounds_played()
		var total := lg.round_count()
		var ids := CompetitionManager.sorted_ids(lg)
		if ids.size() < 4:
			continue
		var mine := lg.id == world.user_league_id()
		var imp := NewsEvent.IMP_NORMAL if mine or lg.nation == world.user_nation() else NewsEvent.IMP_LOW
		if rp >= int(total * 0.5) and rp < total:
			# Título
			var a := world.club(int(ids[0]))
			var b := world.club(int(ids[1]))
			var pa := int(lg.table[a.id]["pts"])
			var pb := int(lg.table[b.id]["pts"])
			var p3 := int(lg.table[int(ids[2])]["pts"])
			var tkey := lg.id + ":t"
			if pa - pb <= 3 and rp - int(tr.get(tkey, -99)) >= 4:
				tr[tkey] = rp
				var three := pa - p3 <= 4
				var title := ("Três na briga: a %s está aberta" % lg.name) if three else ("%s e %s brigam ponto a ponto pela %s" % [a.short_name, b.short_name, lg.name])
				var body := "Faltam %d rodadas. %s lidera com %d pontos, %s tem %d%s." % [total - rp, a.short_name, pa, b.short_name, pb,
					(" e %s, %d" % [world.club(int(ids[2])).short_name, p3]) if three else ""]
				var n := NewsManager.post_raw(world, title, body, a.id, -1, NewsEvent.IMP_HIGH if world.is_user_club(a.id) or world.is_user_club(b.id) else imp, "briga_titulo")
				n.media = {"type": "crest", "club": a.id, "tb": table_rows(lg, ids, 0, 5), "lg": lg.id, "hl": [a.id, b.id]}
				posted += 1
			elif pa - pb >= 9 and rp >= int(total * 0.6) and int(tr.get(lg.id + ":d", 0)) != world.year:
				tr[lg.id + ":d"] = world.year
				var n := NewsManager.post_raw(world, "%s dispara e encaminha o título da %s" % [a.short_name, lg.name],
					"São %d pontos de vantagem sobre o %s a %d rodadas do fim. Só um desastre tira a taça do %s." % [pa - pb, b.short_name, total - rp, a.short_name],
					a.id, -1, NewsEvent.IMP_HIGH if world.is_user_club(a.id) else imp, "briga_titulo")
				n.media = {"type": "crest", "club": a.id, "tb": table_rows(lg, ids, 0, 5), "lg": lg.id, "hl": [a.id]}
				posted += 1
			# Rebaixamento
			var down := lg.relegated_count()
			var zkey := lg.id + ":z"
			if down > 0 and ids.size() > down + 2 and rp - int(tr.get(zkey, -99)) >= 4:
				var cut := ids.size() - down
				var safe := world.club(int(ids[cut - 1]))
				var first_down := world.club(int(ids[cut]))
				var gap := int(lg.table[safe.id]["pts"]) - int(lg.table[first_down.id]["pts"])
				if gap <= 2:
					tr[zkey] = rp
					var n := NewsManager.post_raw(world, "Luta contra a queda esquenta na %s" % lg.name,
						"%s, primeiro fora da zona, tem só %d ponto(s) a mais que o %s. Faltam %d rodadas." % [safe.short_name, gap, first_down.short_name, total - rp],
						first_down.id, -1, NewsEvent.IMP_HIGH if world.is_user_club(safe.id) or world.is_user_club(first_down.id) else imp, "briga_z")
					n.media = {"type": "crest", "club": first_down.id, "tb": table_rows(lg, ids, cut - 3, cut + 3), "lg": lg.id, "zc": cut + 1,
						"hl": [safe.id, first_down.id]}
					posted += 1
		# Prévia do clássico da próxima rodada
		# (lá fora, só um por data e só entre clubes grandes; em casa, clássico de peso ou o do usuário)
		var foreign := lg.nation != world.user_nation()
		if rp < total and int(dp.get(lg.id, -1)) != rp and not (foreign and abroad >= 1):
			for f: Fixture in lg.fixtures_of_round(rp):
				if f.played or not MatchEngine.is_derby(world, f.home, f.away):
					continue
				var user_in := world.is_user_club(f.home) or world.is_user_club(f.away)
				var low := minf(world.club(f.home).reputation, world.club(f.away).reputation)
				if not user_in and low < (70.0 if foreign else 62.0):
					continue
				if foreign:
					abroad += 1
				dp[lg.id] = rp
				_derby_preview(world, lg, ids, f, imp)
				posted += 1
				break
	world.stats["wp_tr"] = tr
	world.stats["wp_dp"] = dp


static func _derby_preview(world: GameWorld, lg: League, ids: Array, f: Fixture, imp: int) -> void:
	var h := world.club(f.home)
	var a := world.club(f.away)
	var hh := FootballMemory.head_to_head(world, h.id, a.id)
	var body := "%s (%dº) recebe o %s (%dº) na próxima rodada da %s." % [h.short_name, ids.find(h.id) + 1, a.short_name, ids.find(a.id) + 1, lg.name]
	if int(hh["games"]) > 0:
		body += " Retrospecto: %d vitória(s) do %s, %d do %s e %d empate(s)." % [int(hh["wins"]), h.short_name, int(hh["losses"]), a.short_name, int(hh["draws"])]
	if h.results != "" and a.results != "":
		body += " Últimos jogos: %s %s, %s %s." % [h.short_name, h.results.right(5), a.short_name, a.results.right(5)]
	var user_in := world.is_user_club(h.id) or world.is_user_club(a.id)
	var n := NewsManager.post_raw(world, "Semana de clássico: %s x %s" % [h.short_name, a.short_name], body, h.id, -1,
		NewsEvent.IMP_HIGH if user_in else imp, "classico_previa")
	n.media = {"type": "crest", "club": h.id, "op": a.id, "lg": lg.id}


# ---------------------------------------------------------------------------
# Virada de ano
# ---------------------------------------------------------------------------

## Obras anunciadas ficam prontas; o que não deu tempo segue para o ano seguinte.
static func season_start(world: GameWorld) -> void:
	for c: Club in world.clubs:
		if not c.affairs.has("proj"):
			continue
		var pj: Array = c.affairs["proj"]
		if int(pj[0]) > world.year:
			continue
		c.affairs.erase("proj")
		if world.is_user_club(c.id):
			continue
		var seats := int(pj[1])
		c.capacity += seats
		c.add_ledger("investimentos", -int(pj[2]))
		if world.has_user():
			var n := NewsManager.post_raw(world, "%s inaugura as obras do %s" % [c.short_name, c.stadium],
				"Com %s lugares a mais, o estádio agora recebe %s torcedores. A festa de reabertura teve casa cheia." % [Fmt.thousands(seats), Fmt.thousands(c.capacity)],
				c.id, -1, NewsEvent.IMP_LOW, "estadio")
			n.media = {"type": "crest", "club": c.id, "rc": "Nova capacidade", "rv": Fmt.thousands(c.capacity)}
