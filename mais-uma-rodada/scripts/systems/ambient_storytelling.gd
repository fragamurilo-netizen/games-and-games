class_name AmbientStorytelling
extends RefCounted
## Camada leve de ambientação: repercussões de treino, vestiário, torcida, imprensa e mercado.
## Não altera o motor de partidas. Usa o estado real do save para gerar notícias e falas contextuais.

const STORY_COOLDOWN := 2


static func after_user_turn(world: GameWorld, result: String) -> void:
	if not world.has_user():
		return
	var turn := world.current_turn()
	var last := int(world.stats.get("ambient_story_turn", -99))
	if turn - last < STORY_COOLDOWN:
		return
	var rng := world.rng
	if rng.randf() > 0.34:
		return
	var club := world.user_club()
	var squad: Array = world.squad(club)
	if squad.is_empty():
		return

	var posted := false
	# Sequências fortes geram repercussão de vestiário/torcida.
	if club.streak_wins >= 3 and rng.randf() < 0.45:
		NewsManager.post(world, "vestiario_reacao", {
			"club": club.short_name,
			"result": "a sequência de %d vitórias" % club.streak_wins
		}, club.id, -1, NewsEvent.IMP_NORMAL)
		posted = true
	elif club.streak_losses >= 2 and rng.randf() < 0.45:
		NewsManager.post(world, "vestiario_reacao", {
			"club": club.short_name,
			"result": "a sequência de %d derrotas" % club.streak_losses
		}, club.id, -1, NewsEvent.IMP_HIGH)
		posted = true

	# Destaque/queda de rendimento no treino.
	if not posted:
		var fit: Array = []
		for p: Player in squad:
			if not p.is_injured():
				fit.append(p)
		if not fit.is_empty():
			var p: Player = RngUtil.pick(rng, fit)
			if p.form() >= 7.0 and rng.randf() < 0.55:
				NewsManager.post(world, "treino_destaque", {
					"player": p.display_name(), "club": club.short_name,
					"age": p.age(world.year)
				}, club.id, p.id, NewsEvent.IMP_NORMAL)
				posted = true
			elif p.morale < 38.0 and rng.randf() < 0.35:
				NewsManager.post(world, "treino_queda", {
					"player": p.display_name(), "club": club.short_name
				}, club.id, p.id, NewsEvent.IMP_NORMAL)
				posted = true

	# Jovem chamando atenção.
	if not posted:
		var kids: Array = []
		for p: Player in squad:
			if p.age(world.year) <= 20 and not p.is_injured():
				kids.append(p)
		if not kids.is_empty() and rng.randf() < 0.5:
			var kid: Player = RngUtil.pick(rng, kids)
			NewsManager.post(world, "jovem_monitorado", {
				"player": kid.display_name(), "club": club.short_name,
				"age": kid.age(world.year)
			}, club.id, kid.id, NewsEvent.IMP_NORMAL)
			posted = true

	# Veterano assume voz no grupo.
	if not posted:
		var vets: Array = []
		for p: Player in squad:
			if p.age(world.year) >= 29 and (p.has_trait("lider") or p.squad_status <= Player.STATUS_ROTATION):
				vets.append(p)
		if not vets.is_empty() and rng.randf() < 0.5:
			var vet: Player = RngUtil.pick(rng, vets)
			NewsManager.post(world, "veterano_lider", {
				"player": vet.display_name(), "club": club.short_name
			}, club.id, vet.id, NewsEvent.IMP_NORMAL)
			posted = true

	# Clima para o próximo jogo.
	if not posted:
		var f := FixtureManager.next_fixture_for(world, club.id)
		if f != null:
			var opp := world.club(f.opponent_of(club.id))
			if opp != null:
				if MatchEngine.is_derby(world, f.home, f.away) or rng.randf() < 0.42:
					NewsManager.post(world, "tecnico_adversario", {
						"club": club.short_name, "opponent": opp.short_name
					}, club.id, -1, NewsEvent.IMP_NORMAL)
					posted = true

	# Rumor de mercado em torno de um jogador valorizado.
	if not posted and rng.randf() < 0.45:
		var candidates: Array = []
		for p: Player in squad:
			if not p.transfer_listed and p.age(world.year) <= 29 and p.squad_status <= Player.STATUS_STARTER:
				candidates.append(p)
		if not candidates.is_empty():
			var target: Player = RngUtil.pick(rng, candidates)
			NewsManager.post(world, "rumor_mercado", {
				"player": target.display_name(), "club": club.short_name
			}, club.id, target.id, NewsEvent.IMP_NORMAL)
			posted = true

	if posted:
		world.stats["ambient_story_turn"] = turn


static func enrich_conversation(world: GameWorld, conv: Dictionary, kind: String, target: int = -1) -> Dictionary:
	if bool(conv.get("done", false)) or not world.has_user():
		return conv
	var line := _context_line(world, kind, target)
	if line != "":
		# Entra antes da pergunta de abertura: as respostas oferecidas respondem a ela, então ela
		# precisa ser a última fala (na coletiva pós-jogo, a pergunta sobre o placar).
		var lines: Array = conv["lines"]
		if not lines.is_empty() and String(lines.back()[0]) == "npc":
			lines.insert(lines.size() - 1, ["npc", line])
		else:
			lines.append(["npc", line])
	return conv


