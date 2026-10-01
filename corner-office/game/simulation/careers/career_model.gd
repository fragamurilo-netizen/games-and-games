class_name CareerModel
extends RefCounted
## Curvas de carreira dos atletas (Game Design Bible §0, §4 "Potencial
## dinâmico", §13; MMA Bible §7, §15, Apêndice A "Prime window").
##
## Cada atleta tem um modelo latente em `hidden` (nunca exposto sem scouting):
##   ability_peak  — nível máximo que o corpo/técnica permitem (pode oscilar)
##   prime_age     — idade de auge; varia por divisão, estilo e biologia
##   growth_gap    — quanto falta desenvolver entre os 18 anos e o auge
##   decline_rate  — velocidade da queda depois do auge
##   attr_noise    — assinatura individual por atributo (estável)
## Os atributos visíveis são derivados desse modelo + base marcial + divisão +
## idade + experiência + desgaste (KOs sofridos). Nada aqui usa Overall.

static var _cfg: Dictionary = {}
static var _bases: Dictionary = {}
static var _attrs: Dictionary = {}

const GROUPS := ["striking", "grappling", "jiu_jitsu", "physical", "mental"]


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		_cfg = ContentDB.load_json("career_model.json")
	return _cfg


static func bases() -> Dictionary:
	if _bases.is_empty():
		_bases = ContentDB.load_json("martial_bases.json")
	return _bases


static func attribute_keys() -> Dictionary:
	if _attrs.is_empty():
		_attrs = ContentDB.load_json("attributes.json")
	return _attrs


static func division(id: String) -> Dictionary:
	return cfg().divisions.get(id, cfg().divisions.m_lightweight)


static func age_on(f: Fighter, date: Dictionary) -> float:
	if f.birth_date.is_empty():
		return 28.0
	return GameDate.days_between(f.birth_date, date) / 365.25


static func pro_bouts(f: Fighter) -> int:
	return int(f.record.get("wins", 0)) + int(f.record.get("losses", 0)) + int(f.record.get("draws", 0))


## Desgaste acumulado: KOs sofridos e dano na cabeça pesam mais para quem é
## sensível a dano (MMA Bible §15: "chronic wear").
static func wear(f: Fighter) -> float:
	var sensitivity := float(f.hidden.get("damage_sensitivity", 55)) / 55.0
	return (int(f.record.get("ko_losses", 0)) * 1.0 + float(f.damage_history.get("head", 0.0)) * 0.8) * sensitivity


static func development(f: Fighter, age: float) -> float:
	var prime := float(f.hidden.get("prime_age", 29.5))
	var gap := float(f.hidden.get("growth_gap", 20.0))
	return gap * pow(clampf((prime - age) / maxf(1.0, prime - 18.0), 0.0, 1.0), 1.25)


static func decline(f: Fighter, age: float) -> float:
	var prime := float(f.hidden.get("prime_age", 29.5))
	return float(f.hidden.get("decline_rate", 0.2)) * pow(maxf(0.0, age - prime), 1.7)


## Nível técnico-atlético geral numa idade. Uso interno da simulação.
static func ability_at(f: Fighter, age: float) -> float:
	return float(f.hidden.get("ability_peak", 60.0)) - development(f, age) - decline(f, age) - wear(f) * 0.45


## Pico necessário para ter `current` hoje, dada a idade (usado na geração).
static func peak_for(f: Fighter, current: float, age: float) -> float:
	return current + development(f, age) + decline(f, age)


static func _age_effect(key: String, age: float, f: Fighter) -> float:
	var w := wear(f)
	match key:
		"speed", "explosiveness":
			return -maxf(0.0, age - 27.0) * 0.9
		"cardio":
			return -maxf(0.0, age - 30.0) * 0.6
		"strength":
			return -maxf(0.0, 24.0 - age) * 0.8 - maxf(0.0, age - 33.0) * 0.7
		"durability":
			return -maxf(0.0, age - 32.0) * 1.0 - w * 1.2
		"chin":
			return -maxf(0.0, age - 32.0) * 1.1 - w * 2.4
		"recovery":
			return -maxf(0.0, age - 29.0) * 0.9 - w * 0.6
		"mobility":
			return -maxf(0.0, age - 30.0) * 0.6
	return 0.0


