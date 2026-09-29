"""Authored examples, never simulated results. Game Bible §§6,15,17."""
from pathlib import Path
import json
from copy import deepcopy as cp
ROOT=Path(__file__).resolve().parents[1];D=ROOT/'game/content'
CAT=json.loads((D/'fight_visuals.json').read_text(encoding='utf-8'));CLIPS={c['id']:c for c in CAT['clips']};GROUND={'guard','half_guard','side_control','mount_back','scramble'}
def fixture(id,title,steps,org='org_crown',indices=(0,1),method='submission'):
    first=CLIPS[steps[0][0]]['from_positions'][0]
    state=dict(position=first,top_id='red' if first in GROUND else None,location='center',stamina=dict(red=1,blue=1),damage={k:dict(head=0,body=0,leg=0) for k in ['red','blue']})
    log=dict(version=1,id=id,title=title,source='authored_preview',organization_id=org,ruleset_id='shinsei_ring' if org=='org_shinsei' else 'unified',fighter_ids=['red','blue'],fighters={k:dict(appearance_index=idx,stance='orthodox' if k=='red' else 'southpaw') for k,idx in zip(['red','blue'],indices)},initial_state=cp(state),events=[])
    at=0
    for i,(tech,outcome) in enumerate(steps):
        c=CLIPS[tech];assert state['position'] in c['from_positions'],(tech,state['position']);actor='red' if i%3 else 'blue'
        if state['position'] in GROUND and c['actor_role']!='either':actor=state['top_id'] if c['actor_role']=='top' else ('blue' if state['top_id']=='red' else 'red')
        target='red' if actor=='blue' else 'blue';after=cp(state)
        after['position']='scramble' if outcome=='knockdown' else 'reset' if outcome in ['stoppage','tapped'] else c['to_position'] if outcome in ['completed','held','threatened'] else state['position']
        after['top_id']=(state['top_id'] or actor) if after['position'] in GROUND else None
        if 'sweep' in tech or 'reversal' in tech:after['top_id']=actor
        if after['position'] in ['cage_wrestling','cage_striking']:after['location']='ropes' if org=='org_shinsei' else 'cage'
        elif tech in ['leave_cage','exit_pocket']:after['location']='center'
        after['stamina'][actor]=round(max(.1,after['stamina'][actor]-.018),3)
        if outcome in ['landed','knockdown','stoppage']:
            zone=c['target'] if c['target'] in ['head','body','leg'] else 'head';after['damage'][target][zone]=round(min(1,after['damage'][target][zone]+.075),3)
        e=dict(id=f'{id}_{i:03}',at_ms=at,duration_ms=c['duration_ms'],round=1,clock_s=max(0,300-int(at/1000)),actor_id=actor,target_id=target,technique_id=tech,outcome=outcome,rules_approved=True,reason_codes=['AUTHORED_PREVIEW'],before=cp(state),after=cp(after));log['events'].append(e);at+=e['duration_ms'];state=after
    log['result']=dict(method=method,winner_id=log['events'][-1]['actor_id'] if method not in ['draw','nc'] else None)
    return log
examples=[
 fixture('integrated','MMA · do boxe à finalização',[('jab','blocked'),('cross','landed'),('enter_clinch','completed'),('pummel','held'),('clinch_knee_body','blocked'),('drive_to_cage','completed'),('cage_single','completed'),('half_guard_elbow','blocked'),('knee_slice','completed'),('side_elbow','landed'),('mount_advance','completed'),('mount_punch','blocked'),('rear_naked_choke','tapped')]),
 fixture('striking','Distância · boxe e chutes',[('circle_left','completed'),('outside_low','landed'),('teep','blocked'),('head_roundhouse','evaded'),('switch_kick','landed'),('enter_pocket','completed'),('jab','blocked'),('cross','evaded'),('liver_hook','landed'),('lead_uppercut','blocked'),('overhand','knockdown'),('sit_out','defended')],org='org_frontline',indices=(3,5),method='decision'),
 fixture('wrestling','Wrestling · entradas e grade',[('jab','missed'),('level_change','completed'),('double_leg','defended'),('chain_reshoot','completed'),('guard_posture','completed'),('guard_open','completed'),('wall_walk','completed'),('cage_turn','held'),('cage_single','completed'),('knee_slice','completed'),('mount_advance','completed'),('mount_hammer','stoppage')],org='org_iron',indices=(2,9),method='ko_tko'),
 fixture('ground','Jiu-jítsu · guarda, raspagem e ataque',[('guard_punch','blocked'),('scissor_sweep','completed'),('triangle','escaped'),('guard_open','completed'),('kimura','threatened'),('knee_slice','completed'),('guard_recover','completed'),('armbar_guard','tapped')],org='org_vale',indices=(1,2)),
 fixture('women','Atletas · clinch e chão',[('jab','blocked'),('cross','landed'),('enter_clinch','completed'),('collar_tie','held'),('clinch_knee_body','landed'),('hip_throw','completed'),('guard_recover','completed'),('guard_open','completed'),('knee_slice','completed'),('mount_advance','completed'),('armbar_mount','tapped')],org='org_ascend',indices=(4,6)),
 fixture('shinsei','Shinsei · ringue e grappling',[('collar_tie','held'),('foot_sweep','completed'),('guard_recover','completed'),('guard_posture','completed'),('triangle','threatened'),('triangle','escaped'),('armbar_guard','tapped')],org='org_shinsei',indices=(5,7))
]
for log in examples:(D/'replays'/f'{log["id"]}.json').write_text(json.dumps(log,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(D/'replays/index.json').write_text(json.dumps([dict(id=x['id'],title=x['title'],file=x['id']+'.json') for x in examples],ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(len(examples),'authored replays')
