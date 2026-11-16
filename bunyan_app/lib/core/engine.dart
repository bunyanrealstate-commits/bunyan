/// محرك الحسابات — منقول سطر بسطر من بنيان (JavaScript) علشان الأرقام تطلع زي ما هي بالظبط.
/// كل دالة هنا ليها نفس اسم الدالة الأصلية.
import 'dart:math' as math;
import 'js.dart';

class Engine {
  Obj S;
  /// المجموعة المختارة: 'all' أو '-' (بدون مجموعة) أو id المجموعة
  String WS;
  Engine(this.S, {this.WS = 'all'});

  List<Obj> get units => objs(S['units']);

  /* ───── المجموعات والنِسب ───── */
  double shR(dynamic id) {
    final g = objs(S['groups']).where((x) => x['id'] == id).firstOrNull;
    if (g == null || !(n(g['share']) > 0)) return 1;
    final gn = truthy(g['n']) ? n(g['n']) : 1.0;
    return (!truthy(g['custom']) && gn > 1) ? 1 / n(g['n']) : n(g['share']) / 100;
  }
  double shg(dynamic id) => S['pmode'] == 'me' ? shR(id) : 1;
  double sh(Obj u) => shg(u['g']);

  bool inW(Obj u) => WS == 'all' || (WS == '-' ? !truthy(u['g']) : str(u['g']) == WS);
  Obj? U(dynamic id) => units.where((x) => x['id'] == id).firstOrNull;
  bool inE(Obj x) {
    if (truthy(x['u'])) { final u = U(x['u']); return u != null ? inW(u) : false; }
    return WS == 'all' || (WS == '-' ? !truthy(x['g']) : str(x['g']) == WS);
  }
  List<Obj> SU() => units.where(inW).toList();
  List<Obj> SE() => objs(S['exp']).where(inE).toList();

  static double isumOf(Obj u) => objs(u['inst']).fold(0.0, (s, i) => s + n0(i['a']));

  /* ───── عقود الإيجار ───── */
  static int months(Obj L) => n0(L['months']).toInt();
  static List<Obj> sch(Obj L) => objs(L['sch']);
  static bool hasSch(Obj L) => truthy(L['sch']);
  static double schA(Obj L, int i) { final s = sch(L); return i >= 0 && i < s.length ? n0(s[i]['a']) : 0; }
  static double schF(Obj L, int i) { final b = n0(L['rent']) + n0(L['inet']); return b > 0 ? schA(L, i) / b : 1; }
  static DateTime schD(Obj L, int i) { final s = sch(L); if (s.isEmpty) return pd(L['start']); return pd(s[math.max(0, math.min(i, s.length - 1))]['d']); }
  static DateTime schE(Obj L) {
    final s = sch(L);
    if (months(L) < s.length) return pd(s[months(L)]['d']);
    if (truthy(L['end'])) return pd(L['end']);
    final x = s.isNotEmpty ? s.last : null; final d = x != null ? pd(x['d']) : pd(L['start']);
    return DateTime(d.year, d.month, d.day + 30);
  }
  static bool xdLast(Obj L) => n(L['xd']) > 0 && same(L['orig'], L['months']);
  static double lf(Obj L, int i) => hasSch(L) ? schF(L, i) : ((xdLast(L) && i == months(L) - 1) ? math.min(1.0, n(L['xd']) / 30) : 1.0);
  static double la(Obj L, int i) {
    final ov = idx(L['ov'], i);
    if (truthy(L['ov']) && ov != null) return n(ov);
    return hasSch(L) ? schA(L, i) : (n0(L['rent']) + n0(L['inet'])) * lf(L, i);
  }
  static double lm(Obj L) { var q = 0.0; for (var i = 0; i < months(L); i++) { q += lf(L, i); } return q; }
  static DateTime lend(Obj L) {
    if (hasSch(L)) return schE(L);
    var e = addM(pd(L['start']), xdLast(L) ? months(L) - 1 : months(L));
    if (xdLast(L)) e = DateTime(e.year, e.month, e.day + n(L['xd']).toInt());
    return e;
  }
  static DateTime payD(Obj L, int i) {
    if (hasSch(L)) return schD(L, i);
    if (truthy(L['stubx']) && truthy(L['shv']) && i == 0) return pd(L['start']);
    final s = pd(L['start']); final y = s.year; final m = s.month - 1 + i + n0(L['sh']).toInt();
    final last = DateTime(y, m + 2, 0).day;
    return DateTime(y, m + 1, math.min(truthy(L['day']) ? n(L['day']).toInt() : s.day, last));
  }
  static double ppA(Obj L, int i) => objs(L['pp']).fold(0.0, (s, x) => s + (same(x['i'], i) ? n0(x['a']) : 0));
  static double ppT(Obj L) => objs(L['pp']).fold(0.0, (s, x) => s + n0(x['a']));
  static List<int> rcv(Obj L) => lst(L['rcv']).map((e) => n(e).toInt()).toList();
  static double rv(Obj L, int i) { final r = idx(L['rav'], i); return (truthy(L['rav']) && r != null) ? n(r) : la(L, i); }
  static double furMo(Obj u) { var m = 0.0; for (final L in objs(u['leases'])) { for (final i in rcv(L)) { if (i < months(L)) m += lf(L, i); } } return m; }

