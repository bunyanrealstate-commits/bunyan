# بيلف النصوص العربي الثابتة في lib/ui بـ L.t('...') علشان الترجمة، ويشيل const من اللي بقى فيه L.
import re,glob,json,sys
AR=re.compile('[؀-ۿ]')
def scan_str(s,i):
    """s[i] is a quote; return end index (exclusive) of the string literal"""
    q=s[i]
    if s[i:i+3]==q*3:
        j=s.index(q*3,i+3); return j+3
    j=i+1
    while True:
        c=s[j]
        if c=='\\': j+=2; continue
        if c=='$' and s[j+1]=='{':
            d=1; j+=2
            while d:
                if s[j] in '\'"': j=scan_str(s,j); continue
                if s[j]=='{': d+=1
                elif s[j]=='}': d-=1
                j+=1
            continue
        if c==q: return j+1
        j+=1
def process(src):
    out=[];i=0;n=len(src);wrapped=0
    while i<n:
        c=src[i]
        if src.startswith('//',i):
            j=src.find('\n',i); j=n if j<0 else j; out.append(src[i:j]); i=j; continue
        if src.startswith('/*',i):
            j=src.index('*/',i)+2; out.append(src[i:j]); i=j; continue
        if c in '\'"':
            raw = i>0 and src[i-1]=='r'
            j=scan_str(src,i); lit=src[i:j]
            body=lit[1:-1]
            line_start=src.rfind('\n',0,i)+1; line=src[line_start:i]
            ok = (not raw and c=="'" and not lit.startswith("'''") and AR.search(body) and '$' not in body
                  and not re.search(r'\bcase\s*$',line) and not re.match(r'\s*(static\s+)?const\s+[\w<>, ]*\s*\w+\s*=',line) and not src[:i].endswith('L.t(')
                  and not re.search(r'\b(String|bool|int|double)\??\s+\w+\s*=\s*$',line) and not re.search(r'RegExp\(\s*$',line))
            if ok: out.append('L.t('+lit+')'); wrapped+=1
            else: out.append(lit)
            i=j; continue
        out.append(c); i+=1
    return ''.join(out),wrapped
def match_end(s,i):
    o=s[i]; cl={'(':')','[':']','{':'}'}[o]; d=0; j=i
    while j<len(s):
        c=s[j]
        if c in '\'"': j=scan_str(s,j); continue
        if c==o: d+=1
        elif c==cl:
            d-=1
            if d==0: return j+1
        j+=1
    return len(s)
def deconst(s):
    changed=True
    while changed:
        changed=False
        for m in re.finditer(r'\bconst\s+(?=[A-Za-z_<\[{(])',s):
            k=m.end()
            # skip `const Foo({super.key})` constructor declarations and top-level const decls
            pre=s[max(0,m.start()-40):m.start()]
            mm=re.match(r'[A-Za-z_][\w.<>, ]*?([(\[{])',s[k:k+200])
            if s[k] in '[{(' : b=k
            elif mm: b=k+mm.start(1)
            else: continue
            e=match_end(s,b); seg=s[b:e]
            if 'L.t(' in seg or 'L.dir' in seg:
                s=s[:m.start()]+s[k:]; changed=True; break
    return s
tot=0
for f in sorted(glob.glob('lib/ui/*.dart')):
    if f.endswith(('ct_css.dart','i18n.dart')): continue
    s=open(f,encoding='utf-8').read()
    s2,w=process(s)
    s2=s2.replace('TextDirection.rtl','L.dir')
    if s2!=s:
        s2=deconst(s2)
        if "import 'i18n.dart';" not in s2: s2=s2.replace("import 'package:flutter/material.dart';","import 'package:flutter/material.dart';\nimport 'i18n.dart';",1)
        open(f,'w',encoding='utf-8').write(s2)
    tot+=w; print(f,w)
print('total',tot)
