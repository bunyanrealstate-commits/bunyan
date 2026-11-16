import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';
import '../core/actions.dart';
import 'dialogs.dart';
import 'lease_edit.dart';
import 'cheques.dart';
import 'unit_boxes.dart';
import 'unit_edit.dart';

/// حالة الاستديو — نفس unitRow في القديم
class _St {
  final String st; final bool soon; final Obj? L; final int od; final DateTime e;
  _St(this.st, this.soon, this.L, this.od, this.e);
  bool get rented => st == 'rent'; bool get late => st == 'late'; bool get ending => soon;
  static _St of(Obj u) {
    final t = today(); final ls = objs(u['leases']);
    Obj? L = ls.where((L) => !pd(L['start']).isAfter(t) && Engine.lend(L).isAfter(t)).firstOrNull;
    if (L == null && truthy(u['onb']) && ls.isNotEmpty) { final f = ([...ls]..sort((a, b) => str(a['start']).compareTo(str(b['start'])))).first; final st = pd(f['start']); if (st.isAfter(t) && st.difference(t).inDays <= 75) L = f; }
    var od = 0; for (final x in ls) { final rc = Engine.rcv(x); for (var i = 0; i < Engine.months(x); i++) { if (!rc.contains(i) && !Engine.payD(x, i).isAfter(t)) od++; } }
    final e = addM(pd(u['start']), n0(u['cm']));
    return _St(od > 0 ? 'late' : (L != null ? 'rent' : 'vac'), !e.isBefore(t) && !e.isAfter(addM(t, 2)), L, od, e);
  }
}

class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});
  @override
  State<UnitsPage> createState() => _UnitsState();
}

class _UnitsState extends State<UnitsPage> {
  String q = '', f = 'all';
  @override
  Widget build(BuildContext context) {
    final e = Engine(Store.I.S, WS: Ws.I.resolve());
    final all = e.SU(); final st = {for (final u in all) u['id']: _St.of(u)};
    bool ok(Obj u) { final s = st[u['id']]!; return f == 'all' || (f == 'r' && s.rented) || (f == 'v' && s.st == 'vac') || (f == 'l' && s.late) || (f == 'e' && s.ending); }
    final us = all.where((u) => ok(u) && (q.isEmpty || '${u['name']} ${u['company']} ${objs(u['leases']).map((L) => L['tenant']).join(' ')}'.toLowerCase().contains(q.toLowerCase()))).toList();
    Widget chip(String k, String l, int n, Color c) => Padding(padding: const EdgeInsetsDirectional.only(end: 6, bottom: 6), child: ChoiceChip(
          label: Text('$l $n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: f == k ? Colors.white : kInk)), selected: f == k, showCheckmark: false,
          avatar: k == 'all' ? null : CircleAvatar(radius: 5, backgroundColor: c), selectedColor: kAc, backgroundColor: Colors.white, onSelected: (_) => setState(() => f = k)));
    return Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
        TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: Tr.t('ابحث: استديو، شركة، مستأجر'), isDense: true), onChanged: (v) => setState(() => q = v.trim())),
        const SizedBox(height: 10),
        Wrap(children: [
          chip('all', Tr.t('الكل'), all.length, kAc),
          chip('r', Tr.t('مؤجر'), all.where((u) => st[u['id']]!.rented).length, kOk),
          chip('v', Tr.t('شاغر'), all.where((u) => st[u['id']]!.st == 'vac').length, Colors.grey),
          chip('l', Tr.t('متأخر'), all.where((u) => st[u['id']]!.late).length, kRed),
          chip('e', Tr.t('ينتهي قريب'), all.where((u) => st[u['id']]!.ending).length, Colors.orange),
        ]),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${us.length} ${Tr.t('استديو')}', style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700))),
        if (us.isEmpty) Padding(padding: const EdgeInsets.all(40), child: Text(Tr.t('مفيش وحدات في المجموعة دي'), textAlign: TextAlign.center)),
        if (us.isNotEmpty) Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFBFD3F5), width: 1.2), boxShadow: const [BoxShadow(color: Color(0x332563EB), blurRadius: 22, offset: Offset(0, 8), spreadRadius: -8)]),
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Column(children: [
            Container(height: 6, color: const Color(0xFF2563EB)),
            for (final (i, u) in us.indexed) ...[if (i > 0) const Divider(height: 1), _UnitCard(u, st[u['id']]!)],
          ])),
        ),
      ]),
      PositionedDirectional(end: 16, bottom: 16, child: FloatingActionButton.extended(heroTag: 'nu', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UnitEdit(null))), icon: const Icon(Icons.add), label: Text(Tr.t('استديو')))),
    ]);
  }
}

