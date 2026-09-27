extends Control

@export_enum("dashboard", "crests") var mode: String = "dashboard"
const W=900.0
const H=1600.0
const BG=Color("#07111F")
const DARK=Color("#0D1B2A")
const CARD=Color("#F5F7FA")
const TEXT=Color("#101827")
const MUTED=Color("#667489")
const WHITE=Color("#F8FAFC")
const GREEN=Color("#20C878")
const CRESTS=[
	["Aurora FC","res://assets/visual_proof/aurora_fc.svg",Color("#F4B942")],
	["Vale Unido","res://assets/visual_proof/vale_unido.svg",Color("#2F7A4D")],
	["Ferro Azul","res://assets/visual_proof/ferro_azul.svg",Color("#45B9F4")],
	["Estrela do Sul","res://assets/visual_proof/estrela_sul.svg",Color("#D9A441")],
	["Monte Verde","res://assets/visual_proof/monte_verde.svg",Color("#2D7A46")]
]

func _ready()->void:
	get_window().size=Vector2i(900,1600)
	get_window().content_scale_size=Vector2i(900,1600)
	get_window().content_scale_factor=1.0
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if mode=="crests": _gallery()
	else: _dashboard()
	print("VISUAL_PROOF_READY ",mode)
	_capture.call_deferred()

func _capture()->void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var dir=ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(dir)
	var name="visual-proof-crests.png" if mode=="crests" else "visual-proof-ui.png"
	var err=get_viewport().get_texture().get_image().save_png(dir.path_join(name))
	print("VISUAL_PROOF_SAVED ",name," err=",err)
	get_tree().quit(0 if err==OK else 1)

func _p(parent:Node,r:Rect2,c:Color,rad:=22)->Panel:
	var n=Panel.new()
	n.position=r.position;n.size=r.size
	var s=StyleBoxFlat.new();s.bg_color=c
	s.corner_radius_top_left=rad;s.corner_radius_top_right=rad
	s.corner_radius_bottom_left=rad;s.corner_radius_bottom_right=rad
	n.add_theme_stylebox_override("panel",s);parent.add_child(n);return n

func _l(parent:Node,txt:String,r:Rect2,fs:int,c:Color,center:=false)->Label:
	var n=Label.new();n.text=txt;n.position=r.position;n.size=r.size
	n.add_theme_font_size_override("font_size",fs);n.add_theme_color_override("font_color",c)
	n.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	n.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	n.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(n);return n

func _c(parent:Node,i:int,r:Rect2)->TextureRect:
	var n=TextureRect.new()
	n.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	n.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	n.custom_minimum_size=Vector2.ZERO
	n.texture=load(CRESTS[i][1])
	n.position=r.position
	n.size=r.size
	n.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	n.set_deferred("size",r.size)
	return n

func _bg(c:Color)->void:
	var b=ColorRect.new();b.color=c;b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(b)

func _gallery()->void:
	_bg(Color("#EEF2F5"))
	_l(self,"5 ESCUDOS REAIS NO GODOT",Rect2(42,35,816,55),30,TEXT)
	_l(self,"SVG vetorial • carregado por TextureRect • sem imagem gerada",Rect2(42,88,816,35),17,MUTED)
	for i in 5:
		var col=i%2;var row=i/2
		var x=46.0+col*414.0;var y=155.0+row*395.0
		if i==4:x=253.0
		var card=_p(self,Rect2(x,y,348,340),Color.WHITE,28)
		_c(card,i,Rect2(74,28,200,205))
		_l(card,CRESTS[i][0],Rect2(20,235,308,42),24,TEXT,true)
		_l(card,"512 × 512 • SVG • FUNDO TRANSPARENTE",Rect2(18,278,312,28),13,MUTED,true)
		var strip=ColorRect.new();strip.color=CRESTS[i][2];strip.position=Vector2(92,320);strip.size=Vector2(164,6);card.add_child(strip)
	_l(self,"render: Viewport.get_texture().get_image()",Rect2(42,1450,816,34),16,MUTED,true)

