import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';
import '../core/actions.dart';
import 'dialogs.dart';
import 'lease_edit.dart';
import 'unit_edit.dart';

class UnitsPage extends StatelessWidget {
  const UnitsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final e = Engine(Store.I.S, WS: Ws.I.resolve());
    final us = e.SU();
    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
        if (us.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Text('مفيش وحدات في المجموعة دي', textAlign: TextAlign.center)),
        for (final u in us) _UnitCard(u),
      ]),
      Positioned(left: 16, bottom: 16, child: FloatingActionButton.extended(heroTag: 'nu', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnitEdit(null))), icon: const Icon(Icons.add_home), label: const Text('استديو جديد'))),
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
      appBar: AppBar(title: Text(str(u['name'])), actions: [IconButton(tooltip: 'حذف الاستديو', icon: const Icon(Icons.delete_outline, color: kRed), onPressed: () async {
        if (!await confirmDlg(context, 'هل تريد حذف الاستديو بكل دفعاتها وعقودها ومصاريفها وتمويلها وتأميناته؟ الرصيد النقدي هيرجع زي ما كان قبل ما تضيفه.', ok: '🗑 احذف') || !context.mounted) return;
        await Act.delUnit(u, Ws.I.resolve()); if (context.mounted) Navigator.pop(context);
      }), IconButton(tooltip: 'تعديل الاستديو', icon: const Icon(Icons.edit), onPressed: () async {
        final ds = [for (final i in objs(u['inst'])) if (truthy(i['p'])) str(i['d'])];
        if (!await lockOk(context, ds) || !context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => UnitEdit(str(u['id']))));
      })]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaseEdit(u, null))), icon: const Icon(Icons.person_add), label: const Text('عقد مستأجر جديد')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kv('الشركة', str(u['company'])),
          _kv('بداية العقد', str(u['start'])),
          _kv('مدة العقد', '${str(u['cm'])} شهر'),
          _kv('إجمالي الإيجار', money(truthy(u['total']) ? n(u['total']) : Engine.isumOf(u))),
          _kv('الأثاث', money(n0(u['furn']))),
          Builder(builder: (_) { final e = Engine(Store.I.S, WS: 'all'); final p = e.projU(u); final a = e.ua(u); final o = e.occ(u);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _kv('📉 سعر اليوم عند الشركة', money(o['c'] as double)),
              _kv('أيام فاضية', '${o['vac']} يوم'),
              if ((o['lossPast'] as double) > 0) _kv('اتخسر في أيام فاتت', money(o['lossPast'] as double)),
              if ((o['lossFut'] as double) > 0) _kv('هيتخسر لو فضل فاضي', money(o['lossFut'] as double)),
              if ((o['free'] as int) > 0) _kv('🎁 أيام إيجار قبل بداية الشركة', '${o['free']} يوم = ${money(o['freeVal'] as double)}'),
              for (final g in (o['gaps'] as List).take(6)) Text('   • فاضي من ${g['a']} لـ ${g['b']} (${g['dys']} يوم)', style: const TextStyle(fontSize: 12, color: kMuted)),
              if (p != null) _kv('🎯 الربح المتوقع', money(p['p'] as double)),
              _kv('🏠 شهور مأجّرة', '${((a['occ']! * 10).round() / 10)} من ${str(u['cm'])}'),
              if (a['vac']! > 0 && a['need']! > 0) _kv('أقل إيجار للشهور الفاضية', '${money(a['need']!)} / شهر'),
            ]); }),
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
      Row(children: [
        Expanded(child: Text('👤 ${str(L['tenant'])}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
        PopupMenuButton<String>(itemBuilder: (_) => [
          if (!truthy(L['exit'])) const PopupMenuItem(value: 'stop', child: Text('⛔ وقف العقد (خروج المستأجر)')),
          if (truthy(L['exit'])) const PopupMenuItem(value: 'resume', child: Text('▶️ استئناف العقد')),
          if (truthy(L['exit']) && n0(L['pen']) > 0) PopupMenuItem(value: 'pen', child: Text(truthy(L['penp']) ? '↩️ لغي استلام الشرط الجزائي' : '💰 استلمت الشرط الجزائي')),
          const PopupMenuItem(value: 'del', child: Text('🗑 حذف العقد', style: TextStyle(color: kRed))),
        ], onSelected: (v) => _leaseMenu(k, v)),
        IconButton(tooltip: 'تعديل العقد', icon: const Icon(Icons.edit_outlined), onPressed: () async {
          if (truthy(L['exit'])) { toast(context, 'العقد موقوف — استأنفه الأول'); return; }
          if (!truthy(L['sch'])) { toast(context, 'العقد ده معمول بالطريقة القديمة — عدّله من بنيان القديم'); return; }
          final ds = [str(L['start']), for (final i in Engine.rcv(L)) iso(Engine.payD(L, i))];
          if (!await lockOk(context, ds) || !context.mounted) return;
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaseEdit(u, k)));
        }),
      ]),
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

  Future<void> _leaseMenu(int k, String v) async {
    final L = objs(u['leases'])[k];
    final ds = [str(L['start']), for (final i in Engine.rcv(L)) iso(Engine.payD(L, i))];
    if (!await lockOk(context, ds) || !mounted) return;
    if (v == 'stop') {
      final o = await formDlg(context, 'وقف العقد — ${str(L['tenant'])}', [FieldSpec('exit', 'تاريخ وقف العقد (خروج المستأجر)', type: 'd', v: truthy(L['exit']) ? L['exit'] : Act.td()), FieldSpec('pen', 'غرامة الخروج المبكر (الشرط الجزائي) — 0 إن لم توجد', type: 'n', v: str(L['pen'] ?? 0))]);
      if (o == null || !mounted) return;
      final pen = double.tryParse(o['pen'] ?? '') ?? 0;
      final paid = pen > 0 && await confirmDlg(context, 'هل دفع المستأجر الغرامة (${money(pen)})؟', ok: 'أيوه دفع');
      await Act.stopLease(u, k, o['exit'] ?? Act.td(), pen, paid);
    } else if (v == 'resume') { if (await confirmDlg(context, 'استئناف العقد وإلغاء الوقف والغرامة؟')) await Act.resumeLease(u, k); }
    else if (v == 'pen') { await Act.togPen(u, k); }
    else if (v == 'del') { if (await confirmDlg(context, 'حذف عقد «${str(L['tenant'])}»؟\n(تقدر ترجعه بعدين من «🗑 سلة المحذوفات»)', ok: '🗑 احذف')) await Act.delLease(u, k, Ws.I.resolve()); }
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
