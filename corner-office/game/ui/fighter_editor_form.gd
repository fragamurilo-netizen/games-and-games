class_name FighterEditorForm
extends RefCounted
## Formulários do criador/editor de lutadores (Game Design Bible §§4,5,22).
## Só monta controles e envia campos para CareerActions → FighterEditor;
## nenhuma regra de validação mora aqui.

const GROUP_LABELS := {"striking": "Trocação", "grappling": "Wrestling", "jiu_jitsu": "Jiu-jítsu", "physical": "Físico", "mental": "Mental"}


## Tela de criação: escolhe a origem (ou deixa no sorteio) e gera o atleta.
## on_done(fighter_id) abre o editor do atleta criado; on_cancel volta.
static func build_create(screen: Screen, on_done: Callable, on_cancel: Callable) -> void:
	var o: Dictionary = FighterEditor.options()
	screen.add_button("← Cancelar", on_cancel)
	screen.add_heading("Criar lutador")
	screen.add_text("Escolha o que importa e deixe o resto no sorteio. Depois você pode editar tudo.", Tokens.MUTED)
	var any := {"id": "", "label": "Sorteio"}
	var division := screen.add_select("Categoria", [any] + o.divisions)
	var country := screen.add_select("País", [any] + o.countries)
	var population := screen.add_select("Traços do rosto", [{"id": "", "label": "Pelo país"}] + o.populations)
	var base := screen.add_select("Base marcial", [any] + o.martial_bases)
	var style := screen.add_select("Estilo de luta", [any] + o.fight_styles)
	var age := screen.add_number("Idade (0 = sorteio)", 0, 0, 45)
	var level := screen.add_number("Nível técnico (0 = sorteio; 40 regional, 60 bom, 75 elite)", 0, 0, 90)
	var phase := screen.add_select("Momento da carreira", [{"id": "", "label": "Formado"}, {"id": "prospect", "label": "Prospecto (poucas lutas)"}])
	var destination := screen.add_select("Destino", [{"id": "", "label": "Agente livre (mercado)"}, {"id": "roster", "label": "Meu elenco (contrato padrão)"}])
	screen.add_button("GERAR LUTADOR", func():
		var result: Dictionary = await screen.run_action("create_fighter", {
			"division": _value(division), "country": _value(country), "population": _value(population),
			"martial_base": _value(base), "fight_style": _value(style), "age": int(age.value), "level": level.value,
			"prospect": _value(phase) == "prospect", "to_roster": _value(destination) == "roster"})
		if result.get("ok"):
			on_done.call(str(result.fighter_id))
		else:
			screen.refresh())


