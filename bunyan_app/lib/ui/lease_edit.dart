import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/lease.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';

/// عقد مستأجر جديد / تعديل — نفس شاشة «📄 عقد مستأجر جديد» في القديم
class LeaseEdit extends StatefulWidget {
  final Obj u; final int? k; final Obj? renew;
  const LeaseEdit(this.u, this.k, {super.key, this.renew});
  @override
  State<LeaseEdit> createState() => _LeaseEditState();
}

class _LeaseEditState extends State<LeaseEdit> {
  final f = LeaseForm();
  bool man = false, m0Auto = true, canBuild = true, locked = false;
  bool get edit => widget.k != null;
  late final Map<String, TextEditingController> c;

  @override
  void initState() {
    super.initState();
    final u = widget.u;
    if (edit) {
      final L = objs(u['leases'])[widget.k!];
      final dp = objs(Store.I.S['dep']).where((x) => x['lid'] == L['id'] && !truthy(x['r'])).firstOrNull ?? objs(Store.I.S['dep']).where((x) => x['lid'] == L['id']).firstOrNull;
      f..tenant = str(L['tenant'])..phone = str(L['phone'])..start = str(L['start'])..rent = n0(L['rent'])..day = truthy(L['day']) ? str(L['day']) : ''
        ..cmo = n0(L['cmo']) > 0 ? n(L['cmo']) : ((Engine.lm(L) * 100).round() / 100).clamp(1, 999).toDouble()
        ..fee = truthy(L['fee']) ? n0(L['adv']) : 0..pm0 = truthy(L['pm0']) ? str(L['pm0']) : 'cash'..chqOn = false..cno = str(L['cno'])
        ..dk = dp != null ? (truthy(dp['mode']) ? str(dp['mode']) : 'cash') : ''..da = dp != null ? n0(dp['a']) : null..dno = str(dp?['no'])..tid = str(L['tid'])..nat = str(L['nat']);
      man = true; m0Auto = false;
      final sch = objs(L['sch']);
      f.rows = [for (var i = 0; i < sch.length; i++) () {
        final lk = Engine.rcv(L).contains(i) || (obj(L['ov'])?['$i'] != null) || Engine.ppA(L, i) > 0;
        if (lk) canBuild = false;
        return LRow(str(sch[i]['d']), n0(sch[i]['a']), oi: i, lock: lk);
      }()];
      if (!canBuild) locked = true;
      f.m0 = (sch.isNotEmpty && f.rent > 0) ? (n0(sch[0]['a']) / f.rent * 100).round() / 100 : 1;
    } else {
      f..start = Act.td()..cmo = 6..firstPaid = true..chqOn = true..dk = '';
      final R = widget.renew;
      if (R != null) { // نفس rnRenew: نفس المستأجر والإيجار ويبدأ من نهاية العقد القديم
        final mo = truthy(R['orig']) ? n(R['orig']) : (truthy(R['months']) ? n(R['months']) : 12);
        f..tenant = str(R['tenant'])..phone = str(R['phone'])..start = iso(Engine.lend(R))..rent = n0(R['rent'])..day = truthy(R['day']) ? str(R['day']) : ''..cmo = mo.toDouble();
      }
      f.m0 = LeaseB.sugM(pd(f.start), LeaseB.payDay(f.start, f.day));
      if (R != null) _rebuild();
    }
    c = {
      'tenant': TextEditingController(text: f.tenant), 'phone': TextEditingController(text: f.phone), 'tid': TextEditingController(text: f.tid), 'nat': TextEditingController(text: f.nat),
      'cmo': TextEditingController(text: _s(f.cmo)), 'rent': TextEditingController(text: f.rent > 0 ? _s(f.rent) : ''), 'day': TextEditingController(text: f.day),
      'm0': TextEditingController(text: _s(f.m0)), 'cno': TextEditingController(text: f.cno), 'da': TextEditingController(text: f.da == null ? '' : _s(f.da!)),
      'dno': TextEditingController(text: f.dno), 'fee': TextEditingController(text: f.fee > 0 ? _s(f.fee) : ''),
    };
  }

