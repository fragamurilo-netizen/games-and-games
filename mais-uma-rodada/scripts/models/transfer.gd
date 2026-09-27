class_name Transfer
extends RefCounted
## Registro de uma transferência concluída (memória do mundo: maiores vendas, idas ao rival...).

const KIND_BUY := 0
const KIND_FREE := 1
const KIND_RELEASE := 2
const KIND_NAMES: Array[String] = ["Transferência", "Sem custo", "Rescisão"]

var year: int = 0
var day: int = 0
var player_id: int = -1
var player_name: String = ""
var from_id: int = -1
var to_id: int = -1
var fee: int = 0
var kind: int = KIND_BUY
var age: int = 0
var overall: int = 0


static func make(y: int, d: int, p: Player, from_club: int, to_club: int, f: int, k: int) -> Transfer:
	var t := Transfer.new()
	t.year = y
	t.day = d
	t.player_id = p.id
	t.player_name = p.display_name()
	t.from_id = from_club
	t.to_id = to_club
	t.fee = f
	t.kind = k
	t.age = p.age(y)
	t.overall = p.overall
	return t


func to_dict() -> Dictionary:
	return {"y": year, "d": day, "p": player_id, "pn": player_name, "f": from_id, "t": to_id, "fee": fee, "k": kind, "age": age, "ovr": overall}


static func from_dict(d: Dictionary) -> Transfer:
	var t := Transfer.new()
	t.year = int(d.get("y", 0))
	t.day = int(d.get("d", 0))
	t.player_id = int(d.get("p", -1))
	t.player_name = d.get("pn", "")
	t.from_id = int(d.get("f", -1))
	t.to_id = int(d.get("t", -1))
	t.fee = int(d.get("fee", 0))
	t.kind = int(d.get("k", KIND_BUY))
	t.age = int(d.get("age", 0))
	t.overall = int(d.get("ovr", 0))
	return t