static func _context_line(world: GameWorld, kind: String, target: int) -> String:
	var rng := _r(world)
	var club := world.user_club()
	match kind:
		"player":
			var p := world.player(target)
			if p == null:
				return ""
			if p.is_injured():
				return _pick(rng, [
					"Quero voltar logo, professor. Ficar vendo de fora é pior do que parece.",
					"O departamento médico está cuidando, mas eu já estou contando os dias para voltar."
				])
			if p.form() >= 7.2:
				return _pick(rng, [
					"Estou me sentindo muito bem com a bola. Queria aproveitar essa fase.",
					"Os jogos estão encaixando para mim. Quero continuar nesse ritmo.",
					"Estou confiante, professor. Parece que tudo está saindo mais natural."
				])
			if p.morale < 40.0:
				return _pick(rng, [
					"Vou ser sincero: minha cabeça não está boa nas últimas semanas.",
					"Estou tentando manter o foco, mas não estou satisfeito com meu momento.",
					"Tem coisa me incomodando. Achei melhor falar antes de virar um problema."
				])
			if p.age(world.year) <= 21:
				return _pick(rng, [
					"Eu sei que ainda tenho muito para aprender. Quero aproveitar cada oportunidade.",
					"Os mais velhos têm me ajudado bastante. Estou tentando absorver tudo.",
					"Quero mostrar que posso ajudar agora, não só no futuro."
				])
			return _pick(rng, [
				"O ambiente do grupo está bom. Dá para sentir quando o time está junto.",
				"Tenho observado bastante o que acontece no vestiário. Tem coisa que só jogador percebe.",
				"Se precisar que eu fale com o grupo, pode contar comigo."
			])
		"board":
			if club.board_confidence < 40.0:
				return _pick(rng, [
					"Vou ser franco: há conselheiros bastante incomodados com os últimos resultados.",
					"A cobrança aumentou nos bastidores. Precisamos mostrar uma direção clara.",
					"O conselho quer respostas, principalmente sobre desempenho e planejamento."
				])
			if club.balance < 0:
				return _pick(rng, [
					"O futebol precisa andar, mas o caixa também. Não podemos ignorar os números.",
					"Estamos apertados financeiramente. Toda decisão agora precisa ter retorno.",
					"A situação do caixa exige cuidado, especialmente no mercado."
				])
			return _pick(rng, [
				"Quero ouvir o que você está vendo no dia a dia antes de decidirmos qualquer coisa.",
				"O conselho gosta de ser surpreendido por resultados, não por problemas.",
				"Planejamento bom é aquele que evita reunião de emergência."
			])
		"staff":
			return _pick(rng, [
				"Separei alguns detalhes do treino e do adversário que podem fazer diferença.",
				"Tem coisa que aparece nos números e coisa que só aparece vendo o treino de perto.",
				"Quero te passar uma leitura do grupo antes que a semana avance.",
				"Alguns jogadores estão respondendo melhor às cargas; outros estão no limite."
			])
		"fans":
			if club.fan_mood < 40.0:
				return _pick(rng, [
					"A arquibancada está impaciente. A gente quer sentir que o time entende o peso da camisa.",
					"Não é só resultado. A torcida quer entrega, principalmente nos jogos grandes.",
					"O clima piorou nas redes. Uma resposta em campo mudaria muita coisa."
				])
			return _pick(rng, [
				"A torcida está comprando a ideia. Não deixa esse clima esfriar.",
				"Quando o time demonstra vontade, a arquibancada responde na hora.",
				"Tem muita gente voltando a acreditar no trabalho."
			])
		"coach":
			return _pick(rng, [
				"Sei que vocês estudaram nosso time. Nós também fizemos o dever de casa.",
				"Jogo entre treinadores também é detalhe. Vamos ver quem lê melhor os noventa minutos.",
				"Tenho respeito pelo seu trabalho, mas dentro de campo ninguém facilita."
			])
		"press":
			if club.streak_losses >= 2:
				return _pick(rng, [
					"Nos bastidores já se fala em pressão. O que mudou nas últimas semanas?",
					"A torcida está cobrando. Você sente que o grupo ainda responde ao seu comando?",
					"Os resultados caíram. Existe alguma explicação que o público ainda não viu?"
				])
			if club.streak_wins >= 3:
				return _pick(rng, [
					"O time embalou. Já dá para falar em algo maior nesta temporada?",
					"A equipe parece mais segura a cada rodada. O que mudou internamente?",
					"Até onde esse time pode chegar jogando desse jeito?"
				])
			return _pick(rng, [
				"Quero fugir do óbvio: o que mais te preocupa no time hoje?",
				"Qual detalhe do trabalho desta semana pode aparecer no próximo jogo?",
				"Tem algum jogador pedindo passagem nos treinos?"
			])
	return ""


static func _r(world: GameWorld) -> RandomNumberGenerator:
	return People.rng(world, 73)


static func _pick(rng: RandomNumberGenerator, arr: Array) -> String:
	return String(RngUtil.pick(rng, arr))
