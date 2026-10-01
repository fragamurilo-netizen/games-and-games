class_name Media
extends RefCounted
## Media & Narrative Engine (Game Design Bible §10; MMA Bible §27).
## Notícia = consequência de estado do mundo. Cada tópico em
## content/news_templates.json declara veículo, editoria, peso e textos; o
## código só publica quando o fato aconteceu (luta, contrato, card, ranking).
## Cada fato tem uma chave estável (`NewsItem.key`): a mesma notícia nunca sai
## duas vezes. A variante de texto é escolhida pelo hash dessa chave, não por
## world.rng — manchete é cosmética e não pode alterar o futuro da simulação.

const METHODS := {"ko_tko": ["nocaute", "nocaute técnico"], "submission": ["finalização", "finalização"], "decision": ["decisão", "decisão"], "dq": ["desclassificação", "desclassificação"], "nc": ["sem resultado", "luta sem resultado"], "draw": ["empate", "empate"]}
const DETAILS := {"unanimous": "unânime", "split": "dividida", "majority": "majoritária"}

static var _cfg: Dictionary = {}
static var _outlets: Dictionary = {}
static var _divisions: Dictionary = {}

var _keys := {}
var _indexed: WorldState


static func config() -> Dictionary:
	if _cfg.is_empty():
		_cfg = ContentDB.load_json("news_templates.json")
		for o: Dictionary in ContentDB.load_json("media_outlets.json"):
			_outlets[o.id] = o
		for d: Dictionary in ContentDB.load_json("weight_classes.json"):
			_divisions[d.id] = "%s %s" % [d.name, "feminino" if d.sex == "F" else "masculino"]
	return _cfg


static func outlet(id: String) -> Dictionary:
	config()
	return _outlets.get(id, {"id": id, "name": "Redação", "reach": 40})


static func division_name(id: String) -> String:
	config()
	return _divisions.get(id, id)


func publish(world: WorldState, topic: String, facts: Array, entity_ids: Array) -> NewsItem:
	var item := _make(world, topic, "", facts, entity_ids)
	_commit(world, item)
	return item


## Publica um tópico de news_templates.json a partir de fatos já ocorridos.
## Devolve null se a chave já foi noticiada ou o tópico não existe.
func story(world: WorldState, topic: String, key: String, vars: Dictionary, entity_ids: Array, facts: Array = []) -> NewsItem:
	if has_story(world, key):
		return null
	var t: Dictionary = config().topics.get(topic, {})
	if not t.has("headlines"):
		return null
	var item := _make(world, topic, key, facts, entity_ids)
	item.channel = str(t.get("channel", "site"))
	item.author_id = str(vars.get("_author", ""))
	item.headline = _variant(t.headlines, key).format(vars)
	item.body = _variant(t.get("bodies", [""]), key + ":body").format(vars)
	var fame := 0.0
	for id: String in entity_ids:
		var f: Fighter = world.fighters.get(id)
		if f:
			fame = maxf(fame, _fame(f))
	item.reach = int(float(outlet(item.outlet_id).get("reach", 40)) * (0.5 + 0.25 * item.importance) + fame)
	if item.channel == "social":
		item.reach = _engagement(world, item.author_id, key)
	_commit(world, item)
	return item


func has_story(world: WorldState, key: String) -> bool:
	if key.is_empty():
		return false
	if _indexed != world:
		_indexed = world
		_keys.clear()
		for n: NewsItem in world.news.values():
			if not n.key.is_empty():
				_keys[n.key] = true
	return _keys.has(key)


## Marca notícias como lidas (estado de leitura do jogador, não regra de jogo).
static func mark_read(world: WorldState, ids: Array) -> void:
	for id: String in ids:
		var n: NewsItem = world.news.get(id)
		if n:
			n.read = true


static func unread_count(world: WorldState) -> int:
	return world.news.values().filter(func(n: NewsItem): return not n.read).size()


## Uma notícia interessa ao jogador quando cita a organização dele ou um
## atleta do elenco dele.
static func involves_player(world: WorldState, item: NewsItem) -> bool:
	for id: String in item.entity_ids:
		if id == world.player_org_id:
			return true
		var f: Fighter = world.fighters.get(id)
		if f and f.organization_id == world.player_org_id:
			return true
		var ev: FightEvent = world.events.get(id)
		if ev and ev.organization_id == world.player_org_id:
			return true
	return false


