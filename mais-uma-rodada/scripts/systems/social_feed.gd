class_name SocialFeed
extends RefCounted
## Redes sociais do mundo do jogo. Nada é inventado solto: cada post nasce de algo que aconteceu
## no save (notícias, jogos do seu time, frases da coletiva, cantos da torcida e os lançamentos de
## uniforme) e é escrito pela conta que falaria daquilo na vida real: o perfil oficial do clube,
## o jogador, o setorista, o portal de resultados ou a organizada.
##
## O feed é montado na hora, de forma determinística (mesmo save, mesmos posts, mesmas curtidas),
## e não ocupa espaço no save.
##
## Post: {key, acc, text, media, y, d, o (ordem), likes, rts, n_rep, replies, cat, club, player, kits?}
## Conta (acc): {kind: club|player|press|outlet|fans|fan, name, handle, verified, club, player, color}

const MAX_NEWS := 90
const FILTERS := [["all", "Para você"], ["mine", "Meu clube"], ["kits", "Uniformes"], ["press", "Imprensa"], ["fans", "Torcida"]]

## Portal de resultados que cobre a liga do usuário (uma conta "de agregador").
const OUTLET_PT := ["Placar Vivo", "Resenha FC", "Jogo Aberto"]
const OUTLET_INT := ["Matchday Live", "Full Time Feed", "Terrace Talk"]

## Notícias que falam de uma pessoa ou clube específico (podem sair várias no mesmo dia).
const PERSONAL := ["transferencia", "transferencia_livre", "venda_usuario", "rumor", "hattrick", "primeiro_gol", "marco_gols",
	"lesao_grave", "aposentadoria", "aposentadoria_anuncio", "campeao", "acesso", "copa_campeao", "estadual_campeao", "novo_tecnico", "demissao"]

const FAN_FIRST := ["joao", "lucas", "bia", "rafa", "duda", "gabi", "leo", "nanda", "caio", "vini", "carol", "tiago",
	"mari", "pedro", "ju", "dani", "gui", "bruno", "lari", "fe", "matheus", "isa", "davi", "paulinha"]
const FAN_TAIL := ["", "_", "oficial", "fc", "10", "raiz", "ultra", "doente", "sempre", "real"]


# ---------------------------------------------------------------------------
# Feed
# ---------------------------------------------------------------------------

## Todos os posts, do mais recente para o mais antigo. `filter`: uma das chaves de FILTERS.
static func posts(world: GameWorld, filter: String = "all", limit: int = 80) -> Array:
	if world == null or not world.has_user():
		return []
	var out: Array = []
	_from_news(world, out)
	_from_user_games(world, out)
	_from_kits(world, out)
	_from_press(world, out)
	_from_fans(world, out)
	var user := world.user_club()
	var kept: Array = []
	for p: Dictionary in out:
		if _passes(world, p, filter, user):
			kept.append(p)
	kept.sort_custom(func(a, b): return float(a["o"]) > float(b["o"]))
	return kept.slice(0, limit)


static func _passes(world: GameWorld, p: Dictionary, filter: String, user: Club) -> bool:
	match filter:
		"mine":
			if int(p.get("club", -1)) == user.id:
				return true
			var pl := world.player(int(p.get("player", -1))) if int(p.get("player", -1)) >= 0 else null
			return pl != null and pl.club_id == user.id
		"kits":
			return String(p.get("cat", "")) == "uniforme"
		"press":
			return String(p["acc"]["kind"]) in ["press", "outlet"]
		"fans":
			return String(p["acc"]["kind"]) in ["fans", "fan"]
	return true


## Os posts mais recentes do clube do usuário e sobre ele (cartão do hub).
static func latest_for_user(world: GameWorld, n: int = 2) -> Array:
	return posts(world, "mine", n)


# ---------------------------------------------------------------------------
# Contas
# ---------------------------------------------------------------------------

