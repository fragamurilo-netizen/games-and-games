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


static func create_appearance(rng: SimRandom, country: String, body_type: String, age: int) -> Dictionary:
	# TODO(M1): camadas de crânio, mandíbula, nariz, sobrancelha, orelha de
	# couve-flor, cabelo, barba, tatuagens (com regra de densidade).
	return {
		"seed": rng.range_i(0, 2147483647),
		"country": country,
		"body_type": body_type,
		"age_at_creation": age,
		"layers": {},
	}


static func render(_appearance: Dictionary, _age: int, _size: int = 256) -> Texture2D:
	# TODO(M1): compor as camadas; cachear por (seed, idade, estado pós-luta).
	return null
