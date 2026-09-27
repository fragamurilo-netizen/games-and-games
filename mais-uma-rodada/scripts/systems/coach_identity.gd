class_name CoachIdentity
extends RefCounted
## O jogo lembra o treinador do usuário: registra o que ele realmente faz (formações, estilo,
## contratações, vendas, base, clubes e países) e transforma isso em reputação.
## Nada é escolhido num menu: os títulos ("Especialista em jovens", "Técnico de pressão alta",
## "Reconstrutor"...) aparecem quando o histórico sustenta, e somem se o jeito de trabalhar mudar.
##
## Memória em world.manager["mem"] (salva junto com o perfil do treinador):
##   g            jogos registrados
##   form         {formação: jogos}
##   ment/sty/pres/line  contagem de jogos por mentalidade, estilo, pressão e linha
##   xi, xi_u21, xi_31   titulares escalados (total, até 21 anos, 31 ou mais)
##   buy, buy_u21, buy_31, buy_free, buy_fee, buy_val, buy_dom, buy_nat{país: n}
##   sell, sell_paid, sell_age, sell_fee, sell_val
##   promo        garotos promovidos da base
##   jobs         [{c, n, nat, from, to, rep0, rep1}] clubes treinados
##   seasons      [{y, c, nat, pos, champ, promo, rel, cups}] temporadas completas
##   titles       {id: ano em que a imprensa passou a usar o título}
##
## Efeitos (pequenos e explícitos, só como consequência do histórico):
##   - jogadores do perfil que você costuma apostar ficam mais abertos a assinar;
##   - clubes cujo perfil combina com o seu (e países onde você já trabalhou) lembram de você
##     quando procuram um técnico;
##   - a imprensa anuncia cada título novo, com os números que o justificam.

const MIN_GAMES := 15
const MIN_BUYS := 5
const MIN_SALES := 4
const SHOWN := 3

## id → nome, texto curto e o que o título muda no jogo.
const TITLES := {
	"jovens": {"name": "Especialista em jovens", "fx": "Garotos de até 21 anos gostam mais de assinar com você."},
	"formador": {"name": "Formador de talentos", "fx": "Garotos de até 21 anos gostam mais de assinar com você; clubes formadores lembram do seu nome."},
	"veteranos": {"name": "Amigo dos veteranos", "fx": "Jogadores de 30 anos ou mais aceitam mais fácil vir para o seu time."},
	"pechincha": {"name": "Caçador de pechinchas", "fx": "Clubes vendedores e sem dinheiro procuram você quando trocam de técnico."},
	"gastador": {"name": "Contrata sem olhar o preço", "fx": "Clubes ricos procuram você; a diretoria sabe que você vai pedir dinheiro."},
	"negociante": {"name": "Negociante", "fx": "Clubes vendedores procuram você quando trocam de técnico."},
	"local": {"name": "Aposta no mercado local", "fx": "Jogadores do país do clube aceitam mais fácil vir para o seu time."},
	"global": {"name": "Olheiro do mundo", "fx": "Jogadores estrangeiros aceitam mais fácil vir para o seu time."},
	"pressao": {"name": "Técnico de pressão alta", "fx": "Clubes que jogam com pressão lembram do seu nome."},
	"posse": {"name": "Adepto da posse de bola", "fx": "Clubes de jogo de posição e toque lembram do seu nome."},
	"contragolpe": {"name": "Mestre do contra-ataque", "fx": "Clubes de contra-ataque e transição lembram do seu nome."},
	"retranca": {"name": "Retranqueiro", "fx": "Clubes defensivos e pragmáticos lembram do seu nome."},
	"ofensivo": {"name": "Técnico ofensivo", "fx": "Clubes de futebol arte e pelas pontas lembram do seu nome."},
	"fiel": {"name": "Fiel ao %s", "fx": "Seu time conhece o sistema de cor."},
	"camaleao": {"name": "Camaleão tático", "fx": "Você muda de sistema conforme o adversário."},
	"reconstrutor": {"name": "Reconstrutor", "fx": "Clubes em crise e tradicionais em queda procuram você."},
	"acessos": {"name": "Especialista em acessos", "fx": "Clubes de divisões de baixo lembram do seu nome."},
	"copas": {"name": "Rei de copas", "fx": "A imprensa aposta em você nos mata-matas."},
	"vencedor": {"name": "Colecionador de títulos", "fx": "Clubes grandes lembram do seu nome."},
	"mundo": {"name": "Cidadão do mundo", "fx": "Clubes de qualquer país consideram você."},
	"simbolo": {"name": "Homem de um clube só", "fx": "A torcida do clube onde você fez história nunca esquece."},
}

