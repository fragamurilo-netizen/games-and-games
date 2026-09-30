class_name FightEngine
extends RefCounted
## Probabilistic exchange engine. Game Bible §6; MMA Bible §§7,20,30.
## Presentation only reads the append-only events emitted here. No UI dependency.
## All probability draws use world.rng. Overall is deliberately absent.

const POSITIONS := ["long_range", "pocket", "cage_striking", "clinch", "open_wrestling", "cage_wrestling", "guard", "half_guard", "side_control", "mount_back", "scramble", "reset"]
const GROUND := ["guard", "half_guard", "side_control", "mount_back", "scramble"]
var _tuning: Dictionary = ContentDB.load_json("fight_tuning.json")
var _catalog: Dictionary = ContentDB.load_json("fight_techniques.json")
var _clips := {}

var _by_position := {}

func _init() -> void:
	for clip: Dictionary in _catalog.clips:
		_clips[clip.id] = clip
		# Candidate lists per position: the catalog is large, the choice runs every exchange.
		if clip.category == "official":
			continue
		for position: String in clip.from_positions:
			if not _by_position.has(position):
				_by_position[position] = []
			_by_position[position].append(clip)

func simulate(world: WorldState, fight: Fight) -> Fight:
	if fight.status != "booked":
		return fight
	var a: Fighter = world.fighters.get(fight.fighter_a_id)
	var b: Fighter = world.fighters.get(fight.fighter_b_id)
	if a == null or b == null or a.id == b.id or fight.rounds < 1 or fight.rounds > 5:
		fight.reasons.append(Reason.make("INVALID_FIGHT_INPUT"))
		return fight
	var event: FightEvent = world.events.get(fight.event_id)
	var org_id: String = event.organization_id if event else a.organization_id
	var org: Organization = world.organizations.get(org_id)
	var ruleset_id: String = org.ruleset_id if org else "unified"
	var rule := {}
	for item: Dictionary in ContentDB.load_json("rulesets.json"):
		if item.id == ruleset_id:
			rule = item
	if rule.is_empty() or fight.rounds > int(rule.max_rounds):
		fight.reasons.append(Reason.make("INVALID_RULESET"))
		return fight
	var ids := [a.id, b.id]
	var state := {"position":"reset", "top_id":null, "location":"center", "stamina":{}, "damage":{}, "stun":{}, "cuts":{}, "submission":{}, "unanswered":{}}
	var totals := {}
	for id: String in ids:
		state.stamina[id] = 1.0
		state.damage[id] = {"head":0.0,"body":0.0,"leg":0.0}
		state.stun[id] = 0.0
		state.cuts[id] = 0.0
		state.unanswered[id] = 0
		totals[id] = _empty_stats()
	var c := {"world":world,"fight":fight,"ids":ids,"fighters":{a.id:a,b.id:b},"org_id":org_id,"rule":rule,"state":state,"totals":totals,"round_stats":{},"round":1,"elapsed":0.0,"at_ms":0.0,"events":[],"last":{},"finished":false,"judges":[],"round_reports":[]}
	for i in 3:
		c.judges.append(Judge.random_profile(world.rng))
	for round_number in fight.rounds:
		c.round = round_number + 1
		c.elapsed = 0.0
		c.events = []
		c.round_stats = {a.id:_empty_stats(),b.id:_empty_stats()}
		_append_official(c, "round_start", a.id, "long_range", "ROUND_START")
		while c.elapsed < float(_tuning.round_seconds) and not c.finished:
			var actor := _choose_actor(c)
			var target: String = b.id if actor == a.id else a.id
			var clip := _choose_clip(c, actor, target)
			if clip.is_empty():
				# Explicit reset event, not an invented attack, if a content gap exists.
				_append_official(c, "referee_break", actor, "reset", "NO_COMPATIBLE_TECHNIQUE")
				_append_official(c, "round_start", actor, "long_range", "REFEREE_RESTART")
				continue
			var seconds := minf(world.rng.range_f(_tuning.exchange_seconds[0], _tuning.exchange_seconds[1]), float(_tuning.round_seconds) - c.elapsed)
			_resolve(c, actor, target, clip, seconds)
		if not c.finished:
			_append_official(c, "round_end", a.id, "reset", "ROUND_ENDED")
		var report := {"round":c.round,"fighter_ids":ids.duplicate(),"elapsed_s":c.elapsed,"stats":c.round_stats.duplicate(true),"events":c.events.duplicate(true),"scores":[]}
		for judge: Judge in c.judges:
			report.scores.append(judge.score_round(report, world.rng))
		c.round_reports.append(report)
		fight.round_log.append(report.duplicate(true))
		if c.finished:
			break
		if round_number < fight.rounds - 1:
			# Interval recovery belongs to the next round's opening snapshot.
			# Emit an event so before/after continuity is never silently broken.
			c.events = []
			var before: Dictionary = c.state.duplicate(true)
			for id: String in ids:
				var f: Fighter = c.fighters[id]
				var gain := float(_tuning.round_recovery) * (0.65 + _skill(f,"physical","recovery") / 150.0)
				c.state.stamina[id] = minf(1.0 - c.state.damage[id].body * 0.25, c.state.stamina[id] + gain)
				c.state.stun[id] *= 0.2
				c.state.unanswered[id] = 0
			c.state.submission = {}
			_emit(c,a.id,b.id,_clips.corner_rest,"completed",before,[Reason.make("CORNER_RECOVERY",gain_for_report(before,c.state,ids))],0.0)
			fight.round_log.append({"round":c.round,"interval":true,"events":c.events.duplicate(true)})
	if not c.finished:
		_decision(c)
	fight.stats = {"fighters":totals.duplicate(true),"engine_version":1,"organization_id":org_id,"ruleset_id":ruleset_id,"rounds_completed":c.round,"presentation_ms":c.at_ms}
	fight.damage = c.state.damage.duplicate(true)
	fight.status = "completed"
	_update_records(world,fight)
	return fight