static func _experience(key: String, bouts: int) -> float:
	match key:
		"fight_iq":
			return minf(12.0, bouts * 0.45)
		"composure":
			return minf(8.0, bouts * 0.3)
		"adaptation":
			return minf(6.0, bouts * 0.25)
		"patience":
			return minf(5.0, bouts * 0.2)
	return 0.0


## Recalcula os atributos visíveis a partir do modelo latente. A base marcial
## define forças e fraquezas; com a experiência as fraquezas diminuem (atleta
## mais completo), mas as forças de origem permanecem (MMA Bible §7).
static func refresh_attributes(f: Fighter, date: Dictionary) -> void:
	var age := age_on(f, date)
	var bouts := pro_bouts(f)
	var level := ability_at(f, age)
	var profile: Dictionary = bases().profiles.get(f.martial_base, {})
	var integration := 1.0 - float(cfg().integration) * minf(1.0, bouts / float(cfg().integration_bouts))
	var div_phys: Dictionary = division(f.division).get("physical", {})
	var noise: Dictionary = f.hidden.get("attr_noise", {})
	var keys := attribute_keys()
	for group: String in GROUPS:
		var values := {}
		for key: String in keys[group]:
			var offset := float(profile.get(key, 0))
			if offset < 0.0:
				offset *= integration
			var v := level + offset + float(noise.get(key, 0.0)) + float(div_phys.get(key, 0)) + _age_effect(key, age, f) + _experience(key, bouts)
			values[key] = clampi(roundi(v), 12, 98)
		f.set(group, values)
	f.style = style_from_skills(f)


## Preferências táticas nascem das habilidades, não de uma etiqueta: um
## faixa-preta com bom boxe pode preferir trocar em pé (MMA Bible §7).
static func style_from_skills(f: Fighter) -> Dictionary:
	var s: Dictionary = f.striking
	var g: Dictionary = f.grappling
	var j: Dictionary = f.jiu_jitsu
	var m: Dictionary = f.mental
	var stand := (float(s.boxing) + float(s.kicks) + float(s.accuracy)) / 3.0
	var ground := (float(g.takedown_offense) + float(g.top_control) + float(j.submission_offense)) / 3.0
	var mean := (stand + ground) / 2.0
	var bias: Dictionary = f.hidden.get("style_bias", {})
	var aggression := (float(m.aggression) - 55.0) / 90.0
	var out := {
		"boxing": 1.0 + (float(s.boxing) - mean) / 45.0 + aggression,
		"kicks": 1.0 + (float(s.kicks) - mean) / 45.0,
		"clinch": 1.0 + (float(g.clinch) - mean) / 50.0,
		"takedown": 1.0 + (float(g.takedown_offense) - mean) / 40.0,
		"ground": 1.0 + (ground - stand) / 50.0,
		"gnp": 1.0 + (float(g.ground_and_pound) - mean) / 50.0 + aggression * 0.5,
		"submission": 1.0 + (float(j.submission_offense) - mean) / 40.0,
		"movement": 1.0 + (float(f.physical.mobility) - mean) / 55.0 - aggression,
		"defense": 1.0 + (float(s.defense) - mean) / 60.0,
		"scramble": 1.0 + (float(g.scramble) - mean) / 60.0,
	}
	for key: String in out:
		out[key] = snappedf(clampf(float(out[key]) + float(bias.get(key, 0.0)), 0.45, 1.9), 0.01)
	return out


## Resumo público de 0–100 só para UI/ordenações de exibição. A simulação
## não usa este número para decidir lutas.
static func summary_level(f: Fighter) -> int:
	var total := 0.0
	var n := 0
	for group: String in GROUPS:
		for v in f.get(group).values():
			total += float(v)
			n += 1
	return roundi(total / maxf(1.0, n))
