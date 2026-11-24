class_name DashKit
extends RefCounted
## Peças do painel inicial dos dois papéis: o cartão da casa (identidade, caixa com tendência e
## números), a agenda das próximas semanas e as faixas que rolam para o lado (equipe, campeões).


## "12 dez" (sem o dia da semana).
static func short_date(week: int) -> String:
	return GameWorld.fight_date_text(week, false).trim_prefix("sáb, ")


## "nesta sem.", "em 3 sem."
static func short_when(w: GameWorld, week: int) -> String:
	var n := week - w.week
	if n <= 0:
		return "nesta sem."
	if n == 1:
		return "na próxima"
	return "em %d sem." % n


## Cartão da casa: escudo, nome e reputação numa linha; o caixa com a tendência; e os números.
## `tiles` = [[valor, legenda, cor], ...].
static func identity(w: GameWorld, t: Team, sub: String, rep_caption: String, tiles: Array, intro: bool) -> PanelContainer:
	var card := UIKit.card("Card", UITokens.S2)
	var h := UIKit.hbox(UITokens.S2)
	var badge := TeamBadge.new()
	badge.team = t
	badge.custom_minimum_size = Vector2(60, 60)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(badge)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := UIKit.label(t.name, "Section")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var sl := UIKit.label(sub, "Small")
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(sl)
	h.add_child(v)
	var rep := UIKit.vbox(0)
	rep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StarsView.new()
	st.star_size = 18
	st.stars = StarsView.from_value(t.reputation)
	st.size_flags_horizontal = Control.SIZE_SHRINK_END
	rep.add_child(st)
	var rc := rep_caption
	var n := t.rep_log.size()
	if n >= 2:
		var d := t.reputation - float(t.rep_log[maxi(0, n - 5)])
		if absf(d) >= 0.5:
			rc += " %s" % ("subindo" if d > 0.0 else "caindo")
	var rl := UIKit.label(rc, "Caps")
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rep.add_child(rl)
	h.add_child(rep)
	card.add_child(h)
	var inset := PanelContainer.new()
	inset.theme_type_variation = "CardInset"
	inset.add_child(_cash(t, intro))
	card.add_child(inset)
	var stats := UIKit.hbox(0)
	for it: Array in tiles:
		stats.add_child(UIKit.stat_tile(String(it[0]), String(it[1]), it[2] if it.size() > 2 else Color(0, 0, 0, 0)))
	card.add_child(stats)
	return UIKit.card_panel(card)


## Caixa: o número, quanto mudou nas últimas semanas e a linha de tendência.
static func _cash(t: Team, intro: bool) -> Control:
	var h := UIKit.hbox(UITokens.S2)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label("Caixa", "Caps"))
	var val := UIKit.label(Fmt.money(t.balance), "Title")
	val.add_theme_color_override(&"font_color", UIColors.RED if t.balance < 0.0 else UIColors.TEXT)
	v.add_child(val)
	var series: Array = t.cash_log.duplicate()
	var now_k := int(round(t.balance / 1000.0))
	if series.is_empty() or int(series.back()) != now_k:
		series.append(now_k)
	var n := series.size()
	if n >= 2:
		var weeks := mini(4, n - 1)
		var ref := float(series[n - 1 - weeks]) * 1000.0
		# A série guarda milhares: a diferença também é em milhares, sem unidades de enfeite.
		var d := float(now_k - int(series[n - 1 - weeks])) * 1000.0
		if is_zero_approx(d):
			v.add_child(UIKit.label("Estável em %s" % Fmt.plural(weeks, "semana", "semanas"), "Caps"))
		else:
			var txt := "%s%s em %s" % ["+" if d >= 0.0 else "−", Fmt.money(absf(d)), Fmt.plural(weeks, "semana", "semanas")]
			v.add_child(UIKit.colored(txt, UIColors.GREEN if d >= 0.0 else UIColors.RED, "Caps"))
		if intro:
			Anim.count(val, ref, t.balance, func(x: float) -> String: return Fmt.money(x))
	else:
		v.add_child(UIKit.label("A tendência aparece com as semanas", "Caps"))
	h.add_child(v)
	if n >= 3:
		var sp := Sparkline.new()
		sp.values = series
		sp.color = UIColors.GREEN if float(series[n - 1]) >= float(series[0]) else UIColors.RED
		sp.custom_minimum_size = Vector2(190, 64)
		sp.size_flags_horizontal = Control.SIZE_SHRINK_END
		sp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if intro:
			Anim.grow(sp, "reveal", 1.0, 0.7, 0.1)
		h.add_child(sp)
	return h