  /* ───── الكاش ───── */
  double cashBase() {
    final gc = obj(S['gc']) ?? {};
    if (WS == 'all') return n0(S['cash']) + gc.values.fold(0.0, (s, x) => s + n(x));
    return WS == '-' ? n0(S['cash']) : n0(gc[WS]);
  }

  /// كل الحركات اللي حصلت بعد لحظة ot (mine = نصيبي بس)
  double mvO(num ot, [bool mine = false]) {
    final od = iso(DateTime.fromMillisecondsSinceEpoch(ot.toInt())); final t = today(); var c = 0.0;
    for (final u in SU()) {
      final f = mine ? shR(u['g']) : 1.0;
      for (final i in objs(u['inst'])) { if (truthy(i['p']) && n0(i['at']) > ot) c -= n(i['a']) * f; }
      if (truthy(u['fp']) && n0(u['fat']) > ot) c -= n0(u['furn']) * f;
      for (final L in objs(u['leases'])) {
        for (final i in rcv(L)) { if (n0(idx(L['rat'], i)) > ot) { final r = idx(L['rav'], i); c += (r != null ? n(r) : la(L, i)) * f; } }
        if (truthy(L['penp']) && n0(L['pat']) > ot) c += n0(L['pen']) * f;
        if (truthy(L['adv']) && n0(L['advat']) > ot) c += n(L['adv']) * f;
        for (final x in objs(L['pp'])) { if (n0(x['at']) > ot) c += n0(x['a']) * f; }
        if (truthy(L['icost'])) { for (var i = 0; i < months(L); i++) { final d = payD(L, i); if (!d.isAfter(t) && iso(d).compareTo(od) > 0) c -= n(L['icost']) * lf(L, i) * f; } }
        if (truthy(L['rme']) && truthy(L['router']) && !pd(L['start']).isAfter(t) && str(L['start']).compareTo(od) > 0) c -= n(L['router']) * f;
      }
    }
    for (final x in SE()) {
      final un = truthy(x['u']) ? U(x['u']) : null;
      final f = mine ? (un != null ? shR(un['g']) : shR(x['g'])) : 1.0;
      final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1;
      for (var i = 0; i < cnt; i++) { final d = addM(pd(x['d']), i); if (!d.isAfter(t) && iso(d).compareTo(od) > 0) c -= n(x['a']) * f; }
    }
    if (WS == 'all' || WS == '-') {
      for (final x in objs(S['dep'])) {
        if (x['mode'] == 'chq') continue;
        final s = x['k'] == 't' ? 1 : -1; final a = n0(x['a']);
        if (n0(x['at']) > ot) c += s * a;
        if (truthy(x['r']) && n0(x['rat']) > ot) c -= s * a;
      }
    }
    for (final a in objs(S['adj'])) {
      if (n(a['at']) > ot && (WS == 'all' || str(a['g']) == (WS == '-' ? '' : WS))) c += n(a['a']);
    }
    return c;
  }
  double cashNow() => cashBase() + mvO(0);