static func slug(s: String) -> String:
	var from := "áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ"
	var to := "aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn"
	var out := ""
	for ch in s:
		var i := from.find(ch)
		if i >= 0:
			ch = to[i]
		ch = ch.to_lower()
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


static func club_acc(c: Club) -> Dictionary:
	return {"kind": "club", "name": c.name if c.name != "" else c.short_name, "handle": "@" + slug(c.short_name),
		"verified": true, "club": c.id, "player": -1, "color": c.color1}


static func player_acc(world: GameWorld, p: Player) -> Dictionary:
	var c := world.club(p.club_id) if p.club_id >= 0 else null
	var h := slug(p.display_name())
	if h.length() < 6:
		h = slug(p.first_name + p.last_name)
	return {"kind": "player", "name": p.display_name(), "handle": "@" + h + (str(p.shirt) if p.shirt > 0 else ""),
		"verified": p.overall >= 68, "club": p.club_id, "player": p.id, "color": c.color1 if c != null else "#4EA8DE"}


static func press_acc(j: Dictionary) -> Dictionary:
	return {"kind": "press", "name": String(j.get("n", "Repórter")), "handle": "@" + slug(String(j.get("n", "reporter"))),
		"outlet": String(j.get("o", "")), "verified": true, "club": -1, "player": -1, "jid": int(j.get("id", -1)),
		"color": {"analitico": "#4EA8DE", "amigavel": "#3DBE7A", "critico": "#E5484D", "bairrista": "#F0A35E", "sensacionalista": "#C77DFF"}.get(String(j.get("t", "")), "#9EA2AA")}


static func outlet_acc(world: GameWorld) -> Dictionary:
	var pt := world.user_nation() in ["BRA", "POR"]
	var arr: Array = OUTLET_PT if pt else OUTLET_INT
	var nm := String(arr[absi(hash(world.world_seed)) % arr.size()])
	return {"kind": "outlet", "name": nm, "handle": "@" + slug(nm), "verified": true, "club": -1, "player": -1, "color": "#FFC940"}


## A organizada: a do usuário vem das relações; a dos outros clubes é gerada pelo nome.
static func fans_acc(world: GameWorld, c: Club) -> Dictionary:
	var nm := ""
	if world.is_user_club(c.id):
		nm = String(People.data(world).get("fans", {}).get("group", ""))
	if nm == "":
		var opts := ["Torcida Jovem %s" % c.short_name, "Força %s" % c.short_name, "Garra %s" % c.short_name, "Fúria %s" % c.short_name]
		nm = String(opts[absi(hash(c.key)) % opts.size()])
	return {"kind": "fans", "name": nm, "handle": "@" + slug(nm), "verified": false, "club": c.id, "player": -1, "color": c.color1}


## Torcedor comum (nas respostas).
static func fan_acc(r: RandomNumberGenerator, c: Club) -> Dictionary:
	var first := String(RngUtil.pick(r, FAN_FIRST))
	var tail := String(RngUtil.pick(r, FAN_TAIL))
	var h := first + (tail if tail != "" else "") + slug(c.abbr if c.abbr != "" else c.short_name).substr(0, 4)
	if r.randf() < 0.5:
		h += str(r.randi_range(1, 99))
	return {"kind": "fan", "name": first.capitalize() + " " + (c.abbr if c.abbr != "" else c.short_name), "handle": "@" + h,
		"verified": false, "club": c.id, "player": -1, "color": c.color1}


# ---------------------------------------------------------------------------
# Engajamento
# ---------------------------------------------------------------------------

## Seguidores do perfil oficial: torcida e tamanho do clube.
static func followers(c: Club) -> int:
	var base := float(c.fan_base) * (0.6 + c.reputation / 40.0)
	return int(maxf(3000.0, base))


