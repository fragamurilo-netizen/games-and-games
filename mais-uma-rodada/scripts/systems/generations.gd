class_name Generations
extends RefCounted
## Gerações do futebol de cada país. De vez em quando um país dá uma geração excepcional: três ou
## quatro anos de nascimento em que saem mais talentos do que o normal, e cinco ou seis garotos bem
## acima da média aparecem perto uns dos outros. Ninguém sabe na hora: a geração é "descoberta"
## quando os garotos chegam aos 17, ganha manchete e, anos depois, puxa a seleção (que é o time dos
## melhores do país) e o ranking. Ela também deixa herança: o país investe na base e passa a formar
## um pouco melhor por décadas (`nb`, que some devagar). Sem geração, a base de cada país anda um
## pouco para cima ou para baixo a cada ano.
##
## Também guarda as categorias (turmas por ano de nascimento, como "categoria 2018" na base): quantos
## garotos daquele país e ano entraram em alguma base, para mostrar depois quantos viraram
## profissionais e quantos chegaram à seleção.
##
## Tudo em world.stats["gen"]:
##   waves  [{n (país), y0, y1 (anos de nascimento), k (força 0,5–1), gc (chance de joia por garoto),
##           y (ano do sorteio), d (ano da descoberta, 0 = ainda não), pk (ano do auge anunciado)}]
##   nb     {país: bônus de formação que mudou com o tempo (soma ao "youth" do nations.json)}
##   co     {país: {ano de nascimento: garotos que entraram numa base}}
##   hist   {país: [[ano, nb]]} (uma marca por temporada, até 40)

const ROLL := 0.02 # chance por temporada de um país (com liga no jogo) sortear uma geração
const SPAN := 4 # anos de nascimento cobertos
const GEMS := 6.0 # joias esperadas numa geração de força 1
const NB_DECAY := 0.96
const NB_MIN := -1.5
const NB_MAX := 2.5
const DISCOVER_AGE := 17
const PEAK_AGE := 25


static func state(world: GameWorld) -> Dictionary:
	if not world.stats.has("gen"):
		world.stats["gen"] = {"waves": [], "nb": {}, "co": {}, "hist": {}}
	return world.stats["gen"]


## Bônus de formação do país hoje (o fixo do nations.json + o que mudou no save).
static func nation_youth(world: GameWorld, nation: String) -> float:
	var base := float(DatabaseManager.nation(nation).get("youth", 0.0))
	if world == null or not world.stats.has("gen"):
		return base
	return base + float(Dictionary(world.stats["gen"]["nb"]).get(nation, 0.0))


static func wave_of(world: GameWorld, nation: String, birth_year: int) -> Dictionary:
	if world == null or not world.stats.has("gen"):
		return {}
	for wv: Dictionary in world.stats["gen"]["waves"]:
		if String(wv["n"]) == nation and birth_year >= int(wv["y0"]) and birth_year <= int(wv["y1"]):
			return wv
	return {}


## Garoto recém-criado numa base: conta na categoria e, se for de uma geração, ganha o empurrão.
## Usa um sorteio próprio (pelo id do jogador) para não mexer no resto da geração do mundo.
static func on_new_kid(world: GameWorld, p: Player) -> void:
	var st := state(world)
	var co: Dictionary = st["co"]
	if not co.has(p.nationality):
		co[p.nationality] = {}
	var by := str(p.birth_year)
	co[p.nationality][by] = int(co[p.nationality].get(by, 0)) + 1
	var wv := wave_of(world, p.nationality, p.birth_year)
	if wv.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([p.id, world.year, "gen"])
	var k := float(wv["k"])
	p.potential = clampi(p.potential + maxi(0, int(round(rng.randfn(2.0, 2.5) * k))), p.overall + 1, 94)
	if rng.randf() < float(wv["gc"]):
		# Joia da geração: talento raro mesmo vindo de um futebol pequeno
		var floor_pot := rng.randi_range(80, 86) + int(round(4.0 * k))
		p.potential = clampi(maxi(p.potential, maxi(p.overall + rng.randi_range(20, 30), floor_pot)), p.overall + 2, 94)


