class_name Contract
extends Entity
## Contrato (Game Design Bible §9, MMA Bible §13, §25).

var fighter_id := ""
var organization_id := ""
var signed_on := {}
var expires_on := {}
var bouts_total := 0
var bouts_remaining := 0

var show_money := 0
var win_bonus := 0
var ppv_points := 0.0
var signing_bonus := 0
var minimum_guarantee := 0

var champion_clause := false
var matching_rights := false
var exclusive := true
# Promessas: [{type: "title_shot"|"main_event"|"home_event"|"activity", due: date, kept: null|bool}]
var promises: Array = []
var active := true
var ai_renewal_tried := false   # IA rival já tentou renovar este contrato
