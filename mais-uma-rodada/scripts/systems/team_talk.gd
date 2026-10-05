class_name TeamTalk
extends RefCounted
## Falas da palestra no vestiário. O efeito no time vem do tom (MatchSimulation.TALKS); aqui fica
## o que o técnico diz de fato, escolhido pelo momento: favorito ou azarão, clássico, decisão,
## fora de casa, placar do intervalo e quem está mandando no jogo. Cada vez que o modal abre sai
## uma fala diferente para cada tom.
##
## Marcadores: {opp} adversário, {stadium} estádio, {star} nosso melhor em campo, {their} o
## melhor deles, {gk} goleiro deles, {cap} capitão (ou o mais experiente).

const LINES := {
	"motivar": {
		"pre": [
			"Olhem para o lado. Cada um aqui suou a semana inteira por esse jogo. Agora é lá dentro.",
			"Primeira bola dividida é nossa. A segunda também. É assim que a gente começa.",
			"Quero intensidade desde o apito. Quem estuda o jogo hoje são eles, não a gente.",
			"Ninguém vai correr mais que a gente hoje. Ninguém.",
			"Hoje é dia de mostrar quem a gente é. Vamos pra cima deles.",
		],
		"pre_fav": [
			"Todo mundo espera que a gente ganhe. Ótimo. Vamos mostrar por quê.",
			"O {opp} vai se fechar e esperar o nosso erro. Paciência e fome, que o gol sai.",
		],
		"pre_under": [
			"Ninguém lá fora aposta na gente. Eu aposto. Vamos incomodar o {opp}.",
			"Eles têm o {their}. A gente tem esse grupo. Eu fico com o grupo.",
			"Vamos assustar eles logo de cara. Time grande também sente pressão.",
		],
		"pre_derby": [
			"Clássico não se joga, se ganha. A cidade inteira vai lembrar desse jogo.",
			"Tem torcedor nosso que esperou o ano inteiro por esse dia. Não dá pra devolver isso com meia entrega.",
		],
		"pre_big": [
			"Jogo assim aparece poucas vezes na carreira. Quero que vocês saiam daqui sem nenhum arrependimento.",
			"Noventa minutos separam a gente de uma coisa que ninguém tira mais.",
		],
		"pre_away": [
			"O {stadium} vai estar contra. Deixa eles gritarem. A gente cala com a bola no pé.",
			"Fora de casa, os primeiros quinze minutos decidem o clima. Começa ligado.",
		],
		"pre_home": [
			"A nossa torcida vai empurrar. Devolve pra ela desde o primeiro lance.",
			"Em casa quem dita o ritmo somos nós. Pressão neles desde a saída de bola.",
		],
		"half_behind": [
			"Tem quarenta e cinco minutos ainda. Um gol e o jogo é outro. Vamos buscar.",
			"Eles estão cansando. Quem tiver mais perna no segundo tempo leva.",
			"Esquece o primeiro tempo. Voltem pra lá como se estivesse zero a zero.",
		],
		"half_behind2": [
			"Ninguém aqui entrega o jogo. Um gol cedo e o {opp} começa a tremer.",
			"Já vi virar jogo pior que esse. Faz o primeiro e vê o que eles fazem.",
		],
		"half_level": [
			"Está tudo aberto. Quem quiser mais vai ganhar, e quero que sejamos nós.",
			"Eles sentiram no fim do primeiro tempo. Volta apertando que o gol sai.",
		],
		"half_lead": [
			"Um gol é pouco. Vamos atrás do segundo pra jogar tranquilo.",
			"Não é hora de recuar. Quem recua chama o adversário pra dentro.",
		],
		"half_lead2": [
			"Jogo bem encaminhado, mas quero o mesmo apetite. Respeito ao torcedor é jogar até o fim.",
		],
		"half_dom": [
			"Estamos melhores e as chances estão vindo. Continuem finalizando que uma entra.",
			"O {gk} não vai pegar tudo. Mais finalização, mais gente chegando na área.",
		],
		"half_suffer": [
			"Eles estão confortáveis demais. Marca alto e briga por cada bola.",
		],
	},
	"tranquilizar": {
		"pre": [
			"Respira. A gente sabe o que fazer, treinamos isso a semana toda.",
			"Ninguém precisa resolver no primeiro lance. Bola no chão e confiem no passe.",
			"Joguem como no treino. O resto vem naturalmente.",
			"Se errar, segue. Ninguém vai ser crucificado aqui dentro por tentar.",
		],
		"pre_big": [
			"Eu sei o tamanho desse jogo. Justamente por isso: cabeça fria e cada um na sua função.",
			"Ansiedade é normal. Joga simples que ela passa no primeiro toque.",
		],
		"pre_derby": [
			"Clássico tem provocação, tem catimba. Não caiam nisso. Quem perde a cabeça perde o jogo.",
		],
		"pre_away": [
			"Vai ter barulho, faz parte. Conversem entre vocês, que é o que importa lá dentro.",
			"Começa segurando a bola. Deixa a torcida deles se cansar.",
		],
		"pre_under": [
			"Ninguém espera nada da gente, então joguem leves. Organização e bola no chão.",
		],
		"half_lead": [
			"Estamos bem. Se eles pressionarem, não é pra se apavorar, é pra administrar.",
			"Controla a bola e faz o tempo passar com ela no nosso pé.",
		],
		"half_lead2": [
			"Jogo resolvido se a gente não inventar. Simples, sem firula, sem cartão bobo.",
		],
		"half_level": [
			"Está igual e está tudo certo. Não precisa forçar, a chance vai aparecer.",
			"Voltem com a mesma organização. Paciência que eles vão abrir.",
		],
		"half_behind": [
			"Calma. Desespero agora é tudo que o {opp} quer. Construindo, a gente chega.",
			"Um gol de diferença não é nada. Tem tempo, não precisa de chutão.",
		],
		"half_behind2": [
			"Cabeça no lugar. Primeiro um gol, depois a gente pensa no resto.",
		],
		"half_suffer": [
			"Eles estão por cima, mas criaram menos do que parece. Fechem as linhas e saiam com calma.",
		],
		"half_dom": [
			"O gol está amadurecendo. Não precisa afobar a finalização.",
		],
	},
	"elogiar": {
		"pre": [
			"A semana de treino foi das melhores. É só levar aquilo pro campo.",
			"Vocês vêm jogando bem. Mantém o padrão e o resultado aparece.",
			"Fiquei satisfeito com o que vi nos treinos. Agora é confirmar.",
		],
		"half_lead": [
			"Primeiro tempo do jeito que a gente pediu. Parabéns, continua assim.",
			"{star}, que primeiro tempo. Todo mundo acompanhou, e é por isso que estamos na frente.",
			"Organização perfeita. Não muda nada.",
		],
		"half_lead2": [
			"Vocês estão jogando muito. Mantém a concentração e esse jogo é nosso.",
		],
		"half_level": [
			"Gostei da postura. O placar ainda não mostra, mas a gente está bem.",
		],
		"half_dom": [
			"Estamos jogando melhor que eles. O gol é questão de tempo, continuem.",
		],
		"half_behind": [
			"Não estamos mal, o placar é que está injusto. Sigam fazendo o que estão fazendo.",
		],
		"half_suffer": [
			"Defensivamente vocês estão muito bem. Segura isso que o contra-ataque vai encaixar.",
		],
	},
	"exigir": {
		"pre": [
			"Só serve a vitória. Empate hoje é derrota.",
			"Vale três pontos e eu quero os três.",
			"Não aceito ninguém andando em campo hoje. Quem não estiver a fim, me avisa agora.",
		],
		"pre_fav": [
			"Somos melhores que o {opp}, e o placar tem que mostrar isso.",
			"Contra time desse nível a gente não pode tropeçar. Concentração do início ao fim.",
		],
		"pre_big": [
			"Não chegamos até aqui pra perder no detalhe. Quero esse jogo.",
			"É jogo de decisão. Quem vacilar hoje vai lembrar disso por muito tempo.",
		],
		"pre_derby": [
			"Perder clássico não é opção. Saiam daqui sabendo disso.",
		],
		"half_level": [
			"Empate não serve. Quero o time no campo de ataque.",
			"Eles não aguentam mais quarenta e cinco minutos assim. Vamos ganhar esse jogo.",
		],
		"half_behind": [
			"Estar atrás com esse time é inaceitável. Quero reação logo no começo.",
		],
		"half_behind2": [
			"Quero ver quem tem coragem de mudar esse jogo. Primeiro gol em quinze minutos.",
		],
		"half_lead": [
			"Um gol não ganha jogo. Quero o segundo e quero a defesa sem erro.",
		],
		"half_lead2": [
			"Ainda não acabou. Quero esse jogo fechado e o nosso gol zerado.",
		],
		"half_dom": [
			"Temos a bola e temos as chances. Agora eu quero o gol.",
		],
	},
	"sem_pressao": {
		"pre": [
			"Joguem soltos. Ninguém aqui vai ser cobrado por tentar.",
			"Divirtam-se lá dentro. Foi por isso que vocês começaram a jogar bola.",
			"A pressão é toda deles. A gente só tem a ganhar.",
		],
		"pre_under": [
			"Ninguém espera nada da gente contra o {opp}. Então vamos jogar sem medo.",
			"O favorito é o {opp}. A responsabilidade toda está do outro lado.",
		],
		"pre_big": [
			"Já fizemos muito pra chegar até aqui. O que vier hoje é lucro.",
		],
		"half_behind": [
			"O placar não define ninguém aqui. Joguem leves que o jogo pode virar.",
		],
		"half_behind2": [
			"O jogo já ficou difícil, então não tem mais nada a perder. Arrisquem.",
		],
		"half_level": [
			"Tira o peso das costas. Joguem o futebol de vocês.",
		],
		"half_suffer": [
			"Eles estão com mais a bola, e tudo bem. Respira e joga sem medo.",
		],
		"half_lead": [
			"A vantagem é nossa. Joguem leves, sem medo de errar.",
		],
		"half_dom": [
			"O gol vai sair. Não fiquem ansiosos, joguem soltos.",
		],
	},
	"cobrar": {
		"pre": [
			"A semana de treino foi fraca. Quero ver em campo o que não vi lá.",
			"Os últimos jogos não foram o nosso padrão. Hoje isso acaba.",
		],
		"half_behind": [
			"Isso foi muito pouco. Vocês estão deixando o {opp} jogar à vontade.",
			"Não reconheço esse time. Quero outra atitude em dez minutos ou eu mexo.",
			"Perdeu a bola, ninguém volta. Isso acabou agora.",
		],
		"half_behind2": [
			"Esse primeiro tempo não pode se repetir. Não pode.",
			"Tem gente aqui que não entrou em campo. Depois eu converso com cada um.",
		],
		"half_level": [
			"Estamos dormindo. Empate com esse futebol é sorte.",
			"Muito passe errado, muita bola perdida à toa. Acorda.",
		],
		"half_lead": [
			"O placar está mentindo. A gente jogou mal e eu quero mais.",
			"Estamos ganhando, mas desse jeito não seguramos. Acordem.",
		],
		"half_suffer": [
			"Eles estão mandando no jogo. Quem não tiver perna, me avisa que eu tiro.",
		],
	},
	"confiar": {
		"pre": [
			"Eu escolhi cada um de vocês. Confio em quem está nessa sala.",
			"Vocês estão prontos. Eu não teria escalado ninguém que não estivesse.",
			"Aconteça o que acontecer lá fora, aqui dentro a gente se apoia.",
			"{star}, a bola vai passar por você. O resto apoia. Confio em vocês.",
		],
		"pre_under": [
			"Eles podem ter mais nome. Eu não trocaria esse grupo por nenhum outro.",
		],
		"pre_big": [
			"Esse grupo já mostrou que aguenta jogo grande. Hoje não vai ser diferente.",
		],
		"half_behind": [
			"Eu sei que vocês conseguem virar isso. Já fizeram antes.",
			"Ninguém aqui deixou de acreditar. Eu também não.",
		],
		"half_behind2": [
			"O placar está pesado, mas eu conheço o caráter desse grupo. De cabeça erguida.",
		],
		"half_level": [
			"Está no caminho. Confio no que a gente treinou, segue o plano.",
		],
		"half_lead": [
			"Fizeram por merecer. Agora confiem em vocês pra fechar o jogo.",
		],
		"half_suffer": [
			"Sofremos e aguentamos. Isso mostra o time que a gente é.",
		],
	},
	"foco": {
		"pre": [
			"Atenção na bola parada. É assim que o {opp} faz a maioria dos gols.",
			"O {their} é o perigo deles. Ninguém deixa ele girar de frente.",
			"Linhas próximas, nada de espaço entre o meio e a defesa. O resto a gente resolve com a bola.",
			"Recuperou, primeiro passe pra frente. A transição é o nosso jogo hoje.",
			"O {gk} sai mal do gol. Bola na área sempre que der.",
		],
		"half": [
			"Estamos dando muito espaço pelos lados. Laterais, mais atenção na volta.",
			"O {their} está achando espaço entre as linhas. Volantes, fechem por dentro.",
			"Estamos cruzando sem gente na área. Mais tabela por dentro.",
			"A segunda bola está toda com eles. Quero o meio mais perto.",
			"Bola parada: cada um no seu homem, ninguém olha só a bola.",
		],
		"half_lead": [
			"Mantém a distância entre as linhas e ataca o espaço quando eles abrirem.",
		],
		"half_behind": [
			"Precisamos chegar mais pelo meio. O {star} tem que receber de frente pro gol.",
		],
	},
	"decepcao": {
		"half_behind": [
			"Estou decepcionado. Esse não é o time que eu vejo nos treinos.",
			"Esperava muito mais de vocês hoje.",
			"Não vou gritar. Mas olhem pra vocês mesmos e pensem se isso é o máximo.",
		],
		"half_behind2": [
			"Sinceramente, estou triste com o que vi. Vocês sabem que são melhores que isso.",
		],
		"half_level": [
			"Achei pouco. Vocês podem muito mais do que mostraram.",
		],
		"half_lead": [
			"Ganhando, mas jogando mal. Não estou satisfeito.",
		],
		"half_suffer": [
			"Estamos só correndo atrás. Não foi isso que combinamos.",
		],
	},
}

