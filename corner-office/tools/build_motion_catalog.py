"""Author paired 2D animation clips. Game Bible §§5–6,15; MMA Bible §§7,20.
No combat probabilities: these tracks only illustrate a resolved event.
Run from any directory. Generated content is committed for Godot/web consumers.
"""
from pathlib import Path
from copy import deepcopy as cp
import json, math
ROOT=Path(__file__).resolve().parents[1]
CONTENT=ROOT/'game/content'
def save(name,data):
    (CONTENT/name).write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
# root is pelvis; hands/feet are world anchors in metres, y points up.
def pose(x=-.44,y=.88,lean=7,hands=None,feet=None):
    return dict(root=[x,y],lean=lean,hands=hands or [[x+.25,1.48],[x+.38,1.31]],feet=feet or [[x-.23,.055],[x+.27,.055]],bend=[-1,1,1,1],head=0,facing=1)
def mirror(p):
    p=cp(p)
    for k in ['root']:p[k][0]*=-1
    for k in ['hands','feet']:
        for v in p[k]:v[0]*=-1
    p['lean']*=-1;p['head']*=-1;p['facing']*=-1;p['bend']=[-v for v in p['bend']]
    return p
def pair(position='pocket'):
    a,b=pose(),mirror(pose())
    if position=='long_range':a=pose(-.78);b=mirror(pose(-.78))
    if position in ['clinch','cage_wrestling']:
        a=pose(-.29,.86,13,[[-.04,1.51],[.19,1.14]],[[-.55,.055],[-.05,.055]])
        b=mirror(a)
    if position=='open_wrestling':
        a=pose(-.48,.64,42,[[.15,.72],[.29,.54]],[[-.8,.055],[-.12,.055]])
        b=pose(.48,.76,-25,[[.03,1.03],[-.05,.83]],[[.26,.055],[.83,.055]])
    if position in ['guard','half_guard','side_control','mount_back','scramble']:
        # Actor is the top fighter; sample mirrors roles from the event top_id.
        b=pose(.29,.18,-88,[[-.20,.66],[-.36,.43]],[[.81,.18],[.68,.61]])
        a=pose(.08,.55,-50,[[-.36,.50],[-.27,.76]],[[.52,.08],[.57,.22]])
        if position=='guard':b['feet']=[[.31,.81],[.62,.66]]
        if position=='half_guard':b['feet']=[[.75,.09],[.50,.39]]
        if position=='side_control':a=pose(-.10,.52,62,[[.60,.39],[.10,.27]],[[-.55,.08],[-.35,.22]])
        if position=='mount_back':a=pose(-.05,.54,-8,[[-.33,.65],[-.10,.90]],[[.39,.08],[-.29,.08]])
        if position=='scramble':a=pose(-.34,.46,49,[[.23,.12],[.33,.36]],[[-.81,.06],[-.46,.08]]);b=pose(.43,.50,-43,[[-.11,.18],[-.34,.32]],[[.82,.06],[.54,.08]])
    if position=='reset':a=pose(-1.1);b=mirror(pose(-1.1))
    return [a,b]
