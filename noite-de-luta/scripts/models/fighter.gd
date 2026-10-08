class_name Fighter
extends RefCounted
## Lutador. Atributos de 1 a 100 em três grupos (em pé, luta agarrada, físico e mental), como os
## atributos de ringue do LEATHER, só que para o MMA. O "nível" é um resumo para a interface: o
## motor de luta usa os atributos, nunca o nível.

const ATTRS: Array[String] = [
	"maos", "chutes", "potencia", "clinch", "movimentacao", "defesa",
	"queda", "def_queda", "por_cima", "por_baixo", "finalizacao", "def_finalizacao",
	"forca", "velocidade", "cardio", "queixo", "coracao", "qi",
]
const ATTR_NAMES := {
	"maos": "Mãos", "chutes": "Chutes", "potencia": "Potência", "clinch": "Clinch",
	"movimentacao": "Movimentação", "defesa": "Defesa em pé",
	"queda": "Quedas", "def_queda": "Defesa de queda", "por_cima": "Jogo por cima",
	"por_baixo": "Jogo por baixo", "finalizacao": "Finalização", "def_finalizacao": "Defesa de finalização",
	"forca": "Força", "velocidade": "Velocidade", "cardio": "Cardio", "queixo": "Queixo",
	"coracao": "Coração", "qi": "QI de luta",
}
const ATTR_HELP := {
	"maos": "Socos: precisão e técnica do jab ao cruzado.",
	"chutes": "Chutes baixos, no corpo e na cabeça.",
	"potencia": "O quanto cada golpe machuca. Nocaute vem daqui.",
	"clinch": "Joelhadas, cotoveladas e controle agarrado em pé, na grade.",
	"movimentacao": "Controle da distância, entrar e sair, cortar o octógono.",
	"defesa": "Bloquear, esquivar e não ficar parado na frente.",
	"queda": "Levar a luta para o chão.",
	"def_queda": "Ficar em pé quando o outro tenta derrubar.",
	"por_cima": "Passar a guarda, controlar e bater por cima (ground and pound).",
	"por_baixo": "Raspar, levantar e se defender de costas no chão.",
	"finalizacao": "Chaves e estrangulamentos.",
	"def_finalizacao": "Sair das chaves e estrangulamentos.",
	"forca": "Força no clinch, nas quedas e no chão.",
	"velocidade": "Mãos e pés rápidos: chega antes e reage antes.",
	"cardio": "Fôlego para manter o ritmo até o último round.",
	"queixo": "Aguentar golpes sem apagar.",
	"coracao": "Voltar depois de ser balançado, segurar o ritmo na adversidade.",
	"qi": "Seguir o plano, ler o adversário e ajustar.",
}
const GROUPS := [
	["Em pé", ["maos", "chutes", "potencia", "clinch", "movimentacao", "defesa"]],
	["Luta agarrada", ["queda", "def_queda", "por_cima", "por_baixo", "finalizacao", "def_finalizacao"]],
	["Físico e mental", ["forca", "velocidade", "cardio", "queixo", "coracao", "qi"]],
]
const STRIKING := ["maos", "chutes", "potencia", "clinch", "movimentacao", "defesa"]
const WRESTLING := ["queda", "def_queda", "por_cima"]
const BJJ := ["por_baixo", "finalizacao", "def_finalizacao"]
const PHYSICAL := ["forca", "velocidade", "cardio", "queixo", "coracao", "qi"]

