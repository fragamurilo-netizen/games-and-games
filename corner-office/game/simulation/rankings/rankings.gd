class_name Rankings
extends RefCounted
## Ranking Engine (Game Design Bible §7; MMA Bible §12, §23).
##  - Ranking oficial por organização + World Combat Index ("wci") independente.
##  - Snapshots salvos por data (append-only em world.rankings).
##  - Title shot é decisão com legitimidade, não consequência automática.

const WCI_ORG_ID := "wci"


static func key(org_id: String, division: String) -> String:
	return "%s:%s" % [org_id, division]


func latest(world: WorldState, org_id: String, division: String) -> Ranking:
	var history: Array = world.rankings.get(key(org_id, division), [])
	return history.back() if not history.is_empty() else null


## Recalcula após lutas; deve gerar explicações para mudanças relevantes.
func update(world: WorldState, org_id: String, division: String) -> Ranking:
	# TODO(M1): resultado, qualidade de oposição, recência, atividade,
	# limitar saltos absurdos, inatividade gradual.
	return latest(world, org_id, division)
