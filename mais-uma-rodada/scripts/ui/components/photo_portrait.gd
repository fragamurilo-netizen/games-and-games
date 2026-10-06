class_name PhotoPortrait
extends Control
## Retrato com cara de foto: o mesmo desenho do PortraitView, recortado num SubViewport, passa uma
## vez pelo photo_look.gdshader (luz do cenário, fundo, grão, curva de foto) e fica como textura.
## Cada momento do jogo tem o seu cenário (ver `for_moment`):
##   estúdio (perfil, ficha), coletiva (prêmios, apresentação, técnico, imprensa), túnel (antes do
##   jogo, entrada em campo), filme 35 mm (lendas, história, temporadas passadas), noite de chuva
##   (jogo à noite com chuva) e treino ao sol (treino, destaque do treino, jogo de dia).
## O formato vem do tamanho do controle: quadrado, em pé (retrato embaixo, fundo em cima) ou
## deitado (retrato no lado indicado por `focus_x`).

const STUDIO := 0
const PRESS := 1
const TUNNEL := 2
const FILM := 3
const RAIN := 4
const SUN := 5
const NAMES: Array[String] = ["Estúdio", "Coletiva", "Túnel", "Filme 35 mm", "Noite de chuva", "Treino ao sol"]

const SHADER_PATH := "res://scripts/ui/components/photo_look.gdshader"
const MAX_PX := 900

static var _shader: Shader = null

var mood := STUDIO:
	set(v):
		mood = v
		_rerender()
## Busto inteiro (true) ou o recorte de cabeça e ombros no estilo FM (false).
var bust := false:
	set(v):
		bust = v
		if _pv != null:
			_pv.cutout = v
		_rerender()
## No formato deitado: onde fica o retrato (0 esquerda, 0,5 centro, 1 direita).
var focus_x := 0.5:
	set(v):
		focus_x = v
		_layout()
var corner_px := 6.0
## Recorte sem fundo (cutout do FM): o jogador "sai" do cabeçalho, com a luz e a textura da foto.
var transparent := false:
	set(v):
		transparent = v
		_rerender()

var _pv: PortraitView
var _vp_cut: SubViewport
var _vp_fx: SubViewport
var _fx: ColorRect
var _view: TextureRect
var _gen := 0
var _club1 := Color(0.06, 0.18, 0.45)
var _club2 := Color(0.78, 0.12, 0.14)
var _seed := 0.0


## Cenário de cada momento do jogo (o mesmo jogador pode aparecer em vários).
static func for_moment(moment: String, wx: Dictionary = {}) -> int:
	match moment:
		"perfil", "ficha", "contrato", "uniforme":
			return STUDIO
		"premio", "apresentacao", "coletiva", "tecnico", "entrevista":
			return PRESS
		"pre_jogo", "escalacao", "capitao":
			return TUNNEL
		"lenda", "historia", "temporada_passada", "recorde":
			return FILM
		"treino":
			return SUN
		"craque_do_jogo", "jogo":
			var kind := String(wx.get("kind", ""))
			if kind in ["rain", "storm"]:
				return RAIN
			return TUNNEL if bool(wx.get("night", false)) else SUN
	return STUDIO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_pv = PortraitView.new()
	_pv.framing = PortraitView.FRAME_FM
	_pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp_cut = SubViewport.new()
	_vp_cut.transparent_bg = true
	_vp_cut.disable_3d = true
	_vp_cut.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp_cut.add_child(_pv)
	add_child(_vp_cut)
	_vp_fx = SubViewport.new()
	_vp_fx.transparent_bg = true
	_vp_fx.disable_3d = true
	_vp_fx.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_fx = ColorRect.new()
	_fx.color = Color.WHITE
	var mat := ShaderMaterial.new()
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	mat.shader = _shader
	_fx.material = mat
	_vp_fx.add_child(_fx)
	add_child(_vp_fx)
	_view = TextureRect.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_view)
	resized.connect(_layout)


## Jogador com o uniforme do clube (ou um uniforme específico, para a apresentação dos uniformes).
func set_player(p: Player, club: Club, year: int, kit_override: Dictionary = {}) -> void:
	_pv.set_player(p, club, year)
	if not kit_override.is_empty():
		_pv.kit = kit_override
		_pv.shirt_color = Color(String(kit_override.get("c1", "#FFFFFF")))
		_pv.trim_color = Color(String(kit_override.get("c2", "#111111")))
	_seed = float(p.id % 997)
	_colors(club)
	_rerender()