var id: int = -1
var first: String = ""
var last: String = ""
var nickname: String = ""
## China e Coreia: sobrenome antes do nome na exibição ("Zhang Wei").
var family_first: bool = false
var sex: String = "m"
var nation: String = "BRA"
var city: String = ""
var eth: int = 1
var face_seed: int = 0
var look: Dictionary = {}
var birth_year: int = 2000
var birth_month: int = 1
var height_cm: int = 178
var reach_cm: int = 180
var southpaw: bool = false
var natural_kg: float = 75.0
var division: String = "M70"
var base: String = "mma"
## Segunda arte que ele treinou para completar o jogo ("" = só a de base). Ver Styles.
var base2: String = ""
var attrs: Dictionary = {}
## Teto de nível (escondido): só o olheiro dá uma ideia dele.
var potential: float = 60.0
var peak_age: int = 29
var team_id: int = -1
## Contrato com a equipe: fatia da bolsa que fica com a equipe e lutas restantes.
var contract: Dictionary = {}
var record: Dictionary = {"w": 0, "l": 0, "d": 0, "nc": 0, "ko_w": 0, "sub_w": 0, "dec_w": 0, "ko_l": 0, "sub_l": 0, "dec_l": 0}
var amateur: Dictionary = {"w": 0, "l": 0}
## Lutas profissionais (só acrescenta): {week, opp, opp_name, res (V/D/E/SR), method, detail, round, time, event, title, tier}
var history: Array = []
## Rating público (tipo Elo), só de resultados e adversários: dele sai o ranking.
var rating: float = 1200.0
var streak: int = 0
var last_fight_week: int = -999
## Condição física (0–100): cai com a luta e o treino pesado, volta com descanso.
var condition: float = 100.0
## Lesão em curso: {name, weeks}. Vazio = saudável.
var injury: Dictionary = {}
## Suspensão médica depois de nocaute (semanas).
var suspension: int = 0
var popularity: float = 10.0
## Dano acumulado na carreira (cabeça): o queixo cai com ele.
var wear: float = 0.0
var retired: bool = false
var titles_won: int = 0
var title_defenses: int = 0
## Treino: foco e intensidade (0 leve, 1 normal, 2 pesado).
var training: Dictionary = {"focus": "equilibrado", "intensity": 1}
## Luta marcada (id da luta) ou -1.
var bout_id: int = -1
## Semana em que pode desafiar alguém acima de novo (perder atrasa os desafios).
var challenge_lock: int = -999
## Treino acumulado ainda não convertido em ponto de atributo.
var progress: Dictionary = {}


func display_name() -> String:
	return (last + " " + first) if family_first else (first + " " + last)


## Como o locutor chama: o sobrenome.
func short_name() -> String:
	return last if last != "" else first


func ring_name() -> String:
	if nickname == "":
		return display_name()
	if family_first:
		return "%s “%s” %s" % [last, nickname, first]
	return "%s “%s” %s" % [first, nickname, last]


func is_female() -> bool:
	return sex == "f"


func age(world_year: int, world_month: int) -> int:
	var a := world_year - birth_year
	if world_month < birth_month:
		a -= 1
	return a


func a(key: String) -> float:
	return float(attrs.get(key, 40.0))


func avg(keys: Array) -> float:
	var s := 0.0
	for k: String in keys:
		s += a(k)
	return s / maxf(1.0, keys.size())


## Nível geral (para listas): média ponderada que valoriza o lado mais forte do lutador, como
## se olha um lutador de verdade (um wrestler de elite não é "médio" por chutar mal).
func level() -> int:
	var st := avg(["maos", "chutes", "potencia", "clinch", "movimentacao", "defesa"])
	var gr := avg(["queda", "def_queda", "por_cima"])
	var jj := avg(["por_baixo", "finalizacao", "def_finalizacao"])
	var ph := avg(["forca", "velocidade", "cardio", "queixo", "coracao", "qi"])
	var best := maxf(st, maxf(gr, jj))
	var defense := (a("defesa") + a("def_queda") + a("def_finalizacao") + a("queixo")) / 4.0
	return int(round(best * 0.34 + (st + gr + jj) / 3.0 * 0.26 + ph * 0.24 + defense * 0.16))


func record_text() -> String:
	var t := "%d-%d-%d" % [int(record["w"]), int(record["l"]), int(record["d"])]
	if int(record.get("nc", 0)) > 0:
		t += " (%d SR)" % int(record["nc"])
	return t


func fights() -> int:
	return int(record["w"]) + int(record["l"]) + int(record["d"]) + int(record.get("nc", 0))


func is_pro() -> bool:
	return fights() > 0


## Fase da carreira para o mercado: amador, profissional ou veterano.
func stage(world_year: int, world_month: int) -> String:
	if not is_pro():
		return "amador"
	if age(world_year, world_month) >= 34:
		return "veterano"
	return "profissional"


func available() -> bool:
	return not retired and bout_id < 0 and injury.is_empty() and suspension <= 0


