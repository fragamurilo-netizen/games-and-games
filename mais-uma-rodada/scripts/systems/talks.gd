class_name Talks
extends RefCounted
## Conversas procedurais: com jogadores, presidente, comissão técnica, torcida organizada,
## técnicos rivais e a imprensa (coletiva). Cada conversa é um dicionário que a interface
## mostra como um bate-papo:
##   {k, t, who, sub, p (jogador ou -1), lines [[quem, texto]], opts [{id, t, hint}], done, fx [resumo]}
## Quem fala: "npc" (o outro lado), "me" (você) e "info" (narração/efeito).
## O resultado de cada fala depende do contexto do save (forma, minutos, contrato, meta, caixa),
## da personalidade e da relação entre as partes, com um pouco de sorte.

const PLAYER_CD := 2 # jogos entre duas conversas com o mesmo jogador
const BOARD_CD := 4
const FANS_CD := 5
const STAFF_CD := 2
const COACH_CD := 5


static func _r(world: GameWorld) -> RandomNumberGenerator:
	return People.rng(world, 31)


static func _say(conv: Dictionary, who: String, text: String) -> void:
	conv["lines"].append([who, text])


static func _fx(conv: Dictionary, text: String) -> void:
	conv["fx"].append(text)


static func _new(kind: String, target: int, who: String, sub: String) -> Dictionary:
	return {"k": kind, "t": target, "who": who, "sub": sub, "p": -1, "lines": [], "opts": [], "done": false, "fx": [], "stage": "", "d": {}}


static func _finish(conv: Dictionary) -> void:
	conv["opts"] = []
	conv["done"] = true


static func _pick(world: GameWorld, arr: Array) -> String:
	return String(RngUtil.pick(_r(world), arr))


## Abre uma conversa. kind: "player" (t = id do jogador), "board", "staff" (t = índice do cargo),
## "fans", "coach" (t = id do clube), "press".
static func start(world: GameWorld, kind: String, target: int = -1) -> Dictionary:
	People.ensure(world)
	match kind:
		"player":
			return _player_start(world, target)
		"board":
			return _board_start(world)
		"staff":
			return _staff_start(world, target)
		"fans":
			return _fans_start(world)
		"coach":
			return _coach_start(world, target)
		"press":
			return _press_start(world)
	var c := _new(kind, target, "", "")
	_finish(c)
	return c


## Escolhe a opção `opt_id` e avança a conversa.
static func choose(world: GameWorld, conv: Dictionary, opt_id: String) -> void:
	if conv.get("done", false):
		return
	for o in conv["opts"]:
		if String(o["id"]) == opt_id:
			_say(conv, "me", String(o.get("say", o["t"])))
			break
	match String(conv["k"]):
		"player":
			_player_choose(world, conv, opt_id)
		"board":
			_board_choose(world, conv, opt_id)
		"staff":
			_staff_choose(world, conv, opt_id)
		"fans":
			_fans_choose(world, conv, opt_id)
		"coach":
			_coach_choose(world, conv, opt_id)
		"press":
			_press_choose(world, conv, opt_id)


static func _cooldown_left(world: GameWorld, key: String, cd: int) -> int:
	var last := int(People.data(world)["talk"].get(key, -99))
	return cd - (world.current_turn() - last)


static func _mark(world: GameWorld, key: String) -> void:
	People.data(world)["talk"][key] = world.current_turn()


# ---------------------------------------------------------------------------
# Jogador
# ---------------------------------------------------------------------------

static func _player_start(world: GameWorld, pid: int) -> Dictionary:
	var p := world.player(pid)
	var club := world.user_club()
	var conv := _new("player", pid, p.display_name() if p != null else "", "")
	if p == null or p.club_id != club.id:
		_say(conv, "info", "Ele não faz mais parte do elenco.")
		_finish(conv)
		return conv
	conv["p"] = p.id
	conv["sub"] = "%s · %d anos · %s" % [Pos.name_of(p.position), p.age(world.year), People.trust_label(People.trust_of(world, p)).to_lower()]
	var requested := false
	for q in People.requests(world):
		if String(q["k"]) == "player" and int(q["t"]) == pid:
			requested = true
	conv["d"]["req"] = requested
	if not requested and _cooldown_left(world, "p%d" % pid, PLAYER_CD) > 0:
		_say(conv, "npc", _pick(world, ["Professor, a gente acabou de conversar. Deixa eu mostrar em campo.", "De novo, professor? Tá tudo certo, pode ficar tranquilo."]))
		_finish(conv)
		return conv
	var t := People.trust_of(world, p)
	if requested:
		_say(conv, "npc", _complaint(world, p))
	elif t >= 70.0:
		_say(conv, "npc", _pick(world, ["Fala, professor! Pode falar.", "Opa, chefe. Tô à disposição.", "Bom te ver, professor. O que manda?"]))
	elif t >= 45.0:
		_say(conv, "npc", _pick(world, ["Pois não, professor?", "Pode falar, professor.", "Diga, professor."]))
	elif t >= 28.0:
		_say(conv, "npc", _pick(world, ["...Oi. O senhor queria falar comigo?", "Diga.", "Tô ouvindo."]))
	else:
		_say(conv, "npc", _pick(world, ["Se for para pedir paciência de novo, nem começa.", "Achei que o senhor nem lembrava que eu existia.", "Fala logo, professor."]))
	_player_topics(world, conv, p)
	return conv


static func _benched(world: GameWorld, p: Player) -> bool:
	var turn := world.current_turn()
	return turn >= 4 and p.stat(Player.S_STARTS) < turn * 0.4


static func _complaint(world: GameWorld, p: Player) -> String:
	if _benched(world, p):
		return _pick(world, ["Professor, eu não aguento mais ficar no banco. Quero entender o que está acontecendo.", "Eu treino, me dedico e nada de jogar. Assim fica difícil."])
	if p.contract_years_left(world.year) < 1:
		return "Meu contrato está acabando e ninguém do clube fala comigo. Eu preciso saber do meu futuro."
	return _pick(world, ["Sinto que o senhor não confia em mim. Precisava falar isso.", "O clima entre a gente não está bom, professor. Vamos conversar?"])


static func _player_topics(world: GameWorld, conv: Dictionary, p: Player) -> void:
	conv["stage"] = "topics"
	var opts: Array = [
		{"id": "elogiar", "t": "Elogiar o momento dele", "hint": "Dá confiança · soa falso se ele está mal"},
		{"id": "cobrar", "t": "Cobrar mais dele", "hint": "Pode acordar ou ofender"},
		{"id": "papel", "t": "Falar sobre o espaço no time", "hint": "Titularidade, banco e promessas"},
		{"id": "futuro", "t": "Falar do futuro no clube", "hint": "Contrato, ambição e planos"},
	]
	for b: Dictionary in People.bonds_of(world, p.id):
		if String(b["k"]) == People.BOND_RIVAL:
			var q := world.player(People.bond_other(b, p.id))
			if q != null:
				opts.append({"id": "rival:%d" % q.id, "t": "Falar da rixa com %s" % q.display_name(), "hint": "Tentar apaziguar o vestiário"})
				break
	if p.age(world.year) >= 27 and (p.has_trait("lider") or People.trust_of(world, p) >= 60.0):
		opts.append({"id": "lider", "t": "Pedir que lidere o grupo", "hint": "Um líder ajuda a segurar o vestiário"})
		var kid := _mentor_target(world, p)
		if kid != null:
			opts.append({"id": "mentor:%d" % kid.id, "t": "Pedir que apadrinhe %s" % kid.display_name(), "hint": "Mentor ajuda o garoto a evoluir"})
	if not p.heart_known and int(Dictionary(world.stats.get("hc_asked", {})).get(str(p.id), 0)) != world.year:
		opts.append({"id": "coracao", "t": "Perguntar para qual time ele torce", "hint": "Conversa leve · ele pode não querer dizer"})
	opts.append({"id": "bye", "t": "Encerrar a conversa", "hint": ""})
	conv["opts"] = opts


