class_name SeasonKit
extends RefCounted
## Peças da temporada: o termômetro (apoio da cidade ou confiança dos sócios), a linha de uma
## meta, o cartão do Início, a linha de uma conquista, as comemorações e os avisos dos sócios.
## As regras estão em Season e Achievements.

const BRONZE := Color("#C08552")
const SILVER := Color("#B9C0C8")


static func tier_color(tier: int) -> Color:
	match tier:
		1:
			return BRONZE
		2:
			return SILVER
	return UIColors.GOLD


static func cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


## Semanas até a virada do ano.
static func weeks_left(w: GameWorld) -> int:
	var k := 1
	while k < 54 and int(GameWorld.date_of(w.week + k)["year"]) == w.year():
		k += 1
	return k


# --- Termômetro --------------------------------------------------------------------------

## Nome, número, faixa em que está, tendência e a barra. `big`: versão da tela da temporada.
static func meter(w: GameWorld, big: bool = false, intro: bool = false) -> Control:
	var v := Season.value_of(w)
	var tone := SupportBar.tone(v)
	var box := UIKit.vbox(4)
	var head := UIKit.hbox(8)
	var nm := UIKit.label(Season.meter_name(w), "Caps")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	var tr := Season.trend(w)
	if absf(tr) >= 1.0:
		head.add_child(UIKit.colored("%s%d em 4 semanas" % ["+" if tr > 0.0 else "−", int(round(absf(tr)))], UIColors.GREEN if tr > 0.0 else UIColors.RED, "Caps"))
	box.add_child(head)
	var row := UIKit.hbox(UITokens.S2)
	var num := UIKit.label(str(int(round(v))), "Title" if big else "Stat")
	num.add_theme_color_override(&"font_color", UIColors.ink(tone))
	num.custom_minimum_size.x = 76 if big else 56
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if intro:
		var log: Array = w.support.get("log", [])
		var prev := float(log[log.size() - 2]) if log.size() >= 2 else v
		Anim.count(num, prev, v, func(x: float) -> String: return str(int(round(x))))
	row.add_child(num)
	var rv := UIKit.vbox(2)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lv := UIKit.label(Season.level_name(w, v), "H3" if big else "Small")
	lv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rv.add_child(lv)
	var bar := SupportBar.new()
	bar.marker = big
	bar.bar_h = 12.0 if big else 8.0
	var ult: Dictionary = w.support.get("ult", {})
	if not ult.is_empty():
		bar.need = float(ult["need"])
	if intro:
		Anim.grow(bar, "value", v, 0.6, 0.1)
	else:
		bar.value = v
	rv.add_child(bar)
	row.add_child(rv)
	box.add_child(row)
	return box


# --- Metas -------------------------------------------------------------------------------

## Marca da meta: argola enquanto aberta, disco verde com o visto quando cumprida.
class GoalMark extends Control:
	var ok := false
	var soft := false

	func _init() -> void:
		custom_minimum_size = Vector2(28, 28)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		if ok:
			var col := UIColors.GREEN
			if soft:
				col = Color(UIColors.GREEN, 0.45)
			draw_circle(c, r, col)
			var k := r * 0.5
			draw_polyline(PackedVector2Array([c + Vector2(-k, 0.0), c + Vector2(-k * 0.25, k * 0.7), c + Vector2(k, -k * 0.7)]), UIColors.BG, 3.0, true)
		else:
			draw_arc(c, r, 0.0, TAU, 28, UIColors.DIM, 2.5, true)


