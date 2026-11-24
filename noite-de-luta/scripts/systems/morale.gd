class_name Morale
extends RefCounted
## Moral do lutador (0–100) e o humor que ela dá. A moral anda toda semana na direção de um alvo
## feito do que pesa na vida dele (`factors`: fase, luta marcada ou tempo parado, lugar no
## ranking, a equipe, o contrato, o corpo) e leva trancos na hora (`bump`: vitória, derrota,
## cinturão, marco, conversa, promessa).
##
## Onde a moral pesa:
## - treino (`train_k`): de 0,88 a 1,10 do que ele evoluiria (e a cobrança do técnico soma 8%);
## - luta (`fight_mods`): confiante luta com mais coração e cabeça, abalado trava;
## - contrato: infeliz não renova e, no fundo do poço, pede para sair (`week`);
## - conversa (`talk`): elogiar, cobrar, prometer luta e dar folga, com resposta pelo jeito dele.

const BASE := 58.0
## Semanas entre uma conversa e outra.
const TALK_GAP := 4
## [mínimo, humor (ele), humor (ela), tom] (tom: 2 ótimo, 1 bom, 0 neutro, -1 atenção, -2 ruim).
const LEVELS := [
	[84.0, "Voando", "Voando", 2],
	[70.0, "Confiante", "Confiante", 1],
	[52.0, "Tranquilo", "Tranquila", 0],
	[38.0, "Inquieto", "Inquieta", -1],
	[24.0, "Abalado", "Abalada", -2],
	[-1.0, "No fundo do poço", "No fundo do poço", -2],
]


static func _level(f: Fighter) -> Array:
	for l: Array in LEVELS:
		if f.morale >= float(l[0]):
			return l
	return LEVELS.back()


static func label(f: Fighter) -> String:
	return String(_level(f)[2 if f.is_female() else 1])


static func tone(f: Fighter) -> int:
	return int(_level(f)[3])


## Uma frase do que o humor faz no jogo.
static func effect_text(f: Fighter) -> String:
	match tone(f):
		2:
			return "Treina melhor e entra na luta com mais coração e cabeça."
		1:
			return "Treina um pouco melhor e luta solto."
		-1:
			return "Treina um pouco pior. Uma conversa ou uma luta marcada ajudam."
		-2:
			return "Treina pior, entra travado na luta e pode não renovar o contrato."
	return "Nem ajuda nem atrapalha."


# --- O que pesa ---------------------------------------------------------------------------

static func gym_quality(w: GameWorld, team: Team) -> float:
	if team == null:
		return 0.0
	var s := 0.0
	for role: String in ["striking", "wrestling", "jiujitsu", "fisico"]:
		s += team.staff_quality(role)
	return s / 4.0


