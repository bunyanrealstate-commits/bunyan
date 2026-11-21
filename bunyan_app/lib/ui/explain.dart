/// 🧮 «الرقم ده جه منين؟» — نفس شاشات eqCash / eqProfit / eqProj / eqOcc… في بنيان القديم
/// + الكروت اللي بتفتح شاشات (التحليل المالي، مقارنة الاستديوهات، الحركة النقدية، الربح المحاسبي، سندات القبض…)
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';

/* ───────── شكل الشاشة (زي eqShow: ✕ + 🧮 العنوان + سطور + إجمالي بخط أزرق) ───────── */
Future<void> eqSheet(BuildContext context, String title, List<Widget> rows, {String icon = '🧮'}) => showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(textDirection: Tr.dir, child: DraggableScrollableSheet(
        expand: false, initialChildSize: .72, minChildSize: .35, maxChildSize: .95,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Container(height: 5, margin: const EdgeInsets.only(top: 0), decoration: const BoxDecoration(color: kTerra, borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 10, 8), child: Row(children: [
              Expanded(child: Text('$icon $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kInk))),
              InkWell(onTap: () => Navigator.of(ctx).pop(), borderRadius: BorderRadius.circular(99), child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFFF1F3F7), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 20))),
            ])),
            const Divider(height: 1),
            Expanded(child: ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: rows)),
          ]),
        ),
      )),
    );

String _sg(num a) => '${a < 0 ? '− ' : '+ '}${money(a.abs())}';

/// سطر بمبلغ بإشارة (+ أخضر / − أحمر) — زي row()
Widget eqR(String l, num a, [String? sub]) => _line(l, sub, Text(_sg(a), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: a < 0 ? kRed : kGreen)));
/// سطر بقيمة عادية — زي N()
Widget eqN(String l, String v, [String? sub]) => _line(l, sub, Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kInk)));
Widget _line(String l, String? sub, Widget v) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE6E8EE), style: BorderStyle.solid))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Priv.txt(l), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: kInk)),
          if (sub != null && sub.isNotEmpty) Text(Priv.txt(sub), style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(width: 10), v,
      ]),
    );
/// عنوان استديو جوه الشاشة — زي eqh
Widget eqH(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 2), child: Text('🏠 ${Priv.un(t)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: kAc)));
/// الإجمالي بخط أزرق فوقه — زي eqt
Widget eqT(String l, String v) => Container(
      margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: kAc, width: 2.5))),
      child: Row(children: [Expanded(child: Text('= $l', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5))), Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))]),
    );
Widget eqMu(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(t, style: const TextStyle(color: kMuted)));

const _ms = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
String fdt(num msv) { final d = DateTime.fromMillisecondsSinceEpoch(msv.toInt()); return '${d.day} ${_ms[d.month - 1]} ${d.year}'; }
String fdd(DateTime d) => '${d.day} ${_ms[d.month - 1]} ${d.year}';
String _r2(num x) => ((x * 100).round() / 100).toString().replaceAll(RegExp(r'\.0$'), '');
String _pc(num x) => '${((x * 10).round() / 10).toString().replaceAll(RegExp(r'\.0$'), '')}%';
double _rv(Obj L, int i) { final r = idx(L['rav'], i); return r != null ? n(r) : Engine.la(L, i); }

