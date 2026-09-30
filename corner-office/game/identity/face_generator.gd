class_name FaceGenerator
extends RefCounted
## Identidade visual dos lutadores (Game Design Bible §5).
##
## A bíblia pede reaproveitar o gerador facial do projeto "Mais Uma Rodada"
## como base estrutural. Ele NÃO está neste repositório: antes de implementar,
## audite aquele projeto, confirme licença/estrutura de assets e porte só os
## módulos reutilizáveis (Game Design Bible §23).
##
## Contrato:
##  - `create_appearance` gera os parâmetros (salvos em Fighter.appearance) a
##    partir de seed + país + biotipo + idade. Aparência é desacoplada dos atributos.
##  - `render` desenha/compõe o retrato; resultados devem ser cacheados.
##  - Envelhecimento muda cabelo, pele, cicatrizes e barba SEM trocar identidade.
##  - Hematomas/cortes pós-luta são temporários (somem com recuperação).


## Parâmetros que o renderer do Fight Studio (prototypes/face-lab/identity.js,
## `genFace(seed, pop, sex)` + `FightAppearance.resolve`) entende. `pop` sai do país
## (content/origins.json: o grupo cultural do atleta), então um atleta de Tbilisi tem traços do
## Cáucaso e um de Osaka, do Leste Asiático. `body` e `age` sobrescrevem o sorteio
## do renderer para que corpo e idade batam com o atleta. extra.height (0–1) é a
## altura relativa à divisão.
const BODY := {
	"lean": {"muscle": 0.55, "fat": 0.08},
	"athletic": {"muscle": 0.68, "fat": 0.11},
	"compact": {"muscle": 0.72, "fat": 0.18},
	"muscular": {"muscle": 0.86, "fat": 0.1},
	"heavy": {"muscle": 0.62, "fat": 0.32},
}


static func create_appearance(rng: SimRandom, country: String, body_type: String, age: int, sex: String = "m", extra: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = ContentDB.load_json("fighter_generation.json")
	var pops: Dictionary = extra.get("populations", {})
	if pops.is_empty():
		pops = FighterGenerator.country_populations(country)
	var pop: String = str(rng.weighted(pops)) if not pops.is_empty() else "misto"
	if cfg.population_names.has(str(extra.get("pop", ""))):
		pop = str(extra.pop)
	var shape: Dictionary = BODY.get(body_type, BODY.athletic)
	var body := {
		"muscle": snappedf(clampf(shape.muscle + rng.range_f(-0.06, 0.06), 0.3, 0.95), 0.01),
		"fat": snappedf(clampf(shape.fat + rng.range_f(-0.04, 0.04), 0.03, 0.5), 0.01),
		"height": snappedf(float(extra.get("height", 0.5)), 0.01),
	}
	if sex == "m":
		body.hair = snappedf(rng.range_f(0.0, 0.6) if rng.chance(0.4) else 0.0, 0.01)
	return {
		"seed": rng.range_i(1, 2000000000),
		"sex": sex,
		"pop": pop,
		"age": age,
		"country": country,
		"body_type": body_type,
		"body": body,
	}


static func render(_appearance: Dictionary, _age: int, _size: int = 256) -> Texture2D:
	# TODO(M1): compor as camadas; cachear por (seed, idade, estado pós-luta).
	return null
