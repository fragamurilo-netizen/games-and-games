class_name SaveCodec
extends RefCounted
## Compactação das listas de registros do save (histórico por temporada, passagens, troféus).
## Uma lista de dicionários com as mesmas chaves vira colunas: inteiros em PackedInt32Array,
## decimais em PackedFloat64Array e textos em PackedStringArray. O arquivo fica bem menor e,
## principalmente, carrega muito mais rápido (poucos arrays compactos em vez de milhares de
## dicionários). `unpack_rows` aceita também a lista antiga, então saves antigos continuam abrindo.

const TAG := "_rows"
const NO_INT := -2147483648 # campo ausente naquela linha


static func pack_rows(rows: Array) -> Variant:
	var n := rows.size()
	if n < 2 or not rows[0] is Dictionary:
		return rows
	# Caminho rápido: todas as linhas com as mesmas chaves da primeira (o caso normal)
	var first: Dictionary = rows[0]
	var keys: Array = first.keys()
	var nk := keys.size()
	for r in rows:
		if not r is Dictionary or (r as Dictionary).size() != nk:
			return _pack_slow(rows)
	var types := ""
	var cols: Array = []
	for k in keys:
		var t0 := typeof(first[k])
		var ok := true
		if t0 == TYPE_INT:
			var c := PackedInt32Array()
			c.resize(n)
			for i in n:
				var v: Variant = rows[i].get(k)
				if typeof(v) != TYPE_INT or v <= NO_INT or v >= 2147483647:
					ok = false
					break
				c[i] = v
			if ok:
				types += "i"
				cols.append(c)
				continue
		elif t0 == TYPE_FLOAT:
			var c := PackedFloat64Array()
			c.resize(n)
			for i in n:
				var v: Variant = rows[i].get(k)
				if typeof(v) != TYPE_FLOAT:
					ok = false
					break
				c[i] = v
			if ok:
				types += "f"
				cols.append(c)
				continue
		elif t0 == TYPE_STRING:
			var c := PackedStringArray()
			c.resize(n)
			for i in n:
				var v: Variant = rows[i].get(k)
				if typeof(v) != TYPE_STRING:
					ok = false
					break
				c[i] = v
			if ok:
				types += "s"
				cols.append(c)
				continue
		var g: Array = []
		g.resize(n)
		for i in n:
			if not rows[i].has(k):
				return _pack_slow(rows)
			g[i] = rows[i][k]
		types += "v"
		cols.append(g)
	return {TAG: n, "k": PackedStringArray(keys), "t": types, "c": cols}


static func _pack_slow(rows: Array) -> Variant:
	var keys: Array = []
	for r in rows:
		if not r is Dictionary:
			return rows
		for k in r:
			if not keys.has(k):
				keys.append(k)
	var types := ""
	var cols: Array = []
	for k in keys:
		var t := _col_type(rows, k)
		types += t
		match t:
			"i":
				var c := PackedInt32Array()
				c.resize(rows.size())
				for i in rows.size():
					c[i] = int(rows[i][k]) if rows[i].has(k) else NO_INT
				cols.append(c)
			"f":
				var c := PackedFloat64Array()
				c.resize(rows.size())
				for i in rows.size():
					c[i] = float(rows[i][k]) if rows[i].has(k) else NAN
				cols.append(c)
			"s":
				var c := PackedStringArray()
				c.resize(rows.size())
				for i in rows.size():
					c[i] = String(rows[i][k]) if rows[i].has(k) else ""
				cols.append(c)
			_:
				var c: Array = []
				for r: Dictionary in rows:
					c.append(r.get(k, null))
				cols.append(c)
	return {TAG: rows.size(), "k": PackedStringArray(keys), "t": types, "c": cols}


## "i" só inteiros, "f" números, "s" só textos, "v" qualquer outra coisa.
static func _col_type(rows: Array, k: Variant) -> String:
	var ints := true
	var nums := true
	var strs := true
	for r: Dictionary in rows:
		if not r.has(k):
			strs = false # texto não tem marca de ausente
			continue
		var v: Variant = r[k]
		var ty := typeof(v)
		if ty == TYPE_INT:
			strs = false
			if absi(v) >= 2147483647:
				ints = false
				nums = false
		elif ty == TYPE_FLOAT:
			strs = false
			ints = false
		elif ty == TYPE_STRING:
			ints = false
			nums = false
		else:
			return "v"
	if ints:
		return "i"
	if nums:
		return "f"
	return "s" if strs else "v"


static func unpack_rows(v: Variant) -> Array:
	if v is Array:
		return v
	if not (v is Dictionary and v.has(TAG)):
		return []
	var n := int(v[TAG])
	var keys: PackedStringArray = v["k"]
	var types: String = v["t"]
	var cols: Array = v["c"]
	var out: Array = []
	out.resize(n)
	for i in n:
		out[i] = {}
	for j in keys.size():
		var k := keys[j]
		var col: Variant = cols[j]
		match types[j]:
			"i":
				var c: PackedInt32Array = col
				for i in n:
					if c[i] != NO_INT:
						out[i][k] = c[i]
			"f":
				var c: PackedFloat64Array = col
				for i in n:
					if not is_nan(c[i]):
						out[i][k] = c[i]
			"s":
				var c: PackedStringArray = col
				for i in n:
					out[i][k] = c[i]
			_:
				var c: Array = col
				for i in n:
					if c[i] != null:
						out[i][k] = c[i]
	return out
