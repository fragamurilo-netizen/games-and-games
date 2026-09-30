class_name TestCase
extends RefCounted
## Base mínima de testes (sem dependências externas).
## Crie arquivos tests/unit/test_*.gd ou tests/sim/test_*.gd com métodos test_*.

var failures: Array = []
## Quantas verificações rodaram. Erro de script em GDScript aborta o método
## sem exceção; um teste que não chega a nenhuma verificação conta como falha.
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	checks += 1
	if actual != expected:
		failures.append("%s (esperado %s, obtido %s)" % [message, str(expected), str(actual)])
