class_name MatchTeam
extends RefCounted
## Um lado da partida: escalação viva, tática (com números cacheados) e setores
## (DEF/MEI/ATA em "pontos de rating", comparáveis ao overall).

var side: int = 0
var club: Club
var sheet: TeamSheet
## Lados do campo (0 esquerda, 1 centro, 2 direita, do ponto de vista do próprio time): força de
## ataque e de cobertura defensiva de cada corredor, pelo desenho e por quem está em campo.
var lane_att: Array[float] = [1.0, 1.0, 1.0]
var lane_def: Array[float] = [1.0, 1.0, 1.0]
var formation: Dictionary
var formation_name: String = "4-4-2"
## Formação trocada durante o jogo (a IA muda no máximo uma vez).
var formation_changed: bool = false
var slots: Array[MatchPlayer] = [] # por vaga (null = vaga vazia após expulsão/lesão sem troca)
var bench: Array[MatchPlayer] = []
var all: Array[MatchPlayer] = [] # titulares + banco
var by_id: Dictionary = {}
var subs_used: int = 0
var max_subs: int = 5
var is_user: bool = false
var auto_subs: bool = true

var mentality: int = 2
var base_mentality: int = 2
var style: int = 0
var intensity: int = 1
var line: int = 1
var pressing: int = 1
## Situação do placar em que o plano de jogo agiu por último (-1 = ainda não agiu).
var plan_state: int = -1

var cohesion_f: float = 1.0
## Parte do entrosamento que vem do elenco (sem a familiaridade com formação/estilo).
var cohesion_base: float = 1.0
## Ajuste de setor pelo foco de treino da semana (só no time do usuário).
var train_att: float = 1.0
var train_def: float = 1.0
## Bola parada ensaiada no treino (TrainingManager.set_piece_bonus): escanteios e faltas.
var sp_bonus: float = 0.0
var home_f: float = 1.0
## Dia do time (inspirado ou apagado), sorteado antes do jogo: dá variação real aos resultados.
var day_f: float = 1.0
## Efeito do placar: quem perde pressiona (mais chances, piores), quem vence recua e sai no
## contra-ataque (menos chances, melhores). Recalculado a cada gol e ao longo do jogo.
var g_rate: float = 1.0
var g_quality: float = 1.0
var g_poss: float = 0.0
## Trabalho do técnico e fase do time (TeamEvolution): entra direto no fator individual.
var evo_f: float = 1.0
## Largura em campo (0 fechado, 1 normal, 2 aberto): começa na da escalação e muda no jogo.
var width_i: int = 1
## Estudo do rival (TacticalScout.exploit): peso e qualidade por tipo de jogada.
var exploit_w: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1, 1, 1])
var exploit_q: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1, 1, 1])
## Massa de meio-campo (soma dos pesos de meio) e técnica com a bola sob pressão.
var mid_mass: float = 4.0
var press_tech: float = 55.0
## Leitura do jogo (IA do banco e auxiliar): chances sofridas por corredor (do ponto de vista
## de quem defende) e por tipo; xG sofrido; decisões táticas já tomadas no jogo.
var lane_conc: Array[int] = [0, 0, 0]
var ct_conc: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
var xg_conc: float = 0.0
var ai_reads: int = 0
## Vulnerabilidade do rival por tipo de jogada e qualidade do estudo de quem prepara o time.
var vuln: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1, 1, 1])
var study: float = 0.5
## Quanto o técnico se dispõe a mudar o plano (filosofia do clube; o usuário decide sozinho).
var adapt: float = 0.5

