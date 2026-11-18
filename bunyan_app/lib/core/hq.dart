/// 📖 الأحاديث والرقائق — نفس hdx3js في بنيان القديم:
/// منتقيات + رياض الصالحين + القرآن وكتب الحديث (الصحيح والحسن) + أقوال السلف والرقائق وطبقات الصوفية
/// بتظهر مرة كل ساعة بس (لما تفتح أو ترجع للتطبيق بعد ساعة)، وبتبدّل بين حديث وقول
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HQItem { final String id, t, s, k; HQItem(this.id, this.t, this.s, this.k); }

class HQ {
  static const _web = 'https://bunyanrealstate-commits.github.io/bunyan/';
  static const gap = Duration(hours: 1);
  static const books = ['quran', 'bukhari', 'muslim', 'nasai', 'abudawud', 'tirmidhi', 'ibnmajah', 'malik', 'nawawi', 'qudsi'];
  /// اللي ظاهر دلوقتي على الشاشة (null = مخفي)
  static final cur = ValueNotifier<HQItem?>(null);

  static List _h = [], _q = [];
  static Map? _riyad, salaf;
  static final Map<String, Map> _bk = {};
  static bool _started = false;
  static final _r = math.Random();

  static String _hk(String t) { var x = 0; for (final c in t.codeUnits) { x = (x * 31 + c) & 0xFFFFFFFF; } return x.toRadixString(36); }

  static Future<String?> _get(String name) async {
    // نسخة محفوظة على الجهاز أولاً
    if (!kIsWeb) {
      try { final f = File('${(await getApplicationDocumentsDirectory()).path}/hq_${name.replaceAll('/', '_')}'); if (await f.exists()) return await f.readAsString(); } catch (_) {}
    }
    final urls = kIsWeb ? [Uri.base.resolve('../$name').toString(), '$_web$name'] : ['$_web$name'];
    for (final u in urls) {
      try {
        final r = await http.get(Uri.parse(u)).timeout(const Duration(seconds: 60));
        if (r.statusCode != 200) continue;
        final t = utf8.decode(r.bodyBytes);
        if (!kIsWeb) { try { await File('${(await getApplicationDocumentsDirectory()).path}/hq_${name.replaceAll('/', '_')}').writeAsString(t); } catch (_) {} }
        return t;
      } catch (_) {}
    }
    return null;
  }

  /// بيتحمّل في الخلفية: المنتقيات فوراً، وبعدين رياض الصالحين والرقائق وطبقات الصوفية، وبعدين الكتب كتاب كتاب
  static Future<void> start() async {
    if (_started) return; _started = true;
    try { final d = jsonDecode(await rootBundle.loadString('assets/hq.json')); _h = d['h']; _q = List.of(d['q']); } catch (_) {}
    Future(() async {
      try { final t = await _get('hadith.json'); if (t != null) _riyad = jsonDecode(t); } catch (_) {}
      try {
        final t = await _get('raqaiq.json');
        if (t != null) { final d = jsonDecode(t); final have = {for (final q in _q) _hk(q[0].toString().replaceAll(RegExp('[«»]'), ''))};
          for (final x in d['q'] as List) { if (!have.add(_hk(x[0]))) continue; final n = d['n'][x[1]], h = d['h'][x[1]];
            _q.add([x[2] == 1 ? x[0] : '«${x[0]}»', n, h, '📜 من أخبار $n $h', d['s'][x[3]], x[4]]); } }
      } catch (_) {}
      try {
        final t = await _get('salaf.json');
        if (t != null) { final d = jsonDecode(t) as Map; salaf = d; final have = {for (final q in _q) q[0].toString().replaceAll(RegExp('[«»]'), '').substring(0, math.min(40, q[0].toString().replaceAll(RegExp('[«»]'), '').length))};
          for (final p in d['p'] as List) { for (final x in p['q'] as List) { final s = x[0] as String; final k = s.substring(0, math.min(40, s.length)); if (s.length > 900 || !have.add(k)) continue;
            _q.add([x[1] == 1 ? s : '«$s»', p['n'], 'رحمه الله', '📜 من أخبار ${p['n']} رحمه الله', d['s'][x[2]], 1]); } } }
      } catch (_) {}
      for (final b in books) {
        try { final t = await _get('hd/$b.json'); if (t != null) _bk[b] = jsonDecode(t); } catch (_) {}
        await Future.delayed(const Duration(seconds: 20));
      }
    });
  }

