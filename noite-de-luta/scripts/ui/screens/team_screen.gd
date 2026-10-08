extends BaseScreen
## Equipe: os lutadores da academia, com a situação de cada um (luta marcada, descanso,
## lesão) e o caminho para o perfil.


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Equipe"


func refresh() -> void:
	var w := world()
	var c := reset()
	var mine := w.user_fighters()
	screen_subtitle = Fmt.plural(mine.size(), "lutador", "lutadores")
	UIManager.refresh_chrome()
	if mine.is_empty():
		c.add_child(UIKit.state_block("empty", "Nenhum lutador ainda", "Contrate no Mercado. Um amador com potencial e um profissional que já lute no regional é um bom começo.", "Ir ao Mercado", func(): UIManager.switch_area("market")))
		return
	for f: Fighter in mine:
		var st := FightKit.status_text(w, f)
		var div := Matchmaker.division_short(f.division)
		c.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("fighter", {"id": f.id}), "%s · %s · %s" % [div, f.record_text() if f.is_pro() else "estreante", String(st[0])], st[1]))
