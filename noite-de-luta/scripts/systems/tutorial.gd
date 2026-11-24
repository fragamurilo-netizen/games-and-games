class_name Tutorial
extends RefCounted
## Tutorial guiado das primeiras semanas. Dois pedaços, os dois dentro do save (`GameWorld.tut`):
## - **Primeiros passos**: uma lista curta por papel. O passo da vez aparece num cartão no Início
##   com o botão que leva até lá; cada passo se conclui sozinho quando o jogador faz a coisa
##   (contratou, marcou a luta, fechou a noite). Dá para pular a qualquer momento.
## - **Dicas de primeira vez**: um cartão no alto das telas principais, uma vez por carreira.
## Carreira nova começa com o tutorial ligado (dá para desligar na criação); save de antes dele
## chega desligado.

## [chave, título, texto, botão, destino]
const STEPS_E := [
	["contratar", "Contrate o primeiro lutador", "No Mercado, amadores custam pouco e aceitam fácil. Abra a ficha, veja os atributos e faça a proposta.", "Ir ao Mercado", "area:market"],
	["staff", "Contrate um técnico", "Sem técnico a evolução é lenta. Na aba Staff do Mercado, um técnico de striking ou de jiu-jitsu já muda o treino.", "Ver candidatos", "area:market"],
	["treino", "Escolha o treino", "Na ficha do lutador, aba Treino: o foco diz o que ele evolui e a intensidade pesa na condição física.", "Abrir a ficha", "fighter:treino"],
	["luta", "Feche a primeira luta", "As propostas chegam na caixa de entrada. Aceite uma que caiba no momento do lutador ou desafie alguém pelo ranking.", "Caixa de entrada", "push:inbox"],
	["corner", "Vá para o corner", "Na semana da luta, monte o plano e acompanhe round a round. No intervalo, a instrução do corner é sua.", "", ""],
	["metas", "Conheça as metas da temporada", "Três metas por ano rendem dinheiro, reputação e o apoio da cidade. Veja o que este ano pede.", "Ver a temporada", "push:season"],
]
const STEPS_P := [
	["card", "Abra o card da próxima noite", "Cada noite tem luta principal, co-principal, card principal e preliminares. O termômetro mostra o quanto o card vende.", "Ver a noite", "next_event"],
	["marcar", "Marque uma luta", "Escolha a categoria, os dois lutadores e a bolsa. As academias respondem na hora e dizem por que recusam.", "Montar o card", "next_event"],
	["sede", "Veja a sede e os ingressos", "Arena grande com card fraco fica vazia na transmissão. Os ingressos vão à venda quatro semanas antes da noite.", "Sede e ingressos", "next_venue"],
	["noite", "Comande uma noite de luta", "No sábado da noite, acompanhe luta a luta, resolva os imprevistos e feche a noite com os bônus.", "", ""],
	["tv", "Veja o contrato de TV", "A TV paga por noite e decide quanto do pay-per-view fica com a liga. As propostas chegam antes de o contrato acabar.", "Contrato de TV", "push:tv"],
	["metas", "Conheça as metas dos sócios", "Três metas por ano. Os sócios olham cada noite: confiança alta libera verba, confiança baixa vira ultimato.", "Ver a temporada", "push:season"],
]
## Dicas de primeira vez: tela -> [título, texto]
const TIPS := {
	"market": ["Mercado", "Amador aceita fácil e evolui com treino. Profissional rende bolsa maior, mas olha a reputação da academia. A chance aparece antes de você propor."],
	"fighter": ["Ficha do lutador", "As abas mostram atributos, treino, contrato e números. O nível resume; a luta usa cada atributo. A moral cai com promessa quebrada e tempo parado."],
	"team": ["Equipe", "Toque num lutador para abrir a ficha. Quem está livre pode desafiar alguém do ranking; quem lutou há pouco precisa descansar."],
	"rankings": ["Ranking", "O campeão fica à parte e a lista sai só dos resultados. Os primeiros lutam na Liga Global; o meio, no continental; o resto, no regional."],
	"offer": ["Proposta de luta", "Compare os dois lados antes de aceitar: nível, estilo, alcance e momento. Bolsa alta contra adversário errado custa a sequência."],
	"fight_plan": ["Plano de luta", "Escolha onde lutar e o ritmo pelo que seu lutador faz melhor e pelo que o adversário faz pior. O camp e a pesagem já entram na conta."],
	"fight": ["No corner", "Acompanhe os lances, os números e o placar da transmissão. No intervalo você muda a instrução. Dá para acelerar ou pular para o fim."],
	"gym": ["Academia", "As mensalidades dos alunos pagam a casa; as bolsas fazem ela crescer. Cada profissional do staff abre mais turmas, mas o salário pesa toda semana."],
	"events": ["Noites da liga", "Uma noite a cada duas semanas; as numeradas vendem pay-per-view. O matchmaker completa o que você deixar em branco."],
	"org_event": ["Montagem do card", "A ordem do card importa: quem luta no alto fica famoso mais rápido. O termômetro diz o que vende e o que esfria a noite."],
	"book": ["Marcar luta", "Ranking próximo, rivalidade e cinturão vendem. Campeão só aceita valendo o cinturão e defende duas vezes por ano: escolha bem as noites dele."],
	"venue": ["Sede e ingressos", "A procura vem do hype, da cidade e do preço. Casa cheia dá prestígio; arena vazia tira."],
	"night": ["Noite de luta", "Assista ou simule luta a luta. No fim, os bônus da noite são seus: luta da noite e duas performances."],
	"tv": ["Contrato de TV", "TV aberta dá alcance e fama; assinatura e streaming pagam mais por noite. Dá para pedir mais, com risco de perder a proposta."],
	"org": ["Organização", "Prestígio atrai público, patrocínio e TV, e faz a folha crescer junto. Na virada do ano os sócios levam 40% do lucro."],
	"season": ["Temporada", "As metas pagam na hora em que são batidas; as de fechamento valem como o ano terminar. O termômetro mostra o porquê de cada subida e descida."],
	"inbox": ["Caixa de entrada", "O que espera decisão fica no alto, com os botões de ação. O resto são avisos sobre a sua casa."],
}