## Varre o mundo procurando fatos ainda não noticiados: cards anunciados ou
## cancelados, contratos, agentes livres e trocas de número 1 nos rankings.
## Chamado uma vez por dia pelo WorldSim.
func scan_triggers(world: WorldState) -> Array:
	var cfg := config()
	var out: Array = []
	var lookback := int(cfg.lookback_days)
	for ev: FightEvent in world.events.values():
		if ev.status == "announced" and not ev.fight_ids.is_empty():
			_add(out, _announce(world, ev))
		elif ev.status == "cancelled" and has_story(world, "announce:" + ev.id) and GameDate.days_between(world.date, ev.date) >= -lookback:
			var org: Organization = world.organizations.get(ev.organization_id)
			_add(out, story(world, "event_cancelled", "cancel:" + ev.id, {"org": org.name if org else "", "event": ev.name, "city": ev.city, "date": GameDate.format(ev.date)}, [ev.id, ev.organization_id]))
	var ids: Array = world.contracts.keys()
	for i in range(ids.size() - 1, -1, -1):
		var c: Contract = world.contracts[ids[i]]
		if GameDate.days_between(c.signed_on, world.date) > lookback:
			break
		_add(out, _signing(world, c))
	for f: Fighter in world.fighters.values():
		if f.retired or not f.organization_id.is_empty() or f.contract_id.is_empty():
			continue
		var c: Contract = world.contracts.get(f.contract_id)
		if c == null or c.active or not (c.organization_id == world.player_org_id or _notable(world, f)):
			continue
		var org: Organization = world.organizations.get(c.organization_id)
		_add(out, story(world, "free_agent", "free:" + c.id, _fighter_vars(f).merged({"org": org.name if org else ""}), [f.id, c.organization_id]))
		_add(out, story(world, "social_free_agent", "post_free:" + c.id, _fighter_vars(f).merged({"_author": f.id}), [f.id, c.organization_id]))
	for key: String in world.rankings:
		var parts := key.split(":")
		if parts[0] != world.player_org_id and parts[0] != Rankings.WCI_ORG_ID:
			continue
		var history: Array = world.rankings[key]
		if history.size() < 2:
			continue
		var now: Ranking = history[-1]
		var before: Ranking = history[-2]
		if now.entries.is_empty() or before.entries.is_empty() or now.entries[0] == before.entries[0]:
			continue
		if GameDate.days_between(now.snapshot_date, world.date) > lookback:
			continue
		var leader: Fighter = world.fighters.get(now.entries[0])
		var previous: Fighter = world.fighters.get(before.entries[0])
		if leader == null or previous == null:
			continue
		var label: String = "World Combat Index" if parts[0] == Rankings.WCI_ORG_ID else world.organizations[parts[0]].short_name
		var top_vars := _fighter_vars(leader).merged({"ranking": label, "previous": previous.display_name(), "previous_handle": handle(world, previous.id), "_author": leader.id})
		_add(out, story(world, "new_number_one", "top:" + now.id, top_vars, [leader.id, parts[0]]))
		if parts[0] == Rankings.WCI_ORG_ID:
			_add(out, story(world, "social_number_one", "post_top:" + now.id, top_vars, [leader.id, previous.id]))
	return out


## Cobertura de uma noite concluída: resumo financeiro (existente) e as
## histórias das lutas. Idempotente: rodar de novo não repete notícia.
func event_report(world: WorldState, ev: FightEvent) -> NewsItem:
	if ev.status != "completed" or ev.actual.is_empty():
		return null
	var recap: NewsItem = null
	for existing: NewsItem in world.news.values():
		if existing.topic == "event_completed" and ev.id in existing.entity_ids:
			recap = existing
	if recap == null:
		recap = publish(world, "event_completed", [Reason.make("EVENT_COMPLETED", ev.fight_ids.size(), {"margin": ev.actual.margin})], [ev.id])
		recap.key = "event:" + ev.id
		_keys[recap.key] = true
		var template: Dictionary = ContentDB.load_json("career_tuning.json").story
		recap.headline = str(template.event_completed).format({"event": ev.name})
		recap.body = str(template.event_body).format({"bouts": ev.fight_ids.size(), "revenue": _number(int(ev.actual.revenue)), "margin": _number(int(ev.actual.margin))})
		recap.reach = int(outlet(recap.outlet_id).get("reach", 40))
		# Cobertura uma vez por noite: os cartéis mudam depois e uma segunda
		# leitura geraria marcos (invicto, sequência) que não eram fato na data.
		cover_event(world, ev)
	return recap


