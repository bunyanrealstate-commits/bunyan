/// عقد المستأجر: بناء جدول الدفعات وحفظ العقد — منقول من mLeaseN/lnSave في بنيان القديم
import 'dart:math' as math;
import 'js.dart';
import 'engine.dart';

class LeaseB {
  static DateTime mk(int y, int m0, int p) { final last = DateTime(y, m0 + 2, 0).day; return DateTime(y, m0 + 1, math.min(p, last)); } // m0 = شهر JS (0-11)
  static DateTime addMo(DateTime d, int n) { final x = DateTime(d.year, d.month + n, 1); return mk(x.year, x.month - 1, d.day); }
  static DateTime endOf(DateTime s, double c) {
    final w = (c + 1e-9).floor(); final fr = c - w; var e = addMo(s, w);
    if (fr > 1e-6) e = DateTime(e.year, e.month, e.day + (fr * 30).round());
    return e;
  }
  static DateTime firstDate(DateTime s, double m0, int p) {
    final w = (m0 + 1e-9).floor(); final fr = m0 - w; var tg = addMo(s, w);
    if (fr > 1e-6) tg = DateTime(tg.year, tg.month, tg.day + (fr * 30).round());
    DateTime? best; var bd = 1e18;
    for (var o = -1; o <= 1; o++) {
      final c = mk(tg.year, tg.month - 1 + o, p);
      if (!c.isAfter(s)) continue;
      final df = (ms(c) - ms(tg)).abs().toDouble();
      if (df <= bd) { bd = df; best = c; }
    }
    return best ?? mk(s.year, s.month, p);
  }
  static double sugM(DateTime s, int p) {
    final t = addMo(s, 1); final c = firstDate(s, 1, p);
    var m = 1 + ((ms(c) - ms(t)) / 864e5).round() / 30; final h = (m * 2).round() / 2;
    if ((m - h).abs() * 30 <= 1.2) m = h;
    return (m * 100).round() / 100;
  }
  static int payDay(String start, dynamic day) { final s = pd(start); final d = n(day); return (d >= 1 && d <= 31) ? d.round() : s.day; }

  /// الجدول: [{d,a}]
  static List<Map<String, dynamic>> build({required String start, required double cmo, required double rent, dynamic day, double m0 = 1}) {
    final s = pd(start); final p = payDay(start, day); final end = endOf(s, cmo);
    final total = (rent * cmo).round(); final mm = m0 > 0 ? m0 : 1.0;
    final rows = <Map<String, dynamic>>[{'d': iso(s), 'a': (rent * mm).round()}];
    var d = firstDate(s, mm, p); var k = 0;
    while (d.isBefore(end) && k < 240) {
      rows.add({'d': iso(d), 'a': rent.round()}); k++;
      final nx = DateTime(d.year, d.month + 1, 1); d = mk(nx.year, nx.month - 1, p);
    }
    while (rows.length > 1) {
      var sum = 0; for (var i = 0; i < rows.length - 1; i++) { sum += rows[i]['a'] as int; }
      final rem = total - sum; if (rem > 0) { rows.last['a'] = rem; break; }
      rows.removeLast();
    }
    if (rows.length == 1) rows[0]['a'] = math.min(rows[0]['a'] as int, total);
    return rows;
  }
}

/// صف في جدول الدفعات أثناء التعديل
class LRow { String d; num a; String no; int oi; bool lock; bool first; LRow(this.d, this.a, {this.no = '', this.oi = -1, this.lock = false, this.first = false}); }

class LeaseForm {
  String tenant = '', phone = '', start = '', day = '', pm0 = 'cash', cno = '', dk = '', dno = '', tid = '', nat = '';
  double cmo = 6, rent = 0, m0 = 1, fee = 0; double? da;
  bool chqOn = true, firstPaid = true;
  List<LRow> rows = [];
  bool f0chg = false;
}

class LeaseSave {
  /// نفس شروط lnSave0 — بيرجع رسالة خطأ أو null
  static String? validate(LeaseForm f, {required bool edit}) {
    if (f.start.isEmpty) return 'اكتب تاريخ بداية العقد';
    if (!(f.rent > 0)) return 'اكتب الإيجار الشهري';
    if (!(f.cmo > 0)) return 'اكتب مدة العقد بالشهور';
    if (f.rows.isEmpty) return 'جدول الدفعات فاضي';
    for (var i = 0; i < f.rows.length; i++) { if (f.rows[i].d.isEmpty) return 'الدفعة ${i + 1} بدون تاريخ'; if (!(f.rows[i].a > 0)) return 'الدفعة ${i + 1} بدون مبلغ'; }
    if (!edit) {
      final fr = f.rows.where((r) => r.first).firstOrNull ?? f.rows[0];
      if (!f.firstPaid) return 'العقد لا يتم إلا بعد استلام إيجار شهر على الأقل — علّم "تم استلام الدفعة الأولى الآن"';
      if (fr.a + 0.5 < f.rent) return 'الدفعة الأولى لازم تكون إيجار شهر على الأقل';
    }
    return null;
  }

  static bool chqOK(LeaseForm f, LRow r) => f.chqOn && !r.lock && !(r.first && f.firstPaid && f.pm0 != 'chq');

