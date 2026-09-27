class_name NewsRow
extends RefCounted
## Linha de notícia reutilizável (hub e tela de notícias).

const CAT_ICON := {
	"selecao": "shield", "rumor": "swap", "premio": "trophy", "imprensa": "news",
	"goleada": "ball", "zebra": "bolt", "classico_vitoria": "bolt", "classico_empate": "bolt", "rivalidade": "bolt", "lider": "trophy",
	"sequencia_vitorias": "up", "sequencia_derrotas": "down", "sem_vencer": "down", "hattrick": "ball",
	"primeiro_gol": "star", "artilheiro": "ball", "lesao_grave": "cross", "transferencia": "swap",
	"transferencia_rival": "swap", "transferencia_livre": "swap", "venda_usuario": "money", "proposta_recebida": "money",
	"aposentadoria_anuncio": "clock", "aposentadoria": "clock", "campeao": "trophy", "acesso": "up", "rebaixamento": "down",
	"jovem_explode": "star", "contrato_fim": "clock", "base": "star", "janela_abre": "swap", "janela_fecha": "swap",
	"marco_gols": "trophy", "temporada": "whistle", "diretoria_ultimato": "info", "demissao": "close", "novo_tecnico": "whistle",
	"copa_classificado": "trophy", "copa_avanca": "trophy", "copa_eliminado": "close", "copa_campeao": "trophy", "estadual_classificado": "trophy", "estadual_avanca": "trophy", "estadual_eliminado": "close", "estadual_campeao": "trophy", "mundial_classificado": "trophy", "mundial_campeao": "trophy",
}


## Editoria da notícia (o chapéu acima da manchete).
static func section_of(n: NewsEvent) -> String:
	var c := n.category
	if c.begins_with("transferencia") or c in ["venda_usuario", "proposta_recebida", "janela_abre", "janela_fecha", "contrato_fim", "rumor"]:
		return "Mercado"
	if c.begins_with("copa") or c.begins_with("estadual") or c.begins_with("mundial"):
		return "Copas"
	if c in ["diretoria_ultimato", "demissao", "novo_tecnico"]:
		return "Bastidores"
	if c in ["selecao"]:
		return "Seleções"
	if c in ["premio", "campeao", "acesso", "rebaixamento", "lider", "artilheiro", "marco_gols", "temporada"]:
		return "Campeonato"
	if c in ["jovem_explode", "base", "primeiro_gol"]:
		return "Revelações"
	if c in ["lesao_grave", "aposentadoria", "aposentadoria_anuncio"]:
		return "Elenco"
	if c == "imprensa":
		return "Imprensa"
	return "Resultados"


static func _tone(n: NewsEvent) -> Color:
	if n.category in ["sequencia_derrotas", "rebaixamento", "lesao_grave", "sem_vencer", "diretoria_ultimato", "demissao", "copa_eliminado", "estadual_eliminado"]:
		return UIColors.RED
	if n.category in ["campeao", "acesso", "jovem_explode", "primeiro_gol", "copa_campeao", "estadual_campeao", "mundial_campeao"]:
		return UIColors.GREEN
	return UIColors.ACCENT


static func _open(w: GameWorld, n: NewsEvent) -> void:
	n.read = true
	if n.player_id >= 0 and w.player(n.player_id) != null:
		UIManager.push("player", {"id": n.player_id})
	elif n.club_id >= 0:
		UIManager.push("club", {"id": n.club_id})


## Manchete: a notícia mais importante em destaque, no fundo do clube envolvido, com o retrato
## do jogador (ou o escudo) ao lado. Como a capa de um portal esportivo.
static func hero(w: GameWorld, n: NewsEvent) -> Control:
	var club := w.club(n.club_id) if n.club_id >= 0 else null
	var pl := w.player(n.player_id) if n.player_id >= 0 else null
	if club == null and pl != null:
		club = w.club(pl.club_id)
	var v := UIKit.card("Card", 10)
	var top := UIKit.hbox(16)
	var col := UIKit.vbox(8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tags := UIKit.hbox(8)
	tags.add_child(UIKit.pill("MANCHETE", _tone(n), 15))
	tags.add_child(UIKit.eyebrow(section_of(n)))
	col.add_child(tags)
	var t := UIKit.label(n.title, "Title", true)
	col.add_child(t)
	if n.body != "":
		col.add_child(UIKit.label(n.body, "Muted", true))
	var when := "Rodada %d · %d" % [n.day + 1, n.year] if n.day < 38 else str(n.year)
	col.add_child(UIKit.label(when, "Caps"))
	top.add_child(col)
	if pl != null:
		var pv := UIKit.portrait(pl, w.club(pl.club_id), w.year, 132)
		pv.size_flags_vertical = Control.SIZE_SHRINK_END
		top.add_child(pv)
	elif club != null:
		var cv := UIKit.crest(club, 112)
		cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(cv)
	v.add_child(top)
	var panel := UIKit.card_panel(v)
	if club != null:
		HeroBackdrop.attach(panel, club, 0.10)
	var tap := Button.new()
	tap.theme_type_variation = "RowOverlay"
	tap.focus_mode = Control.FOCUS_NONE
	tap.pressed.connect(func():
		AudioManager.click()
		_open(w, n))
	panel.add_child(tap)
	return panel


static func make(w: GameWorld, n: NewsEvent, compact: bool) -> Control:
	var row := UIKit.hbox(12)
	var col := UIColors.ACCENT if n.importance >= NewsEvent.IMP_HIGH else UIColors.MUTED
	if n.category in ["sequencia_derrotas", "rebaixamento", "lesao_grave", "sem_vencer", "diretoria_ultimato", "demissao", "copa_eliminado"]:
		col = UIColors.RED
	elif n.category in ["campeao", "acesso", "jovem_explode", "primeiro_gol"]:
		col = UIColors.GREEN
	var tile := PanelContainer.new()
	tile.theme_type_variation = "IconTile"
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.add_child(UIKit.icon_rect(CAT_ICON.get(n.category, "news"), 26, col))
	row.add_child(tile)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIKit.hbox(8)
	var sec := UIKit.label(section_of(n).to_upper(), "Caps")
	sec.add_theme_color_override(&"font_color", col if col != UIColors.MUTED else UIColors.DIM)
	head.add_child(sec)
	if not n.read:
		head.add_child(UIKit.pill("NOVA", UIColors.ACCENT, 13))
	v.add_child(head)
	v.add_child(UIKit.label(n.title, "H3", true))
	if n.body != "" and (not compact or n.importance >= NewsEvent.IMP_HIGH):
		var b := UIKit.label(n.body, "Small", true)
		b.max_lines_visible = 3
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(b)
	if compact:
		var when := "Rodada %d · %d" % [n.day + 1, n.year] if n.day < 38 else str(n.year)
		v.add_child(UIKit.label(when, "Caps"))
	row.add_child(v)
	return UIKit.tap_row(row, func(): _open(w, n))
