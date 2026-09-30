extends TestCase
## FighterEditor: criar, editar e sortear lutadores dentro do jogo (Bible §§4,5,22).


func test_create_respects_chosen_origin_and_style() -> void:
	var w := WorldGenerator.generate(31, "regional_promoter")
	var roster_before: int = w.player_org().roster.size()
	var r := CareerActions.perform(w, "create_fighter", {"division": "m_welterweight", "country": "GE", "martial_base": "wrestling",
		"fight_style": "control", "age": 25, "level": 70, "population": "caucaso", "to_roster": true})
	check(r.ok, "criado")
	var f: Fighter = w.fighters[r.fighter_id]
	check_eq(f.country, "GE", "país escolhido")
	check_eq(f.martial_base, "wrestling", "base escolhida")
	check_eq(f.fight_style, "control", "estilo escolhido")
	check(float(f.style.get("takedown", 1.0)) > 1.0, "estilo pesa nas intenções do Fight Engine")
	check_eq(f.age_on(w.date), 25, "idade escolhida")
	check_eq(f.appearance.pop, "caucaso", "traços escolhidos")
	check_eq(f.organization_id, w.player_org_id, "entrou no meu elenco")
	check_eq(w.player_org().roster.size(), roster_before + 1, "roster cresceu")
	check(w.contracts.has(f.contract_id), "com contrato")
	check(FighterEditor.group_level(f, "grappling") > FighterEditor.group_level(f, "striking") + 5, "controlador wrestler derruba mais do que troca")
	var bad := CareerActions.perform(w, "create_fighter", {"country": "XX"})
	check(not bad.ok, "país inexistente é recusado")


func test_edit_changes_identity_attributes_and_face() -> void:
	var w := WorldGenerator.generate(32, "regional_promoter")
	var id: String = CareerActions.perform(w, "create_fighter", {"division": "m_lightweight"}).fighter_id
	var f: Fighter = w.fighters[id]
	var seed_before: int = f.appearance.seed
	var r := CareerActions.perform(w, "edit_fighter", {"fighter_id": id, "first_name": "  Tiago ", "last_name": "Brandão", "nickname": "Bigorna",
		"country": "BR", "division": "m_welterweight", "martial_base": "bjj", "fight_style": "submission", "age": 30,
		"height_cm": 183, "reach_cm": 190, "group_levels": {"jiu_jitsu": 80}, "attributes": {"striking": {"boxing": 91}},
		"record": {"wins": 9, "losses": 1, "draws": 0}, "population": "afro_diaspora"})
	check(r.ok, "edição aceita")
	check_eq(f.display_name(), "Tiago “Bigorna” Brandão", "nome limpo")
	check_eq(f.division, "m_welterweight", "categoria nova")
	check_eq(f.fight_style, "submission", "estilo novo")
	check(abs(FighterEditor.group_level(f, "jiu_jitsu") - 80) <= 1, "média do grupo ajustada")
	check_eq(f.striking.boxing, 91, "atributo individual")
	check_eq(f.record.wins, 9, "cartel antes da carreira")
	check_eq(f.age_on(w.date), 30, "idade")
	check_eq(f.appearance.age, 30, "rosto envelhece junto")
	check_eq(f.appearance.pop, "afro_diaspora", "traços trocados")
	check_eq(f.appearance.seed, seed_before, "mesmo rosto (seed) sem pedir sorteio")
	CareerActions.perform(w, "edit_fighter", {"fighter_id": id, "reroll_face": true})
	check(f.appearance.seed != seed_before, "rosto novo quando pedido")
	var restored := SaveSystem.decode(SaveSystem.encode(w))
	check_eq(restored.fighters[id].fight_style, "submission", "estilo sobrevive ao save")


func test_invalid_edits_change_nothing() -> void:
	var w := WorldGenerator.generate(33, "regional_promoter")
	var f: Fighter = w.fighters.ftr_carter
	var r := CareerActions.perform(w, "edit_fighter", {"fighter_id": f.id, "first_name": "", "country": "BR"})
	check(not r.ok, "nome vazio recusado")
	check_eq(f.first_name, "Malik", "nada mudou")
	check_eq(f.country, "US", "país intacto")
	var canon := CareerActions.perform(w, "edit_fighter", {"fighter_id": f.id, "nickname": "Rei"})
	check(canon.ok, "canônico editável")
	check(not f.appearance.has("pop"), "retrato autoral do canônico preservado")


func test_booked_fighter_keeps_division_and_history_locks_reroll() -> void:
	var w := WorldGenerator.generate(34, "regional_promoter")
	var fight: Fight
	for candidate: Fight in w.fights.values():
		if candidate.status == "booked":
			fight = candidate
			break
	check(fight != null, "há luta marcada")
	var f: Fighter = w.fighters[fight.fighter_a_id]
	var r := CareerActions.perform(w, "edit_fighter", {"fighter_id": f.id, "division": "w_flyweight" if not f.division.begins_with("w_") else "m_lightweight"})
	check(not r.ok and r.reasons[0].code == "FIGHTER_BOOKED", "categoria travada com luta marcada")
	var created: String = CareerActions.perform(w, "create_fighter", {}).fighter_id
	var again := CareerActions.perform(w, "reroll_fighter", {"fighter_id": created})
	check(again.ok and w.fighters.has(created), "sorteio mantém o id")
	w.fighters[created].fight_ids.append("fight_x")
	check(not CareerActions.perform(w, "reroll_fighter", {"fighter_id": created}).ok, "quem já lutou não é re-sorteado")


func test_editor_screens_build() -> void:
	var w := WorldGenerator.generate(35, "regional_promoter")
	Game.world = w
	var screen: Screen = load("res://ui/screens/fighters_screen.gd").new()
	screen.editing = "new"
	screen.refresh()
	check(screen.body.get_child_count() > 15, "formulário de criação montado")
	var id: String = CareerActions.perform(w, "create_fighter", {}).fighter_id
	screen.editing = id
	screen.refresh()
	check(screen.body.get_child_count() > 60, "editor montado (%d controles)" % screen.body.get_child_count())
	screen.editing = ""
	screen.selected_fighter = id
	screen.refresh()
	check(screen.body.get_child_count() > 5, "perfil montado")
	screen.free()