static func gain_for_report(before: Dictionary, after: Dictionary, ids: Array) -> float:
	return (after.stamina[ids[0]] - before.stamina[ids[0]] + after.stamina[ids[1]] - before.stamina[ids[1]]) * 0.5

## Quanto a diferença de habilidade pesa em cada disputa (>1 = mais zebras).
func _spread() -> float:
	return float(_tuning.get("skill_spread", 1.0))

static func _skill(f: Fighter, group: String, key: String) -> float:
	var values: Dictionary = f.get(group)
	return clampf(float(values.get(key, 50)), 1.0, 100.0)

static func _empty_stats() -> Dictionary:
	return {"attempted":0,"landed":0,"head":0,"body":0,"leg":0,"knockdowns":0,"takedown_attempts":0,"takedowns":0,"submission_attempts":0,"escapes":0,"control_s":0.0,"striking_impact":0.0,"grappling_impact":0.0,"aggression":0.0,"dominant_s":0.0}

func _choose_actor(c: Dictionary) -> String:
	var weights := {}
	for id: String in c.ids:
		var f: Fighter = c.fighters[id]
		var weight := 0.7 + _skill(f,"physical","speed") / 150.0 + _skill(f,"mental","aggression") / 250.0
		weight *= 0.55 + c.state.stamina[id] * 0.45
		if c.state.position in GROUND:
			weight *= 2.3 if c.state.top_id == id else 0.8
		if not c.state.submission.is_empty():
			weight *= float(_tuning.submission.attacker_actor_weight) if c.state.submission.attacker_id == id else 0.4
		if c.last.get("target_id") == id and c.last.get("outcome") in ["evaded","blocked","missed"]:
			weight *= 1.35
		weights[id] = weight
	return c.world.rng.weighted(weights)