func cover_event(world: WorldState, ev: FightEvent) -> Array:
	var cfg := config()
	var out: Array = []
	var player := ev.organization_id == world.player_org_id
	var org: Organization = world.organizations.get(ev.organization_id)
	var fastest: Fight = null
	# Zebra: no máximo uma por noite, a de maior diferença de cartel.
	var upset: Fight = null
	var upset_gap := int(cfg.upset_record_gap) - 1
	for id: String in ev.fight_ids:
		var f: Fight = world.fights[id]
		if f.status != "completed" or f.winner_id.is_empty():
			continue
		var w: Fighter = world.fighters[f.winner_id]
		var l: Fighter = world.fighters[f.fighter_b_id if f.winner_id == f.fighter_a_id else f.fighter_a_id]
		var gap := _pre_diff(l, false) - _pre_diff(w, true)
		if gap > upset_gap:
			upset = f
			upset_gap = gap
	for i in ev.fight_ids.size():
		var fight: Fight = world.fights[ev.fight_ids[i]]
		if fight.status != "completed":
			continue
		var main := i == ev.fight_ids.size() - 1
		var featured := i >= ev.fight_ids.size() - 2
		var v := _fight_vars(world, ev, fight)
		var ids := [fight.fighter_a_id, fight.fighter_b_id, ev.organization_id]
		if fight == upset:
			_add(out, story(world, "upset", "upset:" + fight.id, v, ids))
		elif main:
			_add(out, story(world, "main_event_result" if not fight.winner_id.is_empty() else "main_event_draw", "main:" + fight.id, v, ids))
		if fight.winner_id.is_empty():
			continue
		var winner: Fighter = world.fighters[fight.winner_id]
		var loser: Fighter = world.fighters[fight.fighter_b_id if fight.winner_id == fight.fighter_a_id else fight.fighter_a_id]
		if fight.method == "decision" and fight.method_detail == "split" and (featured or player):
			_add(out, story(world, "split_decision", "split:" + fight.id, v, ids))
			_add(out, story(world, "social_fans_split", "fans_split:" + fight.id, v.merged({"_author": _fan_account(fight.id), "loser_handle": handle(world, loser.id)}), ids))
		if main or fight == upset or (player and featured):
			_social_fight(world, out, ev, fight, winner, loser, v, ids)
		if fight.method in ["ko_tko", "submission"] and not main:
			if fastest == null or _elapsed(fight) < _elapsed(fastest):
				fastest = fight
		var relevant := player or featured or _notable(world, winner)
		var streak := _streak(world, winner, true)
		var fv := _fighter_vars(winner).merged({"event": ev.name, "streak": streak})
		if streak == 3 and _finish_streak(world, winner, 3):
			_add(out, story(world, "new_star", "star:" + fight.id, fv, [winner.id, ev.organization_id]))
		elif winner.record.losses == 0 and int(winner.record.wins) in cfg.undefeated_milestones and relevant:
			_add(out, story(world, "undefeated", "unbeaten:" + fight.id, fv, [winner.id, ev.organization_id]))
		elif streak in cfg.streak_milestones and relevant:
			_add(out, story(world, "win_streak", "streak:" + fight.id, fv, [winner.id, ev.organization_id]))
		var losses := _streak(world, loser, false)
		if losses == int(cfg.losing_streak) and (loser.organization_id == world.player_org_id or _notable(world, loser)):
			_add(out, story(world, "losing_streak", "slump:" + fight.id, _fighter_vars(loser).merged({"event": ev.name, "streak": losses}), [loser.id, ev.organization_id]))
		if fight.method == "ko_tko" and player and not loser.medical_suspension_until.is_empty():
			var days := GameDate.days_between(ev.date, loser.medical_suspension_until)
			_add(out, story(world, "medical_suspension", "med:" + fight.id, _fighter_vars(loser).merged({"event": ev.name, "days": days, "until": GameDate.format(loser.medical_suspension_until)}), [loser.id, ev.organization_id]))
	if fastest and (player or ev.fight_ids.size() >= 6):
		_add(out, story(world, "finish_of_night", "fotn:" + ev.id, _fight_vars(world, ev, fastest), [fastest.winner_id, ev.organization_id]))
	if player and int(ev.actual.get("margin", 0)) < 0:
		_add(out, story(world, "event_loss", "loss:" + ev.id, {"event": ev.name, "org": org.name if org else "", "revenue": _money(int(ev.actual.get("revenue", 0))), "margin": _money(int(ev.actual.margin))}, [ev.id, ev.organization_id]))
	return out