## Como cada um reage, por cima do resumo. {n} = nome do jogador.
const REACT_UP := [
	"{n} bate palmas e chama o grupo.",
	"{n} concorda com a cabeça, concentrado.",
	"{n} é o primeiro a levantar do banco.",
	"{n} repete a instrução em voz alta para os outros.",
	"{n} aperta a mão de cada companheiro antes de sair.",
	"{n} amarra a chuteira de novo e olha para a porta.",
]
const REACT_UP_CAP := [
	"{n}, o capitão, puxa a roda antes de voltar.",
	"{n}, o capitão, fala com os mais novos no canto.",
]
const REACT_DOWN := [
	"{n} fica olhando para o chão.",
	"{n} cruza os braços e não diz nada.",
	"{n} sai do vestiário com a cara fechada.",
	"{n} parece mais nervoso do que antes.",
	"{n} reclama baixo com quem está do lado.",
]
const REACT_LOOSE := [
	"{n} sai rindo, tranquilo até demais.",
	"{n} brinca no corredor como se fosse treino.",
]
const SUMMARY_GOOD := ["O grupo saiu ligado.", "A mensagem chegou.", "Clima bom no vestiário."]
const SUMMARY_SPLIT := ["A conversa dividiu o grupo.", "Nem todo mundo gostou do tom."]
const SUMMARY_FLAT := ["O grupo ouviu em silêncio.", "Reação discreta. Difícil saber se a mensagem chegou."]
const SUMMARY_REPEAT := "Era a mesma conversa de antes do jogo. Pegou menos."