/* ───────── 💵 الرصيد النقدي جه منين ───────── */
void eqCash(BuildContext context, Engine e) {
  final S = e.S, t = today(), ws = e.WS; final L0 = <Map<String, dynamic>>[];
  void add(num d, String l, num a, [String? sub]) { if (a.abs() >= .5) L0.add({'d': d, 'l': l, 'a': a, 'sub': sub}); }
  for (final u in e.SU()) {
    final nm = str(u['name']); final co = str(u['company']).isEmpty ? 'الشركة' : str(u['company']);
    final ins = objs(u['inst']);
    for (var k = 0; k < ins.length; k++) { final i = ins[k]; if (truthy(i['p']) && n0(i['at']) > 0) add(n0(i['at']), 'دفعة $co رقم ${k + 1}', -n0(i['a']), nm); }
    if (truthy(u['fp']) && n0(u['fat']) > 0) add(n0(u['fat']), 'أثاث', -n0(u['furn']), nm);
    for (final L in objs(u['leases'])) {
      final tn = str(L['tenant']).isEmpty ? 'مستأجر' : str(L['tenant']);
      for (final i in Engine.rcv(L)) { final at = n0(obj(L['rat'])?['$i']); if (at > 0) add(at, 'إيجار $tn (دفعة ${i + 1})', _rv(L, i), nm); }
      if (truthy(L['penp']) && n0(L['pat']) > 0) add(n0(L['pat']), 'شرط جزائي $tn', n0(L['pen']), nm);
      if (truthy(L['adv']) && n0(L['advat']) > 0) add(n0(L['advat']), 'رسوم عقد $tn', n0(L['adv']), nm);
      for (final x in objs(L['pp'])) { if (n0(x['at']) > 0) add(n0(x['at']), 'دفعة مقدمة من $tn (من دفعة ${n0(x['i']).toInt() + 1})', n0(x['a']), nm); }
      if (truthy(L['icost'])) { var ic = 0.0; for (var i = 0; i < Engine.months(L); i++) { if (!Engine.payD(L, i).isAfter(t)) ic += n(L['icost']) * Engine.lf(L, i); } add(ms(t), 'إنترنت $tn', -ic, nm); }
      if (truthy(L['rme']) && truthy(L['router']) && !pd(L['start']).isAfter(t)) add(ms(pd(L['start'])), 'راوتر $tn', -n(L['router']), nm);
    }
  }
  for (final x in e.SE()) { var c = 0; final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1; for (var i = 0; i < cnt; i++) { if (!addM(pd(x['d']), i).isAfter(t)) c++; } if (c > 0) add(ms(pd(x['d'])), 'مصروف: ${str(x['w'])}', -n0(x['a']) * c, c > 1 ? '$c مرات' : ''); }
  if (ws == 'all' || ws == '-') {
    for (final x in objs(S['dep'])) { if (x['mode'] == 'chq') continue; final s = x['k'] == 't' ? 1 : -1; final a = n0(x['a']);
      if (n0(x['at']) > 0) add(n0(x['at']), '${s > 0 ? 'تأمين من ' : 'تأمين للشركة '}${str(x['w'])}', s * a);
      if (truthy(x['r']) && n0(x['rat']) > 0) add(n0(x['rat']), 'رد تأمين ${str(x['w'])}', -s * a); }
  }
  for (final a in objs(S['adj'])) { if (n0(a['at']) > 0 && (ws == 'all' || str(a['g']) == (ws == '-' ? '' : ws))) add(n0(a['at']), '${truthy(a['k']) ? '' : 'تسوية '}${str(a['w'])}', n0(a['a'])); }
  L0.sort((a, b) => (a['d'] as num).compareTo(b['d'] as num));
  final base = e.cashBase(); final rows = <Widget>[];
  if (base.abs() >= .5) rows.add(eqR('الرصيد الافتتاحي', base));
  for (final x in L0) { rows.add(eqR(x['l'], x['a'] as num, [if (str(x['sub']).isNotEmpty) str(x['sub']), if ((x['d'] as num) > 1e12) fdt(x['d'] as num)].join(' • '))); }
  if (rows.isEmpty) rows.add(eqMu('مفيش حركات نقدية لسه.'));
  rows.add(eqT('الرصيد النقدي', money(e.cashNow())));
  eqSheet(context, 'الرصيد النقدي', rows);
}

/* ───────── 📈 الربح حتى اليوم ───────── */
void eqProfit(BuildContext context, Engine e) {
  final t = today(); final rows = <Widget>[]; var rev = 0.0, cost = 0.0;
  for (final u in e.SU()) {
    final f = e.sh(u), cm = truthy(u['cm']) ? n(u['cm']) : 1.0, tot = truthy(u['total']) ? n(u['total']) : Engine.isumOf(u), fu = n0(u['furn']);
    final sv = !addM(pd(u['start']), cm).isAfter(t) ? n0(u['salv']) : 0.0; final mc = (tot + fu) / cm;
    var R = 0.0, mo = 0.0; final lines = <Widget>[];
    for (final L in objs(u['leases'])) {
      for (final i in Engine.rcv(L)) { if (i >= Engine.months(L)) continue; final m = Engine.lf(L, i), amt = _rv(L, i) + Engine.ppA(L, i); R += amt; mo += m;
        lines.add(eqR('إيجار ${str(L['tenant']).isEmpty ? 'مستأجر' : str(L['tenant'])} (دفعة ${i + 1})', amt * f, '${_r2(m)} شهر')); }
    }
    if (R == 0) continue;
    rows..add(eqH(str(u['name'])))..addAll(lines)
      ..add(eqN('تكلفة الشهر', money(mc), '(${money(tot)} شركة + ${money(fu)} فرش) ÷ ${_r2(cm)}'))
      ..add(eqR('تكلفة المدة المقبوضة', -mc * mo * f, '${money(mc)} × ${_r2(mo)} شهر'));
    if (sv != 0) { rows.add(eqR('استرداد الأثاث (عقد الشركة انتهى)', sv * f)); cost -= sv * f; }
    rev += R * f; cost += mc * mo * f;
  }
  var ex = 0.0;
  for (final x in e.SE()) { final un = truthy(x['u']) ? e.U(x['u']) : null; final f = un != null ? e.sh(un) : e.shg(x['g']); final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1;
    for (var i = 0; i < cnt; i++) { if (!addM(pd(x['d']), i).isAfter(t)) ex += n0(x['a']) * f; } }
  if (ex != 0) rows.add(eqR('مصروفات', -ex));
  if (rows.isEmpty) rows.add(eqMu('مفيش إيجار مقبوض لسه.'));
  rows..add(eqN('الإيراد', money(rev)))..add(eqN('التكلفة', '− ${money(cost + ex)}'))
    ..add(eqT('${Store.I.S['pmode'] == 'me' ? 'ربحي' : 'ربح المجموعة'} حتى اليوم', money(e.rcvP()['profit']!)));
  eqSheet(context, Tr.t('الربح حتى اليوم'), rows);
}

