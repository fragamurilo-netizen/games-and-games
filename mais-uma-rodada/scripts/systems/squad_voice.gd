class_name SquadVoice
extends RefCounted
## Jeito de falar de cada jogador. A mesma intenção ("concordo", "fiquei chateado", "bora!")
## sai diferente para o tímido, o esquentado, o líder, a estrela, o veterano, o garoto e o
## gringo que ainda não domina a língua. Tudo procedural: pools por voz + pools gerais,
## com trocas de vocativo, bordões e um tempero de quem acabou de chegar.
##
## Uso: SquadVoice.say(world, p, "agree", r) → String pronta para o balão.

const VOICES := ["timido", "esquentado", "lider", "estrela", "veterano", "garoto", "gringo", "festeiro", "profissional"]


## A voz dominante do jogador (uma só, para as falas soarem consistentes).
static func voice(world: GameWorld, p: Player) -> String:
	if p == null:
		return "_"
	var club := world.club(p.club_id)
	if club != null and _foreign_new(world, p, club):
		return "gringo"
	if HiddenPersona.hot_head(p) or p.has_trait("provocador") or p.has_trait("rebelde"):
		return "esquentado"
	if p.has_trait("timido") or p.has_trait("inseguro"):
		return "timido"
	if p.has_trait("lider") or p.has_trait("cascudo") or int(People.data(world).get("captain", -1)) == p.id:
		return "lider"
	if p.has_trait("estrela") or p.squad_status == Player.STATUS_STAR:
		return "estrela"
	if p.has_trait("festeiro"):
		return "festeiro"
	if p.age(world.year) >= 31:
		return "veterano"
	if p.age(world.year) <= 20:
		return "garoto"
	if p.has_trait("profissional") or p.has_trait("disciplinado") or p.has_trait("perfeccionista"):
		return "profissional"
	return "_"


static func _lang(code: String) -> String:
	var lg := String(DatabaseManager.nation(code).get("lang", ""))
	return lg if lg != "" else code


## Estrangeiro de outra língua no primeiro ano no clube.
static func _foreign_new(world: GameWorld, p: Player, club: Club) -> bool:
	if p.nationality == club.nation:
		return false
	var a := _lang(p.nationality).get_slice("_", 0)
	var b := _lang(club.nation).get_slice("_", 0)
	return a != b and world.year - p.joined_year <= 1 and p.hid("ada") < 16


## Como ele chama o treinador.
static func addr(world: GameWorld, p: Player, r: RandomNumberGenerator) -> String:
	if p == null:
		return "professor"
	var lg := _lang(p.nationality)
	if lg == "pt":
		return "mister"
	if lg == "es":
		return RngUtil.pick(r, ["míster", "profe"])
	if voice(world, p) == "gringo":
		return RngUtil.pick(r, ["coach", "mister", "professor"])
	if p.age(world.year) >= 31 or voice(world, p) == "lider":
		return RngUtil.pick(r, ["professor", "chefe", "professor"])
	return RngUtil.pick(r, ["professor", "professor", "prof", "chefe"])


static func _fill(world: GameWorld, p: Player, text: String, r: RandomNumberGenerator) -> String:
	var club := world.user_club() if world.has_user() else null
	var a := addr(world, p, r)
	var out := text.replace("{a}", a).replace("{A}", a.capitalize())
	if club != null:
		out = out.replace("{c}", club.short_name)
	out = out.replace("{n}", p.display_name() if p != null else "")
	return out


## Uma fala da intenção pedida, na voz do jogador.
static func say(world: GameWorld, p: Player, intent: String, r: RandomNumberGenerator) -> String:
	var pools: Dictionary = LINES.get(intent, {})
	if pools.is_empty():
		return ""
	var v := voice(world, p)
	var pool: Array = []
	if pools.has(v):
		pool.append_array(pools[v])
		pool.append_array(pools[v]) # a voz pesa o dobro
	pool.append_array(pools.get("_", []))
	if pool.is_empty():
		return ""
	var text := _fill(world, p, String(RngUtil.pick(r, pool)), r)
	if v == "gringo" and r.randf() < 0.45:
		text = String(RngUtil.pick(r, GRINGO_OPEN)) + text[0].to_lower() + text.substr(1)
	elif r.randf() < 0.18 and TAILS.has(v):
		text += " " + _fill(world, p, String(RngUtil.pick(r, TAILS[v])), r)
	return text


const GRINGO_OPEN := ["Desculpa o português... ", "Como se diz... ", "Eu ainda aprendendo a língua, mas... ", "Ahn... ", "Meu tradutor não está aqui, então... "]

