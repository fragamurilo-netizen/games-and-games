"""Atualiza apenas crest; mantém todos os dados esportivos, financeiros e elencos.

Uso: python tools/crest_gen/refine_clubs.py .
"""
import json
from pathlib import Path
import sys

root = Path(sys.argv[1]) / 'data/world/clubs'

def layer(symbol, color, scale=1, x=0, y=0, **extra):
    return dict(symbol=symbol, sc=color, scale=scale, x=x, y=y, **extra)

changes = {
    'ENG_MSK': dict(shape='ring', field='plain', symbol='none', c1='#FFFFFF', c2='#FFFFFF',
        c3='#6CABDD', tc='#172A47', bc='#172A47', ring_bg='#FFFFFF', border='double', text='MANCHESTER CITY', year='1894',
        sym_scale=1.38, charge_layers=[layer('club_city_shield','#D2AE57'),
            layer('club_city_shield','#FFFFFF',.9),layer('club_rivers','#6CABDD',.75,y=.14),
            layer('club_ship','#D2AE57',.7,y=-.31,dc='#172A47'),layer('club_rose','#C6313C',.24,y=.47,dc='#7B1624')]),
    'ENG_NLR': dict(symbol='club_cannon', sc='#E7C35F', dc='#A87E2B', sym_scale=1.22,
        c1='#C8102E', c2='#9D1024', c3='#E7C35F', bc='#E7C35F', border='thin', finish=False),
    'ENG_MSB': dict(symbol='club_tower', dc='#1D397C', sym_scale=.9,
        charge_layers=[layer('laurel','#FFFFFF',1.1,y=.02)], year='1878'),
    'ENG_ELI': dict(symbol='club_hammers', sc='#E6C360', dc='#B68C2A',
        chief_text='WEST HAM', chief_text2='UNITED', cc='#7A263A', c3='#FFFFFF', bc='#72B7D5', chief_h=.28, border='thin', finish=False),
    'ENG_BEE': dict(symbol='club_bee', sc='#F2C64D', dc='#191919', sym_scale=1.08),
    'ENG_WLV': dict(symbol='club_wolf', sc='#111111', dc='#111111', sym_scale=1.1),
    'ENG_NOT': dict(symbol='club_forest', sc='#FFFFFF', dc='#FFFFFF', sym_scale=1.12),
    'ENG_YOR': dict(symbol='club_rose', dc='#A68B26', sym_scale=1.1),
    'ENG_CHE': dict(shape='french', field='stripes:3', c1='#D71920', c2='#151515', c3='#FFFFFF',
        symbol='club_header', sc='#FFFFFF', dc='#151515', chief_text='AFC BOURNEMOUTH',
        chief_text2='', cc='#151515', chief_h=.23, plate='none', border='thin', finish=False, bc='#D6D6D6', sym_scale=1.05),
    'BRA_RNC': dict(symbol='club_mono_crf', sc='#FFFFFF', plate='none'),
    'BRA_VPA': dict(symbol='club_mono_p', sc='#FFFFFF', plate='none', shape='ring',
        text='PALMEIRAS', text2='', year='1914', tc='#FFFFFF', c1='#006437', c2='#006437', c3='#FFFFFF', border='double'),
    'BRA_TRL': dict(symbol='club_mono_ffc', sc='#FFFFFF', chief_text='', field='halves',
        c1='#78152C', c2='#00613C', fc='#00613C', c3='#FFFFFF', border='double', plate='none', sym_scale=1.12),
    'BRA_COL': dict(symbol='club_mono_sci', sc='#FFFFFF', shape='ring', text='SPORT CLUB INTERNACIONAL',
        text2='', year='1909', c1='#C71029', c2='#C71029', c3='#FFFFFF', tc='#FFFFFF', border='double', sym_scale=1.12),
    'BRA_TIM': dict(charge_layers=[layer('club_city_shield','#FFFFFF',.49,y=.01),
        layer('club_saint','#171717',.38,y=.01)], sym_scale=1.15),
    'BRA_CMA': dict(symbol='none', charge_layers=[layer('club_ship','#FFFFFF',.9,y=.04,dc='#D6D6D6'),
        layer('cross_pattee','#D91928',.32,y=-.1)], sym_scale=1.05),
    'BRA_IMT': dict(symbol='letter', initials='GRÊMIO', mono=False, plate='band', pc='#111111',
        sc='#FFFFFF', field='stripes_tri:3', text='GRÊMIO FOOT-BALL', text2='PORTO ALEGRENSE', year='1903'),
}

count=0
for path in sorted(root.glob('*.json')):
    before=path.read_bytes()
    data=json.loads(before)
    touched=False
    for club in data.get('clubs',[]):
        crest=club.get('crest',{})
        original=dict(crest)
        # Navios e martelos são símbolos compartilhados de vários clubes.
        for key in ['symbol','chief_sym','canton_sym']:
            if key in crest:
                crest[key] = {'ship':'club_ship', 'hammers':'club_hammers'}.get(crest[key],crest[key])
        if club['key'] in changes:
            crest.update(changes[club['key']])
        if crest != original:
            club['crest']=crest
            touched=True
            count+=1
    if touched:
        path.write_text(json.dumps(data,ensure_ascii=False,indent='\t')+'\n',encoding='utf-8')
print('escudos atualizados:',count)
