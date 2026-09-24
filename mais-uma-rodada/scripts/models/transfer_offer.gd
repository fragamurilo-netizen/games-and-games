class_name TransferOffer
extends RefCounted
## Proposta pendente envolvendo o clube do usuário (recebida ou enviada).

const PENDING := 0
const ACCEPTED := 1
const REJECTED := 2
const EXPIRED := 3
const COUNTERED := 4
const WITHDRAWN := 5

var id: int = 0
var player_id: int = -1
var buyer_id: int = -1
var seller_id: int = -1
var fee: int = 0
var created_day: int = 0
var expires_day: int = 0
var status: int = PENDING
var raised: bool = false # comprador já aumentou a oferta uma vez
var max_fee: int = 0 # teto secreto do comprador (IA)
var rounds: int = 0 # contrapropostas do usuário já feitas


func is_pending() -> bool:
	return status == PENDING


func to_dict() -> Dictionary:
	return {
		"id": id, "p": player_id, "b": buyer_id, "s": seller_id, "fee": fee,
		"cd": created_day, "ed": expires_day, "st": status, "rs": raised, "mx": max_fee, "rd": rounds,
	}


static func from_dict(d: Dictionary) -> TransferOffer:
	var o := TransferOffer.new()
	o.id = int(d.get("id", 0))
	o.player_id = int(d.get("p", -1))
	o.buyer_id = int(d.get("b", -1))
	o.seller_id = int(d.get("s", -1))
	o.fee = int(d.get("fee", 0))
	o.created_day = int(d.get("cd", 0))
	o.expires_day = int(d.get("ed", 0))
	o.status = int(d.get("st", PENDING))
	o.raised = bool(d.get("rs", false))
	o.max_fee = int(d.get("mx", 0))
	o.rounds = int(d.get("rd", 0))
	return o
