"""Desenhos próprios: símbolos de futebol e heráldica com proporções reconhecíveis.

Não importa imagens, SVGs nem bancos de brasões.
Uso: python tools/crest_gen/club_art.py scripts/ui/components/crest_art.gd
"""
import math
import sys
from art_lib import *

S = {}

# Canhão: tubo torneado, boca, munhões, roda com aro e seis raios.
barrel = smooth([(-.91,-.18),(-.7,-.27),(-.24,-.25),(.67,-.38),(.75,-.33),(.83,-.39),(.94,-.37),(.96,-.12),(.83,-.1),(.76,-.16),(.67,-.1),(-.24,.05),(-.7,.07),(-.91,-.02)],3)
S['club_cannon'] = J(barrel, rect(-.23,-.03,-.1,.3), rect(-.38,.27,.11,.38),
    ell(-.13,.4,.34,.34,n=40), stroke([(-.08,.4),(.45,.62),(.57,.62)],.11,.06))
S['club_cannon_c'] = J(ell(-.13,.4,.26,.26,n=36))
spokes = [ell(-.13,.4,.075,.075,n=20)]
for i in range(6):
    a=i*math.tau/6
    spokes.append(stroke([(-.13,.4),(-.13+math.cos(a)*.275,.4+math.sin(a)*.275)],.035,.025,False))
S['club_cannon_d'] = J(*spokes,stroke([(-.66,-.19),(.65,-.29)],.022,.022,False),rect(.82,-.35,.86,-.12))

# Navio de três mastros: velas curvas, vergas, cordame, casco e ondas separados.
ship = [[(-.93,.42),(.95,.42),(.63,.73),(-.58,.73)],
    rect(-.56,-.78,-.52,.44),rect(-.025,-.95,.025,.44),rect(.52,-.7,.56,.44)]
for x, top, width in [(-.54,-.65,.38),(0,-.82,.43),(.54,-.57,.34)]:
    ship.append(smooth([(x-width/2,top),(x+width/2,top),(x+width*.47,top+.32),(x-width*.55,top+.32),(x-width*.4,top+.15)],3))
    ship.append(smooth([(x-width*.6,top+.4),(x+width*.6,top+.4),(x+width*.7,top+.83),(x-width*.7,top+.83),(x-width*.5,top+.6)],3))
    ship.append(stroke([(x-width*.7,top+.85),(x,top-.08),(x+width*.7,top+.85)],.014,.014,False))
ship.extend([stroke([(-.8,.86),(-.4,.8),(0,.87),(.4,.8),(.8,.85)],.035,.035),
    [(-.02,-.97),(.3,-.91),(-.02,-.85)]])
S['club_ship'] = J(*ship)
S['club_ship_d'] = J(stroke([(-.74,.52),(0,.58),(.75,.52)],.025,.025,False))
S['club_ship_c'] = J(*[stroke([(x-width*.52,top+.37),(x,top+.34),(x+width*.52,top+.37)],.028,.028,False)
    for x,top,width in [(-.54,-.65,.38),(0,-.82,.43),(.54,-.57,.34)]],
    stroke([(-.68,.6),(0,.66),(.67,.6)],.035,.035,False))
S['club_city_shield'] = J([(-.88,-.9),(.88,-.9),(.83,.15),(.5,.65),(0,.96),(-.5,.65),(-.83,.15)])
S['club_rivers'] = J(stroke([(-.65,.02),(-.25,-.04),(.2,.03),(.65,-.03)],.09,.09),
    stroke([(-.52,.25),(-.2,.19),(.15,.25),(.52,.2)],.08,.08),
    stroke([(-.33,.45),(0,.39),(.33,.45)],.07,.07))

# Rosa heráldica e abelha: desenho simétrico com lóbulos e membros articulados.
petals=[]
for i in range(5):
    a=-math.pi/2+i*math.tau/5
    petals.append(ell(math.cos(a)*.43,math.sin(a)*.43,.32,.39,a-math.pi/2,24))
