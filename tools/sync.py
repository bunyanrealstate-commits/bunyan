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
seed=r"""<script id="hguard">(function(){
var D=["units","exp","dep","gp","gc","adj"];window._ug=0;["pointerdown","keydown","touchstart"].forEach(function(e){addEventListener(e,function(){window._ug=Date.now()},{capture:true,passive:true})});
function pk(o){var r={};D.forEach(function(k){if(o&&o[k]!=null)r[k]=o[k]});return JSON.stringify(r)}
function dec(b){return JSON.parse(decodeURIComponent(escape(atob(String(b).replace(/\s/g,"")))))}
function enc(o){return btoa(unescape(encodeURIComponent(JSON.stringify(o))))}
window._cloudD=null;window._hst={};var f1=window.fetch;window.fetch=function(u,o){var p=f1.apply(this,arguments);try{if((!o||!o.method||o.method==="GET")&&/\/contents\/hakim\.json/.test(String(u))){return p.then(function(r){if(!r.ok){window._hst.err=r.status;hs()}return r.clone().text().then(function(x){try{var j=JSON.parse(x);var d=j&&j.content?dec(j.content):(j&&j.units?j:null);if(d){window._cloudD=pk(d);window._hst.err=0;window._hst.at=d.at||0;window._hst.sig=sg(d);setTimeout(vf,4000)}}catch(e){}return r},function(){return r})},function(e){window._hst.err="net";throw e})}}catch(e){}return p};
function sg(d){var U=d.units||[],L=0,R=0;U.forEach(function(x){(x.leases||[]).forEach(function(l){L++;R+=(l.rcv||[]).length})});return U.map(function(x){return x.id}).sort().join(",")+"|"+L+"|"+R}
function vf(){try{var h=window._hst;h.mm=(typeof S!=="undefined"&&S&&sg(S)!==h.sig)?1:0;if(!h.mm)h.got=h.at;hs()}catch(e){}}
var hsl="",hsT=0,hsB=false;async function hs(){var c=cfg();if(!c||!c.token||hsB||navigator.onLine===false)return;var h=window._hst,o={seen:Date.now(),got:h.got||0,err:h.err||0,mm:h.mm||0,u:(typeof A!=="undefined"&&A&&A.u)||"",mon:h.mon||[],errs:h.errs||0,lastErr:h.lastErr||""},k=JSON.stringify([o.got,o.err,o.mm,o.mon,o.errs]);if(k===hsl)return;hsB=true;
 try{var RF=window._rf||f1,u="https://api.github.com/repos/"+c.repo+"/contents/hakim-status.json",H={"Authorization":"Bearer "+c.token,"Accept":"application/vnd.github+json","X-GitHub-Api-Version":"2022-11-28"};var r=await RF(u+"?t="+Date.now(),{headers:H,cache:"no-store"}),sha="";if(r.ok)sha=(await r.json()).sha;var b={message:"hakim status",content:enc(o)};if(sha)b.sha=sha;var w=await RF(u,{method:"PUT",headers:H,body:JSON.stringify(b)});if(w.ok){hsl=k;hsT=Date.now()}}catch(e){}finally{hsB=false}}
function cfg(){try{return JSON.parse(localStorage.getItem("bny_sync"))||null}catch(e){return null}}
function q(){try{return JSON.parse(localStorage.getItem("hreq_q"))||[]}catch(e){return []}}
function sq(a){try{localStorage.setItem("hreq_q",JSON.stringify(a))}catch(e){}}
var up=false;async function flush(){var a=q(),c=cfg();if(!a.length||!c||!c.token||up||navigator.onLine===false)return;up=true;
 try{var u="https://api.github.com/repos/"+c.repo+"/contents/hakim-req.json",H={"Authorization":"Bearer "+c.token,"Accept":"application/vnd.github+json","X-GitHub-Api-Version":"2022-11-28"};
  var RF=window._rf||f1;var r=await RF(u+"?t="+Date.now(),{headers:H,cache:"no-store"}),sha="",L=[];if(r.ok){var j=await r.json();sha=j.sha;try{L=dec(j.content)||[]}catch(e){L=[]}}
  L=L.concat(a);var b={message:"req "+new Date().toISOString(),content:enc(L)};if(sha)b.sha=sha;
  var w=await RF(u,{method:"PUT",headers:H,body:JSON.stringify(b)});if(w.ok){sq([]);try{toast("📨 طلب التعديل وصل للبرنامج الأساسي")}catch(e){}bar()}}catch(e){}finally{up=false}}
window.hreqFlush=flush;var mq=0;function mon(){clearTimeout(mq);mq=setTimeout(function(){try{if(typeof AUTH==="undefined"||!AUTH||document.hidden||!window.bnyUiCheck)return;var m=bnyUiCheck(),h=window._hst;if(JSON.stringify(m)!==JSON.stringify(h.mon||[])){h.mon=m;hs()}}catch(e){}},2500)}addEventListener("error",function(e){try{var h=window._hst;h.errs=(h.errs||0)+1;h.lastErr=String(e.message||e.error||"").slice(0,120);if(!h.ew||Date.now()-h.ew>300000){h.ew=Date.now();setTimeout(hs,3000)}}catch(x){}});setTimeout(function(){try{var r0=render;render=function(){var o=r0.apply(this,arguments);mon();return o};mon()}catch(e){}},1500);addEventListener("resize",mon);setInterval(flush,30000);addEventListener("online",flush);
var P=Storage.prototype,s0=P.setItem;
P.setItem=function(k,v){try{if(this===window.localStorage&&typeof A!=="undefined"&&A&&k===A.k){var old=localStorage.getItem(k);if(old){var nv=JSON.parse(v),pn=pk(nv);if(pn!==pk(JSON.parse(old))&&pn!==window._cloudD&&Date.now()-window._ug<2500&&!(nv.hist&&nv.hist[0]&&/إنشاء حساب|تسجيل (دخول|خروج)/.test(nv.hist[0].d||""))){var lq=q();if(lq.length&&JSON.stringify(lq[lq.length-1].data)===pn){try{S=JSON.parse(old)}catch(e){}return}var ds=(nv.hist&&nv.hist[0]&&Date.now()-nv.hist[0].t<8000)?String(nv.hist[0].d||""):"تعديل";try{var ov=JSON.parse(old),gn=[];(nv.groups||[]).forEach(function(g){var f=function(o){return JSON.stringify([(o.units||[]).filter(function(u){return u.g===g.id}),(o.gp||{})[g.id]||[],(o.exp||[]).filter(function(e){return e.g===g.id})])};if(f(nv)!==f(ov))gn.push(g.name)});if(gn.length&&(nv.groups||[]).length>1)ds="【"+gn.join(" + ")+"】 "+ds}catch(e){}var a=q();a.push({id:"r"+Date.now(),at:Date.now(),by:A.u,desc:ds,data:JSON.parse(pn)});sq(a);try{S=JSON.parse(old)}catch(e){}setTimeout(function(){try{render();toast("🔒 التعديل محتاج موافقة البرنامج الأساسي — اتبعت طلب");bar(1)}catch(e){}},30);setTimeout(flush,300);return}}}}catch(e){}return s0.apply(this,arguments)};
var bt=0;function bar(f){try{if(f)bt=Date.now();var n=q().length,b=document.getElementById("hbar");if(!n&&Date.now()-bt>5000){if(b)b.style.display="none";return}if(!b){b=document.createElement("div");b.id="hbar";b.style.cssText="position:fixed;bottom:calc(10px + env(safe-area-inset-bottom,0px));left:50%;transform:translateX(-50%);z-index:40;background:#2a9d5c;color:#fff;border-radius:999px;padding:6px 14px;font-size:12.5px;font-weight:700;box-shadow:0 4px 14px rgba(0,0,0,.2);white-space:nowrap";document.body.appendChild(b)}var cc=cfg();b.style.background=(cc&&cc.token)?"#2a9d5c":"#d97706";b.style.display="";b.textContent=!(cc&&cc.token)?("⚠️ المزامنة مش متفعلة — الطلبات مش هتوصل"+(n?" ("+n+" مستني)":"")):(n?("⏳ "+n+" طلب بيتبعت للبرنامج الأساسي…"):"🔒 أي تعديل بيحتاج موافقة البرنامج الأساسي");b.onclick=function(){try{flush();if(window.syOpen&&!(cc&&cc.token))syOpen()}catch(e){}}}catch(e){}}
setTimeout(bar,800);setInterval(bar,5000);
var hET="",apB=false;async function ap(){try{if(typeof AUTH==="undefined"||!AUTH||document.hidden||navigator.onLine===false||!window.syNow||apB)return;var c=cfg();if(!c||!c.token)return;apB=true;var RF=window._rf||f1,H={"Authorization":"Bearer "+c.token,"Accept":"application/vnd.github+json","X-GitHub-Api-Version":"2022-11-28"};if(hET)H["If-None-Match"]=hET;var r=await RF("https://api.github.com/repos/"+c.repo+"/contents/hakim.json",{headers:H,cache:"no-store"});if(r.status===304)return;if(r.ok){hET=r.headers.get("ETag")||"";var j=await r.json();if(j.sha&&j.sha===c.sha)return;syNow()}}catch(e){}finally{apB=false}}
setTimeout(ap,2500);setInterval(ap,60000);document.addEventListener("visibilitychange",function(){if(!document.hidden)setTimeout(ap,800)});addEventListener("online",ap);
})();</script>"""
pre=r'<script>/* نسخة عبد الحكيم: تخزين منفصل + مزامنة للاستقبال فقط من hakim.json */window.HBUILD=1;(function(){try{var P=Storage.prototype,g=P.getItem,s=P.setItem,r=P.removeItem,L=function(t){try{return t===window.localStorage}catch(e){return false}};P.getItem=function(k){if(!L(this))return g.call(this,k);var v=g.call(this,"h:"+k);if(k==="bny_sync"&&v){try{var c=JSON.parse(v);c.path="hakim.json";c.dirty=false;if(!c.sha)c.sha="h0";v=JSON.stringify(c)}catch(e){}}return v};P.setItem=function(k,v){if(!L(this))return s.call(this,k,v);if(k==="bny_sync"){try{var c=JSON.parse(v);c.path="hakim.json";c.dirty=false;if(!c.sha||/^local-/.test(c.sha))c.sha="h0";v=JSON.stringify(c)}catch(e){}}return s.call(this,"h:"+k,v)};P.removeItem=function(k){return L(this)?r.call(this,"h:"+k):r.call(this,k)}}catch(e){}var f0=window.fetch;window._rf=f0;window.fetch=function(u,o){try{var m=o&&o.method;if((m==="PUT"||m==="DELETE")&&/api\.github\.com\/repos\//.test(String(u))){return Promise.resolve(new Response(JSON.stringify({content:{sha:"local-"+Date.now()}}),{status:200,headers:{"Content-Type":"application/json"}}))}}catch(e){}return f0.apply(this,arguments)}})();</script>'
hb=cust.index('<script>')
cust_h=cust[:hb]+pre+cust[hb:]
k=cust_h.rindex('</body>');hk=cust_h[:k]+seed+cust_h[k:]
hk=hk.replace('<title>Bunyan Furnished</title>','<title>Bunyan Furnished — حكيم</title>',1)
hd=os.path.join(os.path.dirname(d),'h');os.makedirs(hd,exist_ok=True)
open(os.path.join(hd,'index.html'),'w',encoding='utf-8').write(hk)
for f in ('sw.js','icon-192.png','icon-512.png','icon-maskable-512.png'):
    shutil.copy(os.path.join(os.path.dirname(d),f),os.path.join(hd,f))
ha=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','assets','hakim')
for f in ('icon-192.png','icon-512.png','icon-maskable-512.png'):
    if os.path.exists(os.path.join(ha,f)):shutil.copy(os.path.join(ha,f),os.path.join(hd,f))
import json
mf=json.load(open(os.path.join(os.path.dirname(d),'manifest.webmanifest'),encoding='utf-8'))
mf.update({'name':'Bunyan — حكيم','short_name':'بنيان حكيم','id':'./?app=hakim','start_url':'./index.html','scope':'./','theme_color':'#2a9d5c'})
json.dump(mf,open(os.path.join(hd,'manifest.webmanifest'),'w',encoding='utf-8'),ensure_ascii=False,indent=1)
hk=hk.replace('content="#1473e6"','content="#2a9d5c"',1).replace('<link rel="apple-touch-icon" href="icon-192.png">','<link rel="apple-touch-icon" href="icon-192.png"><meta name="apple-mobile-web-app-title" content="بنيان حكيم">',1)
open(os.path.join(hd,'index.html'),'w',encoding='utf-8').write(hk)
print('hakim',len(hk))
