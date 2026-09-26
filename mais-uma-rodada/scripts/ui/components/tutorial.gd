class_name Tutorial
extends RefCounted
## Tutorial curto: poucos cartões na primeira vez que o hub abre. Pode ser revisto nas opções.

const STEPS := [
	["home", "Bem-vindo, treinador", "O hub é a sua central. A próxima partida fica no centro, com o que está em jogo nela. Toque em JOGAR para escalar o time e entrar em campo."],
	["tactics", "Escalação e tática", "No pré-jogo, toque em um jogador no campo para trocá-lo. Formação, mentalidade e estilo mudam de verdade o jeito do time jogar — e o encaixe com o seu elenco conta."],
	["whistle", "A partida", "Assista em velocidade normal, rápida ou turbo. Pause quando quiser para trocar jogadores, mudar a mentalidade ou o estilo. Tudo o que acontece sai da simulação: nada é roteirizado."],
	["swap", "Mercado", "Com a janela aberta, faça propostas, negocie salários e venda quem não joga. Jogadores livres podem ser contratados a qualquer momento da temporada."],
	["trophy", "Diretoria e torcida", "A diretoria tem uma meta para a temporada e acompanha resultados, clássicos e contas. A torcida sente cada jogo. Muito tempo abaixo da meta e o cargo balança."],
	["save", "Salvamento automático", "O jogo salva sozinho a cada rodada e quando o app sai de cena. Quando quiser parar, é só sair: a sua carreira espera por você."],
]


static func maybe_show() -> void:
	if AppSettings.tutorial_done:
		return
	AppSettings.tutorial_done = true
	AppSettings.save_settings()
	show_all()


static func show_all() -> void:
	_show_step(0)


static func _show_step(i: int) -> void:
	var s: Array = STEPS[i]
	var v := UIKit.vbox(16)
	v.custom_minimum_size.x = 600
	var head := UIKit.hbox(14)
	head.add_child(UIKit.icon_rect(s[0], 56, UIColors.ACCENT))
	var t := UIKit.label(s[1], "Title", true)
	head.add_child(t)
	v.add_child(head)
	v.add_child(UIKit.label(s[2], "", true))
	var dots := UIKit.label("%d de %d" % [i + 1, STEPS.size()], "Caps")
	v.add_child(dots)
	var row := UIKit.hbox(10)
	var last := i == STEPS.size() - 1
	if not last:
		var skip := UIKit.button("Pular", "GhostButton", func(): UIManager.close_modal())
		skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(skip)
	var nxt := UIKit.button("Começar" if last else "Próximo", "PrimaryButton", func():
		UIManager.close_modal()
		if not last:
			_show_step(i + 1))
	nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nxt.add_theme_font_size_override(&"font_size", 28)
	row.add_child(nxt)
	v.add_child(row)
	UIManager.show_modal(v, false, false)