STYLES=[('boxing','Boxe','Guarda compacta, jab, combinações e esquivas.'),('muay_thai','Muay Thai','Base ereta, chutes, joelhos e controle de clinch.'),('kickboxing','Kickboxing','Combinações de mãos e pernas, entradas e saídas.'),('karate','Karatê','Base lateral, distância e ataques de interceptação.'),('taekwondo','Taekwondo','Chutes de distância e mudanças de base.'),('wrestling','Wrestling','Mudança de nível, encadeamento de quedas e pressão.'),('bjj','Jiu-jítsu','Guardas, passagens, controle e ameaças de submissão.'),('judo','Judô','Desequilíbrios, varridas e projeções adaptadas ao no-gi.'),('sambo','Sambo','Quedas encadeadas, controle e ataques às pernas.'),('mma','MMA integrado','Transições entre todas as fases; estilos não são classes rígidas.')]
PHASES={'movement':'Movimentação','boxing':'Boxe e cotovelos','kicks':'Chutes e joelhos','defense':'Defesas','clinch':'Clinch e grade','takedown':'Quedas','ground':'Chão e transições','gnp':'Ground-and-pound','submission':'Finalizações','scramble':'Scrambles e levantadas','official':'Árbitro e encerramento'}
def shape_motion(motion,family,target,hand,outcome,start,wind,impact,end):
    """Distinct key poses per real-world mechanic (MMA Bible §7). Only illustrates the resolved outcome."""
    a,b=impact;wa=wind[0];hit=outcome not in ['missed','evaded']
    eff='hands' if family=='strike' else 'feet'
    if motion=='hook':
        wa['hands'][hand]=[wa['root'][0]+.05,1.48];a['lean']+=8;a['head']=-8
        if hit:a['hands'][hand][1]+=.03
    elif motion=='uppercut':
        wa['hands'][hand]=[wa['root'][0]+.02,.98];wa['root'][1]-=.08;wa['lean']+=12;a['lean']-=6;a['root'][1]+=.03
        if hit:b['head']=-22;b['lean']-=6
    elif motion=='overhand':
        wa['hands'][hand]=[wa['root'][0]-.28,1.78];a['lean']+=16;a['root'][1]-=.06
    elif motion=='superman':
        wa['feet'][0]=[wa['root'][0]-.55,.5];wa['root'][1]+=.08;a['root'][1]+=.22
        a['feet']=[[a['root'][0]-.5,.38],[a['root'][0]+.05,.3]];a['lean']+=12
    elif motion=='lunge':
        wa['root'][1]-=.05;a['root'][1]-=.1;a['lean']+=10
        a['feet']=[[a['root'][0]-.55,.055],[a['root'][0]+.42,.055]]
    elif motion=='elbow':
        a['root'][0]+=.12;a['hands'][hand]=[a['root'][0]+.3,1.52];a['lean']+=12;a['head']=-10
    elif motion=='body_lean':
        a['root'][1]-=.12;a['lean']+=18;wa['root'][1]-=.06
    elif motion=='front_kick':
        wa['feet'][hand]=[wa['root'][0]+.28,.72];a['lean']=-16
    elif motion=='side_kick':
        wa['feet'][hand]=[wa['root'][0]+.12,.78];wa['lean']=-18;a['lean']=-38;a['head']=12
    elif motion=='back_kick':
        wa['lean']=24;wa['head']=-45;a['lean']=-46;a['head']=30;a['root'][1]-=.03
    elif motion=='axe':
        wa['feet'][hand]=[wa['root'][0]+.35,2.05];wa['lean']=-20
        if hit:a['feet'][hand]=[b['root'][0]-.1,1.45]
        a['lean']=-14
    elif motion=='hook_kick':
        wa['feet'][hand]=[wa['root'][0]+.5,1.5];wa['lean']=-30;a['lean']=-32;a['head']=15
    elif motion=='jump_kick':
        wa['root'][1]+=.1;a['root'][1]+=.32;a['feet'][1-hand]=[a['root'][0]-.25,.6];a['lean']-=8
    elif motion=='spin_jump':
        wa['lean']=-30;wa['head']=-40;wa['root'][1]+=.12;a['root'][1]+=.35;a['feet'][1-hand]=[a['root'][0]-.2,.7];a['head']=28
    elif motion=='stomp':
        a['lean']=-20;a['feet'][hand][1]=min(a['feet'][hand][1],.5)
    elif motion=='cut_kick':
        a['lean']=-22;a['feet'][hand]=[b['root'][0]-.02,.26]
        if hit:b['lean']-=24;b['feet'][0][1]+=.18
    elif motion=='hip_throw':
        a['root']=[b['root'][0]-.06,.72];a['lean']=34;a['hands']=[[a['root'][0]+.05,1.22],[a['root'][0]+.3,1.0]]
        if outcome=='completed':b['root']=[a['root'][0]+.12,1.16];b['lean']=-92;b['feet']=[[b['root'][0]+.62,1.44],[b['root'][0]+.8,1.18]];b['hands']=[[b['root'][0]-.3,1.12],[b['root'][0]-.1,.9]]
    elif motion=='inner_thigh':
        a['root']=[b['root'][0]-.1,.8];a['lean']=48;a['feet'][1]=[a['root'][0]+.34,1.12];a['feet'][0]=[a['root'][0]-.12,.055]
        if outcome=='completed':b['root']=[a['root'][0]+.22,1.05];b['lean']=-80;b['feet']=[[b['root'][0]+.55,1.55],[b['root'][0]+.72,1.3]]
    elif motion=='shoulder_throw':
        a['root']=[b['root'][0]-.02,.6];a['lean']=58;a['hands']=[[a['root'][0]-.08,1.25],[a['root'][0]+.08,1.2]]
        if outcome=='completed':b['root']=[a['root'][0]+.05,1.3];b['lean']=-120;b['feet']=[[b['root'][0]-.2,1.95],[b['root'][0]+.1,1.9]];b['hands']=[[b['root'][0]-.2,1.0],[b['root'][0]+.1,.95]]
    elif motion=='reap':
        a['root']=[b['root'][0]-.28,.84];a['lean']=20;a['feet'][1]=[b['root'][0]+.1,.32]
        if outcome=='completed':b['lean']=-48;b['root'][1]=.72;b['feet'][0]=[b['root'][0]-.2,.5]
    elif motion=='foot_sweep':
        a['lean']=-8;a['feet'][1]=[b['root'][0]-.12,.08]
        if outcome=='completed':b['lean']=-62;b['root'][1]=.62;b['feet']=[[b['root'][0]+.4,.42],[b['root'][0]+.62,.2]]
    elif motion=='lift':
        a['root'][1]=.82;a['lean']=-12;a['hands']=[[a['root'][0]+.2,1.2],[a['root'][0]+.3,1.0]]
        if outcome=='completed':b['root']=[a['root'][0]+.18,1.42];b['lean']=-100;b['feet']=[[b['root'][0]+.5,1.8],[b['root'][0]+.7,1.6]]
    elif motion=='suplex':
        a['root'][1]=.7;a['lean']=-58;a['hands']=[[a['root'][0]+.05,1.1],[a['root'][0]+.18,1.0]]
        if outcome=='completed':b['root']=[a['root'][0]-.22,1.45];b['lean']=-150;b['feet']=[[b['root'][0]+.3,2.1],[b['root'][0]+.5,1.9]]
    elif motion=='sacrifice':
        a['root']=[a['root'][0]+.2,.32];a['lean']=-72;a['feet'][1]=[a['root'][0]+.35,.95]
        if outcome=='completed':b['root']=[a['root'][0]+.2,1.25];b['lean']=78;b['feet']=[[b['root'][0]-.6,1.55],[b['root'][0]-.4,1.7]]
    elif motion=='fireman':
        a['root']=[b['root'][0]-.1,.52];a['lean']=40;a['hands']=[[a['root'][0]+.3,.5],[a['root'][0]+.1,1.25]]
        if outcome=='completed':b['root']=[a['root'][0]+.05,1.34];b['lean']=90;b['feet']=[[b['root'][0]+.6,1.3],[b['root'][0]+.75,1.2]]
    elif motion=='duck_under':
        a['root']=[b['root'][0]+.1,.66];a['lean']=36;a['head']=-20
        if outcome=='completed':b['lean']=24;b['root'][1]=.7
    elif motion=='catch_kick':
        b['feet'][0]=[a['root'][0]+.2,.95];a['hands']=[[a['root'][0]+.18,.98],[a['root'][0]+.3,.9]];a['lean']=-6
        if outcome=='completed':b['lean']=-55;b['root'][1]=.6
    elif motion=='plum':
        a['hands']=[[b['root'][0]-.02,1.62],[b['root'][0]+.05,1.58]];b['head']=30;b['lean']+=20
    elif motion=='sweep_bottom':
        a['feet']=[[b['root'][0]-.05,.6],[b['root'][0]+.1,.9]];b['root'][1]+=.2;b['lean']+=20
    elif motion=='invert':
        a['root'][1]=.25;a['lean']=-150;a['feet']=[[b['root'][0]+.05,.95],[b['root'][0]-.12,1.05]]
    elif motion=='choke_back':
        a['hands']=[[b['root'][0]+.05,1.0],[b['root'][0]-.08,.95]];a['root']=[b['root'][0]+.2,b['root'][1]+.05]
    elif motion=='choke_front':
        a['hands']=[[b['root'][0]-.05,.66],[b['root'][0]+.08,.6]];a['lean']+=20;b['head']=35
    elif motion=='leg_lock':
        a['root']=[b['root'][0]+.35,.2];a['lean']=80;a['feet']=[[b['root'][0]+.2,.35],[b['root'][0]+.5,.45]];a['hands']=[[b['root'][0]+.6,.4],[b['root'][0]+.72,.36]]
    elif motion=='arm_lock':
        a['root']=[b['root'][0]-.05,.24];a['lean']=-80;a['feet']=[[b['root'][0]-.25,.75],[b['root'][0]+.1,.8]];a['hands']=[[b['root'][0]-.1,.95],[b['root'][0]-.02,.9]]
    elif motion=='pin':
        a['root'][1]-=.12;a['lean']=78;a['hands']=[[b['root'][0]-.15,.35],[b['root'][0]+.3,.3]]
    elif motion=='stance_blade':
        for q in [wa,a]:q['feet']=[[q['root'][0]-.45,.055],[q['root'][0]+.38,.055]];q['lean']=2
    elif motion=='shell':
        for q in [wa,a]:q['hands']=[[q['root'][0]+.2,1.24],[q['root'][0]+.08,1.56]];q['lean']=-8;q['head']=-10
    elif motion=='bob':
        a['root'][1]-=.22;a['lean']+=24;a['head']=10
    elif motion=='lean_back':
        a['lean']-=26;a['root'][0]-=.1;a['head']=-15