## Técnico, dirigente ou outra pessoa de terno.
func set_person(seed_value: int, eth: int, age: int, club: Club) -> void:
	_pv.set_person(seed_value, eth, age, club)
	_seed = float(absi(seed_value) % 997)
	_colors(club)
	_rerender()


func _colors(club: Club) -> void:
	if club == null:
		return
	_club1 = club.primary_color()
	_club2 = club.secondary_color()
	# Placas da parede de patrocínio: cor do clube e uma segunda que não suma no fundo claro
	if _club2.get_luminance() > 0.8 or absf(_club2.get_luminance() - _club1.get_luminance()) < 0.1:
		_club2 = Color(0.78, 0.12, 0.14) if _club1.r < 0.5 else Color(0.06, 0.18, 0.45)
	if _club1.get_luminance() > 0.8:
		_club1 = Color(0.12, 0.14, 0.18)


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_VISIBILITY_CHANGED:
		_layout()


func _scale() -> float:
	if not is_inside_tree():
		return 1.0
	# Só a escala da tela: animações de zoom (cerimônia de prêmios) não podem baixar a resolução
	return clampf(get_viewport().get_screen_transform().get_scale().x, 1.0, 2.5)


func _layout() -> void:
	if not is_inside_tree() or size.x < 4.0 or size.y < 4.0:
		return
	var k := _scale()
	var w := size.x
	var h := size.y
	var side := minf(w, h)
	var rect := Rect2(0.0, 0.0, 1.0, 1.0)
	if h > w:
		rect = Rect2(0.0, (h - w) / h, 1.0, w / h) # em pé: retrato embaixo
	elif w > h:
		var cx := clampf(w * focus_x, h * 0.5, w - h * 0.5)
		rect = Rect2((cx - h * 0.5) / w, 0.0, h / w, 1.0)
	var cut_px := mini(MAX_PX, int(side * k))
	var lim := float(MAX_PX) / maxf(w, h)
	var fx_px := Vector2i(int(w * minf(k, lim)), int(h * minf(k, lim)))
	_vp_cut.size = Vector2i(cut_px, cut_px)
	_pv.position = Vector2.ZERO
	_pv.size = Vector2(cut_px, cut_px)
	_vp_fx.size = fx_px
	_fx.position = Vector2.ZERO
	_fx.size = Vector2(fx_px)
	var mat := _fx.material as ShaderMaterial
	mat.set_shader_parameter(&"cut", _vp_cut.get_texture())
	mat.set_shader_parameter(&"cut_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	mat.set_shader_parameter(&"size_px", Vector2(fx_px))
	mat.set_shader_parameter(&"corner_px", corner_px * float(fx_px.x) / maxf(1.0, w))
	_view.texture = _vp_fx.get_texture()
	_rerender()


func _rerender() -> void:
	if _fx == null or not is_inside_tree():
		return
	var mat := _fx.material as ShaderMaterial
	mat.set_shader_parameter(&"mood", mood)
	mat.set_shader_parameter(&"cutout_mode", 1 if transparent else 0)
	mat.set_shader_parameter(&"seed", _seed)
	mat.set_shader_parameter(&"club1", _club1)
	mat.set_shader_parameter(&"club2", _club2)
	_gen += 1
	var g := _gen
	_pass(g)
	# O escudo e o patrocínio na camisa chegam alguns quadros depois (DecalCache): refaz a foto.
	for t in [0.3, 1.0]:
		get_tree().create_timer(t).timeout.connect(func():
			if is_instance_valid(self) and g == _gen:
				_pass(g))


## Um passe: desenha o recorte; no quadro seguinte (recorte pronto), a foto.
func _pass(g: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_vp_cut.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(func():
		if is_instance_valid(self) and g == _gen:
			_vp_fx.render_target_update_mode = SubViewport.UPDATE_ONCE, CONNECT_ONE_SHOT)


## Atalho: foto de um jogador num momento do jogo.
static func of_player(p: Player, club: Club, year: int, px: Vector2, moment: String, wx: Dictionary = {}) -> PhotoPortrait:
	var ph := PhotoPortrait.new()
	ph.custom_minimum_size = px
	ph.mood = for_moment(moment, wx)
	ph.set_player(p, club, year)
	return ph
