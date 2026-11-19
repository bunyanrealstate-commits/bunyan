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
import 'dash.dart';
import 'explain.dart';
import 'notif.dart';
import 'forecast.dart';

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
    final w = Ws.I.resolve(); final g = objs(Store.I.S['groups']).where((x) => x['id'] == w).firstOrNull;
    final an = e.annW();
    var lp = 0.0, lf = 0.0; for (final u in e.SU()) { final o = e.occ(u); lp += o['lossPast'] as double; lf += o['lossFut'] as double; }
    return ListView(padding: const EdgeInsets.fromLTRB(10, 10, 14, 90), children: [
      const HeroScene(),
      const SizedBox(height: 12),
      NtBar(e),
      // ───── 💰 فلوسك ─────
      SecHead(Tr.t('💰 فلوسك'), sub: Tr.t('النهارده')),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _Stat(Tr.t('💵 الرصيد النقدي'), cash, c: kOk, onTap: () => eqCash(context, e))),
        const SizedBox(width: 10),
        Expanded(child: _Stat(mine ? Tr.t('📈 ربحي حتى اليوم') : Tr.t('📈 ربح المجموعة حتى اليوم'), rp['profit']!, c: const Color(0xFF2563EB), sub: 'على الإيجار المقبوض (${(rp['mo']! * 10).round() / 10} شهر)', onTap: () => eqProfit(context, e))),
      ]),
      const SizedBox(height: 12),
      WithdrawCard(e),
      // ───── 🏠 الاستديوهات ─────
      SecHead(Tr.t('🏠 الاستديوهات'), sub: '${e.SU().length} ${Tr.t('استديو')}'),
      StatusTiles(e),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: BStat(Tr.t('🏠 نسبة الإشغال'), 0, c: const Color(0xFF2563EB), text: '${((an['occ'] as double) * 100).round()}%', onTap: () => kpis(e)[1].open(context))),
        const SizedBox(width: 10),
        Expanded(child: _Stat(Tr.t('🧾 الإيجار المقبوض'), rp['rev']!, c: kTeal)),
      ]),
      if (lp + lf >= 1) Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
        if (lp >= 1) Expanded(child: _Stat(Tr.t('📉 خسارة أيام فاضية فاتت'), -lp)),
        if (lp >= 1 && lf >= 1) const SizedBox(width: 10),
        if (lf >= 1) Expanded(child: _Stat(Tr.t('⏳ أيام فاضية جاية'), -lf, sub: Tr.t('لو ما اتأجرتش'))),
      ])),
      // ───── 📊 الأداء والتوقعات ─────
      SecHead(Tr.t('📊 الأداء والتوقعات')),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _Stat(Tr.t('🎯 الربح المتوقع على مدة العقود'), an['p'] as double, c: kOk, sub: Tr.t('بعد كل التكاليف والمصاريف'), onTap: () => eqProj(context, e))),
        const SizedBox(width: 10),
        Expanded(child: _Stat(Tr.t('🤝 فلوس الشراكة'), g == null ? 0 : e.gpMine(g), c: const Color(0xFF2563EB), sub: g == null ? null : (Priv.on ? '••••' : str(g['name'])), onTap: () => Shell.go(4))),
      ]),
      const SizedBox(height: 10),
      _Stat(Tr.t('🏦 صافي حقوقك'), f['eq']!, c: const Color(0xFF7C3AED), onTap: () => eqSheet(context, Tr.t('وضعي المالي اليوم'), [kvTable(fpRows(e)), eqMu('صافي رصيدك بيتغير بنفس مقدار ربحك المحاسبي، زائد أي فلوس تضيفها أو تسحبها.')], icon: '🏦')),
      const SizedBox(height: 14),
      PerUnitCard(e),
      // ───── كروت بتفتح شاشات (زي القديم) ─────
      SecHead(Tr.t('⚡ شاشات سريعة')),
      tRow([
        TCard('📅', '${Tr.t('الدفعات القادمة')}', sub: Tr.t('كل دفعة شركة هتتغطى منين'), c: kTerra, onTap: () => coverageSheet(context, e)),
        TCard('🧭', Tr.t('خطة السحب'), sub: Tr.t('تسحب إمتى وقد إيه'), c: kOk, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastPage()))),
      ]),
      tRow([
        TCard('📊', Tr.t('التحليل المالي'), sub: Tr.t('الإيراد والمصاريف والربح'), c: const Color(0xFF2563EB), onTap: () => analysisSheet(context, e)),
        TCard('🕘', Tr.t('آخر التعديلات'), sub: Tr.t('مين عدّل إيه'), c: const Color(0xFF7C3AED), onTap: () => lastEditsSheet(context)),
      ]),
      // ───── 📅 المواعيد ─────
      SecHead(Tr.t('📅 المواعيد')),
      _Renew(e),
      _Upcoming(e),
      const SizedBox(height: 10),
      // ───── 🏦 المركز المالي ─────
      SecHead(Tr.t('🏦 المركز المالي')),
      const CapitalCard(),
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
      const MonBanner(),
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
  final String l; final double v; final String? sub; final Color? c; final VoidCallback? onTap;
  const _Stat(this.l, this.v, {this.sub, this.c, this.onTap});
  @override
  Widget build(BuildContext context) => BStat(l, v, sub: sub, c: v < 0 ? kRed : c, onTap: onTap);
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

