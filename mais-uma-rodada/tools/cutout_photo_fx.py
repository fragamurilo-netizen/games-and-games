# Protótipo (rodada 2): luz de foto aplicada sobre o recorte (cut_000000.png + cut_ffffff.png de
# tools/cutout_closeup.gd --cutout --bg=#000000 / #ffffff, --size=400 --only=0,2,4,7). Gera r1..r5.png.
import numpy as np, sys
from PIL import Image
from scipy import ndimage as nd
B=np.asarray(Image.open('cut_000000.png').convert('RGB')).astype(float)/255
W=np.asarray(Image.open('cut_ffffff.png').convert('RGB')).astype(float)/255
A=np.clip(1-(W-B).mean(2),0,1)
RGB=np.where(A[...,None]>1e-3, B/np.maximum(A[...,None],1e-3),0).clip(0,1)
A=np.clip((A-0.2)/0.8,0,1)
A=nd.gaussian_filter(nd.grey_erosion(A,size=(2,2)),0.6)
S=400
def crop(i): x=10+i*410; return RGB[10:10+S,x:x+S].copy(), A[10:10+S,x:x+S].copy()
yy,xx=np.mgrid[0:S,0:S]/S
rng=np.random.default_rng(3)
def blur(a,s): return nd.gaussian_filter(a,s)
def blur3(c,s): return np.dstack([blur(c[...,k],s) for k in range(3)])
def lum(c): return c@np.array([0.299,0.587,0.114])
def unsharp(c,s=1.2,amt=0.5): return np.clip(c+amt*(c-blur3(c,s)),0,1)
def grain(c,amt):
    n=blur(rng.standard_normal((S,S)),0.6)*amt
    return np.clip(c+n[...,None],0,1)
def shift(a,dx,dy): return nd.shift(a,(dy,dx),order=1,mode='nearest')
def rim(a,dx,dy,soft=1.5):
    r=a*(1-shift(a,dx,dy)); return blur(r,soft)
def bokeh(bg,n,cols,rmin,rmax,ymax,alpha,seed):
    r=np.random.default_rng(seed)
    out=bg.copy()
    for i in range(n):
        cx,cy=r.uniform(0,1),r.uniform(0,ymax); rr=r.uniform(rmin,rmax)
        d=np.sqrt((xx-cx)**2+(yy-cy)**2)/rr
        m=np.clip(1.2-d,0,1)**0.6*alpha*r.uniform(0.4,1)
        col=np.array(cols[r.integers(len(cols))])
        out=out+(m[...,None]*col)
    return out
def comp(fg,a,bg):
    return fg*a[...,None]+bg*(1-a[...,None])
def circle_mask():
    d=np.sqrt((xx-0.5)**2+(yy-0.5)**2); return np.clip((0.5-d)*S/1.5,0,1)
def tone(c,mul): return np.clip(c*np.array(mul),0,1)

def opt1(c,a):  # contraluz de estadio a noite
    L=lum(c)
    fg=c*0.62*np.array([0.92,0.97,1.08])          # sujeito na penumbra, frio
    fg=fg*(0.85+0.3*(1-yy))[...,None]               # luz de cima
    r=np.clip(rim(a,12,2,3.0)+rim(a,-12,2,3.0),0,1)*np.clip(0.3+yy*1.4,0,1)*(1-np.clip(yy-0.75,0,1)*3)
    fg=fg*(1-0.5*r[...,None])+r[...,None]*np.array([0.8,0.9,1.0])*0.75
    bg=np.zeros((S,S,3))+np.array([0.03,0.05,0.09])
    bg+=(np.clip(0.6-yy,0,1)**2*0.35)[...,None]*np.array([0.5,0.65,0.9])   # névoa iluminada
    bg=bokeh(bg,14,[(1,0.97,0.9),(0.85,0.92,1)],0.02,0.06,0.45,0.55,5)
    bg=blur3(bg,2)
    out=comp(np.clip(fg,0,1),a,bg)
    glow=blur3(np.clip(out-0.75,0,1),8)*0.9; out=out+glow
    return grain(unsharp(np.clip(out,0,1)),0.03)

