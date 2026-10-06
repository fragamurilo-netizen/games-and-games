class_name LicensedData
extends RefCounted
## Campos detalhados (e opcionais) dos JSON de dados, pensados para quem quiser colocar dados
## licenciados — nomes oficiais, estádios, uniformes por temporada, patrocinadores, escudos em
## imagem — só editando arquivos. Tudo aqui é opcional: sem esses campos, o jogo gera como sempre.
##
## Clube (data/world/clubs/<PAÍS>.json → "clubs": [...]), além dos campos de sempre:
##   official / official_name   nome oficial completo ("Sociedade Esportiva ...")
##   short_name, abbreviation, nickname, reputation, archetype
##                              apelidos em inglês de short, abbr, nick, rep, arch
##   founded                    ano (1914) ou data ("1914-08-26")
##   colors                     ["#hex", "#hex"] ou {"primary": "#hex", "secondary": "#hex"}
##   crest_img                  imagem do escudo (nome do arquivo na pasta img/ do mod)
##   stadium                    texto (só o nome) ou objeto:
##                              {name, capacity, city, built, nick, photo, kind}
##                              kind: arena | caldeirao | olimpico | acanhado (desenho do estádio
##                              e corte do gramado na partida; sem kind, o jogo escolhe)
##   kits                       uniformes do clube, no mesmo formato de data/world/kits
##                              ({h, a, t, g, alt, seasons: {"2027": {h, a, t, g}}})
##   sponsors                   {"master": {...}, "fornecedor": {...}, "manga", "costas", "calcao"}
##                              cada um: {n: nome, c: cor de fundo, t: cor do texto, logo: imagem,
##                              yrs: anos de contrato (padrão 3), v: valor anual (padrão: o de mercado)}
## Um uniforme pode trazer "sponsor" e "supplier" (texto ou objeto como acima): viram o master e a
## fornecedora do clube, se o clube ainda não tiver.

const VENUE_KINDS: Array[String] = ["arena", "caldeirao", "olimpico", "acanhado"]
const VENUE_KIND_NAMES := {
	"": "Automático", "arena": "Arena moderna", "caldeirao": "Caldeirão", "olimpico": "Olímpico", "acanhado": "Acanhado",
}
## O que cada tipo de estádio muda no gramado (a partida desenha o corte a partir do tipo).
const VENUE_KIND_PITCH := {
	"": "O jogo escolhe pelo tamanho e pelo país.",
	"arena": "Listras finas e gramado impecável, placas de LED.",
	"caldeirao": "Listras largas, alambrado e arquibancada colada.",
	"olimpico": "Corte xadrez e pista de atletismo em volta.",
	"acanhado": "Gramado gasto nas áreas, muro pintado e poucas placas.",
}
const VENUE_FIELDS: Array[String] = ["kind", "photo", "city", "built", "nick"]
const ALIASES := {
	"official_name": "official", "short_name": "short", "abbreviation": "abbr", "nickname": "nick",
	"reputation": "rep", "archetype": "arch",
}


