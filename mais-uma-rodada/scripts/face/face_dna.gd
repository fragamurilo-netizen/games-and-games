class_name FaceDNA
extends RefCounted
## DNA facial determinístico: semente + etnia + idade (+ ajustes do editor) → traços do rosto.
## O mesmo jogador tem sempre o mesmo DNA e, portanto, o mesmo retrato em todas as telas.
##
## O dicionário é gerado por FaceGen.features (formato, olhos, nariz, boca, cabelo, barba, pele,
## idade) e refinado por FaceVariation (anatomia correlacionada e assimetria). Saves antigos
## guardam só face_seed/eth/idade, então tudo continua derivável do jogador.

## Versão do gerador: entra na chave dos caches de retrato; subir quando o desenho mudar.
const VERSION := 3


static func from_seed(seed_value: int, eth: int, age: int, look: Dictionary = {}) -> Dictionary:
	return FaceGen.features(seed_value, eth, age, look)


static func from_player(p: Player, year: int) -> Dictionary:
	return FaceGen.features(p.face_seed, p.eth, p.age(year), p.look)
