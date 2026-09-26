class_name SocialComments
extends RefCounted
## Comentários da torcida nos posts das redes, montados por peças com os dados do save: quem fez
## o gol, quem foi mal, a posição na tabela, a sequência, o rival, o treinador, a fornecedora do
## uniforme, o setorista que soltou o rumor... Cada torcedor tem um jeito de escrever (empolgado,
## corneteiro, analista, zoeiro, saudosista) e nem todo mundo concorda: tem quem cobre depois da
## vitória e quem defenda depois da derrota, e torcedor rival aparecendo para provocar.
##
## ctx: {kind, club, opp?, rival?, gf?, ga?, home?, scorers?, hero?, weak?, pos?, teams?, streak?,
##       player?, brand?, notes?, score?, journo?, acc?, manager, year}

const PERSONAS := ["empolgado", "corneteiro", "analista", "zoeiro", "saudosista", "otimista"]


## `n` comentários para o post `key`. Cada item: {acc, text, likes}.
static func make(world: GameWorld, key: String, ctx: Dictionary, n: int, post_likes: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash([key, "coment"])
	var club: Club = ctx.get("club")
	if club == null:
		club = world.user_club()
	var out: Array = []
	var used_text: Dictionary = {}
	var used_handle: Dictionary = {}
	var tries := 0
	while out.size() < n and tries < n * 8:
		tries += 1
		var persona := String(RngUtil.pick(r, PERSONAS))
		var author := club
		var outsider := false
		# Rival (ou o adversário do jogo) aparece para provocar.
		var foe: Club = ctx.get("rival") if ctx.get("rival") != null else ctx.get("opp")
		if foe != null and r.randf() < 0.14:
			author = foe
			outsider = true
		var text := _line(world, r, ctx, club, persona, outsider)
		if text == "" or used_text.has(text):
			continue
		used_text[text] = true
		if not outsider:
			text = _voice(r, text, persona, String(ctx.get("kind", "")) in ["loss", "bad", "draw", "kit_bad", "kit_mid", "coletiva"])
		elif r.randf() < 0.4:
			text = String(RngUtil.pick(r, ["KKKKKKK ", "kkkkk ", "Rapaz, "])) + text
		var acc := SocialFeed.fan_acc(r, author)
		while used_handle.has(acc["handle"]):
			acc = SocialFeed.fan_acc(r, author)
		used_handle[acc["handle"]] = true
		out.append({"acc": acc, "text": text, "likes": 0, "rival": outsider})
	# Curtidas em cauda longa: o comentário do topo leva muito mais.
	var top := float(post_likes) * r.randf_range(0.04, 0.12)
	for i in out.size():
		out[i]["likes"] = maxi(0, int(top / pow(i + 1.0, 1.3) * r.randf_range(0.7, 1.3)))
	out.sort_custom(func(a, b): return int(a["likes"]) > int(b["likes"]))
	return out


## O jeito de escrever de cada um.
static func _voice(r: RandomNumberGenerator, text: String, persona: String, sour: bool) -> String:
	match persona:
		"empolgado":
			if r.randf() < 0.35:
				text = text.to_upper()
			text = text.trim_suffix(".") + String(RngUtil.pick(r, ["!!!", "!", "!!", " VAMOS!"]))
		"zoeiro":
			if sour:
				return text
			var pre := String(RngUtil.pick(r, ["KKKKKKK ", "kkkkk ", "Rapaz, ", "Mds, ", ""]))
			if pre != "" and text != text.to_upper():
				text = text.substr(0, 1).to_lower() + text.substr(1)
			text = pre + text
		"corneteiro":
			if not sour:
				return text
			if r.randf() < 0.4:
				text = text.to_lower().trim_suffix(".")
			text += String(RngUtil.pick(r, ["", " Só falo isso.", " Anota aí.", "..."]))
		"analista":
			if not sour:
				return text
			text = String(RngUtil.pick(r, ["Sinceramente, ", "Olha, ", "Pra mim ", ""])) + text.substr(0, 1).to_lower() + text.substr(1) if r.randf() < 0.5 else text
		"saudosista":
			if r.randf() < 0.4:
				text += String(RngUtil.pick(r, [" Saudade do time de antigamente.", " No meu tempo era diferente.", ""]))
	return text


static func _fill(s: String, v: Dictionary) -> String:
	for k in v:
		s = s.replace("{%s}" % k, String(v[k]))
	return s


static func _vars(world: GameWorld, ctx: Dictionary, club: Club) -> Dictionary:
	var v := {"club": club.short_name, "coach": String(ctx.get("manager", "o técnico")), "year": str(ctx.get("year", world.year))}
	var opp: Club = ctx.get("opp")
	v["opp"] = opp.short_name if opp != null else "adversário"
	var rival: Club = ctx.get("rival")
	v["rival"] = rival.short_name if rival != null else (opp.short_name if opp != null else "rival")
	var hero: Player = ctx.get("hero")
	v["hero"] = hero.short_name() if hero != null else ""
	var weak: Player = ctx.get("weak")
	v["weak"] = weak.short_name() if weak != null else ""
	var pl: Player = ctx.get("player")
	v["player"] = pl.short_name() if pl != null else ""
	v["pos"] = str(int(ctx.get("pos", 0)))
	v["score"] = "%d x %d" % [int(ctx.get("gf", 0)), int(ctx.get("ga", 0))]
	v["brand"] = String(ctx.get("brand", "a fornecedora"))
	v["journo"] = String(ctx.get("journo", "esse jornalista"))
	v["streak"] = str(absi(int(ctx.get("streak", 0))))
	v["age"] = str(pl.age(world.year)) if pl != null else ""
	v["pos_name"] = Pos.code(pl.position) if pl != null else ""
	return v


## Uma frase para o contexto e o jeito do torcedor ("" = nada a dizer).
static func _line(world: GameWorld, r: RandomNumberGenerator, ctx: Dictionary, club: Club, persona: String, outsider: bool) -> String:
	var v := _vars(world, ctx, club)
	var kind := String(ctx.get("kind", "neutral"))
	var pool: Array = []
	if outsider:
		match kind:
			"win", "good", "title":
				pool = ["Sorte. Só isso.", "Deixa eles, daqui a pouco caem.", "Juiz ajudou, todo mundo viu.", "Aproveita que dura pouco."]
			"loss", "bad":
				pool = ["Chora não, {club}!", "Freguês é freguês.", "Tá explicado o {pos}º lugar.", "Obrigado pelos três pontos, {club}."]
			"kit_good", "kit_mid", "kit_bad":
				pool = ["Pode fazer o uniforme que quiser, continua perdendo.", "Bonito. Pena que quem veste não joga nada.", "Vai ficar lindo na segunda divisão."]
			_:
				pool = ["Ninguém liga.", "Quem?", "Segue o baile, {club}."]
		return _fill(String(RngUtil.pick(r, pool)), v)
	var hero := String(v["hero"])
	var weak := String(v["weak"])
	var pos := int(ctx.get("pos", 0))
	var streak := int(ctx.get("streak", 0))
	match kind:
		"win":
			pool = ["Três pontos! O {club} tá voando.", "Vitória com a cara do {club}.", "Hoje eu durmo feliz."]
			if hero != "":
				pool.append_array(["{hero} jogou demais hoje.", "{hero} tem que ir pra seleção, não é possível.", "Esse {hero} é diferenciado.", "Quem ainda critica o {hero}?"])
			if pos > 0 and pos <= 4:
				pool.append_array(["{pos}º lugar. Deixa sonhar!", "G4 é nosso lugar."])
			elif pos > 0:
				pool.append("Agora é embalar e subir na tabela. Tamo em {pos}º.")
			if streak >= 3:
				pool.append("{streak} vitórias seguidas. Respeita!")
			if persona in ["corneteiro", "analista"]:
				pool.append_array(["Ganhou, mas o segundo tempo foi horrível.", "Não me engana, {coach}. Esse meio-campo não funciona."])
				if weak != "":
					pool.append_array(["Ganhamos apesar do {weak}.", "O {weak} de novo não fez nada."])
			if int(ctx.get("gf", 0)) - int(ctx.get("ga", 0)) >= 3:
				pool.append_array(["Goleada! Assim que eu gosto.", "Atropelou! {score} é pouco."])
		"loss":
			pool = ["Inadmissível.", "Cadê a raça?", "Que vergonha perder pro {opp}.", "Diretoria, acorda!"]
			if weak != "":
				pool.append_array(["Com o {weak} de titular não dá.", "Tira o {weak}, pelo amor.", "O {weak} entregou o jogo."])
			if pos > 0:
				pool.append("{pos}º lugar. Isso é campanha de time grande?")
			if streak <= -3:
				pool.append_array(["{streak} derrotas seguidas. Já passou da hora de mudar.", "Fora, {coach}!"])
			if persona in ["otimista", "empolgado"]:
				pool.append_array(["Calma, galera. Campeonato é longo.", "Tô com o {coach} até o fim.", "Cabeça erguida, próximo jogo tem que ganhar."])
			if hero != "":
				pool.append("Só o {hero} se salvou.")
		"draw":
			pool = ["Empate com gosto de derrota.", "Um ponto é um ponto.", "Faltou ousadia, {coach}.", "Dava pra ganhar fácil."]
			if hero != "":
				pool.append("Se não fosse o {hero}, tinha perdido.")
			if weak != "":
				pool.append("{weak} perdeu gol feito. Inacreditável.")
		"signing":
			pool = ["Bem-vindo, {player}! Honra essa camisa.", "Gostei. {player} vai ajudar muito.", "Quero ver jogar primeiro.", "Finalmente um {pos_name} de verdade."]
			if int(ctx.get("age", 0)) >= 31:
				pool.append_array(["{player} com {age} anos? Vai jogar de bengala?", "Experiência é bom, mas {age} anos..."])
			elif int(ctx.get("age", 0)) > 0 and int(ctx.get("age", 0)) <= 21:
				pool.append_array(["Garoto bom, só não queimem ele.", "Aposta pro futuro. Gostei."])
			if bool(ctx.get("upgrade", false)):
				pool.append_array(["Reforço de peso!", "Esse chega pra ser titular."])
			else:
				pool.append_array(["Esse aí não joga nem no meu time da pelada.", "Contratação pra compor elenco..."])
		"rumor":
			pool = ["Se vier, eu vou buscar no aeroporto.", "Acredito quando vir a camisa na mão.", "Traz logo, {club}!"]
			if float(ctx.get("acc", 0.5)) >= 0.65:
				pool.append_array(["Se o {journo} falou, tá fechado.", "{journo} não erra. Pode comemorar."])
			else:
				pool.append_array(["{journo} inventando de novo.", "Fonte: vozes da cabeça do {journo}.", "Esse {journo} erra mais do que acerta."])
		"injury":
			pool = ["Força, {player}!", "Volta mais forte.", "Que azar, logo agora.", "Departamento médico precisa rever esse trabalho.", "Sem o {player} complica muito."]
		"title":
			pool = ["É CAMPEÃO!", "Chora, {rival}!", "Valeu cada sofrimento.", "Obrigado, {coach}!", "Título mais que merecido."]
			if hero != "":
				pool.append("Obrigado, {hero}!")
		"bad":
			pool = ["Já deu, precisa mudar alguma coisa.", "Eu não aguento mais sofrer com esse time.", "Paciência tem limite.", "Diretoria, acorda!"]
			if persona == "otimista":
				pool.append("Fase ruim passa. Vamos juntos.")
		"good":
			pool = ["Que fase!", "Esse elenco tá com fome.", "Quem criticou vai ter que engolir.", "Vamos, {club}!"]
			if hero != "":
				pool.append("{hero} voando!")
		"player":
			pool = ["Ídolo!", "Craque demais.", "Joga muito, {player}!", "Renova com ele já, {club}!"]
			if persona == "corneteiro":
				pool.append("Fez um jogo bom e já acha que é o Pelé.")
		"coletiva":
			pool = ["Falou tudo, {coach}.", "Menos conversa e mais resultado.", "Vou cobrar essa frase no fim do ano.", "Gostei da postura.", "Isso aí vai virar meme se não cumprir."]
		"kit_good", "kit_mid", "kit_bad":
			pool = _kit_lines(ctx, kind, persona)
		_:
			pool = ["Vamos, {club}!", "Seguimos.", "Tá difícil prever esse campeonato.", "Bora pra próxima."]
	if pool.is_empty():
		return ""
	return _fill(String(RngUtil.pick(r, pool)), v)


static func _kit_lines(ctx: Dictionary, kind: String, persona: String) -> Array:
	var notes: Array = ctx.get("notes", [])
	var pool: Array = []
	match kind:
		"kit_good":
			pool = ["Manto lindo demais. Já comprei o meu.", "{brand} acertou em cheio esse ano.", "Esse é o uniforme do título, anota."]
		"kit_mid":
			pool = ["Nada demais, mas dá pro gasto.", "Bonito na foto, quero ver em campo.", "Queria algo mais ousado da {brand}."]
		_:
			pool = ["Quem aprovou isso?", "Não compro nem na promoção.", "{brand} errou feio.", "Isso não é o {club}."]
	if "Titular fiel às cores do clube" in notes:
		pool.append_array(["Respeitou a história do clube.", "Cores certas, do jeito que tem que ser."])
	if "Titular longe das cores do clube" in notes:
		pool.append_array(["Cadê as cores do clube?", "Parece uniforme de outro time."])
	if "Igual ao do ano passado" in notes:
		pool.append_array(["É o mesmo do ano passado com outro preço.", "Copiou e colou, {brand}?"])
	if "Novidade sem perder a tradição" in notes:
		pool.append("Novo sem perder a identidade. Assim que é.")
	if "Mudança radical em relação ao ano passado" in notes:
		pool.append_array(["Mudou demais, tô estranhando.", "Ousado. Vai dividir a torcida."])
	if "Reserva parecida com o titular" in notes:
		pool.append("A reserva tá quase igual ao titular, né?")
	if "Terceiro uniforme ousado" in notes:
		pool.append_array(["O terceiro vai esgotar na primeira semana.", "Vou de terceiro uniforme, sem dúvida."])
	if persona == "saudosista":
		pool.append("Bom mesmo era o uniforme dos anos 90, aquele sim.")
	return pool
