class_name Bout
extends RefCounted
## Uma luta marcada (ou já feita). `a` é o corner vermelho (o mais bem ranqueado), `b` o azul.

var id: int = -1
var event_id: int = -1
var week: int = 0
var a: int = -1
var b: int = -1
var division: String = "M70"
var rounds: int = 3
var title: bool = false
var main_event: bool = false
## Bolsa de cada lado: {"show": valor por lutar, "win": bônus de vitória}.
var purse_a: Dictionary = {"show": 0.0, "win": 0.0}
var purse_b: Dictionary = {"show": 0.0, "win": 0.0}
## marcada | feita | cancelada
var status: String = "marcada"
## {winner (id ou -1), method (KO, TKO, FIN, DEC, EMP, SR), detail, round, time (s no round),
##  cards [[a, b] por juiz], stats {a: {...}, b: {...}}, missed_weight [ids]}
var result: Dictionary = {}
## Pesagem: {"kg": [a, b], "missed": [ids], "mods": [{}, {}], "cut": [% a, % b]}
var weigh: Dictionary = {}
## Narração resumida das lutas da equipe do jogador (lances principais), para rever.
var log: Array = []


func other(fid: int) -> int:
	return b if fid == a else a


func purse_of(fid: int) -> Dictionary:
	return purse_a if fid == a else purse_b


func has(fid: int) -> bool:
	return fid == a or fid == b


func to_dict() -> Dictionary:
	return {"id": id, "ev": event_id, "week": week, "a": a, "b": b, "div": division, "rounds": rounds,
		"title": title, "main": main_event, "pa": purse_a, "pb": purse_b, "status": status, "res": result, "log": log, "weigh": weigh}


static func from_dict(d: Dictionary) -> Bout:
	var x := Bout.new()
	x.id = int(d["id"])
	x.event_id = int(d.get("ev", -1))
	x.week = int(d.get("week", 0))
	x.a = int(d.get("a", -1))
	x.b = int(d.get("b", -1))
	x.division = String(d.get("div", "M70"))
	x.rounds = int(d.get("rounds", 3))
	x.title = bool(d.get("title", false))
	x.main_event = bool(d.get("main", false))
	x.purse_a = d.get("pa", {"show": 0.0, "win": 0.0})
	x.purse_b = d.get("pb", {"show": 0.0, "win": 0.0})
	x.status = String(d.get("status", "marcada"))
	x.result = d.get("res", {})
	x.log = d.get("log", [])
	x.weigh = d.get("weigh", {})
	return x
