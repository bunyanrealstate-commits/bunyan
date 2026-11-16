import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/unit.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';

/// 🔁 تجديد عقد الشركة (renBox/renAmt/renDo/renSet) + 🎁 أيام السماح (graceBox) — نفس القديم
class RenBox extends StatelessWidget {
  final Obj u; final VoidCallback onChange;
  const RenBox(this.u, this.onChange, {super.key});
  @override
  Widget build(BuildContext context) {
    final ce = addM(pd(u['start']), n0(u['cm'])); final nd = ((ms(ce) - ms(today())) / 864e5).round();
    if (nd > 120) return const SizedBox.shrink();
    final a = Engine.renEst(u); final cur = objs(u['leases']).where((L) => !truthy(L['exit']) && Engine.lend(L).isAfter(ce)).toList();
    final no = u['ren'] == 'no'; final set = u['renA'] != null && u['renA'] != '';
    final col = no ? Colors.blueGrey : (nd < 0 ? kRed : Colors.orange);
    return Card(shape: RoundedRectangleBorder(side: BorderSide(color: col, width: 1.5), borderRadius: BorderRadius.circular(14)), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(no ? L.t('🚫 مش هتجدد عقد الشركة') : '🔁 عقد الشركة ${nd < 0 ? 'خلص من ${-nd} يوم' : 'بيخلص بعد $nd يوم'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      Text('آخر يوم: ${iso(ce)} — ${str(u['company']).isEmpty ? 'الشركة' : str(u['company'])}'),
      if (!no) Text('💰 الدفعة الأولى للتجديد: ${a != 0 ? money(a) : '—'} ${set ? '(كتبتها انت)' : a != 0 ? '(تقديري = أول دفعة في العقد الحالي)' : '(اكتب المبلغ)'}'),
      if (!no) Text('📅 هتدفعها يوم ${truthy(u['renD']) ? str(u['renD']) : iso(ce)} — ومحسوبة في الدفعات القادمة'),
      if (cur.isNotEmpty) Text(no ? '⚠️ عقد «${str(cur[0]['tenant'])}» بيخلص بعده — لازم يخرج قبل ${iso(ce)}' : '👤 عقد «${str(cur[0]['tenant'])}» شغال بعد ما عقد الشركة يخلص — التجديد ضروري', style: TextStyle(color: no ? kRed : kMuted, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: no
          ? [OutlinedButton(onPressed: () => _set('ren', null), child: Text(L.t('↩ لأ، هجدد')))]
          : [
              FilledButton(onPressed: () => _do(context), child: Text(L.t('✅ جدّدت — سجّل العقد الجديد'))),
              OutlinedButton(onPressed: () => _amt(context), child: Text(L.t('✏️ مبلغ وميعاد التجديد'))),
              TextButton(onPressed: () => _set('ren', 'no'), child: Text(L.t('🚫 مش هجدد'))),
            ]),
    ])));
  }

  Future<void> _set(String k, dynamic v) async { if (v == null || v == '') { u.remove(k); } else { u[k] = v; } await Store.I.save(log: '🔁 تجديد عقد الشركة — ${str(u['name'])}: ${v == 'no' ? 'مش هجدد' : 'هجدد'}'); onChange(); }

  Future<void> _amt(BuildContext context) async {
    final ce = iso(addM(pd(u['start']), n0(u['cm'])));
    final o = await formDlg(context, '🔁 تجديد عقد «${str(u['name'])}»', [FieldSpec('a', L.t('مبلغ الدفعة الأولى للتجديد'), type: 'n', v: Engine.renEst(u) != 0 ? Engine.renEst(u).round() : ''), FieldSpec('d', L.t('هتدفعها يوم'), type: 'd', v: truthy(u['renD']) ? u['renD'] : ce)]);
    if (o == null) return;
    final a = double.tryParse(o['a'] ?? '') ?? 0; u['renA'] = a == a.roundToDouble() ? a.toInt() : a;
    if (truthy(o['d']) && o['d'] != ce) { u['renD'] = o['d']; } else { u.remove('renD'); }
    await Store.I.save(log: '🔁 مبلغ تجديد ${str(u['name'])}: ${money(a)}');
    if (context.mounted) toast(context, L.t('✅ اتسجل — هيظهر في الدفعات القادمة'));
    onChange();
  }

  Future<void> _do(BuildContext context) async {
    final ce = addM(pd(u['start']), n0(u['cm'])); final nr = objs(u['inst']).where((i) => !truthy(i['rn'])).toList();
    final rh = objs(u['renHist']); final last = rh.isNotEmpty ? rh.last : null;
    final usedCm = rh.fold<double>(0, (s, h) => s + n0(h['cm'])); final baseCm = n0(u['cm']) - usedCm;
    final o = await formDlg(context, '✅ تجديد عقد «${str(u['name'])}» مع ${str(u['company']).isEmpty ? 'الشركة' : str(u['company'])}', [
      FieldSpec('cm', L.t('مدة العقد الجديد (شهور)'), type: 'n', v: last != null && truthy(last['cm']) ? last['cm'] : 12),
      FieldSpec('total', L.t('إجمالي العقد الجديد'), type: 'n', v: last != null && truthy(last['total']) ? last['total'] : (truthy(u['total']) && truthy(u['cm']) ? (n(u['total']) / (baseCm != 0 ? baseCm : n(u['cm'])) * 12).round() : '')),
      FieldSpec('n', L.t('عدد الدفعات'), type: 'n', v: last != null && truthy(last['n']) ? last['n'] : (nr.isNotEmpty ? nr.length : 4)),
      FieldSpec('first', L.t('الدفعة الأولى'), type: 'n', v: Engine.renEst(u) != 0 ? Engine.renEst(u).round() : ''),
      FieldSpec('pstart', L.t('ميعاد الدفعة الأولى'), type: 'd', v: truthy(u['renD']) ? u['renD'] : iso(ce)),
    ]);
    if (o == null) return;
    final cm = (double.tryParse(o['cm'] ?? '') ?? 12).clamp(1, 999).toDouble(); var T = double.tryParse(o['total'] ?? '') ?? 0;
    final N = ((double.tryParse(o['n'] ?? '') ?? 1).round()).clamp(1, 999); final F1 = double.tryParse(o['first'] ?? '') ?? 0;
    if (T == 0 && F1 == 0) { if (context.mounted) toast(context, L.t('اكتب إجمالي العقد أو الدفعة الأولى')); return; }
    if (T == 0) T = F1 * N;
    final op = UnitOps(Store.I.S, uid: Act.uid, now: Act.now(), td: Act.td());
    final sc = op.sched(total: T, cm: cm, nn: N, first: F1 != 0 ? F1 : (T / N).roundToDouble(), pstart: truthy(o['pstart']) ? o['pstart']! : iso(ce), start: iso(ce));
    final inst = (u['inst'] as List?) ?? (u['inst'] = <dynamic>[]);
    for (final x in sc) { inst.add({'d': x['d'], 'a': x['a'], 'p': false, 'at': 0, 'rn': 1}); }
    final hist = (u['renHist'] as List?) ?? (u['renHist'] = <dynamic>[]);
    num nm(double v) => v == v.roundToDouble() ? v.toInt() : v;
    hist.add({'at': Act.now(), 'start': iso(ce), 'cm': nm(cm), 'total': nm(T), 'n': N});
    u['cm'] = nm(n0(u['cm']) + cm); u['total'] = nm(n0(u['total']) + T); u.remove('renA'); u.remove('renD'); u.remove('ren');
    await Store.I.save(log: '🔁 جددت عقد الشركة — ${str(u['name'])} ($N دفعات)');
    if (context.mounted) toast(context, '✅ اتجدد لحد ${iso(addM(pd(u['start']), n0(u['cm'])))} — $N دفعات اتضافت');
    onChange();
  }
}

