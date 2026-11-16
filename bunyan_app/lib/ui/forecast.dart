import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';

/// 🔮 التوقعات: الرصيد شهر بشهر لحد سنة قدام (events + project زي القديم)
class ForecastPage extends StatelessWidget {
  const ForecastPage({super.key});
  static const _mn = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  @override
  Widget build(BuildContext context) {
    final e = Engine(Store.I.S, WS: Ws.I.resolve());
    final t = today(); final lim = addM(t, 12);
    final ev = e.events().where((x) => !(x['d'] as DateTime).isAfter(lim)).toList();
    final p = e.project(ev); final rows = (p['rows'] as List).cast<Map<String, dynamic>>();
    final res = n0(Store.I.S['res']); final min = p['min'] as double; final minD = p['minD'] as DateTime;
    final ok = min >= res;
    return Directionality(textDirection: L.dir, child: Scaffold(
      appBar: AppBar(title: Text(L.t('🔮 التوقعات (سنة قدام)'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(color: ok ? const Color(0xFFE8F3EE) : const Color(0xFFFDECEC), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ok ? L.t('✅ الرصيد مش هيقل عن الاحتياطي') : L.t('⚠️ الرصيد هيقل عن الاحتياطي'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: ok ? kGreen : kRed)),
          const SizedBox(height: 6),
          Text('الرصيد دلوقتي: ${money(e.cashNow())}'),
          Text('أقل رصيد هتوصله: ${money(min)} يوم ${iso(minD)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          if (res > 0) Text('الاحتياطي اللي حاطه: ${money(res)}', style: const TextStyle(color: kMuted)),
        ]))),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(children: [
          Row(children: [Expanded(flex: 3, child: Text(L.t('الشهر'), style: TextStyle(fontWeight: FontWeight.bold))), Expanded(flex: 3, child: Text(L.t('داخل'), style: TextStyle(fontWeight: FontWeight.bold))), Expanded(flex: 3, child: Text(L.t('خارج'), style: TextStyle(fontWeight: FontWeight.bold))), Expanded(flex: 3, child: Text(L.t('الرصيد'), style: TextStyle(fontWeight: FontWeight.bold)))]),
          const Divider(),
          for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
            Expanded(flex: 3, child: Text('${_mn[(r['d'] as DateTime).month - 1]} ${(r['d'] as DateTime).year % 100}')),
            Expanded(flex: 3, child: Text(money(r['i'] as double), style: const TextStyle(color: kGreen))),
            Expanded(flex: 3, child: Text(money(r['o'] as double), style: const TextStyle(color: kRed))),
            Expanded(flex: 3, child: Text(money(r['end'] as double), style: TextStyle(fontWeight: FontWeight.bold, color: sign(r['end'] as double)))),
          ])),
        ]))),
        const SizedBox(height: 8),
        Text(L.t('📋 الحركات'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        for (final x in ev.take(80)) ListTile(dense: true, title: Text(str(x['l'])), subtitle: Text(iso(x['d'] as DateTime)), trailing: Text(money(x['a'] as double), style: TextStyle(color: sign(x['a'] as double), fontWeight: FontWeight.bold))),
      ]),
    ));
  }
}
