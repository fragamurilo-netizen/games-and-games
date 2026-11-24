class_name FightHud
extends RefCounted
## Peças do HUD da luta, no jeito de uma transmissão: a linha de números do placar, a
## comparação ao vivo (round ou luta inteira), o placar não oficial da transmissão e a ficha
## oficial dos juízes, round a round. Nada aqui gasta sorteio: lê o que o motor já contou.

## Juízes fictícios; três por luta, sempre os mesmos para a mesma luta.
const JUDGES: Array[String] = ["A. Brandão", "D. Okafor", "M. Lindqvist", "R. Tavares", "S. Yamada", "J. Castellano",
	"P. Novak", "H. Mwangi", "L. Ferreira", "C. Whitlock", "T. Azevedo", "E. Marchetti", "K. Sandoval", "N. Petrov",
	"B. Achterberg", "G. Monteiro", "I. Haddad", "V. Kowalczyk", "F. Arantes", "O. Lindahl"]

## Linhas da comparação: [chave, rótulo]. "sig" e "td" mostram "certos de tentados".
const ROWS: Array = [["sig", "Golpes significativos"], ["head", "Cabeça"], ["body", "Corpo"], ["legs", "Pernas"],
	["kd", "Knockdowns"], ["td", "Quedas"], ["sub_att", "Finalizações tentadas"], ["ctrl", "Controle"]]
const KEYS: Array[String] = ["sig_att", "sig_land", "head", "body", "legs", "kd", "td_att", "td", "sub_att", "ctrl", "rev", "adv", "dmg"]


static func judge_names(b: Bout) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash([b.id, b.a, b.b, "juizes"])
	var pool: Array = JUDGES.duplicate()
	var out: Array = []
	for _i in 3:
		var k := r.randi_range(0, pool.size() - 1)
		out.append(pool[k])
		pool.remove_at(k)
	return out


static func blank() -> Dictionary:
	var d := {}
	for k: String in KEYS:
		d[k] = 0.0
	return d


## Soma os números de vários rounds.
static func sum(list: Array) -> Dictionary:
	var d := blank()
	for st: Dictionary in list:
		for k: String in KEYS:
			d[k] = float(d[k]) + float(st.get(k, 0.0))
	return d


static func value(key: String, st: Dictionary) -> float:
	if key == "sig":
		return float(st.get("sig_land", 0.0))
	return float(st.get(key, 0.0))


static func text(key: String, st: Dictionary) -> String:
	match key:
		"sig":
			return "%d de %d" % [int(st.get("sig_land", 0.0)), int(st.get("sig_att", 0.0))]
		"td":
			return "%d de %d" % [int(st.get("td", 0.0)), int(st.get("td_att", 0.0))]
		"ctrl":
			return Fmt.elapsed(float(st.get("ctrl", 0.0)))
	return str(int(st.get(key, 0.0)))


## Quanto cada lado fez no round, numa nota só (a mesma conta do técnico no intervalo).
static func weight(st: Dictionary) -> float:
	return float(st.get("sig_land", 0.0)) + float(st.get("kd", 0.0)) * 8.0 + float(st.get("td", 0.0)) * 2.5 \
		+ float(st.get("ctrl", 0.0)) / 25.0 + float(st.get("sub_att", 0.0)) * 1.5 + float(st.get("dmg", 0.0)) * 1.5


## Round pela transmissão: [nota A, nota B]. Não é o cartão dos juízes.
static func broadcast_round(a: Dictionary, b: Dictionary) -> Array:
	var sa := weight(a)
	var sb := weight(b)
	if absf(sa - sb) < 0.75 and maxf(sa, sb) < minf(sa, sb) * 1.08 + 0.75:
		return [10, 10]
	var w := 0 if sa > sb else 1
	var sts := [a, b]
	var hi := maxf(sa, sb)
	var lo := minf(sa, sb)
	var big: bool = hi / maxf(0.5, lo) > 4.0 and (float(sts[w].get("kd", 0.0)) >= 1.0 or float(sts[w].get("dmg", 0.0)) > 10.0 or float(sts[w].get("ctrl", 0.0)) > 220.0)
	var card := [10, 10]
	card[1 - w] = 8 if big else 9
	return card


