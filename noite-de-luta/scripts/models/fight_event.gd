class_name FightEvent
extends RefCounted
## Uma noite de lutas: camada (0 regional, 1 continental, 2 Liga Global), cidade e o card.

var id: int = -1
var week: int = 0
var tier: int = 0
var name: String = ""
var city: String = ""
var nation: String = ""
## Lutas na ordem do card: a última é a principal.
var bouts: Array = []
## Quantas lutas o card comporta.
var slots: int = 6
var done: bool = false
## Liga Global com presidente: evento numerado com pay-per-view (os outros são Fight Night).
var ppv: bool = false
## Presidente: a noite já foi fechada (bônus escolhidos e contas feitas).
var closed: bool = false
## Fechamento da noite (presidente): público, receitas, custos, bônus. Vazio antes.
var report: Dictionary = {}


func to_dict() -> Dictionary:
	return {"id": id, "week": week, "tier": tier, "name": name, "city": city, "nation": nation, "bouts": bouts, "slots": slots, "done": done,
		"ppv": ppv, "closed": closed, "report": report}


static func from_dict(d: Dictionary) -> FightEvent:
	var e := FightEvent.new()
	e.id = int(d["id"])
	e.week = int(d.get("week", 0))
	e.tier = int(d.get("tier", 0))
	e.name = String(d.get("name", ""))
	e.city = String(d.get("city", ""))
	e.nation = String(d.get("nation", ""))
	e.bouts = (d.get("bouts", []) as Array).map(func(v): return int(v))
	e.slots = int(d.get("slots", 6))
	e.done = bool(d.get("done", false))
	e.ppv = bool(d.get("ppv", false))
	e.closed = bool(d.get("closed", false))
	e.report = d.get("report", {})
	return e
