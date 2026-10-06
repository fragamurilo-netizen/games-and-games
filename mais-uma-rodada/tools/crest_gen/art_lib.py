"""Ajudantes para desenhar símbolos do CrestArt em Python (caminhos no quadrado [-1, 1], y para baixo).

ell (elipse), stroke (traço com espessura que vira polígono), smooth (contorno fechado suave),
jag (estrela/serrilhado), mirror (espelha no eixo vertical), J (junta polígonos num caminho),
emit (escreve/atualiza as entradas em scripts/ui/components/crest_art.gd).
Sufixos: "_d" detalhe na cor de sombra, "_h" reflexo claro, "_c" recorte na cor do fundo.
"""
import math, re, sys
def f(v): return ('%.3f'%v).rstrip('0').rstrip('.').replace('-0','-0') if abs(v)>1e-9 else '0'
def P(pts): return 'M '+' L '.join(f'{f(x)} {f(y)}' for x,y in pts)+' Z'
def ell(cx,cy,rx,ry,rot=0.0,n=28,a0=0.0,a1=2*math.pi):
    out=[]
    for i in range(n):
        a=a0+(a1-a0)*i/n
        x=rx*math.cos(a); y=ry*math.sin(a)
        out.append((cx+x*math.cos(rot)-y*math.sin(rot), cy+x*math.sin(rot)+y*math.cos(rot)))
    return out
def catmull(pts,seg=6):
    if len(pts)<3: return pts
    p=[pts[0]]+pts+[pts[-1]]; out=[]
    for i in range(1,len(p)-2):
        p0,p1,p2,p3=p[i-1],p[i],p[i+1],p[i+2]
        for k in range(seg):
            t=k/seg; t2=t*t; t3=t2*t
            out.append(tuple(0.5*((2*p1[j])+(-p0[j]+p2[j])*t+(2*p0[j]-5*p1[j]+4*p2[j]-p3[j])*t2+(-p0[j]+3*p1[j]-3*p2[j]+p3[j])*t3) for j in range(2)))
    out.append(pts[-1]); return out
def stroke(pts,w0,w1=None,cap=True):
    if w1 is None: w1=w0
    c=catmull(pts); n=len(c); L=[];R=[]
    for i in range(n):
        a=c[max(i-1,0)]; b=c[min(i+1,n-1)]
        dx,dy=b[0]-a[0],b[1]-a[1]; d=math.hypot(dx,dy) or 1
        nx,ny=-dy/d,dx/d; w=(w0+(w1-w0)*i/(n-1))/2
        L.append((c[i][0]+nx*w,c[i][1]+ny*w)); R.append((c[i][0]-nx*w,c[i][1]-ny*w))
    out=L[:]
    if cap:
        e=c[-1]; b=c[-2]; ang=math.atan2(e[1]-b[1],e[0]-b[0]); w=w1/2
        for k in range(1,6):
            a=ang+math.pi/2-math.pi*k/6; out.append((e[0]+w*math.cos(a),e[1]+w*math.sin(a)))
    out+=R[::-1]
    if cap:
        s=c[0]; b=c[1]; ang=math.atan2(s[1]-b[1],s[0]-b[0]); w=w0/2
        for k in range(1,6):
            a=ang+math.pi/2-math.pi*k/6; out.append((s[0]+w*math.cos(a),s[1]+w*math.sin(a)))
    return out
def smooth(pts,seg=5):
    # contorno fechado suave
    p=pts+pts[:3]; out=[]
    n=len(pts)
    for i in range(n):
        p0,p1,p2,p3=pts[i-1],pts[i],pts[(i+1)%n],pts[(i+2)%n]
        for k in range(seg):
            t=k/seg; t2=t*t; t3=t2*t
            out.append(tuple(0.5*((2*p1[j])+(-p0[j]+p2[j])*t+(2*p0[j]-5*p1[j]+4*p2[j]-p3[j])*t2+(-p0[j]+3*p1[j]-3*p2[j]+p3[j])*t3) for j in range(2)))
    return out
def jag(cx,cy,ri,ro,n,a0=0,a1=2*math.pi,rot=0.0):
    out=[]
    full = abs(a1-a0-2*math.pi)<1e-6
    m = n*2 if full else n*2+1
    for i in range(m):
        a=a0+(a1-a0)*i/(n*2)
        r=ro if i%2 else ri
        out.append((cx+r*math.cos(a+rot),cy+r*math.sin(a+rot)))
    if not full: out.append((cx,cy))
    return out
def mirror(pts): return [(-x,y) for x,y in pts][::-1]
def J(*ps): return ' '.join(P(p) for p in ps)

def rect(x0,y0,x1,y1): return [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]
def emit(path,S):
    s=open(path).read()
    for k,v in S.items():
        pat=r'(\t"%s": ")[^"]*(")'%re.escape(k)
        if re.search(pat,s): s=re.sub(pat, lambda m: m.group(1)+v+m.group(2), s)
        else:
            s=s.replace('\t"laurel": ', '\t"%s": "%s",\n\t"laurel": '%(k,v),1)
    open(path,'w').write(s)