  String _s(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _rebuild() {
    if (f.start.isEmpty || !(f.rent > 0) || !(f.cmo > 0)) { f.rows = []; return; }
    final b = LeaseB.build(start: f.start, cmo: f.cmo, rent: f.rent, day: f.day, m0: f.m0);
    f.rows = [for (var i = 0; i < b.length; i++) LRow(b[i]['d'], b[i]['a'], first: i == 0)];
    _renum(true);
  }
  void _rebuildKeep() {
    final lk = [for (var i = 0; i < f.rows.length; i++) if (f.rows[i].lock) i];
    if (lk.length > 1 || (lk.length == 1 && lk[0] != 0)) { toast(context, L.t('فيه دفعات مستلمة بعد الأولى — عدّل مبالغ الجدول يدوياً أو اضغط إعادة بناء')); return; }
    if (f.start.isEmpty || !(f.rent > 0) || !(f.cmo > 0)) return;
    final b = LeaseB.build(start: f.start, cmo: f.cmo, rent: f.rent, day: f.day, m0: f.m0);
    final nr = [for (var i = 0; i < b.length; i++) LRow(b[i]['d'], b[i]['a'], first: i == 0)];
    if (lk.length == 1 && f.rows.isNotEmpty) { final r0 = f.rows[0]; nr[0]..oi = r0.oi..lock = true..d = r0.d..no = r0.no; f.f0chg = nr[0].a != r0.a || f.f0chg; }
    f.rows = nr; _renum(false);
  }
  void _renum(bool all) {
    final no = f.cno.trim(); final num0 = RegExp(r'^\d+$').hasMatch(no) ? int.parse(no) : null; final w = no.length; var j = 0;
    for (final r in f.rows) {
      if (!LeaseSave.chqOK(f, r)) { if (all) r.no = ''; continue; }
      if (num0 != null) { if (all || r.no.isEmpty) r.no = '${num0 + j}'.padLeft(w, '0'); } else if (all) { r.no = ''; }
      j++;
    }
  }

  void _set(String k, String v) {
    setState(() {
      switch (k) {
        case 'start': f.start = v; break;
        case 'day': f.day = v; break;
        case 'cmo': f.cmo = double.tryParse(v) ?? 0; break;
        case 'rent': f.rent = double.tryParse(v) ?? 0; break;
        case 'm0': f.m0 = double.tryParse(v) ?? 1; m0Auto = false; break;
      }
      if (m0Auto && (k == 'start' || k == 'day') && f.start.isNotEmpty) { final m = LeaseB.sugM(pd(f.start), LeaseB.payDay(f.start, f.day)); f.m0 = m; c['m0']!.text = _s(m); }
      if (!man && canBuild) { _rebuild(); } else { _rebuildKeep(); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final total = f.rows.fold<num>(0, (s, r) => s + r.a); final want = (f.rent * f.cmo).round(); final df = total - want; final bad = df.abs() > .5 && want > 0;
    return Directionality(textDirection: L.dir, child: Scaffold(
      appBar: AppBar(title: Text(edit ? L.t('📄 تعديل عقد المستأجر') : L.t('📄 عقد مستأجر جديد'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _tf('tenant', L.t('اسم المستأجر'), (v) => f.tenant = v),
        _tf('phone', L.t('واتساب المستأجر (مع كود الدولة)'), (v) => f.phone = v, ltr: true, hint: '9715xxxxxxxx'),
        Row(children: [Expanded(child: _tf('tid', L.t('🪪 رقم الهوية (للعقد)'), (v) => f.tid = v)), const SizedBox(width: 8), Expanded(child: _tf('nat', L.t('الجنسية'), (v) => f.nat = v))]),
        _h(L.t('مدة العقد والإيجار')),
        _date(L.t('بداية العقد'), f.start, locked ? null : (v) => _set('start', v)),
        _tf('cmo', L.t('مدة العقد (بالشهور)'), (v) => _set('cmo', v), num: true),
        Wrap(spacing: 6, children: [for (final x in [[1, L.t('شهر')], [2, L.t('شهرين')], [3, L.t('3 شهور')], [6, L.t('6 شهور')], [12, L.t('سنة')]]) ActionChip(label: Text('${x[1]}'), onPressed: () { c['cmo']!.text = '${x[0]}'; _set('cmo', '${x[0]}'); })]),
        const SizedBox(height: 8),
        _tf('rent', L.t('الإيجار الشهري'), (v) => _set('rent', v), num: true),
        _tf('day', L.t('يوم الدفع كل شهر (فارغ = نفس يوم البداية)'), (v) => _set('day', v), num: true),
        _tf('m0', L.t('الدفعة الأولى تغطي كم شهراً؟'), (v) => _set('m0', v), num: true),
        Text(L.t('مثال: العقد يبدأ يوم 1 والمستأجر يدفع يوم 15: الدفعة الأولى شهر ونصف حتى يوم 15، ثم الإيجار كل 15، وآخر دفعة نصف شهر لتكتمل المدة.'), style: TextStyle(color: kMuted, fontSize: 12, height: 1.6)),
        _h(L.t('جدول الدفعات')),
        if (f.rows.isEmpty) Text(L.t('اكتب الإيجار الشهري ومدة العقد ليُبنى الجدول.'), style: TextStyle(color: kMuted)),
        for (var i = 0; i < f.rows.length; i++) _row(i),
        Container(
          margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: bad ? const Color(0xFFFDECEC) : const Color(0xFFE8F3EE), borderRadius: BorderRadius.circular(12)),
          child: Text('قيمة العقد (${money(f.rent)} × ${_s(f.cmo)}): ${money(want)} • مجموع الدفعات: ${money(total)} (${f.rows.length})${bad ? ' • ⚠️ الفرق ${df > 0 ? '+' : ''}${money(df)} — راجع الجدول' : (want > 0 ? ' ✓ مطابق' : '')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
        ),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: () => setState(() { final l = f.rows.isNotEmpty ? pd(f.rows.last.d) : pd(f.start.isEmpty ? Act.td() : f.start); f.rows.add(LRow(iso(LeaseB.addMo(l, 1)), f.rent.round())); man = true; _renum(false); }), child: Text(L.t('+ دفعة'))),
          if (canBuild) OutlinedButton(onPressed: () => setState(() { man = false; _rebuild(); }), child: Text(L.t('🔄 إعادة بناء الجدول'))),
        ]),
        if (!edit) ...[
          _h(L.t('الدفعة الأولى')),
          DropdownButtonFormField<String>(value: f.pm0, decoration: InputDecoration(labelText: L.t('طريقة دفع الدفعة الأولى'), border: OutlineInputBorder()),
            items: [DropdownMenuItem(value: 'cash', child: Text(L.t('نقداً'))), DropdownMenuItem(value: 'bank', child: Text(L.t('تحويل بنكي'))), DropdownMenuItem(value: 'chq', child: Text(L.t('شيك')))],
            onChanged: (v) => setState(() { f.pm0 = v ?? 'cash'; _renum(true); })),
          CheckboxListTile(value: f.firstPaid, onChanged: (v) => setState(() { f.firstPaid = v ?? false; _renum(true); }), title: Text(L.t('تم استلام الدفعة الأولى الآن (مطلوب: إيجار شهر على الأقل)')), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero),
        ],
        _h(L.t('الشيكات')),
        CheckboxListTile(value: f.chqOn, onChanged: (v) => setState(() { f.chqOn = v ?? false; _renum(true); }), title: Text(edit ? L.t('إعادة كتابة الشيكات من الجدول (يمسح شيكاتي الحالية)') : L.t('شيك لكل دفعة قادمة (ضمان — للعلم فقط ولا يغيّر الحسابات)')), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero),
        if (f.chqOn) _tf('cno', L.t('رقم أول شيك (الباقي بيتعدّ لوحده)'), (v) => setState(() { f.cno = v; _renum(true); })),
        _h(L.t('التأمين المسترد')),
        DropdownButtonFormField<String>(value: f.dk, decoration: InputDecoration(labelText: L.t('نوع التأمين'), border: OutlineInputBorder()),
          items: [DropdownMenuItem(value: '', child: Text(L.t('بدون تأمين'))), DropdownMenuItem(value: 'chq', child: Text(L.t('شيك ضمان بدون تاريخ'))), DropdownMenuItem(value: 'cash', child: Text(L.t('تأمين نقدي')))],
          onChanged: (v) => setState(() => f.dk = v ?? '')),
        if (f.dk.isNotEmpty) ...[const SizedBox(height: 8), _tf('da', L.t('مبلغ التأمين (فارغ = إيجار شهر)'), (v) => f.da = double.tryParse(v), num: true)],
        if (f.dk == 'chq') _tf('dno', L.t('رقم شيك التأمين'), (v) => f.dno = v),
        _h(L.t('رسوم كتابة العقد')),
        _tf('fee', L.t('المبلغ الذي دفعه المستأجر (0 إن لم يكن هناك رسوم)'), (v) => f.fee = double.tryParse(v) ?? 0, num: true),
        Text(L.t('تُحسب إيراداً لك في تاريخ بداية العقد، ولا تدخل في الإيجار ولا في الشيكات.'), style: TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: Text(L.t('حفظ العقد'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 30),
      ]),
    ));
  }

  Future<void> _save() async {
    final err = LeaseSave.validate(f, edit: edit);
    if (err != null) { toast(context, err); return; }
    final u = Act.unit(str(widget.u['id'])) ?? widget.u;
    final L = LeaseSave.save(Store.I.S, u, widget.k, f, uid: Act.uid, now: Act.now());
    await Store.I.save(log: edit ? '✏️ عدّلت عقد ${str(L['tenant'])} — ${str(u['name'])}' : '📄 عقد جديد: ${str(L['tenant'])} — ${str(u['name'])}');
    if (mounted) { toast(context, edit ? L.t('تم تعديل العقد') : L.t('تم حفظ العقد وجدول الدفعات')); Navigator.pop(context); }
  }

  Widget _row(int i) {
    final r = f.rows[i];
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
      SizedBox(width: 22, child: Text('${i + 1}', style: const TextStyle(color: kMuted))),
      Expanded(flex: 5, child: InkWell(
        onTap: r.lock ? null : () async { final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(r.d) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2040)); if (d != null) setState(() { r.d = iso(d); man = true; }); },
        child: InputDecorator(decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), child: Text(r.d)),
      )),
      const SizedBox(width: 6),
      Expanded(flex: 4, child: TextFormField(
        key: ValueKey('a$i${r.d}${r.a}'), initialValue: _s(r.a), enabled: !r.lock, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        onFieldSubmitted: (v) => setState(() { r.a = num.tryParse(v) ?? 0; man = true; }),
        onChanged: (v) { r.a = num.tryParse(v) ?? 0; man = true; },
      )),
      r.lock ? const Padding(padding: EdgeInsets.all(8), child: Text('✓', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)))
          : IconButton(onPressed: () { if (f.rows.length <= 1) { toast(context, L.t('لازم يكون في العقد دفعة واحدة على الأقل')); return; } setState(() { f.rows.removeAt(i); man = true; _renum(false); }); }, icon: const Icon(Icons.close, size: 18)),
    ]));
  }

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)));
  Widget _tf(String k, String l, void Function(String) on, {bool num = false, bool ltr = false, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c[k], onChanged: on, textDirection: ltr ? TextDirection.ltr : null, keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(labelText: l, hintText: hint, border: const OutlineInputBorder())),
      );
  Widget _date(String l, String v, void Function(String)? on) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(
        onTap: on == null ? null : () async { final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(v) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2040)); if (d != null) on(iso(d)); },
        child: InputDecorator(decoration: InputDecoration(labelText: l, border: const OutlineInputBorder()), child: Text(v)),
      ));
}