## Arquétipos e filosofias de clube que combinam com cada título (ofertas de emprego).
const MATCH_ARCH := {
	"jovens": ["formador", "projeto_jovem", "base_sem_dinheiro"],
	"formador": ["formador", "projeto_jovem", "base_sem_dinheiro"],
	"veteranos": ["veteranos", "rico_promovido"],
	"pechincha": ["vendedor", "base_sem_dinheiro", "cidade_pequena", "azarao"],
	"gastador": ["rico_promovido", "gigante_endividado", "dinheiro_gestao_ruim"],
	"negociante": ["vendedor", "formador"],
	"reconstrutor": ["tradicional_decadente", "gigante_endividado", "torcida_impaciente"],
	"acessos": ["azarao", "cidade_pequena", "rico_promovido"],
	"vencedor": ["tradicional_equilibrado", "estadio_enorme", "torcida_impaciente"],
	"retranca": ["defensivo"],
}
const MATCH_PHIL := {
	"pressao": ["pressao", "vertical"],
	"posse": ["posicional", "toque"],
	"contragolpe": ["contragolpe", "vertical", "direto"],
	"retranca": ["ferrolho", "pragmatico"],
	"ofensivo": ["toque", "pontas"],
}


# --- Memória ----------------------------------------------------------------

static func mem(world: GameWorld) -> Dictionary:
	var m := ManagerProfile.data(world)
	if not m.has("mem"):
		m["mem"] = {}
	var d: Dictionary = m["mem"]
	for k in ["g", "xi", "xi_u21", "xi_31", "buy", "buy_u21", "buy_31", "buy_free", "buy_fee", "buy_val", "buy_dom",
			"sell", "sell_paid", "sell_age", "sell_fee", "sell_val", "promo"]:
		if not d.has(k):
			d[k] = 0
	for k in ["form", "buy_nat", "titles"]:
		if not d.has(k):
			d[k] = {}
	for k in ["jobs", "seasons"]:
		if not d.has(k):
			d[k] = []
	if not d.has("ment"):
		d["ment"] = [0, 0, 0, 0, 0]
		d["sty"] = [0, 0, 0, 0, 0, 0]
		d["pres"] = [0, 0, 0]
		d["line"] = [0, 0, 0]
	if (d["jobs"] as Array).is_empty() and world.has_user():
		_open_job(world, d, world.user_club())
	return d


static func _open_job(world: GameWorld, d: Dictionary, c: Club) -> void:
	d["jobs"].append({"c": c.id, "n": c.short_name, "nat": c.nation, "from": world.year, "to": 0, "rep0": c.reputation, "rep1": c.reputation})


static func _add(d: Dictionary, k: String, v: float = 1.0) -> void:
	d[k] = d.get(k, 0) + v


static func _inc(arr: Array, i: int) -> void:
	if i >= 0 and i < arr.size():
		arr[i] = int(arr[i]) + 1


## Um jogo oficial do usuário: formação, tática e idade dos titulares.
static func on_match(world: GameWorld, club: Club) -> void:
	if not world.has_user() or club.sheet == null:
		return
	var d := mem(world)
	var s := club.sheet
	_add(d, "g")
	var form: Dictionary = d["form"]
	form[s.formation] = int(form.get(s.formation, 0)) + 1
	_inc(d["ment"], s.mentality)
	_inc(d["sty"], s.style)
	_inc(d["pres"], s.pressing)
	_inc(d["line"], s.line)
	for pid in s.starters:
		var p := world.player(int(pid))
		if p == null:
			continue
		var a := p.age(world.year)
		_add(d, "xi")
		if a <= 21:
			_add(d, "xi_u21")
		elif a >= 31:
			_add(d, "xi_31")