static func _mentor_target(world: GameWorld, p: Player) -> Player:
	for q: Player in world.squad(world.user_club()):
		if q.age(world.year) <= 20 and q.id != p.id:
			var has := false
			for b: Dictionary in People.bonds_of(world, q.id):
				if String(b["k"]) == People.BOND_MENTOR:
					has = true
			if not has:
				return q
	return null


static func _player_choose(world: GameWorld, conv: Dictionary, id: String) -> void:
	var p := world.player(int(conv["p"]))
	if p == null:
		_finish(conv)
		return
	if String(conv["stage"]) == "topics":
		if id == "bye":
			_say(conv, "npc", _pick(world, ["Beleza, professor.", "Tá certo.", "Valeu."]))
			_finish(conv)
			return
		_mark(world, "p%d" % p.id)
		People.clear_request(world, "player", p.id)
		conv["stage"] = id
		_player_topic(world, conv, p, id)
		return
	_player_outcome(world, conv, p, String(conv["stage"]), id)
	_finish(conv)


static func _player_topic(world: GameWorld, conv: Dictionary, p: Player, topic: String) -> void:
	var f := p.form()
	var opts: Array = []
	var head := topic.get_slice(":", 0)
	match head:
		"elogiar":
			if f >= 7.0:
				_say(conv, "npc", _pick(world, ["Valeu, professor. Tô me sentindo muito bem.", "Obrigado! A confiança faz diferença."]))
			elif f < 6.3:
				_say(conv, "npc", _pick(world, ["Elogio? Eu sei que não estou bem...", "O senhor está falando sério? Tô jogando mal."]))
			else:
				_say(conv, "npc", "Obrigado, professor. Dá para melhorar ainda.")
			opts = [
				{"id": "a", "t": "\"Continue assim, você é importante para o grupo.\""},
				{"id": "b", "t": "\"Sei que você pode render ainda mais.\""},
				{"id": "c", "t": "\"Os números mostram a sua evolução.\""}]
		"cobrar":
			if f >= 7.0:
				_say(conv, "npc", "Cobrar? Eu sou dos que mais estão rendendo aqui!")
			elif f < 6.3:
				_say(conv, "npc", _pick(world, ["Eu sei, professor. Não está saindo.", "Tô tentando, mas a fase não ajuda."]))
			else:
				_say(conv, "npc", "O que o senhor espera de mim?")
			opts = [
				{"id": "a", "t": "Na frente do grupo: \"Quero mais entrega.\""},
				{"id": "b", "t": "Em particular: \"Sei que você pode mais.\""},
				{"id": "c", "t": "\"Se não melhorar, perde a vaga.\""}]
		"papel":
			if _benched(world, p):
				_say(conv, "npc", "Eu queria entender por que não tenho jogado. O que falta?")
				opts = [
					{"id": "a", "t": "\"Você vai ter chances. Prometo.\"", "hint": "Promessa: titular em 2 dos próximos 5 jogos"},
					{"id": "b", "t": "\"Treine forte que a vaga vem.\""},
					{"id": "c", "t": "\"Hoje você não está nos meus planos.\"", "hint": "Sinceridade que dói"}]
			else:
				_say(conv, "npc", "Tô feliz jogando, professor. Quero manter isso.")
				opts = [
					{"id": "a", "t": "\"Você é peça-chave do meu time.\""},
					{"id": "b", "t": "\"Ninguém tem vaga garantida aqui.\""}]
		"futuro":
			if p.contract_years_left(world.year) < 1:
				_say(conv, "npc", "Meu contrato termina no fim da temporada. Ninguém me procurou ainda.")
			elif p.trait_sum("ambition") > 15.0:
				_say(conv, "npc", "Vou ser sincero: eu sonho em jogar num clube maior um dia.")
			else:
				_say(conv, "npc", "O que o senhor espera de mim nos próximos anos?")
			opts = [
				{"id": "a", "t": "\"Quero você aqui por muitos anos.\""},
				{"id": "b", "t": "\"Vamos falar de renovação no momento certo.\""},
				{"id": "c", "t": "\"Se aparecer uma boa proposta, a gente conversa.\""}]
		"rival":
			var q := world.player(int(topic.get_slice(":", 1)))
			var qn := q.display_name() if q != null else "ele"
			_say(conv, "npc", "Com o %s? %s" % [qn, _pick(world, ["Não dá, professor. Ele se acha o dono do time.", "Desde aquela discussão no treino a gente não se fala.", "Ele fala de mim pelas costas. Todo mundo sabe."])])
			opts = [
				{"id": "a", "t": "\"Vocês dois vão resolver isso hoje, na minha frente.\""},
				{"id": "b", "t": "\"Fora de campo não me importa. Dentro, quero parceria.\""},
				{"id": "c", "t": "\"Quem criar problema vai para o banco.\""}]
		"lider":
			if p.has_trait("lider"):
				_say(conv, "npc", "Pode contar comigo. Eu já faço isso.")
			else:
				_say(conv, "npc", "Eu? Liderar? Nunca pensei nisso...")
			opts = [
				{"id": "a", "t": "\"O grupo te respeita. Preciso da sua voz.\""},
				{"id": "b", "t": "\"Quero você como capitão.\""}]
		"mentor":
			var q := world.player(int(topic.get_slice(":", 1)))
			_say(conv, "npc", "O %s? Garoto bom. O que o senhor precisa?" % (q.display_name() if q != null else "menino"))
			opts = [
				{"id": "a", "t": "\"Fica de olho nele, dentro e fora de campo.\""},
				{"id": "b", "t": "\"Ensina ele a ser profissional como você.\""}]
		"coracao":
			var asked: Dictionary = world.stats.get("hc_asked", {})
			asked[str(p.id)] = world.year
			world.stats["hc_asked"] = asked
			_say(conv, "npc", "Pode perguntar, professor.")
			opts = [
				{"id": "a", "t": "\"Pra qual time você torcia quando era moleque?\""},
				{"id": "b", "t": "\"Tem algum clube no coração?\""}]
	conv["opts"] = opts