clips=[]
def add(id,label,category,styles,froms,family='strike',target='head',hand=0,to=None,duration=1600,variant=0,motion=None,signature=False,role=None,combo=0):
    if isinstance(froms,str):froms=[froms]
    source=froms[0];dest=to or source
    bottom_ids={'knockdown_recover','triangle','armbar_guard','omoplata','guillotine','guard_recover','half_guard_recover','hip_escape','bridge_escape','scissor_sweep','butterfly_sweep','hip_bump_sweep','kimura_sweep','back_escape','technical_stand','wall_walk','wrestle_up'}
    actor_role=role or ('bottom' if id in bottom_ids else 'top' if source in ['guard','half_guard','side_control','mount_back','scramble'] else 'either')
    outcomes={'strike':['landed','blocked','evaded','missed','knockdown','stoppage'],'kick':['landed','blocked','evaded','missed','knockdown','stoppage'],'entry':['completed','defended'],'transition':['completed','defended'],'submission':['threatened','escaped','tapped'],'control':['held','escaped'],'defense':['completed'],'move':['completed'],'official':['completed']}[family]
    frames={}
    for outcome in outcomes:
        start=pair(source);end=pair(dest if outcome in ['completed','held','threatened','tapped'] else source)
        if actor_role=='bottom':
            start.reverse()
            if 'sweep' not in id:end.reverse()
        wind=cp(start);impact=cp(start)
        eff=None
        if family in ['strike','kick']:
            height={'head':1.53,'body':1.06,'leg':.44}.get(target,.92)
            if category=='gnp':height=.44
            a,b=impact
            if family=='strike':
                eff='hands';wind[0]['hands'][hand]=[wind[0]['root'][0]-.15,1.25 if category!='gnp' else 1.01]
                # Hooks and uppercuts use a different wind-up and torso rotation.
                if variant%3==1:wind[0]['hands'][hand][1]=1.61 if category!='gnp' else .85
                if variant%3==2:wind[0]['hands'][hand][1]=.96 if category!='gnp' else .35
                a['lean']+=13;a['root'][0]+=.16
                contact=[b['root'][0]-.06,height]
                if category=='gnp':contact=[-.20,height]
                a['hands'][hand]=contact
            else:
                eff='feet';wind[0]['feet'][hand]=[wind[0]['root'][0]+.16,.66]
                a['lean']=-24 if height>1 else -10;a['root'][0]+=.15
                a['feet'][hand]=[b['root'][0]-.06,height]
                a['hands']=[[a['root'][0]-.16,1.38],[a['root'][0]+.14,1.49]]
            if outcome=='blocked':b['hands'][0]=[b['root'][0]-.15,height];b['hands'][1]=[b['root'][0]-.06,height-.13];a[eff][hand][0]-=.13
            if outcome in ['evaded','missed']:
                b['root'][0]+=.30;b['lean']+=20
                for h in b['hands']:h[0]+=.28
                a[eff][hand][0]-=.28
            if outcome in ['landed','knockdown','stoppage']:b['head']=18;b['lean']+=9
            if outcome in ['knockdown','stoppage']:
                end[1]=pose(.73,.16,-76,[[.16,.36],[.44,.29]],[[1.29,.09],[1.34,.34]])
                end[0]=pose(-.45)
        elif family=='entry':
            wind[0]=pose(-.37,.50,53,[[.27,.63],[.40,.52]],[[-.76,.05],[-.02,.05]])
            impact[0]=pose(-.03,.50,64,[[.42,.57],[.49,.76]],[[-.46,.05],[.02,.05]])
            impact[1]=pose(.37,.61,-36,[[.01,.85],[-.12,.72]],[[.76,.16],[.48,.36]])
            if variant%3==1:impact[0]['lean']=22;impact[1]['lean']=-65;impact[1]['root'][1]=.81
            if variant%3==2:impact[1]['feet']=[[.79,.35],[.62,.62]];impact[0]['root'][1]=.71
            if outcome=='defended':impact[1]=pose(.57,.48,-60,[[-.15,.85],[-.03,.65]],[[1.06,.06],[.82,.06]])
        elif family in ['transition','submission','control']:
            impact=cp(end if family=='transition' and outcome=='completed' else start)
            impact[0]['root'][0]+=.07*(1 if variant%2 else -1)
            impact[0]['lean']+=8*(1 if variant%2 else -1)
            if family=='submission':
                target_point=[-.20,.40] if target=='head' else ([.60,.29] if target=='leg' else [-.30,.62])
                impact[0]['hands']=[target_point,[target_point[0]+.10,target_point[1]+.07]]
                if target=='arm':impact[0]['feet']=[[-.27,.78],[.48,.48]]
                if target=='leg':impact[0]['lean']=67;impact[0]['root']=[.10,.21];impact[0]['feet']=[[.85,.19],[.72,.48]]
                if 'triangle' in id:impact[0]['feet']=[[-.32,.81],[-.12,.72]]
                if 'rear_naked' in id:
                    impact[0]=pose(.24,.39,-20,[[-.12,1.00],[-.24,.93]],[[.24,.08],[-.34,.08]])
                    impact[1]=pose(-.02,.26,-18,[[-.17,.91],[-.31,.88]],[[.38,.08],[-.43,.08]])
                if outcome=='tapped':end=cp(impact);end[1]['hands'][0]=[.03,.61]
                elif outcome=='escaped':end=pair(source)
                else:end=cp(impact)
            elif family=='control':
                impact[0]['hands'][variant%2]=[impact[1]['root'][0]-.07,1.40 if source in ['clinch','cage_wrestling'] else .47]
                if outcome=='escaped':end=pair('pocket' if source in ['clinch','cage_wrestling'] else 'scramble')
        elif family=='defense':
            impact[0]['lean']-=18+variant*2;impact[0]['root'][1]-=.10*(variant%3)
            impact[0]['hands']=[[-.38,1.57],[-.26,1.46]]
            if 'check' in id:impact[0]['feet'][0]=[-.18,.55]
            if 'sprawl' in id:impact[0]=pose(-.35,.44,67,[[.24,.36],[.16,.52]],[[-.94,.06],[-.68,.06]])
        elif family=='move':
            direction=1 if variant%2 else -1
            for p in impact:
                p['root'][0]+=.16*direction
                for k in ['hands','feet']:
                    for v in p[k]:v[0]+=.16*direction
            impact[0]['lean']+=variant%4*3
            if 'switch' in id:impact[0]['feet'].reverse();impact[0]['hands'].reverse()
        elif family=='official':
            if id=='celebrate':impact[0]['hands']=[[-.89,1.99],[-.30,2.03]];end=cp(impact)
            if id in ['corner_rest','doctor_check']:impact[0]=pose(-.94,.43,14,[[-.65,.77],[-.83,.82]],[[-1.11,.06],[-.60,.06]]);end=cp(impact)
            if id=='referee_stop':end=pair('reset')
        # Ensure strike contact is in reach of the rig, instead of extending bones.
        if family in ['strike','kick'] and outcome not in ['missed','evaded']:
            a,b=impact
            if category!='gnp':
                angle=math.radians(b['lean']); head=[b['root'][0]+math.sin(angle)*.62,b['root'][1]+math.cos(angle)*.62]
                contact=[head[0]-.09,head[1]-.03] if target=='head' else [b['root'][0]-.06,b['root'][1]+.23] if target=='body' else [b['root'][0]-.08,.40]
                if outcome=='blocked':contact=[contact[0]-.12,contact[1]];b['hands'][0]=contact
                eff='hands' if family=='strike' else 'feet';a[eff][hand]=contact
                needed=contact[0]-(.58 if family=='strike' else .45 if target=='head' else .64)
                delta=needed-a['root'][0];a['root'][0]=needed
                if family=='kick' and target=='head':a['root'][1]=.90
                for pt in a['hands']:
                    if pt is not a[eff][hand]:pt[0]+=delta*.6
                for j,pt in enumerate(a['feet']):
                    if eff!='feet' or j!=hand:pt[0]+=delta*.75
            if 'spinning' in id or id=='wheel_kick':wind[0]['lean']=-32;wind[0]['head']=-30;impact[0]['head']=25
            if family=='kick' and target=='head':
                a['feet'][1-hand]=[a['root'][0]-.16,.055]
            if 'knee' in id:
                a['lean']=8;a['root']=[contact[0]-.32,1.2 if id=='flying_knee' else .89]
                hip=[a['root'][0]+(.092 if hand else -.092),a['root'][1]]
                dx,dy=contact[0]-hip[0],contact[1]-hip[1];length=max(.01,math.hypot(dx,dy))
                knee=[hip[0]+dx/length*.44,hip[1]+dy/length*.44]
                a['feet'][hand]=[knee[0]-.22,knee[1]-.37]
                a['feet'][1-hand]=[a['root'][0]-.16,.24 if id=='flying_knee' else .055]
                a['hands']=[[a['root'][0]+.11,1.43],[a['root'][0]+.25,1.49]]
        if motion:shape_motion(motion,family,target,hand,outcome,start,wind,impact,end)
        frames[outcome]=[dict(t=0,a=start[0],b=start[1]),dict(t=.26,a=wind[0],b=wind[1]),dict(t=.56,a=impact[0],b=impact[1]),dict(t=1,a=end[0],b=end[1])]
        if family in ['strike','kick']:
            # Hands accelerate late, then recoil. Feet have a lift instead of sliding through the mat.
            frames[outcome].insert(2,dict(t=.43,a=cp(wind[0]),b=cp(wind[1])))
            if outcome not in ['knockdown','stoppage']:
                frames[outcome].insert(-1,dict(t=.82,a=cp(end[0]),b=cp(end[1])))
        if family=='move':
            for phase in [wind,impact]:
                phase[0]['feet'][variant%2][1]+=.055
            frames[outcome][1]['a']=wind[0]
            frames[outcome][2]['a']=impact[0]
        if combo:
            # Setup shots land before the scored contact; they are presentation only.
            lead=frames[outcome][0]
            for k in range(combo):
                hit=cp(lead['a']);tgt=cp(lead['b']);h=(hand+k+1)%2
                hit['hands'][h]=[tgt['root'][0]-.08,1.5 if k%2==0 else 1.1];hit['lean']+=10;hit['root'][0]+=.1
                t0=.04+k*(.2/combo)
                frames[outcome].insert(1+2*k,dict(t=round(t0+.05/combo,3),a=hit,b=tgt))
                frames[outcome].insert(2+2*k,dict(t=round(t0+.1/combo,3),a=cp(lead['a']),b=cp(lead['b'])))
    clip=dict(id=id,label=label,category=category,actor_role=actor_role,styles=styles.split(),from_positions=froms,to_position=dest,family=family,target=target,limb=hand,duration_ms=duration,contact_t=.56,outcomes=outcomes,tracks=frames,notes='Resultado e legalidade fornecidos pelo motor; variação visual não resolve combate.')
    if motion:clip['motion']=motion
    if signature:clip['signature']=True
    if combo:clip['combo']=combo+1
    clips.append(clip)