# --- Números táticos cacheados (evita dicionários no laço quente) ---
var m_att: float = 1.0
var m_def: float = 1.0
var m_poss: float = 0.0
var s_rate: float = 1.0
var s_quality: float = 1.0
var s_fatigue: float = 1.0
var s_poss: float = 0.0
var s_types: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1, 1, 1])
var s_fit_attrs: Array = []
var s_vs_open: float = 0.0
var s_vs_narrow: float = 0.0
var s_ignores_press: bool = false
var i_perf: float = 1.0
var i_fatigue: float = 1.0
var i_fouls: float = 1.0
var l_opp_rate: float = 1.0
var l_opp_quality: float = 1.0
var l_offside: float = 1.0
# Grito da beira do campo em vigor (MatchSimulation.shout): multiplicadores temporários
var sh_key: String = ""
var sh_until: int = -1 # minuto em que o efeito acaba
var sh_next: int = 0 # próximo minuto em que dá para gritar de novo
var sh_uses: Dictionary = {} # grito -> vezes usado (repetir perde efeito)
var talk_half: int = -1 # tempo em que a última palestra foi dada (0 = antes do jogo)
var talk_key: String = ""
var sh_att: float = 1.0
var sh_def: float = 1.0
var sh_poss: float = 0.0
var sh_fouls: float = 1.0
var sh_fatigue: float = 1.0
var sh_opp_rate: float = 1.0
var l_poss: float = 0.0
var pr_poss: float = 0.0
var pr_fatigue: float = 1.0
var pr_opp_rate: float = 1.0
var pr_fouls: float = 1.0
# --- Instruções de equipe (TacticsManager.deep_mods) + estilos dos jogadores em campo ---
var deep: Array = [1, 1, 0, 1, 1, 0, 0] # TeamSheet.deep_values()
var _dm: Dictionary = {}
var x_rate: float = 1.0
var x_quality: float = 1.0
var x_opp_rate: float = 1.0
var x_opp_quality: float = 1.0
var x_poss: float = 0.0
var x_fatigue: float = 1.0
var x_fouls: float = 1.0
var x_cards: float = 1.0
var x_offside: float = 1.0 # impedimentos do rival (armadilha da própria linha)
var x_offside_own: float = 1.0
var x_corner_ch: float = 1.0
var x_corner_q: float = 1.0
var x_aerial: float = 1.0
## Peso final de cada tipo de jogada do time e do rival (instruções × estilos dos jogadores).
var t_types: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1, 1, 1])
var t_opp_types: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1, 1, 1])
var leading: bool = false
## Adversário (referência fraca: sem ciclo entre os dois times) para a marcação individual.
var opp_ref: WeakRef = null
## Corredores antes do foco de ataque (para medir se o foco vai no lado fraco do rival).
var lane_raw: Array[float] = [1.0, 1.0, 1.0]
# Somas dos estilos em campo (recompute_units)
var _ps_t: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _ps_o: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _ps_poss: float = 0.0
var _ps_off: float = 0.0
var _fit_pts: Array = []

# --- Setores (pontos de rating) ---
var u_def: float = 50.0
var u_mid: float = 50.0
var u_att: float = 50.0
var u_gk: float = 50.0
var aerial_att: float = 50.0
var aerial_def: float = 50.0
var width: float = 2.0
var pace_att: float = 50.0
var pace_def: float = 50.0
var tech: float = 50.0
var discipline: float = 60.0
var avg_decision: float = 50.0
var style_fit: float = 0.0
var on_pitch_count: int = 11
# Normas da formação copiadas (evita acesso a dados compartilhados nas threads)
var norm_def: float = 4.8
var norm_mid: float = 4.2
var norm_att: float = 3.8

# --- Tabelas de escolha (peso por vaga para cada modo; recalculadas com os setores) ---
const PICK_MODES := 9
var pick_w: Array[PackedFloat32Array] = []
var pick_total: PackedFloat32Array = PackedFloat32Array()

# --- Estatísticas ---
var shots: int = 0
var on_target: int = 0
var corners: int = 0
var fouls: int = 0
var yellows: int = 0
var reds: int = 0
var offsides: int = 0
var saves: int = 0
var xg: float = 0.0
var poss_ticks: int = 0