  /// بيحفظ العقد في الوحدة ويرجع العقد. S = كل البيانات
  static Obj save(Obj S, Obj u, int? k, LeaseForm f, {required String Function() uid, required int now}) {
    final edit = k != null;
    final rows = [...f.rows];
    final idx = {for (var i = 0; i < rows.length; i++) rows[i]: i};
    rows.sort((a, b) { final c = a.d.compareTo(b.d); return c != 0 ? c : idx[a]!.compareTo(idx[b]!); });
    final f0 = (edit && f.f0chg && f.rows.isNotEmpty && f.rows[0].lock) ? {'oi': f.rows[0].oi, 'a': f.rows[0].a} : null;
    final leases = (u['leases'] as List?) ?? (u['leases'] = <dynamic>[]);
    final Obj L = edit ? (leases[k] as Obj) : <String, dynamic>{'id': uid(), 'rcv': <dynamic>[], 'rat': <String, dynamic>{}, 'rav': <String, dynamic>{}, 'pp': <dynamic>[]};
    if (edit) {
      final m = <int, int>{}; for (var ni = 0; ni < rows.length; ni++) { if (rows[ni].oi >= 0) m[rows[ni].oi] = ni; }
      final rcv = <int>[]; final rat = <String, dynamic>{}, rav = <String, dynamic>{}, ov = <String, dynamic>{}; final pp = <dynamic>[];
      for (final i in Engine.rcv(L)) { final ni = m[i]; if (ni != null) { rcv.add(ni); final ra = idx_(L['rat'], i); if (ra != null) rat['$ni'] = ra; final rv = idx_(L['rav'], i); if (rv != null) rav['$ni'] = rv; } }
      (obj(L['ov']) ?? {}).forEach((q, v) { final ni = m[int.tryParse(q) ?? -1]; if (ni != null) ov['$ni'] = v; });
      for (final x in objs(L['pp'])) { final ni = m[n(x['i']).toInt()]; if (ni != null) pp.add({'i': ni, 'a': x['a'], 'at': x['at']}); }
      rcv.sort(); L['rcv'] = rcv; L['rat'] = rat; L['rav'] = rav; L['ov'] = ov; L['pp'] = pp;
    }
    final s = pd(f.start); var end = LeaseB.endOf(s, f.cmo); final last = pd(rows.last.d);
    if (!last.isBefore(end)) end = LeaseB.addMo(last, 1);
    L['tenant'] = f.tenant.trim(); L['phone'] = f.phone.trim(); L['start'] = f.start; L['rent'] = _num(f.rent);
    L['day'] = LeaseB.payDay(f.start, f.day); L['cmo'] = _num(f.cmo); L['end'] = iso(end);
    L['sch'] = [for (final r in rows) {'d': r.d, 'a': r.a}]; L['months'] = rows.length; L['orig'] = rows.length; L['xd'] = 0; L['sh'] = 0; L['exit'] = truthy(L['exit']) ? L['exit'] : '';
    for (final q in ['stub', 'stubx', 'shv', 'advm', 'stubd']) { L.remove(q); }
    final fee = math.max(0.0, f.fee); final was = n0(L['adv']);
    L['adv'] = _num(fee); L['fee'] = fee > 0 ? 1 : 0; L['advat'] = fee > 0 ? ((was > 0 && truthy(L['advat'])) ? L['advat'] : now) : 0;
    List<Map<String, dynamic>> chqs() => [for (final r in rows) if (chqOK(f, r)) {'no': r.no.trim(), 'd': r.d, 'a': r.a}];
    if (!edit) {
      L['pm0'] = f.pm0; L['cno'] = f.cno.trim();
      if (f.firstPaid) { var fi = rows.indexWhere((r) => r.first); if (fi < 0) fi = 0; L['rcv'] = [fi]; (L['rat'] as Map)['$fi'] = now; (L['rav'] as Map)['$fi'] = rows[fi].a; }
      L['chq'] = f.chqOn ? chqs() : [];
    } else if (f.chqOn) { L['cno'] = f.cno.trim(); L['chq'] = chqs(); }
    if (f.tid.isNotEmpty) L['tid'] = f.tid; if (f.nat.isNotEmpty) L['nat'] = f.nat;
    if (!edit) leases.add(L);
    // التأمين المسترد
    final dep = (S['dep'] as List?) ?? (S['dep'] = <dynamic>[]);
    Obj? d = objs(dep).where((x) => x['lid'] == L['id'] && !truthy(x['r'])).firstOrNull ?? objs(dep).where((x) => x['lid'] == L['id']).firstOrNull;
    final mode = f.dk; final amt = (f.da ?? 0) > 0 ? f.da! : n(L['rent']);
    if (mode.isEmpty) { if (d != null && !truthy(d['r'])) dep.remove(d); }
    else if (d != null && !truthy(d['r'])) {
      final wa = truthy(d['mode']) ? str(d['mode']) : 'cash';
      d['mode'] = mode; d['a'] = _num(amt); d['no'] = f.dno.trim(); d['w'] = str(L['tenant']).isEmpty ? d['w'] : L['tenant'];
      if (mode == 'chq') { d['at'] = 0; d['rat'] = 0; } else if (wa == 'chq') { d['at'] = now; }
    } else if (d == null) {
      dep.add({'k': 't', 'w': str(L['tenant']).isEmpty ? 'مستأجر' : L['tenant'], 'a': _num(amt), 'd': L['start'], 'r': '', 'mode': mode, 'no': f.dno.trim(), 'lid': L['id'], 'uid': u['id'], 'at': mode == 'cash' ? now : 0, 'rat': 0});
    }
    if (f0 != null) { var ni = -1; for (var j = 0; j < rows.length; j++) { if (rows[j].oi == f0['oi']) ni = j; } if (ni >= 0 && Engine.rcv(L).contains(ni)) { (L['rav'] as Map)['$ni'] = f0['a']; } }
    return L;
  }

  static dynamic idx_(dynamic m, int i) => idx(m, i);
  static num _num(double v) => v == v.roundToDouble() && v.abs() < 9e15 ? v.toInt() : v;
}
