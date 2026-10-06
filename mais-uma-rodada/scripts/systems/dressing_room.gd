class_name DressingRoom
extends RefCounted
## O vestiário por dentro: quem manda (hierarquia), quem anda com quem (panelinhas) e o clima.
##   Hierarquia: capitão, líderes, influentes, grupo e isolados — pela idade, anos de clube, papel
##     no elenco, traços de liderança, braçadeira, seleção e nível.
##   Panelinhas: por língua (os brasileiros, os hispânicos, os de língua inglesa...), os garotos da
##     base e os veteranos. Cada uma tem um líder, um humor (moral média) e a confiança no treinador.
##   Clima: moral, tensão entre as panelinhas e quantos estão isolados.
##   Reunião com o elenco: cobrar, motivar, pedir união ou conversar antes com os líderes — o efeito
##     depende do apoio dos líderes e da fase; pode dar errado. Intervalo de 5 rodadas.

const COOLDOWN := 5
const LANG_GROUP := {"pt": "Os brasileiros e lusófonos", "es": "Os hispânicos", "en": "Os de língua inglesa",
	"fr": "Os francófonos", "it": "Os italianos", "de": "Os de língua alemã", "nl": "Os holandeses e belgas",
	"ar": "Os árabes", "ja": "Os japoneses", "ko": "Os coreanos", "zh": "Os chineses", "tr": "Os turcos"}


static func _lang(code: String) -> String:
	return Languages.primary(code)


## Influência de cada jogador no vestiário (0..100).
static func influence(world: GameWorld, p: Player) -> float:
	var v := 0.0
	var age := p.age(world.year)
	v += clampf(float(age - 18) * 2.2, 0.0, 30.0)
	v += clampf(float(world.year - p.joined_year) * 3.0, 0.0, 18.0)
	v += [16.0, 10.0, 4.0, 0.0, 0.0][clampi(p.squad_status, 0, 4)]
	if p.has_trait("lider"):
		v += 14.0
	if p.has_trait("cascudo") or p.has_trait("idolo") or p.has_trait("mentor"):
		v += 7.0
	if p.has_trait("timido") or p.has_trait("inseguro"):
		v -= 8.0
	if int(People.data(world).get("captain", -1)) == p.id:
		v += 15.0
	v += minf(float(NationalTeamManager.caps_of(world, p.id)[0]) / 6.0, 8.0)
	v += (float(p.overall) - 65.0) * 0.3
	v += (p.hid("lea") - 10) * 0.5
	return clampf(v, 0.0, 100.0)


## [{p, inf, tier}] do mais influente para o menos. tier: capitão, líder, influente, grupo, isolado.
static func hierarchy(world: GameWorld) -> Array:
	var club := world.user_club()
	var cap := int(People.data(world).get("captain", -1))
	var rows: Array = []
	for p: Player in world.squad(club):
		rows.append({"p": p, "inf": influence(world, p)})
	rows.sort_custom(func(a, b): return float(a["inf"]) > float(b["inf"]))
	for i in rows.size():
		var r: Dictionary = rows[i]
		var p: Player = r["p"]
		var tier := "grupo"
		if p.id == cap:
			tier = "capitão"
		elif i < 3 and float(r["inf"]) >= 45.0:
			tier = "líder"
		elif i < 8 and float(r["inf"]) >= 35.0:
			tier = "influente"
		elif _isolated(world, p):
			tier = "isolado"
		r["tier"] = tier
	return rows


## Sem ninguém da mesma língua, recém-chegado ou confiança baixa e sem amigos no grupo.
static func _isolated(world: GameWorld, p: Player) -> bool:
	var club := world.user_club()
	var mates := 0
	var lg := _lang(p.nationality)
	for q: Player in world.squad(club):
		if q != p and _lang(q.nationality) == lg:
			mates += 1
	var friends := 0
	for b: Dictionary in People.bonds_of(world, p.id):
		if int(b.get("v", 0)) > 0:
			friends += 1
	return (mates == 0 and Languages.comm(p, club) < 0.45 and friends == 0) or (People.trust_of(world, p) < 30.0 and friends == 0)


## Panelinhas: [{name, members: [Player], leader: Player, mood, trust}].
static func cliques(world: GameWorld) -> Array:
	var club := world.user_club()
	var squad: Array = world.squad(club)
	var groups := {}
	var home := _lang(club.nation)
	for p: Player in squad:
		var lg := _lang(p.nationality)
		if lg != home and LANG_GROUP.has(lg):
			var key := "L:" + lg
			if not groups.has(key):
				groups[key] = []
			groups[key].append(p)
	var kids: Array = []
	var vets: Array = []
	for p: Player in squad:
		var a := p.age(world.year)
		if a <= 21 and p.joined_year >= world.year - 5:
			kids.append(p)
		elif a >= 30:
			vets.append(p)
	var out: Array = []
	for key in groups:
		var arr: Array = groups[key]
		if arr.size() >= 2:
			out.append(_make(world, String(LANG_GROUP[key.substr(2)]), arr))
	if kids.size() >= 3:
		out.append(_make(world, "Os garotos", kids))
	if vets.size() >= 3:
		out.append(_make(world, "Os veteranos", vets))
	# O resto do elenco da terra: a "maioria" do vestiário
	var locals: Array = squad.filter(func(p: Player): return _lang(p.nationality) == home and p.age(world.year) > 21 and p.age(world.year) < 30)
	if locals.size() >= 3:
		out.append(_make(world, "A turma da casa", locals))
	return out