## Calcula a reação: base da opção + confiança + personalidade + sorte.
static func _player_outcome(world: GameWorld, conv: Dictionary, p: Player, topic: String, tone: String) -> void:
	if topic == "coracao":
		_say(conv, "npc", HeartClubs.ask(world, p))
		if p.heart_known and p.heart >= 0:
			_fx(conv, "Time de coração: %s." % world.club(p.heart).short_name)
		return
	var r := _r(world)
	var club := world.user_club()
	var t := People.trust_of(world, p)
	var f := p.form()
	var good := f >= 7.0
	var bad := f < 6.3
	var s := (t - 50.0) / 100.0 + r.randf_range(-0.3, 0.3) + (People.staff_level(world, "auxiliar") - 0.5) * 0.2
	var head := topic.get_slice(":", 0)
	var pos_fx := {}
	var neu_fx := {}
	var neg_fx := {}
	var pos_line := ""
	var neu_line := ""
	var neg_line := ""
	match head:
		"elogiar":
			match tone:
				"a":
					s += 0.6 if good else (-0.1 if bad else 0.3)
					if p.has_trait("timido"):
						s += 0.4
				"b":
					s += 0.3
					s += 0.3 if (p.has_trait("profissional") or p.has_trait("esforcado")) else 0.0
					s -= 0.2 if p.has_trait("acomodado") else 0.0
				"c":
					s += 0.4 if good else (-0.4 if bad else 0.1)
			pos_fx = {"morale": 6.0, "trust": 5.0}
			neu_fx = {"morale": 2.0, "trust": 1.0}
			neg_fx = {"trust": -3.0}
			pos_line = _pick(world, ["Valeu mesmo, professor. Vou retribuir em campo.", "Isso me dá moral. Obrigado!"])
			neu_line = "Obrigado, professor."
			neg_line = _pick(world, ["Não precisa tentar me agradar, professor.", "Tá bom... se o senhor diz."])
		"cobrar":
			match tone:
				"a":
					s += 0.1 if bad else (-0.8 if good else -0.2)
					s += 0.2 if (p.has_trait("profissional") or p.has_trait("lider")) else 0.0
					s -= 0.5 if p.has_trait("temperamental") else 0.0
					s -= 0.4 if p.has_trait("timido") else 0.0
				"b":
					s += 0.5 if bad else (-0.3 if good else 0.2)
					s += 0.2 if p.has_trait("timido") else 0.0
				"c":
					s += 0.2 if bad else (-0.6 if good else -0.1)
					s += 0.3 if (p.has_trait("esforcado") or p.has_trait("acomodado")) else 0.0
					s -= 0.4 if p.has_trait("temperamental") else 0.0
			pos_fx = {"morale": 4.0, "trust": 2.0, "team": 1.0 if tone == "a" else 0.0}
			neu_fx = {"morale": -1.0}
			neg_fx = {"trust": -8.0, "morale": -6.0, "team": -1.0 if tone == "a" else 0.0}
			pos_line = _pick(world, ["O senhor tem razão. Pode cobrar que eu respondo.", "Entendido. Vou dar a resposta no próximo jogo."])
			neu_line = "Vou pensar no que o senhor falou."
			neg_line = _pick(world, ["Isso não é justo, professor. Não esperava isso do senhor.", "Então é assim? Beleza."])
		"papel":
			if _benched(world, p):
				match tone:
					"a":
						s += 0.5
						s -= 0.3 if p.has_trait("mercenario") else 0.0
					"b":
						s += 0.4 if (p.has_trait("profissional") or p.has_trait("esforcado")) else 0.0
						s -= 0.4 if p.trait_sum("ambition") > 15.0 else 0.0
					"c":
						s -= 0.5
				pos_fx = {"morale": 8.0, "trust": 8.0}
				neu_fx = {"trust": 2.0}
				neg_fx = {"trust": -7.0, "morale": -6.0}
				if tone == "a":
					world.promises.append({"k": "minutes", "p": p.id, "until": world.current_turn() + 5, "need": 2, "s0": p.stat(Player.S_STARTS) + _cup_starts(p)})
					_fx(conv, "Promessa: %s titular em 2 dos próximos 5 jogos" % p.display_name())
				if tone == "c" and (p.trait_sum("ambition") > 10.0 or p.has_trait("mercenario")):
					p.transfer_listed = true
					p.asking_price = TransferManager.asking_price(world, p)
					_fx(conv, "%s pediu para ser negociado" % p.display_name())
				pos_line = "Fechado, professor. Vou estar pronto." if tone != "c" else "Pelo menos o senhor foi sincero. Respeito isso."
				neu_line = "Vou esperar. Mas não para sempre."
				neg_line = "Então vou procurar outro lugar para jogar." if tone == "c" else "Promessa a gente já ouviu muitas, professor."
			else:
				match tone:
					"a":
						s += 0.6
					"b":
						s -= 0.1
						s += 0.4 if p.has_trait("profissional") else 0.0
						s -= 0.4 if p.has_trait("temperamental") else 0.0
				pos_fx = {"morale": 5.0, "trust": 5.0}
				neu_fx = {"trust": 1.0}
				neg_fx = {"trust": -4.0, "morale": -3.0}
				pos_line = "Pode contar comigo, professor."
				neu_line = "Entendido."
				neg_line = "Achei que eu já tinha mostrado o meu valor."
		"futuro":
			var leal := p.has_trait("leal")
			var amb := p.trait_sum("ambition") > 15.0
			match tone:
				"a":
					s += 0.5 + (0.3 if leal else 0.0) - (0.3 if p.has_trait("mercenario") else 0.0)
				"b":
					s += 0.1
					s -= 0.3 if p.contract_years_left(world.year) < 1 else 0.0
				"c":
					s += 0.5 if amb else (-0.6 if leal else -0.1)
			pos_fx = {"trust": 6.0, "morale": 4.0}
			neu_fx = {"trust": 1.0}
			neg_fx = {"trust": -8.0, "morale": -5.0}
			pos_line = _pick(world, ["É isso que eu queria ouvir.", "Fico feliz, professor. Aqui é a minha casa."]) if tone != "c" else "Obrigado pela franqueza. Isso me deixa tranquilo."
			neu_line = "Tá bom. Vou aguardar."
			neg_line = "Então é assim que o clube me vê?" if tone == "c" else "Palavras não pagam contrato, professor."
		"rival":
			var q := world.player(int(topic.get_slice(":", 1)))
			match tone:
				"a":
					s += 0.2 + (0.3 if p.has_trait("lider") or (q != null and q.has_trait("lider")) else 0.0) - (0.3 if p.has_trait("temperamental") else 0.0)
				"b":
					s += 0.3
				"c":
					s += 0.0
			if q != null:
				var d: float = {"a": 25.0, "b": 12.0, "c": 8.0}.get(tone, 8.0)
				pos_fx = {"trust": 2.0, "bond": d, "q": q.id, "cohesion": 1.0}
				neu_fx = {"bond": 3.0, "q": q.id}
				neg_fx = {"bond": -8.0, "q": q.id, "trust": -6.0 if tone == "c" else -2.0}
			pos_line = "Tá certo, professor. Pelo time eu deixo isso de lado."
			neu_line = "Vou tentar. Mas não prometo nada."
			neg_line = "Com ele não tem conversa, professor."
		"lider":
			match tone:
				"a":
					s += 0.5 + (0.3 if p.has_trait("lider") else 0.0) - (0.4 if p.has_trait("timido") else 0.0)
				"b":
					s += 0.2 + (0.4 if p.has_trait("lider") else 0.0) + (0.2 if p.trait_sum("ambition") > 10.0 else 0.0) - (0.4 if p.has_trait("timido") else 0.0)
			pos_fx = {"trust": 6.0, "morale": 5.0, "team": 2.0}
			neu_fx = {"trust": 2.0}
			neg_fx = {"morale": -4.0}
			if tone == "b":
				pos_fx["captain"] = true
			pos_line = "Pode deixar. Ninguém vai largar o barco."
			neu_line = "Vou fazer a minha parte."
			neg_line = "Acho que não sou a pessoa certa para isso, professor."
		"mentor":
			var q := world.player(int(topic.get_slice(":", 1)))
			match tone:
				"a":
					s += 0.4
				"b":
					s += 0.5 if p.has_trait("profissional") else 0.0
			if q != null:
				pos_fx = {"trust": 3.0, "mentor": q.id}
				neu_fx = {"trust": 1.0}
				neg_fx = {"trust": -1.0}
			pos_line = "Deixa comigo. Vou cuidar dele como cuidaram de mim."
			neu_line = "Vou ver o que dá para fazer."
			neg_line = "Já tenho muita coisa para resolver, professor."
	var fx: Dictionary
	if s > 0.35:
		fx = pos_fx
		_say(conv, "npc", pos_line)
	elif s < -0.15:
		fx = neg_fx
		_say(conv, "npc", neg_line)
	else:
		fx = neu_fx
		_say(conv, "npc", neu_line)
	_apply_player_fx(world, conv, p, fx)
	if head == "rival" and s < -0.15 and p.has_trait("temperamental"):
		_fx(conv, "Ele saiu batendo a porta")