/* ───────── 🎯 الربح المتوقع على مدة العقود ───────── */
List<Obj> _live(Engine e) { final t = today(); return e.SU().where((u) => addM(pd(u['start']), n0(u['cm'])).isAfter(t)).toList(); }
void eqProj(BuildContext context, Engine e) {
  final rows = <Widget>[];
  for (final u in _live(e)) {
    final P = e.projU(u); if (P == null) continue;
    final f = e.sh(u), mc = P['mc'] as double, mo = P['months'] as double, k = mo != 0 ? (P['inc'] as double) / (f == 0 ? 1 : f) / mo : 0.0;
    final F = (P['F'] as num), gap = P['gap'] as num, adj = P['adj'] as double, sv = P['sv'] as double;
    rows..add(eqH(str(u['name'])))
      ..add(eqN('تكلفة الشهر', money(mc), '(${money(truthy(u['total']) ? n(u['total']) : Engine.isumOf(u))} شركة + ${money(n0(u['furn']))} فرش) ÷ ${_r2(truthy(u['cm']) ? n(u['cm']) : 12)}'))
      ..add(eqN('متوسط الإيجار الشهري', money(k), 'إيراد العقود ${money((P['inc'] as double) / (f == 0 ? 1 : f))} ÷ ${_r2(mo)} شهر'))
      ..add(eqR('ربح الشهر × الشهور', (k - mc) * mo * f, '(${money(k)} − ${money(mc)}) × ${_r2(mo)} شهر'));
    if (F != 0) rows.add(eqN('أيام مجانية من الشركة', '${F.round()} يوم'));
    if (gap != 0) rows.add(eqN('أيام فاضية', '$gap يوم'));
    if (adj.abs() > .5) rows.add(eqR(adj > 0 ? 'خصم الأيام الفاضية الزيادة' : 'مكسب الأيام المجانية', -adj * f, 'سعر اليوم ${money(mc / 30)}'));
    if (sv != 0) rows.add(eqR('استرداد الأثاث', sv * f));
  }
  final W = e.annW(); if ((W['gx'] as double) != 0) rows.add(eqR('مصروفات عامة', -(W['gx'] as double)));
  if (rows.isEmpty) rows.add(eqMu('مفيش عقود مستأجرين.'));
  rows.add(eqT('الربح المتوقع على مدة العقود', money(W['p'] as double)));
  eqSheet(context, 'الربح المتوقع على مدة العقود', rows);
}

/* ───────── 📊 التحليل المالي (6 مؤشرات، كل واحد بيفتح حسبته) ───────── */
class Kpi { final String l, v, sub; final Color c; final void Function(BuildContext) open; Kpi(this.l, this.v, this.sub, this.c, this.open); }

