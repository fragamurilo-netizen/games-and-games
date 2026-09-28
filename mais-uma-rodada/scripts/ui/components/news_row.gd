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
	"renovacao": "check", "impasse": "clock", "atrito": "bolt", "protesto": "chat", "investimento": "money", "estadio": "home",
	"social": "heart", "recorde": "star", "joia": "star", "rumor_ok": "check", "rumor_nao": "close", "despedida": "clock",
	"aniversario": "trophy", "giro": "news", "briga_titulo": "trophy", "briga_z": "down", "classico_previa": "bolt",
	"tecnicos": "whistle", "torcida": "chat", "clube": "home", "personalidade": "chat", "mercado": "swap", "jogador": "shirt", "liga": "table",
}


const MARKET_CATS := ["transferencia", "transferencia_rival", "transferencia_livre", "venda_usuario", "proposta_recebida", "janela_abre", "janela_fecha", "contrato_fim", "rumor",
	"renovacao", "impasse", "rumor_ok", "rumor_nao", "mercado"]
## Notícias ruins (cor vermelha e torcida pessimista) e boas (verde e torcida animada).
const BAD_CATS := ["sequencia_derrotas", "rebaixamento", "lesao_grave", "sem_vencer", "diretoria_ultimato", "demissao", "copa_eliminado", "estadual_eliminado",
	"atrito", "protesto", "briga_z"]
const GOOD_CATS := ["campeao", "acesso", "jovem_explode", "primeiro_gol", "copa_campeao", "estadual_campeao", "mundial_campeao",
	"renovacao", "investimento", "recorde", "joia", "rumor_ok", "aniversario"]
const KICKERS := {
	"selecao": "SELEÇÕES", "goleada": "RODADA", "zebra": "RODADA", "classico_vitoria": "CLÁSSICO", "classico_empate": "CLÁSSICO",
	"rivalidade": "CLÁSSICO", "lider": "LIDERANÇA", "sequencia_vitorias": "RODADA", "sequencia_derrotas": "RODADA", "sem_vencer": "RODADA",
	"hattrick": "DESTAQUE", "primeiro_gol": "BASE", "artilheiro": "ARTILHARIA", "marco_gols": "DESTAQUE", "premio": "PRÊMIOS",
	"lesao_grave": "DEPARTAMENTO MÉDICO", "aposentadoria_anuncio": "CARREIRA", "aposentadoria": "CARREIRA", "campeao": "TÍTULO",
	"acesso": "ACESSO", "rebaixamento": "REBAIXAMENTO", "jovem_explode": "BASE", "base": "BASE", "temporada": "TEMPORADA",
	"diretoria_ultimato": "BASTIDORES", "demissao": "TÉCNICOS", "novo_tecnico": "TÉCNICOS", "imprensa": "BASTIDORES",
	"atrito": "VESTIÁRIO", "protesto": "TORCIDA", "investimento": "BASTIDORES", "estadio": "ESTÁDIO", "social": "REDES SOCIAIS",
	"recorde": "RECORDE", "joia": "REVELAÇÃO", "despedida": "DESPEDIDA", "aniversario": "MEMÓRIA", "giro": "PELO MUNDO",
	"briga_titulo": "CORRIDA PELO TÍTULO", "briga_z": "LUTA CONTRA A QUEDA", "classico_previa": "CLÁSSICO", "tecnicos": "TÉCNICOS",
	"torcida": "TORCIDA", "jogador": "JOGADOR", "liga": "LIGA", "clube": "BASTIDORES", "personalidade": "VESTIÁRIO",
}


## Editoria resumida usada pelos novos cards e pela manchete.
static func section_of(n: NewsEvent) -> String:
	var cat := n.category
	if cat.begins_with("transferencia") or MARKET_CATS.has(cat):
		return "Mercado"
	if cat.begins_with("copa") or cat.begins_with("estadual") or cat.begins_with("mundial"):
		return "Copas"
	if cat in ["diretoria_ultimato", "demissao", "novo_tecnico", "atrito", "protesto", "investimento", "estadio", "tecnicos", "torcida", "clube", "personalidade"]:
		return "Bastidores"
	if cat == "social":
		return "Redes"
	if cat == "giro":
		return "Mundo"
	if cat == "selecao":
		return "Seleções"
	if cat in ["premio", "campeao", "acesso", "rebaixamento", "lider", "artilheiro", "marco_gols", "temporada", "recorde", "briga_titulo", "briga_z", "aniversario", "liga"]:
		return "Campeonato"
	if cat in ["jovem_explode", "base", "primeiro_gol", "joia"]:
		return "Revelações"
	if cat in ["lesao_grave", "aposentadoria", "aposentadoria_anuncio", "despedida", "jogador"]:
		return "Elenco"
	if cat == "imprensa":
		return "Imprensa"
	return "Resultados"


static func _tone(n: NewsEvent) -> Color:
	if n.category in BAD_CATS:
		return UIColors.RED
	if n.category in GOOD_CATS:
		return UIColors.GREEN
	return UIColors.ACCENT


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
	if n.category in BAD_CATS:
		col = UIColors.RED
	elif n.category in GOOD_CATS:
		col = UIColors.GREEN
	return col


static func _open(w: GameWorld, n: NewsEvent) -> void:
	n.read = true
	UIManager.show_modal(article(w, n), true)


