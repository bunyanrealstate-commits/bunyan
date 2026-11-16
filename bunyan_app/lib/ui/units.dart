import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';
import '../core/actions.dart';
import 'dialogs.dart';

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

class UnitDetail extends StatefulWidget {
  final Obj u;
  const UnitDetail(this.u, {super.key});
  @override
  State<UnitDetail> createState() => _UnitDetailState();
}

class _UnitDetailState extends State<UnitDetail> {
  @override
  void initState() { super.initState(); Store.I.addListener(_r); }
  void _r() { if (mounted) setState(() {}); }
  @override
  void dispose() { Store.I.removeListener(_r); super.dispose(); }

  Obj get u => Act.unit(str(widget.u['id'])) ?? widget.u;

  @override
  Widget build(BuildContext context) {
    final t = today();
    final insts = objs(u['inst']);
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
          const Text('💳 دفعات الشركة — دوس على الدفعة علشان تسجّلها', style: TextStyle(fontWeight: FontWeight.bold)),
          for (var k = 0; k < insts.length; k++) InkWell(
            onTap: () => _inst(k),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              Expanded(child: Text(str(insts[k]['d']))), Text(money(n0(insts[k]['a']))), const SizedBox(width: 8),
              _pill(truthy(insts[k]['p']) ? '✅ مدفوعة' : (pd(insts[k]['d']).isAfter(t) ? '⏳ لسه' : '⚠️ مستحقة'), truthy(insts[k]['p']) ? kGreen : kTerra),
            ])),
          ),
        ]))),
        for (var k = 0; k < objs(u['leases']).length; k++) _lease(k, t),
      ]),
    ));
  }

  Widget _lease(int k, DateTime t) {
    final L = objs(u['leases'])[k];
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('👤 ${str(L['tenant'])}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      if (truthy(L['phone'])) Text(str(L['phone']), style: const TextStyle(color: kMuted)),
      _kv('من', '${str(L['start'])} لـ ${iso(Engine.lend(L))}'),
      _kv('الإيجار', money(n0(L['rent']))),
      const Divider(),
      const Text('دوس على الشهر علشان تسجّل إنه اتدفع', style: TextStyle(color: kMuted, fontSize: 12)),
      for (var i = 0; i < Engine.months(L); i++) Builder(builder: (_) {
        final d = Engine.payD(L, i); final got = Engine.rcv(L).contains(i);
        return InkWell(onTap: () => _rent(k, i, got), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
          Text(got ? '✅' : (d.isAfter(t) ? '⏳' : '⚠️')),
          const SizedBox(width: 8),
          Expanded(child: Text('${iso(d)}  •  دفعة ${i + 1}')),
          Text(money(Engine.rv(L, i) + Engine.ppA(L, i)), style: TextStyle(fontWeight: FontWeight.bold, color: got ? kGreen : kInk)),
        ])));
      }),
    ])));
  }

  Future<void> _rent(int k, int i, bool got) async {
    final L = objs(u['leases'])[k];
    if (!await lockOk(context, [iso(Engine.payD(L, i))])) return;
    if (!mounted) return;
    if (got) {
      if (await confirmDlg(context, 'إلغاء استلام دفعة ${i + 1} من ${str(L['tenant'])}؟', ok: 'إلغاء الاستلام')) await Act.rentUnpaid(u, k, i);
    } else {
      if (await confirmDlg(context, 'تأكيد استلام ${money(Engine.la(L, i))} من ${str(L['tenant'])} — ${str(u['name'])} (دفعة ${i + 1})؟')) {
        await Act.rentPaid(u, k, i);
        if (mounted) toast(context, '✅ اتسجل: استلمت ${money(Engine.la(L, i))}');
      }
    }
  }

  Future<void> _inst(int k) async {
    final i = objs(u['inst'])[k];
    if (!await lockOk(context, [str(i['d'])])) return;
    if (!mounted) return;
    if (truthy(i['p'])) { if (await confirmDlg(context, 'إلغاء تسجيل دفعة الشركة ${money(n0(i['a']))}؟', ok: 'إلغاء')) await Act.instUnpay(u, k); return; }
    final opts = <List<String>>[['', 'دون خصم من الرصيد (دُفعت من بره البرنامج)'], ['cash', 'من الرصيد النقدي في البرنامج'], if (Act.gpOK(u)) ['gp', 'من فلوس الشراكة (دعم الشركاء)']];
    final def = (k == 0 && Act.gpOK(u) && !objs(u['inst']).asMap().entries.any((e) => e.key != 0 && truthy(e.value['p']))) ? 'gp' : '';
    final src = await pickDlg(context, 'تسجيل دفعة للشركة — ${money(n0(i['a']))}\nمن أين دُفعت؟', opts, def);
    if (src != null) await Act.instPay(u, k, src);
  }

  Widget _pill(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(10)), child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)));
  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Text('$k: ', style: const TextStyle(color: kMuted)), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)))]));
}
