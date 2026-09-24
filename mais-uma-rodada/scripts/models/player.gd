class_name Player
extends RefCounted
## Jogador: identidade, atributos, ocultos, contrato, condição e memória estatística.

# --- Curvas de desenvolvimento (ocultas) ---
const CURVE_PRECOCE := 0
const CURVE_NORMAL := 1
const CURVE_TARDIO := 2
const CURVE_DECLINIO_PRECOCE := 3
const CURVE_LONGEVO := 4
const CURVE_NAMES: Array[String] = ["Precoce", "Normal", "Tardio", "Declínio precoce", "Longevo"]

# --- Status no elenco ---
const STATUS_STAR := 0
const STATUS_STARTER := 1
const STATUS_ROTATION := 2
const STATUS_BACKUP := 3
const STATUS_PROSPECT := 4
const STATUS_NAMES: Array[String] = ["Estrela", "Titular", "Rotação", "Reserva", "Promessa"]

# --- Pé ---
const FOOT_RIGHT := 0
const FOOT_LEFT := 1
const FOOT_BOTH := 2
const FOOT_NAMES: Array[String] = ["Direito", "Esquerdo", "Ambos"]

# --- Índices das estatísticas da temporada (PackedInt32Array) ---
const S_APPS := 0
const S_STARTS := 1
const S_MINUTES := 2
const S_GOALS := 3
const S_ASSISTS := 4
const S_YELLOWS := 5
const S_REDS := 6
const S_RATING_SUM := 7 # soma das notas × 10
const S_MOTM := 8
const S_CLEAN := 9
const S_COUNT := 10

# --- Estatísticas de copa (PackedInt32Array por copa; as de liga ficam em `stats`) ---
const C_APPS := 0
const C_GOALS := 1
const C_ASSISTS := 2
const C_RATING := 3 # soma das notas × 10
const C_MINUTES := 4
const C_COUNT := 5

# Identidade
var id: int = 0
var first_name: String = ""
var last_name: String = ""
var nickname: String = ""
var known_as: String = ""
var birth_year: int = 2000
var nationality: String = ""
var eth: int = 1 # etnia (índice em nations.json → ethnicities), usada pelo rosto
var height: int = 178
var foot: int = FOOT_RIGHT
var position: int = Pos.CM
var secondary: Array = []
var shirt: int = 0
var hometown: String = ""
var face_seed: int = 0

# Atributos 1..100
var attrs: PackedByteArray = PackedByteArray()

# Ocultos
var potential: int = 50
var dev_curve: int = CURVE_NORMAL
var consistency: int = 10 # 1..20
var injury_prone: int = 10 # 1..20
var traits: Array = [] # ids de personalidade (String)
var scout_noise: int = 0 # -6..6, ruído estável da avaliação de terceiros

# Contrato e status
var club_id: int = -1
var wage: int = 0 # mensal
var contract_end: int = 0 # ano (fim da temporada)
var squad_status: int = STATUS_ROTATION
var transfer_listed: bool = false
var asking_price: int = 0
var joined_year: int = 0
var value: int = 0

# Condição
var condition: float = 100.0
var morale: float = 65.0
var recent_ratings: Array = [] # últimas 5 notas
var injury_weeks: int = 0
var injury_name: String = ""
var suspension: int = 0
var yellow_acc: int = 0
var retiring: bool = false
var unhappy_weeks: int = 0

# Desenvolvimento
var ovr_f: float = 50.0
var overall: int = 50
var dev_acc: float = 0.0
var minutes_season: int = 0

# Estatísticas e memória
var stats: PackedInt32Array = PackedInt32Array() # liga (temporada)
var cup_stats: Dictionary = {} # copa -> PackedInt32Array (temporada)
var history: Array = [] # [{y, c (club id), cn (nome), a, g, as, r}]
var spells: Array = [] # passagens por clube [{c, cn, from, to, a, g, as}]
var career_apps: int = 0
var career_goals: int = 0
var career_assists: int = 0
var titles: int = 0