## Normaliza um clube dos dados (no lugar): apelidos de campos, estádio em objeto, cores em objeto,
## data de fundação e escudo em imagem. Depois disso, o resto do jogo lê os campos de sempre
## (stadium é texto, capacity é número) e os extras ficam em "venue".
static func normalize_club(d: Dictionary) -> Dictionary:
	for a in ALIASES:
		if d.has(a) and not d.has(ALIASES[a]):
			d[ALIASES[a]] = d[a]
	var cols: Variant = d.get("colors", null)
	if cols is Dictionary:
		d["colors"] = [String(cols.get("primary", "#FFFFFF")), String(cols.get("secondary", "#000000"))]
	var fd: Variant = d.get("founded", null)
	if fd is String:
		d["founded_date"] = fd
		d["founded"] = int(String(fd).get_slice("-", 0))
	var st: Variant = d.get("stadium", null)
	if st is Dictionary:
		var venue: Dictionary = Dictionary(d.get("venue", {})).duplicate(true)
		for k in VENUE_FIELDS:
			if st.has(k):
				venue[k] = st[k]
		if st.has("capacity"):
			d["capacity"] = int(st["capacity"])
		d["stadium"] = String(st.get("name", ""))
		if String(d["stadium"]) == "":
			d.erase("stadium")
		d["venue"] = venue
	var img := String(d.get("crest_img", d.get("crest_image", "")))
	if img != "":
		var cr: Dictionary = Dictionary(d.get("crest", {})).duplicate(true)
		cr["img"] = img
		d["crest"] = cr
	# Patrocínio escrito no uniforme titular vira patrocínio do clube.
	var kits: Variant = d.get("kits", null)
	if kits is Dictionary and kits.get("h", null) is Dictionary:
		var h: Dictionary = kits["h"]
		var sp: Dictionary = Dictionary(d.get("sponsors", {})).duplicate(true)
		if h.has("sponsor") and not sp.has("master"):
			sp["master"] = _brand(h["sponsor"])
		if h.has("supplier") and not sp.has("fornecedor"):
			sp["fornecedor"] = _brand(h["supplier"])
		if not sp.is_empty():
			d["sponsors"] = sp
	return d


static func _brand(v: Variant) -> Dictionary:
	if v is Dictionary:
		return v.duplicate(true)
	return {"n": String(v)}


## Extras de um clube autoral recém-criado (ClubGenerator.from_data).
static func apply_club(c: Club, d: Dictionary) -> void:
	c.official = String(d.get("official", ""))
	var venue: Variant = d.get("venue", {})
	c.venue = venue.duplicate(true) if venue is Dictionary else {}
	var cr: Variant = d.get("crest", {})
	if cr is Dictionary and String(cr.get("img", "")) != "":
		c.crest["img"] = String(cr["img"])


## Tipo de estádio escolhido nos dados ou no editor ("" = automático).
static func venue_kind(c: Club) -> String:
	var k := String(c.venue.get("kind", ""))
	return k if VENUE_KINDS.has(k) else ""


## Patrocinadores fixos dos dados (campo "sponsors" dos clubes): entram por cima dos sorteados.
## Chamado na geração do mundo, depois de SponsorManager.ensure_all.
static func apply_sponsors(w: GameWorld) -> void:
	var by_key := {}
	for n in DatabaseManager.league_nations():
		for d in DatabaseManager.club_data(n):
			if d.get("sponsors", null) is Dictionary and not (d["sponsors"] as Dictionary).is_empty():
				by_key[String(d.get("key", ""))] = d["sponsors"]
	for c: Club in w.clubs:
		var sp: Variant = by_key.get(c.key, Overrides.club(c.key).get("sponsors", null))
		if not (sp is Dictionary) or sp.is_empty():
			continue
		for slot in sp:
			if not SponsorManager.KIT_KEYS.has(slot) or not (sp[slot] is Dictionary):
				continue
			var s: Dictionary = sp[slot]
			if String(s.get("n", "")) == "":
				continue
			var cat := BrandCatalog.find(String(s["n"]))
			var yrs := maxi(1, int(s.get("yrs", 3)))
			var base := float(FinanceManager.sponsor_income(c)) * SponsorManager._share(slot)
			c.sponsors[slot] = {"n": String(s["n"]), "c": String(s.get("c", cat.get("c", c.color2))),
				"t": String(s.get("t", cat.get("t", c.color1))), "logo": String(s.get("logo", cat.get("logo", ""))),
				"m": String(s.get("m", cat.get("m", ""))), "s": String(s.get("s", "material" if slot == "fornecedor" else "")),
				"yrs": yrs, "v": int(s.get("v", Valuation.round_value(base))), "b": 0,
				"tb": SponsorManager.TITLE_BONUS, "qb": SponsorManager.CONT_BONUS, "rc": SponsorManager.RELEGATION_CUT,
				"y": w.year + yrs - 1, "y0": w.year}
		SponsorManager.apply_income(w, c)
		SponsorManager.apply_to_kits(c)
