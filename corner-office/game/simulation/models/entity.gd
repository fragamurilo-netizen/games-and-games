class_name Entity
extends RefCounted
## Base de toda entidade persistente (Game Design Bible §17–18).
## Regras:
##  - `id` é estável por toda a vida do save; nunca reutilize ids.
##  - Campos contêm apenas tipos serializáveis (String, int, float, bool,
##    Array, Dictionary). Referências a outras entidades são por id.
##  - Históricos (lutas, contratos, títulos, rankings) são append-only.

var id: String = ""


func to_dict() -> Dictionary:
	var d := {}
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			d[p.name] = get(p.name)
	return d


func load_dict(d: Dictionary) -> Entity:
	for p in get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and d.has(p.name):
			var v: Variant = d[p.name]
			# JSON devolve números como float; restaura ints declarados.
			if p.type == TYPE_INT and typeof(v) == TYPE_FLOAT:
				v = int(v)
			set(p.name, v)
	return self
