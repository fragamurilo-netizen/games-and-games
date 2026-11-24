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
## Vale o cinturão interino (campeão fora de combate). Ver Titles.
var interim: bool = false
## Lugar no card combinado na negociação: 0 = o matchmaker decide, 1 = card principal,
## 2 = co-principal, 3 = luta principal. Ver Card.
var billing: int = 0
## Campeão que perdeu o cinturão na balança: só este lutador pode ganhar o cinturão (-1 = qualquer um).
var title_for: int = -1
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


## Ordem dos números de cada lutador no save (uma lista curta no lugar de um dicionário).
const STAT_KEYS := ["sig_att", "sig_land", "head", "body", "legs", "kd", "td_att", "td", "sub_att", "ctrl", "rev", "adv", "dmg"]


static func _pack_stats(v: Variant) -> Variant:
	if not (v is Dictionary):
		return v
	var st: Dictionary = v
	var out: Array = []
	for k: String in STAT_KEYS:
		var x := float(st.get(k, 0))
		if k == "ctrl" or k == "dmg":
			out.append(snappedf(x, 0.1))
		else:
			out.append(int(round(x)))
	return out


## Aceita a lista do save novo e o dicionário dos saves antigos.
static func _unpack_stats(v: Variant) -> Variant:
	if not (v is Array):
		return v
	var a: Array = v
	var st := {}
	for i in mini(STAT_KEYS.size(), a.size()):
		var k: String = STAT_KEYS[i]
		st[k] = float(a[i]) if k == "ctrl" or k == "dmg" else int(a[i])
	return st


## O resultado já convertido para o save (luta feita não muda mais).
var _res_pack: Dictionary = {}


func to_dict() -> Dictionary:
	var res := result
	if result.has("stats"):
		if status == "feita" and not _res_pack.is_empty():
			res = _res_pack
		else:
			res = result.duplicate()
			res["stats"] = (result["stats"] as Array).map(_pack_stats)
			if status == "feita":
				_res_pack = res
	var wg := weigh
	if weigh.has("cut"):
		wg = weigh.duplicate()
		wg["cut"] = (weigh["cut"] as Array).map(func(x: Variant) -> float: return snappedf(float(x), 0.0001))
	var d := {"id": id, "ev": event_id, "week": week, "a": a, "b": b, "div": division, "rounds": rounds,
		"title": title, "main": main_event, "pa": purse_a, "pb": purse_b, "status": status, "res": res, "weigh": wg, "tf": title_for}
	if not log.is_empty():
		d["log"] = log
	if interim:
		d["int"] = true
	if billing != 0:
		d["bill"] = billing
	return d


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
	if x.result.has("stats"):
		x.result["stats"] = (x.result["stats"] as Array).map(_unpack_stats)
	x.log = d.get("log", [])
	x.weigh = d.get("weigh", {})
	x.title_for = int(d.get("tf", -1))
	x.interim = bool(d.get("int", false))
	x.billing = int(d.get("bill", 0))
	return x
