extends TestCase
## Bandeiras: todo país do jogo tem especificação válida. Bible §§3,13.

const PATTERNS := ["h", "v", "nordic", "cross", "saltire", "stripes", "tri", "diamond", "quarters", "pall", "serrated", "vband", "diag", "solid"]


func test_every_game_country_has_a_flag() -> void:
	var countries := {}
	for r: Dictionary in ContentDB.load_json("regions.json"):
		for c: String in r.countries: countries[c] = true
	for f: Dictionary in ContentDB.load_json("canonical_fighters.json"):
		if f.has("country"): countries[f.country] = true
	for c: String in countries:
		check(FlagView.has_flag(c), "bandeira para " + c)
	check_eq(FlagView.country_name("BR"), "Brasil", "nome do país")
	check(not FlagView.has_flag("XX"), "código desconhecido sem bandeira")


func test_specs_are_well_formed() -> void:
	var flags: Dictionary = ContentDB.load_json("flags.json").flags
	check(flags.size() >= 62, "cobre os países do universo e do gerador: %d" % flags.size())
	for code: String in flags:
		var spec: Dictionary = flags[code].flag
		check(code.length() == 2 and code == code.to_upper(), "código ISO alfa-2: " + code)
		check(str(spec.get("p", "solid")) in PATTERNS, "padrão conhecido em " + code)
		for c in spec.get("c", []):
			check(Color.html_is_valid(str(c)), "cor válida em " + code)
