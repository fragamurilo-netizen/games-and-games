class_name Reason
extends RefCounted
## Reason codes legíveis (MMA Bible §30): todo cálculo importante registra
## POR QUE aconteceu, para debug e para a UI explicar ao jogador.
## Uso: reasons.append(Reason.make("REFUSE_SHORT_CAMP", -0.25, {"weeks": 3}))


static func make(code: String, weight: float = 0.0, data: Dictionary = {}) -> Dictionary:
	return {"code": code, "weight": weight, "data": data}


static func total(reasons: Array) -> float:
	var t := 0.0
	for r in reasons:
		t += float(r.get("weight", 0.0))
	return t