func _choose_clip(c: Dictionary, actor: String, _target: String) -> Dictionary:
	var f: Fighter = c.fighters[actor]
	var base: String = f.martial_base if _tuning.styles.has(f.martial_base) else "mma"
	var profile: Dictionary = _tuning.styles[base]
	var candidates: Array = []
	var counts := {}
	for clip: Dictionary in _by_position.get(c.state.position,[]):
		if c.state.position in GROUND:
			if clip.actor_role == "top" and c.state.top_id != actor:
				continue
			if clip.actor_role == "bottom" and c.state.top_id == actor:
				continue
		if c.rule.venue == "ring" and ("cage" in clip.id or clip.id == "wall_walk" or clip.id == "drive_to_cage"):
			continue
		candidates.append(clip)
		counts[clip.category] = int(counts.get(clip.category,0)) + 1
	# Signature techniques of a real base dominate that fighter's repertoire; the category
	# total is renormalized so the style profile (and combat calibration) keeps its shape.
	var sig: Dictionary = _tuning.get("signature",{})
	var repertoire := {}
	var repertoire_sum := {}
	for clip: Dictionary in candidates:
		var k := 1.0
		if clip.get("signature",false):
			k = float(sig.get("own",1.0)) if base in clip.styles else float(sig.get("mma",1.0)) if base == "mma" else float(sig.get("other",1.0))
		repertoire[clip.id] = k
		repertoire_sum[clip.category] = float(repertoire_sum.get(clip.category,0.0)) + k
	var weights := {}
	for clip: Dictionary in candidates:
		var weight := float(profile.get(clip.category,1.0)) / float(counts[clip.category])
		weight *= float(repertoire[clip.id]) * float(counts[clip.category]) / float(repertoire_sum[clip.category])
		weight *= clampf(float(f.style.get(clip.category,1.0)),0.05,4.0)
		if base in clip.styles:
			weight *= 1.25
		if clip.family in ["move","defense"]:
			weight *= 0.50 + (1.0-c.state.stamina[actor]) * 1.4
		weight *= float(clip.get("selection_weight",1.0))
		# Intent adapts to fatigue, accumulated damage and the last exchange.
		if c.state.stamina[actor] < .35 and clip.family in ["move","defense"]:
			weight *= 2.0
		if c.state.damage[actor].head > .4 and clip.category in ["defense","scramble","takedown"]:
			weight *= 1.5
		if clip.family in ["strike","kick"] and c.last.get("actor_id") == actor and c.last.get("outcome") == "landed":
			weight *= 1.5
		if clip.id == "enter_pocket":
			weight *= 3.0
		if clip.id == "level_change" or clip.id == "enter_clinch":
			weight *= 1.6 if base in ["wrestling","bjj","sambo","judo"] else 0.6
		if clip.id == "exit_pocket":
			weight *= 0.55
		weights[clip.id] = weight
	if weights.is_empty():
		return {}
	# Keep working an established submission. Its pull is measured against the whole set of
	# alternative submissions, so a larger catalog does not dilute the attack (MMA Bible §20).
	var ongoing: String = str(c.state.submission.get("technique_id","")) if not c.state.submission.is_empty() and actor == c.state.submission.attacker_id else ""
	if weights.has(ongoing):
		var others := 0.0
		for clip: Dictionary in candidates:
			if clip.family == "submission" and clip.id != ongoing:
				others += float(weights[clip.id])
		weights[ongoing] = maxf(float(weights[ongoing])*float(_tuning.submission.repeat_clip_weight),others*float(_tuning.submission.repeat_clip_weight)/3.0)
	return _clips[c.world.rng.weighted(weights)]