## Agenda: `items` = [{week, title, text, cb, color}] (qualquer ordem). Devolve null se vazia.
static func agenda(w: GameWorld, items: Array, limit: int = 6) -> Control:
	if items.is_empty():
		return null
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["week"]) < int(b["week"]))
	var v := UIKit.vbox(UITokens.S1)
	v.add_child(UIKit.section_header("Agenda"))
	var rows: Array = []
	for it: Dictionary in items.slice(0, limit):
		var h := UIKit.hbox(UITokens.S2)
		var dv := UIKit.vbox(-2)
		dv.custom_minimum_size.x = 112
		dv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var col: Color = it.get("color", Color(0, 0, 0, 0))
		var dl := UIKit.label(short_date(int(it["week"])), "H3")
		if col.a > 0.0:
			dl.add_theme_color_override(&"font_color", col)
		dv.add_child(dl)
		dv.add_child(UIKit.label(short_when(w, int(it["week"])), "Caps"))
		h.add_child(dv)
		var tv := UIKit.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tl := UIKit.label(String(it["title"]))
		tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tv.add_child(tl)
		var xl := UIKit.label(String(it.get("text", "")), "Small")
		xl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		xl.visible = xl.text != ""
		tv.add_child(xl)
		h.add_child(tv)
		var cb: Callable = it.get("cb", Callable())
		if cb.is_valid():
			var ic := UIKit.icon_rect("forward", 20, UIColors.DIM)
			ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(ic)
		var row := UIKit.tap_row(h, cb)
		row.custom_minimum_size.y = UITokens.H_ROW - 8
		rows.append(row)
	v.add_child(UIKit.menu_group(rows))
	return v


## Faixa que rola para o lado, com título de seção e link.
static func strip(title: String, tiles: Array, action: String = "", cb: Callable = Callable()) -> Control:
	var v := UIKit.vbox(UITokens.S1)
	v.add_child(UIKit.section_header(title, action, cb))
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := UIKit.hbox(UITokens.S1)
	for t in tiles:
		h.add_child(t)
	sc.add_child(h)
	v.add_child(sc)
	return v


## Cartãozinho de lutador para as faixas: retrato grande, nome, a situação numa cápsula e uma
## etiqueta (o ranking, ou o humor quando pede atenção).
static func fighter_tile(w: GameWorld, f: Fighter, tag: String, tag_color: Color, line: String, line_color: Color, cb: Callable) -> PanelContainer:
	var v := UIKit.vbox(4)
	v.custom_minimum_size.x = 148
	if f != null:
		var p := FightKit.portrait(w, f, 148, FightKit.tone_of(w, f))
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(p)
	else:
		var hole := PanelContainer.new()
		hole.theme_type_variation = "IconTile"
		hole.custom_minimum_size = Vector2(148, 148)
		hole.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var ic := UIKit.icon_rect("belt", 56, UIColors.DIM)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hole.add_child(ic)
		v.add_child(hole)
	var nm := UIKit.label(f.short_name() if f != null else "Vago", "H3")
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var top := UIKit.label(tag, "Caps")
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if tag_color.a > 0.0:
		top.add_theme_color_override(&"font_color", UIColors.ink(tag_color))
	v.add_child(top)
	var ln := UIKit.pill(line, line_color if line_color.a > 0.0 else UIColors.MUTED, 17)
	ln.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ln)
	var box := StyleBoxEmpty.new()
	box.set_content_margin_all(6)
	var row := UIKit.tap_row(v, cb, "Card")
	row.add_theme_stylebox_override(&"panel", box)
	row.custom_minimum_size.x = 160
	return row


## Semanas até a virada do ano (a cerimônia dos prêmios), ou -1 se está longe.
static func awards_week(w: GameWorld) -> int:
	for k in range(1, 9):
		if int(GameWorld.date_of(w.week + k)["year"]) > w.year():
			return w.week + k
	return -1


## Notícias recentes (as mesmas dos dois papéis), em um bloco só.
static func news(w: GameWorld, c: VBoxContainer, hats: Dictionary, limit: int = 8) -> void:
	c.add_child(UIKit.section_header("Notícias", "Resultados", func(): UIManager.push("results")))
	var rows: Array = []
	for i in range(w.news.size() - 1, -1, -1):
		var n: Dictionary = w.news[i]
		if w.week - int(n["week"]) > 6 or rows.size() >= limit:
			break
		rows.append(_news_row(w, n, hats))
	if rows.is_empty():
		c.add_child(UIKit.label("Semana calma no mundo do MMA.", "Muted"))
	else:
		c.add_child(UIKit.menu_group(rows))


static func _news_row(w: GameWorld, n: Dictionary, hats: Dictionary) -> PanelContainer:
	var h := UIKit.hbox(UITokens.S2)
	var ids: Array = n.get("fighters", [])
	if not ids.is_empty() and w.fighter(int(ids[0])) != null:
		var p := FightKit.portrait(w, w.fighter(int(ids[0])), 56)
		p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		h.add_child(p)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kind := String(n.get("kind", ""))
	var cap := UIKit.label("%s · %s" % [String(hats.get(kind, "Notícia")), w.weeks_from_now(int(n["week"]))], "Caps")
	if kind in ["cinturao", "marco", "premio", "hall", "meta", "conquista"]:
		cap.add_theme_color_override(&"font_color", UIColors.GOLD)
	elif kind in ["equipe", "organizacao", "tv", "apoio"]:
		cap.add_theme_color_override(&"font_color", UIColors.ACCENT)
	elif kind == "rivalidade":
		cap.add_theme_color_override(&"font_color", UIColors.ORANGE)
	v.add_child(cap)
	v.add_child(UIKit.label(String(n["text"]), "H3" if bool(n.get("important", false)) else "", true))
	h.add_child(v)
	var cb := Callable()
	if not ids.is_empty():
		var fid := int(ids[0])
		cb = func(): UIManager.push("fighter", {"id": fid})
	elif kind in ["meta", "apoio", "conquista"]:
		var tab := String({"meta": "metas", "apoio": "apoio", "conquista": "conquistas"}[kind])
		cb = func(): UIManager.push("season", {"tab": tab})
	return UIKit.tap_row(h, cb)