func _announce(world: WorldState, ev: FightEvent) -> NewsItem:
	if has_story(world, "announce:" + ev.id):
		return null
	var main: Fight = world.fights.get(ev.fight_ids[-1])
	var org: Organization = world.organizations.get(ev.organization_id)
	if main == null or org == null:
		return null
	var a: Fighter = world.fighters[main.fighter_a_id]
	var b: Fighter = world.fighters[main.fighter_b_id]
	var vars := {"org": org.name, "event": ev.name, "city": ev.city, "date": GameDate.format(ev.date), "bouts": ev.fight_ids.size(), "a": a.display_name(), "b": b.display_name(), "a_record": a.record_string(), "b_record": b.record_string(), "division": division_name(main.division)}
	var item := story(world, "event_announced", "announce:" + ev.id, vars, [ev.id, ev.organization_id, a.id, b.id])
	story(world, "social_org_announce", "post_announce:" + ev.id, vars.merged({"_author": org.id, "a_handle": handle(world, a.id), "b_handle": handle(world, b.id)}), [ev.id, org.id, a.id, b.id])
	return item


func _signing(world: WorldState, c: Contract) -> NewsItem:
	# Contratos do dia zero são o elenco gerado com o mundo, não notícia.
	if has_story(world, "sign:" + c.id) or c.signed_on == GameDate.START:
		return null
	var f: Fighter = world.fighters.get(c.fighter_id)
	var org: Organization = world.organizations.get(c.organization_id)
	if f == null or org == null:
		return null
	var renewal := false
	for other: Contract in world.contracts.values():
		if other.id != c.id and other.fighter_id == c.fighter_id and other.organization_id == c.organization_id and GameDate.to_unix(other.signed_on) < GameDate.to_unix(c.signed_on):
			renewal = true
	var player := c.organization_id == world.player_org_id
	var topic := "renewal" if renewal else "signing_player" if player else "signing_rival"
	if (renewal or not player) and not _notable(world, f):
		return null
	var vars := _fighter_vars(f).merged({"org": org.name, "bouts": c.bouts_total, "org_handle": handle(world, org.id), "_author": f.id})
	var item := story(world, topic, "sign:" + c.id, vars, [f.id, org.id])
	story(world, "social_renewal" if renewal else "social_signing", "post_sign:" + c.id, vars, [f.id, org.id])
	return item


func _make(world: WorldState, topic: String, key: String, facts: Array, entity_ids: Array) -> NewsItem:
	var t: Dictionary = config().topics.get(topic, {})
	var item := NewsItem.new()
	item.id = world.new_id("news")
	item.created_at = world.date.duplicate()
	item.topic = topic
	item.key = key
	item.facts = facts
	item.entity_ids = entity_ids
	item.outlet_id = str(t.get("outlet", "out_fightwire"))
	item.category = str(t.get("category", "eventos"))
	item.importance = int(t.get("importance", 1))
	item.tone = str(outlet(item.outlet_id).get("role", "neutral"))
	return item


func _commit(world: WorldState, item: NewsItem) -> void:
	world.add("news", item)
	if not item.key.is_empty():
		has_story(world, item.key)
		_keys[item.key] = true
	# Busca o autoload em tempo de execução: ferramentas de linha de comando
	# (career_session, preview_fight) compilam este script antes dos autoloads.
	var tree:=Engine.get_main_loop() as SceneTree
	var bus:=tree.root.get_node_or_null("EventBus") if tree else null
	if bus:bus.news_published.emit(item.id)


