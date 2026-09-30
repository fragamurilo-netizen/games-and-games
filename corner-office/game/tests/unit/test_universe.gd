extends TestCase
## Universo anterior ao save (Game Design Bible §§2–3, 13–14).


func test_geography_is_complete_and_linked() -> void:
	check(Universe.countries().size() >= 50, "50+ países")
	check(Universe.cities().size() >= 140, "140+ cidades")
	for c: Dictionary in Universe.cities():
		check(not Universe.country(c.country).is_empty(), "país da cidade %s existe" % c.name)
		check(c.has("art") and c.art.has("landmark"), "cidade %s tem ilustração" % c.name)
	for id: String in Universe.city("city_las_vegas").venues:
		check_eq(Universe.venue(id).city_id, "city_las_vegas", "arena aponta de volta para a cidade")


func test_organization_layers_match_bible_scale() -> void:
	check_eq(Universe.organizations("global").size(), 7, "7 globais")
	var national := Universe.organizations("national").size()
	var regional := Universe.organizations("regional").size()
	check(national >= 24 and national <= 40, "camada nacional (%d)" % national)
	check(regional >= 80 and regional <= 120, "camada regional (%d)" % regional)
	for tier in ["national", "regional", "defunct"]:
		for o: Dictionary in Universe.organizations(tier):
			check(not Universe.city(o.city_id).is_empty(), "sede de %s existe" % o.name)


func test_lineages_never_overlap_and_end_with_canon() -> void:
	for org: String in ["org_crown", "org_ascend", "org_vale", "org_shinsei", "org_frontline", "org_iron", "org_pfl"]:
		for division: String in Universe.divisions_of(org):
			var reigns := Universe.lineage(org, division)
			for i in range(1, reigns.size()):
				check(str(reigns[i - 1].end) <= str(reigns[i].start), "%s %s: reinados em sequência" % [org, division])
			for r: Dictionary in reigns:
				check(not Universe.person(r.fighter_id).is_empty(), "campeão %s registrado" % r.fighter_id)
	check_eq(Universe.last_reign("org_crown", "m_lightweight").fighter_id, "ftr_carter", "Carter reina nos leves da Crown")
	check(Universe.last_reign("org_crown", "m_lightweight").end == null, "reinado de Carter segue aberto")


func test_world_starts_with_champions() -> void:
	var w := WorldGenerator.generate(7, "regional_promoter")
	check_eq(w.organizations.org_crown.titles.m_lightweight.champion_id, "ftr_carter", "Carter é campeão em 2027")
	check_eq(w.organizations.org_iron.titles.m_welterweight.champion_id, "ftr_arsanov", "Arsanov é campeão em 2027")
	var crowned := 0
	for org: Organization in w.organizations.values():
		for division: String in org.titles:
			var f: Fighter = w.fighters[org.titles[division].champion_id]
			check_eq(f.division, division, "campeão luta na própria categoria")
			check(org.roster.has(f.id), "campeão está no elenco de %s" % org.short_name)
			crowned += 1
	for org_id: String in ["org_crown", "org_ascend", "org_vale", "org_shinsei", "org_frontline", "org_iron", "org_pfl"]:
		var org: Organization = w.organizations[org_id]
		for division: String in Universe.divisions_of(org_id):
			var eligible := org.roster.any(func(id): return w.fighters[id].division == division)
			check(org.titles.has(division) == eligible, "%s %s: cinturão com dono sempre que há elenco" % [org_id, division])
	check(crowned >= 20, "cinturões coroados (%d)" % crowned)
	check(w.player_org().titles.is_empty(), "org do jogador não recebe cinturões históricos")


func test_history_is_referenced_and_queryable() -> void:
	for f: Dictionary in Universe.classic_fights():
		check(not Universe.person(f.red).is_empty() and not Universe.person(f.blue).is_empty(), "lutadores de %s existem" % f.id)
	var titles := Universe.on_this_day({"year": 2027, "month": 7, "day": 9}).map(func(x): return x.title)
	check(titles.any(func(t): return "CROWN 198" in t), "Carter vs. Mendes I aparece em 9 de julho")
	check(Universe.hall_of_fame().size() >= 30, "Hall da Fama com 30+ nomes")
	check(not Universe.records().is_empty(), "recordes existem")


func test_universe_uses_no_real_promotion_names() -> void:
	var text := ""
	for file in ["geography", "organizations", "history", "people"]:
		text += JSON.stringify(Universe.data(file))
	for banned in ["UFC", "Bellator", "RIZIN", "ONE Championship", "Strikeforce", "PRIDE FC", "Dana White"]:
		check(not banned in text, "sem '%s' no universo" % banned)


func test_city_art_renders() -> void:
	var img := CityArt.render(Universe.city("city_rio_de_janeiro"), Vector2i(160, 90))
	check_eq(img.get_size(), Vector2i(160, 90), "tamanho pedido")
	check(img.get_pixel(80, 5) != img.get_pixel(80, 85), "céu e chão diferentes")


func test_history_people_have_portrait_data() -> void:
	var a := Universe.as_fighter("hist_braga")
	var b := Universe.as_fighter("hist_harper")
	check(a.appearance.has("seed") and a.appearance.has("pop"), "lenda tem aparência para o retrato")
	check_eq(b.sex, Fighter.Sex.FEMALE, "sexo vem da história")
	check(PortraitService.key_for(a) != PortraitService.key_for(b), "cada pessoa tem retrato próprio")
	var w := WorldGenerator.generate(3, "regional_promoter", false)
	check(Universe.as_fighter("ftr_carter", w) == w.fighters.ftr_carter, "lutador vivo usa a ficha do mundo")