## Editor completo de um atleta existente.
static func build_edit(screen: Screen, f: Fighter, on_done: Callable) -> void:
	var o: Dictionary = FighterEditor.options()
	var world := Game.world
	screen.add_button("← Voltar sem salvar", on_done)
	screen.add_heading("Editar lutador")
	screen.add_text("%s · %s · %s" % [f.display_name(), f.record_string(), CareerText.division(f.division)], Tokens.MUTED)
	var first := screen.add_input("Nome", f.first_name)
	var last := screen.add_input("Sobrenome", f.last_name)
	var nick := screen.add_input("Apelido (vazio = sem apelido)", f.nickname)
	var country := screen.add_select("País", o.countries, f.country)
	var city := screen.add_input("Cidade", f.city)
	var population := screen.add_select("Traços do rosto", o.populations, str(f.appearance.get("pop", "")))
	var new_face := _check(screen, "Sortear um rosto novo ao salvar")
	var division := screen.add_select("Categoria", o.divisions, f.division)
	var base := screen.add_select("Base marcial", o.martial_bases, f.martial_base)
	var style := screen.add_select("Estilo de luta", [{"id": "", "label": "Sem estilo definido"}] + o.fight_styles, f.fight_style)
	var stance := screen.add_select("Guarda", o.stances, f.stance)
	var body := screen.add_select("Biotipo", o.body_types, f.body_type)
	var age := screen.add_number("Idade", f.age_on(world.date), 18, 45)
	var height := screen.add_number("Altura (cm)", f.height_cm, 140, 215)
	var reach := screen.add_number("Envergadura (cm)", f.reach_cm, 130, 235)
	var charisma := screen.add_number("Carisma", f.charisma, 1, 99)

	screen.add_heading("Atributos")
	screen.add_text("A média de cada grupo desloca todos os atributos dele. Abra o detalhe para ajustar um a um.", Tokens.MUTED)
	var levels := {}
	for group: String in FighterEditor.GROUPS:
		levels[group] = screen.add_number(GROUP_LABELS[group] + " (média)", FighterEditor.group_level(f, group), 1, 99)
	var detail := _check(screen, "Mostrar atributos individuais")
	var fields := {}
	var detail_nodes: Array = []
	for group: String in FighterEditor.GROUPS:
		fields[group] = {}
		var values: Dictionary = f.get(group)
		for attribute: String in values:
			var count := screen.body.get_child_count()
			fields[group][attribute] = screen.add_number("%s · %s" % [GROUP_LABELS[group], attribute.replace("_", " ")], values[attribute], 1, 99)
			for i in range(count, screen.body.get_child_count()):
				detail_nodes.append(screen.body.get_child(i))
	for node: Control in detail_nodes:
		node.visible = false
	detail.toggled.connect(func(on: bool):
		for node: Control in detail_nodes:
			node.visible = on)

	var record := {}
	if f.fight_ids.is_empty():
		screen.add_heading("Cartel antes da carreira")
		for key: String in ["wins", "losses", "draws"]:
			record[key] = screen.add_number({"wins": "Vitórias", "losses": "Derrotas", "draws": "Empates"}[key], f.record[key], 0, 99)
	var bio := screen.add_input("Bio", f.bio)

	screen.add_button("SALVAR ALTERAÇÕES", func():
		var p := {"first_name": first.text, "last_name": last.text, "nickname": nick.text, "country": _value(country),
			"city": city.text, "population": _value(population), "reroll_face": new_face.button_pressed,
			"division": _value(division), "martial_base": _value(base), "fight_style": _value(style),
			"stance": _value(stance), "body_type": _value(body), "age": int(age.value), "height_cm": int(height.value),
			"reach_cm": int(reach.value), "charisma": int(charisma.value), "bio": bio.text}
		if _value(country) != f.country and city.text == f.city:
			p.erase("city")  # país novo sem cidade digitada: o jogo escolhe uma cidade de lá
		var group_levels := {}
		for group: String in levels:
			if int(levels[group].value) != FighterEditor.group_level(f, group):
				group_levels[group] = int(levels[group].value)
		p.group_levels = group_levels
		var attributes := {}
		for group: String in fields:
			for attribute: String in fields[group]:
				if int(fields[group][attribute].value) != int(f.get(group)[attribute]):
					if not attributes.has(group):
						attributes[group] = {}
					attributes[group][attribute] = int(fields[group][attribute].value)
		p.attributes = attributes
		if not record.is_empty():
			p.record = {"wins": int(record.wins.value), "losses": int(record.losses.value), "draws": int(record.draws.value)}
		p.fighter_id = f.id
		var result: Dictionary = await screen.run_action("edit_fighter", p)
		if result.get("ok"):
			on_done.call()
		else:
			screen.refresh())
	if f.fight_ids.is_empty():
		screen.add_button("SORTEAR DE NOVO (mesma categoria e país)", func():
			await screen.run_action("reroll_fighter", {"fighter_id": f.id, "division": f.division, "country": f.country})
			screen.refresh())


static func _check(screen: Screen, text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.custom_minimum_size.y = Tokens.TOUCH_MIN
	screen.body.add_child(box)
	return box


static func _value(select: OptionButton) -> String:
	return str(select.get_item_metadata(select.selected)) if select.selected >= 0 else ""
