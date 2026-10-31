const V='bunyan-v4',F=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png'],X=['https://cdnjs.cloudflare.com/ajax/libs/jsQR/1.4.0/jsQR.min.js'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(V).then(async c=>{await c.addAll(F);await Promise.all(X.map(u=>fetch(u,{mode:'no-cors'}).then(r=>c.put(u,r)).catch(()=>{})))}).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==V).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
function net(req,ms){return new Promise((ok,no)=>{const t=setTimeout(()=>no(new Error('timeout')),ms);fetch(req,{cache:'no-cache'}).then(r=>{clearTimeout(t);ok(r)},e=>{clearTimeout(t);no(e)})})}
self.addEventListener('fetch',e=>{const q=e.request;if(q.method!=='GET')return;const u=new URL(q.url);if(u.hostname==='api.github.com'||u.hostname==='wa.me')return;
 const nav=q.mode==='navigate';
 e.respondWith(net(q,nav?4000:8000).then(r=>{if(r&&(r.ok||r.type==='opaque')){const c=r.clone();caches.open(V).then(x=>x.put(q,c)).catch(()=>{})}return r}).catch(()=>caches.match(q,{ignoreSearch:true}).then(m=>m||(nav?caches.match('./index.html'):Response.error()))))});