def opt2(c,a):  # rembrandt / claro-escuro
    side=np.clip(1.3-1.2*xx,0.38,1.25)            # luz forte da esquerda
    side=blur(side,6)
    fg=c*side[...,None]
    warm=np.clip(1-xx*1.6,0,1)[...,None]*np.array([0.08,0.04,-0.02])
    fg=fg+warm*a[...,None]
    fg=np.clip(fg,0,1)
    fg=fg**np.array([0.95,1.0,1.08])
    bg=np.zeros((S,S,3))+np.array([0.09,0.08,0.075])
    d=np.sqrt((xx-0.25)**2+(yy-0.3)**2)
    bg+=(np.clip(0.55-d,0,1)*0.55)[...,None]*np.array([0.62,0.55,0.48])
    sh=blur(shift(a,22,8),14)*0.55
    bg=bg*(1-sh[...,None])
    out=comp(fg,a,bg)
    v=np.clip(1.05-((xx-0.45)**2+(yy-0.45)**2)*1.4,0.45,1)
    out=out*v[...,None]
    return grain(unsharp(out,1.3,0.6),0.035)

def opt3(c,a):  # foto oficial de clube
    fg=c.copy()
    L=lum(fg)[...,None]; fg=fg*0.9+L*0.1                # menos saturado
    fg=np.clip((fg-0.5)*1.08+0.52,0,1)
    fg=fg*(1.06-0.18*xx)[...,None]                      # caída suave para a direita
    bg=np.zeros((S,S,3))+np.array([0.80,0.81,0.83])
    bg*= (1.05-0.25*np.sqrt((xx-0.4)**2+(yy-0.35)**2))[...,None]
    sh=blur(shift(a,10,6),10)*0.32
    bg=bg*(1-sh[...,None])
    out=comp(fg,a,bg)
    return grain(unsharp(out,1.0,0.7),0.02)

def opt4(c,a):  # fim de tarde ao ar livre, sol atrás
    fg=c*np.array([1.0,0.93,0.82])*0.88
    fg=fg*(0.8+0.25*xx)[...,None]                       # rosto um pouco sombreado (sol atrás à direita)
    r=np.clip(rim(a,-9,4,2.0),0,1)*np.clip(1.2-yy,0,1)
    fg=fg+r[...,None]*np.array([1.0,0.78,0.45])*1.2
    bg=np.zeros((S,S,3))
    sky=np.array([0.95,0.72,0.45]); stands=np.array([0.32,0.27,0.24]); grass=np.array([0.22,0.42,0.2])
    bg=np.where((yy<0.35)[...,None],sky*(1-yy[...,None]*0.6),np.where((yy<0.72)[...,None],stands,grass))
    bg=bokeh(bg,25,[(1,0.85,0.6),(0.9,0.6,0.5),(0.95,0.95,0.9)],0.01,0.035,0.7,0.35,9)
    bg=blur3(bg,9)
    d=np.sqrt((xx-0.85)**2+(yy-0.15)**2); bg+=np.clip(0.5-d,0,1)[...,None]*np.array([0.6,0.45,0.25])
    out=comp(np.clip(fg,0,1),a,np.clip(bg,0,1))
    out=out*0.92+0.06*np.array([1,0.85,0.7])            # névoa / pretos levantados
    glow=blur3(np.clip(out-0.7,0,1),10)*0.8; out=out+glow
    return grain(np.clip(unsharp(out),0,1),0.03)

def opt5(c,a):  # preto e branco de revista
    L=lum(c)
    L=L*(1.1-0.45*xx)
    L=np.clip((L-0.45)*1.45+0.48,0,1)
    bg=np.zeros((S,S))+0.16
    d=np.sqrt((xx-0.35)**2+(yy-0.35)**2); bg+=np.clip(0.6-d,0,1)*0.45
    r=rim(a,8,2)*0.7
    L=L+r
    out=L*a+bg*(1-a)
    out=np.dstack([out,out*0.985,out*0.96])
    return grain(unsharp(np.clip(out,0,1),1.2,0.8),0.055)

opts={1:opt1,2:opt2,3:opt3,4:opt4,5:opt5}
which=[int(x) for x in sys.argv[1:]] or list(opts)
cm=circle_mask()
for k in which:
    row=np.zeros((S,S*4+30,3))+0.08
    for i in range(4):
        c,a=crop(i)
        o=opts[k](c,a)
        o=o*cm[...,None]+0.08*(1-cm[...,None])
        row[:,i*(S+10):i*(S+10)+S]=o
    Image.fromarray((np.clip(row,0,1)*255).astype('uint8')).save(f'r{k}.png')
print('ok')