List<Kpi> kpis(Engine e) {
  final t = today(); final out = <Kpi>[];
  // الإشغال الحالي
  { var a = 0, o = 0; final rows = <Widget>[];
    for (final u in e.SU()) {
      final b = pd(u['start']), en = addM(b, n0(u['cm'])); var b0 = b; for (final L in objs(u['leases'])) { final s = pd(L['start']); if (s.isBefore(b0)) b0 = s; }
      if (!(!b0.isAfter(t) && t.isBefore(en))) continue; a++;
      final L = objs(u['leases']).where((L) => !pd(L['start']).isAfter(t) && t.isBefore(truthy(L['exit']) ? pd(L['exit']) : Engine.lend(L))).firstOrNull;
      if (L != null) o++;
      rows.add(eqN(str(u['name']), L != null ? '🟢 ${str(L['tenant']).isEmpty ? 'مؤجر' : str(L['tenant'])}' : '⚪ شاغر'));
    }
    rows..add(eqN('مؤجّر اليوم', '$o من $a'))..add(eqT('الإشغال الحالي', a > 0 ? _pc(o / a * 100) : '—'));
    out.add(Kpi('الإشغال الحالي', a > 0 ? _pc(o / a * 100) : '—', '$o من $a استديو مؤجَّر اليوم', kAc, (c) => eqSheet(c, 'الإشغال الحالي', rows))); }
  // الإشغال على مدة العقود
  { var m = 0.0, oc = 0.0; final rows = <Widget>[];
    for (final u in _live(e)) { final w = e.winU(u); if (w == null) continue; m += w['mW'] as double; oc += w['oc'] as double;
      rows.add(eqN(str(u['name']), '${_r2(w['oc'] as double)} من ${_r2(w['mW'] as double)} شهر', '${fdd(w['s'] as DateTime)} ← ${fdd(w['e'] as DateTime)}')); }
    rows..add(eqN('الإجمالي', '${_r2(oc)} ÷ ${_r2(m)} شهر'))..add(eqT('الإشغال على مدة العقود', m > 0 ? _pc(oc / m * 100) : '—'));
    out.add(Kpi('الإشغال على مدة العقود', m > 0 ? _pc(oc / m * 100) : '—', 'الشهور المؤجّرة من استلام الشركة حتى آخر عقد', kAc, (c) => eqSheet(c, 'الإشغال على مدة العقود', rows))); }
  // هامش الربح / العائد على التكلفة
  var inc = 0.0, cw = 0.0; for (final u in e.SU()) { final a = e.ua(u), P = e.projU(u); inc += a['inc']!; cw += P != null ? P['cost'] as double : a['cost']!; }
  { final p = inc - cw; final v = inc != 0 ? _pc(p / inc * 100) : '—';
    out.add(Kpi('هامش الربح', v, 'الربح ÷ الإيراد على مدة العقود', p >= 0 ? kGreen : kRed, (c) => eqSheet(c, 'هامش الربح', [eqR('إيراد العقود', inc), eqR('التكلفة على مدة العقود', -cw), eqN('الربح', money(p)), eqN('المعادلة', '${money(p)} ÷ ${money(inc)} × 100'), eqT('هامش الربح', v)]))); }
  { final a = e.annW()['p'] as double; final v = cw != 0 ? _pc(a / cw * 100) : '—';
    out.add(Kpi('العائد على التكلفة', v, 'الربح المتوقع ÷ التكلفة على مدة العقود', a >= 0 ? kGreen : kRed, (c) => eqSheet(c, 'العائد على التكلفة', [eqN('الربح المتوقع على مدة العقود', money(a)), eqN('التكلفة على مدة العقود', money(cw)), eqN('المعادلة', '${money(a)} ÷ ${money(cw)} × 100'), eqT('العائد على التكلفة', v)]))); }
  // نقطة التعادل
  { final rents = <double>[]; var cost = 0.0, pot = 0.0, cmT = 0.0;
    for (final u in e.SU()) { cost += e.ua(u)['cost']!; for (final L in objs(u['leases'])) { rents.add(n0(L['rent']) + n0(L['inet'])); } }
    final avg = rents.isEmpty ? 0.0 : rents.reduce((a, b) => a + b) / rents.length;
    for (final u in e.SU()) { pot += n0(u['cm']) * avg * e.sh(u); cmT += n0(u['cm']); }
    final v = pot != 0 ? _pc(cost / pot * 100) : '—';
    out.add(Kpi('نقطة التعادل (إشغال)', v, 'أقل إشغال لتغطية كل التكاليف بمتوسط إيجار ${money(avg)}', kAc, (c) => eqSheet(c, 'نقطة التعادل (إشغال)', [eqN('متوسط الإيجار الشهري', money(avg)), eqN('شهور عقود الشركات', '${_r2(cmT)} شهر'), eqN('أقصى إيراد ممكن', money(pot), '${money(avg)} × ${_r2(cmT)}'), eqN('كل التكاليف', money(cost), 'شركة + فرش − أثاث مسترد'), eqN('المعادلة', '${money(cost)} ÷ ${money(pot)} × 100'), eqT('نقطة التعادل', v)]))); }
  // نسبة التحصيل
  { var due = 0.0, got = 0.0; final rows = <Widget>[];
    for (final u in e.SU()) { final f = e.sh(u); for (final L in objs(u['leases'])) { final rc = Engine.rcv(L); for (var i = 0; i < Engine.months(L); i++) { if (!Engine.payD(L, i).isAfter(t)) { final a = Engine.la(L, i) * f, ok = rc.contains(i); due += a; if (ok) got += a;
      rows.add(eqN('${str(L['tenant']).isEmpty ? 'مستأجر' : str(L['tenant'])} • دفعة ${i + 1}', '${ok ? '✅ ' : '⏳ '}${money(a)}', str(u['name']))); } } } }
    final v = due != 0 ? _pc(got / due * 100) : '—';
    rows..add(eqN('المحصّل ÷ المستحق', '${money(got)} ÷ ${money(due)}'))..add(eqT('نسبة التحصيل', v));
    out.add(Kpi('نسبة التحصيل', v, 'المحصّل ${money(got)} من المستحق ${money(due)}', got >= due ? kGreen : kRed, (c) => eqSheet(c, 'نسبة التحصيل', rows))); }
  return out;
}

void analysisSheet(BuildContext context, Engine e) {
  final K = kpis(e);
  eqSheet(context, 'التحليل المالي', icon: '📊', [
    for (final k in K) Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(
      borderRadius: BorderRadius.circular(16), onTap: () => k.open(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4F7FD), Colors.white]), border: Border.all(color: const Color(0xFFD5DEF2))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k.l, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF3B4250))),
            Text(Priv.on ? '•••' : k.v, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: k.c)),
            Text(Priv.txt(k.sub), style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w600)),
          ])),
          const Text('🧮', style: TextStyle(fontSize: 20)),
        ]),
      ),
    )),
  ]);
}

