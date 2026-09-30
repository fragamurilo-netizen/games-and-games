class_name Popularity
extends RefCounted
## Popularidade e draw (Game Design Bible §10, §12; MMA Bible §18).
## Eixos independentes: skill ≠ ranking ≠ draw. Popularidade é por região
## (ver content/regions.json).


func fighter_draw(world: WorldState, fighter_id: String, region: String) -> float:
	# TODO(M1): combinar popularidade regional, carisma, narrativa e forma.
	var f: Fighter = world.fighters[fighter_id]
	return float(f.popularity_by_region.get(region, 0))


## Resultado move popularidade na região do evento; vitórias respingam na
## região natal. Finalização e main event pesam mais (content/world_tuning.json).
func apply_fight_result(world: WorldState, fight: Fight, region: String) -> void:
	var cfg: Dictionary = ContentDB.load_json("world_tuning.json").popularity
	var finish := fight.method in ["ko_tko", "submission"]
	for id: String in [fight.fighter_a_id, fight.fighter_b_id]:
		var f: Fighter = world.fighters[id]
		var delta := 0.5
		if fight.winner_id == id:
			delta = float(cfg.win) + (float(cfg.finish) if finish else 0.0) + (float(cfg.main_event) if fight.card_slot == "main_event" else 0.0)
		elif not fight.winner_id.is_empty():
			delta = float(cfg.loss) + (float(cfg.finished_loss) if finish else 0.0)
		_add(f, region, delta, float(cfg.max))
		var home := LifeCycle.region_of(f.country)
		if delta > 0.0 and not home.is_empty() and home != region:
			_add(f, home, delta * float(cfg.home_spill), float(cfg.max))


static func _add(f: Fighter, region: String, delta: float, maximum: float) -> void:
	if region.is_empty():
		return
	f.popularity_by_region[region] = clampf(float(f.popularity_by_region.get(region, 0.0)) + delta, 0.0, maximum)