static func start(w: GameWorld, on: bool) -> void:
	w.tut = {"on": on, "tips_on": on, "done": {}, "tips": {}, "seen": {}}


## Save de antes do guia: sem primeiros passos e só com a dica da tela nova (a temporada).
static func for_old_save() -> Dictionary:
	var seen := {}
	for k: String in TIPS:
		if k != "season":
			seen[k] = true
	return {"on": false, "tips_on": true, "done": {}, "tips": seen, "seen": {}}


static func steps(w: GameWorld) -> Array:
	return STEPS_P if w.is_president() else STEPS_E


static func is_done(w: GameWorld, key: String) -> bool:
	return (w.tut.get("done", {}) as Dictionary).has(key)


## Guia ligado e com passo por fazer.
static func active(w: GameWorld) -> bool:
	if not bool(w.tut.get("on", false)):
		return false
	return not current(w).is_empty()


## O passo da vez (o primeiro por fazer), ou [] quando acabou.
static func current(w: GameWorld) -> Array:
	for s: Array in steps(w):
		if not is_done(w, String(s[0])):
			return s
	return []


static func done_count(w: GameWorld) -> int:
	var n := 0
	for s: Array in steps(w):
		if is_done(w, String(s[0])):
			n += 1
	return n


## O jogador passou por uma tela ou fez algo que o mundo não registra sozinho.
static func mark(w: GameWorld, key: String) -> void:
	if w == null or w.tut.is_empty():
		return
	if not w.tut.has("seen"):
		w.tut["seen"] = {}
	(w.tut["seen"] as Dictionary)[key] = true


static func _seen(w: GameWorld, key: String) -> bool:
	return (w.tut.get("seen", {}) as Dictionary).has(key)


static func _met(w: GameWorld, key: String) -> bool:
	var t := w.user_team()
	match key:
		"contratar":
			return not w.user_fighters().is_empty()
		"staff":
			return t != null and not t.staff.is_empty()
		"treino":
			return _seen(w, "treino")
		"luta":
			if Season.life(w, "fights") >= 1.0:
				return true
			for f: Fighter in w.user_fighters():
				if f.bout_id >= 0:
					return true
			return false
		"corner":
			return Season.life(w, "fights") >= 1.0
		"metas":
			return _seen(w, "season")
		"card":
			return _seen(w, "org_event")
		"marcar":
			return Season.life(w, "booked") >= 1.0
		"sede":
			return _seen(w, "venue")
		"noite":
			return Season.life(w, "nights") >= 1.0
		"tv":
			return _seen(w, "tv")
	return false


## Marca os passos que o jogador acabou de cumprir (na ordem: um passo só conta depois dos
## anteriores, menos os que o mundo cumpre de qualquer jeito). Devolve os títulos dos concluídos
## agora; quando o último sai, o guia fecha e rende a conquista.
static func sync(w: GameWorld) -> Array:
	var out: Array = []
	if not bool(w.tut.get("on", false)):
		return out
	if not w.tut.has("done"):
		w.tut["done"] = {}
	var done: Dictionary = w.tut["done"]
	for s: Array in steps(w):
		var key := String(s[0])
		if done.has(key):
			continue
		if not _met(w, key):
			break
		done[key] = w.week
		out.append(String(s[1]))
	if current(w).is_empty() and not bool(w.tut.get("finished", false)):
		w.tut["finished"] = true
		w.tut["on"] = false
		w.life["tut"] = 1.0
		var t := w.user_team()
		if t != null and not w.is_president():
			t.add_money(w.week, "Kit de boas-vindas do fornecedor de material", 3000.0)
		Achievements.check(w)
	return out


static func skip(w: GameWorld) -> void:
	w.tut["on"] = false
	w.tut["skipped"] = true


## A dica desta tela ainda não foi vista (e as dicas estão ligadas).
static func tip_due(w: GameWorld, key: String) -> bool:
	if w == null or not bool(w.tut.get("tips_on", false)) or not TIPS.has(key):
		return false
	return not (w.tut.get("tips", {}) as Dictionary).has(key)


static func tip_seen(w: GameWorld, key: String) -> void:
	if not w.tut.has("tips"):
		w.tut["tips"] = {}
	(w.tut["tips"] as Dictionary)[key] = true


static func tips_off(w: GameWorld) -> void:
	w.tut["tips_on"] = false