func _resolve(c: Dictionary, actor: String, target: String, clip: Dictionary, seconds: float) -> void:
	var before: Dictionary = c.state.duplicate(true)
	var a: Fighter = c.fighters[actor]
	var b: Fighter = c.fighters[target]
	var rng: SimRandom = c.world.rng
	var reasons: Array = [Reason.make("INTENT_" + clip.category.to_upper(),0.0,{"style":a.martial_base,"technique":clip.id})]
	for id: String in c.ids:
		c.state.stun[id] = maxf(0.0,c.state.stun[id] - seconds * float(_tuning.stun_decay_per_second))
	var effort: float = {"strike":0.012,"kick":0.019,"entry":0.035,"transition":0.024,"submission":0.023,"control":0.011,"move":-0.009,"defense":-0.006}.get(clip.family,0.01)
	var cardio := _skill(a,"physical","cardio")
	var cost: float = effort * (1.35-cardio/150.0) * (1.0+c.state.damage[actor].body*.6)
	c.state.stamina[actor] = clampf(c.state.stamina[actor]-cost,float(_tuning.stamina_floor),1.0-c.state.damage[actor].body*.25)
	c.state.stamina[target] = clampf(c.state.stamina[target]+seconds*.0015,float(_tuning.stamina_floor),1.0-c.state.damage[target].body*.25)
	var outcome := "completed"
	if clip.family in ["strike","kick"]:
		outcome = _strike(c,actor,target,clip,reasons)
	elif clip.family == "entry":
		_bump(c,actor,"takedown_attempts",1)
		var offense := _skill(a,"grappling","takedown_offense")*.6+_skill(a,"physical","strength")*.2+_skill(a,"physical","explosiveness")*.2
		var defense := _skill(b,"grappling","takedown_defense")*.7+_skill(b,"physical","mobility")*.3
		var probability := clampf(.44+(offense-defense)/(150.0*_spread())+(c.state.stamina[actor]-c.state.stamina[target])*.22+c.state.damage[target].leg*.15,.06,.88)
		outcome = "completed" if rng.chance(probability) else "defended"
		reasons.append(Reason.make("TAKEDOWN_CONTEST",probability,{"offense":offense,"defense":defense}))
		if outcome == "completed":
			c.state.position = clip.to_position
			c.state.top_id = actor
			_bump(c,actor,"takedowns",1)
			# Positional change alone has little score; offense from it matters later.
			_bump(c,actor,"grappling_impact",.012)
		else:
			c.state.stamina[actor] = maxf(float(_tuning.stamina_floor),c.state.stamina[actor]-.012)
	elif clip.family == "submission":
		outcome = _submission(c,actor,target,clip,reasons)
	elif clip.family == "transition":
		var contested: bool = c.state.position in GROUND or clip.id in ["enter_clinch","drive_to_cage"]
		var probability: float = .58+(_skill(a,"jiu_jitsu","transitions")-_skill(b,"grappling","top_control"))/(220.0*_spread())+(c.state.stamina[actor]-c.state.stamina[target])*.15
		outcome = "completed" if not contested or rng.chance(clampf(probability,.12,.88)) else "defended"
		if outcome == "completed":
			c.state.position = clip.to_position
			if c.state.position in GROUND:
				if c.state.top_id == null or "sweep" in clip.id or "reversal" in clip.id:
					c.state.top_id = actor
			else:
				c.state.top_id = null
			if clip.category == "scramble" or clip.actor_role == "bottom":
				_bump(c,actor,"escapes",1)
			_bump(c,actor,"grappling_impact",.008 if c.state.position in GROUND else 0.0)
			c.state.submission = {}
		reasons.append(Reason.make("POSITION_CONTEST",probability,{"destination":clip.to_position}))
	elif clip.family == "control":
		var probability := clampf(.66+(_skill(a,"grappling","clinch")-_skill(b,"grappling","scramble"))/(220.0*_spread()),.20,.90)
		outcome = "held" if rng.chance(probability) else "escaped"
		if outcome == "escaped":
			c.state.position = "pocket" if c.state.position in ["clinch","cage_wrestling"] else "scramble"
			c.state.top_id = actor if c.state.position in GROUND else null
		reasons.append(Reason.make("CONTROL_CONTEST",probability))
	else:
		c.state.unanswered[actor] = maxi(0,c.state.unanswered[actor]-1)
		reasons.append(Reason.make("RECOVER_OR_MEASURE",-cost))
	if not c.state.submission.is_empty() and clip.family != "submission" and not c.finished:
		c.state.submission.progress = maxf(0.0,c.state.submission.progress-.10)
		if c.state.submission.progress <= .05 or c.state.position not in GROUND:
			c.state.submission = {}
	if c.state.position in ["cage_wrestling","cage_striking"]:
		c.state.location = "cage" if c.rule.venue == "cage" else "ropes"
	elif clip.id in ["leave_cage","exit_pocket","enter_pocket"]:
		c.state.location = "center"
	if c.state.position in GROUND and c.state.top_id != null:
		_bump(c,c.state.top_id,"control_s",seconds)
		if c.state.position in ["side_control","mount_back"]:
			_bump(c,c.state.top_id,"dominant_s",seconds)
	if clip.family in ["strike","kick","entry","submission"]:
		_bump(c,actor,"aggression",1.0)
	c.elapsed += seconds
	_emit(c,actor,target,clip,outcome,before,reasons,seconds)

