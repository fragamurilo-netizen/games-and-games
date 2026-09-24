class_name NewsRow
extends RefCounted
## Linha de notícia reutilizável (hub e tela de notícias).

const CAT_ICON := {
	"goleada": "ball", "zebra": "bolt", "classico_vitoria": "bolt", "classico_empate": "bolt", "lider": "trophy",
	"sequencia_vitorias": "up", "sequencia_derrotas": "down", "sem_vencer": "down", "hattrick": "ball",
	"primeiro_gol": "star", "artilheiro": "ball", "lesao_grave": "cross", "transferencia": "swap",
	"transferencia_rival": "swap", "transferencia_livre": "swap", "venda_usuario": "money", "proposta_recebida": "money",
	"aposentadoria_anuncio": "clock", "aposentadoria": "clock", "campeao": "trophy", "acesso": "up", "rebaixamento": "down",
	"jovem_explode": "star", "contrato_fim": "clock", "base": "star", "janela_abre": "swap", "janela_fecha": "swap",
	"marco_gols": "trophy", "temporada": "whistle",
}


static func make(w: GameWorld, n: NewsEvent, compact: bool) -> Control:
	var row := UIKit.hbox(12)
	var col := UIColors.ACCENT if n.importance >= NewsEvent.IMP_HIGH else UIColors.MUTED
	if n.category in ["sequencia_derrotas", "rebaixamento", "lesao_grave", "sem_vencer"]:
		col = UIColors.RED
	elif n.category in ["campeao", "acesso", "jovem_explode", "primeiro_gol"]:
		col = UIColors.GREEN
	var ic := UIKit.icon_rect(CAT_ICON.get(n.category, "news"), 30, col)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(n.title, "H3", true))
	if n.body != "" and (not compact or n.importance >= NewsEvent.IMP_HIGH):
		v.add_child(UIKit.label(n.body, "Small", true))
	var when := "Rodada %d · %d" % [n.day + 1, n.year] if n.day < 38 else str(n.year)
	var meta := UIKit.label(when + ("  •  nova" if not n.read else ""), "Caps")
	if not n.read:
		meta.add_theme_color_override(&"font_color", UIColors.ACCENT)
	v.add_child(meta)
	row.add_child(v)
	return UIKit.tap_row(row, func():
		n.read = true
		if n.player_id >= 0 and w.player(n.player_id) != null:
			UIManager.push("player", {"id": n.player_id})
		elif n.club_id >= 0:
			UIManager.push("club", {"id": n.club_id}))