## Qualquer transferência envolvendo o clube do usuário (chamado por TransferManager).
static func on_transfer(world: GameWorld, p: Player, buyer: Club, seller: Club, fee: int) -> void:
	if not world.has_user():
		return
	var d := mem(world)
	var a := p.age(world.year)
	if world.is_user_club(buyer.id):
		_add(d, "buy")
		if a <= 21:
			_add(d, "buy_u21")
		elif a >= 31:
			_add(d, "buy_31")
		if fee <= 0:
			_add(d, "buy_free")
		else:
			_add(d, "buy_fee", fee)
			_add(d, "buy_val", maxi(p.value, 1))
		if p.nationality == buyer.nation:
			_add(d, "buy_dom")
		var bn: Dictionary = d["buy_nat"]
		bn[p.nationality] = int(bn.get(p.nationality, 0)) + 1
	elif seller != null and world.is_user_club(seller.id):
		_add(d, "sell")
		if fee > 0:
			_add(d, "sell_paid")
			_add(d, "sell_age", a)
			_add(d, "sell_fee", fee)
			_add(d, "sell_val", maxi(p.value, 1))


static func on_promote(world: GameWorld) -> void:
	if world.has_user():
		_add(mem(world), "promo")


## Troca de clube (demissão seguida de emprego novo).
static func on_new_job(world: GameWorld, old_club: Club, new_club: Club) -> void:
	var d := mem(world)
	var jobs: Array = d["jobs"]
	if not jobs.is_empty():
		var last: Dictionary = jobs[jobs.size() - 1]
		if int(last["to"]) == 0:
			last["to"] = world.year
			if old_club != null:
				last["rep1"] = old_club.reputation
	_open_job(world, d, new_club)


## Fim de temporada do usuário: guarda o resumo e anuncia títulos novos. Retorna os ids novos.
static func on_season_end(world: GameWorld, user: Dictionary, rep_before: float) -> Array:
	if not world.has_user():
		return []
	var d := mem(world)
	var c := world.user_club()
	var cups := 0
	for cu in user.get("cups", []):
		if cu.get("champion", false):
			cups += 1
	d["seasons"].append({"y": world.year, "c": c.id, "n": c.short_name, "nat": c.nation, "pos": int(user.get("pos", 0)),
		"champ": bool(user.get("champion", false)), "promo": bool(user.get("promoted", false)),
		"rel": bool(user.get("relegated", false)), "cups": cups, "rep0": rep_before})
	var jobs: Array = d["jobs"]
	if not jobs.is_empty():
		jobs[jobs.size() - 1]["rep1"] = c.reputation
	var earned: Dictionary = d["titles"]
	var fresh: Array = []
	var names: Array = []
	var lead: Dictionary = {}
	for t in titles(world):
		if earned.has(t["id"]):
			continue
		earned[t["id"]] = world.year
		fresh.append(t["id"])
		if lead.is_empty():
			lead = t
		else:
			names.append("\"%s\"" % t["name"])
	# Uma manchete por temporada: o título mais forte; os outros entram no texto.
	if not lead.is_empty():
		var body := "%s." % lead["why"]
		if not names.is_empty():
			body += " Também já dizem: %s." % ", ".join(names)
		NewsManager.post_raw(world, "A imprensa já chama %s de \"%s\"" % [world.manager_name, lead["name"]], body, c.id, -1, NewsEvent.IMP_HIGH, "clube")
	return fresh


# --- Leitura: hábitos e títulos --------------------------------------------

static func _share(arr: Array, idx: Array, games: int) -> float:
	var n := 0
	for i in idx:
		n += int(arr[i])
	return float(n) / maxf(1.0, float(games))


static func top_formation(d: Dictionary) -> Array:
	var best := ""
	var n := 0
	for f in d["form"]:
		if int(d["form"][f]) > n:
			n = int(d["form"][f])
			best = String(f)
	return [best, n]


