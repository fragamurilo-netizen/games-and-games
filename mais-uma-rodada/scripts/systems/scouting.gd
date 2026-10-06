class_name Scouting
extends RefCounted
## Rede de olheiros. O treinador abre missões (um perfil, uma liga inteira ou um jogador
## específico); a cada rodada os olheiros que estão em campo voltam com nomes novos e com mais
## conhecimento sobre quem já viram. O conhecimento (0–100%) é o que estreita a avaliação: a
## faixa de estrelas, o potencial, os atributos e o que só se descobre vendo de perto
## (personalidade, regularidade, lesões).
##
## Estado em world.stats["scouting"]:
##   ids: {pid: turno em que foi visto pela última vez}   (relatórios; formato antigo mantido)
##   know: {pid: 0..100}   n0: {pid: ruído original}   jobs: [missões]   next: id da próxima
##   last/yr: turno e ano da última missão aberta (compatibilidade)

const ORIGINS := [["all", "Todos"], ["nat", "Nacionais"], ["for", "Estrangeiros"]]
const FOCUS := [["geral", "Melhor disponível", "O melhor nome do perfil que o clube pode pagar."],
	["pronto", "Pronto para jogar", "Quem chega e briga por vaga já, de 23 a 30 anos."],
	["jovem", "Jovem promessa", "Até 21 anos, pelo que pode virar."],
	["barato", "Oportunidade", "Livres, fim de contrato e preço baixo."]]
const KINDS := [["perfil", "Perfil"], ["liga", "Liga"], ["jogador", "Jogador"]]
const MAX_REPORTS := 60
## Conhecimento a partir do qual o relatório revela personalidade e o que é escondido.
const KNOW_TRAITS := 60
const KNOW_HIDDEN := 80


static func state(world: GameWorld) -> Dictionary:
	if not world.stats.has("scouting"):
		world.stats["scouting"] = {"ids": {}, "last": -1, "yr": world.year}
	var s: Dictionary = world.stats["scouting"]
	for k in ["ids", "know", "n0"]:
		if not s.has(k):
			s[k] = {}
	if not s.has("jobs"):
		s["jobs"] = []
	if not s.has("next"):
		s["next"] = 1
	if int(s.get("yr", world.year)) != world.year:
		s["yr"] = world.year
		s["last"] = -1
	return s


## "Nacional" é relativo ao país do clube do usuário.
static func origin_ok(p: Player, club: Club, origin: String) -> bool:
	match origin:
		"nat":
			return p.nationality == club.nation
		"for":
			return p.nationality != club.nation
	return true


static func is_scouted(world: GameWorld, p: Player) -> bool:
	return world.stats.has("scouting") and world.stats["scouting"]["ids"].has(str(p.id))


## Conhecimento do clube sobre o jogador, 0..100. Relatórios antigos (sem número) valem 70.
static func knowledge(world: GameWorld, p: Player) -> int:
	if not world.stats.has("scouting"):
		return 0
	var s: Dictionary = world.stats["scouting"]
	var k := str(p.id)
	if s.has("know") and (s["know"] as Dictionary).has(k):
		return int(s["know"][k])
	return 70 if (s["ids"] as Dictionary).has(k) else 0


static func level(world: GameWorld) -> float:
	return People.staff_level(world, "olheiro")


## Quantos jogadores uma missão de perfil traz (4 a ~9).
static func capacity(world: GameWorld) -> int:
	return 4 + int(round(level(world) * 5.0))


## Missões ao mesmo tempo: o olheiro-chefe e, em clube maior ou com olheiro bom, mais gente.
static func slots(world: GameWorld) -> int:
	var n := 1
	if level(world) >= 0.55:
		n += 1
	var club := world.user_club()
	if club != null and club.reputation >= 70.0:
		n += 1
	return n


static func jobs(world: GameWorld) -> Array:
	return state(world)["jobs"]


static func can_send(world: GameWorld) -> bool:
	return jobs(world).size() < slots(world)


## Rodadas que a missão leva. Jogador de fora do país demora mais.
static func job_length(world: GameWorld, job: Dictionary) -> int:
	match String(job.get("k", "perfil")):
		"jogador":
			var p := world.player(int(job.get("p", -1)))
			var club := world.user_club()
			return 1 if p != null and club != null and _nation_of(world, p) == club.nation else 2
		"liga":
			return 4
	return 3


static func _nation_of(world: GameWorld, p: Player) -> String:
	var c := world.club(p.club_id) if p.club_id >= 0 else null
	return c.nation if c != null else p.nationality