S['club_rose'] = J(*petals,ell(0,0,.35,.35,n=28))
S['club_rose_d'] = J(*[stroke([(math.cos(a)*.17,math.sin(a)*.17),(math.cos(a)*.56,math.sin(a)*.56)],.035,.025,False) for a in [i*math.tau/5 for i in range(5)]],ell(0,0,.15,.15,n=20))
S['club_bee'] = J(ell(0,.1,.26,.6,n=32),ell(0,-.55,.21,.2,n=24),
    ell(-.38,-.15,.32,.5,-.6,28),ell(.38,-.15,.32,.5,.6,28),
    stroke([(-.09,-.7),(-.2,-.9),(-.3,-.92)],.035,.025),stroke([(.09,-.7),(.2,-.9),(.3,-.92)],.035,.025),
    *[stroke([(sx*.17,y),(sx*.4,y+.08),(sx*.55,y+.31)],.04,.025) for sx in [-1,1] for y in [.08,.32]])
S['club_bee_c'] = J(ell(-.38,-.18,.21,.34,-.6,24),ell(.38,-.18,.21,.34,.6,24))
S['club_bee_d'] = J(rect(-.25,-.12,.25,-.02),rect(-.25,.15,.25,.25),rect(-.18,.42,.18,.51))

# Wolf frontal de linhas facetadas; não usa o lobo de perfil genérico do catálogo.
S['club_wolf'] = J([(-.88,-.88),(-.22,-.55),(0,-.61),(.22,-.55),(.88,-.88),(.78,-.05),(.46,.55),(0,.94),(-.46,.55),(-.78,-.05)])
S['club_wolf_c'] = J([(-.66,-.32),(-.14,-.12),(-.3,.08),(-.53,.04)],[(.66,-.32),(.14,-.12),(.3,.08),(.53,.04)])
S['club_wolf_d'] = J([(-.16,.36),(.16,.36),(0,.54)],stroke([(0,.52),(0,.71)],.035,.035,False))

# Árvore de copa lobada e três linhas de água, com tronco contínuo.
tree=[(-.14,.6),(-.13,.03),(-.48,.16),(-.74,.06),(-.78,-.14),(-.65,-.28),(-.72,-.44),(-.58,-.6),(-.35,-.59),(-.3,-.79),(-.13,-.9),(.08,-.84),(.21,-.95),(.4,-.82),(.41,-.63),(.64,-.56),(.74,-.37),(.63,-.2),(.76,-.04),(.62,.13),(.4,.15),(.14,.02),(.13,.6)]
S['club_forest'] = J(smooth(tree,3),*[stroke([(-.77,y),(-.38,y-.06),(0,y+.02),(.38,y-.06),(.77,y)],.06,.06) for y in [.62,.79,.96]])

# Martelos com cabeças desenhadas e cabo afunilado.
hammer=[(-.83,-.84),(-.33,-.84),(-.25,-.65),(-.44,-.6),(.79,.69),(.66,.82),(-.58,-.46),(-.63,-.26),(-.83,-.33)]
S['club_hammers'] = J(hammer,mirror(hammer))
S['club_hammers_d'] = J(stroke([(-.76,-.77),(-.4,-.77)],.025,.025,False),stroke([(.76,-.77),(.4,-.77)],.025,.025,False))

# Torre de pedra e louros laterais, uma silhueta vertical coerente com o brasão.
S['club_tower'] = J([(-.44,.86),(-.36,-.48),(-.52,-.6),(-.52,-.88),(-.3,-.88),(-.3,-.7),(-.1,-.7),(-.1,-.9),(.1,-.9),(.1,-.7),(.3,-.7),(.3,-.88),(.52,-.88),(.52,-.6),(.36,-.48),(.44,.86)],rect(-.55,.82,.55,.94))
S['club_tower_d'] = J(rect(-.06,-.46,.06,-.16),rect(-.055,.05,.055,.28),ell(0,.67,.13,.2,n=24),rect(-.13,.67,.13,.87),
    *[stroke([(-.34,y),(.34,y)],.014,.014,False) for y in [-.1,.31,.52]])

