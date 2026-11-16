import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';

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
      const SizedBox(height: 14),
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
