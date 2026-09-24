class_name NewsEvent
extends RefCounted
## Notícia do feed procedural. Sempre referencia dados reais do save.

const IMP_LOW := 0
const IMP_NORMAL := 1
const IMP_HIGH := 2
const IMP_HEADLINE := 3

var year: int = 0
var day: int = 0
var category: String = "geral"
var title: String = ""
var body: String = ""
var club_id: int = -1
var player_id: int = -1
var importance: int = IMP_NORMAL
var read: bool = false


static func make(y: int, d: int, cat: String, t: String, b: String, c: int = -1, p: int = -1, imp: int = IMP_NORMAL) -> NewsEvent:
	var n := NewsEvent.new()
	n.year = y
	n.day = d
	n.category = cat
	n.title = t
	n.body = b
	n.club_id = c
	n.player_id = p
	n.importance = imp
	return n


func to_dict() -> Dictionary:
	return {"y": year, "d": day, "cat": category, "t": title, "b": body, "c": club_id, "p": player_id, "i": importance, "r": read}


static func from_dict(d: Dictionary) -> NewsEvent:
	var n := NewsEvent.new()
	n.year = int(d.get("y", 0))
	n.day = int(d.get("d", 0))
	n.category = d.get("cat", "geral")
	n.title = d.get("t", "")
	n.body = d.get("b", "")
	n.club_id = int(d.get("c", -1))
	n.player_id = int(d.get("p", -1))
	n.importance = int(d.get("i", IMP_NORMAL))
	n.read = bool(d.get("r", false))
	return n