func refresh_tactics() -> void:
	var t: Dictionary = DatabaseManager.tactics()
	var m: Dictionary = t["mentalities"][mentality]
	m_att = MatchSimulation.damp(float(m["att"]))
	m_def = MatchSimulation.damp(float(m["def"]))
	m_poss = float(m["poss"]) * MatchSimulation.MOD_DAMP
	var s: Dictionary = t["styles"][style]
	s_rate = MatchSimulation.damp(float(s["rate"]))
	s_quality = MatchSimulation.damp(float(s["quality"]))
	s_fatigue = float(s["fatigue"])
	s_poss = float(s["poss"]) * MatchSimulation.MOD_DAMP
	var types: Dictionary = s["types"]
	s_types = PackedFloat32Array([float(types.get("through", 1.0)), float(types.get("cross", 1.0)), float(types.get("long", 1.0)),
		float(types.get("dribble", 1.0)), float(types.get("counter", 1.0)), float(types.get("scramble", 1.0))])
	var ex := TacticalScout.exploit(s_types, vuln, study)
	exploit_w = ex[0]
	exploit_q = ex[1]
	s_vs_open = float(s.get("vs_open_bonus", 0.0)) * MatchSimulation.MOD_DAMP
	s_vs_narrow = float(s.get("vs_narrow_bonus", 0.0)) * MatchSimulation.MOD_DAMP
	s_ignores_press = bool(s.get("ignores_press", false))
	s_fit_attrs.clear()
	for code in s.get("fit", []):
		s_fit_attrs.append(DatabaseManager.attr_index(code))
	var i: Dictionary = t["intensity"][intensity]
	i_perf = float(i["perf"])
	i_fatigue = float(i["fatigue"])
	i_fouls = float(i["fouls"])
	var l: Dictionary = t["line"][line]
	l_opp_rate = MatchSimulation.damp(float(l["opp_rate"]))
	l_opp_quality = MatchSimulation.damp(float(l["opp_quality"]))
	l_offside = float(l["offside"])
	l_poss = float(l["poss"]) * MatchSimulation.MOD_DAMP
	var p: Dictionary = t["pressing"][pressing]
	pr_poss = float(p["poss"]) * MatchSimulation.MOD_DAMP
	pr_fatigue = float(p["fatigue"])
	pr_opp_rate = MatchSimulation.damp(float(p["opp_rate"]))
	pr_fouls = float(p["fouls"])
	_dm = TacticsManager.deep_mods(deep)
	x_corner_ch = float(_dm["corner_ch"])
	x_corner_q = float(_dm["corner_q"])
	x_aerial = float(_dm["aerial"])
	_apply_deep()


## Junta instruções de equipe, encaixe do elenco, estilos em campo e placar (cera) nos números
## que o motor lê. Barato: chamado quando táticas, jogadores ou placar mudam.
func _apply_deep() -> void:
	if _dm.is_empty():
		return
	x_rate = float(_dm["rate"])
	x_quality = float(_dm["quality"])
	x_opp_rate = float(_dm["opp_rate"])
	x_opp_quality = float(_dm["opp_quality"])
	x_poss = float(_dm["poss"]) + clampf(_ps_poss, -0.04, 0.04) * MatchSimulation.MOD_DAMP
	x_fatigue = float(_dm["fatigue"])
	x_fouls = float(_dm["fouls"])
	x_cards = 1.0
	x_offside = float(_dm["offside"])
	x_offside_own = float(_dm["offside_own"]) * (1.0 + clampf(_ps_off, 0.0, 0.4))
	var fits: Array = _dm["fits"]
	for j in mini(fits.size(), _fit_pts.size()):
		var b := TacticsManager.fit_bonus(float(_fit_pts[j]))
		match String(fits[j][1]):
			"quality":
				x_quality *= 1.0 + b
			"rate":
				x_rate *= 1.0 + b
			"opp_quality":
				x_opp_quality *= 1.0 - b
			"opp_rate":
				x_opp_rate *= 1.0 - b
	if leading:
		x_rate *= float(_dm["lead_rate"])
		x_opp_rate *= float(_dm["lead_opp_rate"])
		x_cards *= float(_dm["lead_cards"])
	var dt: PackedFloat32Array = _dm["types"]
	var dot: PackedFloat32Array = _dm["opp_types"]
	for i in 6:
		t_types[i] = dt[i] * clampf(1.0 + _ps_t[i], 0.85, 1.2)
		t_opp_types[i] = dot[i] * clampf(1.0 + _ps_o[i], 0.85, 1.15)


