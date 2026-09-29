class_name AdaptiveCoach
extends RefCounted
## Decisions depend only on observed play and own squad. No access to RNG state/potential.
static func read(own: Dictionary, opp: Dictionary, minute: int, diff: int, xg_gap: float) -> Dictionary:
	var fitness := float(own.get("condition", 90.0))
	if fitness < 67.0 and int(own.get("pressing", 1)) == 2:
		return {"key": "pressing", "value": 1, "reason": "Reduz a pressão: o bloco perdeu fôlego."}
	if int(own.get("line", 1)) == 2 and float(opp.get("pace_att", 60.0)) > float(own.get("pace_def", 60.0)) + 7.0:
		return {"key": "line", "value": 1, "reason": "Protege as costas da defesa contra atacantes mais rápidos."}
	if int(opp.get("pressing", 1)) == 2 and float(own.get("tech", 60.0)) < 64.0 and int(own.get("passing", 1)) != 2:
		return {"key": "passing", "value": 2, "reason": "Evita a pressão na saída com passes mais diretos."}
	if minute >= 65 and diff < 0 and int(own.get("mentality", 2)) < (4 if minute >= 83 else 3):
		return {"key": "mentality", "value": 4 if minute >= 83 else 3, "reason": "Assume risco para buscar o resultado; deixa espaço atrás."}
	if minute >= 76 and diff > 0 and int(own.get("mentality", 2)) > 1 and xg_gap < 0.2:
		return {"key": "mentality", "value": 1, "reason": "Protege a vantagem diante da pressão adversária."}
	if int(opp.get("line", 1)) == 0 and int(opp.get("width", 1)) == 0 and int(own.get("width", 1)) != 2:
		return {"key": "width", "value": 2, "reason": "Abre o campo para deslocar o bloco compacto."}
	if minute >= 30 and xg_gap < -0.45 and fitness > 80.0 and int(own.get("pressing", 1)) == 0:
		return {"key": "pressing", "value": 1, "reason": "Adianta a disputa para interromper o domínio rival."}
	return {}