## Fim de temporada (antes da base nova): a base de cada país anda, gerações nascem, são
## descobertas e chegam ao auge.
static func season_close(world: GameWorld) -> void:
	var st := state(world)
	var nb: Dictionary = st["nb"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.year, "geracoes"])
	var nations := _nations(world)
	for n in nations:
		var v := float(nb.get(n, 0.0)) * NB_DECAY + rng.randfn(0.0, 0.06)
		nb[n] = clampf(v, NB_MIN, NB_MAX)
	# Sorteio de gerações novas (no máximo uma em andamento por país)
	for n in nations:
		if _active(world, n):
			continue
		var base := float(DatabaseManager.nation(n).get("youth", 0.0))
		if rng.randf() >= ROLL * (1.0 + maxf(0.0, base) * 0.08):
			continue
		var y0 := world.year - 15 + rng.randi_range(-1, 1)
		var kids := maxf(8.0, world.clubs_of_nation(n).size() * 2.2 * SPAN)
		var k := rng.randf_range(0.5, 1.0)
		(st["waves"] as Array).append({"n": n, "y0": y0, "y1": y0 + SPAN - 1, "k": snappedf(k, 0.01), "gc": snappedf(minf(0.35, GEMS * k / kids), 0.0001),
			"y": world.year, "d": 0, "pk": 0})
	# Descoberta e auge
	for wv: Dictionary in st["waves"]:
		var mid := int(wv["y0"]) + 1
		if int(wv["d"]) == 0 and world.year - mid >= DISCOVER_AGE:
			var best := members(world, wv, 6)
			if best.size() >= 2:
				wv["d"] = world.year
				nb[String(wv["n"])] = clampf(float(nb.get(String(wv["n"]), 0.0)) + 0.6 * float(wv["k"]), NB_MIN, NB_MAX)
				_news_discovery(world, wv, best)
		elif int(wv["d"]) > 0 and int(wv["pk"]) == 0 and world.year - mid >= PEAK_AGE:
			wv["pk"] = world.year
			_news_peak(world, wv)
	# Marca do ano (depois da descoberta, para o salto aparecer no mesmo ano)
	var h: Dictionary = st["hist"]
	for n in nations:
		if not h.has(n):
			h[n] = []
		(h[n] as Array).append([world.year, snappedf(float(nb.get(n, 0.0)), 0.01)])
		while (h[n] as Array).size() > 40:
			(h[n] as Array).pop_front()


static func _active(world: GameWorld, n: String) -> bool:
	for wv: Dictionary in state(world)["waves"]:
		if String(wv["n"]) == n and world.year - int(wv["y1"]) < PEAK_AGE + 4:
			return true
	return false


## Países que formam jogadores no jogo (têm clubes).
static func _nations(world: GameWorld) -> Array:
	var seen := {}
	for c: Club in world.clubs:
		if c != null and c.nation != "":
			seen[c.nation] = true
	var out := seen.keys()
	out.sort()
	return out


## Os melhores da geração (pelo nível de hoje, desempate pelo potencial).
static func members(world: GameWorld, wv: Dictionary, limit: int = 0) -> Array:
	return cohort(world, String(wv["n"]), int(wv["y0"]), int(wv["y1"]), limit)


## Jogadores ainda no futebol de um país e de uma faixa de anos de nascimento, melhores primeiro.
static func cohort(world: GameWorld, nation: String, y0: int, y1: int, limit: int = 0) -> Array:
	var out: Array = []
	for p: Player in world.players.values():
		if p.nationality == nation and p.birth_year >= y0 and p.birth_year <= y1:
			out.append(p)
	out.sort_custom(func(a: Player, b: Player):
		var va := maxf(a.ovr_f, a.potential * 0.85)
		var vb := maxf(b.ovr_f, b.potential * 0.85)
		return va > vb if va != vb else a.id < b.id)
	return out.slice(0, limit) if limit > 0 else out


