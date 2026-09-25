class_name HiddenPersona
## Personalidade oculta (1..20), como no futebol de verdade: ninguém vê o número, só o efeito.
## Os traços visíveis puxam os valores, mas dois "profissionais" podem ser bem diferentes por dentro.
##
## O que cada um muda no jogo:
## - pro Profissionalismo: evolução, declínio com a idade, lesões, recuperação física.
## - amb Ambição: pedir para sair, salário pedido, recusar renovação, evolução.
## - lea Lealdade: renovar por menos, recusar propostas, sentir a venda de amigos.
## - pre Pressão: jogos grandes, reta final apertada e pênaltis (no jogo e na disputa).
## - tem Temperamento (alto = frio): cartões, reação à cobrança, brigas, oscilação de moral.
## - det Determinação: reage quando o time está perdendo, evolui mais, não se entrega.
## - ada Adaptabilidade: sofre ou não longe de casa, saudade, entrosamento em clube novo.
## - pol Polêmica: indisciplina, confusões fora de campo, brigas no treino, declarações.
##
## Os valores são sorteados sob demanda a partir do id do jogador (não mexem no RNG do mundo,
## então saves antigos ganham personalidade oculta sem mudar mais nada).

const KEYS := ["pro", "amb", "lea", "pre", "tem", "det", "ada", "pol"]
const NAMES := {
	"pro": "Profissionalismo", "amb": "Ambição", "lea": "Lealdade", "pre": "Pressão",
	"tem": "Temperamento", "det": "Determinação", "ada": "Adaptabilidade", "pol": "Polêmica",
}
## Quanto cada traço visível puxa cada valor oculto.
const BIAS := {
	"lider": {"pre": 3, "tem": 2, "det": 3, "lea": 2},
	"ambicioso": {"amb": 6, "lea": -3, "det": 2},
	"leal": {"lea": 7, "amb": -2},
	"mercenario": {"lea": -6, "amb": 2},
	"temperamental": {"tem": -7, "pol": 3},
	"timido": {"pre": -6, "pol": -3, "ada": -2},
	"profissional": {"pro": 6, "tem": 2, "pol": -3},
	"festeiro": {"pro": -6, "pol": 4},
	"esforcado": {"pro": 3, "det": 5},
	"acomodado": {"pro": -5, "amb": -6, "det": -5},
	"estrela": {"amb": 4, "pre": 3, "pol": 3},
	"inseguro": {"pre": -5, "det": -2, "ada": -2},
	"competitivo": {"det": 4, "amb": 3, "pre": 2},
	"provocador": {"pol": 6, "tem": -4},
	"disciplinado": {"pro": 3, "tem": 3, "pol": -3},
	"rebelde": {"pol": 5, "tem": -4, "pro": -3},
	"decisivo": {"pre": 5},
	"jogos_grandes": {"pre": 6},
	"mentor": {"pro": 2, "tem": 2},
	"resiliente": {"det": 5, "ada": 3},
	"perfeccionista": {"pro": 4, "det": 2},
	"cascudo": {"pre": 4, "tem": 2, "ada": 2},
	"idolo": {"lea": 5},
}


## Sorteia os valores ocultos do jogador (determinístico pelo id e pelo rosto).
static func roll(p: Player) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([p.id, p.face_seed, "hid"])
	var out := {}
	for k in KEYS:
		var v := r.randfn(10.5, 3.3)
		for t in p.traits:
			v += float(BIAS.get(t, {}).get(k, 0))
		out[k] = clampi(int(round(v)), 1, 20)
	return out


## Soma de um modificador vindo da personalidade oculta (mesmas chaves de Player.trait_sum).
static func sum_mod(p: Player, key: String) -> float:
	match key:
		"ambition":
			return (p.hid("amb") - 10) * 2.5
		"loyalty":
			return (p.hid("lea") - 10) * 2.5
		"big_game":
			return (p.hid("pre") - 10) * 0.004
		"clutch":
			return (p.hid("pre") - 10) * 0.012
		"leadership":
			return (p.hid("det") - 10) * 0.8 + (p.hid("tem") - 10) * 0.6
	return 0.0


## Multiplicador vindo da personalidade oculta (mesmas chaves de Player.trait_mult).
static func mult_mod(p: Player, key: String) -> float:
	match key:
		"dev_mult":
			return 1.0 + (p.hid("pro") - 10) * 0.014 + (p.hid("det") - 10) * 0.006
		"decline_mult":
			return 1.0 - (p.hid("pro") - 10) * 0.013
		"injury_mult":
			return 1.0 - (p.hid("pro") - 10) * 0.009
		"card_mult":
			return 1.0 - (p.hid("tem") - 10) * 0.035
		"morale_volatility":
			return 1.0 - (p.hid("tem") - 10) * 0.025
		"greed":
			return 1.0 + (p.hid("amb") - 10) * 0.008 - (p.hid("lea") - 10) * 0.006
	return 1.0


