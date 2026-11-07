// Free automatic code repair (runs in GitHub Actions, no Claude needed).
// Reads the phone reports from bunyan-data2/monitor.json (+ recent history), finds a repeated code error,
// asks Gemini (free key) for a fixed version of the function that failed, applies it,
// then runs tools/check.js. Only if it prints ALL GOOD the fix is committed (by the workflow).
// env: GEMINI_KEY, DATA_DIR (clone of bunyan-data2)
const fs=require('fs'),path=require('path'),cp=require('child_process');const acorn=require('acorn');
const ROOT=path.join(__dirname,'..'),F=path.join(ROOT,'rental-tracker.html'),DATA=process.env.DATA_DIR,KEY=process.env.GEMINI_KEY;
const LOG=path.join(__dirname,'autofix-log.json');const log=fs.existsSync(LOG)?JSON.parse(fs.readFileSync(LOG,'utf8')):[];
function out(m){console.log(m)}
if(!KEY||!DATA){out('no GEMINI_KEY / DATA_DIR — skipping');process.exit(0)}
const BENIGN=/Failed to fetch|NetworkError|Load failed|timeout|AbortError|cancel|إلغاء|بصمة|NotAllowed|FILE_NOTCREATED|ResizeObserver|Script error|quota/i;
// collect errors from the last ~24h of monitor.json versions
let reps=[];try{const hs=cp.execSync('git log --since="30 hours ago" --format=%h -- monitor.json',{cwd:DATA}).toString().trim().split('\n').filter(Boolean);
 hs.forEach(h=>{try{reps.push(JSON.parse(cp.execSync('git show '+h+':monitor.json',{cwd:DATA,maxBuffer:1e8}).toString()))}catch(e){}})}catch(e){}
const errs={};reps.forEach(r=>(r.errs||r.errList||[]).concat((r.issues||[]).filter(x=>x.area==='أخطاء برمجية').map(x=>({m:x.msg,s:x.stack||''}))).forEach(e=>{if(!e||!e.m||BENIGN.test(e.m))return;const k=e.m.slice(0,160);errs[k]=errs[k]||{m:e.m,s:e.s||'',n:0};errs[k].n++;if(e.s&&!errs[k].s)errs[k].s=e.s}));
const cand=Object.values(errs).filter(e=>e.n>=2&&!log.some(l=>l.m===e.m&&Date.now()-l.at<3*864e5)).sort((a,b)=>b.n-a.n);
if(!cand.length){out('nothing to fix');process.exit(0)}
const src=fs.readFileSync(F,'utf8');
// map every top-level function declaration in the inline scripts
const fns={};const re=/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/g;let m;while(m=re.exec(src)){const off=m.index+m[0].indexOf('>')+1;let ast;try{ast=acorn.parse(m[1],{ecmaVersion:'latest',allowReturnOutsideFunction:true})}catch(e){continue}
 (function walk(n,depth){if(!n||typeof n.type!=='string')return;if(n.type==='FunctionDeclaration'&&n.id&&!fns[n.id.name])fns[n.id.name]={start:off+n.start,end:off+n.end,depth};for(const k in n){const v=n[k];if(Array.isArray(v))v.forEach(c=>c&&typeof c.type==='string'&&walk(c,depth+1));else if(v&&typeof v.type==='string')walk(v,depth+1)}})(ast,0)}
function nameFrom(e){const names=(String(e.s)+'\n'+e.m).split('\n').map(l=>(l.match(/at\s+(?:Object\.|window\.)?([A-Za-z_$][\w$]*)\s*\(/)||l.match(/^\s*([A-Za-z_$][\w$]*)@/)||[])[1]).filter(n=>n&&fns[n]&&!/^(render|push)$/.test(n));return names[0]}
(async()=>{for(const e of cand.slice(0,3)){const fn=nameFrom(e);const rec={at:Date.now(),m:e.m,fn:fn||'',st:'skip'};if(!fn){rec.why='no function in stack';log.push(rec);continue}
 const f=fns[fn],code=src.slice(f.start,f.end);if(code.length>20000){rec.why='function too big';log.push(rec);continue}
 const q='You are an expert JavaScript engineer. A single-file rental-accounting web app (Arabic UI, Android WebView) keeps throwing this error on the owner phone:\n'+e.m+'\nstack:\n'+String(e.s).slice(0,800)+'\n\nThis is the current function `'+fn+'`:\n```js\n'+code+'\n```\nReturn a fixed version of the SAME function (same name, params, return values). Do not change any calculation or behaviour except preventing the error (guard undefined/null, keep identical results). No fetch, no storage, no new globals. Reply ONLY JSON: {"code":"function '+fn+'(...){...}","why":"one short sentence in Egyptian Arabic"}';
 let j;try{const r=await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',{method:'POST',headers:{'Content-Type':'application/json','x-goog-api-key':KEY},body:JSON.stringify({contents:[{parts:[{text:q}]}],generationConfig:{temperature:0.2,responseMimeType:'application/json'}})});const d=await r.json();const t=d.candidates[0].content.parts.map(p=>p.text).join('');j=JSON.parse(t.match(/\{[\s\S]*\}/)[0])}catch(x){rec.st='fail';rec.why='gemini: '+x.message;log.push(rec);continue}
 const nc=String(j.code||'');try{acorn.parse(nc,{ecmaVersion:'latest'})}catch(x){rec.st='fail';rec.why='bad code';log.push(rec);continue}
 if(!new RegExp('^function\\s+'+fn+'\\s*\\(').test(nc.trim())||/fetch\(|localStorage|XMLHttpRequest|token/.test(nc)){rec.st='fail';rec.why='unsafe/unexpected code';log.push(rec);continue}
 const next=src.slice(0,f.start)+nc.trim()+src.slice(f.end);fs.writeFileSync(F,next);
 let ok=false;try{cp.execSync('python3 tools/sync.py rental-tracker.html',{cwd:ROOT,stdio:'inherit'});const o=cp.execSync('node tools/check.js '+path.join(DATA,'book.json'),{cwd:ROOT}).toString();ok=/ALL GOOD/.test(o);out(o)}catch(x){out(String(x.stdout||x.message))}
 if(ok){rec.st='fixed';rec.why=j.why||'';log.push(rec);fs.writeFileSync(LOG,JSON.stringify(log.slice(-50),null,1));fs.writeFileSync(path.join(ROOT,'.autofix-msg'),'Auto-fix ('+fn+'): '+e.m.slice(0,100)+'\n\n'+(j.why||''));out('FIXED '+fn);process.exit(0)}
 fs.writeFileSync(F,src);cp.execSync('python3 tools/sync.py rental-tracker.html',{cwd:ROOT});rec.st='rejected';rec.why='check failed';log.push(rec)}
 fs.writeFileSync(LOG,JSON.stringify(log.slice(-50),null,1));out('no safe fix')})();
