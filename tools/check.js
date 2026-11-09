// Full-app regression check. Run before every release:
//   node tools/check.js [data.json]
// Fails (exit 1) on: script syntax errors, page errors in any build, a crashed tab,
// accounting self-test mismatch, changed key numbers vs the saved baseline (tools/baseline.json),
// slow/hung language switch, stray UI (visible empty toast, header overlaps).
const fs=require('fs'),path=require('path');function cp(a,b){fs.mkdirSync(b,{recursive:true});for(const n of fs.readdirSync(a)){const x=path.join(a,n),y=path.join(b,n);fs.statSync(x).isDirectory()?cp(x,y):fs.copyFileSync(x,y)}}const {chromium,devices}=require('playwright');
const ROOT=path.join(__dirname,'..'),DATA=process.argv[2]||'/home/claude/bunyan-data2/book.json',BASE=path.join(__dirname,'baseline.json');
const fails=[],notes=[];const F=m=>{fails.push(m);console.log('❌ '+m)},OK=m=>console.log('✅ '+m);
(async()=>{
 // 1) syntax of every inline script
 const src=fs.readFileSync(path.join(ROOT,'rental-tracker.html'),'utf8');let n=0,bad=0;const re=/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/g;let m;while(m=re.exec(src)){n++;try{new Function(m[1])}catch(e){bad++;F('syntax: '+e.message+' :: '+m[1].slice(0,60).replace(/\s+/g,' '))}}
 if(!bad)OK('syntax: '+n+' scripts');
 const b=await chromium.launch();
 async function page(file,tz){const ctx=await b.newContext({...devices['Pixel 7'],timezoneId:tz||'Asia/Dubai'});const H2C=path.join(__dirname,'vendor','html2canvas.min.js');if(fs.existsSync(H2C))await ctx.route(/html2canvas(\.min)?\.js/,r=>r.fulfill({status:200,contentType:'application/javascript',body:fs.readFileSync(H2C,'utf8')}));/* offline: CDN may be blocked where the check runs */
  const p=await ctx.newPage();const errs=[];p.on('pageerror',e=>errs.push(e.message));
  await p.addInitScript(()=>{try{localStorage.setItem('bny_hd_t',String(Date.now()));sessionStorage.setItem('bny_spl','1')}catch(e){}});await p.goto('file://'+file);await p.waitForTimeout(1800);return {p,errs,ctx}}
 // 2) every build boots clean
 for(const f of ['docs/index.html','docs/c/index.html','docs/h/index.html']){const fp=path.join(ROOT,f);if(!fs.existsSync(fp)){F('missing '+f);continue}const {p,errs,ctx}=await page(fp);const t=await p.evaluate(()=>document.body.innerText.length);if(errs.length)F(f+' boot errors: '+errs.slice(0,3).join(' | '));else if(t<50)F(f+' blank page');else OK(f+' boots');await ctx.close()}
 // 3) main app with real data: every tab in every group
 const {p,errs,ctx}=await page(path.join(ROOT,'rental-tracker.html'));
 await p.evaluate(()=>{const b=document.getElementById('bio');b&&b.classList.remove('on')});
 await p.fill('#lu','osama');await p.fill('#lp','1234');await p.fill('#lp2','1234');await p.tap('.dlg button.p');await p.waitForTimeout(1500);
 const data=fs.readFileSync(DATA,'utf8');await p.evaluate(d=>{Object.assign(S,JSON.parse(d));window.__noSave=1},data);
 const tabs=['home','units','grp','acc','n','ct','upd','log','bk','books','rem'];
 let base0=null;try{base0=JSON.parse(fs.readFileSync(BASE,'utf8'))}catch(e){}const DAY=(base0&&base0.day)||new Date().toISOString().slice(0,10);
 const res=await p.evaluate(([tabs,DAY])=>{const out={crash:[],nums:{}};const gs=(S.groups||[]).map(g=>g.id);gs.forEach(g=>{setW(g);tabs.forEach(t=>{try{S.tab=t;render();const a=document.getElementById('app');if(!a||a.innerText.trim().length<20)out.crash.push(g+'/'+t+': empty')}catch(e){out.crash.push(g+'/'+t+': '+e.message)}});
   const RD=Date,FIX=new RD(DAY+'T12:00:00').getTime();function FD(){var a=[].slice.call(arguments);return a.length?new (Function.prototype.bind.apply(RD,[null].concat(a)))():new RD(FIX)}FD.now=function(){return FIX};FD.UTC=RD.UTC;FD.parse=RD.parse;FD.prototype=RD.prototype;
   window.Date=FD;try{const r=rcvP(),f=fpos();out.nums[g]={cash:Math.round(cashNow()),profit:Math.round(r.profit),rev:Math.round(r.rev),eq:Math.round(f.eq)}}catch(e){out.crash.push(g+' numbers: '+e.message)}finally{window.Date=RD}});S.tab='home';render();return out},[tabs,DAY]);
 res.crash.forEach(c=>F('tab '+c));if(!res.crash.length)OK('all tabs render in '+Object.keys(res.nums).length+' groups');
 // 3b) every tab looks right: no cut-off text, nothing off-screen, no overlapping buttons, no NaN/undefined
 {let n=0;const gs=await p.evaluate(()=>(S.groups||[]).map(g=>g.id));for(const g of gs)for(const t of ['home','units','acc','grp','ct','upd','bk','n']){await p.evaluate(([g,t])=>{setW(g);S.tab=t;S.bksub='bk';render()},[g,t]);await p.waitForTimeout(450);const L=await p.evaluate(()=>{try{return bnyUiCheck().filter(x=>!/^الهيدر/.test(x))}catch(e){return ['ui check crashed: '+e.message]}});L.slice(0,3).forEach(x=>{F('look '+g+'/'+t+': '+x);n++})}if(!n)OK('every tab looks right (text fits, nothing off-screen or overlapping)');await p.evaluate(()=>{S.tab='home';render()})}
 // 4) accounting self-test (golden example)
 const st=await p.evaluate(()=>{try{window.monAudit(false);const r=window.monAudit(false);return (r.issues||[]).filter(x=>/محرك الحسابات/.test(x.area)).map(x=>x.msg)}catch(e){return ['monitor crashed: '+e.message]}});st.forEach(x=>F('self-test: '+x));if(!st.length)OK('accounting self-test');
 // 5) key numbers vs baseline (same data => same numbers)
 const key=require('crypto').createHash('md5').update(data).digest('hex');let base=null;try{base=JSON.parse(fs.readFileSync(BASE,'utf8'))}catch(e){}
 if(base&&base.key===key){let diff=0;Object.keys(res.nums).forEach(g=>{const a=res.nums[g],o=base.nums[g]||{};Object.keys(a).forEach(k=>{if(Math.abs(a[k]-(o[k]||0))>1){diff++;F('number changed '+g+'.'+k+': '+o[k]+' → '+a[k])}})});if(!diff)OK('numbers unchanged vs baseline')}
 else{notes.push('baseline saved for this data');fs.writeFileSync(BASE,JSON.stringify({key,day:DAY,at:new Date().toISOString(),nums:res.nums},null,1))}
 if(process.env.ACCEPT){fs.writeFileSync(BASE,JSON.stringify({key,day:DAY,at:new Date().toISOString(),nums:res.nums},null,1));notes.push('baseline accepted')}
 // 5b) finger scroll over the contract moves the page (regression: it used to be stuck)
 try{await p.evaluate(()=>{setW((S.groups[0]||{}).id);S.tab='ct';render()});await p.waitForTimeout(500);await p.evaluate(()=>{const v=document.getElementById('ctview');scrollTo(0,v.getBoundingClientRect().top+scrollY-250)});await p.waitForTimeout(200);
  const cd=await ctx.newCDPSession(p);const r=await p.evaluate(()=>{const v=document.getElementById('ctview').getBoundingClientRect();return {x:v.left+v.width/2,y:Math.min(innerHeight-100,v.top+200)}});const y0=await p.evaluate(()=>scrollY);
  await cd.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:r.x,y:r.y}]});for(let i=1;i<=12;i++){await cd.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:r.x,y:r.y-i*20}]});await p.waitForTimeout(16)}await cd.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(400);
  const y1=await p.evaluate(()=>scrollY);if(Math.abs(y1-y0)<40)F('contract: finger scroll over the contract does not move the page');else OK('contract: finger scroll works');await p.evaluate(()=>{S.tab='home';render()})}catch(e){F('contract scroll check crashed: '+e.message)}
 // 5d) contract tab: one clear layout, no duplicate buttons, both languages render right
 try{const r=await p.evaluate(async()=>{const o=[];setW((S.groups[0]||{}).id);for(const L of ['ar','en']){S.ct.lang=L;S.tab='ct';render();await new Promise(r=>setTimeout(r,1300));
   const vis=e=>{const r=e.getBoundingClientRect();return r.width>2&&r.height>2&&getComputedStyle(e).visibility!=='hidden'};
   const btns=[...document.querySelectorAll('#app button,#app label')].filter(vis).map(b=>b.textContent.trim());
   [/تنزيل PDF/,/ابعت العقد/,/طباعة/,/عقد جديد/,/النموذج الأصلي/,/^🪪 هوية المستأجر/,/^🪪 هوية المؤجر/].forEach(re=>{const n=btns.filter(t=>re.test(t)).length;if(n!==1)o.push(L+': button '+re+' x'+n)});
   const sigMove=btns.filter(t=>/حرّك/.test(t)).length;if(sigMove>1)o.push(L+': move-signature button x'+sigMove);
   const pt=(document.getElementById('ctpaper')||{}).innerText||'';['Landlord Name','Tenant Mobile No.','رقم موبايل المستأجر','Tenant Signature'].forEach(k=>{if(pt.indexOf(k)<0)o.push(L+': paper missing «'+k+'»')});
   if(/LandLord|Mobile No\.\s*\n|• تاريخ العقد/.test(pt))o.push(L+': old paper labels still there');
   const ui=bnyUiCheck();ui.forEach(x=>o.push(L+' ui: '+x));
   if(typeof ctUndo!=='function'||typeof ctWSign!=='function')o.push(L+': undo / witness signature missing');{const h=document.querySelector('#ctpaper h1 small'),d=document.querySelector('#ctpaper .ctdate');if((h&&vis(h))||(d&&vis(d)))o.push(L+': title subtitle / date line should be hidden')}
   ['ct_ll','ct_tn','ct_tid','ct_nat','ct_ph','ct_sub','ct_st','ct_mo','ct_en','ct_due','ct_rent','ct_chq','ct_lid'].forEach(id=>{if(!document.getElementById(id))o.push(L+': form field missing '+id)})}
   S.tab='home';render();return o});r.forEach(x=>F('contract: '+x));if(!r.length)OK('contract tab: layout, buttons, labels in AR and EN')}catch(e){F('contract layout check crashed: '+e.message)}
 // 5f) opening the contract tab must not make the form jump (regression: photo/language bar was moved in after the first paint, form jumped 135px)
 try{const r=await p.evaluate(async()=>{setW((S.groups[0]||{}).id);S.tab='home';render();await new Promise(r=>setTimeout(r,400));scrollTo(0,0);S.tab='ct';render();
   const pos=()=>{const o={};['#ctwrap .ctf','#ctwrap .card select','#ctview'].forEach(q=>{const e=document.querySelector(q);o[q]=e?Math.round(e.getBoundingClientRect().top+scrollY):null});return o};
   const a=await new Promise(r=>requestAnimationFrame(()=>r(pos())));await new Promise(r=>setTimeout(r,1500));const b=pos();const o=[];Object.keys(a).forEach(k=>{if(a[k]!=null&&b[k]!=null&&Math.abs(b[k]-a[k])>40)o.push(k+' moved '+(b[k]-a[k])+'px after first paint')});S.tab='home';render();return o});
  r.forEach(x=>F('contract jump: '+x));if(!r.length)OK('contract tab opens without jumping')}catch(e){F('contract jump check crashed: '+e.message)}
 // 5e) the monitor's rulebook: every known problem is caught AND fixed when broken on purpose; real data passes all rules
 try{const r=await p.evaluate(async()=>{const o=[];if(typeof bnyRulesSelfTest!=='function')return ['rulebook missing'];if(typeof bnyComplain!=='function'||!document.getElementById('cpmi'))o.push('«مش عاجبني» button missing');bnyRulesSelfTest().forEach(x=>o.push('self-test '+x));
   for(const t of ['home','units','acc','ct']){S.tab=t;render();await new Promise(r=>setTimeout(r,900));const fc0=(typeof BNYMEM!=='undefined'?BNYMEM.facts().length:0),ae0=document.activeElement;(bnyRulesRun()||[]).filter(x=>!x.fixed&&x.r.id!=='look').forEach(x=>o.push(t+': '+x.r.id+' '+x.f.join(' • ')));if(typeof BNYMEM!=='undefined'&&BNYMEM.facts().length!==fc0)o.push(t+': a rule check changed the assistant memory');if(document.activeElement!==ae0)o.push(t+': a rule check moved the focus (keyboard)')}S.tab='home';render();return o});
  r.forEach(x=>F('monitor rules: '+x));if(!r.length)OK('monitor rulebook: catches + fixes every known problem')}catch(e){F('monitor rules check crashed: '+e.message)}
 // 5f) zoomed contract: after reaching its end, the finger keeps scrolling the page itself
 try{await p.evaluate(()=>{setW((S.groups[0]||{}).id);S.tab='ct';render()});await p.waitForTimeout(900);await p.evaluate(()=>ctZoom(1));await p.waitForTimeout(400);
  await p.evaluate(()=>{const v=document.getElementById('ctview');scrollTo(0,v.getBoundingClientRect().top+scrollY-200)});await p.waitForTimeout(200);const cdz=await ctx.newCDPSession(p);
  const s0=await p.evaluate(()=>scrollY);for(let k=0;k<8;k++){await cdz.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:200,y:600}]});for(let i=1;i<=10;i++){await cdz.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:200,y:600-i*25}]});await p.waitForTimeout(12)}await cdz.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(150)}
  const r=await p.evaluate(()=>{const v=document.getElementById('ctview');return {end:v.scrollTop>=v.scrollHeight-v.clientHeight-2,y:scrollY}});await p.evaluate(()=>{ctZoom(0);S.tab='home';render()});
  if(!r.end||r.y-s0<60)F('zoomed contract: page does not move after reaching the end (contract end '+r.end+', page moved '+(r.y-s0)+'px)');else OK('zoomed contract: reaching its end scrolls the page')}catch(e){F('contract chain check crashed: '+e.message)}
 // 5g) contract PDF is exactly one page
 try{const n=await p.evaluate(()=>new Promise(res=>{setW((S.groups[0]||{}).id);S.tab='ct';render();setTimeout(()=>{window.__pdfCap=async b=>{const a=new Uint8Array(await b.arrayBuffer());let s='';for(let i=0;i<a.length;i++)s+=String.fromCharCode(a[i]);res((s.match(/\/Type\s*\/Page[^s]/g)||[]).length)};try{window.__ctPdfRaw?__ctPdfRaw():ctPdf()}catch(e){res(-1)}/* empty contract => «missing fields, continue?» confirm: press continue */let k=0;const cf=setInterval(()=>{const c=[...document.querySelectorAll('.dlg button.p')].find(x=>/كمّل|Continue/.test(x.textContent));if(c){c.click();clearInterval(cf)}if(++k>40)clearInterval(cf)},250);setTimeout(()=>res(-2),15000)},900)}));
  const cf=await p.$('.dlg button.p');if(n===-2&&cf){}await p.evaluate(()=>{window.__pdfCap=null;S.tab='home';render()});if(n!==1)F('contract PDF has '+n+' pages (must be 1)');else OK('contract PDF: one page')}catch(e){F('contract pdf check crashed: '+e.message)}
 // 5c) swipe left/right anywhere switches tabs
 try{await p.evaluate(()=>{S.tab='home';render();document.querySelectorAll('.ov,#hdth').forEach(x=>x.remove());scrollTo(0,300)});await p.waitForTimeout(300);const cd2=await ctx.newCDPSession(p);const t0=await p.evaluate(()=>S.tab);const x=200,y=500;
  await cd2.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:x-120,y}]});for(let i=1;i<=12;i++){await cd2.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:x-120+i*20,y:y+i*0.5}]});await p.waitForTimeout(16)}await cd2.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await p.waitForTimeout(500);
  const t1=await p.evaluate(()=>S.tab);if(t1===t0)F('swipe between tabs does not work');else OK('swipe between tabs ('+t0+' → '+t1+')');await p.evaluate(()=>{S.tab='home';render()})}catch(e){F('swipe check crashed: '+e.message)}
 // 6) language switch must not hang
 const t0=Date.now();const ok=await Promise.race([p.evaluate(()=>{setLang('en');return true}),new Promise(r=>setTimeout(()=>r(false),6000))]);const dt=Date.now()-t0;if(!ok||dt>4000)F('language switch slow/hung ('+dt+'ms)');else OK('language switch '+dt+'ms');await p.evaluate(()=>setLang('ar')).catch(()=>{});await p.waitForTimeout(600);
 // 7) stray UI
 const ui=await p.evaluate(()=>{const o=[];const t=document.getElementById('toast');if(t&&!t.textContent.trim()&&t.offsetHeight>0)o.push('empty toast visible');try{(window.bnyUiCheck&&bnyUiCheck()||[]).forEach(x=>o.push('ui: '+(x.msg||x)))}catch(e){}if(document.documentElement.scrollWidth>innerWidth+2)o.push('page scrolls sideways');return o});ui.forEach(F);if(!ui.length)OK('UI checks');
 if(errs.length)errs.slice(0,5).forEach(e=>F('page error: '+e));else OK('no page errors');
 // 8) real-phone flow over http (service worker, refresh, update): no reload loops, app opens
 try{const http=require('http'),os=require('os');const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'bny-'));cp(path.join(ROOT,'docs'),tmp);
  const srv=http.createServer((q,r)=>{let f=path.join(tmp,decodeURIComponent(q.url.split('?')[0]));if(f.endsWith('/'))f+='index.html';fs.readFile(f,(e,d)=>{if(e){r.statusCode=404;return r.end()}r.setHeader('Content-Type',f.endsWith('.html')?'text/html; charset=utf-8':f.endsWith('.js')?'application/javascript':f.endsWith('.json')?'application/json':'application/octet-stream');r.end(d)})}).listen(0);
  const port=srv.address().port,ctx2=await b.newContext({...devices['Pixel 7']}),q=await ctx2.newPage();let loads=0;q.on('load',()=>loads++);const e2=[];q.on('pageerror',e=>e2.push(e.message));
  await q.addInitScript(()=>{try{localStorage.setItem('bny_hd_t',String(Date.now()))}catch(e){}});
  await q.goto('http://127.0.0.1:'+port+'/index.html');await q.waitForTimeout(4000);
  loads=0;await q.reload();await q.waitForTimeout(9000);if(loads>1)F('refresh without update reloaded '+loads+' times');
  fs.appendFileSync(path.join(tmp,'index.html'),'\n<!-- t'+Date.now()+' -->');loads=0;await q.reload();await q.waitForTimeout(15000);if(loads>2)F('reload loop after an update: '+loads+' loads in 15s');
  fs.appendFileSync(path.join(tmp,'index.html'),'\n<!-- u'+Date.now()+' -->');loads=0;await q.reload();await q.waitForTimeout(12000);if(loads>2)F('reload loop after 2nd update: '+loads+' loads');
  const shown=await q.evaluate(()=>document.body.innerText.length);if(shown<50)F('app blank over http');
  e2.slice(0,3).forEach(e=>F('http page error: '+e));if(!fails.some(x=>/reload|http/.test(x)))OK('http flow: refresh/update without loops');srv.close();await ctx2.close()}catch(e){F('http flow check crashed: '+e.message)}
 await b.close();notes.forEach(x=>console.log('ℹ️ '+x));console.log(fails.length?'\nFAILED: '+fails.length:'\nALL GOOD');process.exit(fails.length?1:0)})().catch(e=>{console.log('❌ checker crashed: '+e.message);process.exit(2)});
