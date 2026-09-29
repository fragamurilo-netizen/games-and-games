class_name FightEngine
extends RefCounted
## Motor de luta state-based e probabilístico.
## Referências: Game Design Bible §6; MMA Bible §5, §7, §20.
##
## Contrato:
##  - Entrada: WorldState (lutadores, ruleset, rng) + Fight com status "booked".
##  - Saída: preenche fight.round_log, stats, damage, method, winner_id,
##    scorecards (via Judge) e reasons; muda status para "completed".
##  - Nunca usar Overall como input dominante (MMA Bible §30).
##  - Todo sorteio via world.rng (determinismo).
##
## Pipeline por round (Game Design Bible §6):
##  1. Inicializar estado (energia, dano por zona, momentum, confiança, plano).
##  2. Escolher intenção (estilo, instruções, leitura do rival, situação).
##  3. Resolver exchanges nos estados espaciais (POSITIONS).
##  4. Aplicar consequências (dano, fadiga, posição, knockdown, corte, sub).
##  5. Adaptação entre rounds (corner advice, Fight IQ).
##  6. Pontuação por juiz individual (Judge).

const POSITIONS := [
	"long_range", "pocket", "cage_striking", "clinch", "open_wrestling",
	"cage_wrestling", "guard", "half_guard", "side_control", "mount_back",
	"scramble", "reset",
]

var judge := Judge.new()


func simulate(world: WorldState, fight: Fight) -> Fight:
	# TODO(M1): implementar o loop de exchanges descrito acima.
	push_warning("FightEngine.simulate ainda não implementado (%s)" % fight.id)
	fight.reasons.append(Reason.make("NOT_IMPLEMENTED"))
	return fight
