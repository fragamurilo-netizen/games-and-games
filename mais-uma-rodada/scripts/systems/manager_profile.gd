class_name ManagerProfile
extends RefCounted
## O treinador do usuário: rosto, nacionalidade, idade e estilo de trabalho (world.manager).
## O nome continua em world.manager_name (usado em todo o jogo).
##
## Estilos com efeito pequeno e explícito (o resto é identidade e imprensa):
##   formador     base e garotos do elenco evoluem um pouco mais
##   motivador    a moral do elenco volta mais rápido ao normal depois de derrotas
##   estrategista o entrosamento do time sobe mais rápido nos treinos
##   linha_dura   menos cartões por indisciplina (elenco mais disciplinado)
##   ofensivo     a torcida gosta: humor sobe um pouco a cada vitória
##   pragmatico   a diretoria confia mais: um pouco mais de paciência

const STYLE_FX := {
	"formador": "Garotos da base e jovens do elenco evoluem um pouco mais.",
	"motivador": "A moral do elenco se recupera mais rápido das derrotas.",
	"estrategista": "O entrosamento do time sobe mais rápido nos treinos.",
	"linha_dura": "Elenco mais disciplinado: menos cartões.",
	"ofensivo": "A torcida vibra com o seu estilo: humor sobe a cada vitória.",
	"pragmatico": "A diretoria confia no seu método: um pouco mais de paciência.",
}


static func data(world: GameWorld) -> Dictionary:
	var m := world.manager
	if not m.has("seed"):
		m["seed"] = hash([world.world_seed, "manager"]) & 0x7FFFFFFF
	if not m.has("by"):
		m["by"] = world.year - 42
	if not m.has("nat"):
		m["nat"] = world.user_club().nation if world.has_user() else "BRA"
	if not m.has("eth"):
		m["eth"] = 1
	if not m.has("look"):
		m["look"] = {}
	if not m.has("style"):
		m["style"] = "estrategista"
	return m


static func age(world: GameWorld) -> int:
	return world.year - int(data(world)["by"])


static func style(world: GameWorld) -> String:
	return String(data(world)["style"]) if world.has_user() else ""


static func has_style(world: GameWorld, st: String) -> bool:
	return world.has_user() and style(world) == st


static func style_name(st: String) -> String:
	return String(People.COACH_STYLES.get(st, {}).get("name", st))


## Retrato de terno com a cor do clube atual.
static func portrait(world: GameWorld, px: int) -> PortraitView:
	var m := data(world)
	var v := PortraitView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_person(int(m["seed"]), int(m["eth"]), age(world), world.user_club() if world.has_user() else null)
	v.look = m["look"]
	return v


# --- Efeitos do estilo -------------------------------------------------------

static func youth_mult(world: GameWorld) -> float:
	return 1.05 if has_style(world, "formador") else 1.0


static func cohesion_mult(world: GameWorld) -> float:
	return 1.12 if has_style(world, "estrategista") else 1.0


static func card_mult(world: GameWorld, club_id: int) -> float:
	return 0.9 if club_id == world.user_club_id and has_style(world, "linha_dura") else 1.0


static func morale_recovery(world: GameWorld) -> float:
	return 1.5 if has_style(world, "motivador") else 1.0


static func patience_mult(world: GameWorld) -> float:
	return 1.08 if has_style(world, "pragmatico") else 1.0