## Estilo de luta lido dos atributos (o que o jogador "deduz" olhando a ficha).
func style_label() -> String:
	var st := avg(["maos", "chutes", "potencia", "clinch"])
	var gr := avg(["queda", "por_cima"])
	var jj := avg(["finalizacao", "por_baixo"])
	var top := maxf(st, maxf(gr, jj))
	var spread := top - minf(st, minf(gr, jj))
	if spread < 7.0:
		return "Completo"
	if top == st:
		if a("chutes") > a("maos") + 6.0:
			return "Chutador" if a("clinch") < a("chutes") - 4.0 else "Muay thai"
		if a("potencia") >= 72.0 and a("defesa") < a("potencia") - 8.0:
			return "Pancadeiro"
		if a("movimentacao") >= a("maos") and a("defesa") >= 65.0:
			return "Trocador técnico"
		return "Boxeador"
	if top == gr:
		return "Wrestler" if a("por_cima") < a("queda") + 4.0 else "Pressão no chão"
	return "Finalizador"


func to_dict() -> Dictionary:
	return {
		"id": id, "first": first, "last": last, "nick": nickname, "ff": family_first, "sex": sex, "nation": nation, "city": city,
		"eth": eth, "face": face_seed, "look": look, "by": birth_year, "bm": birth_month, "h": height_cm,
		"r": reach_cm, "sp": southpaw, "nat_kg": natural_kg, "div": division, "base": base, "base2": base2, "attrs": attrs,
		"pot": potential, "peak": peak_age, "team": team_id, "contract": contract, "rec": record, "am": amateur,
		"hist": history, "rating": rating, "streak": streak, "last_fw": last_fight_week, "cond": condition,
		"inj": injury, "susp": suspension, "pop": popularity, "wear": wear, "ret": retired, "titles": titles_won,
		"defs": title_defenses, "train": training, "bout": bout_id, "ch_lock": challenge_lock, "prog": progress,
	}


static func from_dict(d: Dictionary) -> Fighter:
	var f := Fighter.new()
	f.id = int(d["id"])
	f.first = String(d.get("first", ""))
	f.last = String(d.get("last", ""))
	f.nickname = String(d.get("nick", ""))
	f.family_first = bool(d.get("ff", false))
	f.sex = String(d.get("sex", "m"))
	f.nation = String(d.get("nation", "BRA"))
	f.city = String(d.get("city", ""))
	f.eth = int(d.get("eth", 1))
	f.face_seed = int(d.get("face", 0))
	f.look = d.get("look", {})
	f.birth_year = int(d.get("by", 2000))
	f.birth_month = int(d.get("bm", 1))
	f.height_cm = int(d.get("h", 178))
	f.reach_cm = int(d.get("r", 180))
	f.southpaw = bool(d.get("sp", false))
	f.natural_kg = float(d.get("nat_kg", 75.0))
	f.division = String(d.get("div", "M70"))
	f.base = String(d.get("base", "mma"))
	f.base2 = String(d.get("base2", ""))
	f.attrs = d.get("attrs", {})
	f.potential = float(d.get("pot", 60.0))
	f.peak_age = int(d.get("peak", 29))
	f.team_id = int(d.get("team", -1))
	f.contract = d.get("contract", {})
	f.record = d.get("rec", f.record)
	f.amateur = d.get("am", f.amateur)
	f.history = d.get("hist", [])
	f.rating = float(d.get("rating", 1200.0))
	f.streak = int(d.get("streak", 0))
	f.last_fight_week = int(d.get("last_fw", -999))
	f.condition = float(d.get("cond", 100.0))
	f.injury = d.get("inj", {})
	f.suspension = int(d.get("susp", 0))
	f.popularity = float(d.get("pop", 10.0))
	f.wear = float(d.get("wear", 0.0))
	f.retired = bool(d.get("ret", false))
	f.titles_won = int(d.get("titles", 0))
	f.title_defenses = int(d.get("defs", 0))
	f.training = d.get("train", {"focus": "equilibrado", "intensity": 1})
	f.bout_id = int(d.get("bout", -1))
	f.challenge_lock = int(d.get("ch_lock", -999))
	f.progress = d.get("prog", {})
	return f