## Categoria (ano de nascimento) de um país: {entered, active, pros, caps, best: [Player]}.
## "Profissional" = 15+ jogos como profissional; seleção = convocado ao menos uma vez.
static func category(world: GameWorld, nation: String, birth_year: int) -> Dictionary:
	var st := state(world)
	var entered := int(Dictionary(st["co"].get(nation, {})).get(str(birth_year), 0))
	var ps := cohort(world, nation, birth_year, birth_year)
	var pros := 0
	var caps := 0
	var intl: Dictionary = world.stats.get("intl", {}).get("pl", {})
	for p: Player in ps:
		if p.career_apps >= 15:
			pros += 1
		if intl.has(p.id) or intl.has(str(p.id)):
			caps += 1
	for r: Dictionary in world.retired:
		if String(r.get("nat", "")) == nation and int(r.get("by", 0)) == birth_year:
			pros += 1
	return {"entered": entered, "active": ps.size(), "pros": pros, "caps": caps, "best": ps.slice(0, 8)}


static func name_of(wv: Dictionary) -> String:
	var year := int(wv["d"]) if int(wv["d"]) > 0 else int(wv["y0"]) + 1 + DISCOVER_AGE
	return "Geração %s de %d" % [demonym(String(wv["n"])), year]


## Gentílico no feminino ("geração colombiana", "portuguesa", "japonesa").
static func demonym(n: String) -> String:
	var d := String(DatabaseManager.nation(n).get("adj", ""))
	if d == "":
		return "de " + DatabaseManager.nation_name(n)
	if d.ends_with("ês"):
		return d.substr(0, d.length() - 2) + "esa"
	if d.ends_with("eu"):
		return d.substr(0, d.length() - 2) + "eia"
	if d.ends_with("o"):
		return d.substr(0, d.length() - 1) + "a"
	return d


## Índice da formação do país para mostrar (50 = como sempre foi; cada 0,05 do bônus vale 1).
static func index_of(nb: float) -> int:
	return int(round(50.0 + nb * 20.0))


## Como anda a formação do país: "em alta", "estável", "em baixa" (pelo que mudou no save).
static func trend(world: GameWorld, nation: String) -> String:
	var v := float(Dictionary(state(world)["nb"]).get(nation, 0.0))
	if v >= 0.35:
		return "em alta"
	if v <= -0.35:
		return "em baixa"
	return "estável"


static func _news_discovery(world: GameWorld, wv: Dictionary, best: Array) -> void:
	var nat := DatabaseManager.nation_name(String(wv["n"]))
	var names: Array = []
	for p: Player in best.slice(0, 4):
		names.append(p.display_name())
	var title := "%s vê nascer uma geração rara" % nat
	var body := "Olheiros do mundo inteiro estão de olho nos garotos nascidos entre %d e %d: %s. Há muito tempo o país não formava tantos talentos ao mesmo tempo." % [int(wv["y0"]), int(wv["y1"]), ", ".join(PackedStringArray(names))]
	var n := NewsManager.post_raw(world, title, body, -1, (best[0] as Player).id, NewsEvent.IMP_HIGH, "base")
	n.media["code"] = String(wv["n"])


static func _news_peak(world: GameWorld, wv: Dictionary) -> void:
	var best := members(world, wv, 4)
	if best.is_empty():
		return
	var names: Array = []
	for p: Player in best:
		names.append(p.display_name())
	var title := "A %s chega ao auge" % name_of(wv)
	var body := "%s estão no auge. A seleção nunca teve tanta gente pronta ao mesmo tempo." % ", ".join(PackedStringArray(names))
	var n := NewsManager.post_raw(world, title, body, -1, (best[0] as Player).id, NewsEvent.IMP_NORMAL, "selecao")
	n.media["code"] = String(wv["n"])


## Empurrão na reputação da liga do país (investimento e vitrine da geração): 0 a ~3 pontos.
static func league_push(world: GameWorld, nation: String) -> float:
	return clampf(float(Dictionary(state(world)["nb"]).get(nation, 0.0)) * 1.2, -1.5, 3.0)
