extends Node
## Barramento global de sinais. Sistemas de simulação emitem; UI e outros
## sistemas escutam. Nenhum sistema deve chamar a UI diretamente.

signal world_loaded
signal day_advanced(date: Dictionary)
signal week_advanced(date: Dictionary)

signal fight_booked(fight_id: String)
signal fight_cancelled(fight_id: String, reason_code: String)
signal fight_resolved(fight_id: String)
signal event_completed(event_id: String)

signal contract_signed(contract_id: String)
signal ranking_updated(org_id: String, division: String)
signal news_published(news_id: String)

signal month_advanced(date: Dictionary)
signal fighter_retired(fighter_id: String)
signal organization_tier_changed(org_id: String, tier: String)
signal season_closed(season: int)

# Sede (simulation/office): a UI reage; nenhum sistema chama a UI direto.
signal dilemma_created(dilemma_id: String)
signal office_changed
## Microfeedback: tone good | bad | neutral | money.
signal toast(text: String, tone: String)
