class_name RefinementEvents
extends RefCounted
## Decisões nascem da carga, contrato, academia e contas observadas. Sem prêmio em atributos.
const KINDS := ["ref_workload", "ref_contract", "ref_academy", "ref_budget"]

static func build(world: GameWorld, kind: String) -> Dictionary:
	if not world.has_user():return {}
	var club:=world.user_club()
	var p: Player=null
	match kind:
		"ref_workload":
			for q: Player in world.squad(club):
				if not q.is_injured() and q.condition<65.0 and q.minutes_season>=180 and int(q.train.get("ld",1))>0 and (p==null or q.condition<p.condition):p=q
		"ref_contract":
			for q: Player in world.squad(club):
				if q.contract_end<=world.year+1 and not q.retiring and not q.transfer_listed and (p==null or q.overall>p.overall):p=q
		"ref_academy":
			for q: Player in world.academy.values():
				if q.age(world.year)>=17 and q.stats[Player.S_MINUTES]<180 and selected_for_review(world,q):
					p=q;break
		"ref_budget":
			var b: Dictionary=world.stats.get("board_budgets_v1",{}).get(str(club.id),{})
			var progress:=TransferManager.season_progress(world)
			if progress>=0.45 and progress<=0.65 and not bool(b.get("reviewed",false)):
				return {"k":kind,"p":-1,"p2":-1,"d":{}}
	if p==null:return {}
	return {"k":kind,"p":p.id,"p2":-1,"d":{}}

static func selected_for_review(world: GameWorld,p: Player) -> bool:
	return String(AcademyPlan.state(world,p).get("focus","balanced"))=="balanced"

static func describe(world: GameWorld,ev: Dictionary) -> Dictionary:
	var p:=world.player(int(ev.get("p",-1)))
	var name:=p.display_name() if p!=null else "O jogador"
	match String(ev["k"]):
		"ref_workload":
			return {"title":"Departamento físico pede revisão de carga","body":"%s apresenta condição baixa. Poupar treino ajuda a recuperar, mas reduz o trabalho de evolução. Não impede toda lesão." % name,"def":1,"options":[{"t":"Carga leve até o próximo jogo","hint":"Reduz o treino individual; volta à carga anterior depois."},{"t":"Manter e avaliar a escalação","hint":"Sem mudança automática; você decide quem joga."}]}
		"ref_contract":
			return {"title":"Diretoria pede decisão sobre contrato","body":"%s tem contrato perto do fim. O departamento quer saber se deve priorizar renovação ou ouvir propostas. Acordo depende de negociação e verba." % name,"def":2,"options":[{"t":"Priorizar renovação","hint":"Adiciona à agenda em Finanças; não assina automaticamente."},{"t":"Ouvir propostas","hint":"Coloca o jogador no mercado sem prometer uma venda."},{"t":"Reavaliar depois","hint":"Contrato continua correndo normalmente."}]}
		"ref_academy":
			return {"title":"Comissão discute a formação de %s" % name,"body":"O jovem tem poucos minutos. Defina uma prioridade de treino e reveja espaço na categoria antes de promovê-lo. Não existe salto garantido de potencial.","def":2,"options":[{"t":"Priorizar técnica","hint":"Redistribui o treino para passe, técnica e drible."},{"t":"Priorizar leitura de jogo","hint":"Redistribui para decisão, posicionamento e visão."},{"t":"Manter plano equilibrado","hint":"Sem ganho instantâneo de atributos."}]}
		"ref_budget":
			return {"title":"Revisão financeira da janela","body":"A diretoria pode revisar a autorização para contratar. Dívidas, parcelas e reserva operacional têm prioridade. A revisão pode manter ou reduzir a verba.","def":1,"options":[{"t":"Solicitar a revisão","hint":"Aplica uma única revisão nesta temporada."},{"t":"Trabalhar com a verba atual","hint":"Não adiciona dinheiro ao orçamento."}]}
	return {"title":"Revisão encerrada","body":"A situação já mudou.","def":0,"options":[{"t":"Entendi","hint":""}]}

static func resolve(world: GameWorld,ev: Dictionary,opt: int) -> String:
	var p:=world.player(int(ev.get("p",-1)))
	match String(ev["k"]):
		"ref_workload":
			if p!=null and p.club_id==world.user_club_id and opt==0:
				var old:=int(p.train.get("ld",1))
				p.train["ld"]=0
				var rest: Dictionary=world.stats.get("load_reviews_v1",{})
				rest[str(p.id)]={"club":p.club_id,"year":world.year,"until":world.current_turn()+1,"old":old}
				world.stats["load_reviews_v1"]=rest
				return "Carga individual reduzida até o próximo jogo. A condição melhora pelo treino, não pelo evento."
			return "Carga mantida. A escalação e o descanso continuam sob sua responsabilidade."
		"ref_contract":
			if p==null or p.club_id!=world.user_club_id:return "O jogador já não está no clube."
			if opt==0:
				var agenda: Dictionary=world.stats.get("contract_agenda_v1",{})
				agenda[str(p.id)]={"club":p.club_id,"year":world.year}
				world.stats["contract_agenda_v1"]=agenda
				return "Renovação adicionada à agenda em Clube > Gestão > Finanças. Falta negociar os termos."
			if opt==1:
				p.transfer_listed=true
				p.asking_price=TransferManager.asking_price(world,p)
				return "Jogador colocado à venda. Uma proposta ainda depende de interesse e orçamento de outro clube."
			return "Contrato mantido sem promessa de renovação."
		"ref_academy":
			if p!=null and world.academy.has(p.id):
				AcademyPlan.choose(world,p,["technical","tactical","balanced"][clampi(opt,0,2)])
				return "A comissão registrou o foco no plano individual. Desenvolvimento será gradual."
			return "O jovem já não está na academia."
		"ref_budget":
			if opt==0:FinanceManager.mid_season_review(world,world.user_club())
			return "A decisão foi registrada, sem aporte artificial de dinheiro."
	return "Revisão encerrada."

static func tick(world: GameWorld) -> void:
	var rest: Dictionary=world.stats.get("load_reviews_v1",{})
	for key in rest.keys():
		var row: Dictionary=rest[key]
		var p:=world.player(int(key))
		if p==null or p.club_id!=int(row["club"]):rest.erase(key);continue
		if world.year!=int(row["year"]) or world.current_turn()>=int(row["until"]):
			if int(p.train.get("ld",1))==0:p.train["ld"]=int(row["old"])
			rest.erase(key)

static func agenda(world: GameWorld,club: Club) -> Control:
	var box:=UIKit.vbox(8)
	for key in world.stats.get("contract_agenda_v1",{}):
		var row: Dictionary=world.stats["contract_agenda_v1"][key]
		var p:=world.player(int(key))
		if p==null or p.club_id!=club.id or int(row["year"])!=world.year or p.contract_end>world.year+1:continue
		box.add_child(UIKit.button("Rever contrato: "+p.short_name(),"GhostButton",func(): Negotiation.open(world,p,"renew",func(): UIManager.refresh_chrome())))
	return box
