/// أبديت الجروبات التلقائي: الجانب بتاع Dart
/// أندرويد (WaListener) بيقرا صور جروبات الشركات المختارة بـ Gemini ويحفظ النتيجة،
/// وهنا بنطبقها على الفيلا الصح (أو نعمل فيلا جديدة) ونسجل اللي اتغير.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io' show File;
import 'dart:typed_data';
import 'ai.dart';
import 'media.dart';
import 'ocrparse.dart';
import 'model.dart';
import 'native.dart';
import 'store.dart';

String nkey(dynamic s) => str(s).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9؀-ۿ]'), '').replaceAll(RegExp(r'^0+'), '');

/// يطبق صفوف الأبديت على الفيلا: الجديد يتضاف، الموجود يتحدث، واللي اختفى من الأبديت يتعلم محجوز
String applyUpdate(Obj v, List<Obj> rows, {bool missingBooked = true, bool auto = false}) {
  final us = (v['units'] as List?) ?? (v['units'] = <dynamic>[]);
  Obj? match(Obj r) => objs(v['units']).where((u) => nkey(u['no']).isNotEmpty && nkey(u['no']) == nkey(r['no'])).firstOrNull;
  final seen = rows.map((r) => nkey(r['no'])).toSet();
  final missing = objs(v['units']).where((u) => u['avail'] != false && !seen.contains(nkey(u['no']))).toList();
  final added = <String>[], booked = <String>[], back = <String>[], price = <String>[];
  for (final r in rows) {
    final m = match(r);
    final t = m ?? <String, dynamic>{'id': uid(), 'videos': <dynamic>[]};
    final wasAvail = m == null ? null : m['avail'] != false;
    for (final k in ['p1', 'p2', 'p3', 'mo']) {
      if (numOf(r[k]) > 0 && numOf(r[k]) < 1000 && k != 'mo') r[k] = numOf(r[k]) * 1000; // 58 = 58,000
      if (numOf(r[k]) > 0) {
        if (m != null && numOf(m[k]) > 0 && numOf(m[k]) != numOf(r[k])) price.add('${str(r['no'])}: ${money(numOf(m[k]))}→${money(numOf(r[k]))}');
        t[k] = numOf(r[k]);
      }
    }
    t['no'] = str(r['no']);
    if (str(r['floor']).isNotEmpty) t['floor'] = str(r['floor']);
    if (kTypes.any((k) => k[0] == r['type'])) t['type'] = r['type'];
    if (str(r['tx']).isNotEmpty) t['tx'] = r['tx'];
    if (str(r['note']).isNotEmpty) t['note'] = r['note'];
    t['avail'] = r['booked'] != true;
    if (r['fur'] == true) t['fur'] = true;
    if (m == null) { us.add(t); added.add(str(r['no'])); if (t['avail'] != false) t['newAt'] = DateTime.now().toIso8601String(); }
    else if (wasAvail == true && t['avail'] == false) { booked.add(str(r['no'])); }
    else if (wasAvail == false && t['avail'] == true) { back.add(str(r['no'])); t['newAt'] = DateTime.now().toIso8601String(); }
  }
  // أمان للتلقائي: لو الأبديت فيه شقق أقل بكتير من اللي عندنا (صورة ناقصة أو قراية غلط) منعلّمش الباقي محجوز
  var warn = '';
  if (auto && missing.length >= 2 && missing.length > rows.length) { missingBooked = false; warn = '⚠️ الأبديت فيه ${rows.length} شقة بس وعندك ${missing.length} مش موجودين فيه — معلّمتهمش محجوزين، راجع'; }
  if (missingBooked) { for (final u in missing) { u['avail'] = false; booked.add(str(u['no'])); } }
  final d = DateTime.now();
  v['upd'] = '${d.day}/${d.month}';
  v['chk'] = d.toIso8601String();
  final o = <String>[];
  if (booked.isNotEmpty) o.add('اتحجزت: ${booked.join('، ')}');
  if (added.isNotEmpty) o.add('جديدة: ${added.join('، ')}');
  if (back.isNotEmpty) o.add('رجعت متاحة: ${back.join('، ')}');
  if (price.isNotEmpty) o.add('السعر: ${price.join('، ')}');
  if (warn.isNotEmpty) o.add(warn);
  return o.isEmpty ? 'مفيش تغيير' : o.join(' • ');
}

