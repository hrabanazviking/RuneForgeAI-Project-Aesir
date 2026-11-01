import math
M64=(1<<64)-1
class RuneRNG:
    def __init__(self, seed):
        self.state = 0x9E3779B97F4A7C15 if seed==0 else seed & M64
    def next_f(self):
        s=self.state
        s=((s ^ (s>>30))*0xBF58476D1CE4E5B9)&M64
        s=((s ^ (s>>27))*0x94D049BB133111EB)&M64
        self.state=s
        return (((s ^ (s>>31)) & M64) & 0xFFFFFF)/16777216.0
def shape(logits,T,topk,topp):
    if T==0:
        m=max(logits); i=logits.index(m); return [1.0 if j==i else 0.0 for j in range(len(logits))]
    z=[x/T for x in logits]; mx=max(z); e=[math.exp(v-mx) for v in z]; s=sum(e); p=[v/s for v in e]
    order=sorted(range(len(p)), key=lambda i:(-p[i], i))
    if 0<topk<len(p):
        keep=set(order[:topk]); p=[p[i] if i in keep else 0.0 for i in range(len(p))]; s=sum(p); p=[v/s for v in p]
    if topp<1.0:
        cum=0.0; keep=set()
        for i in order:
            if p[i]<=0: continue
            keep.add(i); cum+=p[i]
            if cum>=topp: break
        p=[p[i] if i in keep else 0.0 for i in range(len(p))]; s=sum(p); p=[v/s for v in p]
    return p
def draw(p,u):
    acc=0.0; last=-1
    for i,v in enumerate(p):
        if v>0: last=i
        acc+=v
        if u<acc: return i
    return last
def residual(p,q):
    r=[max(0.0,a-b) for a,b in zip(p,q)]; s=sum(r); return [v/s for v in r]
def chisq(obs,p):
    n=sum(obs); st=0.0
    for o,pr in zip(obs,p):
        if pr>0:
            e=n*pr; st+=(o-e)**2/e
        elif o>0: return -1.0
    return st
t=[2.0,1.0,0.5,0.0,-0.5,-1.0,-1.5,-2.0]; d=[1.2,0.2,1.6,-0.8,0.6,-1.4,-0.2,-2.2]
for name,(T,k,pp) in {"A":(1.0,0,1.0),"B":(0.7,0,1.0),"C":(1.0,3,1.0),"D":(1.0,0,0.8),"E":(1.4,4,0.9)}.items():
    p=shape(t,T,k,pp); q=shape(d,T,k,pp)
    rng=RuneRNG(20261101); obs=[0]*8
    for _ in range(60000):
        ud,ua,ur=rng.next_f(),rng.next_f(),rng.next_f()
        x=draw(q,ud); a=min(1.0,p[x]/q[x])
        obs[x if ua<a else draw(residual(p,q),ur)]+=1
    rng=RuneRNG(20261101); obsn=[0]*8
    for _ in range(60000): obsn[draw(q,rng.next_f())]+=1
    print(name, "corr=%.6f naive=%s"%(chisq(obs,p), chisq(obsn,p)))
# bonus mirror
p=shape(t,1.0,0,1.0); q=shape(d,1.0,0,1.0)
rng=RuneRNG(424242); obs=[0]*8; coll=0; rounds=0
while coll<12000 and rounds<200000:
    dd=[rng.next_f() for _ in range(2)]; ad=[rng.next_f() for _ in range(2)]; fin=rng.next_f()
    rounds+=1; emitted=[]
    for i in range(2):
        x=draw(q,dd[i]); a=min(1.0,p[x]/q[x])
        if ad[i]<a: emitted.append(x)
        else: emitted.append(draw(residual(p,q),fin)); break
    else:
        obs[draw(p,fin)]+=1; coll+=1
print("bonus chi2=%.6f rounds=%d"%(chisq(obs,p),rounds))
