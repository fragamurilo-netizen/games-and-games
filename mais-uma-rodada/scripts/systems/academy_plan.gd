class_name AcademyPlan
extends RefCounted
## Plano individual distribui o treino existente; nunca cria pontos extras de potencial.
const KEY := "academy_plans_v1"
const OPTIONS := [["balanced", "Equilibrado"], ["technical", "Técnica"], ["tactical", "Leitura de jogo"], ["physical", "Base física"], ["recovery", "Recuperação"]]
const BIASES := {
	"balanced": [], "technical": [[Attr.PAS,1.5],[Attr.TEC,1.5],[Attr.DRI,1.25]],
	"tactical": [[Attr.DEC,1.6],[Attr.POS,1.4],[Attr.VIS,1.25]],
	"physical": [[Attr.RES,1.5],[Attr.ACE,1.25],[Attr.FOR,1.2]], "recovery": []}

static func state(world: GameWorld, p: Player) -> Dictionary:
	var plans: Dictionary = world.stats.get(KEY,{})
	var row: Dictionary = plans.get(str(p.id),{})
	return row if int(row.get("club",-1)) == world.user_club_id else {}

static func selected(world: GameWorld, p: Player) -> String:
	return String(state(world,p).get("focus","balanced"))

static func choose(world: GameWorld, p: Player, focus: String) -> bool:
	if not world.academy.has(p.id) or not BIASES.has(focus):
		return false
	var plans: Dictionary = world.stats.get(KEY,{})
	var previous := state(world,p)
	plans[str(p.id)] = {"club":world.user_club_id,"focus":focus,"since":world.current_day(),"year":world.year,"last":previous.get("last",-1),"minutes":previous.get("minutes",p.stats[Player.S_MINUTES])}
	world.stats[KEY]=plans
	return true

static func bias(world: GameWorld, p: Player) -> Array:
	return BIASES.get(selected(world,p),[])

static func training_factor(world: GameWorld, p: Player) -> float:
	if p.is_injured():
		return 0.12
	return 0.35 if selected(world,p)=="recovery" else clampf((p.condition-25.0)/65.0,0.4,1.0)

static func weekly(world: GameWorld, p: Player) -> void:
	if state(world,p).is_empty():
		choose(world,p,"balanced")
	var row := state(world,p)
	var stamp := world.year*10000+world.current_day()
	if int(row.get("last",-1)) == stamp:
		return
	row["last"]=stamp
	var minutes := maxi(0,p.stats[Player.S_MINUTES]-int(row.get("minutes",0)))
	row["minutes"]=p.stats[Player.S_MINUTES]
	row["recent_minutes"]=minutes
	if selected(world,p)=="recovery" and not p.is_injured():
		p.condition=minf(100.0,p.condition+3.0) # descanso, não cura instantânea de lesão
	row["report"]="Carga alta: reveja o descanso." if minutes>180 else ("Poucos minutos: reavalie a categoria e a concorrência." if minutes==0 else "Minutos e treino acompanhados pela comissão.")

static func pathway(world: GameWorld, p: Player) -> String:
	var peers: Array=[]
	for q: Player in world.squad(world.user_club()):
		if Pos.group(q.position)==Pos.group(p.position):peers.append(q.overall)
	peers.sort()
	var reference:=float(peers[peers.size()/2]) if not peers.is_empty() else float(p.overall)
	if p.age(world.year)<16:return "Prioridade: formação e minutos na própria categoria. Promoção precoce não garante evolução."
	if p.overall<reference-8:return "Ainda abaixo da rotação da posição. Mantenha minutos na base antes de promover."
	if p.overall<reference-3:return "Pode treinar com o principal, mas precisa de uma rota de minutos. Empréstimo após promoção é uma alternativa."
	return "Próximo da rotação da posição. Promova apenas com espaço no elenco e no teto salarial."

static func controls(world: GameWorld,p: Player) -> Control:
	var box:=UIKit.vbox(8)
	box.add_child(UIKit.section_header("Plano individual"))
	box.add_child(UIKit.scroll_tabs(OPTIONS,selected(world,p),func(focus: String):
		if choose(world,p,focus):
			GameManager.save_now()
			UIManager.toast("Plano atualizado. Os efeitos aparecem com o treino, não ao clicar.")))
	box.add_child(UIKit.label(pathway(world,p),"Small",true))
	box.add_child(UIKit.label(String(state(world,p).get("report","A comissão acompanhará minutos, carga e recuperação nas próximas semanas.")),"Small",true))
	box.add_child(UIKit.label("O foco redistribui o treino. Não revela nem aumenta automaticamente o teto de potencial.","Small",true))
	return box
