extends Screen
## Lutadores: roster, perfil e rankings (Game Design Bible §4, §7, §15).


func title() -> String:
	return "Lutadores"


func build() -> void:
	for f: Fighter in Game.world.fighters.values():
		add_text("%s  ·  %s  ·  %s" % [f.display_name(), f.record_string(), f.division])
	add_todo("lista virtualizada, filtros por divisão/organização, perfil em bottom sheet, rankings.")