/* ───────── 🏆 مقارنة الاستديوهات (compCard) ───────── */
void compareSheet(BuildContext context, Engine e) {
  final t = today(); final rows = <Map<String, dynamic>>[];
  for (final u in e.SU()) {
    final f = e.sh(u), cm = truthy(u['cm']) ? n(u['cm']) : 12.0, T = truthy(u['total']) ? n(u['total']) : Engine.isumOf(u), mc = (T + n0(u['furn'])) / cm;
    final s0 = pd(u['start']), e0 = addM(s0, cm), end = e0.isBefore(t) ? e0 : t; if (!s0.isBefore(t)) continue;
    final span = math.max(1.0, (ms(end) - ms(s0)) / 864e5); var occd = 0.0, R = 0.0, mo = 0.0;
    for (final L in objs(u['leases'])) {
      final a = math.max(ms(pd(L['start'])), ms(s0)), b = math.min(ms(truthy(L['exit']) ? pd(L['exit']) : Engine.lend(L)), ms(end)); if (b > a) occd += (b - a) / 864e5;
      for (final i in Engine.rcv(L)) { if (i >= Engine.months(L)) continue; R += _rv(L, i) + Engine.ppA(L, i); mo += Engine.lf(L, i); }
    }
    occd = math.min(occd, span); var ex = 0.0;
    for (final x in e.SE()) { if (x['u'] != u['id']) continue; final cnt = truthy(x['n']) ? n(x['n']).toInt() : 1; for (var i = 0; i < cnt; i++) { if (!addM(pd(x['d']), i).isAfter(t)) ex += n0(x['a']) * f; } }
    final cur = objs(u['leases']).where((L) => !truthy(L['exit']) && !pd(L['start']).isAfter(t) && Engine.lend(L).isAfter(t)).firstOrNull;
    rows.add({'u': u, 'occ': occd / span * 100, 'vac': (span - occd).round(), 'pr': (R - mc * mo) * f - ex, 'rent': cur == null ? 0.0 : n0(cur['rent'])});
  }
  if (rows.isEmpty) { eqSheet(context, 'مقارنة الاستديوهات', [eqMu('مفيش استديوهات بدأت لسه.')], icon: '🏆'); return; }
  rows.sort((a, b) => (b['pr'] as double).compareTo(a['pr'] as double));
  final best = rows.first, worst = ([...rows]..sort((a, b) => (b['vac'] as int).compareTo(a['vac'] as int))).first;
  Widget hi(String t1, Obj u, String v) => Expanded(child: Container(
        padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF4F7FA), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDDE3EA))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t1, style: const TextStyle(fontSize: 12.5, color: kMuted, fontWeight: FontWeight.w700)), Text(Priv.un(u['name']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))]),
      ));
  eqSheet(context, 'مقارنة الاستديوهات', icon: '🏆', [
    if (rows.length > 1) Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: Row(children: [hi('🥇 الأكسب', best['u'] as Obj, money(best['pr'] as double)), const SizedBox(width: 10), hi('💤 قعد فاضي أكتر', worst['u'] as Obj, '${worst['vac']} يوم فاضي')])),
    for (var i = 0; i < rows.length; i++) Builder(builder: (_) {
      final x = rows[i], pr = x['pr'] as double, oc = math.min(100.0, math.max(0.0, x['occ'] as double));
      Widget kv(String l, Widget v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 12, color: kMuted, fontWeight: FontWeight.w700)), v]));
      return Container(
        margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFDDE3EA))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i == 0 && rows.length > 1 ? '🥇 ' : ''}${Priv.un((x['u'] as Obj)['name'])}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5)),
          const Divider(),
          Row(children: [kv('الربح', ptxt(moneyRaw(pr), style: TextStyle(fontWeight: FontWeight.w900, color: sign(pr)))), kv('الإشغال', Row(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: oc / 100, minHeight: 7, backgroundColor: const Color(0xFFE3E8EE), color: kTeal))),
            const SizedBox(width: 6), Text('${oc.round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]))]),
          const SizedBox(height: 8),
          Row(children: [kv('أيام فاضي', Text('${x['vac']}', style: TextStyle(fontWeight: FontWeight.w900, color: (x['vac'] as int) > 0 ? kRed : kInk))), kv('الإيجار', Text((x['rent'] as double) > 0 ? money(x['rent'] as double) : '—', style: const TextStyle(fontWeight: FontWeight.w800)))]),
        ]),
      );
    }),
    const Padding(padding: EdgeInsets.only(top: 12), child: Text('الربح = الإيجار المقبوض − تكلفة نفس المدة (عقد الشركة + الفرش ÷ مدة العقد) − مصاريف الاستديو. الإشغال وأيام الفاضي من استلام الاستديو من الشركة لحد النهارده.', style: TextStyle(fontSize: 12.5, color: kMuted))),
  ]);
}

