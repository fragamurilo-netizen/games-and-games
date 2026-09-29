class_name Contracts
extends RefCounted
## Contract & Leverage Engine (Game Design Bible §9; MMA Bible §13, §25).
## Negociação é utilidade esperada vs. BATNA de cada lado — não sliders.
##  - Fighter BATNA: oferta rival, esperar, free agency, aposentar, trocar de divisão.
##  - Promotion BATNA: outro oponente, outra estrela, adiar, cinturão interino.
##  - Agentes lembram negociações hostis (Agent.memory / relationship).
##  - Quebrar promessa hoje encarece deals futuros.


func evaluate_offer(_world: WorldState, _offer: Contract) -> Dictionary:
	# TODO(M1)
	return {"accept_probability": 0.0, "counter": null, "reasons": [Reason.make("NOT_IMPLEMENTED")]}


func sign(world: WorldState, offer: Contract) -> void:
	if offer.id.is_empty():
		offer.id = world.new_id("ctr")
	offer.signed_on = world.date
	offer.active = true
	world.add("contracts", offer)
	var fighter: Fighter = world.fighters[offer.fighter_id]
	fighter.contract_id = offer.id
	fighter.organization_id = offer.organization_id
	var org: Organization = world.organizations[offer.organization_id]
	if not org.roster.has(fighter.id):
		org.roster.append(fighter.id)
	EventBus.contract_signed.emit(offer.id)