## Frase curta de quem está levando o round agora.
static func lean_text(a: Dictionary, b: Dictionary, name_a: String, name_b: String) -> String:
	var sa := weight(a)
	var sb := weight(b)
	if maxf(sa, sb) < 1.0:
		return "Round ainda sem dono"
	if absf(sa - sb) < 0.75 or maxf(sa, sb) < minf(sa, sb) * 1.15:
		return "Round parelho"
	var who := name_a if sa > sb else name_b
	if maxf(sa, sb) > minf(sa, sb) * 2.2 + 2.0:
		return "%s domina o round" % who
	return "%s na frente no round" % who


static func corner_color(i: int) -> Color:
	return UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE


## Tom claro da cor do corner, para texto sobre o fundo escuro.
static func corner_ink(i: int) -> Color:
	return corner_color(i).lerp(UIColors.TEXT, 0.45)


## Legenda dos corners: "■ Fulano   ■ Beltrano" (o primeiro número é sempre do vermelho).
static func legend(name_a: String, name_b: String) -> HBoxContainer:
	var h := UIKit.hbox(UITokens.S2)
	var names := [name_a, name_b]
	for i in 2:
		var item := UIKit.hbox(6)
		var sw := ColorRect.new()
		sw.color = corner_color(i)
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(sw)
		var l := UIKit.label(String(names[i]), "Caps")
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(l)
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(item)
	return h


