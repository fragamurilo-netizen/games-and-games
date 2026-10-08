class_name FightPlan
extends RefCounted
## Plano de luta (a "fightplan" do LEATHER, levada para o MMA): o empresário não controla golpe a
## golpe; define antes de cada round como o lutador vai lutar. O motor lê só estes campos.

## [chave, rótulo, [opções], ajuda]
const FIELDS := [
	["distancia", "Distância", ["Longa", "Média", "Curta (clinch)"], "Onde ele quer lutar em pé. Longa favorece chutes e jab; média, as mãos pesadas; curta, o clinch e as quedas na grade."],
	["postura", "Postura", ["Cautelosa", "Equilibrada", "Agressiva"], "Agressiva toma a iniciativa e pressiona, mas abre a guarda e cansa. Cautelosa defende mais e espera o erro."],
	["ritmo", "Ritmo", ["Baixo", "Médio", "Alto"], "Quantos golpes por minuto. Ritmo alto ganha rounds e gasta o tanque."],
	["combinacoes", "Combinações", ["Golpes soltos", "Curtas", "Longas"], "Sequências longas machucam mais e deixam o lutador exposto ao contragolpe."],
	["alvo", "Alvo", ["Variado", "Cabeça", "Corpo", "Pernas"], "Cabeça procura o nocaute; corpo tira o fôlego; pernas tiram a movimentação."],
	["jogo", "Jogo", ["Só em pé", "Misto", "Levar ao chão"], "Quanto ele procura a queda."],
	["por_cima", "Por cima no chão", ["Bater (ground and pound)", "Buscar finalização", "Controlar", "Deixar levantar"], "O que fazer quando estiver por cima."],
	["por_baixo", "Por baixo no chão", ["Levantar", "Raspar", "Finalizar da guarda"], "O que fazer quando estiver por baixo."],
	["contra", "Contragolpe", ["Não", "Sim"], "Responder a cada ataque do adversário. Bom contra quem entra sem defesa."],
	["base", "Base", ["Natural", "Ortodoxa", "Canhota"], "Trocar de base confunde, mas quem não é natural na outra perde precisão."],
]

const DEFAULT := {"distancia": 1, "postura": 1, "ritmo": 1, "combinacoes": 1, "alvo": 0, "jogo": 1, "por_cima": 0, "por_baixo": 0, "contra": 0, "base": 0}


static func label_of(key: String, value: int) -> String:
	for f: Array in FIELDS:
		if f[0] == key:
			var opts: Array = f[2]
			return String(opts[clampi(value, 0, opts.size() - 1)])
	return ""


static func summary(plan: Dictionary) -> String:
	var parts: Array = []
	parts.append(label_of("postura", int(plan["postura"])))
	parts.append("distância " + label_of("distancia", int(plan["distancia"])).to_lower())
	parts.append("ritmo " + label_of("ritmo", int(plan["ritmo"])).to_lower())
	if int(plan["jogo"]) == 2:
		parts.append("busca a queda")
	elif int(plan["jogo"]) == 0:
		parts.append("só em pé")
	return ", ".join(parts)


