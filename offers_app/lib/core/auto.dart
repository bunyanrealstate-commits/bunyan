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
String applyUpdate(Obj v, List<Obj> rows, {bool missingBooked = true}) {
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
  if (missingBooked) { for (final u in missing) { u['avail'] = false; booked.add(str(u['no'])); } }
  final d = DateTime.now();
  v['upd'] = '${d.day}/${d.month}';
  final o = <String>[];
  if (booked.isNotEmpty) o.add('اتحجزت: ${booked.join('، ')}');
  if (added.isNotEmpty) o.add('جديدة: ${added.join('، ')}');
  if (back.isNotEmpty) o.add('رجعت متاحة: ${back.join('، ')}');
  if (price.isNotEmpty) o.add('السعر: ${price.join('، ')}');
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
  static Map<String, String> get groups => ((Store.I.cfg['groups'] as Map?) ?? {}).map((k, v) => MapEntry('$k', '$v'));

  static Future<void> sync() async {
    if (kIsWeb || Store.I.testMode) return;
    try { await Native.ch.invokeMethod('autoCfg', {'key': Store.I.gemKey, 'prompt': Ai.autoPrompt, 'groups': groups.keys.toList()}); } catch (_) {}
  }

  static Future<bool> on() async { if (kIsWeb) return false; try { return await Native.ch.invokeMethod<bool>('notifOn') ?? false; } catch (_) { return false; } }

  /// الجروبات اللي الواتساب بعت منها إشعارات: {اسم: {at, img}}
  static Future<Map<String, Map>> seen() async {
    if (kIsWeb) return {};
    try { return (jsonDecode(await Native.ch.invokeMethod<String>('autoSeen') ?? '{}') as Map).map((k, v) => MapEntry('$k', v as Map)); } catch (_) { return {}; }
  }

  static List<Obj> get log => objs(Store.I.D['log']);

  /// يقرا اللي اتجمع ويطبقه — بيرجع رسايل قصيرة باللي اتغير
  static Future<List<String>> pull() async {
    if (kIsWeb || Store.I.testMode || groups.isEmpty) return [];
    await sync();
    List items;
    try { await Native.ch.invokeMethod('autoRun'); items = jsonDecode(await Native.ch.invokeMethod<String>('autoTake') ?? '[]') as List; } catch (_) { return []; }
    final out = <String>[];
    for (final it in items.whereType<Map>()) {
      final g = str(it['g']);
      List<Obj> rows;
      try { rows = Ai.parseRows(str(it['txt'])); } catch (_) { continue; }
      if (rows.isEmpty) continue;
      final meta = rows.first;
      final good = rows.where((x) => str(x['no']).isNotEmpty || numOf(x['p1']) > 0 || numOf(x['p3']) > 0 || numOf(x['mo']) > 0).toList();
      if (good.isEmpty) continue;
      final v = findVilla(groups[g] ?? '', meta);
      final String msg;
      if (v == null) {
        msg = '⚠️ $g: جالي أبديت بس مش عارف رقم الفيلا — ضيفه بإيدك من «من صورة الأبديت»';
      } else {
        final ch = applyUpdate(v, good);
        msg = '${v['auto'] == true && objs(v['units']).length == good.length ? '🆕' : '📥'} ${str(v['name'])} ${str(v['no'])}: $ch${str(v['loc']).isEmpty ? ' • ⚠️ ضيف اللوكيشن' : ''}';
      }
      out.add(msg);
      final l = (Store.I.D['log'] as List?) ?? (Store.I.D['log'] = <dynamic>[]);
      l.insert(0, {'at': DateTime.now().toIso8601String(), 'g': g, 'm': msg, 'vid': v?['id']});
      while (l.length > 60) { l.removeLast(); }
    }
    if (out.isNotEmpty) { await Store.I.save(); last.value = out; }
    return out;
  }
}
