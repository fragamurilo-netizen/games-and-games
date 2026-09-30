extends TestCase
## Sede: equipe, carga, folha, ações do presidente, decisões e save.
## (Game Design Bible §12, §15 Organização/staff, §19.)


func _world(seed_value: int = 5) -> WorldState:
	return WorldGenerator.generate(seed_value, "regional_promoter")


func test_new_career_opens_with_staff_and_candidates() -> void:
	var w := _world()
	var team := Office.active_staff(w)
	check_eq(team.size(), Office.config().start_staff.size(), "Equipe inicial")
	check(not Office.candidates(w).is_empty(), "Candidatos no mercado")
	var desks := {}
	for s: StaffMember in team:
		check(not desks.has(s.desk), "Mesa única por pessoa")
		desks[s.desk] = true
		check(s.salary > 0 and not s.look.is_empty() and not s.traits.is_empty(), "Pessoa completa: " + s.full_name())


func test_office_uses_its_own_rng_stream() -> void:
	var a := _world(9)
	var b := _world(9)
	check_eq(a.rng.get_state(), b.rng.get_state(), "Mesmo seed, mesmo RNG da liga")
	check_eq(Office.active_staff(a)[0].full_name(), Office.active_staff(b)[0].full_name(), "Equipe determinística")


func test_hire_places_person_at_a_desk_and_fire_pays_severance() -> void:
	var w := _world()
	var c: StaffMember = Office.candidates(w)[0]
	var r := OfficeActions.perform(w, "hire", {"staff_id": c.id})
	check(r.ok, "Contratou: " + str(r.message))
	check(c.status == "active" and c.desk >= 0, "Tem mesa")
	var cash := w.player_org().cash
	var fired := OfficeActions.perform(w, "fire", {"staff_id": c.id})
	check(fired.ok and c.status == "gone", "Demitido")
	check_eq(w.player_org().cash, cash - c.salary, "Rescisão de um salário")
	check(w.player_org().ledger[-1].kind == "severance", "Livro-caixa explica a saída")


func test_desks_limit_hiring_until_office_grows() -> void:
	var w := _world()
	var org := w.player_org()
	while Office.active_staff(w).size() < Office.desks(org):
		var c := Office.generate(w, "scout")
		check(OfficeActions.perform(w, "hire", {"staff_id": c.id}).ok, "Contrata até lotar")
	var extra := Office.generate(w, "scout")
	check(not OfficeActions.perform(w, "hire", {"staff_id": extra.id}).ok, "Sem mesa, sem contratação")
	org.reputation = 30
	org.cash = 5000000
	check(OfficeActions.perform(w, "expand", {}).ok, "Expande a sede")
	check_eq(org.office_level, 2, "Nível 2")
	check(OfficeActions.perform(w, "hire", {"staff_id": extra.id}).ok, "Nova mesa, nova contratação")


func test_workload_from_real_events_raises_stress() -> void:
	var w := _world()
	var mm: StaffMember = null
	for s: StaffMember in Office.active_staff(w):
		if s.role == "matchmaker":
			mm = s
	var calm := mm.stress
	for i in 3:
		var ev := CareerActions.perform(w, "create_event", {"days": 14})
		check(ev.ok, "Evento criado")
	var sim := WorldSim.new(w)
	for i in 7:
		sim.advance_day()
	check(mm.workload > 1.0, "Três cards em montagem sobrecarregam o matchmaker: %.2f" % mm.workload)
	check(mm.stress > calm, "Estresse sobe com a carga: %.1f → %.1f" % [calm, mm.stress])


func test_payroll_is_paid_on_the_first_of_the_month() -> void:
	var w := _world()
	var sim := WorldSim.new(w)
	var pay := Office.payroll(w)
	while int(w.date.day) != 28:
		sim.advance_day()
	var before := w.player_org().ledger.size()
	while int(w.date.day) != 1:
		sim.advance_day()
	var paid := w.player_org().ledger.slice(before).filter(func(e): return e.kind == "payroll")
	check_eq(paid.size(), 1, "Uma folha por mês")
	check(paid.size() == 1 and -int(paid[0].amount) >= pay * 0.9, "Valor da folha")