static func _engage(p: Dictionary, c: Club, weight: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([p["key"], "eng"])
	var f := float(followers(c)) if c != null else 20000.0
	var likes := f * 0.012 * weight * r.randf_range(0.55, 1.5)
	p["likes"] = int(maxf(3.0, likes))
	p["rts"] = int(maxf(0.0, likes * r.randf_range(0.06, 0.18)))
	p["n_rep"] = int(maxf(1.0, likes * r.randf_range(0.02, 0.07)))


## 1234 → "1,2 mil"; 2500000 → "2,5 mi".
static func count(n: int) -> String:
	if n >= 1000000:
		return _dec(n / 1000000.0) + " mi"
	if n >= 10000:
		return str(int(n / 1000.0)) + " mil"
	if n >= 1000:
		return _dec(n / 1000.0) + " mil"
	return str(n)


static func _dec(x: float) -> String:
	var s := "%.1f" % x
	if s.ends_with(".0"):
		s = s.substr(0, s.length() - 2)
	return s.replace(".", ",")


## Respostas da torcida. `mood`: good, bad, neutral, rumor, signing, injury, kit_good, kit_mid, kit_bad.
static func _replies(world: GameWorld, p: Dictionary, c: Club, mood: String, n: int = 2) -> void:
	if c == null:
		c = world.user_club()
	var r := RandomNumberGenerator.new()
	r.seed = hash([p["key"], "rep"])
	var sn := c.short_name
	var pool: Array = []
	match mood:
		"good":
			pool = ["Que time! %s é outro patamar esse ano." % sn, "Eu falei que dava. Ninguém acreditou.", "Vamos, %s! Hoje eu durmo feliz." % sn,
				"Esse elenco tá com fome.", "Quem criticou vai ter que engolir.", "Chora, rival!"]
		"bad":
			pool = ["Inadmissível. Cadê a raça?", "Já deu, precisa mudar alguma coisa.", "Eu não aguento mais sofrer com esse time.",
				"Diretoria, acorda!", "Com esse meio-campo não dá.", "Paciência tem limite."]
		"rumor":
			pool = ["Fonte: vozes da cabeça dele.", "Se vier, eu vou buscar no aeroporto.", "Acredito quando vir a camisa na mão.",
				"Esse aí erra mais do que acerta.", "Traz logo, %s!" % sn, "Mais um que vai ficar no quase."]
		"signing":
			pool = ["Bem-vindo! Honra essa camisa.", "Gostei da contratação. Era o que faltava.", "Quero ver jogar primeiro.",
				"Chegou o reforço!", "Ele era craque no FIFA, confia.", "Tá pago, diretoria."]
		"injury":
			pool = ["Força, guerreiro!", "Volta mais forte.", "Que azar, logo agora.", "Departamento médico precisa rever isso aí."]
		"kit_good":
			pool = ["Manto lindo demais. Já comprei o meu.", "Respeitou a história do clube. Nota 10.", "Esse é o uniforme do título, anota.",
				"A reserva ficou um espetáculo.", "Fornecedora acertou em cheio esse ano.", "Vou de terceiro uniforme, sem dúvida."]
		"kit_mid":
			pool = ["O titular ficou bom, o terceiro eu não sei não.", "Nada demais, mas dá pro gasto.", "Queria algo mais ousado.",
				"Bonito na foto, quero ver em campo.", "A gola podia ser outra."]
		"kit_bad":
			pool = ["Quem aprovou isso?", "Cadê as cores do clube?", "Parece uniforme de time de várzea.", "Não compro nem na promoção.",
				"Devolve o do ano passado.", "Isso não é o %s." % sn]
		_:
			pool = ["Vamos, %s!" % sn, "Seguimos.", "Tá difícil prever esse campeonato.", "Bora pra próxima.", "Olho nesse aí."]
	RngUtil.shuffle(r, pool)
	var out: Array = []
	var used: Dictionary = {}
	for i in mini(n, pool.size()):
		var a := fan_acc(r, c)
		while used.has(a["handle"]):
			a = fan_acc(r, c)
		used[a["handle"]] = true
		out.append({"acc": a, "text": String(pool[i]), "likes": int(float(p.get("likes", 10)) * r.randf_range(0.01, 0.08))})
	p["replies"] = out


static func _post(key: String, acc: Dictionary, text: String, y: int, d: int, sub: float = 0.0) -> Dictionary:
	return {"key": key, "acc": acc, "text": text, "media": {}, "y": y, "d": d, "o": y * 1000.0 + d + sub,
		"likes": 0, "rts": 0, "n_rep": 0, "replies": [], "cat": "", "club": int(acc.get("club", -1)), "player": int(acc.get("player", -1))}


static func _tags(c: Club, extra: String = "") -> String:
	var t := "#Vamos" + slug(c.short_name).capitalize()
	if extra != "":
		t += " #" + extra
	return t


# ---------------------------------------------------------------------------
# Fontes
# ---------------------------------------------------------------------------

static func _from_news(world: GameWorld, out: Array) -> void:
	var items: Array = world.news
	var start := maxi(0, items.size() - MAX_NEWS)
	var user := world.user_club()
	var js := People.journalists(world)
	var per_day: Dictionary = {}
	for i in range(start, items.size()):
		var n: NewsEvent = items[i]
		# Várias notícias iguais no mesmo dia (clássicos, janela...) viram um post só, fora as pessoais.
		var dk := "%s-%d-%d" % [n.category, n.year, n.day]
		per_day[dk] = int(per_day.get(dk, 0)) + 1
		if int(per_day[dk]) > (3 if n.category in PERSONAL else 1):
			continue
		var c := world.club(n.club_id) if n.club_id >= 0 else null
		var pl := world.player(n.player_id) if n.player_id >= 0 else null
		var key := "n%d-%d-%d" % [n.year, n.day, i]
		var p := _news_post(world, n, c, pl, key, js, user)
		if p.is_empty():
			continue
		p["o"] = float(p["o"]) + i * 0.0001
		out.append(p)


static func _news_post(world: GameWorld, n: NewsEvent, c: Club, pl: Player, key: String, js: Array, user: Club) -> Dictionary:
	var cat := n.category
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	var home := c if c != null else user
	var mine := c != null and c.id == user.id
	var imp := 1.0 + n.importance * 0.6 + (0.8 if mine else 0.0)
	var p: Dictionary
	var mood := "neutral"
	match cat:
		"transferencia", "transferencia_livre", "venda_usuario":
			if pl != null and c != null and pl.club_id == c.id:
				var nm := pl.display_name()
				var hello := String(RngUtil.pick(r, ["Chegou! Seja bem-vindo, %s." % nm, "É oficial: %s é do %s." % [nm, c.short_name], "Novo reforço na área: %s." % nm]))
				p = _post(key, club_acc(c), hello + "\n" + _tags(c, "Bemvindo"), n.year, n.day)
				p["media"] = {"type": "player", "player": pl.id}
				mood = "signing"
			else:
				p = _post(key, _journo(world, js, r, "analitico"), "%s\n%s" % [n.title, n.body], n.year, n.day)
		"transferencia_rival", "proposta_recebida", "rumor", "janela_abre", "janela_fecha", "contrato_fim":
			var tone := "sensacionalista" if cat == "rumor" and r.randf() < 0.5 else ("bairrista" if cat == "rumor" else "analitico")
			var lead := "EXCLUSIVO: " if cat == "rumor" and tone == "sensacionalista" else ("Apurei: " if cat == "rumor" else "")
			p = _post(key, _journo(world, js, r, tone), lead + n.title + (("\n" + n.body) if n.body != "" and cat != "rumor" else ""), n.year, n.day)
			if pl != null:
				p["media"] = {"type": "player", "player": pl.id}
			mood = "rumor" if cat == "rumor" else "neutral"
		"hattrick", "primeiro_gol", "marco_gols", "artilheiro", "jovem_explode":
			if pl != null and pl.club_id >= 0:
				var lines := {
					"hattrick": ["Três gols e a bola vai pra casa. Obrigado, torcida!", "Noite pra guardar pra sempre. Hat-trick!"],
					"primeiro_gol": ["Primeiro de muitos. Obrigado a todos que acreditaram.", "Sonho de criança realizado. Meu primeiro gol!"],
					"marco_gols": ["Marca histórica. Sigo trabalhando.", "Cada gol desse é da minha família."],
					"artilheiro": ["Artilharia é consequência do trabalho do grupo.", "Bola na rede é o meu trabalho."],
					"jovem_explode": ["Muito trabalho por trás. Só o começo.", "Obrigado pela confiança, professor."],
				}
				p = _post(key, player_acc(world, pl), String(RngUtil.pick(r, lines[cat])), n.year, n.day)
				p["media"] = {"type": "player", "player": pl.id}
				mood = "good"
			else:
				p = _post(key, outlet_acc(world), n.title, n.year, n.day)
		"goleada", "zebra", "classico_vitoria", "lider", "sequencia_vitorias", "copa_avanca", "estadual_avanca", "copa_classificado", "estadual_classificado", "mundial_classificado":
			if c != null and r.randf() < 0.7:
				var cheer: String = {"goleada": "Atropelo! ", "zebra": "Ninguém acreditava. Nós sim. ", "classico_vitoria": "O clássico é nosso! ",
					"lider": "Lá em cima! ", "sequencia_vitorias": "Embalados. "}.get(cat, "Seguimos vivos! ")
				p = _post(key, club_acc(c), String(cheer) + n.title + "\n" + _tags(c), n.year, n.day)
			else:
				p = _post(key, outlet_acc(world), n.title + ("\n" + n.body if n.body != "" else ""), n.year, n.day)
			mood = "good"
		"campeao", "acesso", "copa_campeao", "estadual_campeao", "mundial_campeao":
			if c != null:
				p = _post(key, club_acc(c), ("É CAMPEÃO! " if cat != "acesso" else "SUBIMOS! ") + n.title + "\n" + _tags(c, "Historia"), n.year, n.day)
				p["media"] = {"type": "trophy", "club": c.id, "title": n.title}
				imp += 3.0
			else:
				p = _post(key, outlet_acc(world), n.title, n.year, n.day)
			mood = "good"
		"sequencia_derrotas", "sem_vencer", "rebaixamento", "copa_eliminado", "estadual_eliminado", "classico_empate":
			if c != null and r.randf() < 0.55:
				var cry := ["Protesto marcado para o próximo treino. Chega!", "Cobrança é pouco. Queremos respeito à camisa.", "O torcedor não merece isso. Acorda, %s!" % c.short_name]
				p = _post(key, fans_acc(world, c), String(RngUtil.pick(r, cry)), n.year, n.day)
			else:
				p = _post(key, _journo(world, js, r, "critico"), n.title + ("\n" + n.body if n.body != "" else ""), n.year, n.day)
			mood = "bad"
		"lesao_grave":
			if c != null and pl != null:
				p = _post(key, club_acc(c), "Boletim médico: %s passou por exames e será desfalque. Força, %s!" % [pl.display_name(), pl.short_name()], n.year, n.day)
				p["media"] = {"type": "player", "player": pl.id}
			else:
				p = _post(key, outlet_acc(world), n.title, n.year, n.day)
			mood = "injury"
		"aposentadoria", "aposentadoria_anuncio":
			if pl != null:
				p = _post(key, player_acc(world, pl), "Chegou a hora de pendurar as chuteiras. Obrigado, futebol. Obrigado a cada torcedor que gritou meu nome.", n.year, n.day)
				p["media"] = {"type": "player", "player": pl.id}
				imp += 1.5
			else:
				p = _post(key, outlet_acc(world), n.title, n.year, n.day)
			mood = "good"
		"demissao", "novo_tecnico", "diretoria_ultimato":
			if c != null and cat == "novo_tecnico":
				p = _post(key, club_acc(c), n.title + "\nBoa sorte na nova caminhada.", n.year, n.day)
			else:
				p = _post(key, _journo(world, js, r, "sensacionalista" if cat == "diretoria_ultimato" else "analitico"), n.title + ("\n" + n.body if n.body != "" else ""), n.year, n.day)
			mood = "bad" if cat != "novo_tecnico" else "neutral"
		_:
			if n.importance < NewsEvent.IMP_NORMAL:
				return {}
			p = _post(key, outlet_acc(world), n.title + ("\n" + n.body if n.body != "" and n.importance >= NewsEvent.IMP_HIGH else ""), n.year, n.day)
	p["cat"] = cat
	p["club"] = c.id if c != null else int(p["acc"].get("club", -1))
	p["player"] = pl.id if pl != null else int(p["acc"].get("player", -1))
	_engage(p, home, imp)
	_replies(world, p, home, mood)
	return p


## Um jornalista com o tom pedido (os setoristas do país do usuário).
static func _journo(world: GameWorld, js: Array, r: RandomNumberGenerator, tone: String) -> Dictionary:
	if js.is_empty():
		return outlet_acc(world)
	var fits: Array = []
	for j: Dictionary in js:
		if String(j.get("t", "")) == tone:
			fits.append(j)
	return press_acc(RngUtil.pick(r, fits if not fits.is_empty() else js))


## Resultados do seu time: o perfil oficial posta o placar final.
static func _from_user_games(world: GameWorld, out: Array) -> void:
	var user := world.user_club()
	for f: Fixture in FixtureManager.recent_fixtures(world, user.id, 6):
		var home_side := f.home == user.id
		var gf := f.hg if home_side else f.ag
		var ga := f.ag if home_side else f.hg
		var opp := world.club(f.away if home_side else f.home)
		if opp == null:
			continue
		var key := "g%d-%d-%d" % [world.year, f.slot, opp.id]
		var r := RandomNumberGenerator.new()
		r.seed = hash(key)
		var won := gf > ga or (gf == ga and f.pen_h >= 0 and ((f.pen_h > f.pen_a) == home_side))
		var lost := gf < ga or (gf == ga and f.pen_h >= 0 and not won)
		var text := ""
		if won:
			text = String(RngUtil.pick(r, ["FIM DE JOGO! Vitória do %s." % user.short_name, "É do %s! Três pontos na conta." % user.short_name, "Vitória com a cara do %s." % user.short_name]))
		elif lost:
			text = String(RngUtil.pick(r, ["Fim de jogo. Não foi dessa vez.", "Derrota. Cabeça erguida e foco no próximo jogo.", "Fim de jogo. Seguimos trabalhando."]))
		else:
			text = String(RngUtil.pick(r, ["Fim de jogo. Empate fora de casa." if not home_side else "Fim de jogo. Empate em casa.", "Um ponto. Seguimos."]))
		var motm := world.player(f.motm) if f.motm >= 0 else null
		if motm != null and motm.club_id == user.id:
			text += "\nMelhor em campo: %s." % motm.display_name()
		text += "\n" + _tags(user)
		var p := _post(key, club_acc(user), text, world.year, f.slot, 0.5)
		p["media"] = {"type": "score", "home": f.home, "away": f.away, "hg": f.hg, "ag": f.ag, "comp": f.comp, "pen_h": f.pen_h, "pen_a": f.pen_a}
		p["cat"] = "jogo"
		_engage(p, user, 2.2 if won else 1.4)
		_replies(world, p, user, "good" if won else ("bad" if lost else "neutral"), 3)
		out.append(p)


## Frases da coletiva: o setorista repercute o que o treinador disse.
static func _from_press(world: GameWorld, out: Array) -> void:
	var pr: Dictionary = People.data(world).get("press", {})
	var quotes: Array = pr.get("quotes", [])
	var user := world.user_club()
	for i in quotes.size():
		var q: Dictionary = quotes[i]
		if int(q.get("y", 0)) != world.year:
			continue
		var j := People.journalist(world, int(q.get("j", -1)))
		if j.is_empty():
			continue
		var key := "q%d-%d-%d" % [world.year, int(q.get("t", 0)), i]
		var lead: String = {"title": "Promessa registrada.", "blame": "Recado dado.", "reinforce": "Pedido público por reforços."}.get(String(q.get("k", "")), "Na coletiva:")
		var txt := "%s %s na coletiva: \"%s\"" % [lead, world.manager_name, String(q.get("txt", ""))]
		var p := _post(key, press_acc(j), txt, world.year, _turn_day(world, int(q.get("t", 0))), 0.7)
		p["cat"] = "coletiva"
		p["club"] = user.id
		p["media"] = {"type": "press", "club": user.id}
		_engage(p, user, 1.6)
		_replies(world, p, user, "neutral")
		out.append(p)


## Cantos e faixas da arquibancada viram posts da organizada.
static func _from_fans(world: GameWorld, out: Array) -> void:
	var f: Dictionary = People.data(world).get("fans", {})
	var user := world.user_club()
	var chants: Array = f.get("chants", [])
	for i in chants.size():
		var ch: Dictionary = chants[i]
		var key := "c%d-%d-%d" % [world.year, int(ch.get("turn", 0)), i]
		var p := _post(key, fans_acc(world, user), "Hoje na arquibancada: %s" % String(ch.get("t", "")), world.year, _turn_day(world, int(ch.get("turn", 0))), 0.8)
		p["cat"] = "torcida"
		var sup := float(f.get("support", 50.0))
		_engage(p, user, 0.9)
		_replies(world, p, user, "good" if sup >= 50.0 else "bad")
		out.append(p)


## Dia aproximado do calendário para o jogo número `turn` do usuário.
static func _turn_day(world: GameWorld, turn: int) -> int:
	var user := world.user_club()
	var list := FixtureManager.season_fixtures(world, user.id)
	var played := 0
	for fx: Fixture in list:
		if fx.played:
			played += 1
			if played == turn:
				return fx.slot
	return world.current_day()


# ---------------------------------------------------------------------------
# Uniformes: lançamentos e a reação da torcida
# ---------------------------------------------------------------------------

## Posts de lançamento: os uniformes do seu clube ano a ano (histórico) e os dos clubes da sua
## liga nesta temporada (a IA renova a coleção toda virada de ano).
static func _from_kits(world: GameWorld, out: Array) -> void:
	var user := world.user_club()
	var hist := KitDesign.history(user)
	for i in hist.size():
		var y := int(hist[i][0])
		if y == world.year and not KitDesign.launched(world):
			continue
		var prev: Dictionary = hist[i + 1][1] if i + 1 < hist.size() else {}
		out.append(kit_post(world, user, y, hist[i][1], prev))
	if world.season == null:
		return
	for c: Club in world.clubs_in_league(user.league_id):
		if c.id == user.id or c.kit_home.is_empty():
			continue
		out.append(kit_post(world, c, world.year, {"h": c.kit_home, "a": c.kit_away, "t": c.third_kit()}, {}))


## Post de apresentação dos uniformes `kits` ({h, a, t}) do clube no ano `y`.
static func kit_post(world: GameWorld, c: Club, y: int, kits: Dictionary, prev: Dictionary) -> Dictionary:
	var key := "k%d-%d" % [y, c.id]
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	var sup: Dictionary = c.sponsors.get("fornecedor", {})
	var brand := String(sup.get("n", ""))
	var lines := [
		"Apresentamos os novos mantos para %d. Feitos para a nossa história." % y,
		"Chegou a nova coleção %d. Titular, reserva e terceiro: qual é o seu?" % y,
		"Vestir essa camisa é outra coisa. Uniformes %d já disponíveis." % y,
	]
	var text := String(RngUtil.pick(r, lines))
	if brand != "":
		text += "\nEm parceria com %s." % brand
	text += "\n" + _tags(c, "Manto%d" % y)
	var p := _post(key, club_acc(c), text, y, 0, -0.2 + (0.1 if world.is_user_club(c.id) else 0.0))
	p["cat"] = "uniforme"
	p["media"] = {"type": "kits", "club": c.id, "h": kits.get("h", {}), "a": kits.get("a", {}), "t": kits.get("t", {})}
	var rec := kit_reception(c, kits, prev)
	p["reception"] = rec
	var w := 2.4 * (0.6 + float(rec["score"]) / 100.0)
	_engage(p, c, w if world.is_user_club(c.id) else w * 0.7)
	_replies(world, p, c, String(rec["mood"]), 3)
	return p


## Como a torcida recebe os uniformes: respeito às cores do clube, novidade em relação ao ano
## anterior e um terceiro uniforme que dá vontade de comprar. {score 0..100, label, mood, notes}.
static func kit_reception(c: Club, kits: Dictionary, prev: Dictionary) -> Dictionary:
	var h: Dictionary = kits.get("h", {})
	if h.is_empty():
		return {"score": 50, "label": "Divide opiniões", "mood": "kit_mid", "notes": []}
	var notes: Array = []
	var score := 50.0 + (c.fan_mood - 60.0) * 0.15
	# 1) Identidade: a cor que domina o titular é a cor do clube?
	var dom := KitDesign.dominant(h)
	var d1 := KitDesign.delta_e(dom, Color(c.color1))
	var d2 := KitDesign.delta_e(dom, Color(c.color2))
	var ident := minf(d1, d2)
	if ident < 14.0:
		score += 22.0
		notes.append("Titular fiel às cores do clube")
	elif ident < 30.0 or KitDesign.same_family(dom, Color(c.color1)):
		score += 8.0
		notes.append("Cores do clube em outro tom")
	else:
		score -= 24.0
		notes.append("Titular longe das cores do clube")
	# 2) Novidade: igual ao do ano passado cansa; mudar tudo assusta.
	var ph: Dictionary = prev.get("h", {})
	if not ph.is_empty():
		var dist := KitDesign.distance(ph, h)
		var same_design := String(ph.get("pattern", "")) == String(h.get("pattern", "")) and String(ph.get("collar", "")) == String(h.get("collar", ""))
		if dist < 6.0 and same_design:
			score -= 8.0
			notes.append("Igual ao do ano passado")
		elif dist < 30.0:
			score += 8.0
			notes.append("Novidade sem perder a tradição")
		else:
			score -= 6.0
			notes.append("Mudança radical em relação ao ano passado")
	# 3) Reserva e terceiro: bem diferentes do titular e com estampa que vende camisa.
	var a: Dictionary = kits.get("a", {})
	var t: Dictionary = kits.get("t", {})
	if not a.is_empty() and KitDesign.clash(h, a):
		score -= 10.0
		notes.append("Reserva parecida com o titular")
	if not t.is_empty() and String(t.get("pattern", "plain")) in KitDesign.BOLD_PATTERNS:
		score += 6.0
		notes.append("Terceiro uniforme ousado")
	var s := clampi(int(round(score)), 5, 98)
	var label := "Aprovado pela torcida" if s >= 72 else ("Boa aceitação" if s >= 56 else ("Divide opiniões" if s >= 40 else "Rejeitado pela torcida"))
	var mood := "kit_good" if s >= 60 else ("kit_mid" if s >= 40 else "kit_bad")
	return {"score": s, "label": label, "mood": mood, "notes": notes}
