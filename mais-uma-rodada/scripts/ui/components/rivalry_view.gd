class_name RivalryView
extends RefCounted
## Peças de interface da rivalidade: termômetro, retrospecto e linha do clube.


static func heat_color(h: float) -> Color:
	if h >= Rivalry.BIG_AT:
		return UIColors.RED
	if h >= Rivalry.DERBY_AT:
		return UIColors.ORANGE
	if h >= Rivalry.RIXA_AT:
		return UIColors.GOLD
	return UIColors.MUTED


## Barra do termômetro com o nome do nível.
static func meter(h: float) -> Control:
	var row := UIKit.hbox(8)
	var bar := UIKit.bar(h, 100.0, heat_color(h), 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var name := Rivalry.level_name(h)
	var l := UIKit.colored("%s · %d" % [name, int(round(h))] if name != "" else str(int(round(h))), heat_color(h), "Small")
	l.custom_minimum_size.x = 150
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l)
	return row


static func record_text(w: GameWorld, cid: int, other: int) -> String:
	var r := Rivalry.record_for(w, cid, other)
	if int(r["g"]) == 0:
		return "Ainda sem confrontos no save"
	return "%d jogos desde %d · %dV %dE %dD" % [int(r["g"]), int(r["since"]), int(r["w"]), int(r["d"]), int(r["l"])]


## Bloco da prévia: termômetro, retrospecto e o último capítulo. Vazio se não houver rixa.
static func summary(w: GameWorld, cid: int, other: int) -> Control:
	var v := UIKit.vbox(4)
	var h := Rivalry.heat(w, cid, other)
	if h < Rivalry.RIXA_AT:
		return v
	v.add_child(UIKit.label("Rivalidade", "Caps"))
	v.add_child(meter(h))
	v.add_child(UIKit.label(record_text(w, cid, other), "Small"))
	var mem := Rivalry.memory_line(w, cid, other)
	if mem != "":
		v.add_child(UIKit.label(mem + ".", "Small", true))
	if h >= Rivalry.DERBY_AT:
		v.add_child(UIKit.colored("Ingressos disputados: a diretoria trata este jogo como prioridade.", UIColors.ORANGE, "Small", true))
	return v


## Linha tocável da lista de rivais de um clube (abre a linha do tempo da rivalidade).
static func club_row(w: GameWorld, cid: int, e: Dictionary) -> Control:
	var o := w.club(int(e["club"]))
	var box := UIKit.vbox(4)
	var rr := UIKit.hbox(10)
	rr.add_child(UIKit.crest(o, 36))
	var rl := UIKit.label(o.short_name, "H3")
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rr.add_child(rl)
	rr.add_child(UIKit.label(w.league_short(o.league_id), "Small"))
	box.add_child(rr)
	box.add_child(meter(float(e["heat"])))
	box.add_child(UIKit.label(record_text(w, cid, o.id), "Small"))
	var a := cid
	var b := o.id
	return UIKit.tap_row(box, func(): UIManager.push("rivalry", {"a": a, "b": b}), "CardFlat")
