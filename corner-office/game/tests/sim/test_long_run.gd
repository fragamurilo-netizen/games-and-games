extends TestCase
## Testes de simulação longa (Game Design Bible §21; MMA Bible §30).
## Conforme os sistemas forem implementados, adicione aqui:
##  - milhares de lutas: distribuição KO/sub/decisão por divisão e estilo;
##  - lutadores 90+ não invencíveis; upset rate nunca zero;
##  - 20–50 anos: inflação de recordes, rankings travados, colapso econômico,
##    falta de novos talentos, diversidade regional e de estilos.


func test_world_advances_one_year_without_errors() -> void:
	var w := WorldGenerator.generate(123, "regional_promoter")
	var sim := WorldSim.new(w)
	for i in 52:
		sim.advance_week()
	check_eq(w.date.year, 2027, "52 semanas a partir de 01/01/2027")
	check_eq(GameDate.days_between(GameDate.START, w.date), 364, "364 dias simulados")
