extends Screen
## Organização: identidade, finanças, mídia e staff (Game Design Bible §12, §15).


func title() -> String:
	return "Organização"


func build() -> void:
	add_text("Organizações do mundo:", Tokens.MUTED)
	for o: Organization in Game.world.organizations.values():
		add_text("%s  ·  rep %d  ·  %d atletas" % [o.name, o.reputation, o.roster.size()])
	add_todo("P&L por evento, contratos de mídia, popularidade por região, staff.")
