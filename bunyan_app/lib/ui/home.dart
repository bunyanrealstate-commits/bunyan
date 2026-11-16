import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';
import 'units.dart';
import 'dialogs.dart';
import '../core/actions.dart';
import 'lease_edit.dart';
import 'monitor.dart';

/// 🔄 عقود قربت تخلص — هتجدد؟ (renewCard)
class _Renew extends StatelessWidget {
  final Engine e;
  const _Renew(this.e);
  @override
  Widget build(BuildContext context) {
    final R = e.renewList(Store.I.snz);
    if (R.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 14), child: BCard(c: const Color(0xFF0891B2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(Tr.t('🔄 عقود قربت تخلص — هتجدد؟'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      for (final x in R) Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${str((x['L'] as Obj)['tenant']).isEmpty ? 'مستأجر' : str((x['L'] as Obj)['tenant'])} — ${Priv.un((x['u'] as Obj)['name'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
        Text('${(x['n'] as int) > 0 ? 'بيخلص بعد ${x['n']} يوم' : (x['n'] == 0 ? 'بيخلص النهارده' : 'خلص من ${-(x['n'] as int)} يوم')} • ${iso(x['e'] as DateTime)}', style: const TextStyle(fontSize: 12, color: kMuted)),
        Wrap(spacing: 6, children: [
          FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaseEdit(x['u'] as Obj, null, renew: x['L'] as Obj))), child: Text(Tr.t('🔄 تجديد'))),
          OutlinedButton(onPressed: () async { final u = x['u'] as Obj, L = x['L'] as Obj; L['rn'] = 'offer'; u['offer'] = iso(x['e'] as DateTime); await Store.I.save(log: '📢 الاستديو ${str(u['name'])} معروض للإيجار من ${u['offer']}'); if (context.mounted) toast(context, Tr.t('اتعلم إن الاستديو معروض للإيجار')); }, child: Text(Tr.t('📢 أعرض الاستديو'))),
          TextButton(onPressed: () => Store.I.snooze('${(x['u'] as Obj)['id']}_${x['k']}'), child: Text(Tr.t('بعدين'))),
        ]),
      ])),
    ])));
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final e = Engine(Store.I.S, WS: Ws.I.resolve());
    final cash = e.cashNow(); final rp = e.rcvP(); final f = e.fpos();
    final mine = Store.I.S['pmode'] == 'me';
    return ListView(padding: const EdgeInsets.all(14), children: [
      _Alert(e),
      const _Hello(),
      const MonBanner(),
      Row(children: [
        Expanded(child: _Stat(Tr.t('💵 الرصيد النقدي'), cash, c: kOk)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(mine ? Tr.t('📈 ربحي حتى اليوم') : Tr.t('📈 ربح المجموعة حتى اليوم'), rp['profit']!, c: const Color(0xFF2563EB), sub: 'على الإيجار المقبوض (${(rp['mo']! * 10).round() / 10} شهر)')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _Stat(Tr.t('🏦 صافي حقوقك'), f['eq']!, c: const Color(0xFF7C3AED))),
        const SizedBox(width: 10),
        Expanded(child: _Stat(Tr.t('🧾 الإيجار المقبوض'), rp['rev']!, c: kTeal)),
      ]),
      const SizedBox(height: 10),
      const SizedBox(height: 10),
      Builder(builder: (_) { final an = e.annW(); return Row(children: [
        Expanded(child: _Stat(Tr.t('🎯 الربح المتوقع على مدة العقود'), an['p'] as double, c: kOk, sub: Tr.t('بعد كل التكاليف والمصاريف'))),
        const SizedBox(width: 10),
        Expanded(child: BStat(Tr.t('🏠 نسبة الإشغال'), 0, c: const Color(0xFF2563EB), text: '${((an['occ'] as double) * 100).round()}%')),
      ]); }),
      Builder(builder: (_) { var lp = 0.0, lf = 0.0; for (final u in e.SU()) { final o = e.occ(u); lp += o['lossPast'] as double; lf += o['lossFut'] as double; }
        if (lp + lf < 1) return const SizedBox.shrink();
        return Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
          if (lp >= 1) Expanded(child: _Stat(Tr.t('📉 خسارة أيام فاضية فاتت'), -lp)),
          if (lp >= 1 && lf >= 1) const SizedBox(width: 10),
          if (lf >= 1) Expanded(child: _Stat(Tr.t('⏳ أيام فاضية جاية'), -lf, sub: Tr.t('لو ما اتأجرتش'))),
        ])); }),
      _Renew(e),
      const SizedBox(height: 14),
      _Upcoming(e),
      const SizedBox(height: 10),
      BCard(c: const Color(0xFF7C3AED), title: Tr.t('📊 المركز المالي'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(Tr.t('اللي ليك'), style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
        for (final k in [['cash', Tr.t('الكاش')], ['rcv', Tr.t('إيجارات مستحقة لسه متحصلتش')], ['accU', Tr.t('إيجار مكتسب لسه مجاش ميعاده')], ['preCo', Tr.t('إيجار شركات مدفوع مقدم')], ['preI', Tr.t('نت/راوتر مدفوع مقدم')], ['fur', Tr.t('قيمة الأثاث المتبقية')], ['depP', Tr.t('تأمينات دفعتها')], ['gpm', Tr.t('فلوس الشراكة')]])
          if ((f[k[0]] ?? 0).abs() >= 1) _row(k[1], f[k[0]]!),
        const Divider(),
        Text(Tr.t('اللي عليك'), style: TextStyle(color: kRed, fontWeight: FontWeight.bold)),
        for (final k in [['due', Tr.t('دفعات شركات مستحقة')], ['accCo', Tr.t('إيجار شركات مستهلك ولسه مدفعتوش')], ['unr', Tr.t('إيجار مقبوض مقدم')], ['furPay', Tr.t('أثاث لسه متدفعش')], ['depH', Tr.t('تأمينات مستأجرين معاك')], ['ptn', Tr.t('نصيب الشركاء')]])
          if ((f[k[0]] ?? 0).abs() >= 1) _row(k[1], f[k[0]]!),
        const Divider(),
        _row(Tr.t('صافي حقوقك'), f['eq']!, bold: true),
      ])),
      const SizedBox(height: 10),
      Text(Store.I.syncMsg.isEmpty ? '' : 'المزامنة: ${Store.I.syncMsg}', style: const TextStyle(color: kMuted, fontSize: 12), textAlign: TextAlign.center),
      if (lst(Store.I.S['units']).isEmpty) Padding(padding: EdgeInsets.all(30), child: Text(Tr.t('لسه مفيش بيانات — اسحب لتحت علشان تتزامن'), textAlign: TextAlign.center)),
    ]);
  }

  Widget _row(String l, double v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.normal))), Text(money(v), style: TextStyle(fontWeight: FontWeight.bold, color: bold ? sign(v) : kInk))]),
      );
}

