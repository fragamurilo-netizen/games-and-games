class_name PlayStyle
extends RefCounted
## Estilo de jogo do jogador ("Artilheiro", "Pivô", "Volante destruidor"...), deduzido dos
## atributos em que ele mais se destaca para a posição. Só leitura: o motor já usa os atributos.

## Por posição: [nome, {atributo: peso}]. O estilo escolhido é o de maior média ponderada.
const BY_ROLE: Dictionary = {
	"GK": [
		["Paredão", {Attr.GOL: 1.0, Attr.POS: 0.5}],
		["Goleiro-líbero", {Attr.VEL: 0.6, Attr.PAS: 0.7, Attr.DEC: 0.4}],
		["Goleiro seguro", {Attr.DIS: 0.5, Attr.POS: 0.6, Attr.INT: 0.5}],
	],
	"CB": [
		["Xerife", {Attr.MAR: 1.0, Attr.FOR: 0.7, Attr.CAB: 0.5}],
		["Zagueiro construtor", {Attr.PAS: 0.9, Attr.VIS: 0.5, Attr.TEC: 0.5}],
		["Zagueiro veloz", {Attr.VEL: 1.0, Attr.POS: 0.5}],
		["Líder da defesa", {Attr.INT: 0.6, Attr.POS: 0.8, Attr.DEC: 0.6}],
	],
	"FB": [
		["Lateral apoiador", {Attr.CRU: 0.9, Attr.RES: 0.6, Attr.VEL: 0.6}],
		["Lateral marcador", {Attr.MAR: 0.9, Attr.POS: 0.7, Attr.FOR: 0.3}],
		["Lateral construtor", {Attr.PAS: 0.8, Attr.TEC: 0.6, Attr.VIS: 0.5}],
	],
	"DM": [
		["Volante destruidor", {Attr.MAR: 1.0, Attr.FOR: 0.6, Attr.RES: 0.4}],
		["Volante armador", {Attr.PAS: 0.9, Attr.VIS: 0.7, Attr.DEC: 0.3}],
		["Volante de área a área", {Attr.RES: 0.9, Attr.VEL: 0.4, Attr.FIN: 0.3}],
	],
	"CM": [
		["Box-to-box", {Attr.RES: 0.8, Attr.MAR: 0.3, Attr.FIN: 0.4}],
		["Maestro", {Attr.PAS: 0.9, Attr.VIS: 0.9, Attr.TEC: 0.4}],
		["Condutor", {Attr.TEC: 0.8, Attr.VEL: 0.6, Attr.FOR: 0.3}],
	],
	"AM": [
		["Camisa 10", {Attr.VIS: 1.0, Attr.PAS: 0.7, Attr.TEC: 0.6}],
		["Meia-atacante", {Attr.FIN: 0.9, Attr.TEC: 0.5, Attr.DEC: 0.4}],
		["Driblador", {Attr.TEC: 1.0, Attr.VEL: 0.6}],
	],
	"W": [
		["Ponta driblador", {Attr.TEC: 1.0, Attr.VEL: 0.7}],
		["Ponta goleador", {Attr.FIN: 1.0, Attr.DEC: 0.5, Attr.VEL: 0.4}],
		["Ponta cruzador", {Attr.CRU: 1.0, Attr.RES: 0.4}],
		["Flecha", {Attr.VEL: 1.2}],
	],
	"ST": [
		["Artilheiro", {Attr.FIN: 1.0, Attr.DEC: 0.6, Attr.POS: 0.4}],
		["Pivô", {Attr.FOR: 0.9, Attr.CAB: 0.8, Attr.PAS: 0.3}],
		["Centroavante veloz", {Attr.VEL: 1.0, Attr.FIN: 0.5}],
		["Cabeceador", {Attr.CAB: 1.0, Attr.FIN: 0.5}],
		["Falso 9", {Attr.PAS: 0.7, Attr.VIS: 0.7, Attr.TEC: 0.6}],
	],
}


static func _role(pos: int) -> String:
	match pos:
		Pos.GK:
			return "GK"
		Pos.CB:
			return "CB"
		Pos.RB, Pos.LB:
			return "FB"
		Pos.DM:
			return "DM"
		Pos.CM:
			return "CM"
		Pos.AM:
			return "AM"
		Pos.RM, Pos.LM, Pos.RW, Pos.LW:
			return "W"
	return "ST"


static func of(p: Player) -> String:
	var best := ""
	var best_v := -1.0
	for opt in BY_ROLE[_role(p.position)]:
		var w: Dictionary = opt[1]
		var s := 0.0
		var t := 0.0
		for a in w:
			s += p.attrs[a] * float(w[a])
			t += float(w[a])
		var v := s / t
		if v > best_v:
			best_v = v
			best = opt[0]
	return best
