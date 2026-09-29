class_name Economy
extends RefCounted
## Economia (Game Design Bible §12; MMA Bible §16–17).
## Cada evento tem projeção pré-evento e fechamento pós-evento (P&L).
## Receitas: media rights, gate, site fee, hospitality, partnerships, licensing, PPV.
## Custos: bolsas/bônus, produção, arena, viagem/visto, oficiais, marketing, seguro.


func project_event(_world: WorldState, _ev: FightEvent) -> Dictionary:
	# TODO(M1)
	return {"revenue": 0, "costs": 0, "margin": 0, "lines": {}, "reasons": []}


func settle_event(world: WorldState, ev: FightEvent) -> Dictionary:
	# TODO(M1): calcular actual, pagar bolsas/bônus e atualizar org.cash.
	ev.actual = project_event(world, ev)
	return ev.actual