## Esquentado de verdade: o traço visível ou o temperamento oculto no chão.
static func hot_head(p: Player) -> bool:
	return p.has_trait("temperamental") or p.has_trait("rebelde") or p.hid("tem") <= 5


## Encrenqueiro: vive se metendo em confusão fora de campo.
static func troublemaker(p: Player) -> bool:
	return p.has_trait("festeiro") or p.has_trait("rebelde") or p.hid("pol") >= 15


## Reação ao placar durante a partida: quem é determinado cresce atrás do placar;
## quem não é, se entrega. Vencendo, o frio mantém a concentração e o esquentado se perde.
static func score_factor(p: Player, diff: int) -> float:
	if diff < 0:
		var weight := minf(2.0, float(-diff))
		return 1.0 + (p.hid("det") - 10) * 0.0032 * weight
	if diff > 0:
		return 1.0 + (p.hid("tem") - 10) * 0.0012
	return 1.0


## Chance de converter um pênalti: nervos contam tanto quanto o pé.
static func penalty_nerve(p: Player) -> float:
	return (p.hid("pre") - 10) * 0.009 + (p.hid("tem") - 10) * 0.002


## Longe de casa sem companhia: quanto pesa por semana (1.0 = normal).
static func homesick_mult(p: Player) -> float:
	return clampf(1.0 - (p.hid("ada") - 10) * 0.09, 0.15, 1.9)


## A idade e a carreira mexem na personalidade: ficam mais frios e profissionais com o tempo;
## a ambição cai no fim da carreira. Um ajuste pequeno por ano, sem tocar no RNG do mundo.
static func age_year(p: Player, year: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([p.id, year, "hid_age"])
	var age := p.age(year)
	if age >= 27 and r.randf() < 0.25:
		_nudge(p, "tem", 1)
	if age >= 27 and r.randf() < 0.18:
		_nudge(p, "pol", -1)
	if age >= 24 and age <= 31 and r.randf() < 0.12:
		_nudge(p, "pro", 1)
	if age >= 32 and r.randf() < 0.3:
		_nudge(p, "amb", -1)
	if p.club_id >= 0 and year - p.joined_year >= 5 and r.randf() < 0.2:
		_nudge(p, "lea", 1)


## Uma mudança de traço visível também mexe por dentro (virou profissional → mais profissional).
static func on_trait_change(p: Player, t: String, add: bool) -> void:
	var b: Dictionary = BIAS.get(t, {})
	for k in b:
		var d := int(round(int(b[k]) * 0.5))
		_nudge(p, k, d if add else -d)


static func _nudge(p: Player, k: String, d: int) -> void:
	if d == 0:
		return
	p.hid("pro") # garante o sorteio
	p.hidden[k] = clampi(int(p.hidden.get(k, 10)) + d, 1, 20)
	p.clear_trait_cache()


# ---------------------------------------------------------------------------
# O que a comissão técnica percebe (nunca o número)
# ---------------------------------------------------------------------------

const HIGH := {
	"pro": "Profissional exemplar: primeiro a chegar, último a sair.",
	"amb": "Muito ambicioso: quer palcos maiores.",
	"lea": "Apegado ao clube: não pensa em sair.",
	"pre": "Frio em jogo grande: gosta da responsabilidade.",
	"tem": "Cabeça fria: dificilmente perde o controle.",
	"det": "Não se entrega nunca: cresce quando o time está atrás.",
	"ada": "Adapta-se rápido a qualquer lugar.",
	"pol": "Vive envolvido em polêmicas.",
}
const LOW := {
	"pro": "Pouco profissional: treina no mínimo e se cuida mal.",
	"amb": "Sem muita ambição: está bem onde está.",
	"lea": "Pouco apego: sai pela melhor proposta.",
	"pre": "Treme sob pressão: evita a bola decisiva.",
	"tem": "Pavio curtíssimo: um lance e ele explode.",
	"det": "Desanima fácil quando o jogo complica.",
	"ada": "Sofre longe de casa: demora para se adaptar.",
	"pol": "Discreto: nunca dá o que falar.",
}


## A comissão já conhece o jogador? Leva meio ano de convivência (ou uma temporada inteira no clube).
static func known(world: GameWorld, p: Player) -> bool:
	if p.club_id != world.user_club_id:
		return false
	return world.year > p.joined_year or p.minutes_season >= 900 or p.stats[Player.S_APPS] >= 12


## Frases do relatório da comissão: só o que chama atenção, sem números.
static func report(p: Player) -> Array:
	var out: Array = []
	for k in KEYS:
		var v := p.hid(k)
		if v >= 15:
			out.append([HIGH[k], k != "pol"])
		elif v <= 6:
			out.append([LOW[k], k == "pol"])
	return out
