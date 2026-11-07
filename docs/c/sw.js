// Fast start: show the saved copy instantly (cache first), update it in the background,
// and tell the page when a new version arrived (it reloads at the next good moment).
const V='bunyan-v5',F=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png'],X=['https://cdnjs.cloudflare.com/ajax/libs/jsQR/1.4.0/jsQR.min.js'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(async c=>{await c.addAll(F);await Promise.all(X.map(u=>fetch(u,{mode:'no-cors'}).then(r=>c.put(u,r)).catch(()=>{})))}).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==V).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
function net(req,ms){return new Promise((ok,no)=>{const t=setTimeout(()=>no(new Error('timeout')),ms);fetch(req.mode==='navigate'?req.url:req,{cache:'no-cache'}).then(r=>{clearTimeout(t);ok(r)},e=>{clearTimeout(t);no(e)})})}
let lastUpd=0;async function tell(){lastUpd=Date.now();for(const w of [0,800,2000,4000]){await new Promise(r=>setTimeout(r,w));const cs=await self.clients.matchAll({type:'window',includeUncontrolled:true});cs.forEach(c=>c.postMessage({t:'updated'}))}}
self.addEventListener('message',e=>{if(e.data==='q'&&Date.now()-lastUpd<20000&&e.source)e.source.postMessage({t:'updated'})});
self.addEventListener('fetch',e=>{const q=e.request;if(q.method!=='GET')return;const u=new URL(q.url);if(u.hostname==='api.github.com'||u.hostname==='wa.me'||u.hostname.indexOf('googleapis')>=0)return;
 const nav=q.mode==='navigate'||/\/(index\.html)?$/.test(u.pathname);
 if(nav&&u.origin===self.location.origin){
  const key=new URL('./index.html',self.registration.scope).href;
  const hitP=caches.open(V).then(c=>c.match(q,{ignoreSearch:true}).then(m=>m||c.match(key)));
  const oldP=hitP.then(h=>h?h.clone().text():'').catch(()=>'');
  const upd=oldP.then(old=>net(q,15000).then(async r=>{if(r&&r.ok){const c=await caches.open(V);const nb=await r.clone().text();await c.put(q,r.clone());await c.put(key,r.clone());if(old&&nb!==old)await tell()}return r}).catch(()=>null));
  e.waitUntil(upd);
  e.respondWith(hitP.then(hit=>hit||upd.then(r=>r||Response.error())));return}
 e.respondWith(net(q,8000).then(r=>{if(r&&(r.ok||r.type==='opaque')){const c=r.clone();caches.open(V).then(x=>x.put(q,c)).catch(()=>{})}return r}).catch(()=>caches.match(q,{ignoreSearch:true}).then(m=>m||Response.error())))});
