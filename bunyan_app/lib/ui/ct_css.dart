// مولّد تلقائياً من rental-tracker.html (ستايل العقد) — tool: python في PLAN
const ctCss = '''
/* ctcss */

#ctwrap .ctf{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:8px}
#ctwrap .ctf label{font-size:12px;color:var(--mu);display:block;margin:0 0 3px}
#ctwrap .ctf .w2{grid-column:1/-1}
#ctwrap .ctb{display:flex;gap:8px;flex-wrap:wrap;margin-top:10px}
#ctview{overflow:hidden;border-radius:6px;background:#e9edf2;padding:0}
#ctpaper{width:794px;min-height:1000px;box-sizing:border-box;background:#fff;color:#111;margin:0;padding:22px;transform-origin:top right;direction:rtl;font-family:Arial,Tahoma,'Segoe UI','Noto Naskh Arabic','Noto Sans Arabic',sans-serif;outline:0}
#ctpaper .fr{direction:ltr;border:3px double #111;padding:18px 16px 26px;min-height:950px;box-sizing:border-box}
#ctpaper h1{font-size:20px;text-align:center;margin:0 0 4px;text-decoration:underline;font-family:'Times New Roman',serif;direction:ltr}
#ctpaper h1 small{display:block;font-size:15px;font-family:inherit;text-decoration:none;direction:rtl;margin-top:2px}
#ctpaper table{width:100%;border-collapse:collapse;margin:10px 0;table-layout:fixed}
#ctpaper td{unicode-bidi:plaintext;border:1px solid #111;padding:7px 8px;font-size:13px;text-align:center;font-weight:700;vertical-align:middle;word-break:break-word;color:#111}
#ctpaper td.en{width:23%;font-family:'Times New Roman',Times,'Liberation Serif',serif;font-size:12.5px;padding-left:4px;padding-right:4px}
#ctpaper td.ar{width:19%}
#ctpaper .fv{display:inline-block;min-width:40px}
#ctpaper h2{font-size:15px;text-align:center;margin:14px 0 4px;text-decoration:underline;color:#111}
#ctpaper .tm{display:grid;grid-template-columns:1fr 1fr;border:1px solid #111}
#ctpaper .tm>div{padding:8px 12px 8px 16px;font-size:12.5px;line-height:1.85;font-weight:700}
#ctpaper .tm>div:last-child{direction:rtl;text-align:right}#ctpaper .tm>div:first-child{direction:ltr;text-align:left;border-right:1px solid #111;font-family:'Times New Roman',Times,'Liberation Serif',serif;font-size:13px}
#ctpaper ul{margin:0;padding:0 18px 0 0;list-style:disc}#ctpaper h1,#ctpaper h2{unicode-bidi:plaintext}
#ctpaper .tm>div:first-child ul{padding:0 0 0 18px}
#ctpaper .sg{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;text-align:center;margin-top:34px;font-weight:700;font-size:13px}
#ctpaper .sg div{padding-bottom:50px;border-bottom:1px dotted #111}
#ctpaper .sg small{display:block;font-size:11px}
@page{size:A4;margin:8mm}
@media print{
 body.ctp .hd,body.ctp #nav,body.ctp #syinfo,body.ctp .navrest,body.ctp #toast,body.ctp #rob{display:none!important}
 body.ctp #app>*:not(#ctwrap){display:none!important}
 body.ctp #ctwrap>*:not(#ctview){display:none!important}
 body.ctp,body.ctp main,body.ctp #app{background:#fff!important;padding:0!important;margin:0!important}
 body.ctp #ctview{background:#fff;border-radius:0}
 body.ctp #ctpaper{transform:none!important;width:100%!important;padding:0!important}
}

/* ctzcss */
#ctzb .ctid{display:inline-flex;align-items:center;min-height:36px;padding:6px 12px;border-radius:999px;font-size:13px;font-weight:800;background:#e8f6ef;border:1.5px solid #bfe3cf;color:#17643f;cursor:pointer}#ctview,#ctview *,.dlg,#modal{touch-action:pan-x pan-y pinch-zoom!important}#ctview{-webkit-overflow-scrolling:touch}#ctzb{display:flex;gap:6px;justify-content:center;margin:0 0 8px;position:sticky;top:124px;z-index:5}#ctzb button{min-height:36px!important;padding:6px 14px!important;border-radius:999px!important;font-size:14px!important;font-weight:800!important;background:#fff!important;border:1.5px solid #cfe0e6!important;color:#1b4764!important;box-shadow:0 3px 10px rgba(15,39,66,.12)!important}#ctzb #ctzl{min-width:96px}
/* ct2css */
#ctzb{flex-wrap:wrap}#ctzb .ctid.ll{background:#eef4ff;border-color:#c9d8f5;color:#1b4fa0}#ctzb .ctid.ph{background:#fff5e6;border-color:#f3d9ae;color:#8a5a12}#ctzb .ctlang{display:inline-flex;border:1.5px solid #cfe0e6;border-radius:999px;overflow:hidden}#ctzb .ctlang button{border:0!important;border-radius:0!important;min-height:34px!important;padding:4px 12px!important}#ctzb .ctlang button.on{background:#1473e6!important;color:#fff!important}
.sgbox{display:flex;gap:10px;flex-wrap:wrap;margin-top:8px}.sgit{border:2px solid rgba(120,140,160,.25);border-radius:12px;padding:6px;background:#fff;cursor:pointer;position:relative;width:132px;text-align:center}.sgit.on{border-color:#1473e6;box-shadow:0 0 0 3px rgba(20,115,230,.15)}.sgit img{width:120px;height:56px;object-fit:contain;display:block}.sgit small{display:block;font-size:11px;color:#556;margin-top:2px}.sgit .x{position:absolute;top:-8px;left:-8px;width:24px;height:24px;border-radius:50%;padding:0!important;min-height:0!important;font-size:12px!important;background:#fff!important;border:1px solid #e3b4b4!important;color:#b42318!important}
#sgpad{width:100%;height:190px;border:2px dashed #b8c8d4;border-radius:12px;background:#fff;touch-action:none;display:block}
#ctpaper .ctsig{display:block;max-width:150px;max-height:48px;margin:6px auto -50px;object-fit:contain}
/* ct3css */
.ctact{display:flex;gap:8px;flex-wrap:wrap;margin:10px 0 4px}.ctact button{flex:1 1 140px}.ctmiss{background:#fff6e6;border:1px solid #f3d9ae;color:#7a4d0b;border-radius:12px;padding:8px 12px;font-size:13px;margin:8px 0}.ctmiss b{font-weight:800}#ctpaper .ctdate{text-align:center;font-size:13px;margin:-6px 0 10px;color:#333}#ctpaper .cttsig{display:block;max-width:150px;max-height:48px;margin:6px auto -50px;object-fit:contain}
/* ctbarcss */

#ctzb.tidy{flex-direction:column;flex-wrap:nowrap;gap:6px;align-items:stretch;padding:6px;border-radius:16px;background:rgba(255,255,255,.92);box-shadow:0 4px 14px rgba(15,39,66,.10);max-width:520px;margin:0 auto 8px}
#ctzb .zr{display:flex;gap:6px;flex-wrap:nowrap;align-items:center;min-width:0}
#ctzb .zr1 .ctid{flex:1 1 0;min-width:0;justify-content:center;gap:3px;min-height:32px;padding:4px 6px;font-size:12.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#ctzb .zr2{justify-content:space-between}
#ctzb .zcap{font-size:12px;font-weight:800;color:#3d5568;text-align:center;padding:2px 0 0}
#ctzb .zr1 .ctid{font-size:11.5px!important;padding:4px 4px!important}
body.onct.pv #app .bq,body.onct.pv .ov .bq{filter:none!important;pointer-events:auto!important;user-select:auto!important;-webkit-user-select:auto!important}body.onct.pv #app input{filter:none!important}
#ctzb .zg{display:inline-flex;align-items:center;border:1.5px solid #cfe0e6;border-radius:999px;overflow:hidden;background:#fff}
#ctzb .zg button,#ctzb.tidy .ctlang button{border:0!important;border-radius:0!important;box-shadow:none!important;min-height:30px!important;padding:3px 12px!important;font-size:13px!important}
#ctzb .zg #ctzl{min-width:0;border-inline:1px solid #e3edf1!important}
#ctpaper td:has([data-f]){white-space:normal!important;overflow-wrap:break-word}
.fx-btns{display:grid!important;grid-template-columns:1fr 1fr;gap:8px!important}.fx-btns>button{margin:0!important;width:auto!important;justify-content:center}
.ctb.tidy{display:grid!important;grid-template-columns:1fr 1fr;gap:6px!important}
.ctb.tidy>button{min-height:36px!important;padding:6px 8px!important;font-size:13px!important;margin:0!important;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;width:auto!important}

/* ctlayoutcss */

#ctpaper td.en,#ctpaper td.ar{white-space:normal!important}
#ctpaper td.en,#ctpaper .tm>div:first-child,#ctpaper h1{font-family:Arial,Helvetica,'Liberation Sans',sans-serif!important}
#ctwrap .ctsec{grid-column:1/-1;margin:10px 0 0;padding:6px 0 2px;border-top:1px dashed #d5e0e7;font-weight:800;font-size:13.5px;color:#1b4764}
#ctwrap .ctsec:first-child{border-top:0;margin-top:0}
#ctwrap #ctzb.inform{position:static!important;box-shadow:none!important;background:#f3f8fb!important;margin:0 0 10px!important;max-width:none}
#ctzoom{position:sticky;top:124px;z-index:5;display:flex;justify-content:center;margin:0 0 8px}
#ctzoom .zg{box-shadow:0 3px 10px rgba(15,39,66,.12)}
#ctacts{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:4px}
#ctacts>button{margin:0!important;min-height:40px;font-size:13.5px!important;width:auto!important;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
#ctacts>button.wide{grid-column:1/-1;min-height:46px;font-size:15px!important}
#sgcard .sgacts{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:10px}#sgcard .sgacts>button{margin:0!important;width:auto!important;font-size:13px!important}#sgcard .sgacts>button.wide{grid-column:1/-1}
#app .ctb,#app .ctact,#app .sgmb,#sgcard .sghint{display:none!important}
#ctwrap .cttoday{margin-top:4px;font-size:12px!important;padding:3px 10px!important;min-height:0!important}

/* ctpluscss */

#ctpaper h1 small,#ctpaper .ctdate{display:none!important}
#sgcard{padding:10px 12px!important}#sgcard h2{font-size:15px!important;margin:0 0 6px!important;padding-bottom:6px!important}#sgcard>p.mu{display:none!important}
#sgcard .sgbox{gap:6px!important}#sgcard .sgit{min-height:0!important;padding:4px 6px!important}#sgcard .sgit img{max-height:34px!important}#sgcard .sgit small{font-size:11px!important}
#sgcard .sgit[onclick="ctSigNew()"],#sgcard .sgit[onclick="ctSig('')"]{min-height:44px!important;font-size:13px!important}
#sgcard .sgacts{gap:6px!important;margin-top:8px!important}#sgcard .sgacts>button{min-height:34px!important;padding:4px 8px!important;font-size:12.5px!important}
#ctundo{position:fixed;right:max(14px,env(safe-area-inset-right,0px));bottom:calc(96px + env(safe-area-inset-bottom,0px));z-index:900;display:flex;gap:6px}
#ctundo{opacity:.9}#ctundo button{width:44px;height:44px;border-radius:50%;border:0;background:#0f2742;color:#fff;font-size:22px;font-weight:800;box-shadow:0 6px 18px rgba(0,0,0,.25);display:flex;align-items:center;justify-content:center;padding:0}
#ctundo button:disabled{opacity:.35}#ctundo small{position:absolute;top:-6px;left:-4px;background:#e5484d;color:#fff;border-radius:999px;font-size:10px;padding:1px 5px;font-weight:800}
#ctxl{width:min(96vw,440px);box-sizing:border-box;position:fixed;left:50%;transform:translateX(-50%);bottom:calc(14px + env(safe-area-inset-bottom,0px));z-index:950;background:#0f2742;color:#fff;border-radius:16px;padding:6px;box-shadow:0 8px 24px rgba(0,0,0,.3);display:flex;flex-wrap:wrap;gap:4px;justify-content:center;max-width:calc(100vw - 20px)}
#ctxl button{flex:1 1 auto;min-height:32px;min-width:34px;border:0;border-radius:10px;background:#ffffff1f;color:#fff;font-size:12.5px;font-weight:800;padding:0 8px}
#ctxl button.x{background:#e5484d}#ctxl .t{flex-basis:100%;text-align:center;font-size:11px;opacity:.8}
#ctpaper td.xlsel,#ctpaper li.xlsel{outline:2px solid #1473e6;outline-offset:-2px}
.wsdlg .wsw{display:flex;gap:6px;margin:0 0 8px}.wsdlg .wsw button{flex:1}.wsdlg .wsw button.on{background:#1473e6!important;color:#fff!important}

/* ctonepage */

#ctpaper{min-height:1123px!important}#ctpaper .fr{min-height:1079px!important;padding:14px 16px 18px!important}
#ctpaper table{margin:8px 0!important}#ctpaper td{padding:5px 8px!important}
#ctpaper h2{margin:10px 0 4px!important}#ctpaper .tm>div{line-height:1.6!important;padding:6px 12px 6px 16px!important}
#ctpaper .sg{margin-top:20px!important}#ctpaper .sg div{padding-bottom:44px!important}
@media print{body.ctp #ctpaper{zoom:.93}}

/* ctsubpickcss */
#ctsubpk{width:100%;margin-top:6px;font-size:14px;padding:9px 10px;border-radius:10px;border:1.5px dashed var(--ac,#1a7f5a);background:color-mix(in srgb,var(--ac,#1a7f5a) 7%,var(--card,#fff));font-weight:700}
/* ctbidi */
/* Arabic mixed with numbers («6 شيكات») shows in the right order: the direction follows the text itself */
#ctpaper .fv,#ctpaper .t2 td,#ctpaper .t2b td,#ctf input,#ctf textarea,#ct2box input,#ct2box textarea,[data-ct] input{unicode-bidi:plaintext}

/* ct2css */

#ctpaper .fr.t2{border:0;padding:6px 10px 20px;direction:rtl}
#ctpaper .t2b table{display:table!important;width:100%!important}#ctpaper .t2b tbody{display:table-row-group!important}#ctpaper .t2b tr{display:table-row!important}#ctpaper .t2b td{display:table-cell!important}#ctpaper .t2b table.ptb td{font-size:12.5px;padding:4px 6px}#ctpaper .t2b table.ptb td.en{width:25%;font-size:11.5px;line-height:1.3}#ctpaper .t2b .tm>div{font-size:11px!important;line-height:1.5!important;padding:6px 10px!important}#ctpaper .t2b table:not(.ptb) td{padding:4px 7px!important}#ctpaper .t2b h2{margin:8px 0 3px!important}#ctpaper .t2b .sg{margin-top:16px!important}#ctpaper .t2b .sg div{padding-bottom:40px!important}
#ctpaper .t2 table{display:table!important;width:100%!important}#ctpaper .t2 tbody{display:table-row-group!important}#ctpaper .t2 tr{display:table-row!important}#ctpaper .t2 td{display:table-cell!important}
#ctpaper .fr.t2.en{direction:ltr}
#ctpaper .t2 h1{font-size:22px;text-decoration:underline;margin:4px 0 14px;direction:inherit}
#ctpaper .t2 table.kv td{font-size:14.5px;padding:8px 10px;text-align:center}
#ctpaper .t2 table.kv td.k{font-weight:800}
#ctpaper .t2 table.kv td.k2{font-weight:800}
#ctpaper .t2 h2{font-size:16px;margin:10px 0 6px;text-decoration:underline}
#ctpaper .t2 table.ptb td{font-size:14px;padding:5px 8px}
#ctpaper .t2 table.ptb tr:first-child td{font-weight:800}
#ctpaper .t2 .nl{font-weight:800;text-decoration:underline;margin:18px 0 6px;font-size:15px}
#ctpaper .t2 .tm{display:grid;grid-template-columns:1fr 1fr;border:1px solid #111;min-height:240px}
#ctpaper .t2 .tm>div{padding:10px 14px;font-size:14px;line-height:1.55;font-weight:700;direction:inherit!important;text-align:start!important;font-family:inherit!important}
#ctpaper .t2 .tm>div:first-child{border-left:1px solid #111;border-right:0}
#ctpaper .t2.en .tm>div:first-child{border-right:1px solid #111;border-left:0}
#ctpaper .t2 .tm ul{padding:0 18px 0 0!important;list-style:'-  '}
#ctpaper .t2.en .tm ul{padding:0 0 0 18px!important}
#ctpaper .t2 .sg{direction:ltr;margin-top:10px}
#ctpaper .t2 .sg div{padding-bottom:46px}
#ct2tpl{display:flex;gap:6px;margin:0 0 10px}#ct2tpl button{flex:1;margin:0!important;padding:9px!important;border-radius:12px!important;font-weight:800}#ct2tpl button.on{background:var(--ac,#1473e6)!important;color:#fff!important;border-color:transparent!important}
#ct2box{border:1.5px dashed var(--bd,#cfd8e3);border-radius:14px;padding:10px;margin:10px 0}#ct2box h4{margin:0 0 8px;font-size:14px}
#ct2box .g3{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:8px}#ct2box label{font-size:12px;font-weight:700;display:block;margin-bottom:3px}#ct2box input,#ct2box select{width:100%;box-sizing:border-box;margin:0!important}
#ct2box .pr{display:grid;grid-template-columns:28px 1fr 1.1fr .9fr 30px;gap:6px;align-items:center;margin:6px 0}#ct2box .pr b{text-align:center}
#ct2box .rw{display:flex;gap:6px;flex-wrap:wrap;margin-top:8px}#ct2box .rw button{margin:0!important}

/* ctgcss */

#ctgb{position:fixed;left:0;right:0;bottom:0;z-index:300;background:var(--card,#fff);border-top:2px solid #1b7a4b;box-shadow:0 -6px 20px rgba(0,0,0,.15);padding:6px 8px calc(6px + env(safe-area-inset-bottom,0px));direction:rtl}
#ctgb .r{display:flex;gap:5px;overflow-x:auto;scrollbar-width:none;padding:2px 0}#ctgb .r::-webkit-scrollbar{display:none}
#ctgb button{flex:none;margin:0!important;padding:7px 9px!important;font-size:12.5px!important;border-radius:10px!important;white-space:nowrap}
#ctgb .t{font-size:11.5px;font-weight:800;color:#0f5132;margin:0 2px 3px;display:flex;justify-content:space-between;align-items:center}#ctgb .t button{padding:3px 9px!important}
#ctgb button.dl{color:#b3261e!important}
#ctpaper .ctgsel{outline:3px solid #f2a516!important;outline-offset:-2px}#ctpaper .ctgblk{outline:2px dashed #1b7a4b!important;outline-offset:2px}
body.ctgon #app{padding-bottom:110px}
html.dark #ctgb .t{color:#9fe0bb}

''';