class _Stat extends StatelessWidget {
  final String l; final double v; final String? sub; final Color? c;
  const _Stat(this.l, this.v, {this.sub, this.c});
  @override
  Widget build(BuildContext context) => BStat(l, v, sub: sub, c: v < 0 ? kRed : c);
}

/// المتأخر والقادم خلال 30 يوم — دوس على الإيجار تسجّله اتدفع
class _Upcoming extends StatelessWidget {
  final Engine e;
  const _Upcoming(this.e);
  @override
  Widget build(BuildContext context) {
    final all = e.items().where((x) => ['rent', 'inst', 'exp', 'end', 'cend', 'debt', 'recv'].contains(x['ty'])).toList()
      ..sort((a, b) => str(a['d']).compareTo(str(b['d'])));
    final late = all.where((x) => (x['ty'] == 'rent' || x['ty'] == 'inst' || x['ty'] == 'debt') && Engine.dd(x['d']) < 0).toList();
    final soon = all.where((x) { final d = Engine.dd(x['d']); return d >= 0 && d <= 30; }).toList();
    if (late.isEmpty && soon.isEmpty) return const SizedBox();
    Widget row(Map<String, dynamic> x) {
      final d = Engine.dd(x['d']);
      final ic = {'rent': '💰', 'inst': '🏢', 'exp': '🧾', 'end': '📄', 'cend': '🏁', 'debt': '⬆️', 'recv': '⬇️'}[x['ty']] ?? '•';
      final when = d < 0 ? 'متأخر ${-d} يوم' : d == 0 ? Tr.t('النهارده') : d == 1 ? Tr.t('بكره') : 'بعد $d يوم';
      return InkWell(
        onTap: () async {
          final u = x['u'] == null ? null : Act.unit(str(x['u']));
          if (u == null) return;
          if (x['ty'] == 'rent') {
            final k = x['k'] as int, i = x['i'] as int; final L = objs(u['leases'])[k];
            if (!await lockOk(context, [str(x['d'])]) || !context.mounted) return;
            if (await confirmDlg(context, 'تأكيد استلام ${money(Engine.la(L, i))} من ${str(L['tenant'])} — ${str(u['name'])} (دفعة ${i + 1})؟')) { await Act.rentPaid(u, k, i); if (context.mounted) toast(context, Tr.t('✅ اتسجل')); }
          } else { Navigator.of(context).push(MaterialPageRoute(builder: (_) => UnitDetail(u))); }
        },
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
          Text(ic), const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(Priv.txt(str(x['label'])), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            Text('${str(x['d'])} • $when', style: TextStyle(color: d < 0 ? kRed : kMuted, fontSize: 12)),
          ])),
          if ((x['amt'] as num) != 0) Text(money(x['amt'] as num), style: TextStyle(fontWeight: FontWeight.w900, color: x['ty'] == 'rent' || x['ty'] == 'recv' ? kGreen : kRed)),
        ])),
      );
    }
    return BCard(c: const Color(0xFFEA580C), title: '📅 ${Tr.t('الدفعات القادمة')}', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (late.isNotEmpty) ...[Text('⚠️ متأخر (${late.length})', style: const TextStyle(fontWeight: FontWeight.w900, color: kRed, fontSize: 16)), for (final x in late.take(20)) row(x), const Divider()],
      Text('${Tr.t('الـ30 يوم الجايين')} (${soon.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kMuted)),
      if (soon.isEmpty) Text(Tr.t('مفيش حاجة'), style: TextStyle(color: kMuted)),
      for (final x in soon.take(30)) row(x),
      Text(Tr.t('دوس على الإيجار علشان تسجّل إنه اتدفع'), style: TextStyle(color: kMuted, fontSize: 11)),
    ]));
  }
}