class GraceBox extends StatelessWidget {
  final Obj u;
  const GraceBox(this.u, {super.key});
  @override
  Widget build(BuildContext context) {
    final o = Engine(Store.I.S, WS: 'all').gi(u);
    final g = o['g'] as int, B = o['B'] as int, vp = o['vp'] as int, vf = o['vf'] as int; final c = o['c'] as double, dr = o['dr'] as double; final now = o['now'] == true;
    if (g == 0 && !now && vp == 0) return const SizedBox.shrink();
    final t = today(); final nx = o['nextIn'] as DateTime?, since = o['since'] as DateTime?, lastOut = o['lastOut'] as DateTime?, ce = o['ce'] as DateTime;
    final lines = <Widget>[
      Text('🎁 أيام السماح من الشركة: $g يوم', style: const TextStyle(fontWeight: FontWeight.w900)),
      if (g > 0) Text('(الشركة رحّلت عقدها من ${iso(o['H'] as DateTime)} لـ ${iso(o['cs'] as DateTime)})', style: const TextStyle(fontSize: 12, color: kMuted)),
      if (g > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: LinearProgressIndicator(value: (B / g).clamp(0, 1).toDouble(), color: kGreen, backgroundColor: kSand)),
      Text('📭 أيام فاضية لحد النهارده: $vp يوم${g > 0 ? ' — اتخصمت من أيام السماح' : ''}'),
      Text(B >= 0 ? '✅ فاضلك $B يوم سماح${B > 0 && dr > 0 ? ' — لو ما اتصرفوش = مكسب زيادة ≈ ${money(B * dr)}' : ''}' : '❌ ${g > 0 ? 'خلصت أيام السماح' : 'مفيش أيام سماح'} — ${-B} يوم فاضي = خسارة ≈ ${money(-B * c)} (${money(c)} في اليوم)', style: TextStyle(color: B >= 0 ? kGreen : kRed, fontWeight: FontWeight.bold)),
      if (now && nx != null) Text('🟡 فاضي من ${iso(since!)} لحد ما المستأجر الجاي يدخل يوم ${iso(nx)} (${Engine.dy(t, nx)} يوم كمان)'),
      if (now && nx == null) Text('🔴 الاستديو فاضي من ${iso(since!)}${B > 0 ? ' — قدامك $B يوم وبعدها كل يوم فاضي خسارة ${money(c)}' : ' — كل يوم فاضي دلوقتي خسارة ${money(c)}'}', style: const TextStyle(color: kRed)),
      if (!now && vf > 0 && lastOut != null && lastOut.isBefore(ce)) Text('⏳ بعد ما عقد المستأجر يخلص (${iso(lastOut)}) لو مالقيتش مستأجر: ${B > 0 ? 'معاك $B يوم سماح، وبعدها ' : ''}كل يوم خسارة ${money(c)}'),
    ];
    return Card(color: const Color(0xFFF3FAF6), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines)));
  }
}