# Stable technique ids, not every outcome counted as a new movement.
for i,(id,label) in enumerate([('step_in','Avançar medindo distância'),('step_out','Recuo em guarda'),('circle_left','Circular à esquerda'),('circle_right','Circular à direita'),('pivot','Pivô e saída lateral'),('switch_stance','Troca de base'),('feint_jab','Finta de jab'),('feint_level','Finta de queda'),('cut_cage','Cortar a grade'),('bounce','Base móvel'),('reset_distance','Recompor distância'),('touch_gloves','Toque de luvas')]):add(id,label,'movement','mma boxing karate taekwondo','long_range','move',variant=i)
for i,(id,label,target,hand) in enumerate([('jab','Jab','head',0),('cross','Direto','head',1),('lead_hook','Gancho da frente','head',0),('rear_hook','Gancho de trás','head',1),('lead_uppercut','Uppercut da frente','head',0),('rear_uppercut','Uppercut de trás','head',1),('body_jab','Jab no corpo','body',0),('body_cross','Direto no corpo','body',1),('liver_hook','Gancho no corpo','body',0),('overhand','Overhand','head',1),('check_hook','Check hook','head',0),('shovel_hook','Gancho ascendente','body',1),('long_jab','Jab de encontro','head',0),('short_cross','Direto curto','head',1),('horizontal_elbow','Cotovelo horizontal','head',0),('rising_elbow','Cotovelo ascendente','head',1),('spinning_elbow','Cotovelo giratório','head',1),('backfist','Soco de revés','head',0)]):add(id,label,'boxing','boxing muay_thai kickboxing mma',['pocket','cage_striking'],'strike',target,hand,variant=i)
for i,(id,label,target,hand) in enumerate([('inside_low','Low kick interno','leg',0),('outside_low','Low kick externo','leg',1),('calf_kick','Chute na panturrilha','leg',1),('body_roundhouse','Chute circular no corpo','body',1),('head_roundhouse','Chute circular alto','head',1),('switch_kick','Chute com troca de base','body',0),('teep','Chute frontal de pressão','body',0),('rear_front','Chute frontal de trás','body',1),('side_kick','Chute lateral','body',0),('spinning_back_kick','Chute giratório no corpo','body',1),('wheel_kick','Chute giratório alto','head',1),('question_mark','Chute com mudança de altura','head',0),('crescent_kick','Chute em arco','head',0),('oblique_kick','Chute oblíquo','leg',0),('step_knee','Joelhada de encontro','body',1),('flying_knee','Joelhada com salto','head',1)]):add(id,label,'kicks','muay_thai kickboxing karate taekwondo mma','long_range','kick',target,hand,duration=1900,variant=i)
for i,(id,label) in enumerate([('high_guard','Bloqueio em guarda alta'),('parry','Desvio com a mão'),('slip_inside','Esquiva para dentro'),('slip_outside','Esquiva para fora'),('roll','Pêndulo sob o gancho'),('pull_counter','Recuo de tronco'),('low_check','Bloqueio de low kick'),('kick_catch','Amortecer e segurar chute'),('frame','Frame com antebraço'),('sprawl','Sprawl'),('underhook_defense','Pummel defensivo'),('wall_frame','Frame contra a grade')]):add(id,label,'defense','mma boxing wrestling kickboxing','pocket','defense',variant=i)
for i,(id,label) in enumerate([('collar_tie','Controle de nuca'),('double_collar','Duplo controle de nuca'),('pummel','Pummel por posição interna'),('underhook','Underhook'),('overhook','Overhook defensivo'),('body_lock','Cintura fechada'),('wrist_control','Controle de punho'),('head_position','Pressão de cabeça'),('cage_pin','Fixar na grade'),('cage_turn','Giro na grade'),('dirty_boxing','Boxe curto no clinch'),('clinch_knee_body','Joelhada no corpo no clinch'),('clinch_knee_thigh','Joelhada na coxa'),('clinch_elbow','Cotovelo na saída'),('break_clinch','Romper o clinch')]):
    source='cage_wrestling' if 'cage' in id else 'clinch'
    fam='strike' if id in ['dirty_boxing','clinch_elbow'] else 'kick' if 'knee' in id else 'transition' if id=='break_clinch' else 'control'
    add(id,label,'clinch','muay_thai wrestling judo sambo mma',source,fam,'leg' if 'thigh' in id else 'body' if 'knee' in id else 'head',i%2,to='pocket' if id=='break_clinch' else source,variant=i)
