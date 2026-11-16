/// الاستديو (عقد الشركة): إضافة وتعديل — منقول من mUnit في بنيان القديم
import 'dart:math' as math;
import 'js.dart';
import 'engine.dart';

class UnitOps {
  final Obj S; final String Function() uid; final int now; final String td;
  UnitOps(this.S, {required this.uid, required this.now, required this.td});
  Engine get e => Engine(S);
  double sh(Obj u) => e.sh(u);

  List<Map<String, dynamic>> sched({required double total, required double cm, required int nn, double first = 0, String pstart = '', required String start, int paidN = 0}) {
    final k = math.max(1, nn); final cmv = cm > 0 ? cm : 12.0; final r = <Map<String, dynamic>>[];
    if (total == 0 && first == 0) return r;
    final f = first > 0 ? first.round() : (total / k).round(); final rest = k > 1 ? ((total - f) / (k - 1)).round() : 0;
    final p0 = pstart.isNotEmpty ? pstart : start;
    r.add({'d': p0, 'a': f, 'p': false});
    for (var i = 1; i < k; i++) { r.add({'d': iso(addM(pd(p0), (i * cmv / k).round())), 'a': rest, 'p': false}); }
    if (k > 1 && total != 0) { final s = r.fold<num>(0, (a, x) => a + (x['a'] as num)); r[k - 1]['a'] = (r[k - 1]['a'] as num) + (total - s).round(); }
    for (var i = 0; i < math.min(paidN, k); i++) { r[i]['p'] = true; }
    return r;
  }

  void recalcInst(Obj u, dynamic oT, dynamic oC, dynamic oS) {
    final inst = objs(u['inst']); final nn = inst.where((i) => !truthy(i['rn'])).length; if (nn == 0) return;
    if (!same(u['cm'], oC) || u['start'] != oS) {
      final p0 = truthy(u['pstart']) ? str(u['pstart']) : str(u['start']);
      final cm0 = n(u['cm']) - objs(u['renHist']).fold(0.0, (s, h) => s + n0(h['cm']));
      var k = 0;
      for (final i in inst) { if (truthy(i['rn'])) continue; if (!truthy(i['p'])) i['d'] = iso(addM(pd(p0), (k * (cm0 > 0 ? cm0 : n(u['cm'])) / nn).round())); k++; }
    }
    if (!same(u['total'], oT) && n(u['total']) > 0) {
      final paid = inst.where((i) => truthy(i['p'])).fold(0.0, (s, i) => s + n(i['a']));
      final un = inst.where((i) => !truthy(i['p'])).toList(); final rem = math.max(0.0, n(u['total']) - paid);
      if (un.isNotEmpty) { final each = (rem / un.length).floor(); for (final i in un) { i['a'] = each; } un.last['a'] = _num(each + rem - each * un.length); }
      else if (rem > 0) { (u['inst'] as List).add({'d': td, 'a': _num(rem), 'p': false, 'at': 0}); }
    }
  }

  String fsrcOf(Obj u) {
    if (u.containsKey('fsrc') && u['fsrc'] != null) return str(u['fsrc']);
    if (!truthy(u['fp'])) return '';
    if (n0(u['fat']) > 0) return 'cash';
    return objs(S['tx']).any((x) => x['c'] == 'تمويل استديو' && x['w'] == 'تمويل استديو ${str(u['name'])}') ? 'me' : 'old';
  }

  List<dynamic> _l(String k) => (S[k] as List?) ?? (S[k] = <dynamic>[]);