# Cabeça e bola do escudo dos Cherries: desenho estilizado próprio.
S['club_header'] = J(smooth([(-.35,.9),(-.36,.6),(-.65,.52),(-.8,.27),(-.68,.04),(-.61,-.28),(-.37,-.42),(-.16,-.32),(-.05,-.08),(.12,.03),(.02,.15),(.04,.3),(-.08,.49),(.04,.73),(.33,.9)],3),ell(.27,-.65,.34,.34,n=36))
S['club_header_d'] = J(jag(.27,-.65,.09,.12,5,rot=-math.pi/2),stroke([(-.56,-.09),(-.4,-.16)],.025,.025,False))

# Monogramas vetoriais próprios: hastes, curvas abertas, pés e travessas se
# entrelaçam. Não dependem de uma fonte nem do texto comprimido do brasão.
def letter_c(cx,cy,w,h):
    return stroke([(cx+w*.3,cy-h*.72),(cx-w*.15,cy-h),(cx-w*.55,cy-h*.62),
                   (cx-w*.6,cy+h*.42),(cx-w*.12,cy+h),(cx+w*.35,cy+h*.7)],.13,.105)
def letter_f(cx,cy,w,h):
    return [rect(cx-w*.23,cy-h,cx-w*.08,cy+h),rect(cx-w*.35,cy-h,cx+w*.55,cy-h*.78),
            rect(cx-w*.22,cy-h*.08,cx+w*.35,cy+h*.12),rect(cx-w*.4,cy+h*.83,cx+w*.1,cy+h)]
def letter_r(cx,cy,w,h):
    return [rect(cx-w*.35,cy-h,cx-w*.19,cy+h),
            stroke([(cx-w*.25,cy-h*.93),(cx+w*.4,cy-h*.94),(cx+w*.52,cy-h*.4),(cx-w*.22,cy-h*.04)],.13,.13),
            stroke([(cx-w*.12,cy-.04),(cx+w*.52,cy+h)],.14,.12),rect(cx-w*.48,cy+h*.85,cx-w*.04,cy+h)]
S['club_mono_crf'] = J(letter_c(-.18,-.13,.95,.75),*letter_r(.18,.13,.95,.75),*letter_f(-.05,-.01,.8,.77))
S['club_mono_ffc'] = J(*letter_f(-.3,-.12,.82,.73),*letter_f(.13,.13,.82,.73),letter_c(.25,-.01,.8,.8))
S['club_mono_sci'] = J(stroke([(.12,-.84),(-.48,-.74),(-.55,-.34),(.37,.02),(.45,.45),(-.3,.78),(-.6,.54)],.14,.12),
    letter_c(.2,.04,.92,.75),rect(.05,-.74,.2,.86),rect(-.1,-.85,.37,-.69),rect(-.1,.7,.38,.86))
S['club_mono_p'] = J(rect(-.43,-.88,-.23,.86),
    stroke([(-.33,-.8),(.43,-.8),(.58,-.38),(.34,-.05),(-.3,-.04)],.17,.15),
    rect(-.6,.72,-.03,.9),rect(-.6,-.9,-.15,-.73))

# São Jorge e dragão do Corinthians: medalhão pequeno de silhueta própria.
S['club_saint'] = J(ell(-.05,-.63,.13,.15,n=20),
    stroke([(-.08,-.47),(.03,-.05),(-.27,.23)],.18,.13),
    stroke([(-.14,-.37),(.2,-.18),(.35,-.4)],.08,.06),
    stroke([(.26,-.87),(.12,-.12),(-.08,.59)],.025,.025),
    smooth([(-.7,.0),(-.45,-.12),(-.25,-.03),(.2,.08),(.42,-.15),(.51,-.45),(.68,-.5),(.77,-.3),(.6,-.06),(.46,.3),(.15,.42),(-.45,.35),(-.7,.21)],3),
    stroke([(-.45,.25),(-.52,.65),(-.65,.79)],.08,.05),stroke([(.2,.32),(.4,.62),(.63,.64)],.09,.05),
    smooth([(-.65,.68),(-.36,.57),(-.1,.63),(.16,.57),(.45,.73),(.26,.85),(-.13,.78),(-.45,.89)],3))

if __name__ == '__main__':
    emit(sys.argv[1], S)
    print('desenhos próprios:',len(S))