## Abre uma missão; a primeira leva de nomes já vem na hora. Devolve os jogadores vistos.
static func open_job(world: GameWorld, job: Dictionary) -> Array:
	var s := state(world)
	if not can_send(world):
		return []
	if String(job.get("k", "")) == "jogador":
		for j: Dictionary in s["jobs"]:
			if String(j["k"]) == "jogador" and int(j.get("p", -1)) == int(job.get("p", -2)):
				return []
	job["id"] = int(s["next"])
	s["next"] = int(s["next"]) + 1
	job["t0"] = world.current_turn()
	job["done"] = 0
	job["found"] = []
	job["len"] = job_length(world, job)
	s["jobs"].append(job)
	s["last"] = world.current_turn()
	var seen := _step(world, job)
	_trim(world)
	return seen


## Compatível com o fluxo antigo (missão de perfil aberta já com a primeira leva).
static func send_mission(world: GameWorld, origin: String, group: int, max_age: int) -> Array:
	return open_job(world, {"k": "perfil", "o": origin, "g": group, "a": max_age, "f": "geral"})


static func watch_player(world: GameWorld, p: Player) -> bool:
	return not open_job(world, {"k": "jogador", "p": p.id}).is_empty() or _has_job_for(world, p)


static func _has_job_for(world: GameWorld, p: Player) -> bool:
	for j: Dictionary in jobs(world):
		if String(j["k"]) == "jogador" and int(j.get("p", -1)) == p.id:
			return true
	return false


static func cancel(world: GameWorld, job_id: int) -> void:
	var s := state(world)
	s["jobs"] = (s["jobs"] as Array).filter(func(j: Dictionary) -> bool: return int(j["id"]) != job_id)


## Uma rodada: cada missão em campo avança. As que terminam viram mensagem do olheiro.
static func tick(world: GameWorld) -> void:
	if not world.has_user():
		return
	var s := state(world)
	var finished: Array = []
	for job: Dictionary in s["jobs"]:
		if int(job.get("t0", -1)) == world.current_turn():
			continue # aberta nesta rodada: a primeira leva já veio
		_step(world, job)
		if int(job["done"]) >= int(job["len"]):
			finished.append(job)
	for job: Dictionary in finished:
		s["jobs"].erase(job)
		_report_done(world, job)
	_trim(world)


## Avança a missão uma rodada: novos nomes (perfil e liga) e mais conhecimento dos já vistos.
static func _step(world: GameWorld, job: Dictionary) -> Array:
	var done := int(job["done"])
	var total := int(job["len"])
	var gain := (30.0 + level(world) * 20.0)
	var seen: Array = []
	match String(job["k"]):
		"jogador":
			var p := world.player(int(job.get("p", -1)))
			if p != null and p.club_id != world.user_club_id:
				_learn(world, p, int(round(100.0 / total + 4.0)))
				seen.append(p)
				if not (job["found"] as Array).has(p.id):
					(job["found"] as Array).append(p.id)
		_:
			# Mais conhecimento de quem já foi visto...
			for pid in job["found"]:
				var q := world.player(int(pid))
				if q != null and q.club_id != world.user_club_id:
					_learn(world, q, int(round(gain * 0.8)))
			# ...e nomes novos nas primeiras rodadas.
			var cap := capacity(world) + (2 if String(job["k"]) == "liga" else 0)
			var per_round := int(ceil(float(cap) / maxf(1.0, total - 1.0)))
			var want := mini(per_round, cap - (job["found"] as Array).size())
			if want > 0 and done < total - 1:
				for p: Player in candidates(world, job, want):
					_learn(world, p, int(round(gain)))
					(job["found"] as Array).append(p.id)
					seen.append(p)
	job["done"] = done + 1
	return seen


## Sobe o conhecimento e encolhe o erro do olheiro na mesma proporção.
static func _learn(world: GameWorld, p: Player, amount: int) -> void:
	var s := state(world)
	var key := str(p.id)
	if not (s["n0"] as Dictionary).has(key):
		s["n0"][key] = p.scout_noise
	var k := mini(100, knowledge(world, p) + amount)
	s["know"][key] = k
	s["ids"][key] = world.current_turn()
	p.scout_noise = int(round(float(s["n0"][key]) * (1.0 - 0.85 * k / 100.0)))
	PlayerAssessment.invalidate()