## Plano que a equipe rival (ou o técnico do jogador, como sugestão) monta olhando os dois
## atributos. Mesma informação para todos: o lutador e o adversário, nada escondido.
static func suggest(me: Fighter, opp: Fighter) -> Dictionary:
	var p := DEFAULT.duplicate()
	var my_st := (me.a("maos") + me.a("chutes") + me.a("potencia")) / 3.0
	var op_st := (opp.a("maos") + opp.a("chutes") + opp.a("potencia")) / 3.0
	var my_wr := (me.a("queda") + me.a("por_cima")) / 2.0
	var op_tdd := opp.a("def_queda")
	var op_wr := (opp.a("queda") + opp.a("por_cima")) / 2.0
	var my_tdd := me.a("def_queda")
	var my_bjj := (me.a("finalizacao") + me.a("por_baixo")) / 2.0
	var op_bjj_def := opp.a("def_finalizacao")
	# Quedas: só se ele derruba melhor do que o outro defende e não é pior no chão.
	var td_edge := my_wr - op_tdd
	var st_edge := my_st - (opp.a("defesa") + op_st) / 2.0
	if td_edge > 6.0 and td_edge > st_edge:
		p["jogo"] = 2
		p["distancia"] = 2 if me.a("clinch") >= 60.0 else 1
	elif op_wr - my_tdd > 6.0 or (my_st > op_st + 6.0 and td_edge < 0.0):
		p["jogo"] = 0
	# Em pé: chutador fica longe; pancadeiro encurta; clincher cola.
	if p["jogo"] != 2:
		if me.a("chutes") > me.a("maos") + 5.0 or me.reach_cm > opp.reach_cm + 6:
			p["distancia"] = 0
		elif me.a("clinch") > me.a("maos") + 6.0 and me.a("clinch") > opp.a("clinch") + 5.0:
			p["distancia"] = 2
		else:
			p["distancia"] = 1
	# Postura e ritmo: quem tem mais fôlego acelera; quem bate mais forte pressiona.
	if me.a("potencia") > opp.a("queixo") + 8.0 and me.a("defesa") >= 50.0:
		p["postura"] = 2
	elif opp.a("potencia") > me.a("queixo") + 8.0 or opp.a("maos") > me.a("defesa") + 10.0:
		p["postura"] = 0
		p["contra"] = 1 if me.a("velocidade") + me.a("defesa") > opp.a("velocidade") + opp.a("defesa") else 0
	if me.a("cardio") > opp.a("cardio") + 7.0:
		p["ritmo"] = 2
	elif me.a("cardio") < opp.a("cardio") - 8.0:
		p["ritmo"] = 0
	p["combinacoes"] = 2 if me.a("maos") >= 68.0 and me.a("cardio") >= 60.0 else (0 if me.a("maos") < 50.0 else 1)
	# Alvo: corpo de quem tem pouco fôlego, pernas de quem vive de movimentação.
	if opp.a("cardio") < 52.0 and p["ritmo"] >= 1:
		p["alvo"] = 2
	elif opp.a("movimentacao") > 70.0 and me.a("chutes") >= 60.0:
		p["alvo"] = 3
	elif me.a("potencia") >= 70.0:
		p["alvo"] = 1
	# Chão.
	if me.a("finalizacao") > op_bjj_def + 6.0:
		p["por_cima"] = 1
	elif me.a("por_cima") >= 60.0:
		p["por_cima"] = 0
	else:
		p["por_cima"] = 2
	if p["jogo"] == 0 and me.a("por_cima") < opp.a("por_baixo"):
		p["por_cima"] = 3
	if my_bjj > op_bjj_def + 8.0:
		p["por_baixo"] = 2
	elif me.a("por_baixo") > opp.a("por_cima") + 4.0:
		p["por_baixo"] = 1
	else:
		p["por_baixo"] = 0
	_school(p, me, opp)
	return p


## O jeito da escola por cima da conta dos atributos: o sambista de combate bate por cima, o
## jiu-jiteiro joga de guarda, o caratê luta de longe e no contra-ataque, o tailandês cola.
static func _school(p: Dictionary, me: Fighter, opp: Fighter) -> void:
	var pr := Styles.profile(me)
	if Styles.mark(pr, "gnp") >= 0.6 and int(p["por_cima"]) == 2:
		p["por_cima"] = 0
	if Styles.mark(pr, "guard") >= 0.6 and me.a("finalizacao") >= 60.0 and me.a("finalizacao") > opp.a("def_finalizacao"):
		p["por_baixo"] = 2
	if Styles.mark(pr, "blitz") >= 0.6 and int(p["jogo"]) != 2:
		p["distancia"] = 0
		if int(p["postura"]) != 2:
			p["contra"] = 1
	if Styles.mark(pr, "plum") >= 0.8 and int(p["jogo"]) != 2 and me.a("clinch") >= opp.a("clinch"):
		p["distancia"] = 2
	if Styles.mark(pr, "low_kicks") >= 0.8 and int(p["alvo"]) == 0:
		p["alvo"] = 3
	elif Styles.mark(pr, "body") >= 0.8 and int(p["alvo"]) == 0:
		p["alvo"] = 2
	if Styles.mark(pr, "counter") >= 0.7 and int(p["postura"]) != 2:
		p["contra"] = 1
	if Styles.mark(pr, "chain") >= 0.6 and int(p["jogo"]) == 1 and me.a("queda") >= opp.a("def_queda"):
		p["jogo"] = 2


## Ajuste do corner entre rounds (o que a IA rival faz, como no LEATHER: quem está perdendo
## sobe o ritmo, a agressividade e encurta a distância).
static func adjust(plan: Dictionary, me: Fighter, losing_rounds: int, stamina: float, rounds_left: int) -> Dictionary:
	var p := plan.duplicate()
	if losing_rounds > 0 and rounds_left > 0:
		p["postura"] = mini(2, int(p["postura"]) + 1)
		if stamina > 0.45:
			p["ritmo"] = mini(2, int(p["ritmo"]) + 1)
		if int(p["distancia"]) == 0 and me.a("maos") >= me.a("chutes") - 4.0:
			p["distancia"] = 1
		if me.a("queda") >= 62.0 and int(p["jogo"]) < 2:
			p["jogo"] = int(p["jogo"]) + 1
	elif losing_rounds < 0 and rounds_left <= 1:
		p["postura"] = maxi(0, int(p["postura"]) - 1)
	if stamina < 0.35:
		p["ritmo"] = 0
	return p
