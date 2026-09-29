class_name Popularity
extends RefCounted
## Popularidade e draw (Game Design Bible §10, §12; MMA Bible §18).
## Eixos independentes: skill ≠ ranking ≠ draw. Popularidade é por região
## (ver content/regions.json).


func fighter_draw(world: WorldState, fighter_id: String, region: String) -> float:
	# TODO(M1): combinar popularidade regional, carisma, narrativa e forma.
	var f: Fighter = world.fighters[fighter_id]
	return float(f.popularity_by_region.get(region, 0))


func apply_fight_result(_world: WorldState, _fight: Fight, _region: String) -> void:
	# TODO(M1): finalizações, performances e controvérsia movem popularidade.
	pass