func test_staff_quality_changes_real_systems() -> void:
	var w := _world()
	var org := w.player_org()
	var ev_id: String = CareerActions.perform(w, "create_event", {"days": 30}).event_id
	var ev: FightEvent = w.events[ev_id]
	var roster: Array = org.roster
	for i in range(0, 8, 2):
		var f := Fight.new()
		f.id = w.new_id("fight"); f.event_id = ev_id; f.fighter_a_id = roster[i]; f.fighter_b_id = roster[i + 1]; f.status = "booked"
		w.add("fights", f); ev.fight_ids.append(f.id)
	var with_staff := Economy.new().project_event(w, ev)
	var saved := w.staff.duplicate()
	for s: StaffMember in Office.active_staff(w):
		if s.role == "marketing":
			s.status = "gone"
	var without := Economy.new().project_event(w, ev)
	check(int(with_staff.attendance) > int(without.attendance), "Marketing enche a arena: %d vs %d" % [with_staff.attendance, without.attendance])
	w.staff = saved
	check(Office.effect(w, "org_crown", "marketing") == 0.0, "Rivais não têm sede simulada")


func test_praise_pressure_and_raise_react_to_personality() -> void:
	var w := _world()
	var s: StaffMember = Office.active_staff(w)[0]
	s.traits = ["hothead"]
	var morale := s.morale
	check(OfficeActions.perform(w, "pressure", {"staff_id": s.id}).tone == "bad", "Pavio curto reage mal à cobrança")
	check(s.morale < morale, "Moral cai")
	s.traits = ["workaholic"]
	check(OfficeActions.perform(w, "pressure", {"staff_id": s.id}).tone == "good", "Workaholic responde com trabalho")
	var salary := s.salary
	OfficeActions.perform(w, "raise", {"staff_id": s.id})
	check(s.salary > salary, "Aumento aplicado")
	check(OfficeActions.perform(w, "praise", {"staff_id": s.id}).tone == "good", "Elogio motiva")
	check(OfficeActions.perform(w, "praise", {"staff_id": s.id}).tone == "neutral", "Elogio repetido perde valor")


func test_dilemma_needs_a_fact_and_consequences_follow() -> void:
	var w := _world()
	var s: StaffMember = Office.active_staff(w)[0]
	check(Dilemmas._requirement(w, "underpaid_ambitious", {}).is_empty() or s.ambition >= 55, "Sem fato, sem pedido")
	s.ambition = 90
	s.skill = 70
	s.salary = 3000
	s.hired_on = GameDate.add_days(w.date, -400)
	var ctx := Dilemmas._requirement(w, "underpaid_ambitious", {})
	check(ctx.get("staff_ids", []) == [s.id], "Pedido nasce do salário abaixo do mercado")
	var d := Dilemmas.create(w, "raise_request", ctx)
	check(d != null and d.options.size() >= 4, "Opções contextuais")
	var morale := s.morale
	var r := Dilemmas.resolve(w, d, "refuse")
	check(r.ok and d.status == "resolved", "Resolvido")
	check(s.morale < morale, "Recusa derruba a moral")
	check(not Dilemmas.resolve(w, d, "give").ok, "Não decide duas vezes")
	var queue: Array = w.player_org().office_state.get("followups", [])
	check(queue.all(func(f): return f.event == "poach_offer"), "Desdobramento possível é a sondagem rival")


func test_unanswered_dilemma_applies_default_when_it_expires() -> void:
	var w := _world()
	var s: StaffMember = Office.active_staff(w)[0]
	s.stress = 95
	var d := Dilemmas.create(w, "burnout", Dilemmas._requirement(w, "burning_out", {}))
	check(d != null, "Esgotamento vira decisão")
	w.date = GameDate.add_days(d.expires_on, 1)
	Dilemmas.tick(w)
	check_eq(d.status, "expired", "Prazo venceu")
	check_eq(d.choice, "ignore", "Aplica a opção padrão")


func test_office_state_survives_save_and_migration() -> void:
	var w := _world()
	var s: StaffMember = Office.active_staff(w)[0]
	s.traits = ["mentor"]
	OfficeActions.perform(w, "raise", {"staff_id": s.id})
	var d := Dilemmas.create(w, "understaffed", {"role_id": "scout", "impact": "x"})
	check(d != null, "Dilema criado")
	var data: Dictionary = JSON.parse_string(JSON.stringify(w.to_dict()))
	var back := WorldState.from_dict(data)
	var s2: StaffMember = back.staff[s.id]
	check_eq(s2.salary, s.salary, "Salário salvo")
	check_eq(s2.traits, ["mentor"], "Traços salvos")
	check_eq(back.dilemmas[d.id].title, d.title, "Decisão salva")
	check_eq(back.office_rng.get_state(), w.office_rng.get_state(), "RNG da sede salvo")
	var old := w.to_dict()
	old.erase("staff"); old.erase("dilemmas"); old.erase("office_rng_state"); old.schema_version = 3
	var migrated := SaveSystem._migrate_v3_to_v4(old)
	check(migrated.has("staff") and migrated.has("office_rng_state"), "Migração v3 → v4")