class _UnitCard extends StatelessWidget {
  final Obj u; final _St s;
  const _UnitCard(this.u, this.s);
  @override
  Widget build(BuildContext context) {
    final L = s.L;
    final dot = s.late ? kRed : (s.rented ? kOk : Colors.grey);
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UnitDetail(u))),
      child: Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 6), child: CircleAvatar(radius: 5, backgroundColor: dot)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Priv.un(u['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kNavy)),
          Text([if (L != null && truthy(L['tenant'])) str(L['tenant']), str(u['company'])].where((x) => x.isNotEmpty).join(' • '), style: const TextStyle(color: kMuted, fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${s.soon ? '⏳ ' : ''}${Tr.t('عقد الشركة لحد')} ${iso(s.e)}${s.late ? ' • ${s.od} ${Tr.t('متأخر')}' : ''}', style: TextStyle(color: s.late ? kRed : (s.soon ? kTerra : kMuted), fontSize: 11.5)),
          if (L == null) Text(Tr.t('فاضية — مفيش مستأجر'), style: const TextStyle(color: kTerra, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
        if (L != null) Text(money(n0(L['rent'])), style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 16)),
      ])),
    );
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
    return Directionality(textDirection: Tr.dir, child: Scaffold(
      appBar: AppBar(title: Text(Priv.un(u['name'])), actions: [IconButton(tooltip: Tr.t('حذف الاستديو'), icon: const Icon(Icons.delete_outline, color: kRed), onPressed: () async {
        if (!await confirmDlg(context, Tr.t('هل تريد حذف الاستديو بكل دفعاتها وعقودها ومصاريفها وتمويلها وتأميناته؟ الرصيد النقدي هيرجع زي ما كان قبل ما تضيفه.'), ok: Tr.t('🗑 احذف')) || !context.mounted) return;
        await Act.delUnit(u, Ws.I.resolve()); if (context.mounted) Navigator.pop(context);
      }), IconButton(tooltip: Tr.t('تعديل الاستديو'), icon: const Icon(Icons.edit), onPressed: () async {
        final ds = [for (final i in objs(u['inst'])) if (truthy(i['p'])) str(i['d'])];
        if (!await lockOk(context, ds) || !context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => UnitEdit(str(u['id']))));
      })]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaseEdit(u, null))), icon: const Icon(Icons.person_add), label: Text(Tr.t('عقد مستأجر جديد'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
        RenBox(u, () { if (mounted) setState(() {}); }),
        GraceBox(u),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _kv(Tr.t('الشركة'), str(u['company'])),
          _kv(Tr.t('بداية العقد'), str(u['start'])),
          _kv(Tr.t('مدة العقد'), '${str(u['cm'])} شهر'),
          _kv(Tr.t('إجمالي الإيجار'), money(truthy(u['total']) ? n(u['total']) : Engine.isumOf(u))),
          _kv(Tr.t('الأثاث'), money(n0(u['furn']))),
          Builder(builder: (_) { final e = Engine(Store.I.S, WS: 'all'); final p = e.projU(u); final a = e.ua(u); final o = e.occ(u);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _kv(Tr.t('📉 سعر اليوم عند الشركة'), money(o['c'] as double)),
              _kv(Tr.t('أيام فاضية'), '${o['vac']} يوم'),
              if ((o['lossPast'] as double) > 0) _kv(Tr.t('اتخسر في أيام فاتت'), money(o['lossPast'] as double)),
              if ((o['lossFut'] as double) > 0) _kv(Tr.t('هيتخسر لو فضل فاضي'), money(o['lossFut'] as double)),
              if ((o['free'] as int) > 0) _kv(Tr.t('🎁 أيام إيجار قبل بداية الشركة'), '${o['free']} يوم = ${money(o['freeVal'] as double)}'),
              for (final g in (o['gaps'] as List).take(6)) Text('   • فاضي من ${g['a']} لـ ${g['b']} (${g['dys']} يوم)', style: const TextStyle(fontSize: 12, color: kMuted)),
              if (p != null) _kv(Tr.t('🎯 الربح المتوقع'), money(p['p'] as double)),
              _kv(Tr.t('🏠 شهور مأجّرة'), '${((a['occ']! * 10).round() / 10)} من ${str(u['cm'])}'),
              if (a['vac']! > 0 && a['need']! > 0) _kv(Tr.t('أقل إيجار للشهور الفاضية'), '${money(a['need']!)} / شهر'),
            ]); }),
          const Divider(),
          Text(Tr.t('💳 دفعات الشركة — دوس على الدفعة علشان تسجّلها'), style: TextStyle(fontWeight: FontWeight.bold)),
          for (var k = 0; k < insts.length; k++) InkWell(
            onTap: () => _inst(k),
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
              Expanded(child: Text(str(insts[k]['d']))), Text(money(n0(insts[k]['a']))), const SizedBox(width: 8),
              _pill(truthy(insts[k]['p']) ? Tr.t('✅ مدفوعة') : (pd(insts[k]['d']).isAfter(t) ? Tr.t('⏳ لسه') : Tr.t('⚠️ مستحقة')), truthy(insts[k]['p']) ? kGreen : kTerra),
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
          if (!truthy(L['exit'])) PopupMenuItem(value: 'stop', child: Text(Tr.t('⛔ وقف العقد (خروج المستأجر)'))),
          if (truthy(L['exit'])) PopupMenuItem(value: 'resume', child: Text(Tr.t('▶️ استئناف العقد'))),
          if (truthy(L['exit']) && n0(L['pen']) > 0) PopupMenuItem(value: 'pen', child: Text(truthy(L['penp']) ? Tr.t('↩️ لغي استلام الشرط الجزائي') : Tr.t('💰 استلمت الشرط الجزائي'))),
          PopupMenuItem(value: 'renew', child: Text(Tr.t('🔄 تجديد العقد (عقد جديد بعده)'))),
          PopupMenuItem(value: 'chq', child: Text(Tr.t('📑 شيك جديد'))),
          if (_depOf(L) != null && !truthy(_depOf(L)!['r'])) PopupMenuItem(value: 'refund', child: Text('🔐 رد التأمين (${money(n0(_depOf(L)!['a']))})')),
          PopupMenuItem(value: 'del', child: Text(Tr.t('🗑 حذف العقد'), style: TextStyle(color: kRed))),
        ], onSelected: (v) => _leaseMenu(k, v)),
        IconButton(tooltip: Tr.t('تعديل العقد'), icon: const Icon(Icons.edit_outlined), onPressed: () async {
          if (truthy(L['exit'])) { toast(context, Tr.t('العقد موقوف — استأنفه الأول')); return; }
          if (!truthy(L['sch'])) { toast(context, Tr.t('العقد ده معمول بالطريقة القديمة — عدّله من بنيان القديم')); return; }
          final ds = [str(L['start']), for (final i in Engine.rcv(L)) iso(Engine.payD(L, i))];
          if (!await lockOk(context, ds) || !context.mounted) return;
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaseEdit(u, k)));
        }),
      ]),
      if (truthy(L['phone'])) Text(str(L['phone']), style: const TextStyle(color: kMuted)),
      _kv(Tr.t('من'), '${str(L['start'])} لـ ${iso(Engine.lend(L))}'),
      _kv(Tr.t('الإيجار'), money(n0(L['rent']))),
      if (_depOf(L) != null) _kv(Tr.t('🔐 التأمين'), '${money(n0(_depOf(L)!['a']))} ${str(_depOf(L)!['mode']) == 'chq' ? '(شيك ضمان)' : 'كاش'}${truthy(_depOf(L)!['r']) ? ' • اترد ${_depOf(L)!['r']}' : ''}'),
      for (final (q, c) in Chq.list(L).indexed) InkWell(onTap: () async { await Chq.edit(context, L, q); if (mounted) setState(() {}); }, onLongPress: () async { await Chq.del(context, L, q); if (mounted) setState(() {}); },
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('📑 ${str(c['no']).isEmpty ? 'شيك' : 'شيك ${c['no']}'} • ${c['d']} • ${money(n0(c['a']))}', style: const TextStyle(fontSize: 12, color: kMuted)))),
      const Divider(),
      Text(Tr.t('دوس على الشهر علشان تسجّل إنه اتدفع'), style: TextStyle(color: kMuted, fontSize: 12)),
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

  Obj? _depOf(Obj L) { final D = objs(Store.I.S['dep']); return D.where((x) => x['lid'] == L['id'] && !truthy(x['r'])).firstOrNull ?? D.where((x) => x['lid'] == L['id']).firstOrNull; }

  Future<void> _leaseMenu(int k, String v) async {
    final L = objs(u['leases'])[k];
    if (v == 'renew') { Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaseEdit(u, null, renew: L))); return; }
    if (v == 'chq') { await Chq.edit(context, L, null); if (mounted) setState(() {}); return; }
    if (v == 'refund') {
      final d = _depOf(L)!;
      final o = await formDlg(context, 'رد التأمين — ${str(L['tenant'])}', [FieldSpec('r', Tr.t('تاريخ الرد'), type: 'd', v: Act.td())]);
      if (o == null) return;
      d['r'] = truthy(o['r']) ? o['r'] : Act.td(); d['rat'] = str(d['mode']) == 'chq' ? 0 : Act.now();
      await Store.I.save(log: '🔐 رديت التأمين ${money(n0(d['a']))} — ${str(L['tenant'])}');
      if (mounted) { setState(() {}); toast(context, Tr.t('✅ اتسجل رد التأمين')); }
      return;
    }
    final ds = [str(L['start']), for (final i in Engine.rcv(L)) iso(Engine.payD(L, i))];
    if (!await lockOk(context, ds) || !mounted) return;
    if (v == 'stop') {
      final o = await formDlg(context, 'وقف العقد — ${str(L['tenant'])}', [FieldSpec('exit', Tr.t('تاريخ وقف العقد (خروج المستأجر)'), type: 'd', v: truthy(L['exit']) ? L['exit'] : Act.td()), FieldSpec('pen', Tr.t('غرامة الخروج المبكر (الشرط الجزائي) — 0 إن لم توجد'), type: 'n', v: str(L['pen'] ?? 0))]);
      if (o == null || !mounted) return;
      final pen = double.tryParse(o['pen'] ?? '') ?? 0;
      final paid = pen > 0 && await confirmDlg(context, 'هل دفع المستأجر الغرامة (${money(pen)})؟', ok: Tr.t('أيوه دفع'));
      await Act.stopLease(u, k, o['exit'] ?? Act.td(), pen, paid);
    } else if (v == 'resume') { if (await confirmDlg(context, Tr.t('استئناف العقد وإلغاء الوقف والغرامة؟'))) await Act.resumeLease(u, k); }
    else if (v == 'pen') { await Act.togPen(u, k); }
    else if (v == 'del') { if (await confirmDlg(context, 'حذف عقد «${str(L['tenant'])}»؟\n(تقدر ترجعه بعدين من «🗑 سلة المحذوفات»)', ok: Tr.t('🗑 احذف'))) await Act.delLease(u, k, Ws.I.resolve()); }
  }

  Future<void> _rent(int k, int i, bool got) async {
    final L = objs(u['leases'])[k];
    if (!await lockOk(context, [iso(Engine.payD(L, i))])) return;
    if (!mounted) return;
    if (got) {
      if (await confirmDlg(context, 'إلغاء استلام دفعة ${i + 1} من ${str(L['tenant'])}؟', ok: Tr.t('إلغاء الاستلام'))) await Act.rentUnpaid(u, k, i);
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
    if (truthy(i['p'])) { if (await confirmDlg(context, 'إلغاء تسجيل دفعة الشركة ${money(n0(i['a']))}؟', ok: Tr.t('إلغاء'))) await Act.instUnpay(u, k); return; }
    final opts = <List<String>>[['', Tr.t('دون خصم من الرصيد (دُفعت من بره البرنامج)')], ['cash', Tr.t('من الرصيد النقدي في البرنامج')], if (Act.gpOK(u)) ['gp', Tr.t('من فلوس الشراكة (دعم الشركاء)')]];
    final def = (k == 0 && Act.gpOK(u) && !objs(u['inst']).asMap().entries.any((e) => e.key != 0 && truthy(e.value['p']))) ? 'gp' : '';
    final src = await pickDlg(context, 'تسجيل دفعة للشركة — ${money(n0(i['a']))}\nمن أين دُفعت؟', opts, def);
    if (src != null) await Act.instPay(u, k, src);
  }

  Widget _pill(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(10)), child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)));
  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Flexible(child: Text('$k: ', style: const TextStyle(color: kMuted))), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.bold)))]));
}