  /* ───── الربح على الإيجار المقبوض ───── */
  Map<String, double> rcvP() {
    final t = today(); var rev = 0.0, cost = 0.0, mo = 0.0;
    for (final u in SU()) {
      final f = sh(u); final cm = truthy(u['cm']) ? n(u['cm']) : 1.0;
      final mc = ((truthy(u['total']) ? n(u['total']) : isumOf(u)) + n0(u['furn'])) / cm;
      if (!addM(pd(u['start']), cm).isAfter(t)) cost -= n0(u['salv']) * f;
      for (final L in objs(u['leases'])) {
        for (final i in rcv(L)) {
          if (i >= months(L)) continue;
          final m = lf(L, i); final amt = rv(L, i) + ppA(L, i);
          rev += amt * f; cost += mc * m * f; mo += m;
        }
      }
    }
    for (final x in SE()) {
      final un = truthy(x['u']) ? U(x['u']) : null; final f = un != null ? sh(un) : shg(x['g']);
      final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1;
      for (var i = 0; i < cnt; i++) { if (!addM(pd(x['d']), i).isAfter(t)) cost += n(x['a']) * f; }
    }
    return {'rev': rev, 'cost': cost, 'profit': rev - cost, 'mo': mo};
  }

  /* ───── فلوس الشراكة ───── */
  double gpTot(dynamic id) => lst(obj(S['gp'])?[id]).fold(0.0, (s, x) => s + n0(obj(x)?['a']));
  static List<double> shares(Obj g) {
    final nn = math.max(2, truthy(g['n']) ? n(g['n']).toInt() : 2);
    final me = truthy(g['custom']) ? (truthy(g['share']) ? n(g['share']) : 50.0) : 100.0 / nn;
    final rest = (100 - me) / (nn - 1);
    return [me, for (var i = 1; i < nn; i++) rest];
  }
  double gpMine(Obj g) => gpTot(g['id']) * (S['pmode'] == 'me' ? shares(g)[0] / 100 : 1);

  /* ───── المركز المالي (اللي ليك واللي عليك) ───── */
  Map<String, double> fpos() {
    final t = today(); final tm = ms(t);
    final r = <String, double>{'cash': cashNow(), 'rcv': 0, 'accU': 0, 'preCo': 0, 'preI': 0, 'fur': 0, 'depP': 0, 'due': 0, 'accCo': 0, 'unr': 0, 'furPay': 0, 'depH': 0, 'fut': 0};
    void add(String k, double v) => r[k] = r[k]! + v;
    for (final u in SU()) {
      final f = sh(u); final b = pd(u['start']); final e = addM(b, n(u['cm']));
      final span = ms(e) - ms(b);
      final fe = math.max(0.0, math.min(1.0, (tm - ms(b)) / (span == 0 ? 1 : span)));
      final tot = truthy(u['total']) ? n(u['total']) : isumOf(u);
      final C = tot * fe;
      var P = 0.0, D = 0.0, AM = 0.0;
      for (final i in objs(u['inst'])) {
        final a = n0(i['a']);
        if (truthy(i['p'])) { P += a; } else if (!pd(i['d']).isAfter(t)) { D += a; } else { add('fut', a * f); }
      }
      final x = P + D - C; add('due', D * f);
      if (x >= 0) { add('preCo', x * f); } else { add('accCo', -x * f); }
      if (truthy(n0(u['furn']))) {
        final cm = truthy(u['cm']) ? n(u['cm']) : 1.0;
        add('fur', math.max(0.0, n0(u['furn']) - n0(u['furn']) / cm * furMo(u)) * f);
        if (!truthy(u['fp'])) add('furPay', n(u['furn']) * f);
      }
      for (final L in objs(u['leases'])) {
        var E = 0.0, R = 0.0, B = 0.0, Ip = 0.0, Ia = 0.0, m = 0.0;
        final rc = rcv(L); final M = months(L);
        for (var i = 0; i < M; i++) {
          final d0 = payD(L, i); if (d0.isAfter(t)) continue;
          final d1 = i < M - 1 ? payD(L, i + 1) : lend(L);
          final fr = math.max(0.0, math.min(1.0, (tm - ms(d0)) / math.max(1, ms(d1) - ms(d0))));
          E += (rv(L, i) + (same(L['advp'], i) ? n0(L['advA']) : 0) + ppA(L, i)) * fr;
          if (!rc.contains(i)) B += la(L, i);
          Ip += n0(L['icost']) * lf(L, i); Ia += n0(L['icost']) * lf(L, i) * fr; m += lf(L, i) * fr;
        }
        if (!pd(L['start']).isAfter(t)) {
          E += (!L.containsKey('advA') && !L.containsKey('stubA')) ? n0(L['adv']) : n0(L['stubA']);
          if (truthy(L['rme']) && truthy(L['router'])) Ip += n0(L['router']);
        }
        final lmv = lm(L);
        Ia += m * (truthy(L['rme']) ? n0(L['router']) / (lmv == 0 ? 1 : lmv) : 0);
        var AR = 0.0;
        for (final i in rc) {
          R += rv(L, i);
          if (i < M) {
            final d0 = payD(L, i); final d1 = i < M - 1 ? payD(L, i + 1) : lend(L);
            if (d1.isAfter(t)) {
              final s0 = d0.isAfter(t) ? d0 : t;
              final ff = math.max(0.0, math.min(1.0, (ms(d1) - ms(s0)) / math.max(1, ms(d1) - ms(d0))));
              AR += rv(L, i) * ff; AM += (ms(d1) - ms(s0)) / (864e5 * 30.4375);
            }
          }
        }
        R += n0(L['adv']) + ppT(L);
        if (truthy(L['penp']) && truthy(L['pen'])) { R += n(L['pen']); if (truthy(L['exit']) && !pd(L['exit']).isAfter(t)) E += n(L['pen']); }
        final y = R + B - E; add('rcv', B * f);
        if (y >= 0) { add('unr', math.max(0.0, y - AR) * f); } else { add('accU', -y * f); }
        add('preI', (Ip - Ia) * f);
      }
      if (AM > 0) { final cm = truthy(u['cm']) ? n(u['cm']) : 1.0; add('preCo', -(tot / cm * AM * f)); }
    }
    if (r['preCo']! < 0) { add('accCo', -r['preCo']!); r['preCo'] = 0; }
    if (WS == 'all' || WS == '-') {
      for (final x in objs(S['dep'])) {
        if (truthy(x['r']) || x['mode'] == 'chq') continue;
        if (x['k'] == 't') { add('depH', n0(x['a'])); } else { add('depP', n0(x['a'])); }
      }
    }
    r['ptn'] = 0; r['gpm'] = 0;
    if (S['pmode'] == 'me') r['ptn'] = mvO(0) - mvO(0, true);
    for (final g in objs(S['groups'])) { if (WS == 'all' || WS == g['id']) add('gpm', gpMine(g)); }
    r['A'] = r['cash']! + r['rcv']! + r['accU']! + r['preCo']! + r['preI']! + r['fur']! + r['depP']! + r['gpm']!;
    r['L'] = r['due']! + r['accCo']! + r['unr']! + r['furPay']! + r['depH']! + r['ptn']!;
    r['eq'] = r['A']! - r['L']!;
    return r;
  }