## Melhores nomes do perfil da missão que ainda não foram vistos.
static func candidates(world: GameWorld, job: Dictionary, count: int) -> Array:
	var club := world.user_club()
	var s := state(world)
	var ids: Dictionary = s["ids"]
	var origin := String(job.get("o", "all"))
	var group := int(job.get("g", -1))
	var max_age := int(job.get("a", 99))
	var focus := String(job.get("f", "geral"))
	var league_id := String(job.get("l", ""))
	var reach := maxi(club.transfer_budget * 3 / 2, 1)
	var out: Array = []
	for p: Player in world.players.values():
		if p.club_id == club.id or p.retiring or ids.has(str(p.id)) or (job["found"] as Array).has(p.id):
			continue
		if group >= 0 and Pos.group(p.position) != group:
			continue
		var age := p.age(world.year)
		if age > max_age or not origin_ok(p, club, origin):
			continue
		if league_id != "":
			var pc := world.club(p.club_id) if p.club_id >= 0 else null
			if pc == null or pc.league_id != league_id:
				continue
		var price := 0.0 if p.club_id < 0 else float(TransferManager.asking_price(world, p))
		if league_id == "" and price > reach:
			continue
		var score := PlayerAssessment.score(world, p)
		match focus:
			"pronto":
				if age < 23 or age > 30:
					continue
				score += 2.0
			"jovem":
				if age > 21:
					continue
				score += maxf(0.0, float(p.potential_estimate(0.0) - p.overall)) * 0.6
			"barato":
				var cheap := p.club_id < 0 or p.contract_end <= world.year or price <= reach * 0.35
				if not cheap:
					continue
				score -= price / maxf(1.0, reach) * 6.0
			_:
				if age <= 23:
					score += maxf(0.0, 26.0 - age) * 0.5
				elif age > 30:
					score -= (age - 30) * 1.5
		out.append([p, score])
	out.sort_custom(func(a, b): return a[1] > b[1])
	return out.slice(0, count).map(func(e): return e[0])


static func _report_done(world: GameWorld, job: Dictionary) -> void:
	var found: Array = []
	for pid in job["found"]:
		var p := world.player(int(pid))
		if p != null and p.club_id != world.user_club_id:
			found.append(p)
	if found.is_empty():
		InboxManager.send(world, "olheiro", "Missão encerrada: %s" % job_title(world, job),
			"Ninguém no perfil valeu um relatório desta vez.", {"k": "screen", "s": "market", "args": {"tab": "scout"}})
		return
	found.sort_custom(func(a: Player, b: Player): return verdict_score(world, a) > verdict_score(world, b))
	var lines: Array = []
	for p: Player in found.slice(0, 4):
		var v := verdict(world, p)
		lines.append("%s, %d anos (%s): %s." % [p.display_name(), p.age(world.year), _club_name(world, p), String(v["label"]).to_lower()])
	var top: Player = found[0]
	InboxManager.send(world, "olheiro", "Relatório pronto: %s" % job_title(world, job),
		"%s observado%s. Os que mais valem:\n\n%s" % [Fmt.plural(found.size(), "jogador", "jogadores"), "" if found.size() == 1 else "s", "\n".join(lines)],
		{"k": "screen", "s": "market", "args": {"tab": "scout"}}, top.id)


static func _club_name(world: GameWorld, p: Player) -> String:
	return world.club(p.club_id).short_name if p.club_id >= 0 else "sem clube"


## Nome curto da missão para listas e mensagens.
static func job_title(world: GameWorld, job: Dictionary) -> String:
	match String(job.get("k", "")):
		"jogador":
			var p := world.player(int(job.get("p", -1)))
			return p.display_name() if p != null else "Jogador"
		"liga":
			var lg := world.league(String(job.get("l", "")))
			var g := int(job.get("g", -1))
			return (lg.short_name if lg != null else "Liga") + ("" if g < 0 else ", " + ["goleiros", "defesa", "meio", "ataque"][g])
	var parts: Array = []
	var g2 := int(job.get("g", -1))
	parts.append(["Goleiros", "Defensores", "Meio-campistas", "Atacantes"][g2] if g2 >= 0 else "Todos os setores")
	for f: Array in FOCUS:
		if String(f[0]) == String(job.get("f", "geral")) and String(f[0]) != "geral":
			parts.append(String(f[1]).to_lower())
	if int(job.get("a", 99)) < 99:
		parts.append("até %d anos" % int(job["a"]))
	return ", ".join(parts)


## Relatórios válidos (remove quem sumiu, aposentou ou já está no seu elenco).
static func reports(world: GameWorld) -> Array:
	_trim(world)
	var out: Array = []
	for k in state(world)["ids"]:
		var p := world.player(int(k))
		if p != null:
			out.append(p)
	return out


## Vistos na última rodada (os "novos" da lista).
static func is_new(world: GameWorld, p: Player) -> bool:
	var s := state(world)
	return int(s["ids"].get(str(p.id), -99)) >= world.current_turn() - 1


