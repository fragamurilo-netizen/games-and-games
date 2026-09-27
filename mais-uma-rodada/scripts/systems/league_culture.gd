class_name LeagueCulture
extends RefCounted
## Cultura de cada liga (leagues.json → "culture"), calibrada pelas médias reais recentes:
##   goals  multiplicador das chances (média de gols da liga / 2,65)
##   home   peso do mando de campo (viagens longas, altitude, pressão da arquibancada)
##   cards  multiplicador de cartões (a arbitragem e o jogo mais truncado)
## Liga sem cultura definida = 1,0 em tudo. Copas nacionais usam a cultura da liga do mandante;
## copas continentais só herdam o mando (altitude e caldeirão continuam valendo) e o apito é neutro.

const NEUTRAL := {"goals": 1.0, "home": 1.0, "cards": 1.0}


static func of_league(league_id: String) -> Dictionary:
	var c: Dictionary = DatabaseManager.league_cfg(league_id).get("culture", {})
	if c.is_empty():
		return NEUTRAL
	return {"goals": float(c.get("goals", 1.0)), "home": float(c.get("home", 1.0)), "cards": float(c.get("cards", 1.0))}


static func for_match(world: GameWorld, comp: String, home: Club) -> Dictionary:
	if comp != "" and DatabaseManager.has_league(comp):
		return of_league(comp)
	if home == null:
		return NEUTRAL
	var base := of_league(home.league_id)
	if comp != "" and CupManager.is_international(comp):
		return {"goals": 1.0, "home": base["home"], "cards": 1.0}
	return base
