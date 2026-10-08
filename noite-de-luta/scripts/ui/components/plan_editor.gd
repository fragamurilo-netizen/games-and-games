class_name PlanEditor
extends RefCounted
## Editor do plano de luta: cada escolha é um seletor curto; a explicação fica embaixo.


static func build(plan: Dictionary, on_change: Callable, with_help: bool = true) -> VBoxContainer:
	var v := UIKit.vbox(UITokens.S2)
	for fd: Array in FightPlan.FIELDS:
		var key := String(fd[0])
		var box := UIKit.vbox(4)
		box.add_child(UIKit.label(String(fd[1]), "Caps"))
		var items: Array = []
		var opts: Array = fd[2]
		for i in opts.size():
			items.append([str(i), String(opts[i])])
		box.add_child(UIKit.segment(items, str(int(plan.get(key, 0))), func(k: String):
			plan[key] = int(k)
			on_change.call()))
		if with_help:
			box.add_child(UIKit.label(String(fd[3]), "Meta", true))
		v.add_child(box)
	return v


## Leitura do técnico: por que o plano sugerido é esse (o que ele viu nos dois).
static func coach_read(me: Fighter, opp: Fighter) -> String:
	var lines: Array = []
	if opp.a("queda") > me.a("def_queda") + 6.0:
		lines.append("%s derruba bem e a nossa defesa de queda não é das melhores." % opp.short_name())
	elif me.a("queda") > opp.a("def_queda") + 6.0:
		lines.append("Dá para derrubar %s: a defesa de queda dele é fraca." % opp.short_name())
	if opp.a("potencia") > me.a("queixo") + 8.0:
		lines.append("Cuidado com a mão pesada de %s." % opp.short_name())
	if me.a("cardio") > opp.a("cardio") + 7.0:
		lines.append("Temos mais fôlego: o terceiro round é nosso se aguentarmos o ritmo.")
	elif opp.a("cardio") > me.a("cardio") + 7.0:
		lines.append("Ele tem mais tanque. Não adianta acelerar cedo demais.")
	if opp.a("finalizacao") > me.a("def_finalizacao") + 8.0:
		lines.append("No chão, %s finaliza. Melhor não ficar por baixo." % opp.short_name())
	if opp.a("chutes") > opp.a("maos") + 6.0:
		lines.append("%s gosta de chutar de longe: encurtar a distância tira a arma dele." % opp.short_name())
	if me.reach_cm > opp.reach_cm + 6:
		lines.append("Temos %d cm a mais de envergadura." % (me.reach_cm - opp.reach_cm))
	if lines.is_empty():
		lines.append("Luta parelha. Quem errar menos ganha.")
	return " ".join(lines)
