import 'model.dart';
import 'native.dart';
import 'reqs.dart';
import 'store.dart';

/// 🏷️ سكرين من ليبل في واتساب الأعمال (Studio empty / 1bhk …) → عملاء
/// كل شات: سطر الاسم (وجنبه الساعة) ← آخر رسالة ← الليبل بحروف كابيتال
class LabelShots {
  static final _tag = RegExp(r'studio|bhk|\bbed|room|partition|hall|fur|empty|\d\s*b\b', caseSensitive: false);
  static final _time = RegExp(r'\b\d{1,2}:\d{2}\b');

  static List<List<Map>> _lines(List els) {
    final es = els.whereType<Map>().where((m) => '${m['s']}'.trim().isNotEmpty).toList()
      ..sort((a, b) => (numOf(a['y']) + numOf(a['h']) / 2).compareTo(numOf(b['y']) + numOf(b['h']) / 2));
    final out = <List<Map>>[];
    for (final e in es) {
      final cy = numOf(e['y']) + numOf(e['h']) / 2;
      final l = out.isEmpty ? null : out.last;
      if (l != null) {
        final ly = l.map((x) => numOf(x['y']) + numOf(x['h']) / 2).reduce((a, b) => a + b) / l.length;
        final lh = l.map((x) => numOf(x['h'])).reduce((a, b) => a < b ? a : b);
        if ((cy - ly).abs() < (numOf(e['h']) < lh ? numOf(e['h']) : lh) * .6) { l.add(e); continue; }
      }
      out.add([e]);
    }
    for (final l in out) { l.sort((a, b) => numOf(a['x']).compareTo(numOf(b['x']))); }
    return out;
  }

  static String _t(List<Map> l) => l.map((m) => '${m['s']}').join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _isTag(String t) {
    final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '');
    return letters.length >= 3 && letters == letters.toUpperCase() && _tag.hasMatch(t) && t.length <= 24 && !_time.hasMatch(t) && !t.contains('+');
  }

  /// [{title, label}] — title = اسم الشات زي ما الواتساب كاتبه (الحروف العربي مبتتقريش)
  static List<Map<String, String>> parse(List els) {
    final ls = _lines(els).map(_t).where((t) => t.isNotEmpty).toList();
    final out = <Map<String, String>>[];
    var start = 0;
    for (var i = 0; i < ls.length; i++) {
      if (!_isTag(ls[i])) continue;
      final block = ls.sublist(start, i);
      start = i + 1;
      // سطر الاسم هو اللي جنبه الساعة
      var title = block.lastWhere((t) => _time.hasMatch(t), orElse: () => '');
      title = title.replaceAll(_time, '').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (title.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length < 3) continue;
      out.add({'title': title, 'label': ls[i]});
    }
    return out;
  }

  static String _k(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// يضيف العملاء: الرقم مكتوب → على طول، الاسم مكتوب → ندوّر عليه في جهات الاتصال
  static Future<({int added, int found, List<String> missed})> importAll(List<Map<String, String>> items, List<Map<String, String>> contacts) async {
    final have = Reqs.all.map((r) => str(r['p'])).where((p) => p.isNotEmpty).toSet();
    var n = 0;
    final missed = <String>[];
    for (final it in items) {
      final title = it['title']!, label = it['label']!;
      final digits = title.replaceAll(RegExp(r'[^\d]'), '');
      final hits = <Map<String, String>>[];
      if (title.startsWith('+') || (digits.length >= 9 && digits.length >= title.replaceAll(' ', '').length - 2)) {
        hits.add({'n': '', 'p': Native.phone(digits)});
      } else {
        final k = _k(title);
        hits.addAll(contacts.where((c) => k.length >= 4 && _k(c['n'] ?? '').contains(k)));
      }
      if (hits.isEmpty) { missed.add(title); continue; }
      for (final c in hits) {
        final ph = c['p'] ?? '';
        if (ph.isEmpty) continue;
        final cn = (c['n'] ?? '').isNotEmpty ? c['n']! : title;
        final q = parseRequest('$label $cn');
        final old = Reqs.all.where((r) => str(r['p']) == ph).firstOrNull;
        if (old != null) {
          // موجود: الليبل يكمّل اللي ناقص (النوع / مفروش ولا لأ)
          if (((old['types'] as List?) ?? []).isEmpty) old['types'] = q['types'];
          if (old['fur'] == null && q['fur'] != null) old['fur'] = q['fur'];
          old['label'] = label;
          continue;
        }
        if (have.contains(ph)) continue;
        final p = parseContactName(cn);
        final r = Reqs.add(name: str(p?['name']).isNotEmpty ? str(p!['name']) : (c['n'] ?? '').isNotEmpty ? cn : '', phone: ph, text: '$label • $cn');
        for (final k in ['types', 'fur']) { if (q[k] != null) r[k] = q[k]; }
        if (numOf(r['budget']) == 0 && numOf(q['budget']) > 0) r['budget'] = q['budget'];
        r['cn'] = cn; r['label'] = label; r['st'] = 'wait'; r['src'] = 'label';
        r['seen'] = [for (final x in Reqs.matches(r)) Reqs.key(x['v'] as Obj, x['u'] as Obj)];
        have.add(ph); n++;
      }
    }
    await Store.I.save();
    return (added: n, found: items.length, missed: missed);
  }
}
