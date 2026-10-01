extends TestCase
## Fotos dos lutadores: mesmo desenho do Fight Studio, cache estável. Bible §5.


func _fighter(seed: int) -> Fighter:
	var f := Fighter.new(); f.id = "ftr_p%d" % seed; f.first_name = "Ana"; f.last_name = "Costa"
	f.appearance = {"seed": seed, "sex": "f", "pop": "latino", "age": 27}
	return f


func test_key_follows_appearance_only() -> void:
	var a := _fighter(10); var b := _fighter(10); b.first_name = "Outra"
	check_eq(PortraitService.key_for(a), PortraitService.key_for(b), "nome não muda a foto")
	check(PortraitService.key_for(a) != PortraitService.key_for(_fighter(11)), "aparência diferente, chave diferente")
	check_eq(PortraitService.initials(a), "AC", "iniciais de reserva")


func test_sheet_reuses_fight_studio_scripts() -> void:
	var html := PortraitService.new().sheet_html([{"key": "k", "fighter": PortraitService.payload(_fighter(3))}])
	check(html.contains("function drawFace"), "usa identity.js original")
	check(html.contains("FightRenderer"), "usa renderer.js original")
	check(html.contains("FightAppearance"), "usa appearance.js original")
	check(not html.contains("Fight Night broadcast shell"), "sem o shell da transmissão")
	check(html.contains("renderCornerOfficePortrait"), "inclui portrait_sheet.js")
	check(not html.contains("__CO_PORTRAIT_W__"), "tamanho substituído")


func test_accepted_png_is_cached_and_announced() -> void:
	var service := PortraitService.new()
	var img := Image.create(PortraitService.W, PortraitService.H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.4, 0.3, 1))
	var url := "data:image/png;base64," + Marshalls.raw_to_base64(img.save_png_to_buffer())
	var got := []
	service.portrait_ready.connect(func(k): got.append(k))
	var f := _fighter(987654)
	var key := PortraitService.key_for(f)
	check(service.accept(key, url), "PNG aceito")
	check_eq(got, [key], "UI avisada")
	check(service.texture_for(f) != null, "textura em memória")
	var fresh := PortraitService.new()
	check(fresh.texture_for(f) != null, "textura recarregada do cache em disco")
	fresh.free()
	check(not service.accept("x", "not a png"), "lixo rejeitado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s/%s.png" % [PortraitService.CACHE_DIR, key]))
	service.free()
