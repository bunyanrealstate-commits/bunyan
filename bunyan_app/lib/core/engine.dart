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
    // «رد التأمين» على انتهاء العقد (depOf)
    for (var j = 0; j < r.length; j++) {
      final x = r[j]; if (x['ty'] != 'end') continue;
      final mm = RegExp(r'^(.*)e(\d+)$').firstMatch(str(x['id'])); final u = mm == null ? null : U(mm[1]); final ls = u == null ? null : objs(u['leases']);
      final L = (ls != null && int.parse(mm![2]!) < ls.length) ? ls[int.parse(mm[2]!)] : null; final d = L == null ? null : depOf(L);
      if (d != null && !truthy(d['r'])) r[j] = {...x, 'label': '${x['label']} • رد التأمين ${d['mode'] == 'chq' ? '(شيك ضمان)' : _fmt(n0(d['a']))}'};
    }
    // 🔁 تجديد عقد الشركة (renewjs)
    for (final u in SU()) {
      if (u['ren'] == 'no') continue;
      final ce = addM(pd(u['start']), n0(u['cm'])); final nd = ((ms(ce) - ms(t)) / 864e5).round();
      if (nd > 120 || nd < -45) continue;
      final a = renEst(u); final d = truthy(u['renD']) ? str(u['renD']) : iso(ce); final set = u['renA'] != null && u['renA'] != '';
      r.add({'ty': 'inst', 'id': '${u['id']}rn', 'd': d, 'label': '🔁 تجديد عقد الشركة - ${str(u['name'])}${a != 0 ? ' (دفعة أولى${set ? '' : ' متوقعة'})' : ' (اكتب مبلغ التجديد)'}', 'amt': a, 'offs': [60, 45, 30, 21, 14, 7, 3, 1, 0], 'rn': 1});
    }
    // ⏳ أيام السماح بتخلص والاستديو فاضي
    for (final u in SU()) {
      final o = gi(u); if (o['now'] != true || o['nextIn'] != null || !((o['c'] as double) > 0)) continue;
      final B = o['B'] as int; final d = DateTime.fromMillisecondsSinceEpoch(ms(t) + math.max(0, B) * 86400000);
      r.add({'ty': 'grace', 'id': '${u['id']}gr', 'd': iso(d), 'label': B > 0 ? '⏳ أيام السماح بتاعة «${str(u['name'])}» بتخلص — بعدها كل يوم فاضي خسارة ${_fmt((o['c'] as double).roundToDouble())}' : '🔴 «${str(u['name'])}» فاضي وخلصت أيام السماح — كل يوم خسارة ${_fmt((o['c'] as double).roundToDouble())}', 'amt': 0, 'offs': [3, 2, 1, 0]});
    }
    return r;
  }

  Obj? depOf(Obj L) { final D = objs(S['dep']); return D.where((x) => x['lid'] == L['id'] && !truthy(x['r'])).firstOrNull ?? D.where((x) => x['lid'] == L['id']).firstOrNull; }
  static double renEst(Obj u) { if (u['renA'] != null && u['renA'] != '') return n0(u['renA']); final nr = objs(u['inst']).where((i) => !truthy(i['rn'])).toList(); return nr.isNotEmpty ? n0(nr[0]['a']) : 0; }
  static String _fmt(num v) { final r = v.round(); final s = r.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','); return r < 0 ? '-$s' : s; }

  /// أيام السماح (graceInfo / gi)
  Map<String, dynamic> gi(Obj u) {
    final g = n0(u['grace']).toInt(); final cs = pd(u['start']), ce = addM(cs, n0(u['cm'])); var H = DateTime.fromMillisecondsSinceEpoch(ms(cs) - g * 86400000); final t = today();
    final D = math.max(1, dy(cs, ce)); final tot = truthy(u['total']) ? n(u['total']) : isumOf(u); final c = tot / D * sh(u);
    final iv = [for (final L in objs(u['leases'])) [pd(L['start']), truthy(L['exit']) ? pd(L['exit']) : lend(L)]].where((x) => x[1].isAfter(x[0])).toList()..sort((a, b) => a[0].compareTo(b[0]));
    final m = <List<DateTime>>[];
    for (final x in iv) { if (m.isNotEmpty && !x[0].isAfter(m.last[1])) { if (x[1].isAfter(m.last[1])) m.last[1] = x[1]; } else { m.add([x[0], x[1]]); } }
    DateTime mx(DateTime a, DateTime b) => a.isAfter(b) ? a : b; DateTime mn(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
    int oc(DateTime a, DateTime b) { var k = 0; for (final x in m) { final p = mx(x[0], a), q = mn(x[1], b); if (q.isAfter(p)) k += dy(p, q); } return k; }
    if (truthy(u['onb'])) { if (m.isNotEmpty && m[0][0].isAfter(H)) { H = m[0][0]; } else if (m.isEmpty) { H = mx(t, H); } }
    final tc = mn(mx(t, H), ce); final vp = math.max(0, dy(H, tc) - oc(H, tc)), vf = math.max(0, dy(tc, ce) - oc(tc, ce));
    final now = !t.isBefore(H) && t.isBefore(ce) && !m.any((x) => !x[0].isAfter(t) && t.isBefore(x[1]));
    DateTime? since; if (now) { final prev = m.where((x) => !x[1].isAfter(t)).toList(); since = prev.isNotEmpty ? prev.last[1] : H; }
    final nx = m.where((x) => x[0].isAfter(t)).toList(); var rent = 0.0; for (final L in objs(u['leases'])) { if (n0(L['rent']) != 0) rent = n0(L['rent']); }
    final B = g - vp;
    return {'g': g, 'H': H, 'cs': cs, 'ce': ce, 'c': c, 'vp': vp, 'vf': vf, 'B': B, 'Bend': B - vf, 'now': now, 'since': since, 'nextIn': nx.isNotEmpty ? nx[0][0] : null, 'lastOut': m.isNotEmpty ? m.last[1] : null, 'dr': rent != 0 ? rent * 12 / 365 * sh(u) : 0.0};
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

  /* ───── الربح المتوقع للاستديو والسنة (ua / projU / winU / annW / occ) ───── */
  static int dy(DateTime a, DateTime b) => ((ms(b) - ms(a)) / 864e5).round();
  static double mBtw(DateTime a, DateTime b) {
    if (!b.isAfter(a)) return 0;
    var k = 0; while (k < 600 && !addM(a, k + 1).isAfter(b)) { k++; }
    final x = addM(a, k), y = addM(a, k + 1); final r = (ms(b) - ms(x)) / 864e5; final dmv = ((ms(y) - ms(x)) / 864e5).round(); final dm = dmv == 0 ? 30 : dmv;
    return k + (r > 0.5 ? r.round() / dm : 0);
  }
  Map<String, dynamic> onbPre(Obj u) {
    try {
      final ls = objs(u['leases']);
      if (!truthy(u['onb']) || ls.isEmpty) return {'m': 0.0, 'a': 0.0, 'to': null};
      final L = ([...ls]..sort((a, b) => str(a['start']).compareTo(str(b['start'])))).first;
      final s0 = pd(u['start']), fs = pd(L['start']);
      if (!fs.isAfter(s0)) return {'m': 0.0, 'a': 0.0, 'to': null};
      final m = math.min(mBtw(s0, fs), truthy(u['cm']) ? n(u['cm']) : 12.0);
      return {'m': m, 'a': n0(L['rent']) * m, 'to': L['start'], 'L': L};
    } catch (_) { return {'m': 0.0, 'a': 0.0, 'to': null}; }
  }
  Map<String, double> ua(Obj u) {
    final f = sh(u);
    final ue = objs(S['exp']).where((x) => x['u'] == u['id']).fold(0.0, (s, x) => s + n(x['a']) * (truthy(x['n']) ? n(x['n']) : 1));
    final full = (truthy(u['total']) ? n(u['total']) : isumOf(u)) + n0(u['furn']) + ue; final pre = onbPre(u);
    final ls = objs(u['leases']);
    final occN = ls.fold(0.0, (s, L) => s + lm(L)) + (pre['m'] as double);
    var incL = 0.0;
    for (final L in ls) {
      var a = 0.0; for (var i = 0; i < months(L); i++) { a += la(L, i); }
      (obj(L['rav']) ?? {}).forEach((q, v) { a += n(v) - la(L, int.tryParse(q) ?? 0); });
      a += (truthy(L['penp']) ? n0(L['pen']) : 0) + n0(L['adv']) + ppT(L);
      incL += a;
    }
    final inc = (pre['a'] as double) * f + incL * f;
    final ic = ls.fold(0.0, (s, L) => s + n0(L['icost']) * lm(L) + (truthy(L['rme']) ? n0(L['router']) : 0)) * f;
    final salv = n0(u['salv']); final cost = (full - salv) * f + ic; final cm = n0(u['cm']);
    final vac = math.max(0.0, cm - occN); final tg = (S['tp'] == null ? 25 : n(S['tp'])) / 100;
    final tr = cm != 0 ? (full - salv) * (1 + tg) / cm : 0.0;
    return {'cost': cost, 'inc': inc, 'occ': occN, 'vac': vac, 'tr': tr, 'tg': tg, 'full': full - salv, 'profit': inc - cost, 'need': vac != 0 ? math.max(0.0, (cost * (1 + tg) - inc) / f / vac) : 0.0};
  }
  Map<String, dynamic>? winU(Obj u) {
    final s0 = pd(u['start']); final ce = addM(s0, truthy(u['cm']) ? n(u['cm']) : 12); DateTime? le;
    for (final L in objs(u['leases'])) { var e = lend(L); if (truthy(L['exit']) && pd(L['exit']).isBefore(e)) e = pd(L['exit']); if (le == null || e.isAfter(le)) le = e; }
    if (le == null || !le.isAfter(s0)) return null;
    final e = le.isBefore(ce) ? le : ce; final mW = mBtw(s0, e); var oc = 0.0;
    for (final L in objs(u['leases'])) { var a = pd(L['start']), b = lend(L); if (truthy(L['exit']) && pd(L['exit']).isBefore(b)) b = pd(L['exit']); if (a.isBefore(s0)) a = s0; if (b.isAfter(e)) b = e; if (b.isAfter(a)) oc += mBtw(a, b); }
    return {'s': s0, 'e': e, 'mW': mW, 'oc': math.min(oc, mW), 'occ': mW != 0 ? math.min(1.0, oc / mW) : 0.0};
  }
  Map<String, dynamic>? projU(Obj u) {
    final f = sh(u); final s0 = pd(u['start']); final cm = truthy(u['cm']) ? n(u['cm']) : 12.0; final ce = addM(s0, cm);
    final mc = ((truthy(u['total']) ? n(u['total']) : isumOf(u)) + n0(u['furn'])) / cm; final dc = mc / 30; const D = 864e5;
    var mo = 0.0, F = 0.0; DateTime? le; final iv = <List<int>>[];
    for (final L in objs(u['leases'])) {
      final a = pd(L['start']); var b = lend(L); if (truthy(L['exit']) && pd(L['exit']).isBefore(b)) b = pd(L['exit']);
      if (!b.isAfter(a)) continue;
      mo += truthy(L['exit']) ? mBtw(a, b) : lm(L);
      if (a.isBefore(s0)) F += ((math.min(ms(s0), ms(b)) - ms(a)) / D).round();
      if (le == null || b.isAfter(le)) le = b;
      final x = a.isBefore(s0) ? s0 : a, y = b.isAfter(ce) ? ce : b; if (y.isAfter(x)) iv.add([ms(x), ms(y)]);
    }
    if (le == null) return null;
    final e = le.isBefore(ce) ? le : ce; iv.sort((p, q) => p[0].compareTo(q[0]));
    var cov = 0; List<int>? cur;
    for (final v in iv) { if (cur == null || v[0] > cur[1]) { if (cur != null) cov += cur[1] - cur[0]; cur = [v[0], v[1]]; } else if (v[1] > cur[1]) { cur[1] = v[1]; } }
    if (cur != null) cov += cur[1] - cur[0];
    final gap = math.max(0, ((ms(e) - ms(s0)) / D - cov / D).round()); final net = F - gap; final end = !le.isBefore(ce);
    var cost = mc * mo; var adj = 0.0; if (net < 0) { adj = -net * dc; } else if (end) { adj = -net * dc; } cost += adj;
    final sv = end ? n0(u['salv']) : 0.0; cost -= sv;
    final inc = ua(u)['inc']! / (f == 0 ? 1 : f);
    return {'mc': mc, 'months': mo, 'F': F, 'gap': gap, 'adj': adj, 'sv': sv, 'inc': inc * f, 'cost': cost * f, 'p': (inc - cost) * f, 's': s0, 'e': e, 'end': end};
  }
  Map<String, dynamic> annW() {
    final t = today(); var mo = 0.0, p = 0.0, mW = 0.0, oc = 0.0; DateTime? e0, s0;
    for (final u in SU()) {
      if (!addM(pd(u['start']), n(u['cm'])).isAfter(t)) continue;
      final w = winU(u); if (w == null) continue;
      final P = projU(u); p += P != null ? P['p'] as double : 0; if (P != null) mo += P['months'] as double;
      mW += w['mW'] as double; oc += w['oc'] as double;
      final we = w['e'] as DateTime, ws = w['s'] as DateTime;
      if (e0 == null || we.isAfter(e0)) e0 = we; if (s0 == null || ws.isBefore(s0)) s0 = ws;
    }
    var gx = 0.0;
    if (e0 != null) {
      for (final x in SE()) { if (truthy(x['u'])) continue; final f = shg(x['g']); final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1;
        for (var i = 0; i < cnt; i++) { final d = addM(pd(x['d']), i); if (!d.isBefore(t) && d.isBefore(e0)) gx += n0(x['a']) * f; } }
    }
    return {'p': p - gx, 'gx': gx, 'occ': mW != 0 ? oc / mW : 0.0, 'mW': mW, 's': s0, 'e': e0, 'mo': mo};
  }

  /* ───── دفتر الحسابات (ledger) ───── */
  List<Map<String, dynamic>> ledger() {
    final t = today(); final r = <Map<String, dynamic>>[];
    for (final u in SU()) {
      final f = sh(u); final nm = str(u['name']);
      for (final i in objs(u['inst'])) { if (truthy(i['p'])) r.add({'d': str(i['d']), 'u': nm, 'c': 'co', 'w': 'دفعة ${str(u['company']).isEmpty ? 'الشركة' : str(u['company'])}', 'a': -n(i['a']) * f}); }
      if (truthy(u['fp']) && truthy(u['furn'])) r.add({'d': str(u['start']), 'u': nm, 'c': 'fu', 'w': 'أثاث', 'a': -n(u['furn']) * f});
      for (final L in objs(u['leases'])) {
        for (final i in rcv(L)) { final rv0 = idx(L['rav'], i); r.add({'d': iso(payD(L, i)), 'u': nm, 'c': 'rn', 'w': 'إيجار${truthy(L['inet']) ? ' + إنترنت' : ''} ${str(L['tenant'])}', 'a': (rv0 != null ? n(rv0) : la(L, i)) * f}); }
        if (truthy(L['adv'])) r.add({'d': str(L['start']), 'u': nm, 'c': 'rn', 'w': '${truthy(L['fee']) ? 'رسوم كتابة عقد ' : 'دفعة مقدمة '}${str(L['tenant'])}', 'a': n(L['adv']) * f});
        for (final x in objs(L['pp'])) { r.add({'d': iso(DateTime.fromMillisecondsSinceEpoch(truthy(x['at']) ? n(x['at']).toInt() : DateTime.now().millisecondsSinceEpoch)), 'u': nm, 'c': 'rn', 'w': 'دفعة مقدمة من إيجار شهر ${n(x['i']).toInt() + 1} ${str(L['tenant'])}', 'a': n0(x['a']) * f}); }
        if (truthy(L['icost'])) { for (var i = 0; i < months(L); i++) { final d = payD(L, i); if (!d.isAfter(t)) r.add({'d': iso(d), 'u': nm, 'c': 'is', 'w': 'تكلفة إنترنت', 'a': -n(L['icost']) * lf(L, i) * f}); } }
        if (truthy(L['rme']) && truthy(L['router']) && !pd(L['start']).isAfter(t)) r.add({'d': str(L['start']), 'u': nm, 'c': 'is', 'w': 'راوتر', 'a': -n(L['router']) * f});
        if (truthy(L['pen']) && truthy(L['penp']) && truthy(L['exit'])) r.add({'d': str(L['exit']), 'u': nm, 'c': 'pn', 'w': 'شرط جزائي', 'a': n(L['pen']) * f});
      }
    }
    for (final x in SE()) {
      final un = truthy(x['u']) ? U(x['u']) : null; final f = un != null ? sh(un) : shg(x['g']); final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1;
      for (var i = 0; i < cnt; i++) { final d = addM(pd(x['d']), i); if (!d.isAfter(t)) r.add({'d': iso(d), 'u': un != null ? str(un['name']) : '', 'c': 'ex', 'w': str(x['w']), 'a': -n(x['a']) * f}); }
    }
    final idx0 = {for (var i = 0; i < r.length; i++) r[i]: i};
    r.sort((a, b) { final c = str(b['d']).compareTo(str(a['d'])); return c != 0 ? c : idx0[a]!.compareTo(idx0[b]!); });
    return r;
  }

  /* ───── الإشغال والأيام الشاغرة (occ) ───── */
  Map<String, dynamic> occ(Obj u) {
    final cs = pd(u['start']), ce = addM(cs, n0(u['cm'])), t = today();
    final D = math.max(1, dy(cs, ce)); final tot = truthy(u['total']) ? n(u['total']) : isumOf(u); final c = tot / D;
    final g = n0(u['grace']); final lo = g > 0 ? DateTime.fromMillisecondsSinceEpoch(ms(cs) - (g * 864e5).round()) : DateTime.fromMillisecondsSinceEpoch(0);
    DateTime le(Obj L) => truthy(L['exit']) ? pd(L['exit']) : lend(L);
    final iv = [for (final L in objs(u['leases'])) [pd(L['start']), le(L)]].where((x) => x[1].isAfter(x[0])).toList()..sort((a, b) => a[0].compareTo(b[0]));
    final m = <List<DateTime>>[];
    for (final x in iv) { if (m.isNotEmpty && !x[0].isAfter(m.last[1])) { if (x[1].isAfter(m.last[1])) m.last[1] = x[1]; } else { m.add([x[0], x[1]]); } }
    DateTime mx(DateTime a, DateTime b) => a.isAfter(b) ? a : b; DateTime mn(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
    var free = 0; for (final x in m) { final a = mx(x[0], lo), b = mn(x[1], cs); if (b.isAfter(a)) free += dy(a, b); }
    var preVal = 0.0;
    for (final L in objs(u['leases'])) { final a = mx(pd(L['start']), lo), b = mn(le(L), cs); for (var d = a; d.isBefore(b); d = DateTime(d.year, d.month, d.day + 1)) { preVal += n0(L['rent']) / DateTime(d.year, d.month + 1, 0).day; } }
    final gaps = <List<DateTime>>[]; var cur = truthy(u['onb']) && m.isNotEmpty ? mx(cs, m[0][0]) : cs;
    for (final x in m) { final a = mx(x[0], cs), b = mn(x[1], ce); if (!b.isAfter(a)) continue; if (a.isAfter(cur)) gaps.add([cur, a]); cur = mx(cur, b); }
    if (cur.isBefore(ce)) gaps.add([cur, ce]);
    final G = [for (final x in gaps) () { final dys = dy(x[0], x[1]); final past = math.max(0, math.min(dys, dy(x[0], mn(x[1], t)))); return {'a': iso(x[0]), 'b': iso(x[1]), 'dys': dys, 'past': past, 'fut': dys - past, 'loss': dys * c, 'lossPast': past * c, 'lossFut': (dys - past) * c}; }()];
    final f = sh(u);
    return {'D': D, 'c': c * f, 'free': free, 'freeVal': preVal * f, 'gaps': G, 'vac': G.fold<int>(0, (s, x) => s + (x['dys'] as int)), 'lossPast': G.fold<double>(0, (s, x) => s + (x['lossPast'] as double)) * f, 'lossFut': G.fold<double>(0, (s, x) => s + (x['lossFut'] as double)) * f};
  }

  /* ───── عقود قربت تخلص (renewList) — snz = أيام التأجيل ───── */
  List<Map<String, dynamic>> renewList(bool Function(String key) snz) {
    final r = <Map<String, dynamic>>[]; final t = today();
    for (final u in SU()) {
      final ls = objs(u['leases']);
      for (var k = 0; k < ls.length; k++) {
        final L = ls[k]; if (truthy(L['exit']) || truthy(L['rn'])) continue;
        final e = lend(L); final nd = ((ms(e) - ms(t)) / 864e5).round();
        final span = (ms(e) - ms(pd(L['start']))) / 864e5; final win = math.max(5, math.min(45, (span * 0.25).round()));
        if (nd < -3 || nd > win) continue;
        if (ls.any((M) => !identical(M, L) && !pd(M['start']).isBefore(addM(e, -1)) && !truthy(M['exit']))) continue;
        if (snz('${u['id']}_$k')) continue;
        r.add({'u': u, 'L': L, 'k': k, 'n': nd, 'e': e});
      }
    }
    r.sort((a, b) => (a['n'] as int).compareTo(b['n'] as int));
    return r;
  }
}
