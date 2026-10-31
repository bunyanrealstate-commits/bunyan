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
assert 'var OW=' not in cust and 'ownbtn' not in cust
import shutil
cd=os.path.join(os.path.dirname(d),'c');os.makedirs(cd,exist_ok=True)
open(os.path.join(cd,'index.html'),'w',encoding='utf-8').write(cust)
for f in ('manifest.webmanifest','sw.js','icon-192.png','icon-512.png','icon-maskable-512.png'):
    shutil.copy(os.path.join(os.path.dirname(d),f),os.path.join(cd,f))
pass
print('customer',len(cust))