## O que pesa hoje na moral: [[texto, pontos], ...] (positivo puxa para cima).
static func factors(w: GameWorld, f: Fighter) -> Array:
	var out: Array = []
	var fem := f.is_female()
	var mine := w.is_user_fighter(f)
	# Fase.
	if f.streak >= 2:
		out.append(["Vem de %d vitórias seguidas" % f.streak, minf(12.0, 3.0 * f.streak)])
	elif f.streak <= -2:
		out.append(["Vem de %d derrotas seguidas" % -f.streak, -minf(16.0, 4.0 * -f.streak)])
	elif not f.history.is_empty() and w.week - f.last_fight_week <= 26:
		var res := String((f.history.back() as Dictionary).get("res", ""))
		if res == "V":
			out.append(["Venceu a última luta", 3.0])
		elif res == "D":
			out.append(["Perdeu a última luta", -4.0])
	# Luta marcada ou tempo parado.
	var b := w.bout(f.bout_id)
	if b != null and b.status == "marcada":
		if b.title:
			out.append(["Vai disputar o cinturão", 10.0])
		elif b.main_event:
			out.append(["Faz a luta principal da noite", 6.0])
		else:
			out.append(["Tem luta marcada", 4.0])
	elif f.is_pro() and f.injury.is_empty() and f.suspension <= 0:
		var idle := w.week - f.last_fight_week - Matchmaker.rest_weeks(f) - 10
		if idle > 0:
			var k := 1.5 if Persona.has(f, "guerreiro") else (0.5 if Persona.has(f, "preguicoso") else 1.0)
			var months := maxi(1, int(round(float(w.week - f.last_fight_week) / 4.35)))
			out.append(["%s há %s sem luta marcada" % ["Parada" if fem else "Parado", Fmt.plural(months, "mês", "meses")], -minf(15.0, idle * 0.5 * k)])
	# Lugar no ranking.
	var r := w.rank_of(f)
	if r == 0:
		out.append(["É a campeã" if fem else "É o campeão", 10.0])
	elif r >= 1 and r <= 5:
		out.append(["Está no top 5", 4.0])
	# Equipe.
	var team := w.team(f.team_id)
	if team == null:
		if f.is_pro():
			out.append(["Sem equipe", -6.0])
	else:
		var v := clampf((gym_quality(w, team) - 45.0) / 7.0, -6.0, 6.0)
		if v >= 1.5:
			out.append(["Confia na comissão técnica", v])
		elif v <= -1.5:
			out.append(["Sente falta de técnicos melhores", v])
	# Contrato (só na equipe do jogador: as rivais usam o contrato padrão).
	if mine:
		var cut := float(f.contract.get("cut", 0.2))
		if cut > 0.21:
			out.append(["A equipe fica com %d%% das bolsas" % int(round(cut * 100.0)), -(cut - 0.2) * 80.0 * (2.0 if Persona.has(f, "mercenario") else 1.0)])
		elif cut < 0.19:
			out.append(["Contrato generoso: %d%% para a equipe" % int(round(cut * 100.0)), (0.2 - cut) * 50.0])
		if f.contract.has("fights") and int(f.contract["fights"]) <= 0:
			out.append(["Contrato vencido", -5.0])
		if not f.promise.is_empty():
			out.append(["Você prometeu uma luta", 3.0])
	# Corpo.
	if not f.injury.is_empty():
		out.append(["Machucada" if fem else "Machucado", -5.0])
	elif f.condition < 70.0 and w.week - f.last_fight_week > 3:
		out.append(["Corpo cansado do treino", -4.0])
	return out


static func target(w: GameWorld, f: Fighter) -> float:
	var t := BASE
	for it: Array in factors(w, f):
		t += float(it[1])
	return clampf(t, 5.0, 98.0)


## Para onde a moral está indo: 1 sobe, -1 cai, 0 parada.
static func trend(w: GameWorld, f: Fighter) -> int:
	var d := target(w, f) - f.morale
	return 1 if d > 4.0 else (-1 if d < -4.0 else 0)


# --- Trancos ------------------------------------------------------------------------------

static func _swing(f: Fighter, delta: float) -> float:
	var k := 1.0
	if Persona.has(f, "frio"):
		k *= 0.7
	if Persona.has(f, "nervoso"):
		k *= 1.3
	if Persona.has(f, "falastrao"):
		k *= 1.2
	if delta < 0.0 and Persona.has(f, "guerreiro"):
		k *= 0.75
	return k


## Tranco na moral, com o motivo guardado para o perfil (equipe do jogador e seguidos).
static func bump(w: GameWorld, f: Fighter, delta: float, why: String) -> void:
	var d := delta * _swing(f, delta)
	f.morale = clampf(f.morale + d, 0.0, 100.0)
	if w != null and why != "" and absf(d) >= 1.0 and (w.is_user_fighter(f) or w.is_followed(f)):
		f.mood_log.append([w.week, int(round(d)), why])
		if f.mood_log.size() > 6:
			f.mood_log = f.mood_log.slice(f.mood_log.size() - 6)


## Depois da luta. `rank_opp`: ranking do adversário antes da luta; `rank_me`: o dele.
static func after_fight(w: GameWorld, f: Fighter, b: Bout, res_code: String, method: String, champ_before: int, rank_me: int, rank_opp: int) -> void:
	var finish := method in ["KO", "TKO", "FIN"]
	if res_code == "V":
		var d := 7.0 + (3.0 if finish else 0.0)
		var why := "Vitória por nocaute" if method in ["KO", "TKO"] else ("Vitória por finalização" if method == "FIN" else "Vitória por decisão")
		if b.title and (b.title_for < 0 or b.title_for == f.id):
			if champ_before == f.id:
				d += 6.0
				why = "Defendeu o cinturão"
			else:
				d += 16.0
				why = "Ganhou o cinturão"
		elif rank_opp >= 0 and (rank_me < 0 or rank_opp < rank_me - 3):
			d += 4.0
			why = "Venceu alguém mais bem ranqueado"
		bump(w, f, d, why)
	elif res_code == "D":
		var d2 := -8.0 - (5.0 if method in ["KO", "TKO"] else 0.0)
		var why2 := "Derrota por nocaute" if method in ["KO", "TKO"] else ("Derrota por finalização" if method == "FIN" else "Derrota por decisão")
		if b.title and champ_before == f.id:
			d2 -= 8.0
			why2 = "Perdeu o cinturão"
		bump(w, f, d2, why2)
	else:
		bump(w, f, -1.0, "Empate")