func _strike(c: Dictionary, actor: String, target: String, clip: Dictionary, reasons: Array) -> String:
	var a: Fighter = c.fighters[actor]
	var b: Fighter = c.fighters[target]
	var rng: SimRandom = c.world.rng
	var technical: float = _skill(a,"striking","kicks") if clip.family == "kick" else _skill(a,"striking","boxing")
	if clip.category == "gnp":
		technical = _skill(a,"grappling","ground_and_pound")
	var accuracy := _skill(a,"striking","accuracy")*.55+technical*.45
	var defense: float = _skill(b,"striking","defense") * (.65+c.state.stamina[target]*.35) * (1.0-c.state.stun[target]*.3)
	var counter: bool = c.last.get("actor_id") == target and c.last.get("outcome") in ["missed","evaded","blocked"]
	var reach := clampf(float(a.reach_cm-b.reach_cm)/700.0,-.07,.07)
	var probability := clampf(.36+(accuracy-defense)/(170.0*_spread())+reach+c.state.stun[target]*.12+(0.06 if counter else 0.0),.10,.84)
	_bump(c,actor,"attempted",1)
	reasons.append(Reason.make("STRIKE_ACCURACY",probability,{"accuracy":accuracy,"defense":defense,"counter":counter}))
	if not rng.chance(probability):
		c.state.unanswered[target] = maxi(0,c.state.unanswered[target]-1)
		return rng.weighted({"blocked":.45,"evaded":.32,"missed":.23})
	var zone: String = clip.target if clip.target in ["head","body","leg"] else "head"
	var power := .45+_skill(a,"striking","power")/100.0+_skill(a,"physical","explosiveness")/250.0
	var resistance := .75+_skill(b,"physical","durability")/150.0
	var damage: float = float(_tuning.strike_damage)*float(_tuning.get("strike_damage_by_sex",{}).get("f" if a.sex==Fighter.Sex.FEMALE else "m",1.0))*power/resistance*rng.range_f(.72,1.32)*(.5+c.state.stamina[actor]*.5)
	if "jab" in clip.id:
		damage *= .64
	if clip.family == "kick":
		damage *= 1.35
	if counter:
		damage *= 1.18
	if clip.category == "gnp":
		damage *= 1.12
	c.state.damage[target][zone] = minf(1.0,c.state.damage[target][zone]+damage)
	c.state.unanswered[target] += 1
	c.state.unanswered[actor] = 0
	_bump(c,actor,"landed",1)
	_bump(c,actor,zone,1)
	_bump(c,actor,"striking_impact",damage)
	reasons.append(Reason.make("DAMAGE_"+zone.to_upper(),damage,{"power":power,"resistance":resistance}))
	if zone == "body":
		c.state.stamina[target] = maxf(float(_tuning.stamina_floor),c.state.stamina[target]-damage*.85)
	if zone == "head":
		var chin := _skill(b,"physical","chin")
		var cs: Dictionary = _tuning.clean_shot
		var clean := rng.chance(clampf(float(cs.base)+(accuracy-defense)/float(cs.skill_divisor),float(cs.min),float(cs.max)))
		c.state.stun[target] = minf(1.0,c.state.stun[target]+damage*(6.5-chin/35.0)+(float(cs.stun) if clean else 0.0))
		# Elbows open cuts far more often than gloved punches (MMA Bible §7).
		if rng.chance(damage*(6.0 if "elbow" in clip.id else 2.0)):
			c.state.cuts[target] = minf(1.0,c.state.cuts[target]+rng.range_f(.08,.20))
		var collapse: bool = c.state.stun[target] > .60 and rng.chance(.14+(100.0-chin)/170.0)
		var unable: bool = c.state.unanswered[target] >= int(_tuning.tko_unanswered) and c.state.damage[target].head > .28 and (c.state.stamina[target] < .56 or c.state.stun[target] > .32 or c.state.position in GROUND)
		if collapse or unable or (c.state.damage[target].head > .82 and rng.chance(.28)):
			_finish(c,actor,"ko_tko","ko" if collapse else "referee_tko", "LOSS_OF_CONSCIOUSNESS" if collapse else "UNANSWERED_EFFECTIVE_OFFENSE")
			reasons.append(Reason.make("REFEREE_STOP",c.state.stun[target]))
			return "stoppage"
		if c.state.position not in GROUND and c.state.stun[target] > float(_tuning.knockdown_threshold) and rng.chance(.48):
			c.state.position = "scramble"
			c.state.top_id = actor
			_bump(c,actor,"knockdowns",1)
			reasons.append(Reason.make("KNOCKDOWN",c.state.stun[target]))
			return "knockdown"
	elif c.state.damage[target][zone] > .88 and c.state.stamina[target] < .28 and rng.chance(.15):
		_finish(c,actor,"ko_tko","body_tko" if zone == "body" else "leg_tko","UNABLE_TO_CONTINUE_"+zone.to_upper())
		return "stoppage"
	return "landed"

