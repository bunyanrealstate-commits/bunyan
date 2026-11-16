import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';

class UnitsPage extends StatelessWidget {
  const UnitsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final e = Engine(Store.I.S, WS: Ws.I.resolve());
    final us = e.SU();
    if (us.isEmpty) return ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Text('مفيش وحدات في المجموعة دي', textAlign: TextAlign.center))]);
    return ListView(padding: const EdgeInsets.all(14), children: [
      for (final u in us) _UnitCard(u),
    ]);
  }
}

class _UnitCard extends StatelessWidget {
  final Obj u;
  const _UnitCard(this.u);
  @override
  Widget build(BuildContext context) {
    final ls = objs(u['leases']);
    final t = today();
    return Card(child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UnitDetail(u))),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(str(u['name']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          Text(str(u['company']), style: const TextStyle(color: kMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        if (ls.isEmpty) const Text('فاضية — مفيش مستأجر', style: TextStyle(color: kTerra, fontWeight: FontWeight.bold)),
        for (final L in ls) ...[
          Builder(builder: (_) {
            final rc = Engine.rcv(L); var due = 0;
            for (var i = 0; i < Engine.months(L); i++) { if (!Engine.payD(L, i).isAfter(t) && !rc.contains(i)) due++; }
            return Row(children: [
              Expanded(child: Text('👤 ${str(L['tenant'])}', style: const TextStyle(fontWeight: FontWeight.bold))),
              Text('${money(n0(L['rent']))} / شهر', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              if (due > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(10)), child: Text('$due متأخر', style: const TextStyle(color: kRed, fontSize: 11, fontWeight: FontWeight.bold))),
            ]);
          }),
        ],
      ])),
    ));
  }
}

class UnitDetail extends StatelessWidget {
  final Obj u;
  const UnitDetail(this.u, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = today();
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: Text(str(u['name']))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kv('الشركة', str(u['company'])),
          _kv('بداية العقد', str(u['start'])),
          _kv('مدة العقد', '${str(u['cm'])} شهر'),
          _kv('إجمالي الإيجار', money(truthy(u['total']) ? n(u['total']) : Engine.isumOf(u))),
          _kv('الأثاث', money(n0(u['furn']))),
          const Divider(),
          const Text('💳 دفعات الشركة', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final i in objs(u['inst'])) Row(children: [
            Expanded(child: Text(str(i['d']))), Text(money(n0(i['a']))), const SizedBox(width: 8),
            Text(truthy(i['p']) ? '✅ مدفوعة' : (pd(i['d']).isAfter(t) ? '⏳' : '⚠️ مستحقة'), style: TextStyle(color: truthy(i['p']) ? kGreen : kTerra, fontSize: 12)),
          ]),
        ]))),
        for (final L in objs(u['leases'])) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('👤 ${str(L['tenant'])}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          if (truthy(L['phone'])) Text(str(L['phone']), style: const TextStyle(color: kMuted)),
          _kv('من', '${str(L['start'])} لـ ${iso(Engine.lend(L))}'),
          _kv('الإيجار', money(n0(L['rent']))),
          const Divider(),
          for (var i = 0; i < Engine.months(L); i++) Builder(builder: (_) {
            final d = Engine.payD(L, i); final got = Engine.rcv(L).contains(i);
            return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
              Text(got ? '✅' : (d.isAfter(t) ? '⏳' : '⚠️')),
              const SizedBox(width: 8),
              Expanded(child: Text(iso(d))),
              Text(money(Engine.rv(L, i) + Engine.ppA(L, i)), style: const TextStyle(fontWeight: FontWeight.bold)),
            ]));
          }),
        ]))),
      ]),
    ));
  }
  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Text('$k: ', style: const TextStyle(color: kMuted)), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)))]));
}