static func _apply_player_fx(world: GameWorld, conv: Dictionary, p: Player, fx: Dictionary) -> void:
	var club := world.user_club()
	var before := People.trust_of(world, p)
	if fx.has("trust"):
		People.add_trust(world, p, float(fx["trust"]))
	if fx.has("morale"):
		p.morale = clampf(p.morale + float(fx["morale"]), 0.0, 100.0)
		_fx(conv, "Moral de %s %s" % [p.display_name(), "subiu" if float(fx["morale"]) > 0 else "caiu"])
	var after := People.trust_of(world, p)
	if absf(after - before) >= 1.0:
		_fx(conv, "Confiança em você: %s (%d)" % [People.trust_label(after).to_lower(), int(round(after))])
	if float(fx.get("team", 0.0)) != 0.0:
		for q: Player in world.squad(club):
			if q.id != p.id:
				q.morale = clampf(q.morale + float(fx["team"]), 0.0, 100.0)
		_fx(conv, "O grupo %s" % ("gostou" if float(fx["team"]) > 0 else "sentiu o clima pesar"))
	if fx.has("bond") and fx.has("q"):
		var b := People.add_bond(world, p.id, int(fx["q"]), float(fx["bond"]))
		if not b.is_empty():
			_fx(conv, "Relação com %s: %s" % [world.player(int(fx["q"])).display_name(), People.bond_text(b).to_lower()])
	if fx.has("cohesion"):
		club.cohesion = minf(92.0, club.cohesion + float(fx["cohesion"]))
	if fx.get("captain", false):
		People.data(world)["captain"] = p.id
		_fx(conv, "%s é o novo capitão" % p.display_name())
		People.log_event(world, "%s virou capitão." % p.display_name())
	if fx.has("mentor"):
		var q := world.player(int(fx["mentor"]))
		if q != null and People.bond_between(world, p.id, q.id).is_empty():
			People.data(world)["bonds"].append({"a": p.id, "b": q.id, "k": People.BOND_MENTOR, "v": 45.0})
			q.dev_acc += 0.3
			_fx(conv, "%s agora é mentor de %s" % [p.display_name(), q.display_name()])


static func _cup_starts(p: Player) -> int:
	var n := 0
	for k in p.cup_stats:
		n += int(p.cup_stats[k][Player.C_APPS])
	return n


# ---------------------------------------------------------------------------
# Presidente
# ---------------------------------------------------------------------------

static func _board_start(world: GameWorld) -> Dictionary:
	var club := world.user_club()
	var pr := People.president(world, club.id)
	var st := People.pres_style(world, club.id)
	var conv := _new("board", -1, "Presidente %s" % String(pr["n"]), "%s · relação %s" % [String(st["name"]), People.rel_label(float(pr.get("rel", 50.0))).to_lower()])
	var summon := false
	for q in People.requests(world):
		if String(q["k"]) == "board":
			summon = true
	conv["d"]["summon"] = summon
	if summon:
		_say(conv, "npc", "Sente-se, %s. Os resultados não estão aparecendo e eu preciso de respostas. O que você vai fazer?" % world.manager_name)
		conv["stage"] = "summon"
		conv["opts"] = [
			{"id": "a", "t": "\"Vou mudar o time e dar chance a quem está bem.\""},
			{"id": "b", "t": "\"Preciso de reforços. O elenco não aguenta.\""},
			{"id": "c", "t": "\"Coloco o meu cargo à disposição.\"", "hint": "Tudo ou nada"}]
		return conv
	if _cooldown_left(world, "board", BOARD_CD) > 0:
		_say(conv, "npc", "Conversamos há pouco, %s. Vamos ver os resultados primeiro." % world.manager_name)
		_finish(conv)
		return conv
	var rel := float(pr.get("rel", 50.0))
	if rel >= 65.0:
		_say(conv, "npc", _pick(world, ["Entre, %s! Aceita um café?" % world.manager_name, "Meu treinador! Pode falar."]))
	elif rel >= 40.0:
		_say(conv, "npc", _pick(world, ["Pode falar. Estou com a agenda cheia hoje.", "Pois não, %s." % world.manager_name]))
	else:
		_say(conv, "npc", _pick(world, ["Seja breve.", "Espero que seja importante."]))
	conv["stage"] = "topics"
	var opts: Array = [
		{"id": "verba", "t": "Pedir mais dinheiro para contratações", "hint": "Hoje: %s" % Fmt.money(club.transfer_budget)},
		{"id": "folha", "t": "Pedir aumento do teto salarial", "hint": "Hoje: %s/mês" % Fmt.money(club.wage_budget)},
		{"id": "facilities", "t": "Pedir investimento no CT", "hint": "Centro de treinamento %d/100" % club.facilities},
		{"id": "youth", "t": "Pedir investimento na base", "hint": "Base %d/100" % club.youth_level},
		{"id": "staff", "t": "Pedir mais verba para a comissão", "hint": "Teto hoje: %s/mês" % Fmt.money(People.staff_budget(world))},
		{"id": "cargo", "t": "Perguntar sobre a sua situação", "hint": "Ele diz o que pensa"},
	]
	if club.board_confidence < 50.0:
		opts.append({"id": "tempo", "t": "Pedir tempo e paciência", "hint": "Pode segurar o cargo por alguns jogos"})
	opts.append({"id": "bye", "t": "Encerrar a reunião", "hint": ""})
	conv["opts"] = opts
	return conv


## Chance-base de o presidente dizer sim.
static func _board_base(world: GameWorld) -> float:
	var club := world.user_club()
	var s := 0.3 + (club.board_confidence - 50.0) / 100.0 + (People.pres_rel(world) - 50.0) / 150.0
	var rev := float(FinanceManager.expected_revenue(club))
	if club.balance > rev * 0.2:
		s += 0.15
	elif club.balance < 0:
		s -= 0.4
	return s