# --- Virada da semana ---------------------------------------------------------------------

## As pendências abertas agora (para comparar depois de avançar a semana).
static func open_keys(w: GameWorld) -> Array:
	var out: Array = []
	for m: Dictionary in Inbox.pending(w):
		out.append(String(m.get("key", "")))
	return out


## No máximo de semanas que o Adiantar fecha de uma vez.
const SKIP_MAX := 12
## A virada da semana está em andamento (segura o segundo toque no botão).
static var closing := false


## Fecha a semana a partir do Início (dos dois papéis). Com `many`, segue fechando até aparecer
## algo que peça o jogador: uma luta da casa ou uma noite da liga, uma novidade na caixa de
## entrada, a gala, os sócios ou o caixa no vermelho. A conta roda fora da tela (o aviso anima).
static func close_week(screen: BaseScreen, many: bool = false) -> void:
	if closing or GameManager.world == null:
		return
	closing = true
	var w := GameManager.world
	var t := w.user_team()
	if not w.is_president() and t.balance < 0.0 and w.user_fighters().is_empty():
		UIManager.toast("Caixa negativo e ninguém para lutar. Corte custos na Academia.", UIColors.RED)
	var cash := t.balance
	var keys := open_keys(w)
	if many:
		await UIManager.busy("Adiantando…", "Para na próxima novidade. Toque para parar.")
	else:
		await UIManager.busy("Fechando a semana…")
	GameManager.batch = many
	var n := 0
	while true:
		await GameManager.advance_week_async()
		n += 1
		if not many or n >= SKIP_MAX or UIManager.busy_tapped or needs_player(GameManager.world, keys, cash):
			break
		UIManager.busy_text("Semana de %s" % GameWorld.week_short(GameManager.world.week))
	GameManager.batch = false
	UIManager.busy_done()
	closing = false
	w = GameManager.world
	if w == null:
		return
	week_turn(w, cash, keys, n)
	if not is_instance_valid(screen) or UIManager.current() != screen:
		return
	screen.intro_pending = true
	screen.refresh()
	screen.play_intro()
	screen.scroll_to_top()
	SeasonKit.after_week(w, screen.refresh)


## Há algo novo que pede o jogador? (É o que faz o Adiantar parar.)
static func needs_player(w: GameWorld, open_before: Array, cash_before: float) -> bool:
	if w == null:
		return true
	if w.is_president():
		if Org.night_this_week(w) != null:
			return true
	elif not Career.pending_user_bouts(w).is_empty():
		return true
	if not Season.event(w).is_empty() or Season.gala_pending(w):
		return true
	var t := w.user_team()
	if t != null and t.balance < 0.0 and cash_before >= 0.0:
		return true
	Inbox.scan(w)
	for m: Dictionary in Inbox.pending(w):
		if not open_before.has(String(m.get("key", ""))):
			return true
	return false


## A semana virou: o som, a faixa com a data nova e o que mudou (caixa e novidades na caixa de
## entrada). `cash_before` e `open_before` são de antes de avançar.
static func week_turn(w: GameWorld, cash_before: float, open_before: Array, weeks: int = 1) -> void:
	Sfx.play("week", -6.0)
	var t := w.user_team()
	var lines: Array = []
	if weeks > 1:
		lines.append(["%d semanas" % weeks, UIColors.TEXT])
	var d := (t.balance - cash_before) if t != null else 0.0
	if absf(d) >= 1.0:
		lines.append(["%s%s no caixa" % ["+" if d >= 0.0 else "−", Fmt.money(absf(d))], UIColors.GREEN if d >= 0.0 else UIColors.RED])
	var fresh := 0
	for m: Dictionary in Inbox.pending(w):
		if not open_before.has(String(m.get("key", ""))):
			fresh += 1
	if fresh > 0:
		lines.append([Fmt.plural(fresh, "novidade", "novidades"), UIColors.GOLD])
		later(0.5, "mail", -9.0)
	UIManager.banner("Semana de " + GameWorld.week_short(w.week), lines)


## Um som daqui a pouco (para não empilhar tudo no mesmo instante).
static func later(delay: float, sound: String, db: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.create_timer(delay).timeout.connect(func(): Sfx.play(sound, db))