static func _add(out: Array, item: NewsItem) -> void:
	if item:
		out.append(item)


static func _variant(options: Array, key: String) -> String:
	return str(options[absi(key.hash()) % options.size()]) if not options.is_empty() else ""


static func _fame(f: Fighter) -> float:
	var fame := 0.0
	for value in f.popularity_by_region.values():
		fame = maxf(fame, float(value))
	return fame


## Notável = popular ou entre os primeiros do World Combat Index (informação
## pública; nunca olha atributos ocultos).
func _notable(world: WorldState, f: Fighter) -> bool:
	var cfg := config()
	if _fame(f) >= float(cfg.notable_popularity):
		return true
	var history: Array = world.rankings.get(Rankings.key(Rankings.WCI_ORG_ID, f.division), [])
	return not history.is_empty() and f.id in history[-1].entries.slice(0, int(cfg.notable_rank))


## Saldo vitórias − derrotas antes da luta que acabou de acontecer.
static func _pre_diff(f: Fighter, won: bool) -> int:
	return int(f.record.wins) - int(f.record.losses) - (1 if won else -1)


static func _streak(world: WorldState, f: Fighter, wins: bool) -> int:
	var n := 0
	for i in range(f.fight_ids.size() - 1, -1, -1):
		var fight: Fight = world.fights.get(f.fight_ids[i])
		if fight == null or fight.status != "completed":
			continue
		if fight.winner_id.is_empty() or (fight.winner_id == f.id) != wins:
			break
		n += 1
	return n


static func _finish_streak(world: WorldState, f: Fighter, count: int) -> bool:
	var n := 0
	for i in range(f.fight_ids.size() - 1, -1, -1):
		var fight: Fight = world.fights.get(f.fight_ids[i])
		if fight == null or fight.status != "completed":
			continue
		if fight.winner_id != f.id or fight.method not in ["ko_tko", "submission"]:
			return false
		n += 1
		if n == count:
			return true
	return false


static func _elapsed(f: Fight) -> int:
	return (f.end_round - 1) * 300 + f.end_time_s


static func _number(value: int) -> String:
	var source := str(absi(value))
	var result := ""
	for i in source.length():
		if i > 0 and (source.length() - i) % 3 == 0:
			result += "."
		result += source[i]
	return ("−" if value < 0 else "") + result


static func _money(value: int) -> String:
	return ("−US$ " if value < 0 else "US$ ") + _number(absi(value))


static func _fighter_vars(f: Fighter) -> Dictionary:
	var female := f.sex == Fighter.Sex.FEMALE
	return {"fighter": f.display_name(), "record": f.record_string(), "division": division_name(f.division), "invicto": "invicta" if female else "invicto", "atleta": "a atleta" if female else "o atleta"}


func _fight_vars(world: WorldState, ev: FightEvent, fight: Fight) -> Dictionary:
	var a: Fighter = world.fighters[fight.fighter_a_id]
	var b: Fighter = world.fighters[fight.fighter_b_id]
	var winner: Fighter = world.fighters.get(fight.winner_id, a)
	var loser: Fighter = b if winner == a else a
	var method: Array = METHODS.get(fight.method, [fight.method, fight.method])
	var full := str(method[1])
	if fight.method == "decision" and DETAILS.has(fight.method_detail):
		full += " " + DETAILS[fight.method_detail]
	var won := not fight.winner_id.is_empty()
	var org: Organization = world.organizations.get(ev.organization_id)
	return {
		"event": ev.name, "org": org.name if org else "", "city": ev.city, "date": GameDate.format(ev.date),
		"a": a.display_name(), "b": b.display_name(),
		"winner": winner.display_name(), "loser": loser.display_name(),
		"winner_record": winner.record_string(), "loser_record": loser.record_string(),
		"winner_before": _record_before(winner, won), "loser_before": _record_before(loser, false) if won else loser.record_string(),
		"method": method[0], "method_full": full, "round": fight.end_round,
		"when": ("após %d rounds" % fight.end_round) if fight.method in ["decision", "draw"] else ("no %dº round, aos %d:%02d" % [fight.end_round, fight.end_time_s / 60, fight.end_time_s % 60]),
		"time": "%d:%02d" % [fight.end_time_s / 60, fight.end_time_s % 60],
		"division": division_name(fight.division),
	}


