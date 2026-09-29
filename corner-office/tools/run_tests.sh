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
if grep -qE "SCRIPT ERROR|Parse Error" <<<"$out"; then
	echo "Falha: erros de script no log." >&2
	exit 1
fi
exit $status