add('enter_clinch','Entrar no clinch','clinch','mma wrestling muay_thai','pocket','transition',to='clinch')
add('drive_to_cage','Conduzir à grade','clinch','mma wrestling','clinch','transition',to='cage_wrestling')
for i,(id,label) in enumerate([('double_leg','Double-leg'),('single_leg','Single-leg'),('high_crotch','Entrada por dentro'),('ankle_pick','Captura do tornozelo'),('knee_tap','Toque no joelho'),('body_lock_trip','Queda da cintura'),('inside_trip','Varrida interna'),('outside_trip','Varrida externa'),('hip_throw','Projeção de quadril'),('foot_sweep','Rasteira'),('lateral_drop','Projeção lateral'),('snap_down','Snap-down'),('mat_return','Retorno ao chão'),('cage_double','Double-leg na grade'),('cage_single','Single-leg na grade'),('chain_reshoot','Reentrada encadeada')]):
    source='cage_wrestling' if 'cage' in id else 'clinch' if i in [5,6,7,8,9,10,12] else 'open_wrestling'
    add(id,label,'takedown','wrestling judo sambo mma',source,'entry',to='guard' if id in ['double_leg','chain_reshoot','cage_double'] else 'half_guard' if 'single' in id else 'side_control',duration=2400,variant=i)
add('level_change','Mudança de nível e entrada','takedown','wrestling sambo mma','pocket','transition',to='open_wrestling')
for i,(id,label,source,dest) in enumerate([('guard_posture','Posturar na guarda','guard','guard'),('guard_open','Abrir a guarda','guard','half_guard'),('knee_slice','Passagem knee-slice','half_guard','side_control'),('over_under_pass','Passagem por pressão','guard','side_control'),('leg_drag','Leg drag','guard','side_control'),('half_guard_crossface','Crossface na meia-guarda','half_guard','half_guard'),('mount_advance','Avançar à montada','side_control','mount_back'),('mount_stabilize','Estabilizar montada','mount_back','mount_back'),('back_take','Tomar as costas','side_control','mount_back'),('seatbelt','Controle seatbelt','mount_back','mount_back'),('guard_recover','Recompor a guarda','side_control','guard'),('half_guard_recover','Recuperar meia-guarda','mount_back','half_guard'),('hip_escape','Fuga de quadril','side_control','half_guard'),('bridge_escape','Ponte de saída','mount_back','scramble'),('scissor_sweep','Raspagem tesoura','guard','guard'),('butterfly_sweep','Raspagem borboleta','guard','half_guard'),('hip_bump_sweep','Raspagem de quadril','guard','guard'),('kimura_sweep','Raspagem com controle do braço','half_guard','side_control'),('turtle_cover','Fechar em tartaruga','side_control','scramble'),('back_escape','Escape das costas','mount_back','half_guard')]):add(id,label,'ground','bjj wrestling judo sambo mma',source,'transition',to=dest,duration=2300,variant=i)
for i,(id,label,source,target) in enumerate([('guard_punch','Soco na guarda','guard','head'),('guard_body_punch','Soco no corpo na guarda','guard','body'),('half_guard_elbow','Cotovelo da meia-guarda','half_guard','head'),('side_elbow','Cotovelo do controle lateral','side_control','head'),('mount_punch','Soco da montada','mount_back','head'),('mount_hammer','Martelo da montada','mount_back','head'),('short_ground_hook','Gancho curto no chão','half_guard','head'),('posture_hammer','Martelo com postura','guard','head')]):add(id,label,'gnp','mma wrestling bjj',source,'strike',target,i%2,variant=i)
for i,(id,label,source,target) in enumerate([('rear_naked_choke','Mata-leão','mount_back','head'),('guillotine','Guilhotina','guard','head'),('arm_triangle','Triângulo de braço','side_control','head'),('triangle','Triângulo','guard','head'),('armbar_guard','Armlock da guarda','guard','arm'),('armbar_mount','Armlock da montada','mount_back','arm'),('kimura','Kimura','half_guard','arm'),('americana','Americana','side_control','arm'),('omoplata','Omoplata','guard','arm'),('darce','D’Arce','half_guard','head'),('anaconda','Anaconda','scramble','head'),('straight_ankle','Chave reta de tornozelo','guard','leg'),('kneebar','Chave de joelho','half_guard','leg'),('heel_hook','Chave de calcanhar','guard','leg'),('calf_slicer','Compressão de panturrilha','half_guard','leg')]):add(id,label,'submission','bjj sambo judo mma',source,'submission',target,duration=3000,variant=i)
for i,(id,label,source,dest) in enumerate([('technical_stand','Levantada técnica','guard','pocket'),('wall_walk','Levantada na grade','half_guard','cage_wrestling'),('wrestle_up','Wrestle-up','guard','open_wrestling'),('sit_out','Sit-out','scramble','open_wrestling'),('granby','Rolamento de recuperação','scramble','guard'),('switch_reversal','Reversão de quadril','scramble','side_control'),('stand_from_turtle','Levantar da tartaruga','scramble','clinch'),('disengage_ground','Soltar e levantar','side_control','long_range')]):add(id,label,'scramble','wrestling bjj sambo mma',source,'transition',to=dest,duration=2400,variant=i)
for id,label in [('round_start','Início de round'),('round_end','Fim de round'),('referee_break','Separação do árbitro'),('referee_stop','Interrupção do árbitro'),('doctor_check','Avaliação médica'),('corner_rest','Intervalo no corner'),('decision','Anúncio da decisão'),('celebrate','Vitória'),('respect','Cumprimento final')]:add(id,label,'official','mma','reset','official',duration=2500)
add('enter_pocket','Fechar a distância','movement','mma','long_range','transition',to='pocket')
add('exit_pocket','Sair do pocket','movement','mma','pocket','transition',to='long_range')
add('cage_separate','Separar as pegadas na grade','clinch','mma','cage_wrestling','transition',to='cage_striking')
add('leave_cage','Sair da grade','movement','mma','cage_striking','transition',to='pocket')
add('knockdown_followup','Ataque após knockdown','gnp','mma wrestling','scramble','strike','head',1)
add('knockdown_recover','Recuperar a base após knockdown','scramble','mma','scramble','transition',to='pocket')
# ---- Repertório por estilo real (rodada de estilos). `signature` = golpe típico da base;
# o motor o favorece para essa base e o torna raro para as demais (MMA Bible §§7,20).
POCKET=['pocket','cage_striking']
def S(rows,category,family,froms,duration=1600,**kw):
    for row in rows:
        id,label,styles,target,hand,motion=row[:6];extra=row[6] if len(row)>6 else {}
        opts={**kw,**{k:v for k,v in extra.items() if k not in ('duration','froms')}}
        add(id,label,category,styles,extra.get('froms',froms),family,target,hand,duration=extra.get('duration',duration),variant=len(clips),motion=motion,signature=True,**opts)
