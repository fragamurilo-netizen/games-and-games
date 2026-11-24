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
		# O humor só aparece quando pede atenção (ou quando ele está voando), ao lado do nome.
		var mood := ""
		var mood_col := Color(0, 0, 0, 0)
		if Morale.tone(f) < 0:
			mood = Morale.label(f).to_lower()
			mood_col = UIColors.RED if Morale.tone(f) <= -2 else UIColors.ORANGE
		elif Morale.tone(f) >= 2:
			mood = Morale.label(f).to_lower()
			mood_col = UIColors.GREEN
		var rec := f.record_text() if f.is_pro() else "estreante"
		var line := "%s · %s · %s" % [div, rec, String(st[0])]
		# Com luta marcada a linha fica curta (adversário e prazo), senão não cabe no celular.
		var b := Camp.bout_of(w, f)
		if b != null and f.injury.is_empty() and f.suspension <= 0:
			var left := b.week - w.week
			line = "%s · contra %s · %s" % [rec, w.fighter(b.other(f.id)).short_name(), "sábado" if left <= 0 else "em %d sem." % left]
		c.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("fighter", {"id": f.id}), line, st[1], "", null, mood, mood_col))