/* ───────── جدول بندين (البند / المبلغ) زي tbl ───────── */
Widget kvTable(List<List<dynamic>> rows) => Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB9C0CC))),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Column(children: [
        Container(color: const Color(0xFFF1F3F7), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: const Row(children: [Expanded(child: Text('البند', style: TextStyle(fontWeight: FontWeight.w800))), Text('المبلغ', style: TextStyle(fontWeight: FontWeight.w800))])),
        for (final r in rows) Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFDDE1E8)))),
          child: Row(children: [
            Expanded(child: Text(r[0] as String, style: TextStyle(fontWeight: r.length > 2 && r[2] == true ? FontWeight.w900 : FontWeight.w600, fontSize: 13.5))),
            const SizedBox(width: 10),
            ptxt(moneyRaw(r[1] as num), style: TextStyle(fontWeight: FontWeight.w900, color: r.length > 2 && r[2] == true ? sign(r[1] as num) : kInk)),
          ]),
        ),
      ])),
    );

/// وضعي المالي اليوم (fpTbl)
List<List<dynamic>> fpRows(Engine e) {
  final F = e.fpos(); final r = <List<dynamic>>[['الرصيد النقدي', F['cash']!]];
  void rw(String l, double v) { if (v.abs() >= .5) r.add([l, v]); }
  rw('مستحقاتي لدى المستأجرين (إيجارات حل موعدها ولم تُحصَّل)', F['rcv']!); rw('إيجار عن أيام مضت لم يحل موعد دفعه', F['accU']!); rw('إيجار شركة مدفوع مقدماً (لأيام لم تأتِ بعد)', F['preCo']!);
  rw('إنترنت وراوتر مدفوع مقدماً', F['preI']!); rw('رأس مال الفرش اللي لسه ما اتردش (بيترد مع كل شهر إيجار بتقبضه)', F['fur']!); rw('تأمينات دفعتها للشركات', F['depP']!); rw('حصتي من فلوس الشراكة المتبقية', F['gpm']!);
  r.add(['إجمالي ما أملكه', F['A']!, true]);
  rw('يجب أن أدفعه الآن (دفعات شركة تجاوزت موعدها)', -F['due']!); rw('إيجار شركة مستحق عن أيام مضت (لم يحل موعد دفعه)', -F['accCo']!); rw('إيجارات مقبوضة أو مستحقة عن أيام لم تأتِ بعد (التزام حتى تنقضي)', -F['unr']!);
  rw('أثاث لم يُدفع ثمنه بعد', -F['furPay']!); rw('تأمينات المستأجرين عندي (تُرد لهم)', -F['depH']!); rw('حصة الشركاء من النقدي اللي معايا', -F['ptn']!);
  r.add(['صافي رصيدي', F['eq']!, true]);
  return r;
}

/// 📋 الحركة النقدية (ما دخل وخرج فعلياً)
void cashflowSheet(BuildContext context, Engine e) {
  final lg = e.ledger(); double sm(String c) => lg.where((x) => x['c'] == c).fold(0.0, (s, x) => s + (x['a'] as double));
  final rn = sm('rn'), pn = sm('pn'), co = -sm('co'), fu = -sm('fu'), is_ = -sm('is'), ex = -sm('ex'); final R = rn + pn, E = co + fu + is_ + ex;
  var gi = 0.0, go = 0.0; final G = obj(e.S['gp']) ?? {};
  G.forEach((g, l) { if (e.WS != 'all' && e.WS != g) return; final f = e.shg(g); for (final x in objs(l)) { final a = n0(x['a']); if (a > 0) { gi += a * f; } else if (!truthy(x['key'])) { go += -a * f; } } });
  eqSheet(context, 'الحركة النقدية (ما دخل وخرج فعلياً)', icon: '📋', [
    kvTable([['إيجارات المستأجرين', rn], ['شرط جزائي', pn], if (gi != 0) ['فلوس الشركاء (تمويل)', gi], ['إجمالي الدخل', R + gi, true], if (go != 0) ['سحب من فلوس الشراكة', -go], ['إيجار الشركة المدفوع', -co], ['الأثاث (المدفوع)', -fu], if (is_ != 0) ['الإنترنت والراوتر', -is_], ['مصروفات أخرى', -ex], ['صافي الحركة النقدية', R + gi - go - E, true]]),
    eqMu('ده كل اللي دخل وخرج بتاريخه. أي قسط أو أثاث مدفوع مقدماً بيتحسب كله هنا.'),
  ]);
}

/// 📋 الربح المحاسبي (موزع على الشهور)
void accrualSheet(BuildContext context, Engine e) {
  final A = e.accr();
  eqSheet(context, 'الربح المحاسبي (موزع على الشهور)', icon: '📋', [
    kvTable([['إيجارات المستأجرين (الأشهر المنقضية)', A['rentE']!], ['شرط جزائي', A['pen']!], ['إجمالي الدخل', A['earned']!, true], ['إيجار الشركة (موزع على أيام العقد)', -A['coC']!], ['استرداد رأس مال الفرش (موزع على شهور عقد الشركة)', -A['fuC']!], if (A['isC']! != 0) ['الإنترنت والراوتر', -A['isC']!], ['مصروفات (في شهرها)', -A['exC']!], ['الربح الصافي', A['profit']!, true]]),
    eqMu('إيجار كل شهر بيتوزع على أيامه (من ميعاد دفعه لميعاد الدفعة اللي بعدها)، والتكلفة بتتوزع على أيام العقد سواء الاستديو مشغول أو فاضي. الإيجار المقبوض عن أيام لسه مجتش مش بيتحسب إيراد غير لما أيامه تعدي.'),
  ]);
}