# --- Efeitos ------------------------------------------------------------------------------

static func train_k(w: GameWorld, f: Fighter) -> float:
	return lerpf(0.88, 1.1, f.morale / 100.0) * (1.08 if w != null and w.week < f.push_until else 1.0)


static func fight_mods(f: Fighter) -> Dictionary:
	if f.morale >= 84.0:
		return {"coracao": 3.0, "qi": 2.0}
	if f.morale >= 70.0:
		return {"coracao": 1.5, "qi": 1.0}
	if f.morale < 24.0:
		return {"coracao": -4.0, "qi": -3.0}
	if f.morale < 38.0:
		return {"coracao": -2.0, "qi": -1.5}
	return {}


## Chance a mais (ou a menos) de renovar o contrato.
static func renew_mod(f: Fighter) -> float:
	return clampf((f.morale - 55.0) / 100.0, -0.4, 0.3)


# --- Semana -------------------------------------------------------------------------------

static func week(w: GameWorld, f: Fighter) -> void:
	f.morale += (target(w, f) - f.morale) * 0.07
	var mine := w.is_user_fighter(f)
	if not f.promise.is_empty():
		if not mine:
			f.promise = {}
		elif f.bout_id >= 0:
			f.promise = {}
			bump(w, f, 4.0, "Promessa cumprida: luta marcada")
		elif w.week > int(f.promise.get("until", 0)):
			f.promise = {}
			bump(w, f, -12.0, "Promessa de luta não cumprida")
			w.add_news("equipe", "%s cobra a luta que você prometeu e não marcou. A moral %s caiu." % [f.display_name(), "dela" if f.is_female() else "dele"], [f.id], true)
	if f.morale >= 24.0 or f.bout_id >= 0 or f.team_id < 0:
		return
	if mine:
		if w.rng.randf() >= 0.08:
			return
		if not f.contract.has("fights") or int(f.contract["fights"]) <= 1:
			Signing.release(w, f, false)
			f.morale = 45.0
			w.add_news("equipe", "%s deixou a equipe: estava infeliz e não quis esperar o fim do contrato." % f.display_name(), [f.id], true)
		elif w.week - int(f.contract.get("unhappy", -99)) >= 8:
			f.contract["unhappy"] = w.week
			w.add_news("equipe", "%s está infeliz na equipe e já fala em sair. Converse com %s ou marque uma luta." % [f.display_name(), "ela" if f.is_female() else "ele"], [f.id], true)
	elif w.rng.randf() < 0.03:
		# Nas rivais: o infeliz larga a academia e vai para o mercado.
		var t := w.team(f.team_id)
		f.team_id = -1
		f.contract = {}
		f.morale = 45.0
		if t != null and (f.level() >= 66 or w.is_followed(f)):
			w.add_news("mercado", "%s deixa a %s: o clima não era bom. Está livre no mercado." % [f.display_name(), t.name], [f.id])


# --- Conversa -----------------------------------------------------------------------------

static func talk_wait(w: GameWorld, f: Fighter) -> int:
	return maxi(0, TALK_GAP - (w.week - f.talk_week))


## Conversas possíveis agora: [{key, title, desc}].
static func talk_options(w: GameWorld, f: Fighter) -> Array:
	var out: Array = [
		{"key": "elogiar", "title": "Elogiar", "desc": "Reconhecer o trabalho. Cai melhor depois de uma vitória."},
		{"key": "cobrar", "title": "Cobrar", "desc": "Exigir mais no treino por seis semanas. Uns crescem com a cobrança, outros se fecham."},
	]
	var b := w.bout(f.bout_id)
	if b == null and f.promise.is_empty() and f.injury.is_empty():
		out.append({"key": "prometer", "title": "Prometer uma luta", "desc": "Luta marcada em até oito semanas. Promessa não cumprida custa caro."})
	if b == null or b.week - w.week > 2:
		out.append({"key": "folga", "title": "Dar uma semana de folga", "desc": "Sem treino nesta semana: o corpo descansa e a cabeça também."})
	return out