# Cache (não salvo)
var _pos_cache: PackedFloat32Array = PackedFloat32Array()
var _pos_cache_dirty: bool = true
var _trait_sum: Dictionary = {}
var _trait_mult: Dictionary = {}


func _init() -> void:
	attrs.resize(Attr.COUNT)
	attrs.fill(40)
	stats.resize(S_COUNT)
	stats.fill(0)


# ---------------------------------------------------------------------------
# Derivados
# ---------------------------------------------------------------------------

func age(year: int) -> int:
	return year - birth_year


func full_name() -> String:
	if nickname != "":
		return "%s %s (%s)" % [first_name, last_name, nickname]
	return first_name + " " + last_name


func display_name() -> String:
	return known_as if known_as != "" else last_name


func attr(i: int) -> int:
	return attrs[i]


func set_attr(i: int, v: int) -> void:
	attrs[i] = clampi(v, 1, 99)
	_pos_cache_dirty = true


func has_trait(t: String) -> bool:
	return traits.has(t)


## Soma de um modificador numérico entre os traços (ex.: "loyalty", "big_game"). Cacheado.
func trait_sum(key: String) -> float:
	if _trait_sum.has(key):
		return _trait_sum[key]
	var total := 0.0
	for t in traits:
		var d: Dictionary = DatabaseManager.trait_data(t)
		total += float(d.get(key, 0.0))
	_trait_sum[key] = total
	return total


## Produto de um multiplicador entre os traços (ex.: "dev_mult", "card_mult"). Cacheado.
func trait_mult(key: String) -> float:
	if _trait_mult.has(key):
		return _trait_mult[key]
	var total := 1.0
	for t in traits:
		var d: Dictionary = DatabaseManager.trait_data(t)
		total *= float(d.get(key, 1.0))
	_trait_mult[key] = total
	return total


func set_traits(new_traits: Array) -> void:
	traits = new_traits
	_trait_sum.clear()
	_trait_mult.clear()


## Overall bruto (sem familiaridade) calculado com os pesos de uma posição.
func raw_rating(p: int) -> float:
	var w: Array = Pos.WEIGHTS[p]
	var total := 0.0
	for i in Attr.COUNT:
		var wi: float = w[i]
		if wi > 0.0:
			total += wi * attrs[i]
	return total


## Rendimento esperado em uma posição, já com a penalidade de familiaridade (cacheado).
func rating_at(p: int) -> float:
	if _pos_cache_dirty:
		_rebuild_pos_cache()
	return _pos_cache[p]


func _rebuild_pos_cache() -> void:
	_pos_cache.resize(Pos.COUNT)
	for i in Pos.COUNT:
		_pos_cache[i] = raw_rating(i) * Pos.familiarity(position, secondary, i)
	_pos_cache_dirty = false


## Melhor posição alternativa (útil para sugerir improvisações).
func best_position() -> int:
	var best := position
	var best_v := -1.0
	for i in Pos.COUNT:
		var v := rating_at(i)
		if v > best_v:
			best_v = v
			best = i
	return best


func recompute_overall() -> void:
	ovr_f = raw_rating(position)
	overall = clampi(int(round(ovr_f)), 1, 99)
	_pos_cache_dirty = true


func is_injured() -> bool:
	return injury_weeks > 0


func is_available() -> bool:
	return injury_weeks <= 0 and suspension <= 0


func form() -> float:
	if recent_ratings.is_empty():
		return 6.5
	var s := 0.0
	for r in recent_ratings:
		s += r
	return s / recent_ratings.size()


func push_rating(r: float) -> void:
	recent_ratings.append(snappedf(r, 0.1))
	while recent_ratings.size() > 5:
		recent_ratings.remove_at(0)


func contract_years_left(year: int) -> int:
	return max(0, contract_end - year)


func stat(i: int) -> int:
	return stats[i]


func avg_rating() -> float:
	if stats[S_APPS] <= 0:
		return 0.0
	return stats[S_RATING_SUM] / 10.0 / stats[S_APPS]


func reset_season_stats() -> void:
	stats.fill(0)
	cup_stats.clear()
	minutes_season = 0


