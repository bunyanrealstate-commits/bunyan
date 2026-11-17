/// أبديت الجروبات التلقائي: الجانب بتاع Dart
/// أندرويد (WaListener) بيقرا صور جروبات الشركات المختارة بـ Gemini ويحفظ النتيجة،
/// وهنا بنطبقها على الفيلا الصح (أو نعمل فيلا جديدة) ونسجل اللي اتغير.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ai.dart';
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
    for (final k in ['p1', 'p3', 'mo']) {
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
    if (m == null) { us.add(t); added.add(str(r['no'])); }
    else if (wasAvail == true && t['avail'] == false) { booked.add(str(r['no'])); }
    else if (wasAvail == false && t['avail'] == true) { back.add(str(r['no'])); }
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
  final m = RegExp(r'villa\s*(?:no\.?|#|:|-)?\s*([0-9]+[a-z]?)', caseSensitive: false).firstMatch(s) ?? RegExp(r'فيلا\s*(?:رقم)?\s*([0-9]+)').firstMatch(s);
  if (m != null) return m.group(1)!;
  final all = RegExp(r'[0-9]+').allMatches(s).toList();
  return all.isEmpty ? '' : all.last.group(0)!;
}

/// يلاقي الفيلا من الشركة (بتاعة الجروب) ورقم الفيلا المكتوب في الأبديت — ولو مش موجودة يعملها
Obj? findVilla(String company, Obj meta, {bool create = true}) {
  final no = villaNoOf(str(meta['villa']));
  if (no.isEmpty) return null;
  final comp = company.isNotEmpty ? company : str(meta['company']);
  final c = Store.I.villas.where((v) => nkey(v['no']) == nkey(no) || nkey(villaNoOf('${v['name']} ${v['no']}')) == nkey(no)).toList();
  final hit = c.where((v) => comp.isEmpty || _same(str(v['company']), comp) || _same(str(v['name']), comp) || str(v['company']).isEmpty).toList();
  if (hit.isNotEmpty) { if (str(hit.first['company']).isEmpty && comp.isNotEmpty) hit.first['company'] = comp; return hit.first; }
  if (!create) return null;
  final v = <String, dynamic>{'id': uid(), 'name': comp.isEmpty ? 'فيلا' : comp, 'no': no, 'company': comp, 'area': str(meta['area']), 'loc': '', 'units': <dynamic>[], 'auto': true};
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
  static Future<List<String>> pull() async {
    if (kIsWeb || Store.I.testMode || (!allOn && groups.isEmpty)) return [];
    await sync();
    List items;
    try { await Native.ch.invokeMethod('autoRun'); items = jsonDecode(await Native.ch.invokeMethod<String>('autoTake') ?? '[]') as List; } catch (_) { return []; }
    final out = <String>[];
    var logged = false;
    for (final it in items.whereType<Map>()) {
      final g = str(it['g']);
      List<Obj> rows;
      try { rows = Ai.parseRows(str(it['txt'])); } catch (_) { continue; }
      if (rows.isEmpty) continue;
      final meta = rows.first;
      final good = rows.where((x) => str(x['no']).isNotEmpty || numOf(x['p1']) > 0 || numOf(x['p3']) > 0 || numOf(x['mo']) > 0).toList();
      if (good.isEmpty) continue;
      final v = findVilla(companyOf(g), meta);
      if (v != null && str(meta['terms']).isNotEmpty) v['terms'] = str(meta['terms']);
      final String msg;
      var quiet = it['same'] == true;
      if (quiet) {
        msg = '✓ ${v == null ? g : '${str(v['name'])} ${str(v['no'])}'}: نفس الأبديت — مفيش جديد';
      } else if (v == null) {
        msg = '⚠️ $g: جالي أبديت بس مش عارف رقم الفيلا — ضيفه بإيدك من «من صورة الأبديت»';
      } else {
        final ch = applyUpdate(v, good, auto: true);
        quiet = ch == 'مفيش تغيير'; // نفس الأبديت اتبعت تاني — منزعجكش، بس الصورة بتتسجل
        msg = quiet ? '✓ ${str(v['name'])} ${str(v['no'])}: نفس الأبديت — مفيش جديد' : '${v['auto'] == true && objs(v['units']).length == good.length ? '🆕' : '📥'} ${str(v['name'])} ${str(v['no'])}: $ch${str(v['loc']).isEmpty ? ' • ⚠️ ضيف اللوكيشن' : ''}';
      }
      if (!quiet) out.add(msg);
      final l = (Store.I.D['log'] as List?) ?? (Store.I.D['log'] = <dynamic>[]);
      l.insert(0, {'at': DateTime.now().toIso8601String(), 'g': g, 'm': msg, 'vid': v?['id'], 'img': str(it['id']), 'same': quiet, 'n': good.length});
      while (l.length > 150) { l.removeLast(); }
      logged = true;
    }
    if (logged) await Store.I.save();
    if (out.isNotEmpty) last.value = out;
    return out;
  }
}