func _dashboard()->void:
	_bg(BG)
	var h=_p(self,Rect2(0,0,W,176),Color("#0A1726"),0)
	_c(h,0,Rect2(32,27,116,116))
	_l(h,"AURORA FC",Rect2(168,34,430,48),34,WHITE)
	_l(h,"MAIS UMA RODADA",Rect2(168,80,430,30),18,Color("#9EABBA"))
	_l(h,"TEMPORADA 2026  •  BRASIL",Rect2(168,112,430,28),16,Color("#758399"))
	var pos=_p(h,Rect2(700,48,158,66),Color("#173047"),18)
	_l(pos,"5º LUGAR",Rect2(0,0,158,66),19,WHITE,true)

	var game=_p(self,Rect2(30,202,840,280),CARD,28)
	_l(game,"PRÓXIMO JOGO",Rect2(26,15,320,42),25,TEXT)
	_l(game,"SÉRIE A • RODADA 19",Rect2(485,15,325,42),16,MUTED,true)
	_c(game,0,Rect2(48,72,128,128));_c(game,1,Rect2(664,72,128,128))
	_l(game,"Aurora FC",Rect2(25,198,175,32),20,TEXT,true)
	_l(game,"Vale Unido",Rect2(640,198,175,32),20,TEXT,true)
	_l(game,"SÁBADO",Rect2(320,74,200,28),15,MUTED,true)
	_l(game,"19:00",Rect2(310,100,220,64),48,TEXT,true)
	_l(game,"Estádio Aurora",Rect2(300,164,240,28),16,MUTED,true)
	var b=_p(game,Rect2(292,216,256,48),Color("#13975E"),16)
	_l(b,"IR PARA O JOGO",Rect2(0,0,256,48),20,WHITE,true)

	var table=_p(self,Rect2(30,510,406,486),CARD,26)
	_l(table,"CLASSIFICAÇÃO",Rect2(22,14,270,42),24,TEXT)
	_l(table,"PTS",Rect2(330,14,54,42),15,MUTED,true)
	var pts=[38,35,33,31,29]
	for i in 5:
		var y=78.0+i*72.0
		if i==4:_p(table,Rect2(12,y-5,382,62),Color("#E2EAF1"),14)
		_l(table,str(i+1),Rect2(16,y,30,48),17,MUTED,true)
		_c(table,i,Rect2(54,y,44,44))
		_l(table,CRESTS[i][0],Rect2(110,y,192,48),18,TEXT)
		_l(table,str(pts[i]),Rect2(334,y,50,48),19,TEXT,true)
	var tb=_p(table,Rect2(20,424,366,44),Color("#172B40"),14)
	_l(tb,"VER TABELA COMPLETA",Rect2(0,0,366,44),16,WHITE,true)

	var news=_p(self,Rect2(464,510,406,486),CARD,26)
	_l(news,"NOTÍCIAS",Rect2(22,14,220,42),24,TEXT)
	var nt=["Aurora chega a cinco jogos sem perder","Joia da base pede passagem","Diretoria revisa verba da janela"]
	var nb=["Boa fase aproxima o clube do G4.","Treinos fortes aumentam a disputa por vaga.","Mercado, caixa e dívida entram na conta."]
	for i in 3:
		var y=78.0+i*112.0
		var dot=ColorRect.new();dot.color=CRESTS[i][2];dot.position=Vector2(24,y+7);dot.size=Vector2(6,78);news.add_child(dot)
		_l(news,nt[i],Rect2(45,y,335,46),18,TEXT)
		_l(news,nb[i],Rect2(45,y+46,335,50),15,MUTED)

	var fin=_p(self,Rect2(30,1022,406,322),CARD,26)
	_l(fin,"FINANÇAS",Rect2(22,14,220,42),24,TEXT)
	_l(fin,"Saldo em caixa",Rect2(22,70,250,28),15,MUTED)
	_l(fin,"R$ 42,8 mi",Rect2(22,98,300,46),30,Color("#12835A"))
	_l(fin,"Orçamento de transferências",Rect2(22,160,300,28),15,MUTED)
	_l(fin,"R$ 86,4 mi",Rect2(22,188,300,42),26,TEXT)
	_l(fin,"Moeda selecionável: R$ / € / US$",Rect2(22,252,350,32),15,MUTED)

	var squad=_p(self,Rect2(464,1022,406,322),CARD,26)
	_l(squad,"ELENCO",Rect2(22,14,220,42),24,TEXT)
	var rows=[["Força do XI","74,2"],["Idade média","25,8"],["Moral","BOA"],["Prioridade","LD titular"]]
	for i in 4:
		var y=70.0+i*54.0
		_l(squad,rows[i][0],Rect2(22,y,220,34),16,MUTED)
		_l(squad,rows[i][1],Rect2(245,y,135,34),20,GREEN if i==2 else TEXT,true)

	var nav=_p(self,Rect2(0,1380,W,220),Color("#091724"),0)
	var names=["INÍCIO","ELENCO","TÁTICAS","MERCADO","CLUBE"]
	var icons=["●","◉","▦","⇄","◆"]
	for i in 5:
		var x=18.0+i*176.0
		_l(nav,icons[i],Rect2(x,30,150,50),30,GREEN if i==0 else Color("#A8B4C2"),true)
		_l(nav,names[i],Rect2(x,80,150,38),15,WHITE if i==0 else Color("#A8B4C2"),true)
	_l(nav,"UI REAL • GODOT 4.7 • CONTROL NODES",Rect2(30,160,840,30),13,Color("#637287"),true)