## Faz a conversa. Devolve {text, delta} com a reação dele.
static func talk(w: GameWorld, f: Fighter, key: String) -> Dictionary:
	var he := "Ela" if f.is_female() else "Ele"
	var nm := f.short_name()
	var last_res := ""
	if not f.history.is_empty() and w.week - f.last_fight_week <= 8:
		last_res = String((f.history.back() as Dictionary).get("res", ""))
	var d := 0.0
	var text := ""
	var why := ""
	match key:
		"elogiar":
			why = "Conversa: elogio"
			d = 3.0
			text = "%s agradeceu." % nm
			if last_res == "V":
				d += 3.0
				text = "%s ainda está no embalo da vitória e gostou de ouvir." % nm
			elif last_res == "D":
				if Persona.has(f, "humilde"):
					d += 1.0
					text = "%s precisava ouvir isso depois da derrota." % nm
				else:
					d = -1.0
					text = "Depois da derrota, o elogio soou vazio para %s." % nm
			if Persona.has(f, "falastrao") and d > 0.0:
				d += 2.0
				text = "%s adora um elogio. Saiu da sala maior do que entrou." % nm
			elif Persona.has(f, "disciplinado") and d > 0.0:
				d = minf(d, 2.0)
				text = "%s agradeceu e voltou para o treino. Prefere trabalho a elogio." % nm
			elif Persona.has(f, "preguicoso") and d > 0.0:
				f.push_until = -999
				text = "%s gostou, e relaxou: a cobrança no treino acabou." % nm
		"cobrar":
			why = "Conversa: cobrança"
			f.push_until = w.week + 6
			d = -2.0
			text = "%s ouviu calado. Vai treinar mais forte por seis semanas." % nm
			if f.is_female():
				text = "%s ouviu calada. Vai treinar mais forte por seis semanas." % nm
			if Persona.has(f, "disciplinado") or Persona.has(f, "guerreiro"):
				d = 2.0
				text = "%s gosta de ser exigido: aceitou a cobrança de cabeça erguida." % nm
				if f.is_female():
					text = "%s gosta de ser exigida: aceitou a cobrança de cabeça erguida." % nm
			elif Persona.has(f, "nervoso"):
				d = -6.0
				text = "%s sentiu a cobrança. Vai treinar mais, mas saiu abalado." % nm
				if f.is_female():
					text = "%s sentiu a cobrança. Vai treinar mais, mas saiu abalada." % nm
			elif Persona.has(f, "encrenqueiro"):
				d = -6.0
				text = "%s respondeu atravessado e bateu a porta. No treino, pelo menos, apareceu." % nm
			elif Persona.has(f, "falastrao"):
				d = -4.0
				text = "%s não gostou de ser cobrado. O ego ficou ferido." % nm
				if f.is_female():
					text = "%s não gostou de ser cobrada. O ego ficou ferido." % nm
			elif Persona.has(f, "preguicoso"):
				d = -5.0
				text = "%s fechou a cara, mas vai ter de suar." % nm
			elif Persona.has(f, "humilde") or Persona.has(f, "frio"):
				d = 0.0
				text = "%s ouviu, concordou e foi treinar." % nm
			if last_res == "D":
				d += 2.0
			elif f.streak >= 3:
				d -= 3.0
				text += " Vindo de %d vitórias, achou a cobrança injusta." % f.streak
		"prometer":
			why = "Conversa: promessa de luta"
			d = 5.0
			f.promise = {"kind": "luta", "until": w.week + 8}
			text = "%s ficou animado: quer a luta marcada em até oito semanas." % nm
			if f.is_female():
				text = "%s ficou animada: quer a luta marcada em até oito semanas." % nm
		"folga":
			why = "Conversa: semana de folga"
			d = 3.0
			f.training["off"] = w.week
			f.condition = minf(100.0, f.condition + 12.0)
			text = "%s vai descansar nesta semana." % nm
			if Persona.has(f, "preguicoso"):
				d = 5.0
				text = "%s não esperou você terminar a frase. Folga é com %s." % [nm, he.to_lower()]
			elif Persona.has(f, "disciplinado"):
				d = 1.0
				text = "%s aceitou a folga, meio a contragosto." % nm
		_:
			return {"text": "", "delta": 0}
	f.talk_week = w.week
	var before := f.morale
	bump(w, f, d, why)
	return {"text": text, "delta": int(round(f.morale - before))}
