class_name Matchmaking
extends RefCounted
## Matchmaking Engine (Game Design Bible §7; MMA Bible §11, §22).
## Três scores SEPARADOS, nunca colapsados num "match score" único na UI:
##  - sporting_fit:   proximidade de ranking, forma, lógica de revanche,
##                    necessidade da divisão, novidade de estilo.
##  - acceptance:     bolsa, risco, aviso prévio, lesão, objetivos de carreira,
##                    promessas, postura do agente (por lutador).
##  - commercial_fit: draw, mercado, papel no card, narrativa, broadcaster.
## "BOOK" não é botão garantido: propor é gameplay.


func evaluate(_world: WorldState, fighter_a_id: String, fighter_b_id: String, _event_id: String) -> Dictionary:
	# TODO(M1)
	return {
		"sporting_fit": 0.0,
		"acceptance": {fighter_a_id: 0.0, fighter_b_id: 0.0},
		"commercial_fit": 0.0,
		"projected_cost": 0,
		"reasons": [Reason.make("NOT_IMPLEMENTED")],
	}


## Envia a proposta; o lutador/agente pode aceitar, recusar ou contrapropor.
## Retorna {"outcome": "accepted"|"refused"|"counter", "reasons": [...]}.
func propose(_world: WorldState, _fight: Fight) -> Dictionary:
	# TODO(M1)
	return {"outcome": "refused", "reasons": [Reason.make("NOT_IMPLEMENTED")]}
