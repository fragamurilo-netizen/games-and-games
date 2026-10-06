class_name Autopilot
extends RefCounted
## O auxiliar no comando durante o "Simular até..." (SimDialog). Três jeitos de delegar:
## - MODE_OFF ("Tradicional"): o auxiliar só escala; a simulação para em cada decisão;
## - MODE_KEY ("Só o importante"): o auxiliar resolve o rotineiro (pedidos, coletivas, conversas,
##   propostas por reservas, plano de cada jogo) e para no que mexe com a temporada: proposta por
##   titular, mudança de dono, ultimato, convite de outro clube, jogador querendo sair;
## - MODE_ALL ("Auxiliar decide tudo"): só para no fim. A carreira do treinador (convite de outro
##   clube) nunca é decidida por ele: o convite fica esperando e vence se ninguém responder.
## Tudo o que ele decidiu vai para um diário (world.stats["auto_log"]) mostrado no fim.

const MODE_OFF := 0
const MODE_KEY := 1
const MODE_ALL := 2
const MODE_NAMES := ["Tradicional", "Só o importante", "Auxiliar decide tudo"]
const MODE_DESC := [
	"Você decide tudo. O auxiliar só escala, se quiser.",
	"O auxiliar cuida do dia a dia e para a simulação nas decisões grandes.",
	"O auxiliar comanda até o fim. Você lê o relatório depois.",
]

## Eventos que pesam na temporada: no modo "Só o importante" a simulação para neles.
const BIG_EVENTS := ["takeover", "want_leave", "rival_bid", "tapping_up", "youth_bid", "prodigy", "renewal_standoff",
	"chairman", "board_meeting", "board_cut", "sack_rumor", "stadium", "betting", "idol_farewell"]

static var mode := MODE_OFF


## Plano do jogo: o auxiliar estuda o rival e ajusta a tática do usuário (não no modo tradicional).
static func prepare_match(world: GameWorld, club: Club) -> void:
	if mode == MODE_OFF or club.sheet == null:
		return
	var f := FixtureManager.next_fixture_for(world, club.id)
	if f == null:
		return
	var opp := world.club(f.opponent_of(club.id))
	if opp == null:
		return
	var d := Assistant.dossier(world, club, opp, f.home == club.id)
	var plan: Dictionary = d.get("plan", {})
	if not plan.is_empty() and not Assistant.plan_matches(club.sheet, plan):
		Assistant.apply_plan(club.sheet, plan)


## Depois de cada data: resolve o que o modo deixa. Retorna o motivo para parar ("" = segue).
static func handle(world: GameWorld) -> String:
	if mode == MODE_OFF or not world.has_user():
		return ""
	var stop := ""
	# 1) Decisões (eventos)
	for ev in EventManager.pending(world).duplicate():
		var k := String(ev["k"])
		if mode == MODE_KEY and k in BIG_EVENTS:
			if stop == "":
				stop = "Uma decisão grande espera por você."
			continue
		var desc := EventManager.describe(world, ev)
		var opt := pick_option(desc)
		var opts: Array = desc.get("options", [])
		var msg := EventManager.resolve(world, ev, opt)
		_log(world, "%s: %s" % [String(desc.get("title", "")), String(opts[opt]["t"]) if opt < opts.size() else ""], msg)
	# 2) Propostas pelos jogadores do elenco
	for o: TransferOffer in TransferManager.pending_offers(world).duplicate():
		var p := world.player(o.player_id)
		if p == null:
			continue
		var key := p.squad_status <= Player.STATUS_STARTER
		if mode == MODE_KEY and key:
			if stop == "":
				stop = "Chegou uma proposta por %s." % p.display_name()
			continue
		var buyer := world.club(o.buyer_id)
		var bar := 1.6 if p.squad_status == Player.STATUS_STAR else (1.3 if key else 1.0)
		if world.transfer_window_open() and o.fee >= p.value * bar:
			var msg := TransferManager.respond_offer(world, o, "accept")
			_log(world, "Venda de %s ao %s" % [p.display_name(), buyer.short_name if buyer != null else ""], msg)
		else:
			TransferManager.respond_offer(world, o, "reject")
			_log(world, "Proposta do %s por %s recusada" % [buyer.short_name if buyer != null else "", p.display_name()], "Valor abaixo do que o jogador vale para o elenco.")
	# 3) Pedidos de conversa (jogador, imprensa); a convocação do presidente é com o treinador.
	for q in People.requests(world):
		var kind := String(q["k"])
		if kind == "board":
			if stop == "":
				stop = "O presidente chamou você para uma reunião."
			continue
		People.clear_request(world, kind, int(q.get("t", -1)))
		if kind == "player":
			var pl := world.player(int(q.get("t", -1)))
			if pl != null:
				People.add_trust(world, pl, 1.0)
			world.stats["auto_talk"] = int(world.stats.get("auto_talk", 0)) + 1
		elif kind == "press":
			world.stats["auto_press"] = int(world.stats.get("auto_press", 0)) + 1
	# 4) Convite de outro clube: nunca decidido pelo auxiliar.
	if not People.job_offer(world).is_empty() and mode == MODE_KEY and stop == "":
		stop = "Um clube quer você como técnico."
	if BoardManager.pending_job_offers(world).size() > 0 and stop == "":
		stop = "Você está sem clube."
	return stop


## Escolha do auxiliar: com três ou mais opções, a do meio (o meio-termo); com duas, a padrão.
static func pick_option(desc: Dictionary) -> int:
	var opts: Array = desc.get("options", [])
	if opts.size() >= 3:
		return 1
	return clampi(int(desc.get("def", 0)), 0, maxi(0, opts.size() - 1))


static func _log(world: GameWorld, what: String, result: String) -> void:
	var lg: Array = world.stats.get("auto_log", [])
	var n := int(world.stats.get("auto_n", 0)) + 1
	world.stats["auto_n"] = n
	lg.append({"i": n, "d": world.season.date_label(world.season.day, false) if world.season != null else "", "w": what, "r": result})
	while lg.size() > 60:
		lg.pop_front()
	world.stats["auto_log"] = lg


## Decisões tomadas depois do marco `start` (log_mark no começo da simulação).
static func log_since(world: GameWorld, start: int) -> Array:
	return (world.stats.get("auto_log", []) as Array).filter(func(e: Dictionary): return int(e.get("i", 0)) > start)


static func log_mark(world: GameWorld) -> int:
	return int(world.stats.get("auto_n", 0))


## Rotina (coletivas e conversas) atendida pelo auxiliar: [coletivas, conversas] até agora.
static func routine(world: GameWorld) -> Array:
	return [int(world.stats.get("auto_press", 0)), int(world.stats.get("auto_talk", 0))]