/// 🧾 سندات القبض: آخر الإيجارات المستلمة — دوس على 🧾 تبعت سند للمستأجر
void receiptsSheet(BuildContext context, Engine e) {
  final r = <Map<String, dynamic>>[];
  for (final u in e.SU()) { for (final L in objs(u['leases'])) { for (final i in Engine.rcv(L)) { if (i >= Engine.months(L)) continue; r.add({'u': u, 'L': L, 'i': i, 'd': iso(Engine.payD(L, i)), 'a': _rv(L, i)}); } } }
  r.sort((a, b) => str(b['d']).compareTo(str(a['d'])));
  eqSheet(context, 'سندات القبض', icon: '🧾', [
    eqMu('آخر الإيجارات المستلمة. دوس 🧾 علشان تبعت سند قبض للمستأجر.'),
    if (r.isEmpty) eqMu('مفيش إيجارات مستلمة لسه.'),
    for (final x in r.take(40)) Builder(builder: (_) {
      final u = x['u'] as Obj, L = x['L'] as Obj, tn = str(L['tenant']).isEmpty ? 'مستأجر' : str(L['tenant']);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE6E8EE)))),
        child: Row(children: [
          Expanded(child: Text('$tn • ${Priv.un(u['name'])}  ${x['d']}', style: const TextStyle(fontWeight: FontWeight.w800))),
          ptxt(moneyRaw(x['a'] as double), style: const TextStyle(fontWeight: FontWeight.w900, color: kGreen)),
          const SizedBox(width: 8),
          InkWell(borderRadius: BorderRadius.circular(99), onTap: () => Share.share('🧾 سند قبض\nاستلمنا من: $tn\nالمبلغ: ${money(x['a'] as double)} درهم\nإيجار ${str(u['name'])} — دفعة ${(x['i'] as int) + 1}\nبتاريخ: ${x['d']}\nBunyan Furnished'),
            child: Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kBd)), child: const Text('🧾'))),
        ]),
      );
    }),
  ]);
}

/// 📤 تصدير للمحاسب: الدفتر كـ CSV يفتح في Excel
Future<void> exportCsv(Engine e) async {
  final b = StringBuffer('﻿التاريخ,الاستديو,البيان,المبلغ\n');
  String q(String s) => '"${s.replaceAll('"', '""')}"';
  for (final x in e.ledger()) { b.writeln('${x['d']},${q(str(x['u']))},${q(str(x['w']))},${(x['a'] as double).round()}'); }
  await Share.shareXFiles([XFile.fromData(Uint8List.fromList(utf8.encode(b.toString())), mimeType: 'text/csv', name: 'bunyan-ledger-${iso(today())}.csv')], text: 'دفتر حسابات بنيان');
}

/// 📅 الدفعات القادمة: كل دفعة شركة هتتغطى منين (زي القديم)
void coverageSheet(BuildContext context, Engine e) {
  final all = e.items().where((x) => x['ty'] == 'rent' || x['ty'] == 'inst').toList()..sort((a, b) => str(a['d']).compareTo(str(b['d'])));
  final fut = all.where((x) => Engine.dd(x['d']) >= 0).toList();
  final pays = fut.where((x) => x['ty'] == 'inst').toList();
  final inc = fut.where((x) => x['ty'] == 'rent').fold(0.0, (s, x) => s + n0(x['amt']));
  final out = pays.fold(0.0, (s, x) => s + n0(x['amt']).abs());
  var bal = e.cashNow(); var prev = '';
  final rows = <Widget>[
    Container(
      margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF2F8F5), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('هتستلم', style: TextStyle(color: kMuted, fontWeight: FontWeight.w700)), ptxt(moneyRaw(inc), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kGreen))])),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('هتدفع', style: TextStyle(color: kMuted, fontWeight: FontWeight.w700)), ptxt(moneyRaw(out), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: kRed))])),
      ]),
    ),
    const Padding(padding: EdgeInsets.only(top: 16, bottom: 4), child: Text('🧾 كل دفعة هتتغطى منين', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
  ];
  var k = 0;
  for (final p in pays) {
    k++; final d = str(p['d']);
    final rents = fut.where((x) => x['ty'] == 'rent' && str(x['d']).compareTo(prev) > 0 && str(x['d']).compareTo(d) <= 0).fold(0.0, (s, x) => s + n0(x['amt']));
    final have = bal + rents, a = n0(p['amt']).abs(), left = have - a; final dd = Engine.dd(d);
    rows.add(Container(
      margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: left < 0 ? const Color(0xFFF2B8B8) : const Color(0xFFCFE6DE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$k) ⬆️ ${Priv.txt(str(p['label']))}', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(children: [Text(fdd(pd(d)), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: dd <= 7 ? kTerra : kGreen, borderRadius: BorderRadius.circular(99)), child: Text('بعد $dd يوم', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)))]),
        const SizedBox(height: 4),
        _cv(k == 1 ? 'الرصيد اللي معاك دلوقتي' : 'متبقي من الدفعة اللي قبلها', bal, kInk),
        _cv('+ إيجارات هتوصل قبلها', rents, kGreen),
        _cv('= هيبقى معاك', have, kInk),
        _cv('− الدفعة', a, kRed),
        const Divider(height: 12),
        _cv(left >= 0 ? '✅ يفضل معاك ويترحّل للدفعة اللي بعدها' : '⚠️ ناقص — محتاج تحط فلوس', left, left >= 0 ? kGreen : kRed),
      ]),
    ));
    bal = left; prev = d;
  }
  if (pays.isEmpty) rows.add(eqMu('✅ مفيش دفعات شركة جاية.'));
  eqSheet(context, 'الدفعات القادمة (${fut.length})', icon: '📅', rows);
}
Widget _cv(String l, double v, Color c) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(child: Text(l, style: const TextStyle(fontWeight: FontWeight.w600))), ptxt(moneyRaw(v), style: TextStyle(fontWeight: FontWeight.w900, color: c))]));

