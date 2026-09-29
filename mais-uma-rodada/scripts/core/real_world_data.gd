class_name RealWorldData
extends RefCounted
## Piloto factual datado, separado das estimativas de simulação. Não é uma licença comercial.
## Só se aplica durante a geração de uma carreira padrão nova; nunca converte saves em andamento.
const PATH := "res://data/world/real_roster_pilot.json"
const KEY := "real_roster_pilot_v1"
static var _pack: Dictionary = {}

static func pack() -> Dictionary:
	if _pack.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary: _pack = data
	return _pack

static func identity(w: GameWorld, pid: int) -> Dictionary:
	return w.stats.get(KEY,{}).get("players",{}).get(str(pid),{})

static func apply_new_world(w: GameWorld) -> void:
	if w.world_type != "padrao" or w.stats.has(KEY): return
	var marks := {"as_of":String(pack().get("as_of","")),"players":{},"clubs":[],"license":"not_obtained"}
	w.stats[KEY] = marks
	var by_club := {}
	for e: Dictionary in pack().get("players",[]):
		var key := String(e["club"])
		if not by_club.has(key): by_club[key]=[]
		by_club[key].append(e)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5192026 # não consome o gerador do mundo
	var names := WorldGenerator.used_names_of(w)
	for key: String in by_club:
		var club := w.club_by_key(key)
		if club == null: continue
		var available: Array = w.squad(club).duplicate()
		var added: Array = []
		for e: Dictionary in by_club[key]:
			var pos := PlayerMods.pos_from(e["pos"])
			var best := -1
			var score := INF
			for i in available.size():
				var candidate: Player = available[i]
				var d := absf(candidate.overall-float(e["ovr_target"])) + (0.0 if candidate.position==pos else 100.0)
				if d<score: score=d; best=i
			var p: Player
			if best>=0:
				p=available.pop_at(best)
			else:
				p=PlayerGenerator.create(w,rng,pos,float(e["ovr_target"]),w.year-int(e["birth"]),String(e["nat"]),club.city,names)
				PlayerGenerator.sign_to_club(w,rng,p,club,true)
			# Apaga a identidade procedural antes de preencher os campos factuais.
			p.nickname=""
			p.secondary=[]
			p.eth=1 # geometria neutra; tons são escolhas visuais explícitas, não dados raciais
			PlayerMods.fill(w,p,e)
			PlayerMods.scale_to(p,int(e["ovr_target"]))
			p.potential=maxi(p.overall,int(e["pot"]))
			p.consistency=12
			p.injury_prone=10
			p.set_traits([])
			p.hidden={}
			p.signature=""
			p.heart=-1
			p.heart_known=false
			p.transfer_listed=false
			p.asking_price=0
			p.clauses={}
			p.loan={}
			p.joined_year=w.year
			p.contract_end=w.year+2 # estimativa explicitamente identificada
			p.wage=Valuation.round_wage(Valuation.base_wage(p.ovr_f)*float(club.league_cfg().get("wage",1.0)))
			Valuation.update_value(p,w.year)
			marks["players"][str(p.id)]={"uid":e["uid"],"source":e["source"],"as_of":e["checked_on"],"birth_date":e["birth_date"],"club_key":key,"known":e["known"],"estimated_fields":e["estimated_fields"]}
			added.append(p.id)
		# Mantém o resto do universo: sobras procedurais viram livres, não membros falsos do elenco real.
		for p: Player in available:
			club.player_ids.erase(p.id)
			p.club_id=-1
			p.contract_end=w.year
			p.wage=0
		club.player_ids=added
		PlayerGenerator.assign_statuses(w,club)
		marks["clubs"].append(key)
	w._free_agents_dirty=true

static func apply_new_coaches(w: GameWorld) -> void:
	if not w.stats.has(KEY): return
	for e: Dictionary in pack().get("coaches",[]):
		var c := w.club_by_key(String(e["club"]))
		if c==null: continue
		var co: Dictionary = w.people.get("coaches",{}).get(c.id,{})
		if co.is_empty(): continue
		co["n"]=e["name"]
		co["nat"]=e["nat"]
		co["by"]=e["birth"]
		co["since"]=w.year # registro simulado começa aqui; não inventa resultados anteriores
		co["st"]=e["style_estimate"]
		co["sk"]=e["skill_estimate"]
		co["rep"]=e["rep_estimate"]
		co["real_source"]=e["source"]
		co["real_as_of"]=pack()["as_of"]
		co["w"]=0; co["d"]=0; co["l"]=0
		co["look"]={"hs":2,"bd":1,"sk":2,"hc":1} if String(e["nat"])=="POR" else {"hs":1,"bd":0,"sk":1,"hc":9}

static func is_real(w: GameWorld, pid: int) -> bool:
	return not identity(w,pid).is_empty()

static func description() -> String:
	return "Piloto com 52 jogadores e 2 técnicos de Palmeiras e Barcelona, consultado em 29/09/2026. Demais elencos são procedurais. Atributos, potencial, contratos e aparência são estimativas do jogo. Não é um produto oficialmente licenciado."
