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
clips=[]
def add(id,label,category,styles,froms,family='strike',target='head',hand=0,to=None,duration=1600,variant=0):
    if isinstance(froms,str):froms=[froms]
    source=froms[0];dest=to or source
    bottom_ids={'knockdown_recover','triangle','armbar_guard','omoplata','guillotine','guard_recover','half_guard_recover','hip_escape','bridge_escape','scissor_sweep','butterfly_sweep','hip_bump_sweep','kimura_sweep','back_escape','technical_stand','wall_walk','wrestle_up'}
    actor_role='bottom' if id in bottom_ids else 'top' if source in ['guard','half_guard','side_control','mount_back','scramble'] else 'either'
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
    clips.append(dict(id=id,label=label,category=category,actor_role=actor_role,styles=styles.split(),from_positions=froms,to_position=dest,family=family,target=target,limb=hand,duration_ms=duration,contact_t=.56,outcomes=outcomes,tracks=frames,notes='Resultado e legalidade fornecidos pelo motor; variação visual não resolve combate.'))
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
for c in clips:
    c['selection_weight']=2.2 if c['id'] in ['jab','cross','body_cross','outside_low','calf_kick','teep','double_leg','single_leg','guard_punch','mount_punch','rear_naked_choke'] else .18 if any(x in c['id'] for x in ['spinning','wheel','flying','crescent','backfist','slicer']) else 1.0
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