static func _pct(x: float) -> String:
	return "%d%%" % roundi(x * 100.0)


## Títulos que o histórico sustenta hoje, do mais forte para o mais fraco.
## Cada um: {id, name, why, fx, score}.
static func titles(world: GameWorld) -> Array:
	var d := mem(world)
	var out: Array = []
	var g := int(d["g"])
	var buys := int(d["buy"])
	var add := func(id: String, score: float, why: String, fmt: String = "") -> void:
		var name := String(TITLES[id]["name"])
		if fmt != "":
			name = name % fmt
		out.append({"id": id, "name": name, "why": why, "fx": String(TITLES[id]["fx"]), "score": score})
	# Tática
	if g >= MIN_GAMES:
		var tf := top_formation(d)
		var fs := float(tf[1]) / g
		if fs >= 0.75:
			add.call("fiel", fs, "Usou o %s em %s dos %d jogos" % [tf[0], _pct(fs), g], String(tf[0]))
		elif (d["form"] as Dictionary).size() >= 4 and fs <= 0.4:
			add.call("camaleao", 1.0 - fs, "Já usou %d formações diferentes e nenhuma passou de %s dos jogos" % [(d["form"] as Dictionary).size(), _pct(fs)])
		var pr := maxf(_share(d["pres"], [2], g), _share(d["sty"], [TeamSheet.STYLE_PRESSAO], g))
		if pr >= 0.6:
			add.call("pressao", pr, "Pressionou alto em %s dos jogos" % _pct(pr))
		var po := _share(d["sty"], [TeamSheet.STYLE_POSSE], g)
		if po >= 0.6:
			add.call("posse", po, "Jogou com posse de bola em %s dos jogos" % _pct(po))
		var ct := _share(d["sty"], [TeamSheet.STYLE_CONTRA], g)
		if ct >= 0.6:
			add.call("contragolpe", ct, "Armou o time no contra-ataque em %s dos jogos" % _pct(ct))
		var rt := _share(d["ment"], [0, 1], g)
		var of := _share(d["ment"], [3, 4], g)
		if rt >= 0.6:
			add.call("retranca", rt, "Entrou defensivo em %s dos jogos" % _pct(rt))
		elif of >= 0.6:
			add.call("ofensivo", of, "Entrou para atacar em %s dos jogos" % _pct(of))
	# Mercado
	if buys >= MIN_BUYS:
		var yu := float(d["buy_u21"]) / buys
		if yu >= 0.5:
			add.call("jovens", yu + 0.2, "%d dos %d reforços chegaram com até 21 anos" % [int(d["buy_u21"]), buys])
		var ve := float(d["buy_31"]) / buys
		if ve >= 0.4:
			add.call("veteranos", ve + 0.2, "%d dos %d reforços tinham 31 anos ou mais" % [int(d["buy_31"]), buys])
		var paid := buys - int(d["buy_free"])
		var ratio := float(d["buy_fee"]) / maxf(1.0, float(d["buy_val"]))
		var free := float(d["buy_free"]) / buys
		if free >= 0.5 or (paid >= 3 and ratio <= 0.85):
			var why := "%d dos %d reforços vieram de graça" % [int(d["buy_free"]), buys] if free >= 0.5 else "Paga em média %s do valor de mercado" % _pct(ratio)
			add.call("pechincha", maxf(free, 1.0 - ratio + 0.5), why)
		elif paid >= 3 and ratio >= 1.25:
			add.call("gastador", ratio - 0.5, "Paga em média %s do valor de mercado" % _pct(ratio))
		var dom := float(d["buy_dom"]) / buys
		var nats := (d["buy_nat"] as Dictionary).size()
		if dom >= 0.8 and buys >= 8:
			add.call("local", dom, "%s dos reforços são do país do clube" % _pct(dom))
		elif nats >= 5 and dom <= 0.4:
			add.call("global", 0.5 + nats * 0.05, "Contratou jogadores de %d países" % nats)
	if int(d["sell_paid"]) >= MIN_SALES:
		var profit := float(d["sell_fee"]) / maxf(1.0, float(d["sell_val"]))
		if profit >= 1.1 and int(d["sell_fee"]) >= 5_000_000:
			add.call("negociante", profit - 0.3, "Vendeu %d jogadores por %s, %s do valor de mercado" % [int(d["sell_paid"]), Fmt.money(int(d["sell_fee"])), _pct(profit)])
	# Base
	var promo := int(d["promo"])
	var xu := float(d["xi_u21"]) / maxf(1.0, float(d["xi"]))
	if promo >= 5 or (g >= MIN_GAMES and xu >= 0.3 and promo >= 2):
		add.call("formador", 0.6 + promo * 0.04 + xu, "Promoveu %d garotos da base; %s dos titulares tinham até 21 anos" % [promo, _pct(xu)])
	# Carreira
	var ms := world.manager_stats
	var best_rise := 0.0
	var rise_club := ""
	for j: Dictionary in d["jobs"]:
		var yrs := (int(j["to"]) if int(j["to"]) > 0 else world.year) - int(j["from"])
		var rise := float(j.get("rep1", 0.0)) - float(j.get("rep0", 0.0))
		if yrs >= 2 and rise > best_rise:
			best_rise = rise
			rise_club = String(j["n"])
	if best_rise >= 10.0:
		add.call("reconstrutor", 0.6 + best_rise / 40.0, "Levou o %s de %d para %d de reputação" % [rise_club, roundi(_job_of(d, rise_club)["rep0"]), roundi(_job_of(d, rise_club)["rep1"])])
	if int(ms.get("promotions", 0)) >= 2:
		add.call("acessos", 0.6 + int(ms["promotions"]) * 0.1, "%d acessos na carreira" % int(ms["promotions"]))
	var cup_t := int(ms.get("cup_titles", 0))
	var league_t := int(ms.get("titles", 0)) - cup_t
	if cup_t >= 2 and cup_t > league_t:
		add.call("copas", 0.6 + cup_t * 0.1, "%d copas levantadas, mais do que ligas" % cup_t)
	if int(ms.get("titles", 0)) >= 5:
		add.call("vencedor", 0.7 + int(ms["titles"]) * 0.05, "%d títulos na carreira" % int(ms["titles"]))
	var countries := worked_countries(world)
	if countries.size() >= 3:
		add.call("mundo", 0.5 + countries.size() * 0.1, "Trabalhou em %d países" % countries.size())
	for j: Dictionary in d["jobs"]:
		var yrs := (int(j["to"]) if int(j["to"]) > 0 else world.year) - int(j["from"])
		if yrs >= 8:
			add.call("simbolo", 0.6 + yrs * 0.03, "%d temporadas no comando do %s" % [yrs, String(j["n"])])
			break
	out.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	return out