static func _board_choose(world: GameWorld, conv: Dictionary, id: String) -> void:
	var club := world.user_club()
	var pr := People.president(world, club.id)
	var style := String(pr.get("st", ""))
	var r := _r(world)
	match String(conv["stage"]):
		"summon":
			People.clear_request(world, "board", -1)
			_mark(world, "board")
			var s := _board_base(world) + r.randf_range(-0.3, 0.3)
			match id:
				"a":
					s += 0.2
					if s > 0.1:
						_say(conv, "npc", "Pois bem. Mudanças, então. Estou de olho.")
						club.board_confidence = clampf(club.board_confidence + 3.0, 0.0, 100.0)
						People.add_pres_rel(world, 2.0)
						_fx(conv, "Confiança da diretoria +3")
					else:
						_say(conv, "npc", "Já ouvi isso antes. Quero ver em campo.")
						People.add_pres_rel(world, -2.0)
				"b":
					s += 0.15 if style == "vaidoso" else (-0.2 if style == "empresario" else 0.0)
					if s > 0.25 and club.balance > 0:
						var add := int(maxf(club.transfer_budget * 0.2, FinanceManager.expected_revenue(club) * 0.03))
						club.transfer_budget += add
						_say(conv, "npc", "Vou liberar %s. Mas agora não há mais desculpas." % Fmt.money(add))
						_fx(conv, "Verba para contratações +%s" % Fmt.money(add))
						club.board_confidence = clampf(club.board_confidence - 2.0, 0.0, 100.0)
					else:
						_say(conv, "npc", "Reforços? Com esses resultados? Trabalhe com o que tem.")
						People.add_pres_rel(world, -3.0)
						_fx(conv, "Relação com o presidente piorou")
				"c":
					if club.board_confidence < 22.0 and r.randf() < 0.5 and world.difficulty > 0:
						_say(conv, "npc", "...Aceito. Obrigado pelo trabalho, %s. O clube segue outro caminho." % world.manager_name)
						People.fire_user(world, "cargo à disposição")
						_fx(conv, "Você não é mais o técnico do %s" % club.short_name)
					else:
						_say(conv, "npc", "Não. Gostei da sua hombridade. Continue, mas quero reação.")
						People.add_pres_rel(world, 6.0)
						club.board_confidence = clampf(club.board_confidence + 5.0, 0.0, 100.0)
						_fx(conv, "Confiança da diretoria +5 · relação com o presidente melhorou")
			_finish(conv)
			return
		"topics":
			if id == "bye":
				_say(conv, "npc", "Bom trabalho. Até a próxima.")
				_finish(conv)
				return
			_mark(world, "board")
			if id == "cargo":
				_say(conv, "npc", _job_assessment(world))
				People.add_pres_rel(world, 1.0)
				_finish(conv)
				return
			conv["stage"] = id
			var line := ""
			match id:
				"verba", "folha":
					line = "Mais dinheiro? Me convença."
				"facilities", "youth":
					line = "Investimento é coisa séria. Por que agora?"
				"staff":
					line = "A comissão já custa caro. O que você quer?"
				"tempo":
					line = "Tempo é o que menos temos. Por que eu deveria esperar?"
			_say(conv, "npc", line)
			if id == "tempo":
				conv["opts"] = [
					{"id": "a", "t": "\"Me dê quatro jogos e o time reage.\""},
					{"id": "b", "t": "\"A meta é alta demais para esse elenco.\""},
					{"id": "c", "t": "\"A torcida ainda está comigo.\""}]
			else:
				conv["opts"] = [
					{"id": "a", "t": "\"Com isso a meta fica garantida.\"", "hint": "Promessa ousada"},
					{"id": "b", "t": "\"Os números do clube permitem.\""},
					{"id": "c", "t": "\"A torcida está cobrando.\""}]
			return
	# Segunda etapa: pedido com argumento
	var ask := String(conv["stage"])
	var s := _board_base(world) + r.randf_range(-0.3, 0.3)
	match id:
		"a":
			s += 0.15 if style in ["vaidoso", "exigente"] else 0.05
		"b":
			s += 0.3 if style == "empresario" and club.balance > 0 else (-0.1 if club.balance < 0 else 0.0)
		"c":
			s += (People.fan_support(world) - 50.0) / 100.0 + (0.25 if style == "populista" else 0.0)
	var yes := false
	match ask:
		"verba":
			yes = s > 0.3
			if yes:
				var add := int(maxf(club.transfer_budget * 0.25, FinanceManager.expected_revenue(club) * 0.04))
				club.transfer_budget += add
				_say(conv, "npc", "Está bem. Libero mais %s. Não me decepcione." % Fmt.money(add))
				_fx(conv, "Verba para contratações: %s" % Fmt.money(club.transfer_budget))
				People.add_pres_rel(world, -1.0)
		"folha":
			yes = s > 0.35
			if yes:
				club.wage_budget = int(club.wage_budget * 1.06)
				_say(conv, "npc", "Um pequeno aumento no teto. Use com cabeça.")
				_fx(conv, "Teto salarial: %s/mês" % Fmt.money(club.wage_budget))
				People.add_pres_rel(world, -1.0)
		"facilities", "youth":
			yes = s > 0.45
			if yes:
				if ask == "facilities":
					club.facilities = mini(100, club.facilities + 3)
				else:
					club.youth_level = mini(100, club.youth_level + 3)
				_say(conv, "npc", "Consegui um parceiro para bancar a obra. Pode anunciar.")
				_fx(conv, "%s +3 (sem custo para o caixa)" % ("Centro de treinamento" if ask == "facilities" else "Categorias de base"))
		"staff":
			yes = s > 0.3
			if yes:
				People.data(world)["sbud"] = float(People.data(world).get("sbud", 0.0)) + 0.02
				_say(conv, "npc", "Pode reforçar a comissão. Quero profissionais de verdade.")
				_fx(conv, "Teto da comissão: %s/mês" % Fmt.money(People.staff_budget(world)))
		"tempo":
			yes = s > 0.25
			if yes:
				People.data(world)["grace"] = world.current_turn() + 4
				club.board_confidence = clampf(club.board_confidence + 4.0, 0.0, 100.0)
				_say(conv, "npc", "Quatro jogos. Nem um a mais.")
				_fx(conv, "A diretoria não vai te demitir nos próximos 4 jogos · confiança +4")
	if not yes:
		_say(conv, "npc", _pick(world, ["Não. Não é o momento.", "A resposta é não. Traga resultados e conversamos.", "Não vejo sentido nisso agora."]))
		People.add_pres_rel(world, -3.0)
		if ask == "tempo":
			club.board_confidence = clampf(club.board_confidence - 2.0, 0.0, 100.0)
		_fx(conv, "Relação com o presidente piorou")
	elif id == "a" and ask != "tempo":
		People.data(world)["pledge"] = world.year
		_fx(conv, "Você prometeu cumprir a meta")
	_finish(conv)


static func _job_assessment(world: GameWorld) -> String:
	var club := world.user_club()
	var conf := club.board_confidence
	var goal := SeasonManager.goal_of(world, club.id)
	var sup := People.fan_support(world)
	var fans := " A torcida está com você, e isso pesa." if sup >= 70.0 else (" A arquibancada já pede a sua cabeça." if sup <= 30.0 else "")
	if conf >= 75.0:
		return "Seu cargo está garantido. A meta (%s) está bem encaminhada.%s" % [String(goal[0]).to_lower(), fans]
	if conf >= 55.0:
		return "Estamos satisfeitos, mas atentos. A meta é %s.%s" % [String(goal[0]).to_lower(), fans]
	if conf >= BoardManager.ULTIMATUM:
		return "Vou ser franco: o conselho está preocupado. Precisamos de uma sequência boa.%s" % fans
	return "Não vou mentir: se nada mudar logo, vamos trocar o comando.%s" % fans


# ---------------------------------------------------------------------------
# Comissão técnica
# ---------------------------------------------------------------------------

static func _staff_start(world: GameWorld, role_idx: int) -> Dictionary:
	var role: String = People.STAFF_ORDER[clampi(role_idx, 0, People.STAFF_ORDER.size() - 1)]
	var s: Dictionary = People.staff(world).get(role, {})
	var conv := _new("staff", role_idx, String(s.get("n", "")), String(People.STAFF_ROLES[role]["name"]))
	conv["d"]["role"] = role
	if _cooldown_left(world, "s:" + role, STAFF_CD) > 0:
		_say(conv, "npc", "Ainda estou fechando o relatório desta semana, professor.")
		_finish(conv)
		return conv
	_mark(world, "s:" + role)
	for line in _staff_report(world, role):
		_say(conv, "npc", line)
	conv["opts"] = [
		{"id": "a", "t": "\"Bom trabalho. Sigo a sua avaliação.\"", "hint": "Sintonia com a comissão sobe"},
		{"id": "b", "t": "\"Quero relatórios mais diretos.\"", "hint": "Ele fica incomodado"},
		{"id": "bye", "t": "\"Obrigado.\"", "hint": ""}]
	return conv