## Situação da palestra para escolher as falas: chaves de grupo, da mais específica à geral.
static func situation(sim: MatchSimulation, side: int) -> Array[String]:
	var out: Array[String] = []
	var t: MatchTeam = sim.teams[side]
	var o: MatchTeam = sim.teams[1 - side]
	if not sim.started:
		var fav := (t.u_att + t.u_mid + t.u_def) - (o.u_att + o.u_mid + o.u_def)
		if sim.derby:
			out.append("pre_derby")
		if sim.importance >= 0.7:
			out.append("pre_big")
		if fav > 3.0:
			out.append("pre_fav")
		elif fav < -3.0:
			out.append("pre_under")
		if not sim.neutral:
			out.append("pre_home" if side == 0 else "pre_away")
		out.append("pre")
		return out
	var diff := sim.score[side] - sim.score[1 - side]
	var xd := t.xg - o.xg
	if diff >= 2:
		out.append("half_lead2")
	if diff >= 1:
		out.append("half_lead")
	elif diff == 0:
		out.append("half_level")
	else:
		if diff <= -2:
			out.append("half_behind2")
		out.append("half_behind")
	if xd >= 0.6 and diff <= 0:
		out.append("half_dom")
	elif xd <= -0.6 and diff >= 0:
		out.append("half_suffer")
	out.append("half")
	return out