func _submission(c: Dictionary, actor: String, target: String, clip: Dictionary, reasons: Array) -> String:
	var a: Fighter = c.fighters[actor]
	var b: Fighter = c.fighters[target]
	var rng: SimRandom = c.world.rng
	var existing: Dictionary = c.state.submission
	var progress := 0.06
	if not existing.is_empty() and existing.attacker_id == actor:
		progress = float(existing.progress)*(1.0 if existing.technique_id == clip.id else .65)
	else:
		_bump(c,actor,"submission_attempts",1)
	var offense := _skill(a,"jiu_jitsu","leg_locks") if clip.target == "leg" else _skill(a,"jiu_jitsu","submission_offense")
	var defense := _skill(b,"jiu_jitsu","submission_defense")
	var escape := clampf(float(_tuning.submission.escape_base)+(defense-offense)/(200.0*_spread())+c.state.stamina[target]*.12-progress*.18,.08,.77)
	reasons.append(Reason.make("SUBMISSION_CONTEST",1.0-escape,{"type":clip.id,"offense":offense,"defense":defense,"progress_before":progress}))
	if rng.chance(escape):
		c.state.submission = {}
		_bump(c,target,"escapes",1)
		reasons.append(Reason.make("SUBMISSION_ESCAPE",escape))
		return "escaped"
	progress = clampf(progress+float(_tuning.submission.progress_gain)+(offense-defense)/(260.0*_spread())+(1.0-c.state.stamina[target])*.16+rng.range_f(-.04,.07),0.0,1.0)
	c.state.submission = {"attacker_id":actor,"defender_id":target,"technique_id":clip.id,"progress":progress}
	c.state.stamina[target] = maxf(float(_tuning.stamina_floor),c.state.stamina[target]-.022)
	_bump(c,actor,"grappling_impact",.015+progress*.035)
	if progress >= .94:
		_finish(c,actor,"submission",clip.id,"SUBMISSION_SECURED")
		reasons.append(Reason.make("TAP_OUT",progress,{"type":clip.id}))
		return "tapped"
	return "threatened"

func _bump(c: Dictionary, id: String, field: String, amount: float) -> void:
	c.totals[id][field] += amount
	c.round_stats[id][field] += amount

func _finish(c: Dictionary, winner: String, method: String, detail: String, reason: String) -> void:
	c.finished = true
	c.fight.winner_id = winner
	c.fight.method = method
	c.fight.method_detail = detail
	c.fight.end_round = c.round
	c.state.position = "reset"
	c.state.top_id = null
	c.fight.reasons.append(Reason.make(reason,0.0,{"winner_id":winner,"method_detail":detail}))

