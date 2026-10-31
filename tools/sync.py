#!/usr/bin/env python3
"""Usage: python3 tools/sync.py path/to/rental-tracker.html
Writes docs/index.html (PWA-ready) from the main app file. Push to main => GitHub Pages => phone app updates itself."""
import sys,re,os
src=open(sys.argv[1],encoding='utf-8').read()
head='<meta name="theme-color" content="#1473e6"><meta name="mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-capable" content="yes"><link rel="manifest" href="manifest.webmanifest"><link rel="apple-touch-icon" href="icon-192.png"><link rel="icon" href="icon-192.png">'
sw='<script>if("serviceWorker" in navigator&&location.protocol.indexOf("http")===0){addEventListener("load",function(){navigator.serviceWorker.register("sw.js").catch(function(){})})}</script>'
assert '<title>Bunyan Furnished</title>' in src
out=src.replace('<title>Bunyan Furnished</title>',head+'<title>Bunyan Furnished</title>',1)
k=out.rindex('</body>');out=out[:k]+sw+out[k:]
d=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','docs','index.html')
open(d,'w',encoding='utf-8').write(out);print('ok',len(out))
# customer build: same app without the owner module (license issuing)
a=out.find('<script>\n(function(){\nvar OW={')
assert a>0,'owner block not found'
b=out.index('</script>',a)+len('</script>')
cust=out[:a]+out[b:]
# the personal 'كاشير QR' tab stays out of the customer build
q=cust.find('<script id="qrc-tab">')
if q>0:
    e=cust.index('</script>',q)+len('</script>');cust=cust[:q]+cust[e:]
assert 'id="qrc-tab"' not in cust
assert 'var OW=' not in cust and 'ownbtn' not in cust
import shutil
cd=os.path.join(os.path.dirname(d),'c');os.makedirs(cd,exist_ok=True)
open(os.path.join(cd,'index.html'),'w',encoding='utf-8').write(cust)
for f in ('manifest.webmanifest','sw.js','icon-192.png','icon-512.png','icon-maskable-512.png'):
    shutil.copy(os.path.join(os.path.dirname(d),f),os.path.join(cd,f))
pass
print('customer',len(cust))

# Abdelhakim build: customer build preset to the group "مع عبد الحكيم" (2 partners, 50/50)
seed='<script id="seed-hakim">(function(){function go(){try{if(!AUTH||!S)return;if(S._seedH)return;if((S.groups||[]).length||(S.units||[]).length){S._seedH=1;return}S.groups=[{id:"ghakim",name:"مع عبد الحكيم",n:2,share:50,custom:true,pn:"أسامة، عبد الحكيم"}];S._seedH=1;try{localStorage.setItem("bny_ws","ghakim")}catch(e){}WS="ghakim";save();render()}catch(e){}}var r0=render;render=function(){var o=r0.apply(this,arguments);setTimeout(go,0);return o};setTimeout(go,500)})();</script>'
pre=r'<script>/* نسخة عبد الحكيم: تخزين منفصل + مزامنة للاستقبال فقط من hakim.json */window.HBUILD=1;(function(){try{var P=Storage.prototype,g=P.getItem,s=P.setItem,r=P.removeItem,L=function(t){try{return t===window.localStorage}catch(e){return false}};P.getItem=function(k){if(!L(this))return g.call(this,k);var v=g.call(this,"h:"+k);if(k==="bny_sync"&&v){try{var c=JSON.parse(v);c.path="hakim.json";v=JSON.stringify(c)}catch(e){}}return v};P.setItem=function(k,v){if(!L(this))return s.call(this,k,v);if(k==="bny_sync"){try{var c=JSON.parse(v);c.path="hakim.json";v=JSON.stringify(c)}catch(e){}}return s.call(this,"h:"+k,v)};P.removeItem=function(k){return L(this)?r.call(this,"h:"+k):r.call(this,k)}}catch(e){}var f0=window.fetch;window.fetch=function(u,o){try{var m=o&&o.method;if((m==="PUT"||m==="DELETE")&&/api\.github\.com\/repos\//.test(String(u))){return Promise.resolve(new Response(JSON.stringify({content:{sha:"local-"+Date.now()}}),{status:200,headers:{"Content-Type":"application/json"}}))}}catch(e){}return f0.apply(this,arguments)}})();</script>'
hb=cust.index('<script>')
cust_h=cust[:hb]+pre+cust[hb:]
k=cust_h.rindex('</body>');hk=cust_h[:k]+seed+cust_h[k:]
hk=hk.replace('<title>Bunyan Furnished</title>','<title>Bunyan Furnished — عبد الحكيم</title>',1)
hd=os.path.join(os.path.dirname(d),'h');os.makedirs(hd,exist_ok=True)
open(os.path.join(hd,'index.html'),'w',encoding='utf-8').write(hk)
for f in ('sw.js','icon-192.png','icon-512.png','icon-maskable-512.png'):
    shutil.copy(os.path.join(os.path.dirname(d),f),os.path.join(hd,f))
import json
mf=json.load(open(os.path.join(os.path.dirname(d),'manifest.webmanifest'),encoding='utf-8'))
mf.update({'name':'Bunyan — عبد الحكيم','short_name':'بنيان حكيم','id':'./?app=hakim','start_url':'./index.html','scope':'./','theme_color':'#2a9d5c'})
json.dump(mf,open(os.path.join(hd,'manifest.webmanifest'),'w',encoding='utf-8'),ensure_ascii=False,indent=1)
hk=hk.replace('content="#1473e6"','content="#2a9d5c"',1).replace('<link rel="apple-touch-icon" href="icon-192.png">','<link rel="apple-touch-icon" href="icon-192.png"><meta name="apple-mobile-web-app-title" content="بنيان حكيم">',1)
open(os.path.join(hd,'index.html'),'w',encoding='utf-8').write(hk)
print('hakim',len(hk))