bool _same(String a, String b) { final x = nkey(a).toLowerCase(), y = nkey(b).toLowerCase(); return x.isNotEmpty && y.isNotEmpty && (x.contains(y) || y.contains(x)); }

String villaNoOf(String s) {
  s = s.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}');
  s = s.replaceAll(RegExp(r'\d+°[\d.\x27"]+\s*[NSEW]', caseSensitive: false), ' '); // الإحداثيات مش رقم فيلا
  s = s.replaceAll(RegExp(r'https?://\S+'), ' ');
  final m = RegExp(r'\bno\.?\s*[-:#]?\s*([0-9]+)', caseSensitive: false).firstMatch(s) ?? RegExp(r'villa\s*(?:no\.?|#|:|-)?\s*([0-9]+[a-z]?)', caseSensitive: false).firstMatch(s) ?? RegExp(r'فيلا\s*(?:رقم)?\s*([0-9]+)').firstMatch(s);
  if (m != null) return m.group(1)!;
  final all = RegExp(r'[0-9]+').allMatches(s).toList();
  return all.isEmpty ? '' : all.last.group(0)!;
}

/// يلاقي الفيلا من الشركة (بتاعة الجروب) ورقم الفيلا المكتوب في الأبديت — ولو مش موجودة يعملها
Obj? findVilla(String company, Obj meta, {bool create = true}) {
  final no = villaNoOf(str(meta['villa']));
  if (no.isEmpty) {
    // فيلا مكتوب اسمها من غير رقم (زي «Villa Madinat Al Riyad»): نعرفها بالاسم + الشركة
    final vn = str(meta['villa']).trim();
    if (vn.length < 5 || company.isEmpty) return null;
    final hit = Store.I.villas.where((v) => str(v['no']).isEmpty && nkey(v['name']).toLowerCase() == nkey(vn).toLowerCase() && _same(str(v['company']), company)).firstOrNull;
    if (hit != null || !create) return hit;
    final v = <String, dynamic>{'id': uid(), 'name': vn, 'no': '', 'company': company, 'area': str(meta['area']), 'loc': '', 'units': <dynamic>[], 'auto': true};
    ((Store.I.D['villas'] as List?) ?? (Store.I.D['villas'] = <dynamic>[])).add(v);
    return v;
  }
  final comp = company.isNotEmpty ? company : str(meta['company']);
  final c = Store.I.villas.where((v) => nkey(v['no']) == nkey(no) || nkey(villaNoOf('${v['name']} ${v['no']}')) == nkey(no)).toList();
  final area = str(meta['area']);
  final hit = c.where((v) => (comp.isEmpty || _same(str(v['company']), comp) || _same(str(v['name']), comp) || str(v['company']).isEmpty) && (area.isEmpty || str(v['area']).isEmpty || _same(str(v['area']), area) || _same(str(v['name']), area))).toList();
  if (hit.isNotEmpty) { if (str(hit.first['company']).isEmpty && comp.isNotEmpty) hit.first['company'] = comp; return hit.first; }
  if (!create) return null;
  final vn = str(meta['villa']).trim();
  final named = RegExp(r'[A-Za-z\u0600-\u06FF]{3,}').allMatches(vn).any((m) => !RegExp(r'^(villa|فيلا|no|rd|road)$', caseSensitive: false).hasMatch(m.group(0)!));
  final v = <String, dynamic>{'id': uid(), 'name': named ? vn : (comp.isEmpty ? 'فيلا' : comp), 'no': no, 'company': comp, 'area': area, 'loc': '', 'units': <dynamic>[], 'auto': true};
  ((Store.I.D['villas'] as List?) ?? (Store.I.D['villas'] = <dynamic>[])).add(v);
  return v;
}