# Boxe: combinações, cortes de ângulo, contragolpes.
S([('one_two','Um-dois','boxing kickboxing','head',1,None,{'combo':1}),('one_two_hook','Um-dois-gancho','boxing kickboxing','head',0,'hook',{'combo':2}),
   ('double_jab','Jab duplo','boxing','head',0,None,{'combo':1}),('jab_body_cross','Jab e direto no corpo','boxing','body',1,'body_lean',{'combo':1}),
   ('liver_shot_combo','Gancho no fígado e cruzado','boxing muay_thai','body',0,'hook',{'combo':1}),('shovel_uppercut_combo','Uppercut e gancho curto','boxing','head',1,'uppercut',{'combo':1}),
   ('pull_counter_cross','Contragolpe após recuo','boxing','head',1,None),('slip_cross','Esquiva e direto','boxing','head',1,'body_lean'),
   ('roll_hook_counter','Pêndulo e gancho','boxing','head',0,'hook'),('pivot_hook','Pivô com gancho','boxing','head',0,'hook'),
   ('shoeshine_body','Sequência curta no corpo','boxing','body',0,'body_lean',{'combo':2}),('bolo_punch','Soco bolo','boxing','body',1,'uppercut'),
   ('check_uppercut','Uppercut de encontro','boxing','head',1,'uppercut'),('overhand_counter','Overhand de contra-ataque','boxing wrestling','head',1,'overhand'),
   ('jab_to_body_lean','Jab no corpo abaixando','boxing wrestling','body',0,'body_lean'),('lead_hook_high_low','Gancho alto e baixo','boxing','head',0,'hook',{'combo':1})],'boxing','strike',POCKET)
S([('shoulder_roll','Rolar o ombro','boxing','head',0,'shell'),('bob_weave','Bob and weave','boxing','head',0,'bob'),('catch_block','Aparar com a luva','boxing kickboxing','head',0,'shell'),
   ('philly_shell','Guarda Philly','boxing','head',0,'shell'),('duck_counter','Abaixar e sair','boxing wrestling','head',0,'bob'),('lean_back_counter','Recuar o tronco','muay_thai kickboxing','head',0,'lean_back')],'defense','defense','pocket')
# Muay thai: joelhos, cotovelos, chutes longos e clinch tailandês.
S([('teep_face','Teep no rosto','muay_thai','head',0,'front_kick'),('long_knee','Joelhada longa','muay_thai','body',1,None),('diagonal_knee','Joelhada diagonal','muay_thai','body',0,None),
   ('switch_knee','Joelhada com troca de base','muay_thai kickboxing','body',0,None),('thai_body_kick','Chute tailandês no corpo','muay_thai','body',1,None,{'duration':2000}),
   ('thai_head_kick','Chute tailandês alto','muay_thai','head',1,None,{'duration':2000}),('thai_low_kick','Low kick tailandês','muay_thai','leg',1,None),
   ('cut_kick','Chute de corte na base','muay_thai kickboxing','leg',0,'cut_kick'),('push_kick_thigh','Teep na coxa','muay_thai','leg',0,'stomp'),
   ('jab_low_kick','Jab e low kick','muay_thai kickboxing','leg',1,None,{'combo':1}),('cross_body_kick','Direto e chute no corpo','muay_thai kickboxing','body',1,None,{'combo':1})],'kicks','kick','long_range',1900)
S([('elbow_slash','Cotovelo cortante','muay_thai','head',1,'elbow'),('uppercut_elbow','Cotovelo ascendente curto','muay_thai','head',0,'elbow'),('stab_elbow','Cotovelo descendente em ângulo','muay_thai','head',1,'elbow'),
   ('double_elbow','Cotovelo duplo','muay_thai','head',0,'elbow',{'combo':1}),('reverse_elbow','Cotovelo reverso','muay_thai','head',1,'elbow')],'boxing','strike',POCKET)
S([('plum_knee','Joelhada no clinch tailandês','muay_thai','head',1,'plum'),('plum_knee_body','Joelhada no corpo na nuca','muay_thai','body',0,'plum'),('side_knee_clinch','Joelhada lateral no clinch','muay_thai','body',1,'plum')],'clinch','kick','clinch')
S([('plum_control','Clinch tailandês','muay_thai','head',0,'plum'),('arm_frame_clinch','Enquadrar e girar no clinch','muay_thai','head',1,None)],'clinch','control','clinch')
S([('clinch_dump','Derrubada do clinch tailandês','muay_thai','body',0,'reap',{'to':'half_guard'}),('catch_kick_sweep','Segurar o chute e varrer','muay_thai kickboxing','leg',0,'catch_kick')],'takedown','entry','clinch',2300,to='side_control')
# Kickboxing: holandês, chutes giratórios, superman.
S([('dutch_combo','Combinação holandesa','kickboxing','leg',1,None,{'combo':2}),('hook_low_kick','Gancho e low kick','kickboxing','leg',1,None,{'combo':1}),
   ('double_roundhouse','Chute circular duplo','kickboxing taekwondo','body',1,None,{'combo':1}),('high_low_kick','Chute alto e baixo','kickboxing','head',1,None,{'combo':1}),
   ('spinning_hook_kick','Chute giratório de gancho','kickboxing taekwondo karate','head',1,'hook_kick',{'duration':2100})],'kicks','kick','long_range',1900)
S([('superman_punch','Superman punch','kickboxing mma','head',1,'superman'),('spinning_backfist','Soco giratório de revés','kickboxing karate','head',0,'spinning'),
   ('jab_cross_hook_body','Um-dois-gancho no corpo','kickboxing','body',0,'hook',{'combo':2})],'boxing','strike',POCKET)
# Karatê: blitz, base lateral, contra-ataques.
S([('blitz_reverse_punch','Blitz com soco reverso','karate','head',1,'lunge'),('lunge_punch','Oi-zuki','karate','head',0,'lunge'),('kizami_gyaku','Jab e reverso de karatê','karate','head',1,'lunge',{'combo':1}),
   ('counter_reverse_punch','Contra com soco reverso','karate','body',1,'lunge'),('ridge_hand','Mão em faca','karate','head',0,'hook')],'boxing','strike',POCKET)
S([('side_kick_knee','Chute lateral no joelho','karate taekwondo','leg',0,'side_kick'),('karate_roundhouse','Mawashi-geri alto','karate','head',1,None),('front_kick_face','Chute frontal no rosto','karate taekwondo','head',1,'front_kick'),
   ('crane_front_kick','Chute frontal da base lateral','karate','head',0,'front_kick'),('ura_mawashi','Chute em gancho','karate taekwondo','head',0,'hook_kick'),('karate_axe_kick','Chute machado','karate taekwondo','head',1,'axe',{'duration':2000})],'kicks','kick','long_range',1900)
