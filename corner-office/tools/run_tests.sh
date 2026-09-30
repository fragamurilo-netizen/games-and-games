#!/usr/bin/env bash
# Roda os testes headless e falha também se a Godot reportar qualquer
# SCRIPT ERROR (GDScript não lança exceções; erros só aparecem no log).
# Uso: tools/run_tests.sh [unit|sim]   (GODOT=/caminho/godot para sobrescrever)
set -uo pipefail
cd "$(dirname "$0")/../game"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
out="$("$GODOT" --headless --path . -s res://tests/run_tests.gd ${1:+-- "$@"} 2>&1)"
status=$?
echo "$out"
# Navegação do hub precisa de uma árvore de cena real; roda à parte.
nav="$("$GODOT" --headless --path . -s res://tools/check_navigation.gd 2>&1)"
nav_status=$?
echo "$nav" | grep -E "^(FAIL|NAVIGATION)"
out="$out
$nav"
[ $nav_status -ne 0 ] && status=1
if grep -qE "SCRIPT ERROR|Parse Error" <<<"$out"; then
	echo "Falha: erros de script no log." >&2
	exit 1
fi
exit $status