static func _staff_report(world: GameWorld, role: String) -> Array:
	var club := world.user_club()
	var squad := world.squad(club)
	var out: Array = []
	match role:
		"auxiliar":
			var worst: Player = null
			var best_out: Player = null
			for p: Player in squad:
				if worst == null or People.trust_of(world, p) < People.trust_of(world, worst):
					worst = p
				if p.form() >= 7.0 and p.squad_status >= Player.STATUS_ROTATION and (best_out == null or p.form() > best_out.form()):
					best_out = p
			if worst != null and People.trust_of(world, worst) < 40.0:
				out.append("O %s anda distante do grupo. Acho que vale uma conversa." % worst.display_name())
			var rivals: Array = People.data(world)["bonds"].filter(func(b): return String(b["k"]) == People.BOND_RIVAL)
			if not rivals.is_empty():
				var b: Dictionary = rivals[0]
				var pa := world.player(int(b["a"]))
				var pb := world.player(int(b["b"]))
				if pa != null and pb != null:
					out.append("%s e %s não se bicam. Se colocar os dois juntos, fique de olho." % [pa.display_name(), pb.display_name()])
			if best_out != null:
				out.append("O %s está voando nos treinos. Merece uma chance." % best_out.display_name())
			out.append("Entrosamento do time: %d/100." % int(club.cohesion))
		"preparador":
			var tired: Array = []
			for p: Player in squad:
				if p.condition < 80.0 and not p.is_injured():
					tired.append(p.display_name())
			out.append("Estão no limite: %s." % ", ".join(tired.slice(0, 4)) if not tired.is_empty() else "O grupo está inteiro fisicamente.")
			out.append("Treino atual: %s, intensidade %s." % [TrainingManager.focus_of(club)["name"], String(TrainingManager.intensity_of(club)["name"]).to_lower()])
		"medico":
			var hurt: Array = []
			var prone: Player = null
			for p: Player in squad:
				if p.is_injured():
					hurt.append("%s (%d sem.)" % [p.display_name(), p.injury_weeks])
				elif p.injury_prone >= 15 and (prone == null or p.injury_prone > prone.injury_prone):
					prone = p
			out.append("No departamento médico: %s." % ", ".join(hurt) if not hurt.is_empty() else "Ninguém no departamento médico.")
			if prone != null:
				out.append("Cuidado com o %s: tem histórico de lesões." % prone.display_name())
		"goleiros":
			var gks: Array = squad.filter(func(p): return p.position == Pos.GK)
			gks.sort_custom(func(a, b): return a.overall > b.overall)
			for p: Player in gks.slice(0, 3):
				out.append("%s: %d de geral, forma %.1f." % [p.display_name(), p.overall, p.form()])
		"olheiro":
			var need: Array = []
			for nd in TransferManager.squad_needs(world, club):
				need.append_array(TransferManager.FAMILIES[int(nd["fam"])][0])
			var best: Player = null
			for p: Player in world.free_agents():
				if p.age(world.year) <= 31 and (need.is_empty() or need.has(p.position)) and (best == null or p.overall > best.overall):
					best = p
			if best != null:
				out.append("Sem clube e disponível: %s (%s, %d anos), nível %d." % [best.display_name(), Pos.name_of(best.position), best.age(world.year), best.overall])
			if not need.is_empty():
				out.append("Nossa carência: %s." % ", ".join(need.slice(0, 3).map(func(x): return Pos.name_of(int(x)))))
			out.append("Estou afinando as avaliações de jogadores de outros clubes.")
		"base":
			var kid: Player = YouthManager.best_prospect(world, club)
			if kid != null:
				out.append("O melhor da base é o %s, %d anos. Tem futuro." % [kid.display_name(), kid.age(world.year)])
			out.append("Temos %d garotos nas categorias de base." % world.academy.size())
	if out.is_empty():
		out.append("Tudo sob controle, professor.")
	return out


static func _staff_choose(world: GameWorld, conv: Dictionary, id: String) -> void:
	var role := String(conv["d"].get("role", ""))
	match id:
		"a":
			People.add_staff_rel(world, role, 4.0)
			_say(conv, "npc", "Obrigado, professor. Seguimos juntos.")
			_fx(conv, "Sintonia com %s melhorou" % conv["who"])
		"b":
			People.add_staff_rel(world, role, -3.0)
			_say(conv, "npc", "...Entendido.")
			_fx(conv, "%s ficou incomodado" % conv["who"])
		_:
			_say(conv, "npc", "Às ordens.")
	_finish(conv)


# ---------------------------------------------------------------------------
# Torcida
# ---------------------------------------------------------------------------

static func _fans_start(world: GameWorld) -> Dictionary:
	var fans: Dictionary = People.data(world)["fans"]
	var conv := _new("fans", -1, "%s (%s)" % [String(fans.get("leader", "Líder")), String(fans.get("group", "organizada"))], "Apoio: %s" % People.support_label(People.fan_support(world)).to_lower())
	if _cooldown_left(world, "fans", FANS_CD) > 0:
		_say(conv, "npc", "Professor, a gente já conversou. Agora é com vocês em campo.")
		_finish(conv)
		return conv
	var sup := People.fan_support(world)
	if sup >= 65.0:
		_say(conv, "npc", "Professor! A arquibancada está contigo. O que precisa?")
	elif sup >= 40.0:
		_say(conv, "npc", "A gente quer ouvir o senhor. A torcida está dividida.")
	else:
		_say(conv, "npc", "Veio dar satisfação? A paciência acabou, professor.")
	conv["opts"] = [
		{"id": "a", "t": "\"Preciso de vocês apoiando nos 90 minutos.\""},
		{"id": "b", "t": "\"A responsabilidade pelos resultados é minha.\""},
		{"id": "c", "t": "\"A pressão está atrapalhando os jogadores.\""},
		{"id": "bye", "t": "Ir embora", "hint": ""}]
	return conv


static func _fans_choose(world: GameWorld, conv: Dictionary, id: String) -> void:
	if id == "bye":
		_say(conv, "npc", "...")
		_finish(conv)
		return
	_mark(world, "fans")
	var club := world.user_club()
	var r := _r(world)
	var sup := People.fan_support(world)
	var s := (sup - 45.0) / 100.0 + (club.fan_mood - 50.0) / 150.0 + r.randf_range(-0.3, 0.3)
	match id:
		"a":
			s += 0.2
			if s > 0.1:
				People.add_support(world, 6.0)
				club.fan_mood = clampf(club.fan_mood + 4.0, 0.0, 100.0)
				_say(conv, "npc", "Pode deixar. Domingo o estádio vai tremer!")
				_fx(conv, "Apoio da torcida subiu")
			else:
				People.add_support(world, -3.0)
				_say(conv, "npc", "Apoio a gente dá quando o time merece.")
				_fx(conv, "A torcida não comprou o discurso")
		"b":
			s += 0.35
			if s > 0.1:
				People.add_support(world, 7.0)
				club.board_confidence = clampf(club.board_confidence + 1.0, 0.0, 100.0)
				_say(conv, "npc", "Pelo menos tem coragem de assumir. Respeito isso.")
				_fx(conv, "Apoio da torcida subiu · diretoria gostou da postura")
			else:
				People.add_support(world, -2.0)
				_say(conv, "npc", "Assumir é fácil. Queremos resultado.")
		"c":
			People.add_support(world, -6.0)
			for p: Player in world.squad(club):
				People.add_trust(world, p, 2.0)
			_say(conv, "npc", "Então a culpa é nossa agora? Tá bom, professor...")
			_fx(conv, "A torcida não gostou · o elenco sentiu-se protegido")
			People.log_event(world, "Você enfrentou a organizada para proteger o elenco.")
	_finish(conv)


# ---------------------------------------------------------------------------
# Técnico rival
# ---------------------------------------------------------------------------

static func _coach_start(world: GameWorld, club_id: int) -> Dictionary:
	var co := People.coach_of(world, club_id)
	var c := world.club(club_id)
	var conv := _new("coach", club_id, String(co.get("n", "")), "Técnico do %s" % (c.short_name if c != null else ""))
	if co.is_empty():
		_finish(conv)
		return conv
	if _cooldown_left(world, "c%d" % int(co["id"]), COACH_CD) > 0:
		_say(conv, "info", "Vocês se falaram há pouco tempo.")
		_finish(conv)
		return conv
	var rel := People.coach_rel(world, int(co["id"]))
	_say(conv, "info", "Você liga para %s." % String(co["n"]))
	if rel <= -40.0:
		_say(conv, "npc", "O que você quer?")
	elif rel >= 30.0:
		_say(conv, "npc", "Grande %s! Quanto tempo." % world.manager_name)
	else:
		_say(conv, "npc", "Alô? Ah, %s. Tudo bem?" % world.manager_name)
	conv["opts"] = [
		{"id": "a", "t": "Elogiar o trabalho dele", "say": "\"Parabéns pelo trabalho. Seu time joga bem.\""},
		{"id": "b", "t": "Provocar para o próximo encontro", "say": "\"Aproveita enquanto dá. No confronto direto a gente acerta as contas.\""},
		{"id": "bye", "t": "Desligar", "hint": ""}]
	return conv