## Placar mudou (MatchSimulation._game_state): a cera só vale para quem está vencendo.
func apply_state(diff: int) -> void:
	var l := diff > 0 and int(deep[5]) == 1
	if l != leading:
		leading = l
		_apply_deep()


## Descrição para o choque de instruções (TacticsManager.clash).
func clash_desc(opp: MatchTeam) -> Dictionary:
	var rel := 1.0
	var f := int(deep[4])
	if f != 1 and opp != null:
		var fl := 0 if f == 0 else (1 if f == 2 else 2)
		var mean := 0.0
		var r := [0.0, 0.0, 0.0]
		for l in 3:
			r[l] = lane_raw[l] / maxf(1.0, opp.lane_def[2 - l])
			mean += float(r[l]) * float(MatchSimulation.LANE_BASE[l])
		rel = float(r[fl]) / maxf(0.01, mean)
	return {"passing": int(deep[1]), "pressing": pressing, "line": line, "marking": int(deep[2]), "transition": int(deep[3]),
		"tech": press_tech, "pace_att": pace_att, "pace_def": pace_def, "lane_rel": rel}


## Muda uma instrução de equipe durante o jogo (índice em TacticsManager.DEEP).
func set_deep(k: int, v: int) -> void:
	deep[k] = v
	refresh_tactics()


## Descrição para o confronto de ideias (TacticalMatchup).
func matchup_desc() -> Dictionary:
	return {"tech": press_tech, "mid": mid_mass, "pressing": pressing, "style": style, "mentality": mentality, "line": line, "width": width_i}


func goalkeeper() -> MatchPlayer:
	if slots.size() > 0 and slots[0] != null:
		return slots[0]
	return null


## Fator individual: familiaridade × físico × (moral, forma, desempenho do dia, contexto) × time.
func refresh_factors() -> void:
	var team_f := MatchSimulation.damp(i_perf) * MatchSimulation.damp(cohesion_f) * MatchSimulation.damp(home_f) * evo_f
	_refresh_marking()
	for mp: MatchPlayer in slots:
		if mp == null:
			continue
		var c := clampf(mp.cond, 0.0, 100.0) / 100.0
		mp.f = mp.fam * (0.84 + 0.16 * c * c) * MatchSimulation.damp(mp.base_f) * team_f * mp.sh_f * mp.talk_f * mp.sc_f * mp.mk_f


## Marcação individual do rival ("Marcar o craque"): cada marcador em campo pega o jogador mais
## perigoso ainda livre deste time. Bom marcador contra craque sem drible = craque some (até -8%).
func _refresh_marking() -> void:
	for mp: MatchPlayer in slots:
		if mp != null:
			mp.mk_f = 1.0
	var opp: MatchTeam = opp_ref.get_ref() if opp_ref != null else null
	if opp == null:
		return
	for om: MatchPlayer in opp.slots:
		if om == null or om.slot <= 0 or not bool(om.instr.get("mark", false)):
			continue
		var target: MatchPlayer = null
		var best := -1.0
		for mp: MatchPlayer in slots:
			if mp == null or mp.slot <= 0 or mp.mk_f < 1.0:
				continue
			var threat := mp.slot_rating * (mp.w_att + 0.5 * mp.w_mid)
			if threat > best:
				best = threat
				target = mp
		if target == null:
			continue
		var edge := (om.attr(Attr.MAR) + om.attr(Attr.DES)) * 0.5 - (target.attr(Attr.TEC) + target.attr(Attr.DRI)) * 0.5
		target.mk_f = 1.0 - clampf(0.045 + edge * 0.002, 0.015, 0.08)