  /* ───── المواعيد: دفعات الشركة، الإيجارات، نهاية العقود، المصاريف (items في القديم) ───── */
  static String nthT(int k, num of, String last) { final o = of.ceil(); if (!(o > 1)) return ''; return k >= o ? ' ($last $k/$o)' : ' ($k من $o)'; }
  static int dd(String d) => ((ms(pd(d)) - ms(today())) / 864e5).round();
  List<Map<String, dynamic>> items() {
    final t = today(); final r = <Map<String, dynamic>>[];
    void P(String ty, String id, String d, String label, num amt, List<int> offs, [Map<String, dynamic>? x]) => r.add({'ty': ty, 'id': id, 'd': d, 'label': label, 'amt': amt, 'offs': offs, ...?x});
    for (final u in SU()) {
      final inst = objs(u['inst']);
      for (var k = 0; k < inst.length; k++) {
        final i = inst[k]; if (truthy(i['p'])) continue;
        final g = inst.where((j) => truthy(j['rn']) == truthy(i['rn'])).toList();
        P('inst', '${u['id']}i$k', str(i['d']), 'دفعة ${str(u['company']).isEmpty ? 'الشركة' : str(u['company'])} - ${str(u['name'])}${truthy(i['rn']) ? ' — العقد المجدد' : ''}${nthT(g.indexOf(i) + 1, g.length, 'الأخيرة')}', n0(i['a']), [30, 21, 14, 7, 2, 0], {'u': u['id'], 'k': k});
      }
      final ls = objs(u['leases']);
      for (var k = 0; k < ls.length; k++) {
        final L = ls[k]; final rc = rcv(L);
        for (var i = 0; i < months(L); i++) { if (!rc.contains(i)) P('rent', '${u['id']}l${k}_$i', iso(payD(L, i)), 'إيجار ${str(L['tenant']).isEmpty ? 'مستأجر' : str(L['tenant'])} - ${str(u['name'])}${nthT(i + 1, months(L), 'آخر إيجار')}', la(L, i), [1, 0], {'u': u['id'], 'k': k, 'i': i}); }
        P('end', '${u['id']}e$k', iso(lend(L)), 'انتهاء عقد ${str(L['tenant']).isEmpty ? 'المستأجر' : str(L['tenant'])} - ${str(u['name'])}', 0, [30, 14, 7, 0], {'u': u['id'], 'k': k});
      }
      P('cend', '${u['id']}c', iso(addM(pd(u['start']), n(u['cm']))), 'انتهاء عقد الشركة - ${str(u['name'])}', 0, [0], {'u': u['id']});
    }
    final debts = objs(S['debts']); for (var k = 0; k < debts.length; k++) { P('debt', 'd$k', str(debts[k]['d']), 'دفعة مستحقة عليّ: ${str(debts[k]['w'])}', n0(debts[k]['a']), [0]); }
    final recv = objs(S['recv']); for (var k = 0; k < recv.length; k++) { P('recv', 'r$k', str(recv[k]['d']), 'مستحقات لي: ${str(recv[k]['w'])}', n0(recv[k]['a']), [0]); }
    final se = SE();
    for (var k = 0; k < se.length; k++) {
      final x = se[k]; final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1;
      for (var i = 0; i < cnt; i++) { final d = iso(addM(pd(x['d']), i)); if (!pd(d).isBefore(t)) P('exp', 'x${k}_$i', d, 'مصروف: ${str(x['w'])}', n0(x['a']), [0]); }
    }
    return r;
  }

