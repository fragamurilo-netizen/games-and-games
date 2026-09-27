class_name PenaltyKick
extends RefCounted
## Uma cobrança de pênalti de verdade, igual para o jogo, a disputa e o modo rápido.
##   Cobrador: finalização, técnica, frieza e cabeça (nervos escondidos), cansaço e pressão
##   (importância do jogo, disputa, "se errar acabou"), torcida contra.
##   Onde bate: cada cobrador tem um lado preferido (destro abre para o seu lado natural, o canto
##   direito do goleiro); alguns batem no meio; os muito frios arriscam a cavadinha.
##   Goleiro: lê o cobrador (inteligência, decisão, reflexos e o quanto o clube estudou) e escolhe
##   um canto ou fica no meio. Canto certo: ainda precisa alcançar (goleiro × qualidade da batida).
##   Resultado: gol, defesa, para fora, por cima ou na trave.
## Referência real: ~76% de conversão no jogo, ~72% em disputas; ~17% defendidos, ~7% para fora.
##
## Direções (vistas pelo cobrador): 0 esquerda, 1 meio, 2 direita.

const DIRS: Array[String] = ["esquerda", "meio", "direita"]


## Lado natural do cobrador: destro abre o pé para a esquerda dele; canhoto para a direita.
static func natural_side(p: Player) -> int:
	if p.foot == Player.FOOT_LEFT:
		return 2
	if p.foot == Player.FOOT_BOTH:
		return 0 if p.face_seed % 2 == 0 else 2
	return 0


## O quanto o cobrador repete o lado (0..1). Frios e técnicos variam mais e são mais imprevisíveis.
static func predictability(p: Player) -> float:
	return clampf(0.72 - (float(p.attrs[Attr.FRI]) - 60.0) * 0.004 - (float(p.attrs[Attr.INT]) - 60.0) * 0.002 + float(p.face_seed % 7) * 0.012, 0.42, 0.8)


static func skill(p: Player) -> float:
	return float(p.attrs[Attr.FIN]) * 0.42 + float(p.attrs[Attr.TEC]) * 0.3 + float(p.attrs[Attr.FRI]) * 0.28


static func gk_skill(gk: Player) -> float:
	if gk == null:
		return 25.0
	return float(gk.attrs[Attr.GOL]) * 0.35 + float(gk.attrs[Attr.REF]) * 0.4 + float(gk.attrs[Attr.POS]) * 0.1 + float(gk.attrs[Attr.DEC]) * 0.15


## ctx: {f (fator do cobrador no jogo), gk_f, cond (0..100), pressure (0..1), away (torcida contra),
##       study (0..1, quanto o goleiro conhece o cobrador), kick (-1 ou 0..2: escolha do técnico),
##       dive (-1 ou 0..2: escolha do técnico para o goleiro)}
## Retorna {res: "goal"|"save"|"wide"|"over"|"post", dir, dive, high, panenka}.
static func kick(rng: RandomNumberGenerator, taker: Player, gk: Player, ctx: Dictionary) -> Dictionary:
	var f := float(ctx.get("f", 1.0))
	var cond := float(ctx.get("cond", 90.0))
	var pressure := clampf(float(ctx.get("pressure", 0.3)), 0.0, 1.0)
	var nerve := HiddenPersona.penalty_nerve(taker) # -0.1 (treme) .. +0.1 (gelo)
	var s := skill(taker) * f - maxf(0.0, 55.0 - cond) * 0.25
	# Pressão pesa menos em quem tem frieza e nervos bons
	var shake := pressure * clampf(1.0 - (float(taker.attrs[Attr.FRI]) - 50.0) / 60.0 - nerve * 3.0, 0.2, 1.4)
	if bool(ctx.get("away", false)):
		shake += 0.08
	# Onde bate
	var nat := natural_side(taker)
	var dir := int(ctx.get("kick", -1))
	var panenka := false
	if dir < 0:
		var pr := predictability(taker)
		var center := 0.1 + (0.05 if float(taker.attrs[Attr.FRI]) >= 75.0 else 0.0)
		var r := rng.randf()
		if r < center:
			dir = 1
			panenka = float(taker.attrs[Attr.FRI]) >= 78.0 and float(taker.attrs[Attr.TEC]) >= 75.0 and rng.randf() < 0.18 and shake < 0.5
		elif r < center + (1.0 - center) * pr:
			dir = nat
		else:
			dir = 2 - nat
	var high := dir != 1 and rng.randf() < 0.22 + (float(taker.attrs[Attr.CHL]) - 60.0) * 0.003
	# Para fora: canto alto arrisca mais; a pressão e o cansaço tiram a precisão
	var p_off := clampf(0.075 - (s - 65.0) * 0.0022 + shake * 0.07 + (0.05 if high else 0.0) - (0.04 if dir == 1 else 0.0), 0.015, 0.3)
	if rng.randf() < p_off:
		var rr := rng.randf()
		return {"res": "post" if rr < 0.22 else ("over" if rr < 0.55 or high else "wide"), "dir": dir, "dive": -1, "high": high, "panenka": panenka}
	# Goleiro escolhe
	var dive := int(ctx.get("dive", -1))
	if dive < 0:
		var read := 0.5
		if gk != null:
			read = clampf(0.5 + (float(gk.attrs[Attr.INT]) + float(gk.attrs[Attr.DEC]) - 120.0) * 0.0025 + float(ctx.get("study", 0.3)) * 0.12, 0.35, 0.72)
		var rd := rng.randf()
		if rd < 0.08:
			dive = 1
		elif rd < 0.08 + 0.92 * read:
			dive = nat # aposta no lado preferido do cobrador
		else:
			dive = 2 - nat
	var gs := gk_skill(gk) * float(ctx.get("gk_f", 1.0))
	if dir == 1:
		# No meio: goleiro que ficou pega quase sempre (a cavadinha passa por cima se ele ficou em pé)
		if dive == 1:
			var ps := 0.75 if not panenka else 0.25
			return {"res": "save" if rng.randf() < ps else "goal", "dir": dir, "dive": dive, "high": false, "panenka": panenka}
		return {"res": "goal", "dir": dir, "dive": dive, "high": false, "panenka": panenka}
	if dive != dir:
		return {"res": "goal", "dir": dir, "dive": dive, "high": high, "panenka": false}
	# Canto certo: alcança? Batida alta e forte quase não se pega
	var p_save := clampf(0.42 + (gs - s) * 0.006 + shake * 0.08 - (0.25 if high else 0.0), 0.08, 0.8)
	return {"res": "save" if rng.randf() < p_save else "goal", "dir": dir, "dive": dive, "high": high, "panenka": false}