## Recalcula os setores a partir de quem está em campo.
## Cada setor = média ponderada dos compostos × raiz da "massa" da formação (formação pesa, mas não domina).
func recompute_units() -> void:
	refresh_factors()
	var d := 0.0
	var dw := 0.0
	var m := 0.0
	var mw := 0.0
	var a := 0.0
	var aw := 0.0
	var wsum := 0.0
	var aer: Array = []
	var pace_a := 0.0
	var pace_a_n := 0.0
	var pace_d := 0.0
	var pace_d_n := 0.0
	var tech_sum := 0.0
	var dis_sum := 0.0
	var dec_sum := 0.0
	var dec_n := 0.0
	var fit_sum := 0.0
	var ovr_sum := 0.0
	var pt_sum := 0.0
	var n := 0
	u_gk = 15.0
	_ps_t.fill(0.0)
	_ps_o.fill(0.0)
	_ps_poss = 0.0
	_ps_off = 0.0
	var fits: Array = _dm.get("fits", [])
	_fit_pts.resize(fits.size())
	_fit_pts.fill(0.0)
	for mp: MatchPlayer in slots:
		if mp == null:
			continue
		for i in 6:
			_ps_t[i] += mp.fx_t[i]
			_ps_o[i] += mp.fx_o[i]
		_ps_poss += mp.fx_poss
		if mp.slot == 0:
			u_gk = mp.c_gk * mp.f
			continue
		_ps_off += mp.fx_offside
		for j in fits.size():
			var ids: Array = fits[j][0]
			var fs := 0.0
			for ai in ids:
				fs += mp.p.attrs[ai]
			_fit_pts[j] = float(_fit_pts[j]) + fs / maxf(1.0, ids.size()) - mp.slot_rating
		n += 1
		d += mp.c_def * mp.f * mp.w_def
		dw += mp.w_def
		m += mp.c_mid * mp.f * mp.w_mid
		mw += mp.w_mid
		a += mp.c_att * mp.f * mp.w_att
		aw += mp.w_att
		wsum += mp.w_wide
		aer.append(mp.c_aer * mp.f)
		if mp.w_att >= 0.45:
			pace_a += mp.a_vel
			pace_a_n += 1.0
		if mp.w_def >= 0.5:
			pace_d += mp.a_vel
			pace_d_n += 1.0
			dec_sum += mp.a_dec
			dec_n += 1.0
		tech_sum += mp.a_tec
		pt_sum += mp.a_tec * 0.45 + mp.a_pas_vis * 0.175 + mp.a_dec * 0.2
		dis_sum += mp.a_dis
		if not s_fit_attrs.is_empty():
			fit_sum += mp.style_fit_value(style, s_fit_attrs)
		ovr_sum += mp.slot_rating
	on_pitch_count = n + (1 if slots.size() > 0 and slots[0] != null else 0)
	_recompute_lanes()
	u_def = ((d / maxf(0.01, dw)) * sqrt(dw / norm_def) if dw > 0.0 else 10.0) * train_def
	u_mid = (m / maxf(0.01, mw)) * sqrt(mw / norm_mid) if mw > 0.0 else 10.0
	u_att = ((a / maxf(0.01, aw)) * sqrt(aw / norm_att) if aw > 0.0 else 10.0) * train_att
	width = wsum * [0.7, 1.0, 1.3][clampi(width_i, 0, 2)]
	mid_mass = mw
	press_tech = pt_sum / maxf(1.0, n)
	aer.sort()
	aer.reverse()
	aerial_att = _avg(aer.slice(0, 3))
	aerial_def = _avg(aer.slice(0, 4))
	pace_att = pace_a / pace_a_n if pace_a_n > 0.0 else 50.0
	pace_def = pace_d / pace_d_n if pace_d_n > 0.0 else 50.0
	tech = tech_sum / maxf(1.0, n)
	discipline = dis_sum / maxf(1.0, n)
	avg_decision = dec_sum / dec_n if dec_n > 0.0 else 50.0
	style_fit = clampf((fit_sum - ovr_sum) / maxf(1.0, n) * 0.006, -0.06, 0.06) if n > 0 and not s_fit_attrs.is_empty() else 0.0
	for j in _fit_pts.size():
		_fit_pts[j] = float(_fit_pts[j]) / maxf(1.0, n)
	_apply_deep()
	_rebuild_pick_tables()