  void setF(Obj u, String a, String b, [double? oldAmt]) {
    final f = sh(u); final amt = n0(u['furn']) * f; final oa = (oldAmt ?? n0(u['furn'])) * f; final tx = _l('tx');
    if (a == 'me' && b == 'me') { if ((amt - oa).abs() >= .5) tx.add({'id': uid(), 'k': 'me', 'd': td, 'w': 'تعديل أثاث ${u['name']}', 'a': _num(oa - amt), 'c': 'تمويل استديو', 'u': u['id']}); }
    else {
      if (a == 'me' && oa != 0) tx.add({'id': uid(), 'k': 'me', 'd': td, 'w': 'إلغاء دفع أثاث ${u['name']} من أموالي الخاصة', 'a': _num(oa), 'c': 'تمويل استديو', 'u': u['id']});
      if (b == 'me' && amt != 0) tx.add({'id': uid(), 'k': 'me', 'd': td, 'w': 'أثاث ${u['name']} من أموالي الخاصة', 'a': _num(-amt), 'c': 'تمويل استديو', 'u': u['id']});
    }
    u['fat'] = b == 'cash' ? ((a == 'cash' && truthy(u['fat'])) ? u['fat'] : now) : 0; u['fsrc'] = b; u['fp'] = b.isNotEmpty;
    // فلوس الشراكة
    if (a == 'gp' || b == 'gp') _gpRm(str(u['g']), 'f${u['id']}');
    if (b == 'gp' && truthy(n0(u['furn']))) _gpPay(str(u['g']), 'f${u['id']}', -n0(u['furn']), 'فرش ${u['name']}');
  }
  void ownMv(Obj u, double d, String w) {
    if (d.abs() < .5) return;
    _l('adj').add({'id': uid(), 'at': now, 'a': _num(d), 'w': 'تمويل $w ${u['name']} من أموالي الخاصة', 'g': str(u['g']), 'u': u['id']});
    _l('tx').add({'id': uid(), 'k': 'me', 'd': td, 'w': '$w ${u['name']} من أموالي الخاصة', 'a': _num(-d), 'c': 'تمويل استديو', 'u': u['id']});
  }
  void ownF(Obj u, double v) {
    final max = u['fsrc'] == 'cash' ? n0(u['furn']) * sh(u) : 0.0; final nn = math.min(math.max(0.0, v), max); final o = n0(u['capF']);
    ownMv(u, nn - o, 'أثاث'); if (nn > 0) { u['capF'] = _num(nn); } else { u.remove('capF'); }
  }
  void ownI(Obj u, double v) {
    final max = objs(u['inst']).where((i) => truthy(i['p']) && n0(i['at']) > 0).fold(0.0, (s, i) => s + n0(i['a'])) * sh(u);
    final nn = math.min(math.max(0.0, v), max); final o = n0(u['capI']); ownMv(u, nn - o, 'دفعات شركة'); u['capI'] = _num(nn);
  }
  void _gpRm(String gid, String key) { final gp = S['gp']; if (gp is! Map || gp[gid] is! List) return; gp[gid] = (gp[gid] as List).where((x) => !(x is Map && x['key'] == key)).toList(); }
  void _gpPay(String gid, String key, double a, String w) {
    if (gid.isEmpty) return; final gp = (S['gp'] as Map?) ?? (S['gp'] = <String, dynamic>{}); if (gp[gid] is! List) gp[gid] = <dynamic>[];
    _gpRm(gid, key); (gp[gid] as List).add({'id': uid(), 'd': td, 'a': _num(a), 'w': w, 'key': key});
  }

  /// o: name,g,company,start,grace,cm,total,furn,salv? + للجديد: pstart,first,mo,n,paidN,src,mx + fsrc,fmx,pmx
  Obj save(String? id, Map<String, dynamic> o) {
    final units = _l('units');
    final src = str(o.remove('src')); final mx = n0(o.remove('mx')); final fmx = n0(o.remove('fmx')); final pmx = o.remove('pmx');
    final fsRaw = o.remove('fsrc'); final fsM = fsRaw == 'mix'; final fs = fsRaw == null ? '' : (fsM ? 'cash' : str(fsRaw));
    o['share'] = 100; o['partner'] = '';
    final u0 = id == null ? null : objs(units).where((x) => x['id'] == id).firstOrNull;
    o['name'] = str(o['name']).trim().isNotEmpty ? str(o['name']).trim() : (u0 != null ? u0['name'] : 'استديو ${units.length + 1}');
    if (u0 != null) {
      final u = u0; final oT = u['total'], oC = u['cm'], oS = u['start'], oF = fsrcOf(u), oA = n0(u['furn']);
      o.forEach((k, v) => u[k] = v);
      recalcInst(u, oT, oC, oS);
      if (!(fs == 'split' && oF == 'split')) { setF(u, oF == 'split' ? '' : oF, fs, oA); ownF(u, fsM ? fmx : 0); }
      if (pmx != null && str(pmx).isNotEmpty) ownI(u, n0(pmx));
      return u;
    }
    if (truthy(o['mo'])) o['n'] = math.max(1, (truthy(o['cm']) ? n(o['cm']) : 12).round());
    o.remove('mo');
    final inst = sched(total: n0(o['total']), cm: n0(o['cm']), nn: n0(o['n']).toInt(), first: n0(o['first']), pstart: str(o['pstart']), start: str(o['start']), paidN: n0(o['paidN']).toInt())
        .map((x) => {...x, 'at': (x['p'] == true && (src == 'cash' || src == 'mix')) ? now : 0}).toList();
    for (final k in ['first', 'n', 'paidN']) { o.remove(k); }
    final nu = <String, dynamic>{'id': uid(), 'inst': inst, 'leases': <dynamic>[], ...o, 'fp': false, 'fat': 0, 'fsrc': ''};
    units.add(nu);
    final f = sh(nu); final pI = inst.where((i) => i['p'] == true).fold<double>(0, (s, i) => s + n(i['a'])) * f;
    final cI = src == 'me' ? pI : (src == 'mix' ? math.min(math.max(0.0, mx), pI) : 0.0);
    nu['capI'] = _num(cI);
    if (src == 'mix' && cI != 0) _l('adj').add({'id': uid(), 'at': now, 'a': _num(cI), 'w': 'تمويل ${nu['name']} من أموالي الخاصة', 'g': str(nu['g']), 'u': nu['id']});
    if (cI != 0) _l('tx').add({'id': uid(), 'k': 'me', 'd': td, 'w': 'دفعات شركة ${nu['name']} من أموالي الخاصة', 'a': _num(-cI), 'c': 'تمويل استديو', 'u': nu['id']});
    setF(nu, '', fs); ownF(nu, fsM ? fmx : 0);
    return nu;
  }

  static num _num(double v) => v == v.roundToDouble() && v.abs() < 9e15 ? v.toInt() : v;
}