## Linha de uma meta: marca, título, andamento em texto e barra. `detailed` acrescenta a
## explicação e a recompensa.
static func goal_row(w: GameWorld, g: Dictionary, detailed: bool = false, intro: bool = false) -> Control:
	var p := Season.progress(w, g)
	var ok := bool(p["ok"])
	var final := bool(p["final"])
	var hold := bool(p["hold"])
	var h := UIKit.hbox(UITokens.S2)
	var mark := GoalMark.new()
	mark.ok = ok
	mark.soft = ok and not final
	h.add_child(mark)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(8)
	var t := UIKit.label(String(g["t"]), "H3" if detailed else "", detailed)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not detailed:
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(t)
	if not detailed:
		# Andamento curto: texto comprido (dinheiro) vira porcentagem.
		var short := String(p["text"])
		if short.length() > 16:
			short = "%d%%" % int(round(float(p["frac"]) * 100.0))
		var st := UIKit.label("Cumprida" if final else short, "Caps")
		if ok:
			st.add_theme_color_override(&"font_color", UIColors.GREEN)
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(st)
	v.add_child(top)
	var bar := UIKit.bar(0.0, 1.0, UIColors.GREEN if ok else UIColors.GOLD, 6)
	if intro:
		Anim.grow(bar, "value", float(p["frac"]), 0.6, 0.15)
	else:
		bar.value = float(p["frac"])
	v.add_child(bar)
	if detailed:
		var st2 := UIKit.label(String(p["text"]), "Small")
		if ok:
			st2.add_theme_color_override(&"font_color", UIColors.GREEN)
		v.add_child(st2)
		v.add_child(UIKit.label(String(g["x"]), "Small", true))
		var note := ""
		if final:
			note = "Cumprida %s. Recebido: %s." % [w.weeks_from_now(int(g["done"])), Season.reward_text(w, g)]
		elif hold:
			note = "Vale como o ano terminar. Recompensa: %s." % Season.reward_text(w, g)
		else:
			note = "Paga na hora em que for batida: %s." % Season.reward_text(w, g)
		var nl := UIKit.label(note, "Caps", true)
		if final:
			nl.add_theme_color_override(&"font_color", UIColors.GREEN)
		v.add_child(nl)
	h.add_child(v)
	return h


## Cartão da temporada no Início: termômetro, as três metas e o título de gestor. Toque abre a
## tela da temporada.
static func hub_card(w: GameWorld, intro: bool = false) -> Control:
	if w.goals.is_empty() or w.support.is_empty():
		return null
	var card := UIKit.card("Card", UITokens.S2)
	var head := UIKit.hbox(8)
	var el := UIKit.eyebrow("Temporada de %d" % int(w.goals.get("year", w.year())))
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(el)
	head.add_child(UIKit.label("Faltam %s" % Fmt.plural(weeks_left(w), "semana", "semanas"), "Caps"))
	head.add_child(UIKit.icon_rect("forward", 18, UIColors.DIM))
	card.add_child(head)
	card.add_child(meter(w, false, intro))
	for g: Dictionary in Season.items(w):
		card.add_child(goal_row(w, g, false, intro))
	var rk := Achievements.rank(w)
	var foot := UIKit.hbox(8)
	foot.add_child(UIKit.icon_rect("medal", 20, UIColors.GOLD))
	var fl := UIKit.label("%s · %d de %d conquistas · %d pontos" % [String(rk["name"]), Achievements.count(w), Achievements.list(w).size(), Achievements.points(w)], "Caps")
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	foot.add_child(fl)
	card.add_child(foot)
	var p := UIKit.card_panel(card)
	var tap := Button.new()
	tap.theme_type_variation = "RowOverlay"
	tap.pressed.connect(func():
		Sfx.click()
		UIManager.push("season"))
	UIKit.attach_row_overlay(p, tap)
	return p


# --- Conquistas --------------------------------------------------------------------------