const FAN_LINES := {
	"good": ["Que fase! Ninguém segura esse time.", "Eu avisei desde o começo da temporada.", "Assim dá gosto de acompanhar.", "Isso é trabalho, não é sorte.", "Tem que valorizar esse elenco."],
	"bad": ["Precisa mudar alguma coisa, e rápido.", "Já vi esse filme antes e não termina bem.", "Diretoria tem que se mexer.", "Sem cobrança não vai.", "Paciência tem limite."],
	"market": ["Grande contratação, se vier na forma de antes.", "Esse preço tá fora da realidade.", "Pode dar muito certo ou muito errado.", "Vai ser titular em duas semanas.", "Não era a prioridade do elenco."],
	"social": ["Ídolo demais!", "Esse aí é gente como a gente.", "Posta menos e joga mais.", "Mensagem bonita, respeito.", "Tô de olho nesse post aí..."],
	"neutral": ["Vamos ver no campo.", "Notícia interessante, mas é cedo pra julgar.", "Quero ver o próximo jogo.", "Segue o jogo.", "Isso muda a briga na tabela."],
}
const FAN_NAMES := ["Arquibancada Raiz", "Torcedor de Sofá", "Tático de Bar", "Dona Tabela", "Estatístico Amador", "Velha Guarda", "Ultra da Curva", "Olheiro de Fim de Semana"]


## Matéria completa: chapéu, título, texto, quem aparece, repercussão e relacionadas.
static func article(w: GameWorld, n: NewsEvent) -> Control:
	var v := UIKit.vbox(12)
	var k := UIKit.label(kicker(w, n), "Caps")
	k.add_theme_color_override(&"font_color", _icon_color(n))
	v.add_child(k)
	v.add_child(UIKit.label(n.title, "H1", true))
	v.add_child(UIKit.label(source(w, n) + "  ·  " + when(n), "Small"))
	v.add_child(UIKit.label(n.body if n.body != "" else n.title, "", true))
	# Blocos com os dados da notícia (placar, ficha da transferência, tabela, recorde...)
	for blk: Control in NewsExtras.blocks(w, n):
		v.add_child(blk)
	# Quem aparece na matéria
	var p := w.player(n.player_id) if n.player_id >= 0 else null
	var c := w.club(n.club_id) if n.club_id >= 0 else null
	var links := UIKit.hbox(10)
	if p != null:
		var pid := p.id
		var bp := UIKit.button("Ver " + p.display_name(), "GhostButton", func():
			UIManager.close_modal()
			UIManager.push("player", {"id": pid}), "shirt")
		bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		links.add_child(bp)
	if c != null:
		var cid := c.id
		var bc := UIKit.button("Ver " + c.short_name, "GhostButton", func():
			UIManager.close_modal()
			UIManager.push("club", {"id": cid}), "shield")
		bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		links.add_child(bc)
	if links.get_child_count() > 0:
		v.add_child(links)
	# Repercussão da torcida (fixa por notícia)
	var mood := "neutral"
	if n.category == "social":
		mood = "social"
	elif MARKET_CATS.has(n.category):
		mood = "market"
	elif n.category in BAD_CATS:
		mood = "bad"
	elif n.category in GOOD_CATS or n.category in ["goleada", "sequencia_vitorias", "hattrick", "lider", "classico_vitoria", "despedida"]:
		mood = "good"
	var rc := UIKit.card("CardInset", 6)
	rc.add_child(UIKit.label("Repercussão", "Caps"))
	var h := absi(hash(n.title + str(n.year)))
	var pool: Array = FAN_LINES[mood]
	for i in 3:
		var row := UIKit.vbox(0)
		row.add_child(UIKit.label(String(FAN_NAMES[(h + i * 3) % FAN_NAMES.size()]), "H3"))
		row.add_child(UIKit.label(String(pool[(h / 7 + i * 2) % pool.size()]), "Small", true))
		rc.add_child(row)
	var likes := 40 + h % 900
	rc.add_child(UIKit.label("%d curtidas · %d comentários" % [likes, likes / 6 + 3], "Small"))
	v.add_child(UIKit.card_panel(rc))
	# Relacionadas
	var rel: Array = []
	for i in range(w.news.size() - 1, -1, -1):
		var o: NewsEvent = w.news[i]
		if o == n:
			continue
		if (n.club_id >= 0 and o.club_id == n.club_id) or (n.player_id >= 0 and o.player_id == n.player_id):
			rel.append(o)
			if rel.size() >= 3:
				break
	if not rel.is_empty():
		v.add_child(UIKit.label("Leia também", "Caps"))
		for o: NewsEvent in rel:
			var on := o
			var b := UIKit.button(o.title, "GhostButton", func():
				UIManager.close_modal()
				_open(w, on))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			v.add_child(b)
	var close := UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal())
	v.add_child(close)
	return v


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


## Manchete em destaque para o novo layout de notícias.
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
	col.add_child(UIKit.label(n.title, "Title", true))
	if n.body != "":
		var body := UIKit.label(n.body, "Muted", true)
		body.max_lines_visible = 4
		body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(body)
	col.add_child(_meta(w, n, true))
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
		var tile := PanelContainer.new()
		tile.theme_type_variation = "IconTile"
		tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tile.add_child(UIKit.icon_rect(CAT_ICON.get(n.category, "news"), 26, _icon_color(n)))
		row.add_child(tile)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := UIKit.hbox(8)
	var sec := UIKit.label(section_of(n).to_upper(), "Caps")
	var tone := _tone(n)
	sec.add_theme_color_override(&"font_color", tone if tone != UIColors.MUTED else UIColors.DIM)
	head.add_child(sec)
	if not n.read:
		head.add_child(UIKit.pill("NOVA", UIColors.ACCENT, 13))
	v.add_child(head)
	v.add_child(UIKit.label(n.title, "H3", true))
	if n.body != "" and (not compact or n.importance >= NewsEvent.IMP_HIGH):
		var body := UIKit.label(n.body, "Small", true)
		body.max_lines_visible = 3
		body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(body)
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