static func _coach_choose(world: GameWorld, conv: Dictionary, id: String) -> void:
	var co := People.coach_of(world, int(conv["t"]))
	if co.is_empty() or id == "bye":
		_finish(conv)
		return
	_mark(world, "c%d" % int(co["id"]))
	var rel := People.coach_rel(world, int(co["id"]))
	match id:
		"a":
			if rel <= -40.0:
				_say(conv, "npc", "Guarda os elogios. Nos vemos em campo.")
				People.add_coach_rel(world, int(co["id"]), 3.0)
			else:
				_say(conv, "npc", "Obrigado! Vindo de você, vale muito.")
				People.add_coach_rel(world, int(co["id"]), 8.0)
			_fx(conv, "Relação com %s: %s" % [String(co["n"]), People.coach_rel_label(People.coach_rel(world, int(co["id"]))).to_lower()])
		"b":
			_say(conv, "npc", "Ha! Veremos. Anota aí o placar.")
			People.add_coach_rel(world, int(co["id"]), -10.0)
			People.add_support(world, 1.0)
			_fx(conv, "Rivalidade com %s esquentou" % String(co["n"]))
	_finish(conv)


# ---------------------------------------------------------------------------
# Coletiva de imprensa
# ---------------------------------------------------------------------------

static func _press_start(world: GameWorld) -> Dictionary:
	var conv := _new("press", -1, "Coletiva de imprensa", "")
	var js := People.journalists(world)
	var qs := _press_questions(world)
	if js.is_empty() or qs.is_empty():
		_say(conv, "info", "Nenhum jornalista apareceu hoje.")
		_finish(conv)
		return conv
	People.data(world)["press"]["last"] = world.current_turn()
	People.clear_request(world, "press", -1)
	conv["d"]["qs"] = qs
	conv["d"]["i"] = 0
	conv["d"]["head"] = ""
	conv["sub"] = "%d perguntas" % qs.size()
	_say(conv, "info", "Sala cheia. Microfones ligados.")
	_press_ask(world, conv)
	return conv


static func _press_ask(world: GameWorld, conv: Dictionary) -> void:
	var qs: Array = conv["d"]["qs"]
	var i := int(conv["d"]["i"])
	var q: Dictionary = qs[i]
	var j := People.journalist(world, int(q["j"]))
	conv["who"] = "%s (%s)" % [String(j.get("n", "Repórter")), String(j.get("o", ""))]
	_say(conv, "npc", String(q["q"]))
	var opts: Array = []
	for k in Array(q["o"]).size():
		opts.append({"id": str(k), "t": String(q["o"][k]["t"])})
	conv["opts"] = opts


static func _press_choose(world: GameWorld, conv: Dictionary, id: String) -> void:
	var qs: Array = conv["d"]["qs"]
	var i := int(conv["d"]["i"])
	var q: Dictionary = qs[i]
	var o: Dictionary = q["o"][clampi(int(id), 0, Array(q["o"]).size() - 1)]
	var fx: Dictionary = o.get("fx", {})
	_apply_press_fx(world, conv, fx, int(q["j"]))
	if fx.get("head", false) or String(conv["d"]["head"]) == "":
		conv["d"]["head"] = String(o["t"])
	i += 1
	conv["d"]["i"] = i
	if i < qs.size():
		_press_ask(world, conv)
		return
	_say(conv, "info", "Fim da coletiva.")
	var club := world.user_club()
	NewsManager.post_raw(world, "%s: %s" % [world.manager_name, String(conv["d"]["head"])],
		"Na coletiva desta semana, o treinador do %s respondeu a %d perguntas." % [club.short_name, qs.size()], club.id, -1, NewsEvent.IMP_NORMAL, "imprensa")
	_finish(conv)


static func _apply_press_fx(world: GameWorld, conv: Dictionary, fx: Dictionary, jid: int) -> void:
	var club := world.user_club()
	var jd := float(fx.get("jrel", 1.0))
	People.add_journalist_rel(world, jid, jd)
	if jd <= -2.0:
		_say(conv, "info", "O repórter não gostou da resposta.")
	if fx.has("sup"):
		People.add_support(world, float(fx["sup"]))
		_fx(conv, "Torcida %s" % ("aprovou" if float(fx["sup"]) > 0 else "não gostou"))
	if fx.has("mood"):
		club.fan_mood = clampf(club.fan_mood + float(fx["mood"]), 0.0, 100.0)
	if fx.has("board"):
		club.board_confidence = clampf(club.board_confidence + float(fx["board"]), 0.0, 100.0)
		_fx(conv, "Diretoria %s" % ("gostou" if float(fx["board"]) > 0 else "não gostou"))
	if fx.has("pres"):
		People.add_pres_rel(world, float(fx["pres"]))
		_fx(conv, "Presidente %s" % ("gostou" if float(fx["pres"]) > 0 else "ficou irritado"))
	if fx.has("team"):
		for p: Player in world.squad(club):
			p.morale = clampf(p.morale + float(fx["team"]), 0.0, 100.0)
		_fx(conv, "Elenco %s" % ("motivado" if float(fx["team"]) > 0 else "incomodado"))
	for key in fx:
		var k := String(key)
		if k.begins_with("trust:"):
			var p := world.player(int(k.get_slice(":", 1)))
			if p != null:
				People.add_trust(world, p, float(fx[key]))
				_fx(conv, "%s %s" % [p.display_name(), "gostou" if float(fx[key]) > 0 else "não gostou"])
		elif k.begins_with("crel:"):
			People.add_coach_rel(world, int(k.get_slice(":", 1)), float(fx[key]))
			_fx(conv, "Técnico rival %s" % ("agradeceu" if float(fx[key]) > 0 else "vai responder"))
		elif k.begins_with("bond:"):
			People.add_bond(world, int(k.get_slice(":", 1)), int(k.get_slice(":", 2)), float(fx[key]))
		elif k.begins_with("promise:"):
			var p := world.player(int(k.get_slice(":", 1)))
			if p != null:
				world.promises.append({"k": "minutes", "p": p.id, "until": world.current_turn() + 5, "need": 2, "s0": p.stat(Player.S_STARTS) + _cup_starts(p)})
				_fx(conv, "Promessa pública: %s titular em 2 dos próximos 5 jogos" % p.display_name())
	if fx.get("bold", false):
		world.stats["press_bold"] = world.current_turn()
		_fx(conv, "Se perder o próximo jogo, a frase volta para cobrar")