## Barra dividida: o vermelho cresce da esquerda, o azul da direita, na proporção dos dois.
class DuelBar:
	extends Control
	var a := 0.0
	var b := 0.0
	var split := 0.5
	var _tw: Tween

	func _init(h: int = 6) -> void:
		custom_minimum_size = Vector2(0, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_values(x: float, y: float) -> void:
		if is_equal_approx(x, a) and is_equal_approx(y, b):
			return
		a = x
		b = y
		var to := 0.5 if a + b <= 0.0 else clampf(a / (a + b), 0.06, 0.94)
		if _tw != null and _tw.is_valid():
			_tw.kill()
		if Anim.on() and is_inside_tree():
			_tw = create_tween()
			_tw.tween_property(self, "split", to, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tw.parallel().tween_method(func(_k: float): queue_redraw(), 0.0, 1.0, 0.3)
		else:
			split = to
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var gap := 3.0
		var x := roundf((w - gap) * split)
		var idle := a + b <= 0.0
		var ca := UIColors.SURFACE_3 if idle else (FightHud.corner_color(0) if a >= b else FightHud.corner_color(0).darkened(0.45))
		var cb := UIColors.SURFACE_3 if idle else (FightHud.corner_color(1) if b >= a else FightHud.corner_color(1).darkened(0.45))
		draw_rect(Rect2(0, 0, x, h), ca)
		draw_rect(Rect2(x + gap, 0, w - x - gap, h), cb)


## Uma linha da comparação: valor do vermelho, rótulo, valor do azul e a barra dividida.
class StatRow:
	extends VBoxContainer
	var key := ""
	var la: Label
	var lb: Label
	var bar: FightHud.DuelBar

	func _init(k: String, caption: String, side_w: int = 120) -> void:
		key = k
		add_theme_constant_override(&"separation", 4)
		var r := UIKit.hbox(8)
		la = UIKit.label("0", "H3")
		la.custom_minimum_size.x = side_w
		la.add_theme_font_override(&"font", DataTable.tabular_font())
		r.add_child(la)
		var n := UIKit.label(caption, "Caps")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r.add_child(n)
		lb = UIKit.label("0", "H3")
		lb.custom_minimum_size.x = side_w
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lb.add_theme_font_override(&"font", DataTable.tabular_font())
		r.add_child(lb)
		add_child(r)
		bar = FightHud.DuelBar.new(6)
		add_child(bar)

	func set_stats(sa: Dictionary, sb: Dictionary) -> void:
		var va := FightHud.value(key, sa)
		var vb := FightHud.value(key, sb)
		la.text = FightHud.text(key, sa)
		lb.text = FightHud.text(key, sb)
		la.add_theme_color_override(&"font_color", UIColors.TEXT if va >= vb and va > 0.0 else UIColors.MUTED)
		lb.add_theme_color_override(&"font_color", UIColors.TEXT if vb >= va and vb > 0.0 else UIColors.MUTED)
		bar.set_values(va, vb)


## A comparação completa (todas as linhas de ROWS, ou só as de `keys`).
class StatPanel:
	extends VBoxContainer
	var rows: Array = []

	func _init(keys: Array = [], side_w: int = 120) -> void:
		add_theme_constant_override(&"separation", UITokens.S2)
		for r: Array in FightHud.ROWS:
			if not keys.is_empty() and not keys.has(r[0]):
				continue
			var row := FightHud.StatRow.new(String(r[0]), String(r[1]), side_w)
			rows.append(row)
			add_child(row)

	func set_stats(sa: Dictionary, sb: Dictionary) -> void:
		for row: FightHud.StatRow in rows:
			row.set_stats(sa, sb)


## Linha de números do placar, sempre à vista: golpes, quedas e controle da luta inteira.
class MiniLine:
	extends HBoxContainer
	var cells: Array = [] # [chave, Label vermelho, Label azul]

	func _init() -> void:
		add_theme_constant_override(&"separation", 0)
		var items := [["sig", "Golpes"], ["td", "Quedas"], ["ctrl", "Controle"]]
		for i in items.size():
			if i > 0:
				var sep := ColorRect.new()
				sep.color = UITokens.HAIRLINE
				sep.custom_minimum_size = Vector2(2, 22)
				sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				add_child(sep)
			var cell := UIKit.hbox(6)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.alignment = BoxContainer.ALIGNMENT_CENTER
			var la := UIKit.label("0", "H3")
			la.add_theme_font_override(&"font", DataTable.tabular_font())
			la.add_theme_font_size_override(&"font_size", UITokens.F_META)
			var cap := UIKit.label(String(items[i][1]), "Caps")
			var lb := UIKit.label("0", "H3")
			lb.add_theme_font_override(&"font", DataTable.tabular_font())
			lb.add_theme_font_size_override(&"font_size", UITokens.F_META)
			cell.add_child(la)
			cell.add_child(cap)
			cell.add_child(lb)
			add_child(cell)
			cells.append([String(items[i][0]), la, lb])

	func set_stats(sa: Dictionary, sb: Dictionary) -> void:
		for c: Array in cells:
			var key: String = c[0]
			var va := FightHud.value(key, sa)
			var vb := FightHud.value(key, sb)
			var la: Label = c[1]
			var lb: Label = c[2]
			la.text = Fmt.elapsed(va) if key == "ctrl" else str(int(va))
			lb.text = Fmt.elapsed(vb) if key == "ctrl" else str(int(vb))
			la.add_theme_color_override(&"font_color", FightHud.corner_ink(0) if va > vb else (UIColors.TEXT if va == vb and va > 0.0 else UIColors.MUTED))
			lb.add_theme_color_override(&"font_color", FightHud.corner_ink(1) if vb > va else (UIColors.TEXT if va == vb and vb > 0.0 else UIColors.MUTED))


## Bolinhas dos rounds no placar: os que passaram, o atual e os que faltam.
class Pips:
	extends Control
	var total := 3
	var current := 1
	var over := false

	func _init() -> void:
		custom_minimum_size = Vector2(0, 10)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_round(n: int, of: int, done: bool = false) -> void:
		current = n
		total = of
		over = done
		custom_minimum_size.x = of * 16.0 - 6.0
		queue_redraw()

	func _draw() -> void:
		var w := total * 16.0 - 6.0
		var x0 := (size.x - w) * 0.5
		for i in total:
			var col := UIColors.SURFACE_3
			if i + 1 < current or (over and i + 1 <= current):
				col = UIColors.MUTED
			elif i + 1 == current:
				col = UIColors.GOLD
			draw_rect(Rect2(x0 + i * 16.0, 2, 10, 6), col)


## Tabela de cartões round a round. `names`: rótulo de cada linha (os juízes, ou "Transmissão").
## `per_row`: para cada linha, a lista de [nota A, nota B] por round. Rounds que não chegaram a
## acontecer ficam com um traço. Devolve o VBox; as linhas ficam em meta "rows" para revelar.
static func cards_table(names: Array, per_row: Array, rounds: int, pending_round: int = -1) -> VBoxContainer:
	var v := UIKit.vbox(2)
	var cw := 62 if rounds <= 3 else 50
	var tw := 82 if rounds <= 3 else 72
	var head := UIKit.hbox(0)
	var hn := UIKit.label("", "Caps")
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hn)
	for r in rounds:
		var hl := UIKit.label("R%d" % (r + 1), "Caps")
		hl.custom_minimum_size.x = cw
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(hl)
	var ht := UIKit.label("Total", "Caps")
	ht.custom_minimum_size.x = tw
	ht.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(ht)
	v.add_child(UIKit.margin(head, 14, 0, 14, 0))
	var rows: Array = []
	for j in names.size():
		var cards: Array = per_row[j] if j < per_row.size() else []
		var p := PanelContainer.new()
		p.theme_type_variation = "CardFlat"
		var row := UIKit.hbox(0)
		row.custom_minimum_size.y = 36
		var nm := UIKit.label(String(names[j]), "Small")
		nm.add_theme_color_override(&"font_color", UIColors.TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(nm)
		var tot := [0, 0]
		for r in rounds:
			var cell := UIKit.label("–", "Meta")
			cell.custom_minimum_size.x = cw
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_theme_font_override(&"font", DataTable.tabular_font())
			if r < cards.size():
				var c: Array = cards[r]
				var ca := int(c[0])
				var cb := int(c[1])
				tot[0] += ca
				tot[1] += cb
				cell.text = "%d-%d" % [ca, cb]
				cell.add_theme_color_override(&"font_color", corner_ink(0) if ca > cb else (corner_ink(1) if cb > ca else UIColors.TEXT))
			elif r == pending_round:
				cell.text = "…"
			row.add_child(cell)
		var tl := UIKit.label("%d-%d" % [tot[0], tot[1]] if not cards.is_empty() else "–", "H3")
		tl.custom_minimum_size.x = tw
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tl.add_theme_font_override(&"font", DataTable.tabular_font())
		if tot[0] != tot[1]:
			tl.add_theme_color_override(&"font_color", corner_ink(0) if tot[0] > tot[1] else corner_ink(1))
		row.add_child(tl)
		p.add_child(row)
		v.add_child(p)
		rows.append(p)
	v.set_meta(&"rows", rows)
	return v


## Placar da transmissão até aqui: uma linha, com os rounds já fechados.
static func broadcast_cards(round_stats: Array, upto: int) -> Array:
	var out: Array = []
	for r in mini(upto, round_stats.size()):
		var rs: Array = round_stats[r]
		out.append(broadcast_round(rs[0], rs[1]))
	return out


## Comparação dos números finais de uma luta (totais guardados no resultado).
static func totals_panel(b: Bout) -> Control:
	var st: Array = b.result.get("stats", [])
	if st.size() < 2:
		return null
	var p := StatPanel.new()
	p.set_stats(st[0], st[1])
	return p
