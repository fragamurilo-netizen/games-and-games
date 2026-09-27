class_name Contract
extends RefCounted
## Termos de contrato usados em negociações (o contrato vigente fica gravado no Player).

var wage: int = 0 # mensal
var years: int = 1
var signing_bonus: int = 0


static func make(w: int, y: int, bonus: int = 0) -> Contract:
	var c := Contract.new()
	c.wage = w
	c.years = y
	c.signing_bonus = bonus
	return c


## Custo total estimado do contrato (salários + luvas).
func total_cost() -> int:
	return wage * 12 * years + signing_bonus


func to_dict() -> Dictionary:
	return {"w": wage, "y": years, "b": signing_bonus}


static func from_dict(d: Dictionary) -> Contract:
	return make(int(d.get("w", 0)), int(d.get("y", 1)), int(d.get("b", 0)))