## Perguntas conforme o momento: clássico, sequência, cargo, vestiário, base, mercado, ex-jogadores.
static func _press_questions(world: GameWorld) -> Array:
	var club := world.user_club()
	var r := _r(world)
	var js := People.journalists(world)
	if js.is_empty():
		return []
	var pick_j := func(tone: String) -> int:
		for j: Dictionary in js:
			if String(j["t"]) == tone:
				return int(j["id"])
		return int(RngUtil.pick(r, js)["id"])
	var qs: Array = []
	var nf := FixtureManager.next_fixture_for(world, club.id)
	var opp: Club = world.club(nf.opponent_of(club.id)) if nf != null else null
	var oc: Dictionary = People.coach_of(world, opp.id) if opp != null else {}
	var ocn := String(oc.get("n", "o técnico deles"))
	if opp != null and MatchEngine.is_derby(world, nf.home, nf.away):
		var qtext := "Clássico contra o %s. %s disse que vocês chegam pressionados. O que responde?" % [opp.short_name, ocn]
		var grudge := Rivalry.last_grudge(world, club.id, opp.id)
		if Rivalry.is_emergent_derby(world, club.id, opp.id) and not grudge.is_empty():
			qtext = "Esse jogo virou clássico. A torcida ainda fala de \"%s\". %s diz que vocês chegam pressionados. O que responde?" % [String(grudge["t"]), ocn]
		qs.append({"j": pick_j.call("bairrista"), "q": qtext, "o": [
			{"t": "\"Pressionado está ele. Domingo a gente mostra.\"", "fx": {"sup": 3.0, "team": 3.0, "crel:%d" % int(oc.get("id", -1)): -10.0, "bold": true, "head": true, "jrel": 3.0}},
			{"t": "\"Respeito o %s. Clássico se decide em campo.\"" % ocn, "fx": {"board": 2.0, "crel:%d" % int(oc.get("id", -1)): 5.0}},
			{"t": "\"Não vou alimentar polêmica.\"", "fx": {"jrel": -3.0}}]})
	elif not oc.is_empty() and People.coach_rel(world, int(oc["id"])) <= -30.0:
		qs.append({"j": pick_j.call("sensacionalista"), "q": "%s criticou o seu estilo de jogo nesta semana. Quer responder?" % ocn, "o": [
			{"t": "\"Ele deveria cuidar do time dele.\"", "fx": {"sup": 2.0, "crel:%d" % int(oc["id"]): -8.0, "head": true, "jrel": 3.0}},
			{"t": "\"Cada um tem a sua ideia. Respeito.\"", "fx": {"crel:%d" % int(oc["id"]): 6.0, "board": 1.0}},
			{"t": "\"Nem vi. Próxima pergunta.\"", "fx": {"jrel": -2.0}}]})
	if club.streak_losses >= 2:
		var worst: Player = null
		for p: Player in world.squad(club):
			if p.squad_status <= Player.STATUS_STARTER and (worst == null or p.form() < worst.form()):
				worst = p
		var o2 := {"team": -4.0, "board": 2.0, "head": true}
		if worst != null:
			o2["trust:%d" % worst.id] = -6.0
		qs.append({"j": pick_j.call("critico"), "q": "São %d derrotas seguidas. O que está acontecendo com o %s?" % [club.streak_losses, club.short_name], "o": [
			{"t": "\"A responsabilidade é minha.\"", "fx": {"sup": 3.0, "team": 2.0, "board": 1.0}},
			{"t": "\"Alguns jogadores precisam render mais.\"", "fx": o2},
			{"t": "\"Faltou sorte. O trabalho está bom.\"", "fx": {"sup": -2.0, "jrel": -2.0}}]})
	elif club.streak_wins >= 3:
		qs.append({"j": pick_j.call("amigavel"), "q": "%d vitórias seguidas. Dá para sonhar alto?" % club.streak_wins, "o": [
			{"t": "\"Por que não? Somos candidatos.\"", "fx": {"sup": 4.0, "mood": 3.0, "head": true, "jrel": 2.0}},
			{"t": "\"Pé no chão. Jogo a jogo.\"", "fx": {"board": 2.0}},
			{"t": "\"Esse grupo não tem limite.\"", "fx": {"team": 3.0}}]})
	var unhappy: Player = null
	for p: Player in world.squad(club):
		if People.trust_of(world, p) < 35.0 and p.overall >= 55 and (unhappy == null or p.overall > unhappy.overall):
			unhappy = p
	if unhappy != null:
		qs.append({"j": pick_j.call("sensacionalista"), "q": "Dizem que %s está insatisfeito com você. Ele tem espaço no time?" % unhappy.display_name(), "o": [
			{"t": "\"Conto com ele. Vai ter chances.\"", "fx": {"trust:%d" % unhappy.id: 6.0, "promise:%d" % unhappy.id: true}},
			{"t": "\"Quem decide a escalação sou eu.\"", "fx": {"trust:%d" % unhappy.id: -6.0, "board": 1.0, "head": true}},
			{"t": "\"Isso a gente resolve internamente.\"", "fx": {"trust:%d" % unhappy.id: 2.0, "jrel": -2.0}}]})
	if club.board_confidence < 40.0:
		var lie := club.board_confidence < 30.0
		qs.append({"j": pick_j.call("critico"), "q": "O seu cargo corre risco?", "o": [
			{"t": "\"Tenho o apoio do presidente.\"", "fx": {"pres": -4.0 if lie else 2.0}},
			{"t": "\"Treinador vive de resultado. Vou buscar.\"", "fx": {"board": 1.0}},
			{"t": "\"Se quiserem me demitir, é só avisar.\"", "fx": {"sup": 2.0, "pres": -8.0, "head": true, "jrel": 3.0}}]})
	var rivals: Array = People.data(world)["bonds"].filter(func(b): return String(b["k"]) == People.BOND_RIVAL and float(b["v"]) <= -35.0)
	if not rivals.is_empty() and r.randf() < 0.6:
		var b: Dictionary = RngUtil.pick(r, rivals)
		var pa := world.player(int(b["a"]))
		var pb := world.player(int(b["b"]))
		if pa != null and pb != null:
			qs.append({"j": pick_j.call("sensacionalista"), "q": "Existe um racha entre %s e %s?" % [pa.display_name(), pb.display_name()], "o": [
				{"t": "\"Isso é invenção.\"", "fx": {"jrel": -3.0}},
				{"t": "\"Tivemos uma discussão e já resolvemos.\"", "fx": {"bond:%d:%d" % [pa.id, pb.id]: 6.0, "jrel": 2.0}},
				{"t": "\"Os dois sabem o que eu penso.\"", "fx": {"trust:%d" % pa.id: -2.0, "trust:%d" % pb.id: -2.0, "head": true}}]})
	var kid: Player = null
	for p: Player in world.squad(club):
		if p.age(world.year) <= 20 and p.potential >= 70 and p.stat(Player.S_STARTS) < 3 and (kid == null or p.potential > kid.potential):
			kid = p
	if kid != null and r.randf() < 0.5:
		qs.append({"j": pick_j.call("bairrista"), "q": "A torcida pede %s no time. Ele vai ter chance?" % kid.display_name(), "o": [
			{"t": "\"Ele está pronto. Vai jogar.\"", "fx": {"trust:%d" % kid.id: 6.0, "sup": 2.0, "promise:%d" % kid.id: true, "head": true}},
			{"t": "\"Tem que ter paciência com garoto.\"", "fx": {"trust:%d" % kid.id: -2.0, "board": 1.0}}]})
	if opp != null:
		for p: Player in world.squad(opp):
			if People.has_trust(world, p.id) and People.trust_of(world, p) != 50.0:
				var t := People.trust_of(world, p)
				qs.append({"j": pick_j.call("analitico"), "q": "Você reencontra %s, que já trabalhou com você. Como foi a relação?" % p.display_name(), "o": [
					{"t": "\"Grande profissional. Desejo sorte, menos contra nós.\"", "fx": {"trust:%d" % p.id: 5.0, "jrel": 1.0}},
					{"t": "\"Página virada.\"", "fx": {}},
					{"t": "\"Quem quis sair foi ele.\"" if t < 45.0 else "\"Ele sabe o quanto brigamos juntos.\"", "fx": {"sup": 2.0, "head": true, "trust:%d" % p.id: -5.0 if t < 45.0 else 3.0}}]})
				break
	var offer := People.job_offer(world)
	if not offer.is_empty():
		var oc2 := world.club(int(offer["c"]))
		qs.append({"j": pick_j.call("sensacionalista"), "q": "O %s procurou você. Vai sair?" % oc2.short_name, "o": [
			{"t": "\"Estou focado aqui.\"", "fx": {"sup": 4.0, "pres": 3.0}},
			{"t": "\"Fico lisonjeado. Vamos ver.\"", "fx": {"sup": -6.0, "pres": -5.0, "head": true, "jrel": 3.0}}]})
	if world.transfer_window_open() and r.randf() < 0.5:
		qs.append({"j": pick_j.call("analitico"), "q": "A janela está aberta. Vem reforço?", "o": [
			{"t": "\"Estamos atentos ao mercado.\"", "fx": {}},
			{"t": "\"Preciso de reforços com urgência.\"", "fx": {"board": -2.0, "team": -2.0, "sup": 2.0, "head": true}},
			{"t": "\"Confio no elenco que tenho.\"", "fx": {"team": 3.0}}]})
	if opp != null:
		qs.append({"j": int(RngUtil.pick(r, js)["id"]), "q": "Como chega o time para o jogo contra o %s?" % opp.short_name, "o": [
			{"t": "\"Preparado. Vamos para cima.\"", "fx": {"team": 2.0}},
			{"t": "\"Temos desfalques, mas confio no grupo.\"", "fx": {}},
			{"t": "\"Sem comentários.\"", "fx": {"jrel": -2.0}}]})
	return qs.slice(0, 3)