## Tons oferecidos agora: antes do jogo não há o que lamentar do placar.
static func tones(sim: MatchSimulation) -> Array[String]:
	if not sim.started:
		return ["motivar", "tranquilizar", "confiar", "foco", "exigir", "sem_pressao", "elogiar", "cobrar"]
	return ["motivar", "tranquilizar", "confiar", "foco", "elogiar", "exigir", "decepcao", "cobrar", "sem_pressao"]


## Uma fala por tom para a situação, já com os nomes. [{key, short, text}]
static func options(sim: MatchSimulation, side: int, rng: RandomNumberGenerator) -> Array:
	var sit := situation(sim, side)
	var out: Array = []
	for key in tones(sim):
		var txt := pick_line(key, sit, rng)
		if txt == "":
			continue
		out.append({"key": key, "short": String(MatchSimulation.TALKS[key]["short"]), "text": fill(txt, sim, side)})
	return out


## Sorteia a fala: as listas mais específicas da situação pesam mais que a geral.
static func pick_line(key: String, sit: Array[String], rng: RandomNumberGenerator) -> String:
	var pools: Dictionary = LINES.get(key, {})
	var cand: Array = []
	for i in sit.size():
		var arr: Array = pools.get(sit[i], [])
		var w := 3 if i < sit.size() - 1 else 1
		for line in arr:
			for _k in w:
				cand.append(line)
	if cand.is_empty():
		# Situação sem fala própria neste tom: usa qualquer fala do mesmo momento (antes/intervalo)
		var pre := sit[sit.size() - 1] == "pre"
		for k in pools.keys():
			if String(k).begins_with("pre") == pre:
				cand.append_array(pools[k])
	if cand.is_empty():
		return ""
	return String(cand[rng.randi_range(0, cand.size() - 1)])


