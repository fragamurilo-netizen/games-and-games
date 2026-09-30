class_name Ranking
extends Entity
## Snapshot de ranking (MMA Bible §12, §23). Cada snapshot é salvo por data.
## org ranking, World Combat Index e prioridade de matchmaking são coisas distintas.

var organization_id := ""      # "wci" = World Combat Index
var division := ""             # id de weight_classes.json, ou "p4p" no WCI
var model := "panel"           # panel | algorithmic | promoter_assisted | bracket
var snapshot_date := {}
var champion_id := ""
var entries: Array = []        # fighter ids em ordem
var explanations: Array = []   # Reason codes das mudanças relevantes
var scores: Dictionary = {}    # fighter id -> score esportivo neste snapshot
var changes: Dictionary = {}   # fighter id -> {from, to, reason} vs. snapshot anterior (-1 = fora)
