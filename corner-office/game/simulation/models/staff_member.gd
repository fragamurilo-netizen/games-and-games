class_name StaffMember
extends Entity
## Funcionário da sede (Game Design Bible §15 Organização/staff, §19).
## Números 0–100. A UI traduz em barras, tags e frases; a regra vive em Office.

var organization_id := ""
var status := "active"          # candidate | active | vacation | gone
var first_name := ""
var last_name := ""
var sex := "m"
var country := ""
var age := 30
var role := "matchmaker"        # content/office.json roles
var level := "pleno"            # junior | pleno | senior | director
var salary := 0                 # US$ por mês
var skill := 50.0
var potential := 60.0
var experience := 0             # anos de mercado
var morale := 65.0
var energy := 80.0
var stress := 20.0
var ambition := 50.0
var loyalty := 50.0
var trust := 0.0                # relação com o presidente (-100..100)
var traits: Array = []
var relationships := {}         # staff_id -> {"value": -100..100, "kind": friend|rival|mentor|mentee|neutral}
var activity := "working"       # working | meeting | talking | break | overloaded | tired | vacation | celebrating | leaving
var mood_reasons: Array = []    # códigos do último cálculo de moral (por que está assim)
var workload := 0.0             # 0 = ocioso, 1 = no limite, >1 = sobrecarga
var desk := -1
var look := {}                  # aparência modular do sprite: skin, hair, hair_color, glasses, beard
var hired_on := {}
var left_on := {}
var vacation_until := {}
var last_praise_on := {}
var last_raise_on := {}
var last_pressure_on := {}
var asking_salary := 0          # candidato: pedida; ativo: último pedido de aumento
var interviewed := false        # candidato entrevistado revela habilidade real
var expires_on := {}            # candidato sai do mercado
var history: Array = []         # append-only: {date, text}
var destination_org := ""       # quem o levou ao sair


func full_name() -> String:
	return first_name + " " + last_name


func is_active() -> bool:
	return status == "active" or status == "vacation"