S([('bladed_stance','Base lateral de karatê','karate','head',0,'stance_blade'),('blitz_in_out','Entrar e sair em blitz','karate','head',0,'stance_blade'),('stance_switch_feint','Finta com troca de base','karate taekwondo','head',0,'stance_blade')],'movement','move','long_range')
# Taekwondo: chutes saltados e giratórios.
S([('tornado_kick','Chute tornado','taekwondo','head',1,'spin_jump',{'duration':2200}),('back_kick','Chute para trás','taekwondo karate','body',1,'back_kick',{'duration':2000}),
   ('jumping_back_kick','Chute para trás saltado','taekwondo','body',1,'spin_jump',{'duration':2200}),('axe_kick','Chute machado','taekwondo','head',1,'axe',{'duration':2000}),
   ('hopping_side_kick','Chute lateral saltado','taekwondo','body',0,'side_kick'),('fast_roundhouse','Chute circular rápido','taekwondo','body',0,None),
   ('switch_head_kick','Chute alto com troca de base','taekwondo kickboxing','head',0,None),('jumping_switch_kick','Chute saltado com troca','taekwondo','head',0,'jump_kick',{'duration':2100}),
   ('double_head_kick','Chute alto duplo','taekwondo','head',1,None,{'combo':1}),('push_kick','Chute de empurrão','taekwondo','body',0,'front_kick'),
   ('spinning_heel_kick','Chute giratório de calcanhar','taekwondo','head',1,'hook_kick',{'duration':2200}),('butterfly_kick','Chute borboleta','taekwondo','head',1,'spin_jump',{'duration':2300})],'kicks','kick','long_range',1900)
# Wrestling: entradas, finalizações de queda e controle no chão.
S([('blast_double','Double-leg explosivo','wrestling','body',0,None,{'to':'guard'}),('high_crotch_finish','Finalização de high crotch','wrestling','body',0,'lift',{'to':'guard'}),
   ('sweep_single','Sweep single','wrestling','leg',0,None,{'to':'half_guard'}),('low_single','Single baixo','wrestling','leg',0,None,{'to':'half_guard'}),('snatch_single','Snatch single','wrestling','leg',1,None,{'to':'half_guard'}),
   ('duck_under','Duck under','wrestling','body',0,'duck_under'),('arm_drag_takedown','Arm drag e queda','wrestling sambo','body',1,'duck_under'),
   ('fireman_carry','Fireman carry','wrestling sambo','body',0,'fireman'),('double_leg_slam','Double-leg com levantada','wrestling','body',0,'lift',{'to':'guard'}),
   ('body_lock_lift','Levantada pela cintura','wrestling sambo','body',0,'lift'),('suplex','Suplex','wrestling','body',0,'suplex'),
   ('front_headlock_spin','Front headlock e volta','wrestling','head',0,'duck_under'),('outside_step_double','Double-leg com passo externo','wrestling','body',0,None,{'to':'guard'})],'takedown','entry','open_wrestling',2400,to='side_control')

S([('cage_body_lock_trip','Trip na cintura contra a grade','wrestling','body',0,'reap'),('cage_mat_return','Retorno ao chão na grade','wrestling','body',0,'lift',{'to':'half_guard'})],'takedown','entry','cage_wrestling',2400,to='side_control')
S([('whizzer_defense','Whizzer','wrestling','body',0,'lean_back'),('sprawl_go_behind','Sprawl e volta às costas','wrestling','body',0,'pin'),('down_block','Bloqueio da entrada','wrestling','body',0,'bob')],'defense','defense','pocket')
S([('cradle','Cradle','wrestling','body',0,'pin'),('leg_ride','Controle pelas pernas','wrestling','body',1,'pin'),('wrestling_ride','Ride na tartaruga','wrestling','body',0,'pin'),('mat_tilt','Tilt','wrestling','body',1,'pin')],'ground','control','side_control')
S([('wrestling_stand_up','Stand-up de wrestling','wrestling','body',0,None),('hand_fight_up','Controle de mãos e levantar','wrestling','body',1,None)],'scramble','transition','scramble',2300,to='open_wrestling')
# Judô: projeções clássicas adaptadas ao no-gi (Game Bible §22: nomes técnicos genéricos).
S([('o_soto_gari','O-soto-gari','judo sambo','body',0,'reap'),('o_uchi_gari','O-uchi-gari','judo sambo','leg',1,'reap',{'to':'half_guard'}),('ko_uchi_gari','Ko-uchi-gari','judo','leg',0,'foot_sweep',{'to':'half_guard'}),
   ('uchi_mata','Uchi-mata','judo','body',1,'inner_thigh'),('harai_goshi','Harai-goshi','judo','body',1,'hip_throw'),('o_goshi','O-goshi','judo sambo','body',0,'hip_throw'),
   ('seoi_nage','Seoi-nage','judo','body',1,'shoulder_throw'),('tai_otoshi','Tai-otoshi','judo','body',1,'foot_sweep'),('de_ashi_barai','De-ashi-barai','judo','leg',0,'foot_sweep'),
   ('sumi_gaeshi','Sumi-gaeshi','judo','body',0,'sacrifice'),('tomoe_nage','Tomoe-nage','judo','body',0,'sacrifice'),('ura_nage','Ura-nage','judo sambo','body',0,'suplex'),
   ('kouchi_makikomi','Makikomi','judo','body',1,'hip_throw')],'takedown','entry','clinch',2500,to='side_control')
S([('kesa_gatame','Kesa-gatame','judo sambo','body',0,'pin'),('scarf_hold_punch_setup','Controle de lado estilo judô','judo','body',1,'pin')],'ground','control','side_control')
# Jiu-jítsu: raspagens, passagens, pegadas nas costas e finalizações modernas.
S([('x_guard_sweep','Raspagem da guarda X','bjj','leg',0,'sweep_bottom'),('dlr_sweep','Raspagem De La Riva','bjj','leg',1,'sweep_bottom'),('flower_sweep','Raspagem pêndulo','bjj','body',0,'sweep_bottom'),
   ('berimbolo_sweep','Berimbolo','bjj','body',0,'invert',{'to':'mount_back'}),('single_leg_x_sweep','Raspagem da single-leg X','bjj sambo','leg',0,'sweep_bottom'),
   ('elevator_sweep','Raspagem elevador','bjj','body',1,'sweep_bottom')],'ground','transition','guard',2400,to='side_control',role='bottom')
S([('toreando_pass','Passagem toreando','bjj','body',0,None),('stack_pass','Passagem empilhando','bjj wrestling','body',1,None),('leg_weave_pass','Passagem leg weave','bjj','body',0,None),
   ('long_step_pass','Passagem com passo longo','bjj','body',1,None),('body_lock_pass','Passagem de cintura','bjj wrestling','body',0,None)],'ground','transition','guard',2400,to='side_control')
