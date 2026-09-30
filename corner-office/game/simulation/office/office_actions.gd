class_name OfficeActions
extends RefCounted
## Ações do presidente sobre a sede (Game Design Bible §15, §19). A reação de
## cada pessoa depende de traços, ambição, lealdade, confiança e contexto.
## Retorna {ok, message, tone} — tone: good | bad | neutral (feedback da UI).

static func perform(world: WorldState, action: String, p: Dictionary = {}) -> Dictionary:
	var org := world.player_org()
	var t := Office.tuning()
	var s: StaffMember = world.staff.get(str(p.get("staff_id", "")))
	match action:
		"hire":
			if s == null or s.status != "candidate":
				return _fail("Candidato indisponível.")
			if Office.active_staff(world).size() >= Office.desks(org):
				return _fail("Sem mesa livre. Expanda a sede para contratar mais.")
			var offer := int(p.get("salary", s.asking_salary))
			if offer < s.asking_salary:
				var gap := float(s.asking_salary - offer) / maxf(1.0, s.asking_salary)
				if gap > 0.15 or world.office_rng.chance(gap * 4.0 + s.ambition / 400.0):
					s.asking_salary = int(s.asking_salary * 1.03)
					return {"ok": false, "message": "%s recusou %s. Pede %s." % [s.first_name, _money(offer), _money(s.asking_salary)], "tone": "bad"}
				s.asking_salary = offer
			Office.hire(world, s)
			Media.new().story(world, "staff_hired", "staffhire:" + s.id, {"staff": s.full_name(), "role": Office.role_label(s.role), "org": org.name}, [org.id])
			return {"ok": true, "message": "%s chegou à sede como %s." % [s.full_name(), Office.role_label(s.role)], "tone": "good"}
		"interview":
			if s == null or s.status != "candidate":
				return _fail("Candidato indisponível.")
			s.interviewed = true
			return {"ok": true, "message": "Entrevista feita: %s mostrou o que sabe." % s.first_name, "tone": "neutral"}
		"expand":
			var next := Office.next_level_info(org)
			if next.is_empty():
				return _fail("A sede já está no tamanho máximo.")
			if org.reputation < int(next.reputation):
				return _fail("Reputação %d exigida para %s." % [int(next.reputation), next.label])
			if org.cash - CareerActions.reserved_cash(world) < int(next.cost):
				return _fail("Caixa insuficiente: a mudança custa %s." % _money(int(next.cost)))
			Office.ledger(world, org, "office", -int(next.cost), "Expansão: " + str(next.label))
			org.office_level += 1
			for m: StaffMember in Office.active_staff(world):
				m.morale = minf(100.0, m.morale + 8.0)
			Media.new().story(world, "office_expanded", "office:%d" % org.office_level, {"org": org.name, "office": next.label}, [org.id])
			return {"ok": true, "message": "Nova sede: %s. Mais mesas e novas salas." % next.label, "tone": "good"}
	if s == null or s.organization_id != org.id or not s.is_active():
		return _fail("Pessoa fora da equipe.")
	match action:
		"talk":
			s.trust = clampf(s.trust + 2.0, -100.0, 100.0)
			var said := "Tudo em ordem por aqui." if s.mood_reasons.is_empty() else Office.mood_text(str(s.mood_reasons[0]))
			for code: String in s.mood_reasons:
				if code in ["UNDERPAID", "OVERLOADED", "HAS_RIVAL", "WANTS_GROWTH", "EXHAUSTED", "DISTRUSTS_YOU"]:
					said = Office.mood_text(code)
					if code == "HAS_RIVAL":
						for id: String in s.relationships:
							if str(s.relationships[id].kind) == "rival" and world.staff.has(id):
								said = "Não aguenta mais trabalhar com %s." % world.staff[id].first_name
					break
			return {"ok": true, "message": "%s: \"%s\"" % [s.first_name, said], "tone": "neutral"}
		"praise":
			var fresh := s.last_praise_on.is_empty() or GameDate.days_between(s.last_praise_on, world.date) >= int(t.praise_cooldown_days)
			s.last_praise_on = world.date.duplicate()
			if not fresh:
				s.trust -= 1.0
				return {"ok": true, "message": "%s agradeceu, mas elogio toda semana perde valor." % s.first_name, "tone": "neutral"}
			var gain := 10.0 if Office.performance(s) >= 50 else 4.0
			s.morale = minf(100.0, s.morale + gain)
			s.trust = minf(100.0, s.trust + 5.0)
			s.stress = maxf(0.0, s.stress - (8.0 if "anxious" in s.traits else 3.0))
			Office.log_history(world, s, "Recebeu elogio da presidência.")
			return {"ok": true, "message": "%s ficou motivado (+%d moral)." % [s.first_name, int(gain)], "tone": "good"}
		"pressure":
			s.last_pressure_on = world.date.duplicate()
			var hot := "hothead" in s.traits or "perfectionist" in s.traits
			if "workaholic" in s.traits or (s.loyalty > 70 and not hot):
				s.skill = minf(s.potential, s.skill + 0.8)
				s.stress = minf(100.0, s.stress + 8.0)
				Office.log_history(world, s, "Foi cobrado e respondeu com trabalho.")
				return {"ok": true, "message": "%s aceitou a cobrança e acelerou o ritmo." % s.first_name, "tone": "good"}
			s.stress = minf(100.0, s.stress + (18.0 if hot else 12.0))
			s.morale = maxf(0.0, s.morale - (14.0 if hot else 7.0))
			s.trust = maxf(-100.0, s.trust - (12.0 if hot else 5.0))
			Office.log_history(world, s, "Foi cobrado pela presidência.")
			return {"ok": true, "message": ("%s saiu da sala batendo a porta." if hot else "%s ficou abalado com a cobrança.") % s.first_name, "tone": "bad"}
		"raise":
			var pct := float(p.get("pct", t.raise_pct))
			var new_salary := int(round(s.salary * (1.0 + pct) / 50.0)) * 50
			var market := Office.market_salary(s.role, s.level, s.skill)
			var gain := 12.0 if s.salary < market else 6.0
			if "ambitious" in s.traits and pct < 0.1:
				gain *= 0.5
			s.salary = new_salary
			s.last_raise_on = world.date.duplicate()
			s.morale = minf(100.0, s.morale + gain)
			s.loyalty = minf(100.0, s.loyalty + 4.0)
			s.trust = minf(100.0, s.trust + 6.0)
			Office.log_history(world, s, "Aumento para %s/mês." % _money(new_salary))
			return {"ok": true, "message": "%s agora ganha %s/mês." % [s.first_name, _money(new_salary)], "tone": "good"}
		"promote":
			var levels: Array = Office.config().levels
			var idx := -1
			for i in levels.size():
				if levels[i].id == s.level:
					idx = i
			if idx < 0 or idx >= levels.size() - 1:
				return _fail("%s já está no topo da carreira." % s.first_name)
			var next_level: Dictionary = levels[idx + 1]
			if s.skill < float(next_level.min_skill):
				return _fail("%s ainda não tem nível para %s (precisa de %d de habilidade)." % [s.first_name, next_level.label, int(next_level.min_skill)])
			if next_level.id == "director":
				for m: StaffMember in Office.active_staff(world):
					if m.id != s.id and m.level == "director" and Office.department(m.role) == Office.department(s.role):
						return _fail("%s já dirige %s." % [m.full_name(), Office.department_label(Office.department(s.role))])
			s.level = str(next_level.id)
			s.salary = maxi(int(round(s.salary * (1.0 + float(t.promotion_pct)) / 50.0)) * 50, Office.market_salary(s.role, s.level, s.skill))
			s.morale = minf(100.0, s.morale + 18.0)
			s.loyalty = minf(100.0, s.loyalty + 8.0)
			s.trust = minf(100.0, s.trust + 10.0)
			s.activity = "celebrating"
			Office.log_history(world, s, "Promovido a %s." % next_level.label)
			# Quem disputava o mesmo espaço sente o golpe.
			for m: StaffMember in Office.active_staff(world):
				if m.id != s.id and m.role == s.role and m.ambition > 60:
					m.morale = maxf(0.0, m.morale - 10.0)
					Office._relate(world, m, s, -18.0)
			return {"ok": true, "message": "%s promovido a %s." % [s.first_name, next_level.label], "tone": "good"}
		"vacation":
			if s.status == "vacation":
				return _fail("%s já está de férias." % s.first_name)
			var days := int(p.get("days", t.vacation_days))
			s.status = "vacation"
			s.activity = "vacation"
			s.vacation_until = GameDate.add_days(world.date, days)
			s.trust = minf(100.0, s.trust + 3.0)
			Office.log_history(world, s, "Saiu de férias por %d dias." % days)
			return {"ok": true, "message": "%s volta em %s." % [s.first_name, GameDate.format(s.vacation_until)], "tone": "neutral"}
		"move":
			var role := str(p.get("role", ""))
			if not Office.config().roles.has(role) or role == s.role:
				return _fail("Função inválida.")
			var before := Office.role_label(s.role)
			s.role = role
			s.skill = maxf(15.0, s.skill * 0.82)
			s.morale = maxf(0.0, s.morale - (4.0 if s.ambition > 60 else 0.0))
			Office.log_history(world, s, "Transferido de %s para %s." % [before, Office.role_label(role)])
			return {"ok": true, "message": "%s agora trabalha em %s (curva de aprendizado)." % [s.first_name, Office.role_label(role)], "tone": "neutral"}
		"fire":
			var severance := s.salary * int(t.severance_months)
			Office.ledger(world, org, "severance", -severance, "Rescisão: " + s.full_name())
			_leave(world, s, "Demitido pela presidência.")
			for m: StaffMember in Office.active_staff(world):
				var rel: Dictionary = m.relationships.get(s.id, {})
				if str(rel.get("kind", "")) in ["friend", "mentor", "mentee"]:
					m.morale = maxf(0.0, m.morale - 12.0)
					m.trust = maxf(-100.0, m.trust - 8.0)
				elif str(rel.get("kind", "")) == "rival":
					m.morale = minf(100.0, m.morale + 5.0)
			Media.new().story(world, "staff_left", "staffleft:" + s.id, {"staff": s.full_name(), "role": Office.role_label(s.role), "org": org.name}, [org.id])
			return {"ok": true, "message": "%s deixou a empresa. Rescisão: %s." % [s.full_name(), _money(severance)], "tone": "bad"}
	return _fail("Ação desconhecida.")


static func _leave(world: WorldState, s: StaffMember, text: String, destination: String = "") -> void:
	s.status = "gone"
	s.activity = "leaving"
	s.left_on = world.date.duplicate()
	s.destination_org = destination
	Office.log_history(world, s, text)


static func _fail(text: String) -> Dictionary:
	return {"ok": false, "message": text, "tone": "bad"}


static func _money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if v < 0 else "") + "US$ " + s + out