static func _job_of(d: Dictionary, club_name: String) -> Dictionary:
	for j: Dictionary in d["jobs"]:
		if String(j["n"]) == club_name:
			return j
	return {"rep0": 0.0, "rep1": 0.0}


static func has_title(world: GameWorld, id: String) -> bool:
	if not world.has_user():
		return false
	for t in titles(world):
		if t["id"] == id:
			return true
	return false


## Título principal (o mais forte) ou "" se o histórico ainda é curto.
static func headline(world: GameWorld) -> String:
	if not world.has_user():
		return ""
	var t := titles(world)
	return String(t[0]["name"]) if not t.is_empty() else ""


## Países onde trabalhou → temporadas completas (o emprego atual conta ao menos uma).
static func worked_countries(world: GameWorld) -> Dictionary:
	var d := mem(world)
	var out := {}
	for s: Dictionary in d["seasons"]:
		out[s["nat"]] = int(out.get(s["nat"], 0)) + 1
	for j: Dictionary in d["jobs"]:
		if not out.has(j["nat"]):
			out[j["nat"]] = 0
	return out


## Frases do que o jogo aprendeu sobre você, com números.
static func habits(world: GameWorld) -> Array:
	var d := mem(world)
	var out: Array = []
	var g := int(d["g"])
	if g >= 5:
		var tf := top_formation(d)
		out.append("Prefere o %s (%s dos %d jogos)" % [tf[0], _pct(float(tf[1]) / g), g])
		var sty: Array = d["sty"]
		var bi := 0
		for i in sty.size():
			if int(sty[i]) > int(sty[bi]):
				bi = i
		var names: Array = DatabaseManager.tactics().get("styles", [])
		if bi < names.size():
			out.append("Estilo mais usado: %s (%s)" % [String(names[bi].get("name", "")).to_lower(), _pct(float(sty[bi]) / g)])
		if int(d["xi"]) > 0:
			out.append("%s dos titulares tinham até 21 anos" % _pct(float(d["xi_u21"]) / float(d["xi"])))
	var buys := int(d["buy"])
	if buys > 0:
		out.append("%d reforços: %d com até 21 anos, %d de graça" % [buys, int(d["buy_u21"]), int(d["buy_free"])])
		if int(d["buy_val"]) > 0:
			var r := float(d["buy_fee"]) / float(d["buy_val"])
			out.append("Paga em média %s do valor de mercado%s" % [_pct(r), " (raramente paga caro)" if r <= 0.9 else (" (paga o que pedem)" if r >= 1.2 else "")])
		var nats := (d["buy_nat"] as Dictionary).size()
		if nats >= 2:
			out.append("Contratou jogadores de %d países" % nats)
	if int(d["sell_paid"]) > 0:
		out.append("Vende jogadores, em média, aos %d anos" % roundi(float(d["sell_age"]) / float(d["sell_paid"])))
	if int(d["promo"]) > 0:
		out.append("Promoveu %d %s da base" % [int(d["promo"]), "garoto" if int(d["promo"]) == 1 else "garotos"])
	var wc := worked_countries(world)
	if not wc.is_empty():
		var parts: Array = []
		var keys := wc.keys()
		keys.sort_custom(func(a, b): return int(wc[a]) > int(wc[b]))
		for k in keys:
			var n := int(wc[k])
			parts.append("%s (%d %s)" % [DatabaseManager.nation_name(String(k)), n, "temporada" if n == 1 else "temporadas"] if n > 0 else DatabaseManager.nation_name(String(k)))
		out.append("Trabalhou em: %s" % ", ".join(parts))
	return out


