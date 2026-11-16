# بيعمل lib/ui/i18n.dart من tool/en.json (عربي → إنجليزي) للنصوص المستخدمة بـ L.t
import json,re,glob
EN=json.load(open('tool/en.json'))
used=set()
for f in glob.glob('lib/ui/*.dart'):
    if f.endswith('i18n.dart'): continue
    for m in re.finditer(r"L\.t\('((?:[^'\\\n]|\\.)*)'\)",open(f).read()): used.add(m.group(1))
def dq(s): return "'"+s.replace('\\','\\\\').replace("'","\\'").replace('$','\\$')+"'"
miss=[u for u in used if not (EN.get(u) or EN.get(u.strip()))]
if miss: print('MISSING',miss)
lines=['  %s: %s,'%("'"+u+"'",dq(EN.get(u) or EN.get(u.strip()))) for u in sorted(used) if (EN.get(u) or EN.get(u.strip()))]
open('lib/ui/i18n.dart','w').write("""/// اللغة: عربي (الأساس) أو إنجليزي — القاموس من بنيان القديم (TRD) + ترجمات الشاشات الجديدة. الملف ده متولّد: tool/i18n_gen.py
import 'package:flutter/material.dart';
import '../core/store.dart';

class L {
  static String get lang => Store.I.cfg['lang'] == 'en' ? 'en' : 'ar';
  static bool get en => lang == 'en';
  static TextDirection get dir => en ? TextDirection.ltr : TextDirection.rtl;
  static String t(String s) => en ? (_en[s] ?? _en[s.trim()] ?? s) : s;
  static Future<void> set(String l) async { Store.I.cfg['lang'] = l; await Store.I.saveCfg(); Store.I.notify(); }
  static const Map<String, String> _en = {
"""+'\n'.join(lines)+"""
  };
}
""")
print('entries',len(lines))