S([('mount_s','Montada em S','bjj','body',0,'pin'),('body_triangle','Triângulo de corpo nas costas','bjj','body',0,'choke_back'),('crucifix','Crucifixo','bjj wrestling','body',1,'pin'),('knee_on_belly','Joelho na barriga','bjj judo','body',0,'pin')],'ground','control','mount_back')
S([('north_south_choke','Estrangulamento norte-sul','bjj','head',0,'choke_front',{'froms':['side_control']}),('ezekiel_choke','Ezequiel','bjj judo','head',0,'choke_front',{'froms':['mount_back']}),
   ('arm_in_guillotine','Guilhotina com braço','bjj','head',0,'choke_front',{'froms':['guard']}),('high_elbow_guillotine','Guilhotina de cotovelo alto','bjj','head',1,'choke_front',{'froms':['guard']}),
   ('von_flue_choke','Estrangulamento Von Flue','bjj','head',0,'choke_front',{'froms':['side_control']}),('peruvian_necktie','Gravata peruana','bjj','head',0,'choke_front',{'froms':['scramble']}),
   ('japanese_necktie','Gravata japonesa','bjj','head',1,'choke_front',{'froms':['scramble']}),('gogoplata','Gogoplata','bjj','head',0,'arm_lock',{'froms':['guard'],'role':'bottom'}),
   ('mounted_triangle','Triângulo montado','bjj','head',0,'choke_front',{'froms':['mount_back']}),('reverse_triangle','Triângulo invertido','bjj','head',1,'choke_front',{'froms':['side_control']}),
   ('twister','Twister','bjj','head',0,'choke_back',{'froms':['mount_back']}),('bicep_slicer','Compressão de bíceps','bjj sambo','arm',0,'arm_lock',{'froms':['mount_back']}),
   ('wrist_lock','Chave de punho','bjj judo','arm',1,'arm_lock',{'froms':['guard'],'role':'bottom'}),('short_choke','Mata-leão curto','bjj','head',0,'choke_back',{'froms':['mount_back']}),
   ('arm_triangle_mount','Triângulo de braço da montada','bjj','head',1,'choke_front',{'froms':['mount_back']})],'submission','submission','mount_back',3000)
# Sambo: quedas encadeadas e chaves de perna.
S([('toe_hold','Chave de dedos','sambo bjj','leg',0,'leg_lock',{'froms':['half_guard']}),('sambo_kneebar','Chave de joelho de sambo','sambo','leg',1,'leg_lock',{'froms':['scramble']}),
   ('estima_lock','Chave de tornozelo em torção','sambo bjj','leg',0,'leg_lock',{'froms':['guard']}),('achilles_lock','Chave de Aquiles','sambo','leg',1,'leg_lock',{'froms':['guard'],'role':'bottom'}),
   ('sambo_armbar','Armlock de sambo da cintura','sambo judo','arm',0,'arm_lock',{'froms':['side_control']})],'submission','submission','half_guard',3000)
S([('sambo_hip_toss','Arremesso de quadril de sambo','sambo','body',0,'hip_throw'),('back_trip','Rasteira por trás','sambo judo','leg',1,'reap'),('sambo_leg_trip','Rasteira de sambo','sambo','leg',0,'foot_sweep'),
   ('kani_basami','Tesoura voadora','sambo','leg',0,'sacrifice'),('sambo_shoulder_throw','Projeção de ombro de sambo','sambo','body',1,'shoulder_throw'),('sambo_double_lift','Levantada dupla de sambo','sambo wrestling','body',0,'lift',{'to':'guard'})],'takedown','entry','clinch',2400,to='side_control')
S([('imanari_roll','Rolamento para chave de perna','sambo bjj','leg',0,'invert')],'scramble','transition','scramble',2400,to='half_guard')
# MMA integrado: transições entre fases.
S([('cage_wall_elbow','Cotovelo contra a grade','mma','head',1,'elbow'),('knee_to_takedown','Joelhada e queda','mma wrestling','body',0,None,{'combo':1}),
   ('feint_overhand','Finta e overhand','mma','head',1,'overhand'),('level_change_uppercut','Finta de queda e uppercut','mma wrestling','head',1,'uppercut')],'boxing','strike',POCKET)
S([('ground_elbow_side','Cotovelada em ângulo no controle lateral','mma','head',0,'elbow',{'froms':['side_control']}),('knee_body_side','Joelhada no corpo do controle lateral','mma wrestling','body',1,None,{'froms':['side_control']}),
   ('back_punches','Socos nas costas pegadas','mma','head',0,None,{'froms':['mount_back']}),('hammerfist_back','Martelo com as costas pegadas','mma','head',1,None,{'froms':['mount_back']}),
   ('crucifix_elbows','Cotoveladas do crucifixo','mma wrestling','head',0,'elbow',{'froms':['mount_back']}),('standing_guard_punch','Soco de pé na guarda','mma wrestling','head',1,'overhand',{'froms':['guard']})],'gnp','strike','guard')

for c in clips:
    c['selection_weight']=2.2 if c['id'] in ['jab','cross','body_cross','outside_low','calf_kick','teep','double_leg','single_leg','guard_punch','mount_punch','rear_naked_choke'] else .18 if any(x in c['id'] for x in ['spinning','wheel','flying','crescent','backfist','slicer']) else 1.0
    # Ground rides/pins illustrate control; they must not crowd out advancing positions.
    if c.get('signature') and c['family']=='control' and c['category']=='ground':c['selection_weight']=.35
    if c['category']=='official':
        c['from_positions']=['reset','long_range','pocket','cage_striking','clinch','open_wrestling','cage_wrestling','guard','half_guard','side_control','mount_back','scramble']
        c['to_position']='long_range' if c['id']=='round_start' else 'reset'
        if c['id']=='round_start':
            for frames in c['tracks'].values():
                end=pair('long_range');frames[-1]['a'],frames[-1]['b']=end
save('fight_visuals.json',dict(version=1,units='metres_y_up',source='Game Design Bible §§5–6,15,17; MMA Bible §§7,20',positions=['long_range','pocket','cage_striking','clinch','open_wrestling','cage_wrestling','guard','half_guard','side_control','mount_back','scramble','reset'],categories=PHASES,styles=[dict(id=i,label=l,description=d) for i,l,d in STYLES],clips=clips))
save('fight_techniques.json',dict(version=1,clips=[{k:v for k,v in c.items() if k not in ['tracks','notes','contact_t']} for c in clips]))
orgs=json.loads((CONTENT/'organizations.json').read_text(encoding='utf-8'))
palettes=[('#B88B46','#22282D','#DBD6C9'),('#427B86','#1A3039','#D7E1E2'),('#477C58','#203A2B','#DDDCD1'),('#B3453E','#342529','#ECE5D7'),('#A45B44','#352A29','#DAD5CD'),('#658087','#243038','#CDD1CA'),('#327C83','#1D3439','#DCE1D8')]
arenas=[]
for i,(o,p) in enumerate(zip(orgs,palettes)):
    arenas.append(dict(id=o['id'],name=o['name'],short_name=o['short_name'],ruleset_id=o['ruleset_id'],venue='ring' if o['id']=='org_shinsei' else 'cage',sides=4 if o['id']=='org_shinsei' else 8,radius_m=4.2 if i==0 else 3.8,height_m=1.75,ropes=4,accent=p[0],apron=p[1],mat=p[2],ink='#253039',steel='#46535E',red_corner='#C83B3B',blue_corner='#426D8B',boundary_opacity=.18,city=o['base_city'],mark=['crown','ascent','valley','sun','lines','hex','wave'][i]))
save('arena_profiles.json',dict(version=1,source='Game Design Bible §§3,16,22; content/rulesets.json',arenas=arenas))
print(f'{len(clips)} techniques, {sum(len(c["tracks"]) for c in clips)} paired outcome tracks, {len(arenas)} arenas')