static func forget(world: GameWorld, p: Player) -> void:
	var s := state(world)
	var key := str(p.id)
	s["ids"].erase(key)
	s["know"].erase(key)


static func _trim(world: GameWorld) -> void:
	var s := state(world)
	var ids: Dictionary = s["ids"]
	var club := world.user_club()
	for k in ids.keys():
		var p := world.player(int(k))
		if p == null or p.club_id == club.id:
			ids.erase(k)
			s["know"].erase(k)
			s["n0"].erase(k)
	if ids.size() > MAX_REPORTS:
		var ks: Array = ids.keys()
		ks.sort_custom(func(a, b): return int(ids[a]) < int(ids[b]))
		for k in ks.slice(0, ids.size() - MAX_REPORTS):
			ids.erase(k)
			s["know"].erase(k)


# ---------------------------------------------------------------------------
# O relatório
# ---------------------------------------------------------------------------

## Peso da recomendação: quanto melhora o time, quanto promete e quanto custa.
static func verdict_score(world: GameWorld, p: Player) -> float:
	var r := PlayerAssessment.report(world, p)
	var now := (float(r["low"]) + float(r["high"])) * 0.5
	var fut := (float(r["future_low"]) + float(r["future_high"])) * 0.5
	var age := p.age(world.year)
	var v := (now - 3.0) * 2.0 + maxf(0.0, fut - now) * (1.2 if age <= 23 else 0.4)
	if age >= 31:
		v -= (age - 30) * 0.4
	var club := world.user_club()
	var price := 0.0 if p.club_id < 0 else float(TransferManager.asking_price(world, p))
	var budget := maxf(1.0, float(club.transfer_budget))
	if price > budget:
		v -= minf(3.0, log(price / budget) / log(2.0) * 1.2)
	if p.club_id < 0 or p.contract_end <= world.year:
		v += 0.6
	return v


## Recomendação do olheiro: rótulo, cor e uma letra de A a D.
static func verdict(world: GameWorld, p: Player) -> Dictionary:
	var v := verdict_score(world, p)
	if v >= 2.6:
		return {"grade": "A", "label": "Contratar", "color": UIColors.GREEN}
	if v >= 1.2:
		return {"grade": "B", "label": "Boa opção", "color": UIColors.GREEN}
	if v >= -0.2:
		return {"grade": "C", "label": "Para compor elenco", "color": UIColors.TEXT}
	return {"grade": "D", "label": "Não recomendado", "color": UIColors.ORANGE}


## Atributos que pesam na posição, do melhor para o pior pelo olho do olheiro.
static func key_attributes(world: GameWorld, p: Player) -> Array:
	var list: Array = []
	for a in Attr.COUNT:
		if float(Pos.WEIGHTS[p.position][a]) >= 0.035:
			list.append(a)
	list.sort_custom(func(a, b): return PlayerAssessment.attribute(world, p, a) > PlayerAssessment.attribute(world, p, b))
	return list


## O que o olheiro escreve: frases curtas a partir do que viu. Quanto mais conhecimento,
## mais coisas ele afirma (personalidade, regularidade e lesões só de perto).
static func notes(world: GameWorld, p: Player) -> Dictionary:
	var k := knowledge(world, p)
	var attrs := key_attributes(world, p)
	var n_strong := 1 if k < 40 else (2 if k < 70 else 3)
	var strong: Array = []
	for a in attrs.slice(0, n_strong):
		strong.append("%s %s" % [Attr.name_of(a), PlayerAssessment.attribute_text(world, p, a)])
	var weak: Array = []
	var rev := attrs.duplicate()
	rev.reverse()
	for a in rev.slice(0, 1 if k < 70 else 2):
		weak.append("%s %s" % [Attr.name_of(a), PlayerAssessment.attribute_text(world, p, a)])
	var person: Array = []
	if k >= KNOW_TRAITS:
		for t in p.traits:
			var td: Dictionary = DatabaseManager.trait_data(String(t))
			if not td.is_empty():
				person.append(String(td.get("name", td.get("n", t))))
	var risks: Array = []
	if k >= KNOW_HIDDEN:
		if p.injury_prone >= 14:
			risks.append("Machuca com frequência")
		elif p.injury_prone <= 6:
			risks.append("Quase nunca se machuca")
		if p.consistency <= 7:
			risks.append("Irregular de um jogo para o outro")
		elif p.consistency >= 15:
			risks.append("Muito regular")
	var foot: String = ["Destro", "Canhoto", "Ambidestro"][clampi(p.foot, 0, 2)]
	return {"strong": strong, "weak": weak, "person": person, "risks": risks, "foot": foot, "know": k}
