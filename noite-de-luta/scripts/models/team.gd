class_name Team
extends RefCounted
## Equipe (academia) de lutadores. A do jogador começa pequena; as outras são as rivais que
## disputam os mesmos lutadores e as mesmas bolsas.

var id: int = -1
var name: String = ""
## Sigla de até 3 letras (selo e listas apertadas).
var short: String = ""
var nation: String = "BRA"
var city: String = ""
var color1: Color = Color("#B3262E")
var color2: Color = Color("#F1F0EC")
## Reputação 0–100: abre portas (lutadores aceitam assinar, propostas melhores chegam).
var reputation: float = 20.0
var balance: float = 0.0
var is_user: bool = false
## Staff contratado: [{id, name, role, quality, age, wage, nation, since}]
var staff: Array = []
## Lançamentos da semana para a tela de finanças: [{week, label, value}] (últimos 80).
var ledger: Array = []


func add_money(week: int, label: String, value: float) -> void:
	balance += value
	ledger.append({"week": week, "label": label, "value": value})
	if ledger.size() > 120:
		ledger = ledger.slice(ledger.size() - 120)


func staff_of(role: String) -> Dictionary:
	for s: Dictionary in staff:
		if String(s["role"]) == role:
			return s
	return {}


## Qualidade do profissional da função (0 quando não há ninguém). Equipes rivais não têm staff
## nomeado: a reputação faz as vezes dele.
func staff_quality(role: String) -> float:
	if not is_user:
		return clampf(reputation * 0.8 + 10.0, 20.0, 85.0)
	var s := staff_of(role)
	return float(s.get("quality", 0.0))


func weekly_wages() -> float:
	var t := 0.0
	for s: Dictionary in staff:
		t += float(s["wage"])
	return t


func to_dict() -> Dictionary:
	return {"id": id, "name": name, "short": short, "nation": nation, "city": city, "c1": color1.to_html(false),
		"c2": color2.to_html(false), "rep": reputation, "bal": balance, "user": is_user, "staff": staff, "ledger": ledger}


static func from_dict(d: Dictionary) -> Team:
	var t := Team.new()
	t.id = int(d["id"])
	t.name = String(d.get("name", ""))
	t.short = String(d.get("short", ""))
	t.nation = String(d.get("nation", "BRA"))
	t.city = String(d.get("city", ""))
	t.color1 = Color(String(d.get("c1", "B3262E")))
	t.color2 = Color(String(d.get("c2", "F1F0EC")))
	t.reputation = float(d.get("rep", 20.0))
	t.balance = float(d.get("bal", 0.0))
	t.is_user = bool(d.get("user", false))
	t.staff = d.get("staff", [])
	t.ledger = d.get("ledger", [])
	return t