  static Map<String, List<HQItem>> _pool() {
    final P = <String, List<HQItem>>{};
    _bk.forEach((b, d) { final k = '📖 ${d['n']}'; P[k] = [for (final h in d['h'] as List) HQItem('${b.substring(0, 3)}${h[1]}', h[0], '${d['n']} (${h[1]})', k)]; });
    for (final h in _h) { (P['منتقيات'] ??= []).add(HQItem('c${_hk(h[0])}', '«${h[0]}»', h[1], 'قال رسول الله ﷺ')); }
    final R = _riyad;
    if (R != null) { final hs = R['h'] as List; for (var i = 0; i < hs.length; i++) { final h = hs[i]; final kk = (R['k'] as List).length > h[2] ? R['k'][h[2]] : 'رياض الصالحين'; (P[kk] ??= []).add(HQItem('r$i', h[0], '${h[1]} — رياض الصالحين', '📖 $kk')); } }
    return P;
  }

  static HQItem? _pickQ(SharedPreferences p) {
    if (_q.isEmpty) return null;
    final seen = (p.getStringList('hq_qseen') ?? []).toSet();
    var L = [for (var i = 0; i < _q.length; i++) if (!seen.contains('q${_hk(_q[i][0])}')) i];
    if (L.isEmpty) { seen.clear(); L = [for (var i = 0; i < _q.length; i++) i]; }
    final pr = L.where((i) => _q[i].length > 5 && _q[i][5] == 1).toList();
    if (pr.isNotEmpty && _r.nextDouble() < .7) L = pr;
    final q = _q[L[_r.nextInt(L.length)]]; final id = 'q${_hk(q[0])}';
    seen.add(id); p.setStringList('hq_qseen', seen.toList());
    return q.length > 3 && q[3] != null && q[3] != '' ? HQItem(id, q[0], q.length > 4 ? (q[4] ?? '') : '', q[3]) : HQItem(id, '«${q[0]}»', '', '💬 قال ${q[1]} ${q[2]}');
  }

  static HQItem? _pickH(SharedPreferences p) {
    final P = _pool(); if (P.isEmpty) return null;
    final seen = (p.getStringList('hq_hseen') ?? []).toSet(); final last = p.getString('hq_last') ?? '', lastK = p.getString('hq_lk') ?? '';
    Map<String, List<HQItem>> av(bool useSeen) => {for (final e in P.entries) if (e.value.any((o) => (!useSeen || !seen.contains(o.id)) && o.id != last)) e.key: e.value.where((o) => (!useSeen || !seen.contains(o.id)) && o.id != last).toList()};
    var L = av(true); if (L.isEmpty) { seen.clear(); L = av(false); }
    var ks = L.keys.toList(); if (ks.length > 1) ks = ks.where((k) => k != lastK).toList();
    final k = ks[_r.nextInt(ks.length)], l = L[k]!, o = l[_r.nextInt(l.length)];
    seen.add(o.id); final sl = seen.toList(); p.setStringList('hq_hseen', sl.length > 6000 ? sl.sublist(sl.length - 6000) : sl);
    p.setString('hq_last', o.id); p.setString('hq_lk', k);
    return o;
  }

  /// حديث مرة وقول مرة (زي القديم)
  static Future<HQItem?> pick() async {
    final p = await SharedPreferences.getInstance();
    final nx = (p.getString('hq_alt') ?? 'h') == 'h' ? 'q' : 'h'; await p.setString('hq_alt', nx);
    return (nx == 'q' ? _pickQ(p) : _pickH(p)) ?? _pickH(p) ?? _pickQ(p);
  }

  /// يظهر لو عدّت ساعة من آخر مرة
  static Future<void> maybeShow({bool force = false}) async {
    await start();
    final p = await SharedPreferences.getInstance(); final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - (p.getInt('hq_t') ?? 0) < gap.inMilliseconds) return;
    await p.setInt('hq_t', now);
    final o = await pick(); if (o != null) cur.value = o;
  }

  static void hide() => cur.value = null;
}