static func fill(text: String, sim: MatchSimulation, side: int) -> String:
	var t: MatchTeam = sim.teams[side]
	var o: MatchTeam = sim.teams[1 - side]
	var out := text.replace("{opp}", o.club.short_name)
	out = out.replace("{stadium}", o.club.stadium if side == 1 else t.club.stadium)
	out = out.replace("{star}", _best(t, false))
	out = out.replace("{their}", _best(o, false))
	var gk := o.goalkeeper()
	out = out.replace("{gk}", gk.p.display_name() if gk != null else "goleiro deles")
	out = out.replace("{cap}", captain_name(t))
	return out


## Melhor jogador de linha em campo (o "craque" da fala).
static func _best(t: MatchTeam, gk_ok: bool) -> String:
	var best: MatchPlayer = null
	for mp: MatchPlayer in t.slots:
		if mp == null or (not gk_ok and mp.p.position == Pos.GK):
			continue
		if best == null or mp.p.overall > best.p.overall:
			best = mp
	return best.p.display_name() if best != null else ""


static func captain_id(t: MatchTeam) -> int:
	if t.sheet != null and t.sheet.captain >= 0 and t.by_id.has(t.sheet.captain):
		return t.sheet.captain
	return -1


static func captain_name(t: MatchTeam) -> String:
	var cid := captain_id(t)
	if cid >= 0:
		return (t.by_id[cid] as MatchPlayer).p.display_name()
	return _best(t, false)


## Texto da reação no vestiário: resumo + até 4 jogadores. {summary, lines: [text]}
static func reaction(sim: MatchSimulation, side: int, key: String, up: Array, down: Array, repeat: bool, rng: RandomNumberGenerator) -> Dictionary:
	var t: MatchTeam = sim.teams[side]
	var cid := captain_id(t)
	var summary := ""
	if repeat:
		summary = SUMMARY_REPEAT
	elif up.size() > down.size() + 2:
		summary = SUMMARY_GOOD[rng.randi_range(0, SUMMARY_GOOD.size() - 1)]
	elif down.size() > up.size() or (down.size() >= 2 and up.size() <= down.size() + 1):
		summary = SUMMARY_SPLIT[rng.randi_range(0, SUMMARY_SPLIT.size() - 1)]
	else:
		summary = SUMMARY_FLAT[rng.randi_range(0, SUMMARY_FLAT.size() - 1)]
	var lines: Array = []
	var used: Dictionary = {}
	var ups := up.duplicate()
	if ups.has(cid):
		ups.erase(cid)
		ups.push_front(cid)
	for pid in ups.slice(0, 3):
		var mp: MatchPlayer = t.by_id.get(int(pid), null)
		if mp == null:
			continue
		var pool: Array = REACT_UP_CAP if int(pid) == cid else REACT_UP
		lines.append(_react_line(pool, mp.p.display_name(), used, rng))
	for pid in down.slice(0, 2):
		var mp: MatchPlayer = t.by_id.get(int(pid), null)
		if mp == null:
			continue
		var loose := key in ["elogiar", "sem_pressao"] and (mp.p.has_trait("acomodado") or mp.p.has_trait("festeiro") or mp.p.has_trait("brincalhao"))
		lines.append(_react_line(REACT_LOOSE if loose else REACT_DOWN, mp.p.display_name(), used, rng))
	return {"summary": summary, "lines": lines}


static func _react_line(pool: Array, name: String, used: Dictionary, rng: RandomNumberGenerator) -> String:
	var i := rng.randi_range(0, pool.size() - 1)
	for _k in pool.size():
		if not used.has(pool[i]):
			break
		i = (i + 1) % pool.size()
	used[pool[i]] = true
	return String(pool[i]).replace("{n}", name)