class AutoUpd {
  static final last = ValueNotifier<List<String>>([]);
  static Map<String, String> get groups => ((Store.I.cfg['groups'] as Map?) ?? {}).map((k, v) => MapEntry(cleanGroup('$k'), '$v'));

  /// نفس تنضيف أندرويد: يشيل «(رسالتان)» و«(3 messages)» وعلامات الاتجاه والمسافات الزيادة
  static String cleanGroup(String s) {
    var t = s.replaceAll(RegExp('[\u200e\u200f\u202a-\u202e\u2066-\u2069\ufeff]'), '');
    final r = RegExp(r'\s*[(（][^()（）]*(\d|[٠-٩]|رسال|message|new|جديد)[^()（）]*[)）]\s*$', caseSensitive: false);
    while (r.hasMatch(t)) { t = t.replaceAll(r, ''); }
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// «تابع كل الجروبات»: أي جروب (حتى الجديد) متابَع إلا اللي قفلته
  static bool get allOn => Store.I.cfg['allGroups'] == true;
  static List<String> get off => ((Store.I.cfg['offGroups'] as List?) ?? const []).map((e) => cleanGroup('$e')).toList();
  static bool follows(String g) => allOn ? !off.contains(cleanGroup(g)) : groups.containsKey(cleanGroup(g));
  /// الشركة بتاعة الجروب: اللي اخترتها، وإلا اسم الجروب نفسه
  static String companyOf(String g) => groups[cleanGroup(g)] ?? cleanGroup(g).replaceAll(RegExp(r'[^\p{L}\p{N}\s&.-]', unicode: true), '').trim();

  static Future<void> sync() async {
    if (kIsWeb || Store.I.testMode) return;
    try { await Native.ch.invokeMethod('autoCfg', {'key': Store.I.gemKey, 'prompt': Ai.autoPrompt, 'groups': groups.keys.toList(), 'all': allOn, 'off': off, 'dm': Store.I.cfg['dm'] == true}); } catch (_) {}
  }

  static Future<bool> on() async { if (kIsWeb) return false; try { return await Native.ch.invokeMethod<bool>('notifOn') ?? false; } catch (_) { return false; } }

  /// الجروبات اللي الواتساب بعت منها إشعارات: {اسم: {at, img}}
  static Future<Map<String, Map>> seen() async {
    if (kIsWeb) return {};
    try {
      final m = <String, Map>{};
      (jsonDecode(await Native.ch.invokeMethod<String>('autoSeen') ?? '{}') as Map).forEach((k, v) {
        final c = cleanGroup('$k'), o = m[c];
        m[c] = o == null ? Map.from(v as Map) : {'at': [o['at'] ?? 0, (v as Map)['at'] ?? 0].reduce((a, b) => (a as num) > (b as num) ? a : b), 'img': ((o['img'] ?? 0) as num) + ((v['img'] ?? 0) as num)};
      });
      return m;
    } catch (_) { return {}; }
  }

  static List<Obj> get log => objs(Store.I.D['log']);

  /// يقرا اللي اتجمع ويطبقه — بيرجع رسايل قصيرة باللي اتغير
  /// صفوف الأبديت → مجموعات حسب الفيلا (صورة واحدة ممكن يبقى فيها شقق من كذا فيلا)
  static List<MapEntry<Obj, List<Obj>>> groupRows(List<Obj> rows) {
    final meta = rows.isEmpty ? <String, dynamic>{} : rows.first;
    final good = rows.where((x) => str(x['no']).isNotEmpty || numOf(x['p1']) > 0 || numOf(x['p2']) > 0 || numOf(x['p3']) > 0 || numOf(x['mo']) > 0).toList();
    final m = <String, MapEntry<Obj, List<Obj>>>{};
    for (final r in good) {
      final vn = str(r['villa']).isNotEmpty ? str(r['villa']) : str(meta['villa']);
      final ar = str(r['area']).isNotEmpty && str(r['villa']).isNotEmpty ? str(r['area']) : str(meta['area']);
      final k = '${nkey(vn).toLowerCase()}|${nkey(ar).toLowerCase()}';
      m.putIfAbsent(k, () => MapEntry({'villa': vn, 'area': ar, 'company': meta['company'], 'terms': meta['terms'], 'kind': meta['kind']}, <Obj>[])).value.add(r);
    }
    // فيلا كل شققها مكتوب إنها برا المناطق اللي تهمك (مدينة الرياض)
    for (final e in m.values) { if (e.value.any((r) => r['inArea'] == false) && !e.value.any((r) => r['inArea'] == true)) e.key['out'] = true; }
    return m.values.toList();
  }

  /// يطبق صورة أبديت (كل فيلا لوحدها) ويسجلها — بيرجع الرسايل اللي فيها تغيير
  static bool get onlyArea => Store.I.cfg['onlyArea'] != false;
  static const _generic = {'real', 'estate', 'properties', 'property', 'llc', 'l.l.c', 'l.l.c.', 'management', 'group', 'team', 'co', 'company', 'and', 'the', 'realestate', 'real-estate', 'برو', 'للعقارات', 'العقارية', 'عقارات'};
  static List<String> _sig(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF ]'), ' ').split(RegExp(r'\s+')).where((w) => w.length >= 3 && !_generic.contains(w)).toList();

  /// الجروب لسه باسمه هو (مش متربط بشركة) والأبديت مكتوب عليه اسم شركة → اربط الجروب بيها وغيّر اسم فللها
  static void linkGroup(String g, String company) {
    final k = cleanGroup(g);
    final cur = groups[k];
    final def = k.replaceAll(RegExp(r'[^\p{L}\p{N}\s&.-]', unicode: true), '').trim();
    if (cur != null && cur != def && cur != k) return; // متربط بشركة قبل كده
    if (_sig(company).any((w) => _sig(def).contains(w))) return;
    Store.I.cfg['groups'] = {...groups, k: company};
    Store.I.saveCfg();
    for (final v in Store.I.villas) { if (str(v['company']) == def || str(v['company']) == k) v['company'] = company; }
  }

  /// الشركة من الكلام المكتوب في الصورة نفسها (اللوجو/الاسم) — علشان صورة شركة متتحطش باسم جروب تاني
  static String companyFromText(String text, String g, [List? els]) {
    final t = ' ${text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF ]'), ' ')} ';
    bool has(String c) { final w = _sig(c); return w.isNotEmpty && w.every((x) => t.contains(' $x ') || t.contains(x)); }
    final mine = companyOf(g);
    if (mine.isNotEmpty && has(mine)) return mine;
    final known = {for (final v in Store.I.villas) str(v['company']), ...groups.values, ...groups.keys.map(cleanGroup)}.where((c) => _sig(c).isNotEmpty).toList()
      ..sort((a, b) => _sig(b).length.compareTo(_sig(a).length));
    for (final c in known) { if (has(c)) return c; }
    final m = RegExp(r'([A-Z][A-Z&\. ]{2,40}?)\s+(REAL\s*ESTATE|PROPERTIES|PROPERTY|HOLDING|REALTY)', caseSensitive: true).firstMatch(text);
    if (m != null) return '${m.group(1)!.trim()} ${m.group(2)!.replaceAll(RegExp(r'\s+'), ' ')}'.split(' ').map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()).join(' ');
    // «Vellast Property Management» / «Kiev Real Estate» مكتوبة بحروف صغيرة
    for (final m2 in RegExp(r'([A-Za-z][A-Za-z&\.]{2,20})\s+(real\s*estate|properties|property\s+management|property|holding|realty)\b', caseSensitive: false).allMatches(text)) {
      final n = m2.group(1)!;
      if (RegExp(r'^(villa|city|riyadh?|the|for|and|our|new|private|rent|abu|dhabi|zone|with|floor|al|el)$', caseSensitive: false).hasMatch(n)) continue;
      return '${n[0].toUpperCase()}${n.substring(1).toLowerCase()} ${m2.group(2)!.replaceAll(RegExp(r'\s+'), ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ')}';
    }
    // اسم الشركة مش مكتوب جنبه Real Estate (زي «Grand Aroma») → أكبر كلام فوق في الصورة
    if (els != null) { final tt = OcrParse.titleText(els); if (tt.isNotEmpty) return tt; }
    return '';
  }

  static List<String> applyRows(String g, List<Obj> rows, {String img = '', List files = const [], bool same = false, String how = '', String company = ''}) {
    final out = <String>[];
    final l = (Store.I.D['log'] as List?) ?? (Store.I.D['log'] = <dynamic>[]);
    for (final grp in groupRows(rows)) {
      final meta = grp.key, good = grp.value;
      if (onlyArea && meta['out'] == true) continue;
      final gc = companyOf(g), mc = str(meta['company']);
      // الشركة المكتوبة في الصورة لو مختلفة عن الجروب (صورة شركة اتعملها فوروارد في جروب تاني)
      final cmp = company.isNotEmpty ? company : (mc.isNotEmpty && (gc.isEmpty || !_sig(mc).any((w) => _sig(gc).contains(w))) ? mc : gc);
      if (company.isNotEmpty) linkGroup(g, company);
      final v = findVilla(cmp, meta);
      if (v != null && str(meta['terms']).isNotEmpty) v['terms'] = str(meta['terms']);
      final String msg;
      var quiet = same;
      if (quiet) {
        msg = '✓ ${v == null ? g : '${str(v['name'])} ${str(v['no'])}'}: نفس الأبديت — مفيش جديد';
      } else if (v == null) {
        msg = '⚠️ $g: جالي أبديت بس مش عارف رقم الفيلا — ضيفه بإيدك من «من صورة الأبديت»';
      } else {
        // إعلان سعر جديد لشقة أو اتنين: منعلّمش باقي الفيلا محجوز
        final ch = applyUpdate(v, good, auto: true, missingBooked: meta['kind'] != 'price');
        quiet = ch == 'مفيش تغيير';
        msg = quiet ? '✓ ${str(v['name'])} ${str(v['no'])}: نفس الأبديت — مفيش جديد' : '${v['auto'] == true && objs(v['units']).length == good.length ? '🆕' : '📥'} ${str(v['name'])} ${str(v['no'])}: $ch${str(v['loc']).isEmpty ? ' • ⚠️ ضيف اللوكيشن' : ''}';
      }
      if (!quiet) out.add(msg);
      l.insert(0, {'at': DateTime.now().toIso8601String(), 'g': g, 'm': msg, 'vid': v?['id'], 'img': img, if (files.isNotEmpty) 'files': files, 'same': quiet, 'n': good.length, if (how.isNotEmpty) 'how': how});
    }
    // اللي برا مدينة الرياض بيتساب من غير ما نزعجك بيه
    while (l.length > 200) { l.removeLast(); }
    return out;
  }

  /// 📥 «اقرا أبديتات النهارده»: كل الجروبات من نص الليل (حتى اللي مش متابَعة) — ممكن ياخد كام دقيقة
  static Future<List<String>> pullToday() async {
    if (kIsWeb || Store.I.testMode) return [];
    await sync();
    try { await Native.ch.invokeMethod('autoToday'); } catch (_) {}
    return pull(force: true);
  }

  /// إيه اللي حصل لآخر صور الجروبات (اتقرت / مش أبديت / ما اتحملتش / Gemini مش رادد)
  static Future<List<Map>> dbg() async {
    if (kIsWeb) return [];
    try { return (jsonDecode(await Native.ch.invokeMethod<String>('autoDbg') ?? '[]') as List).whereType<Map>().toList().reversed.toList(); } catch (_) { return []; }
  }

  static Future<List<Uint8List>> _pagesOf(Map it) async {
    final out = <Uint8List>[];
    final fs = (it['files'] as List?) ?? const [];
    if (fs.isNotEmpty) { for (final f in fs) { try { out.add(await File('$f').readAsBytes()); } catch (_) {} } return out; }
    final b = await Media.orig(str(it['id']));
    if (b != null) out.add(b);
    return out;
  }

  /// 🔍 قراية صفحات (صور) أبديت: على الموبايل الأول (OCR + فهم الجدول)، ولو مش واضح Gemini
  /// 🛠️ تصليح لوحده: أبديت اتحط باسم شركة غلط (أو فلل برا الرياض) — بيتقري تاني على الموبايل ويتحط صح من غير ما تعمل حاجة
  static Future<int> autoFix() async {
    if (kIsWeb || Store.I.testMode) return 0;
    final done = ((Store.I.cfg['fixed3'] as List?) ?? const []).map(str).toSet();
    final keys = <String, Obj>{};
    for (final l in log) {
      final k = str(l['img']).isNotEmpty ? str(l['img']) : (((l['files'] as List?) ?? const []).map(str).firstOrNull ?? '');
      if (k.isEmpty || done.contains(k)) continue;
      final v = Store.I.villa(str(l['vid']));
      if (v != null && v['auto'] == true) keys.putIfAbsent(k, () => l);
    }
    var n = 0;
    for (final e in keys.entries.take(15)) {
      done.add(e.key);
      final it = e.value, g = str(it['g']), files = (it['files'] as List?) ?? const [];
      try {
        final pages = await _pagesOf(it);
        if (pages.isEmpty) continue;
        final all = <dynamic>[];
        var off = 0.0;
        for (final p in pages) {
          final s = await Native.ch.invokeMethod<String>('ocr', {'bytes': p});
          if (s == null) break;
          var mh = 0.0;
          for (final m in (jsonDecode(s) as List).whereType<Map>()) { all.add({...m, 'y': numOf(m['y']) + off}); mh = [mh, numOf(m['y']) + numOf(m['h'])].reduce((a, b) => a > b ? a : b); }
          off += (mh < 1000 ? 1000 : mh) + 200;
        }
        final rows = all.isEmpty ? null : OcrParse.parse(all);
        if (rows == null) continue;
        final comp = companyFromText(all.whereType<Map>().map((m) => '${m['s']}').join(' '), g, all);
        final shotVillas = log.where((l) => (str(l['img']).isNotEmpty ? str(l['img']) : (((l['files'] as List?) ?? const []).map(str).firstOrNull ?? '')) == e.key).map((l) => Store.I.villa(str(l['vid']))).whereType<Obj>().where((v) => v['auto'] == true).toList();
        final wrongComp = comp.isNotEmpty && shotVillas.any((v) => !_sig(str(v['company'])).any((w) => _sig(comp).contains(w)));
        final outside = onlyArea && rows.any((r) => r['inArea'] == false);
        if (!wrongComp && !outside) continue;
        for (final v in shotVillas) { (Store.I.D['villas'] as List).removeWhere((x) => (x as Map)['id'] == v['id']); }
        (Store.I.D['log'] as List).removeWhere((l) { final m = (l as Map); return (str(m['img']).isNotEmpty ? str(m['img']) : (((m['files'] as List?) ?? const []).map(str).firstOrNull ?? '')) == e.key; });
        applyRows(g, rows, img: str(it['img']), files: files, how: 'ocr', company: comp);
        n++;
      } catch (_) {}
    }
    Store.I.cfg['fixed3'] = done.toList().reversed.take(400).toList();
    await Store.I.saveCfg();
    if (n > 0) await Store.I.save();
    return n;
  }

  static String lastText = '';
  static List lastEls = const [];
  static Future<({List<Obj> rows, String how})> smartRead(List<Uint8List> pages, {bool auto = true}) async {
    lastText = '';
    lastEls = const [];
    if (!kIsWeb) {
      try {
        final all = <dynamic>[];
        var off = 0.0;
        for (final p in pages) {
          final s = await Native.ch.invokeMethod<String>('ocr', {'bytes': p});
          if (s == null) { all.clear(); break; }
          final e = jsonDecode(s) as List;
          var mh = 0.0;
          for (final m in e.whereType<Map>()) { all.add({...m, 'y': numOf(m['y']) + off}); mh = [mh, numOf(m['y']) + numOf(m['h'])].reduce((a, b) => a > b ? a : b); }
          off += (mh < 1000 ? 1000 : mh) + 200;
        }
        lastText = all.whereType<Map>().map((m) => '${m['s']}').join(' ');
        lastEls = all;
        final r = all.isEmpty ? null : OcrParse.parse(all);
        if (r != null) return (rows: r, how: 'ocr');
      } catch (_) {}
    }
    return (rows: await Ai.readUpdatePages(pages, auto: auto), how: 'ai');
  }

  static Future<String> progress() async { try { return await Native.ch.invokeMethod<String>('autoProg') ?? ''; } catch (_) { return ''; } }

  static Future<List<String>> pull({bool force = false}) async {
    if (kIsWeb || Store.I.testMode || (!force && !allOn && groups.isEmpty)) return [];
    if (!force) await sync();
    List items;
    try { if (!force) await Native.ch.invokeMethod('autoRun'); items = jsonDecode(await Native.ch.invokeMethod<String>('autoTake') ?? '[]') as List; } catch (_) { return []; }
    final out = <String>[];
    var logged = false;
    // اللي ما اتقراش المرة اللي فاتت (Gemini كان مش رادد) نحاول تاني
    final pend = ((Store.I.D['pend'] as List?) ?? []).whereType<Map>().toList();
    Store.I.D['pend'] = <dynamic>[];
    for (final it in [...pend, ...items.whereType<Map>()]) {
      List<Obj> rows;
      var how = 'ai', comp = '';
      if (it['ocr'] != null || it['retry'] == true) {
        // 🔍 القراءة على الموبايل نفسه — ولو الجدول مش واضح نسأل Gemini
        final o = it['ocr'] is List ? it['ocr'] as List : (it['ocr'] is String ? (jsonDecode(it['ocr'] as String) as List) : null);
        final local = o == null ? null : OcrParse.parse(o);
        if (o != null) comp = companyFromText(o.whereType<Map>().map((m) => '${m['s']}').join(' '), str(it['g']), o);
        if (local != null) { rows = local; how = 'ocr'; } else {
          try {
            final pages = await _pagesOf(it);
            if (pages.isEmpty) continue;
            rows = await Ai.readUpdatePages(pages, auto: true);
          } catch (_) {
            ((Store.I.D['pend'] as List?) ?? (Store.I.D['pend'] = <dynamic>[])).add({'g': it['g'], 't': it['t'], 'id': it['id'], 'files': it['files'], 'retry': true});
            logged = true;
            continue;
          }
        }
      } else {
        try { rows = Ai.parseRows(str(it['txt'])); } catch (_) { continue; }
      }
      if (rows.isEmpty) continue;
      out.addAll(applyRows(str(it['g']), rows, img: it['files'] == null ? str(it['id']) : '', files: (it['files'] as List?) ?? const [], same: it['same'] == true, how: how, company: comp.isNotEmpty ? comp : str(rows.first['company']).isNotEmpty && companyOf(str(it['g'])).isEmpty ? str(rows.first['company']) : ''));
      logged = true;
    }
    if (logged) await Store.I.save();
    if (out.isNotEmpty) last.value = out;
    return out;
  }
}