/// 🔔 شريط التنبيه الأزرق (زي ntb في القديم): أقرب حاجة محتاجة تتعمل
class _Alert extends StatelessWidget {
  final Engine e;
  const _Alert(this.e);
  @override
  Widget build(BuildContext context) {
    final al = e.items().where((x) {
      final d = Engine.dd(x['d']); final offs = lst(x['offs']).map((o) => n(o).toInt()).toList();
      if (d < 0) return ['rent', 'inst', 'debt'].contains(x['ty']);
      return offs.contains(d) || (offs.isNotEmpty && d <= offs.first && x['ty'] != 'exp' && x['ty'] != 'end' && d <= 3);
    }).toList()..sort((a, b) => str(a['d']).compareTo(str(b['d'])));
    if (al.isEmpty) return const SizedBox.shrink();
    final x = al.first; final d = Engine.dd(x['d']);
    final when = d < 0 ? '${Tr.t('متأخر')} ${-d} ${Tr.t('يوم')}' : d == 0 ? Tr.t('النهارده') : '${Tr.t('بعد')} $d ${Tr.t('يوم')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(color: kAc, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x401473E6), blurRadius: 14, offset: Offset(0, 6))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), decoration: BoxDecoration(color: Colors.white.withOpacity(.22), borderRadius: BorderRadius.circular(99)), child: Text('🔔 ${al.length} ${Tr.t('تنبيه')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
        const SizedBox(height: 6),
        Text('$when: ${Priv.txt(str(x['label']))}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.5)),
      ]),
    );
  }
}

/// كارت الترحيب (مساء الخير…)
class _Hello extends StatelessWidget {
  const _Hello();
  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour; final nm = str(Store.I.cfg['u']).isEmpty ? '' : '، ${Store.I.cfg['u']}';
    final g = h < 12 ? Tr.t('صباح الخير') : Tr.t('مساء الخير');
    const ms = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    const ds = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final t = DateTime.now();
    return Container(
      height: 104, margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9FD8F0), Color(0xFFD7F0FA), Color(0xFFBFE6C9)]), boxShadow: const [BoxShadow(color: Color(0x1A14213D), blurRadius: 10, offset: Offset(0, 4))]),
      child: Stack(children: [
        const Positioned(left: 70, top: 6, child: Text('☀️', style: TextStyle(fontSize: 34))),
        const Positioned(left: 8, bottom: 0, child: Text('🏢🏬', style: TextStyle(fontSize: 40))),
        const Positioned(left: 110, bottom: 0, child: Text('🏠🌴', style: TextStyle(fontSize: 30))),
        PositionedDirectional(start: 12, top: 14, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$g$nm 👋', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kGreen)),
            Text(Tr.en ? '${t.day}/${t.month}/${t.year}' : '${ds[t.weekday - 1]}، ${t.day} ${ms[t.month - 1]}', style: const TextStyle(color: kMuted, fontSize: 12)),
          ]),
        )),
      ]),
    );
  }
}
