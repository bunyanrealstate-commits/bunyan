import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';
import 'units.dart';
import 'dialogs.dart';
import '../core/actions.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final e = Engine(Store.I.S, WS: Ws.I.resolve());
    final cash = e.cashNow(); final rp = e.rcvP(); final f = e.fpos();
    final mine = Store.I.S['pmode'] == 'me';
    return ListView(padding: const EdgeInsets.all(14), children: [
      Row(children: [
        Expanded(child: _Stat('💵 الرصيد النقدي', cash)),
        const SizedBox(width: 10),
        Expanded(child: _Stat(mine ? '📈 ربحي حتى اليوم' : '📈 ربح المجموعة حتى اليوم', rp['profit']!, sub: 'على الإيجار المقبوض (${(rp['mo']! * 10).round() / 10} شهر)')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _Stat('🏦 صافي حقوقك', f['eq']!)),
        const SizedBox(width: 10),
        Expanded(child: _Stat('🧾 الإيجار المقبوض', rp['rev']!)),
      ]),
      const SizedBox(height: 10),
      Builder(builder: (_) { final an = e.annW(); return Row(children: [
        Expanded(child: _Stat('🎯 الربح المتوقع على مدة العقود', an['p'] as double, sub: 'بعد كل التكاليف والمصاريف')),
        const SizedBox(width: 10),
        Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🏠 نسبة الإشغال', style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${((an['occ'] as double) * 100).round()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kGreen)),
          LinearProgressIndicator(value: (an['occ'] as double).clamp(0, 1), color: kGreen, backgroundColor: kSand),
        ])))),
      ]); }),
      const SizedBox(height: 14),
      _Upcoming(e),
      const SizedBox(height: 10),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📊 المركز المالي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('اللي ليك', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
        for (final k in [['cash', 'الكاش'], ['rcv', 'إيجارات مستحقة لسه متحصلتش'], ['accU', 'إيجار مكتسب لسه مجاش ميعاده'], ['preCo', 'إيجار شركات مدفوع مقدم'], ['preI', 'نت/راوتر مدفوع مقدم'], ['fur', 'قيمة الأثاث المتبقية'], ['depP', 'تأمينات دفعتها'], ['gpm', 'فلوس الشراكة']])
          if ((f[k[0]] ?? 0).abs() >= 1) _row(k[1], f[k[0]]!),
        const Divider(),
        const Text('اللي عليك', style: TextStyle(color: kRed, fontWeight: FontWeight.bold)),
        for (final k in [['due', 'دفعات شركات مستحقة'], ['accCo', 'إيجار شركات مستهلك ولسه مدفعتوش'], ['unr', 'إيجار مقبوض مقدم'], ['furPay', 'أثاث لسه متدفعش'], ['depH', 'تأمينات مستأجرين معاك'], ['ptn', 'نصيب الشركاء']])
          if ((f[k[0]] ?? 0).abs() >= 1) _row(k[1], f[k[0]]!),
        const Divider(),
        _row('صافي حقوقك', f['eq']!, bold: true),
      ]))),
      const SizedBox(height: 10),
      Text(Store.I.syncMsg.isEmpty ? '' : 'المزامنة: ${Store.I.syncMsg}', style: const TextStyle(color: kMuted, fontSize: 12), textAlign: TextAlign.center),
      if (lst(Store.I.S['units']).isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('لسه مفيش بيانات — اسحب لتحت علشان تتزامن', textAlign: TextAlign.center)),
    ]);
  }

  Widget _row(String l, double v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [Expanded(child: Text(l, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.normal))), Text(money(v), style: TextStyle(fontWeight: FontWeight.bold, color: bold ? sign(v) : kInk))]),
      );
}

class _Stat extends StatelessWidget {
  final String l; final double v; final String? sub;
  const _Stat(this.l, this.v, {this.sub});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(money(v), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: sign(v))),
        if (sub != null) Text(sub!, style: const TextStyle(color: kMuted, fontSize: 11)),
      ])));
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
      final when = d < 0 ? 'متأخر ${-d} يوم' : d == 0 ? 'النهارده' : d == 1 ? 'بكره' : 'بعد $d يوم';
      return InkWell(
        onTap: () async {
          final u = x['u'] == null ? null : Act.unit(str(x['u']));
          if (u == null) return;
          if (x['ty'] == 'rent') {
            final k = x['k'] as int, i = x['i'] as int; final L = objs(u['leases'])[k];
            if (!await lockOk(context, [str(x['d'])]) || !context.mounted) return;
            if (await confirmDlg(context, 'تأكيد استلام ${money(Engine.la(L, i))} من ${str(L['tenant'])} — ${str(u['name'])} (دفعة ${i + 1})؟')) { await Act.rentPaid(u, k, i); if (context.mounted) toast(context, '✅ اتسجل'); }
          } else { Navigator.of(context).push(MaterialPageRoute(builder: (_) => UnitDetail(u))); }
        },
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
          Text(ic), const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(str(x['label']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
            Text('${str(x['d'])} • $when', style: TextStyle(color: d < 0 ? kRed : kMuted, fontSize: 12)),
          ])),
          if ((x['amt'] as num) != 0) Text(money(x['amt'] as num), style: TextStyle(fontWeight: FontWeight.w900, color: x['ty'] == 'rent' || x['ty'] == 'recv' ? kGreen : kRed)),
        ])),
      );
    }
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (late.isNotEmpty) ...[Text('⚠️ متأخر (${late.length})', style: const TextStyle(fontWeight: FontWeight.w900, color: kRed, fontSize: 16)), for (final x in late.take(20)) row(x), const Divider()],
      Text('📅 الـ30 يوم الجايين (${soon.length})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      if (soon.isEmpty) const Text('مفيش حاجة', style: TextStyle(color: kMuted)),
      for (final x in soon.take(30)) row(x),
      const Text('دوس على الإيجار علشان تسجّل إنه اتدفع', style: TextStyle(color: kMuted, fontSize: 11)),
    ])));
  }
}