/// 🕘 آخر التعديلات
void lastEditsSheet(BuildContext context) {
  final H = objs(Store.I.S['hist']).where((x) => !RegExp(r'تسجيل (دخول|خروج)|تنزيل|نسخة احتياطية').hasMatch(str(x['d']))).take(12).toList();
  eqSheet(context, 'آخر التعديلات', icon: '🕘', [
    if (H.isEmpty) eqMu('مفيش تعديلات لسه.'),
    for (final x in H) Container(
      padding: const EdgeInsets.symmetric(vertical: 10), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE6E8EE)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Priv.txt(str(x['d'])), style: const TextStyle(fontWeight: FontWeight.w800)),
        Text('${str(x['by'])}${n0(x['t']) > 0 ? ' • ${fdt(n0(x['t']))}' : ''}', style: const TextStyle(fontSize: 12, color: kMuted)),
      ]),
    ),
    Padding(padding: const EdgeInsets.only(top: 12), child: OutlinedButton(onPressed: () { Navigator.of(context).pop(); Shell.go(5); }, child: const Text('📜 سجل التعديلات كله'))),
  ]);
}

/* ───────── كارت-زرار: دوسة على الكارت كله تفتح الشاشة — أيقونة ملوّنة + عنوان + سطر صغير ───────── */
class TCard extends StatelessWidget {
  final String ic, t; final String? sub; final Color c; final VoidCallback onTap;
  const TCard(this.ic, this.t, {super.key, this.sub, this.c = const Color(0xFF3B82F6), required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16), onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [Color.lerp(Colors.white, c, .10)!, Colors.white]),
              borderRadius: BorderRadius.circular(16), border: Border.all(color: Color.lerp(Colors.white, c, .28)!),
              boxShadow: const [BoxShadow(color: Color(0x0F14213D), blurRadius: 10, offset: Offset(0, 3))]),
            child: Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 10), child: Row(children: [
              Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: Color.lerp(Colors.white, c, .18), borderRadius: BorderRadius.circular(12)), child: Text(ic, style: const TextStyle(fontSize: 20))),
              const SizedBox(width: 9),
              Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, maxLines: 2, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, height: 1.25, color: Color.lerp(kInk, c, .25))),
                if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(Priv.txt(sub!), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: kMuted, fontWeight: FontWeight.w600, height: 1.3))),
              ])),
              Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right, size: 18, color: c.withOpacity(.7)),
            ])),
          ),
        ),
      );
}

/// صف كارتين جنب بعض
Widget tRow(List<Widget> a) => Padding(padding: const EdgeInsets.only(bottom: 8), child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < a.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: a[i])],
      if (a.length == 1) ...[const SizedBox(width: 8), const Expanded(child: SizedBox())],
    ])));

/* ───────── ⏰ المتأخرات ───────── */
class ArrearsCard extends StatelessWidget {
  final Engine e;
  const ArrearsCard(this.e, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = today(); final l = <Widget>[];
    for (final u in e.SU()) { final f = e.sh(u); for (final L in objs(u['leases'])) { final rc = Engine.rcv(L); for (var i = 0; i < Engine.months(L); i++) {
      final d = Engine.payD(L, i); if (d.isAfter(t) || rc.contains(i)) continue;
      l.add(_cv('${str(L['tenant']).isEmpty ? 'مستأجر' : str(L['tenant'])} • ${Priv.un(u['name'])} — ${iso(d)} (متأخر ${t.difference(d).inDays} يوم)', Engine.la(L, i) * f, kRed)); } } }
    return BCard(c: kOk, title: '⏰ المتأخرات', child: l.isEmpty ? const Text('لا توجد إيجارات متأخرة 👌', style: TextStyle(color: kGreen, fontWeight: FontWeight.w800)) : Column(children: l));
  }
}