## Pesos de escolha por vaga para cada modo (finalizar, cabecear, passar, driblar...).
## Modos: 0 chute, 1 cabeça, 2 chute de longe, 3 drible, 4 contra-ataque, 5 passe, 6 cruzamento, 7 meio, 8 defesa (erro).
func _rebuild_pick_tables() -> void:
	var ns := slots.size()
	if pick_w.size() != PICK_MODES:
		pick_w.clear()
		for _m in PICK_MODES:
			var arr := PackedFloat32Array()
			arr.resize(ns)
			pick_w.append(arr)
		pick_total.resize(PICK_MODES)
	for m in PICK_MODES:
		var arr: PackedFloat32Array = pick_w[m]
		if arr.size() != ns:
			arr.resize(ns)
		var total := 0.0
		for i in ns:
			var mp: MatchPlayer = slots[i]
			var v := 0.0
			if mp != null and mp.slot != 0:
				match m:
					0:
						v = (mp.w_att + 0.04) * MatchSimulation.shot_share(mp.c_fin) * mp.f * (MatchSimulation.ST_SHOOT if mp.pos == Pos.ST else 1.0)
					1:
						v = (mp.w_att + (MatchSimulation.CB_HEAD if mp.pos == Pos.CB else 0.0) + 0.05) * mp.c_head * mp.f
					2:
						v = (mp.w_mid + mp.w_att * 0.6 + 0.05) * mp.c_long * mp.f
					3:
						v = (mp.w_att + mp.w_wide * 0.3 + 0.05) * mp.a_tec_vel * mp.f
					4:
						v = (mp.w_att + 0.05) * mp.a_vel_fin * mp.f
					5:
						v = (mp.w_mid + mp.w_att * 0.5 + 0.05) * pow(mp.a_pas_vis / 100.0, MatchSimulation.CREATOR_EXP) * 100.0 * mp.f
					6:
						v = (mp.w_wide + 0.05) * mp.a_cru * mp.f
					7:
						v = (mp.w_mid + 0.1) * mp.f
					8:
						v = (mp.w_def + 0.05) * (110.0 - mp.a_dec)
				v *= mp.pick_m[m]
			arr[i] = v
			total += v
		pick_w[m] = arr
		pick_total[m] = total


static func _avg(arr: Array) -> float:
	if arr.is_empty():
		return 40.0
	var s := 0.0
	for v in arr:
		s += v
	return s / arr.size()


## Corredor de uma vaga pela posição no desenho (x: 0 esquerda … 1 direita).
func lane_of(mp: MatchPlayer) -> int:
	if formation.is_empty() or mp.slot < 0 or mp.slot >= formation["slots"].size():
		return 1
	var x := float(formation["slots"][mp.slot]["x"])
	return 0 if x < 0.34 else (2 if x > 0.66 else 1)


func _recompute_lanes() -> void:
	var la: Array[float] = [0.0, 0.0, 0.0]
	var ld: Array[float] = [0.0, 0.0, 0.0]
	for mp: MatchPlayer in slots:
		if mp == null or mp.slot == 0:
			continue
		var l := lane_of(mp)
		var att := mp.c_att * mp.f * mp.w_att
		var dfv := mp.c_def * mp.f * mp.w_def
		# Quem sobe deixa o corredor aberto na perda da bola (só no corredor: a defesa geral já
		# levou o ajuste da instrução).
		var lane_dfv := dfv * (1.0 - float(mp.instr.get("gap", 0.0)))
		if l == 1:
			la[1] += att
			ld[1] += lane_dfv
			# Quem joga por dentro ainda cobre um pouco os lados.
			ld[0] += dfv * 0.2
			ld[2] += dfv * 0.2
			la[0] += att * 0.1
			la[2] += att * 0.1
		else:
			la[l] += att + mp.c_att * mp.f * mp.w_wide * 0.3
			ld[l] += lane_dfv
			ld[1] += dfv * 0.15
	var focus: Array = _dm.get("lanes", [1.0, 1.0, 1.0])
	for i in 3:
		lane_raw[i] = maxf(5.0, la[i])
		# Foco do ataque: mais jogadas pelo corredor escolhido (TacticsManager.clash mede se compensa).
		lane_att[i] = lane_raw[i] * float(focus[i])
		lane_def[i] = maxf(5.0, ld[i])