func _emit(c: Dictionary, actor: String, target: String, clip: Dictionary, outcome: String, before: Dictionary, reasons: Array, seconds: float) -> void:
	var event := {"id":"%s_r%d_e%d" % [c.fight.id,c.round,int(c.at_ms)],"at_ms":c.at_ms,"duration_ms":float(clip.duration_ms),"round":c.round,"clock_s":maxf(0.0,float(_tuning.round_seconds)-c.elapsed),"actor_id":actor,"target_id":target,"technique_id":clip.id,"outcome":outcome,"rules_approved":true,"reason_codes":reasons.map(func(r: Dictionary): return r.code),"reasons":reasons.duplicate(true),"before":before.duplicate(true),"after":c.state.duplicate(true),"exchange_seconds":seconds}
	c.events.append(event)
	c.at_ms += event.duration_ms
	c.last = event
	if c.finished:
		c.fight.end_time_s = int(round(c.elapsed))

func _append_official(c: Dictionary, technique: String, actor: String, destination: String, reason: String) -> void:
	var before: Dictionary = c.state.duplicate(true)
	c.state.position = destination
	c.state.top_id = null
	c.state.location = "center"
	c.state.submission = {}
	var target: String = c.ids[1] if c.ids[0] == actor else c.ids[0]
	_emit(c,actor,target,_clips[technique],"completed",before,[Reason.make(reason)],0.0)

func _decision(c: Dictionary) -> void:
	var votes := [0,0]
	var cards: Array = []
	for i in 3:
		var totals := [0,0]
		var rounds: Array = []
		if c.rule.scoring == "whole_fight":
			var whole := {"fighter_ids":c.ids,"stats":c.totals,"elapsed_s":float(_tuning.round_seconds)*c.round}
			var score: Array = c.judges[i].score_round(whole,c.world.rng)
			totals = [1 if score[0]>score[1] else 0,1 if score[1]>score[0] else 0]
		else:
			for report: Dictionary in c.round_reports:
				var score: Array = report.scores[i]
				rounds.append(score.duplicate())
				totals[0] += score[0]
				totals[1] += score[1]
		if totals[0] > totals[1]: votes[0] += 1
		elif totals[1] > totals[0]: votes[1] += 1
		cards.append({"judge_id":"judge_%d" % i,"rounds":rounds,"total":totals,"scoring":c.rule.scoring})
	c.fight.scorecards = cards
	c.fight.method = "draw" if maxi(votes[0],votes[1]) < 2 else "decision"
	c.fight.winner_id = "" if c.fight.method == "draw" else c.ids[0 if votes[0]>votes[1] else 1]
	c.fight.method_detail = "unanimous" if maxi(votes[0],votes[1]) == 3 else "split" if mini(votes[0],votes[1]) == 1 else "majority"
	c.fight.end_round = c.round
	c.fight.end_time_s = int(_tuning.round_seconds)
	c.fight.reasons.append(Reason.make("JUDGES_DECISION",0.0,{"votes":votes,"scoring":c.rule.scoring}))

func _update_records(world: WorldState, fight: Fight) -> void:
	var ratings := {fight.fighter_a_id: world.fighters[fight.fighter_a_id].rating, fight.fighter_b_id: world.fighters[fight.fighter_b_id].rating}
	var ev: FightEvent = world.events.get(fight.event_id)
	for id: String in [fight.fighter_a_id,fight.fighter_b_id]:
		var fighter: Fighter = world.fighters[id]
		var opponent_id: String = fight.fighter_b_id if id == fight.fighter_a_id else fight.fighter_a_id
		fighter.fight_ids.append(fight.id)
		var result := "D" if fight.method == "draw" else "NC" if fight.method == "nc" else "W" if id == fight.winner_id else "L"
		# Cartel, métodos, rating público, sequência e resumo recente (CareerHistory).
		CareerHistory.record_result(fighter, ev.date if ev else world.date, result, fight.method, fight.method_detail, fight.end_round, ratings[opponent_id], {"fight_id": fight.id, "opponent_id": opponent_id, "opponent": world.fighters[opponent_id].first_name + " " + world.fighters[opponent_id].last_name, "organization_id": ev.organization_id if ev else "", "title": fight.title_stakes == "title"})
		fighter.damage_history.head += float(fight.damage[id].head)
		fighter.damage_history.body += float(fight.damage[id].body)
		fighter.damage_history.legs += float(fight.damage[id].leg)