  /* ───── حركات الفلوس الجاية (events) والتوقع (project) ───── */
  List<Map<String, dynamic>> events() {
    final t = today(); final ev = <Map<String, dynamic>>[];
    DateTime cl(dynamic d) { final x = pd(d); return x.isBefore(t) ? t : x; }
    for (final u in SU()) {
      const f = 1.0;
      for (final i in objs(u['inst'])) { if (!truthy(i['p']) && truthy(i['a']) && truthy(i['d'])) ev.add({'d': cl(i['d']), 'a': -n(i['a']) * f, 'l': '${str(u['name'])} – دفعة ${str(u['company']).isEmpty ? 'الشركة' : str(u['company'])}'}); }
      if (!truthy(u['fp']) && truthy(u['furn'])) ev.add({'d': t, 'a': -n(u['furn']) * f, 'l': '${str(u['name'])} – أثاث'});
      if (truthy(u['salv'])) { final d = addM(pd(u['start']), n(u['cm'])); if (!d.isBefore(t)) ev.add({'d': d, 'a': n(u['salv']) * f, 'l': '${str(u['name'])} – استرداد الأثاث'}); }
      for (final L in objs(u['leases'])) {
        final rc = rcv(L);
        for (var i = 0; i < months(L); i++) {
          if (!rc.contains(i)) ev.add({'d': cl(iso(payD(L, i))), 'a': la(L, i) * f, 'l': '${str(u['name'])} – إيجار ${str(L['tenant']).isEmpty ? 'مستأجر' : str(L['tenant'])}'});
          if (truthy(L['icost']) && payD(L, i).isAfter(t)) ev.add({'d': cl(iso(payD(L, i))), 'a': -n(L['icost']) * lf(L, i) * f, 'l': '${str(u['name'])} – إنترنت'});
        }
        if (truthy(L['rme']) && truthy(L['router']) && pd(L['start']).isAfter(t)) ev.add({'d': cl(L['start']), 'a': -n(L['router']) * f, 'l': '${str(u['name'])} – راوتر'});
        if (truthy(L['pen']) && !truthy(L['penp']) && truthy(L['exit'])) ev.add({'d': cl(L['exit']), 'a': n(L['pen']) * f, 'l': '${str(u['name'])} – شرط جزائي'});
      }
    }
    for (final x in objs(S['debts'])) { ev.add({'d': cl(x['d']), 'a': -n(x['a']), 'l': str(x['w'])}); }
    for (final x in objs(S['recv'])) { ev.add({'d': cl(x['d']), 'a': n(x['a']), 'l': str(x['w'])}); }
    for (final x in SE()) { final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1; for (var i = 0; i < cnt; i++) { final d = addM(pd(x['d']), i); if (d.isAfter(t)) ev.add({'d': d, 'a': -n(x['a']), 'l': str(x['w'])}); } }
    // ترتيب ثابت زي Array.sort في JS
    final idx = {for (var i = 0; i < ev.length; i++) ev[i]: i};
    ev.sort((a, b) { final c = (a['d'] as DateTime).compareTo(b['d'] as DateTime); return c != 0 ? c : idx[a]!.compareTo(idx[b]!); });
    return ev;
  }

