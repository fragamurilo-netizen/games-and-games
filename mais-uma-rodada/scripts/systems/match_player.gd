class_name MatchPlayer
extends RefCounted
## Estado de um jogador durante uma partida. Os compostos de atributos são calculados
## uma vez em prepare() (os atributos não mudam durante o jogo).

var p: Player
var slot: int = -1 # vaga na formação (-1 = banco/fora)
var pos: int = Pos.CM
var role: String = "CM"
var instr: Dictionary = {} # instrução individual (TeamSheet.INSTRUCTIONS)
var w_def: float = 0.0
var w_mid: float = 0.0
var w_att: float = 0.0
var w_wide: float = 0.0
var slot_rating: float = 50.0
var on_pitch: bool = false
var used: bool = false # entrou em campo em algum momento
var start_min: int = 0
var end_min: int = -1
var cond: float = 100.0
var perf: float = 1.0 # desempenho do dia (consistência)
var ctx: float = 1.0 # contexto (clássico/jogo grande × personalidade)
var fam: float = 1.0 # familiaridade com a vaga
var base_f: float = 1.0 # moral × forma × desempenho × contexto
var f: float = 1.0 # fator total (atualizado com a fadiga)
var sh_f: float = 1.0 # reação ao grito do técnico (incentivo/cobrança), enquanto durar
var card_mult: float = 1.0
var clutch: float = 0.0
var injury_f: float = 1.0
var rating_pts: float = 0.0
var goals: int = 0
var assists: int = 0
var shots: int = 0
var shots_on: int = 0
var saves: int = 0
var fouls: int = 0
var yellow: int = 0
var red: bool = false
var injured: bool = false
var injury_weeks: int = 0
var own_goals: int = 0
var final_rating: float = 6.0

# Compostos cacheados
var c_def: float = 50.0
var c_mid: float = 50.0
var c_att: float = 50.0
var c_gk: float = 50.0
var c_aer: float = 50.0
var c_fin: float = 50.0
var c_head: float = 50.0
var c_long: float = 50.0
var a_vel: float = 50.0
var a_tec: float = 50.0
var a_dis: float = 50.0
var a_dec: float = 50.0
var a_res: float = 50.0
var a_cru: float = 50.0
var a_int: float = 50.0
var a_pas_vis: float = 100.0
var a_tec_vel: float = 100.0
var a_vel_fin: float = 100.0
var fit_cache: Dictionary = {}
# Bases sem o efeito do pé (a vaga muda com substituições e trocas de formação)
var _b_cru: float = 50.0
var _b_fin: float = 50.0
var _b_long: float = 50.0
var _b_tv: float = 100.0


func prepare() -> void:
	var a := p.attrs
	c_def = a[Attr.MAR] * 0.18 + a[Attr.DES] * 0.14 + a[Attr.POS] * 0.28 + a[Attr.FOR] * 0.1 + a[Attr.CAB] * 0.1 + a[Attr.VEL] * 0.1 + a[Attr.DEC] * 0.1
	c_mid = a[Attr.PAS] * 0.3 + a[Attr.VIS] * 0.2 + a[Attr.TEC] * 0.12 + a[Attr.DRI] * 0.08 + a[Attr.DEC] * 0.15 + a[Attr.RES] * 0.15
	c_att = a[Attr.FIN] * 0.25 + a[Attr.TEC] * 0.1 + a[Attr.DRI] * 0.12 + a[Attr.VEL] * 0.12 + a[Attr.ACE] * 0.08 + a[Attr.DEC] * 0.1 + a[Attr.POS] * 0.13 + a[Attr.FRI] * 0.1
	# Corpo: altura e peso na bola aérea e no choque; peso demais tira velocidade e fôlego
	var aer := Physique.aerial(p)
	var strg := Physique.strength(p)
	var heavy := Physique.pace_penalty(p)
	c_def += strg * 0.25
	c_gk = a[Attr.GOL] * 0.4 + a[Attr.REF] * 0.22 + a[Attr.POS] * 0.2 + a[Attr.DEC] * 0.1 + a[Attr.FRI] * 0.08 + Physique.gk_reach(p)
	c_aer = a[Attr.CAB] * 0.7 + a[Attr.FOR] * 0.3 + aer
	c_fin = a[Attr.FIN] * 0.6 + a[Attr.FRI] * 0.15 + a[Attr.DEC] * 0.1 + a[Attr.TEC] * 0.15
	c_head = a[Attr.CAB] * 0.7 + a[Attr.POS] * 0.2 + a[Attr.FOR] * 0.1 + aer * 0.6
	c_long = a[Attr.CHL] * 0.6 + a[Attr.FIN] * 0.15 + a[Attr.TEC] * 0.25
	a_vel = a[Attr.VEL] - heavy
	a_tec = a[Attr.TEC]
	a_dis = a[Attr.DIS]
	a_dec = a[Attr.DEC]
	a_res = a[Attr.RES] - heavy * 0.6
	a_cru = a[Attr.CRU]
	a_int = a[Attr.INT]
	a_pas_vis = a[Attr.PAS] + a[Attr.VIS]
	a_tec_vel = a[Attr.TEC] * 0.4 + a[Attr.DRI] * 0.6 + a_vel * 0.5 + (a[Attr.ACE] - heavy) * 0.5
	a_vel_fin = a_vel + a[Attr.FIN]
	_b_cru = a_cru
	_b_fin = c_fin
	_b_long = c_long
	_b_tv = a_tec_vel
	var morale_f := 0.96 + p.morale / 100.0 * 0.08
	var form_f := clampf(1.0 + (p.form() - 6.5) * 0.012, 0.97, 1.03)
	base_f = morale_f * form_f * perf * ctx


## Pé x lado da vaga: chamado sempre que o jogador assume uma vaga.
func apply_side(slot_pos: int) -> void:
	var m := Physique.side_mods(p, slot_pos)
	a_cru = _b_cru + float(m[0])
	c_fin = _b_fin + float(m[1])
	c_long = _b_long + float(m[2])
	a_tec_vel = _b_tv + float(m[3])


func minutes_played(final_minute: int) -> int:
	if not used:
		return 0
	var e := end_min if end_min >= 0 else final_minute
	return clampi(e - start_min, 0, 130)


func attr(i: int) -> float:
	return float(p.attrs[i])


func finishing() -> float:
	return c_fin


func heading() -> float:
	return c_head


func long_shot() -> float:
	return c_long


func gk_comp() -> float:
	return c_gk


## Média dos atributos que tornam um estilo eficiente (cacheada por estilo).
func style_fit_value(style: int, attr_ids: Array) -> float:
	if fit_cache.has(style):
		return fit_cache[style]
	var s := 0.0
	for ai in attr_ids:
		s += p.attrs[ai]
	var v := s / maxf(1.0, attr_ids.size())
	fit_cache[style] = v
	return v