## Bordões que às vezes fecham a fala.
const TAILS := {
	"esquentado": ["E não vou ficar quieto.", "Falo mesmo.", "Quem quiser que fique chateado."],
	"lider": ["O grupo está comigo nisso.", "Pode contar com o vestiário.", "Vou passar isso para os meninos."],
	"estrela": ["Todo mundo sabe o que eu entrego.", "Jogador grande precisa de confiança.", "Meu empresário concorda."],
	"veterano": ["Já vi muita coisa nesse futebol.", "Na minha idade a gente não perde tempo.", "Já passei por isso antes."],
	"garoto": ["Tô aprendendo todo dia.", "Minha mãe vai ficar feliz.", "É um sonho, {a}."],
	"festeiro": ["Mas vida é pra ser vivida, né?", "Depois a gente comemora.", "Relaxa, {a}."],
	"profissional": ["Vou ajustar o que for preciso.", "Já estou pensando no próximo treino.", "Foco total."],
	"timido": ["...", "Só isso mesmo.", "Desculpa qualquer coisa."],
}

const LINES := {
	"greet_hi": {
		"_": ["Fala, {a}! Pode falar.", "Opa, {a}. Tô à disposição.", "Bom te ver, {a}. O que manda?", "Diz aí, {a}! Tá tudo certo?", "Chegou em boa hora, {a}. Senta aí."],
		"lider": ["{A}, pode falar. Se for sobre o grupo, eu já sei de algumas coisas.", "Tô aqui, {a}. Manda."],
		"garoto": ["Oi, {a}! Fiz alguma coisa errada?", "{A}! Pode falar, tô ouvindo."],
		"estrela": ["Fala, {a}. Tava querendo mesmo trocar uma ideia.", "E aí, {a}? Bora conversar."],
		"festeiro": ["Fala, {a}! Que cara séria é essa?", "Opa, {a}, se for sobre sábado eu explico!"],
		"gringo": ["Oi, {a}! Tudo bem? Pode falar devagar.", "Olá, {a}. Eu escuto."],
	},
	"greet_mid": {
		"_": ["Pois não, {a}?", "Pode falar, {a}.", "Diga, {a}.", "Sim, {a}?", "O senhor me chamou?"],
		"timido": ["...Pois não, {a}?", "Oi, {a}. Aconteceu alguma coisa?"],
		"veterano": ["Diga, {a}. Tô ouvindo.", "Vamos lá, {a}."],
		"profissional": ["Pode falar, {a}. Quero ouvir.", "Diga, {a}. No que eu posso melhorar?"],
	},
	"greet_low": {
		"_": ["...Oi. O senhor queria falar comigo?", "Diga.", "Tô ouvindo.", "Hm. Pode falar."],
		"esquentado": ["Se for pra me encher, nem começa.", "Fala logo, {a}. Tenho treino.", "Agora o senhor lembra de mim?"],
		"estrela": ["Achei que o senhor nem lembrava que eu existia.", "Quer falar agora? Tá bom."],
		"timido": ["...", "Tá bom, {a}."],
		"veterano": ["Sei como isso funciona, {a}. Pode falar.", "Vamos ser diretos, {a}."],
	},
	"agree": {
		"_": ["Fechado, {a}.", "Pode deixar.", "Entendi. Vou fazer.", "Tá certo, {a}. Conta comigo.", "Valeu pela conversa, {a}."],
		"lider": ["Pode deixar comigo. Ninguém larga o barco.", "Vou puxar a fila, {a}.", "É isso. O grupo vai entender."],
		"esquentado": ["Beleza. Mas vou cobrar isso depois, hein.", "Tá, tá. Fechado."],
		"timido": ["Tá bom, {a}. Obrigado.", "Vou tentar, {a}."],
		"estrela": ["Isso. É assim que se fala com quem decide.", "Agora sim, {a}."],
		"garoto": ["Valeu, {a}! Vou dar tudo!", "Nossa, obrigado, {a}! Não vou decepcionar."],
		"veterano": ["Combinado. Palavra de homem.", "É isso. Simples assim."],
		"gringo": ["Ok, ok. Entendi. Obrigado.", "Sim! Eu entendo. Vamos."],
		"festeiro": ["Fechou, {a}! Tamo junto!", "Bora, {a}! Aqui é alegria e trabalho."],
		"profissional": ["Entendido. Vou ajustar já no próximo treino.", "Perfeito, {a}. É isso que eu precisava ouvir."],
	},
	"neutral": {
		"_": ["Vou pensar no que o senhor falou.", "Entendi.", "Tá. Vamos ver.", "Ok, {a}.", "Pode ser."],
		"esquentado": ["Hum. Vamos ver se é verdade.", "Tá. Mas eu não esqueço fácil."],
		"estrela": ["Vamos ver, {a}. Palavra é uma coisa, campo é outra.", "Hum. Ok."],
		"timido": ["...Tá bom.", "Se o senhor diz..."],
		"veterano": ["Já ouvi isso antes, {a}. Mas vou esperar.", "Vamos ver."],
	},
	"refuse": {
		"_": ["Não concordo, {a}.", "Isso não é justo.", "Esperava outra coisa do senhor.", "Então tá. Beleza.", "Assim fica difícil, {a}."],
		"esquentado": ["Isso é piada, né? Não vou aceitar calado.", "Então é assim? Vou falar com quem tiver que falar.", "Eu não sou moleque, {a}!"],
		"timido": ["...Tá bom, {a}.", "Eu... não sei o que dizer."],
		"estrela": ["O senhor sabe quem está falando com o senhor?", "Meu empresário vai gostar de saber disso.", "Tem clube grande me querendo, {a}."],
		"veterano": ["Com todo respeito, {a}, isso não se faz.", "Eu já dei muito por esse clube."],
		"lider": ["Não é assim que se trata o grupo, {a}.", "O vestiário não vai gostar disso."],
		"gringo": ["Não... eu não entendo por que.", "Isso não é bom, {a}."],
		"garoto": ["Eu... tá. Desculpa, {a}.", "Tá bom. Eu entendi."],
	},
	"hurt": {
		"_": ["Fiquei chateado, não vou mentir.", "Isso doeu, {a}.", "Não esperava isso."],
		"timido": ["...", "Tá bom. Com licença, {a}."],
		"esquentado": ["Isso não vai ficar assim.", "Tá de brincadeira comigo."],
	},
	"grateful": {
		"_": ["Valeu mesmo, {a}.", "Obrigado pela confiança.", "Isso me dá moral.", "Vou retribuir em campo."],
		"timido": ["Obrigado, {a}. De verdade.", "Nossa... valeu."],
		"garoto": ["Vou contar pra minha família!", "Obrigado, {a}! Não vou esquecer."],
		"veterano": ["Na minha idade, isso vale ouro.", "Obrigado. Ainda tenho lenha pra queimar."],
		"gringo": ["Obrigado! Muito obrigado!", "Eu fico feliz aqui. Obrigado."],
	},
	# Reunião com o grupo: quem levanta a mão para falar
	"meet_bad": {
		"_": ["{A}, o grupo sabe que está devendo. Mas ninguém aqui está largando o barco.", "A gente precisa se olhar no espelho antes de apontar dedo.", "Tá faltando conversa dentro de campo. Cada um está jogando por si."],
		"lider": ["Eu falo pelo grupo: a responsabilidade é nossa. Vamos virar isso juntos.", "Quem não estiver disposto a sofrer, pode sair da sala agora."],
		"esquentado": ["Tem gente aqui que não corre. Não vou citar nome, mas todo mundo sabe.", "Enquanto uns se matam, outros ficam passeando em campo."],
		"veterano": ["Já passei por fase pior. O segredo é não se desesperar e treinar dobrado.", "Os mais novos estão sentindo. A gente precisa proteger eles."],
		"estrela": ["Se a bola chegar, eu resolvo. Mas não está chegando.", "Precisamos de mais bola no pé de quem decide."],
		"garoto": ["...Eu só queria dizer que tô pronto se precisar.", "A gente acredita, {a}."],
	},
	"meet_good": {
		"_": ["O ambiente está bom, {a}. Dá pra sentir no treino.", "Ninguém aqui está satisfeito ainda. Queremos mais.", "É manter a humildade e seguir."],
		"lider": ["Agora é que a cobrança aumenta. Ninguém relaxa.", "Tá todo mundo fechado. Isso é o mais importante."],
		"festeiro": ["O clima tá ótimo! Churrasco no fim de semana?", "Vestiário assim dá gosto!"],
		"estrela": ["Quando o time joga pra frente, eu apareço. Continua assim.", "É isso. Agora é buscar título."],
		"veterano": ["Já vi time perder o rumo depois de sequência boa. Pé no chão.", "Aproveitem, meninos. Isso não é sempre."],
	},
	"meet_complain": {
		"_": ["Tem gente que não tem chance nenhuma, {a}. Isso desanima.", "Os treinos estão pesados demais. O corpo está sentindo.", "Falta clareza sobre quem joga e por quê."],
		"esquentado": ["Queria saber qual é o critério pra escalar. Porque eu não entendo.", "Tem panelinha nesse time, {a}. Todo mundo vê."],
		"estrela": ["O prêmio da vitória podia ser melhor, né?", "Eu preciso jogar mais perto do gol."],
		"gringo": ["Para nós que chegamos agora é difícil. Ninguém explica nada.", "Eu queria mais ajuda com a língua, a cidade..."],
		"garoto": ["Os mais novos quase não treinam com o time principal.", "A gente queria mais chance, {a}."],
	},
}