## Linha de uma conquista: medalha na cor do nível, título, texto e o andamento (ou a data).
static func feat_row(w: GameWorld, d: Array, intro: bool = false) -> Control:
	var p := Achievements.progress(w, d)
	var done := bool(p["done"])
	var hidden := bool(d[8]) and not done
	var tier := int(d[3])
	var h := UIKit.hbox(UITokens.S2)
	var tile := PanelContainer.new()
	tile.theme_type_variation = "IconTile"
	tile.custom_minimum_size = Vector2(52, 52)
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var ic := UIKit.icon_rect("medal" if not hidden else "info", 28, tier_color(tier) if done else UIColors.DIM)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(ic)
	h.add_child(tile)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox(8)
	var t := UIKit.label("Conquista escondida" if hidden else String(d[4]), "H3")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not done:
		t.add_theme_color_override(&"font_color", UIColors.MUTED)
	top.add_child(t)
	var tl := UIKit.label("%s · %d" % [String(Achievements.TIER_NAMES[tier]), int(Achievements.TIER_POINTS[tier])], "Caps")
	tl.add_theme_color_override(&"font_color", UIColors.ink(tier_color(tier)) if done else UIColors.DIM)
	top.add_child(tl)
	v.add_child(top)
	v.add_child(UIKit.label("Aparece quando você chegar lá." if hidden else String(d[5]), "Small", true))
	if done:
		var wk := int(p["week"])
		v.add_child(UIKit.colored("Conquistada em %s" % GameWorld.week_text(wk) if wk > 0 else "Conquistada no começo da carreira", UIColors.GREEN, "Caps"))
	elif not hidden and float(d[7]) > 1.0:
		var row := UIKit.hbox(8)
		var bar := UIKit.bar(0.0, 1.0, UIColors.GOLD, 6)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if intro:
			Anim.grow(bar, "value", float(p["frac"]), 0.5, 0.1)
		else:
			bar.value = float(p["frac"])
		row.add_child(bar)
		row.add_child(UIKit.label("%s de %s" % [Achievements.value_text(d, float(p["val"])), Achievements.value_text(d, float(p["n"]))], "Caps"))
		v.add_child(row)
	h.add_child(v)
	return h


## Título de gestor: nome, pontos e a barra até o próximo título.
static func rank_card(w: GameWorld, intro: bool = false) -> Control:
	var rk := Achievements.rank(w)
	var pts := Achievements.points(w)
	var card := UIKit.card("CardHighlight", UITokens.S1)
	var h := UIKit.hbox(UITokens.S2)
	h.add_child(UIKit.icon_rect("trophy", 40, UIColors.GOLD))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label("Título de gestor", "Caps"))
	v.add_child(UIKit.label(String(rk["name"]), "Section"))
	h.add_child(v)
	var pv := UIKit.vbox(0)
	var pl := UIKit.label(str(pts), "Stat")
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(pl)
	var pc := UIKit.label("pontos", "Caps")
	pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pv.add_child(pc)
	h.add_child(pv)
	card.add_child(h)
	if int(rk["next"]) > 0:
		var bar := UIKit.bar(0.0, 1.0, UIColors.GOLD, 8)
		var fr := float(pts - int(rk["at"])) / maxf(1.0, float(int(rk["next"]) - int(rk["at"])))
		if intro:
			Anim.grow(bar, "value", fr, 0.6, 0.1)
		else:
			bar.value = fr
		card.add_child(bar)
		card.add_child(UIKit.label("Faltam %d pontos para %s. %d de %d conquistas." % [int(rk["next"]) - pts, String(rk["next_name"]), Achievements.count(w), Achievements.list(w).size()], "Small", true))
	else:
		card.add_child(UIKit.label("O título mais alto. %d de %d conquistas." % [Achievements.count(w), Achievements.list(w).size()], "Small", true))
	return UIKit.card_panel(card)


# --- Comemorações e avisos ---------------------------------------------------------------

## Mostra o que saiu desde a última vez (meta cumprida, conquista): até três avisos, um som só.
static func celebrate(w: GameWorld) -> void:
	if w == null or w.pops.is_empty() or UIManager.main == null or Season.gala_pending(w):
		return
	var pops := w.pops.duplicate()
	w.pops.clear()
	var shown := 0
	for p: Dictionary in pops:
		if shown >= 3:
			break
		if String(p["k"]) == "goal":
			UIManager.award_toast("Meta cumprida", String(p["x"]), "check", shown == 0)
		else:
			UIManager.award_toast("Conquista · %s" % String(p["x"]), String(p["t"]), "medal", shown == 0)
		shown += 1
	if pops.size() > shown:
		UIManager.toast("E mais %s na tela da temporada." % Fmt.plural(pops.size() - shown, "novidade", "novidades"))