static func _record_before(f: Fighter, won: bool) -> String:
	return "%d-%d-%d" % [int(f.record.wins) - (1 if won else 0), int(f.record.losses) - (0 if won else 1), int(f.record.draws)]


# --- Redes sociais (Game Design Bible §10: trash talk, rivalidades) ---------
# Posts são NewsItem com channel "social": o autor é um atleta, uma
# organização ou uma conta de torcida (content/news_templates.json → social).

func _social_fight(world: WorldState, out: Array, ev: FightEvent, fight: Fight, winner: Fighter, loser: Fighter, v: Dictionary, ids: Array) -> void:
	_add(out, story(world, "social_win", "post_win:" + fight.id, v.merged({"_author": winner.id, "loser_handle": handle(world, loser.id)}), ids))
	_add(out, story(world, "social_loss", "post_loss:" + fight.id, v.merged({"_author": loser.id}), ids))
	if fight.id != ev.fight_ids[-1]:
		return
	# Callout: o vencedor cobra o nome mais alto do World Combat Index.
	var history: Array = world.rankings.get(Rankings.key(Rankings.WCI_ORG_ID, winner.division), [])
	if history.is_empty():
		return
	for id: String in history[-1].entries.slice(0, 3):
		if id != winner.id and id != loser.id and world.fighters.has(id):
			var target: Fighter = world.fighters[id]
			var cv := _fighter_vars(winner).merged({"_author": winner.id, "target": target.display_name(), "target_handle": handle(world, id), "target_record": target.record_string(), "event": ev.name})
			_add(out, story(world, "social_callout", "callout:" + fight.id, cv, [winner.id, id, ev.organization_id]))
			# O tabloide repercute a provocação no site.
			_add(out, story(world, "callout_story", "callout_story:" + fight.id, cv, [winner.id, id, ev.organization_id]))
			return


static func handle(world: WorldState, id: String) -> String:
	var f: Fighter = world.fighters.get(id)
	if f:
		return "@" + _slug(f.first_name + f.last_name)
	var org: Organization = world.organizations.get(id)
	if org:
		return "@" + _slug(org.short_name)
	return str(_account(id).get("handle", "@" + id))


static func author_name(world: WorldState, id: String) -> String:
	var f: Fighter = world.fighters.get(id)
	if f:
		return f.display_name()
	var org: Organization = world.organizations.get(id)
	if org:
		return org.name
	return str(_account(id).get("name", id))


static func _account(id: String) -> Dictionary:
	for a: Dictionary in config().social.accounts:
		if a.id == id:
			return a
	return {}


static func _fan_account(key: String) -> String:
	var accounts: Array = config().social.accounts
	return str(accounts[absi(key.hash()) % accounts.size()].id)


static func _slug(text: String) -> String:
	var out := ""
	for ch in text.to_lower():
		var i := "áàâãäéèêëíìîïóòôõöúùûüçñ".find(ch)
		if i >= 0:
			ch = "aaaaaeeeeiiiiooooouuuucn"[i]
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out


## Curtidas estimadas: fama e carisma do autor (públicos), variação estável
## pela chave do fato. Nunca olha atributos ocultos.
func _engagement(world: WorldState, author_id: String, key: String) -> int:
	var base := float(config().social.fan_account_base)
	var f: Fighter = world.fighters.get(author_id)
	if f:
		base = (_fame(f) + 10.0) * (0.5 + f.charisma / 100.0) * 40.0
	var org: Organization = world.organizations.get(author_id)
	if org:
		base = org.reputation * 60.0
	return int(base * (0.8 + float(absi(key.hash()) % 400) / 1000.0))


## 12400 → "12,4 mil" (rótulo de engajamento para a UI).
static func compact(value: int) -> String:
	if value >= 1000000:
		return ("%.1f mi" % (value / 1000000.0)).replace(".", ",")
	if value >= 1000:
		return ("%.1f mil" % (value / 1000.0)).replace(".", ",")
	return str(value)