# --- Efeitos ----------------------------------------------------------------

## Interesse extra de um jogador em assinar com o clube do usuário.
static func interest_delta(world: GameWorld, p: Player, buyer: Club) -> float:
	if not world.has_user() or not world.is_user_club(buyer.id):
		return 0.0
	var ids := {}
	for t in titles(world):
		ids[t["id"]] = true
	var v := 0.0
	var a := p.age(world.year)
	if a <= 21 and (ids.has("jovens") or ids.has("formador")):
		v += 0.06
	if a >= 30 and ids.has("veteranos"):
		v += 0.06
	if ids.has("local") and p.nationality == buyer.nation:
		v += 0.04
	if ids.has("global") and p.nationality != buyer.nation:
		v += 0.04
	return v


## O que os clubes sabem de você na hora de procurar um técnico (calcule uma vez por busca).
static func job_context(world: GameWorld) -> Dictionary:
	if not world.has_user():
		return {}
	var ids: Array = []
	for t in titles(world):
		ids.append(t["id"])
	return {"ids": ids, "nat": worked_countries(world)}


## Bônus de um clube na lista de ofertas de emprego: perfil que combina e países conhecidos.
static func job_score(ctx: Dictionary, c: Club) -> float:
	if ctx.is_empty():
		return 0.0
	var v := 0.0
	for id: String in ctx["ids"]:
		if c.archetype in MATCH_ARCH.get(id, []):
			v += 6.0
		if c.philosophy in MATCH_PHIL.get(id, []):
			v += 5.0
		if id == "vencedor" and c.reputation >= 75.0:
			v += 4.0
	if (ctx["nat"] as Dictionary).has(c.nation):
		v += 3.0
	return v