## Comemora daqui a pouco (depois do som do resultado da luta ou do fechamento da noite).
static func celebrate_later(delay: float = 1.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.create_timer(delay).timeout.connect(func(): celebrate(GameManager.world))


## Depois de avançar a semana: aviso dos sócios (intervenção ou fim de mandato), a cerimônia do
## ano que acabou e as comemorações. Devolve verdadeiro se abriu alguma coisa por cima.
static func after_week(w: GameWorld, on_change: Callable) -> bool:
	if board_event(w, on_change):
		return true
	if Season.gala_pending(w) and UIManager.main != null:
		UIManager.push("gala", {"year": int(w.gala["year"])})
		return true
	celebrate(w)
	return false


## Intervenção dos sócios (aviso) ou fim de mandato (decisão). Devolve verdadeiro se mostrou.
static func board_event(w: GameWorld, on_change: Callable) -> bool:
	if w == null or UIManager.main == null or UIManager.has_modal():
		return false
	var e := Season.event(w)
	if e.is_empty():
		return false
	var t := w.user_team()
	if String(e["k"]) == "interv":
		Season.clear_event(w)
		GameManager.save_now()
		Sfx.play("notify_bad", -6.0)
		UIManager.dialog("Intervenção dos sócios", "O ultimato venceu sem a confiança voltar a %d. Os sócios retiraram %s do caixa em dividendos e o prestígio da %s caiu 6 pontos.\n\nA confiança recomeça em 42. Mais um ultimato perdido encerra o seu mandato." % [int(Season.ULT_NEED), Fmt.money(float(e.get("fee", 0.0))), t.name],
			[{"text": "Entendi", "style": "PrimaryButton", "cb": on_change}])
		return true
	if not Season.fired(w):
		Season.clear_event(w)
		return false
	Sfx.play("lose", -6.0)
	var v := UIKit.vbox(UITokens.S3)
	v.custom_minimum_size.x = 560
	v.add_child(UIKit.label("Fim do mandato", "H2", true))
	var body := UIKit.label("Os sócios votaram pela sua saída da presidência da %s: dois ultimatos perdidos." % t.name, "", true)
	body.add_theme_color_override(&"font_color", UIColors.MUTED)
	v.add_child(body)
	var stats := UIKit.hbox(0)
	stats.add_child(UIKit.stat_tile(str(int(Season.life(w, "nights"))), "Noites"))
	stats.add_child(UIKit.stat_tile(str(int(Season.life(w, "title_bouts"))), "Cinturões em jogo"))
	stats.add_child(UIKit.stat_tile(str(int(Season.life(w, "goals_met"))), "Metas cumpridas"))
	v.add_child(stats)
	var floor_cash: float = Org.START_FUNDS[0]
	var deal := "o caixa volta a %s" % Fmt.money(floor_cash) if t.balance < floor_cash else "um quarto do caixa sai com os antigos sócios"
	v.add_child(UIKit.label("Outro grupo de investidores quer comprar a parte deles e manter você no comando: %s e o prestígio da liga cai 8 pontos." % deal, "Small", true))
	var go := UIKit.button("Começar novo mandato", "PrimaryButton", func():
		UIManager.close_modal()
		Season.new_term(w)
		Achievements.check(w)
		GameManager.save_now()
		on_change.call())
	v.add_child(go)
	v.add_child(UIKit.button("Sair para o menu", "GhostButton", func():
		UIManager.close_modal()
		GameManager.close_career()
		UIManager.goto("menu")))
	UIManager.show_modal(v, false, false)
	return true