  Map<String, dynamic> project(List<Map<String, dynamic>> ev) {
    final lim = addM(today(), 12); var b = cashNow(); var min = b; var minD = today(); final m = <int, Map<String, dynamic>>{}; final order = <int>[];
    for (final e in ev) {
      final a = e['a'] as double; final d = e['d'] as DateTime; b += a;
      if (!d.isAfter(lim) && b < min) { min = b; minD = d; }
      final k = mkey(d); if (!m.containsKey(k)) { m[k] = {'d': d, 'i': 0.0, 'o': 0.0}; order.add(k); }
      if (a > 0) { m[k]!['i'] = (m[k]!['i'] as double) + a; } else { m[k]!['o'] = (m[k]!['o'] as double) - a; }
      m[k]!['end'] = b;
    }
    final rows = [for (final k in order) m[k]!]..sort((x, y) => (x['d'] as DateTime).compareTo(y['d'] as DateTime));
    return {'min': min, 'minD': minD, 'rows': rows};
  }

  /* ───── الربح على أساس الاستحقاق (accr) ───── */
  Map<String, double> accr() {
    final t = today(); final tm = ms(t); var rentE = 0.0, pen = 0.0, coC = 0.0, fuC = 0.0, isC = 0.0, exC = 0.0;
    for (final u in SU()) {
      final f = sh(u); final cm = truthy(u['cm']) ? n(u['cm']) : 1.0; final b = pd(u['start']); final e = addM(b, n(u['cm']));
      final span = ms(e) - ms(b); final el = cm * math.max(0.0, math.min(1.0, (tm - ms(b)) / (span == 0 ? 1 : span)));
      for (final L in objs(u['leases'])) {
        var m = 0.0; final M = months(L);
        for (var i = 0; i < M; i++) {
          final d0 = payD(L, i);
          if (!d0.isAfter(t)) {
            final d1 = i < M - 1 ? payD(L, i + 1) : lend(L);
            final fr = math.max(0.0, math.min(1.0, (tm - ms(d0)) / math.max(1, ms(d1) - ms(d0)))); final lfi = lf(L, i) * fr;
            rentE += (rv(L, i) + (same(L['advp'], i) ? n0(L['advA']) : 0) + ppA(L, i)) * fr * f; isC += n0(L['icost']) * lfi * f; m += lfi;
          }
        }
        final lmv = lm(L);
        isC += m * (truthy(L['rme']) ? n0(L['router']) / (lmv == 0 ? 1 : lmv) : 0) * f;
        if (truthy(L['pen']) && truthy(L['penp']) && truthy(L['exit']) && !pd(L['exit']).isAfter(t)) pen += n(L['pen']) * f;
        if (!pd(L['start']).isAfter(t)) { if (!L.containsKey('advA') && !L.containsKey('stubA')) { rentE += n0(L['adv']) * f; } else { rentE += n0(L['stubA']) * f; } }
      }
      coC += (truthy(u['total']) ? n(u['total']) : isumOf(u)) / cm * el * f;
      fuC += (n0(u['furn']) / cm * el - (el >= cm ? n0(u['salv']) : 0)) * f;
    }
    for (final x in SE()) {
      final un = truthy(x['u']) ? U(x['u']) : null; final f = un != null ? sh(un) : shg(x['g']); final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1;
      for (var i = 0; i < cnt; i++) { if (!addM(pd(x['d']), i).isAfter(t)) exC += n(x['a']) * f; }
    }
    final earned = rentE + pen, cost = coC + fuC + isC + exC;
    return {'earned': earned, 'cost': cost, 'profit': earned - cost, 'rentE': rentE, 'pen': pen, 'coC': coC, 'fuC': fuC, 'isC': isC, 'exC': exC};
  }
}