static func _make(world: GameWorld, name: String, members: Array) -> Dictionary:
	var lead: Player = null
	var best := -1.0
	var mood := 0.0
	var trust := 0.0
	for p: Player in members:
		var inf := influence(world, p)
		if inf > best:
			best = inf
			lead = p
		mood += p.morale
		trust += People.trust_of(world, p)
	return {"name": name, "members": members, "leader": lead, "mood": mood / members.size(), "trust": trust / members.size()}


## Clima do vestiário 0..100 e o principal problema (texto).
static func atmosphere(world: GameWorld) -> Array:
	var club := world.user_club()
	var squad: Array = world.squad(club)
	if squad.is_empty():
		return [50.0, ""]
	var m := 0.0
	for p: Player in squad:
		m += p.morale
	m /= squad.size()
	var cl := cliques(world)
	var lo := 100.0
	var hi := 0.0
	var worst := ""
	for c: Dictionary in cl:
		if float(c["mood"]) < lo:
			lo = float(c["mood"])
			worst = String(c["name"])
		hi = maxf(hi, float(c["mood"]))
	var tension := maxf(0.0, hi - lo - 10.0)
	var iso := 0
	for r: Dictionary in hierarchy(world):
		if r["tier"] == "isolado":
			iso += 1
	var v := clampf(m - tension * 0.5 - iso * 2.5, 0.0, 100.0)
	var why := ""
	if tension >= 15.0:
		why = "%s andam insatisfeitos e o grupo está rachado." % worst
	elif iso >= 3:
		why = "%d jogadores estão isolados no vestiário." % iso
	elif m < 50.0:
		why = "A moral do grupo está baixa."
	return [v, why]


static func wait_turns(world: GameWorld) -> int:
	return maxi(0, int(People.data(world).get("meet_t", -99)) + COOLDOWN - world.current_turn())


## Reunião com o elenco. kind: "cobrar", "motivar", "uniao", "lideres".
## Retorna {ok, title, lines: [[jogador, fala]], summary}.
static func meeting(world: GameWorld, kind: String) -> Dictionary:
	var club := world.user_club()
	People.data(world)["meet_t"] = world.current_turn()
	var r := People.rng(world, world.current_turn() * 7 + kind.length())
	var h := hierarchy(world)
	var leaders: Array = []
	for row: Dictionary in h:
		if row["tier"] in ["capitão", "líder"]:
			leaders.append(row["p"])
	var support := 50.0
	for p: Player in leaders:
		support += (People.trust_of(world, p) - 50.0) / maxf(1.0, leaders.size())
	var form := 0
	for ch in club.results.right(5):
		form += 1 if ch == "V" else (-1 if ch == "D" else 0)
	var lines: Array = []
	var summary := ""
	var ok := true
	match kind:
		"cobrar":
			# Cobrança funciona com os líderes do seu lado e o time devendo; em boa fase soa injusta
			var p_ok := clampf(0.35 + (support - 50.0) / 80.0 - form * 0.08, 0.1, 0.9)
			ok = r.randf() < p_ok
			for p: Player in world.squad(club):
				p.morale = clampf(p.morale + (4.0 if ok else -5.0) * p.trait_mult("morale_volatility"), 0.0, 100.0)
				if not ok and (p.has_trait("estrela") or HiddenPersona.hot_head(p)):
					People.add_trust(world, p, -4.0)
			summary = "O grupo sentiu a cobrança e prometeu reação." if ok else "A cobrança pegou mal: parte do elenco achou injusta."
		"motivar":
			ok = form <= 2 or r.randf() < 0.7
			for p: Player in world.squad(club):
				p.morale = clampf(p.morale + (5.0 if ok else 1.0), 0.0, 100.0)
			summary = "O discurso levantou o astral do vestiário." if ok else "Palavras bonitas, mas o grupo já estava no clima. Pouco mudou."
		"uniao":
			var cl := cliques(world)
			var lo: Dictionary = {}
			for c: Dictionary in cl:
				if lo.is_empty() or float(c["mood"]) < float(lo["mood"]):
					lo = c
			ok = support >= 45.0 or r.randf() < 0.5
			if not lo.is_empty():
				for p: Player in lo["members"]:
					p.morale = clampf(p.morale + (7.0 if ok else 2.0), 0.0, 100.0)
					People.add_trust(world, p, 4.0 if ok else 0.0)
			summary = ("Você puxou %s para perto e o grupo se fechou." % String(lo.get("name", "o grupo")).to_lower()) if ok else "O pedido de união soou vazio: as panelinhas continuam."
		"lideres":
			for p: Player in leaders:
				People.add_trust(world, p, 6.0)
				p.morale = clampf(p.morale + 4.0, 0.0, 100.0)
			for p: Player in world.squad(club):
				p.morale = clampf(p.morale + 1.5, 0.0, 100.0)
			summary = "Os líderes saíram da sala com a mensagem e vão levar ao grupo."
	# Cada panelinha responde pela voz do seu líder
	var intent := "agree" if ok else "refuse"
	for c: Dictionary in cliques(world).slice(0, 3):
		var lp: Player = c["leader"]
		if lp != null:
			lines.append([lp, SquadVoice.say(world, lp, intent, r)])
	var titles := {"cobrar": "Cobrança no vestiário", "motivar": "Discurso motivacional", "uniao": "Pedido de união", "lideres": "Conversa com os líderes"}
	return {"ok": ok, "title": titles.get(kind, "Reunião"), "lines": lines, "summary": summary}
