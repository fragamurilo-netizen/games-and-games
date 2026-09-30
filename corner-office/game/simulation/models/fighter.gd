class_name Fighter
extends Entity
## Lutador como agente (Game Design Bible §4, MMA Bible §7, §14–15, §18).
## Overall é só um resumo para UI — a simulação nunca deve depender dele.

enum Sex { MALE, FEMALE }

# Identidade
var first_name := ""
var last_name := ""
var nickname := ""
var country := ""          # ISO-3166 alpha-2
var city := ""
var languages: Array = []
var sex: int = Sex.MALE
var birth_date := {}       # GameDate dict
var gym_id := ""
var agent_id := ""
var organization_id := ""  # "" = free agent
var contract_id := ""

# Biometria
var height_cm := 0
var reach_cm := 0
var stance := "orthodox"   # orthodox | southpaw | switch
var body_type := "athletic"  # lean | athletic | compact | muscular | heavy
var division := ""         # id em content/weight_classes.json
var natural_weight_kg := 0.0

# Base marcial = origem técnica, não classe (MMA Bible §1, §7).
var martial_base := ""

# Atributos técnicos 1–100 (chaves em content/attributes.json).
var striking := {}
var grappling := {}
var jiu_jitsu := {}
var physical := {}
var mental := {}

# Ocultos: só visíveis via scouting (faixas + confiança).
var hidden := {}
# Potencial dinâmico: distribuição, não teto (Game Design Bible §4).
var potential := {"mean": 50.0, "spread": 10.0}

# Estilo de luta (content/fighter_generation.json → fight_styles) e seus
# pesos por categoria de técnica (distribuição de intenções no Fight Engine).
var fight_style := ""
var style := {}

# Carreira
var record := {"wins": 0, "losses": 0, "draws": 0, "nc": 0}
var fight_ids: Array = []          # append-only
var titles: Array = []             # append-only
var career_goals := {}             # money / legacy / activity / belt ...

# Mercado — popularidade é regional e separada de skill (MMA Bible §18).
var popularity_by_region := {}
var charisma := 50

# Saúde (MMA Bible §15)
var injuries: Array = []
var medical_suspension_until := {}
var damage_history := {"head": 0.0, "body": 0.0, "legs": 0.0}

# Identidade visual: seed/params do gerador; desacoplado dos atributos.
var appearance := {}

var bio := ""               # gancho narrativo (texto livre)
var retired := false


func display_name() -> String:
	if nickname.is_empty():
		return "%s %s" % [first_name, last_name]
	return "%s “%s” %s" % [first_name, nickname, last_name]


func age_on(date: Dictionary) -> int:
	if birth_date.is_empty():
		return 0
	var age: int = int(date.year) - int(birth_date.year)
	if int(date.month) < int(birth_date.month) or (int(date.month) == int(birth_date.month) and int(date.day) < int(birth_date.day)):
		age -= 1
	return age


func record_string() -> String:
	return "%d-%d-%d" % [record.wins, record.losses, record.draws]