func cup_add(cup_id: String, mins: int, goals: int, assists: int, rating: float) -> void:
	var st: PackedInt32Array
	if cup_stats.has(cup_id):
		st = cup_stats[cup_id]
	else:
		st = PackedInt32Array()
		st.resize(C_COUNT)
		st.fill(0)
	st[C_APPS] += 1
	st[C_GOALS] += goals
	st[C_ASSISTS] += assists
	st[C_RATING] += int(round(rating * 10.0))
	st[C_MINUTES] += mins
	cup_stats[cup_id] = st


## Totais da temporada somando liga e copas: [jogos, gols, assistências].
func season_totals() -> Array:
	var apps := stats[S_APPS]
	var goals := stats[S_GOALS]
	var assists := stats[S_ASSISTS]
	for k in cup_stats:
		var st: PackedInt32Array = cup_stats[k]
		apps += st[C_APPS]
		goals += st[C_GOALS]
		assists += st[C_ASSISTS]
	return [apps, goals, assists]


## Potencial estimado com ruído (o valor real nunca aparece na UI).
## precision: 0 = olheiro ruim/sem informação, 1 = conhece perfeitamente.
func potential_estimate(precision: float) -> int:
	var noise := int(round(scout_noise * (1.0 - precision)))
	return clampi(potential + noise, overall, 99)


static func potential_label(p: int) -> String:
	if p >= 82:
		return "Potencial extraordinário"
	if p >= 74:
		return "Grande promessa"
	if p >= 66:
		return "Promissor"
	if p >= 56:
		return "Razoável"
	return "Baixo"


## Perfil de jogo em uma palavra, derivado dos atributos (memorável: "Pivô", "Velocista"...).
func playstyle() -> String:
	# Sempre relativo ao próprio overall: o rótulo descreve o *perfil*, não o nível.
	var a := attrs
	var o := float(overall)
	match Pos.group(position):
		Pos.G_GK:
			if a[Attr.PAS] >= o - 4:
				return "Goleiro-líbero"
			if a[Attr.VEL] >= o - 6:
				return "Goleiro de reflexo"
			if a[Attr.POS] >= o + 3:
				return "Bem colocado"
			return "Paredão"
		Pos.G_DEF:
			if position == Pos.RB or position == Pos.LB:
				if a[Attr.CRU] >= a[Attr.MAR] + 6:
					return "Lateral ofensivo"
				if a[Attr.VEL] >= o + 8:
					return "Lateral veloz"
				return "Lateral marcador"
			if a[Attr.PAS] >= o - 2:
				return "Zagueiro construtor"
			if a[Attr.CAB] >= o + 6 and a[Attr.FOR] >= o + 4:
				return "Xerife"
			if a[Attr.VEL] >= o + 2:
				return "Zagueiro rápido"
			return "Zagueiro clássico"
		Pos.G_MID:
			if position == Pos.DM:
				return "Cão de guarda" if a[Attr.MAR] >= a[Attr.PAS] + 4 else "Primeiro volante"
			if position == Pos.AM:
				return "Camisa 10" if a[Attr.VIS] >= a[Attr.FIN] + 3 else "Meia-atacante"
			if position == Pos.RM or position == Pos.LM:
				return "Cruzador" if a[Attr.CRU] >= a[Attr.TEC] + 3 else "Meia driblador"
			if a[Attr.RES] >= o + 6 and a[Attr.MAR] >= o - 6:
				return "Box-to-box"
			if a[Attr.FIN] >= o - 2:
				return "Meia chegador"
			return "Armador" if a[Attr.VIS] >= o + 2 else "Meio-campista"
		_:
			if position == Pos.ST:
				if a[Attr.CAB] >= o + 5 and a[Attr.FOR] >= o + 3:
					return "Pivô"
				if a[Attr.VEL] >= o + 8:
					return "Velocista"
				if a[Attr.FIN] >= o + 6:
					return "Matador"
				return "Atacante técnico"
			if a[Attr.VEL] >= o + 8:
				return "Ponta veloz"
			if a[Attr.TEC] >= o + 4:
				return "Driblador"
			if a[Attr.FIN] >= o + 2:
				return "Ponta finalizador"
			return "Ponta"


