class_name Fight
extends Entity
## Luta (Game Design Bible §6, MMA Bible §20–21). Depois de resolvida é
## registro histórico imutável: nunca edite result/stats retroativamente.

var event_id := ""
var fighter_a_id := ""
var fighter_b_id := ""
var division := ""
var catchweight_kg := 0.0
var rounds := 3
var card_slot := "prelims"     # main_event | co_main | main_card | prelims | early_prelims
var title_stakes := ""         # "" | title | interim | eliminator
var status := "proposed"       # proposed | booked | cancelled | completed

# Resultado
var winner_id := ""
var method := ""               # ko_tko | submission | decision | draw | nc | dq
var method_detail := ""
var end_round := 0
var end_time_s := 0
var scorecards: Array = []     # [{judge_id, rounds: [[10,9],...], total: [a,b]}]
var round_log: Array = []      # event log por round (fonte para juízes, mídia, replay)
var stats := {}
var damage := {}
var reasons: Array = []        # Reason codes do resultado
