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


const MARKET_CATS := ["transferencia", "transferencia_rival", "transferencia_livre", "venda_usuario", "proposta_recebida", "janela_abre", "janela_fecha", "contrato_fim", "rumor"]
const KICKERS := {
	"selecao": "SELEÇÕES", "goleada": "RODADA", "zebra": "RODADA", "classico_vitoria": "CLÁSSICO", "classico_empate": "CLÁSSICO",
	"rivalidade": "CLÁSSICO", "lider": "LIDERANÇA", "sequencia_vitorias": "RODADA", "sequencia_derrotas": "RODADA", "sem_vencer": "RODADA",
	"hattrick": "DESTAQUE", "primeiro_gol": "BASE", "artilheiro": "ARTILHARIA", "marco_gols": "DESTAQUE", "premio": "PRÊMIOS",
	"lesao_grave": "DEPARTAMENTO MÉDICO", "aposentadoria_anuncio": "CARREIRA", "aposentadoria": "CARREIRA", "campeao": "TÍTULO",
	"acesso": "ACESSO", "rebaixamento": "REBAIXAMENTO", "jovem_explode": "BASE", "base": "BASE", "temporada": "TEMPORADA",
	"diretoria_ultimato": "BASTIDORES", "demissao": "TÉCNICOS", "novo_tecnico": "TÉCNICOS", "imprensa": "BASTIDORES",
}


## É notícia de fora do país do usuário (clube de outra nação ou seleção estrangeira)?
static func is_foreign(w: GameWorld, n: NewsEvent) -> bool:
	if not w.has_user():
		return false
	var c := w.club(n.club_id) if n.club_id >= 0 else null
	if c != null:
		return c.nation != w.user_nation()
	var code := String(n.media.get("code", ""))
	return code != "" and code != w.user_nation() and String(n.media.get("vs", "")) != w.user_nation()


## Chapéu da notícia: editoria e, se for de fora, o país.
static func kicker(w: GameWorld, n: NewsEvent) -> String:
	var k := "CLUBE"
	if MARKET_CATS.has(n.category):
		k = "MERCADO"
	elif KICKERS.has(n.category):
		k = KICKERS[n.category]
	elif n.category.begins_with("copa_") or n.category.begins_with("estadual_") or n.category.begins_with("mundial_"):
		k = "COPAS"
	if is_foreign(w, n):
		var c := w.club(n.club_id) if n.club_id >= 0 else null
		var nat := c.nation if c != null else String(n.media.get("code", ""))
		k += " · " + DatabaseManager.nation_name(nat).to_upper()
	return k


## Veículo que deu a notícia (os mesmos das coletivas; lá fora, os internacionais).
static func source(w: GameWorld, n: NewsEvent) -> String:
	var pool: Array = Array(People.OUTLETS_INT)
	if not is_foreign(w, n) and People._lang(w.user_nation()) == "pt":
		pool = Array(People.OUTLETS_PT)
	return String(pool[absi(hash(n.title)) % pool.size()])


static func when(n: NewsEvent) -> String:
	return "Rodada %d · %d" % [n.day + 1, n.year] if n.day < 38 else str(n.year)


static func _icon_color(n: NewsEvent) -> Color:
	var col := UIColors.ACCENT if n.importance >= NewsEvent.IMP_HIGH else UIColors.MUTED
	if n.category in ["sequencia_derrotas", "rebaixamento", "lesao_grave", "sem_vencer", "diretoria_ultimato", "demissao", "copa_eliminado"]:
		col = UIColors.RED
	elif n.category in ["campeao", "acesso", "jovem_explode", "primeiro_gol"]:
		col = UIColors.GREEN
	return col


static func _open(w: GameWorld, n: NewsEvent) -> void:
	n.read = true
	if n.player_id >= 0 and w.player(n.player_id) != null:
		UIManager.push("player", {"id": n.player_id})
	elif n.club_id >= 0:
		UIManager.push("club", {"id": n.club_id})


static func _meta(w: GameWorld, n: NewsEvent, with_source: bool) -> Label:
	var txt := when(n)
	if with_source:
		txt = source(w, n) + "  ·  " + txt
	var meta := UIKit.label(txt + ("  •  nova" if not n.read else ""), "Caps")
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not n.read:
		meta.add_theme_color_override(&"font_color", UIColors.ACCENT)
	return meta


static func _kicker_label(w: GameWorld, n: NewsEvent) -> Label:
	var col := UIColors.BLUE if is_foreign(w, n) else UIColors.ACCENT
	var l := UIKit.colored(kicker(w, n), col, "Caps")
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


## Linha compacta (hub): miniatura quando a notícia tem imagem, senão o ícone da categoria.
static func make(w: GameWorld, n: NewsEvent, compact: bool) -> Control:
	var row := UIKit.hbox(12)
	var th := NewsArt.make(w, n, 78, true) if compact else null
	if th != null:
		th.custom_minimum_size = Vector2(104, 78)
		th.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		th.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(th)
	else:
		var ic := UIKit.icon_rect(CAT_ICON.get(n.category, "news"), 30, _icon_color(n))
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(n.title, "H3", true))
	if n.body != "" and (not compact or n.importance >= NewsEvent.IMP_HIGH):
		v.add_child(UIKit.label(n.body, "Small", true))
	v.add_child(_meta(w, n, false))
	row.add_child(v)
	return UIKit.tap_row(row, func(): _open(w, n))


## Matéria com foto grande em cima (manchete ou notícia importante).
static func feature(w: GameWorld, n: NewsEvent, img_h: int, headline: bool) -> Control:
	var v := UIKit.vbox(8)
	var art := NewsArt.make(w, n, img_h, false)
	if art != null:
		v.add_child(art)
	var text := UIKit.vbox(4)
	text.add_child(_kicker_label(w, n))
	text.add_child(UIKit.label(n.title, "Title" if headline else "H2", true))
	if n.body != "":
		text.add_child(UIKit.label(n.body, "Muted" if headline else "Small", true))
	text.add_child(_meta(w, n, true))
	v.add_child(UIKit.margin(text, 4, 2, 4, 4))
	return UIKit.tap_row(v, func(): _open(w, n), "CardFlat")


## Linha do feed: miniatura à esquerda, chapéu, título e veículo.
static func item(w: GameWorld, n: NewsEvent) -> Control:
	var row := UIKit.hbox(14)
	var th := NewsArt.make(w, n, 96, true)
	if th != null:
		th.custom_minimum_size = Vector2(128, 96)
		th.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		th.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(th)
	else:
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIColors.SURFACE_3
		sb.set_corner_radius_all(10)
		box.add_theme_stylebox_override(&"panel", sb)
		box.custom_minimum_size = Vector2(128, 96)
		box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var ic := UIKit.icon_rect(CAT_ICON.get(n.category, "news"), 40, _icon_color(n))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.add_child(ic)
		row.add_child(box)
	var v := UIKit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_kicker_label(w, n))
	v.add_child(UIKit.label(n.title, "H3", true))
	v.add_child(_meta(w, n, true))
	row.add_child(v)
	return UIKit.tap_row(row, func(): _open(w, n))