# ---------------------------------------------------------------------------
# Serialização
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"id": id, "fn": first_name, "ln": last_name, "nn": nickname, "ka": known_as,
		"by": birth_year, "nat": nationality, "eth": eth, "h": height, "ft": foot, "pos": position,
		"sec": secondary, "sh": shirt, "ht": hometown, "fs": face_seed,
		"at": attrs, "pot": potential, "dc": dev_curve, "cons": consistency, "inj_p": injury_prone,
		"tr": traits, "sn": scout_noise,
		"club": club_id, "wage": wage, "ce": contract_end, "st": squad_status, "tl": transfer_listed,
		"ask": asking_price, "jy": joined_year, "val": value,
		"cond": condition, "mor": morale, "rr": recent_ratings, "iw": injury_weeks, "in": injury_name,
		"sus": suspension, "ya": yellow_acc, "ret": retiring, "uw": unhappy_weeks,
		"acc": dev_acc, "min": minutes_season,
		"stats": stats, "cs": cup_stats, "hist": history, "spells": spells,
		"ca": career_apps, "cg": career_goals, "cas": career_assists, "tt": titles,
	}


static func from_dict(d: Dictionary) -> Player:
	var p := Player.new()
	p.id = int(d.get("id", 0))
	p.first_name = d.get("fn", "")
	p.last_name = d.get("ln", "")
	p.nickname = d.get("nn", "")
	p.known_as = d.get("ka", "")
	p.birth_year = int(d.get("by", 2000))
	p.nationality = d.get("nat", "")
	p.eth = int(d.get("eth", 1))
	p.height = int(d.get("h", 178))
	p.foot = int(d.get("ft", FOOT_RIGHT))
	p.position = int(d.get("pos", Pos.CM))
	p.secondary = Array(d.get("sec", []))
	p.shirt = int(d.get("sh", 0))
	p.hometown = d.get("ht", "")
	p.face_seed = int(d.get("fs", p.id))
	var at: Variant = d.get("at", null)
	if at is PackedByteArray and at.size() == Attr.COUNT:
		p.attrs = at
	p.potential = int(d.get("pot", 50))
	p.dev_curve = int(d.get("dc", CURVE_NORMAL))
	p.consistency = int(d.get("cons", 10))
	p.injury_prone = int(d.get("inj_p", 10))
	p.traits = Array(d.get("tr", []))
	p.scout_noise = int(d.get("sn", 0))
	p.club_id = int(d.get("club", -1))
	p.wage = int(d.get("wage", 0))
	p.contract_end = int(d.get("ce", 0))
	p.squad_status = int(d.get("st", STATUS_ROTATION))
	p.transfer_listed = bool(d.get("tl", false))
	p.asking_price = int(d.get("ask", 0))
	p.joined_year = int(d.get("jy", 0))
	p.value = int(d.get("val", 0))
	p.condition = float(d.get("cond", 100.0))
	p.morale = float(d.get("mor", 65.0))
	p.recent_ratings = Array(d.get("rr", []))
	p.injury_weeks = int(d.get("iw", 0))
	p.injury_name = d.get("in", "")
	p.suspension = int(d.get("sus", 0))
	p.yellow_acc = int(d.get("ya", 0))
	p.retiring = bool(d.get("ret", false))
	p.unhappy_weeks = int(d.get("uw", 0))
	p.dev_acc = float(d.get("acc", 0.0))
	p.minutes_season = int(d.get("min", 0))
	var st: Variant = d.get("stats", null)
	if st is PackedInt32Array and st.size() == S_COUNT:
		p.stats = st
	var cs: Dictionary = d.get("cs", {})
	for k in cs:
		if cs[k] is PackedInt32Array and cs[k].size() == C_COUNT:
			p.cup_stats[k] = cs[k]
	p.history = Array(d.get("hist", []))
	p.spells = Array(d.get("spells", []))
	p.career_apps = int(d.get("ca", 0))
	p.career_goals = int(d.get("cg", 0))
	p.career_assists = int(d.get("cas", 0))
	p.titles = int(d.get("tt", 0))
	p.recompute_overall()
	return p
