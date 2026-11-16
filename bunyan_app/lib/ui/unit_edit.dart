import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/unit.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';
import 'shell.dart';
import 'lease_edit.dart';

/// استديو جديد / تعديل استديو — نفس فورم القديم
class UnitEdit extends StatefulWidget {
  final String? id;
  const UnitEdit(this.id, {super.key});
  @override
  State<UnitEdit> createState() => _UnitEditState();
}

class _UnitEditState extends State<UnitEdit> {
  final c = <String, TextEditingController>{};
  String g = '', fsrc = 'cash', src = 'cash', start = '', pstart = '';
  bool mo = false;
  Obj? u;
  late UnitOps op;

  @override
  void initState() {
    super.initState();
    op = UnitOps(Store.I.S, uid: Act.uid, now: Act.now(), td: Act.td());
    u = widget.id == null ? null : Act.unit(widget.id!);
    final x = u ?? {};
    final ws = Ws.I.resolve();
    g = u != null ? str(x['g']) : ((ws == 'all' || ws == '-') ? '' : ws);
    start = truthy(x['start']) ? str(x['start']) : Act.td();
    fsrc = u != null ? ((op.fsrcOf(x) == 'cash' && n0(x['capF']) > 0) ? 'mix' : op.fsrcOf(x)) : 'cash';
    for (final e in {
      'name': str(x['name']), 'company': str(x['company']), 'grace': truthy(x['grace']) ? str(x['grace']) : '0', 'cm': x['cm'] != null ? str(x['cm']) : '12',
      'total': truthy(x['total']) ? str(x['total']) : '', 'first': '', 'n': '4', 'paidN': '1', 'furn': truthy(x['furn']) ? str(x['furn']) : '',
      'fmx': u != null ? str(n0(x['capF']).round()) : '0', 'pmx': u != null ? str(n0(x['capI']).round()) : '', 'mx': '0',
    }.entries) { c[e.key] = TextEditingController(text: e.value); }
  }

  bool get isNew => u == null;
  bool get paidFromCash => !isNew && objs(u!['inst']).any((i) => truthy(i['p']) && n0(i['at']) > 0);

  @override
  Widget build(BuildContext context) {
    final groups = objs(Store.I.S['groups']);
    final fso = [['cash', 'من الرصيد النقدي في البرنامج'], ['me', 'من أموالي الخاصة (رأس مال يُسترد من الإيجار)'], ['mix', 'جزء من الرصيد النقدي وجزء من أموالي الخاصة'], ['gp', 'من فلوس الشراكة (دعم الشركاء)'], ['old', 'دُفع سابقاً (دون خصم من أي رصيد)'], ['', 'لم يُدفع بعد']];
    if (!isNew && op.fsrcOf(u!) == 'split') fso.insert(0, ['split', 'مقسّم: من النقدي / الشراكة / الجيب']);
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: Text(isNew ? 'استديو جديد' : 'تعديل استديو')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _tf('name', 'اسم الاستديو'),
        DropdownButtonFormField<String>(value: groups.any((x) => x['id'] == g) ? g : '', decoration: const InputDecoration(labelText: 'المجموعة (الشراكة)', border: OutlineInputBorder()),
          items: [const DropdownMenuItem(value: '', child: Text('بدون مجموعة')), for (final x in groups) DropdownMenuItem(value: str(x['id']), child: Text(str(x['name'])))],
          onChanged: (v) => setState(() => g = v ?? '')),
        const SizedBox(height: 10),
        _tf('company', 'اسم الشركة'),
        _date('بداية العقد (مع الشركة)', start, (v) => setState(() => start = v)),
        _tf('grace', 'أيام السماح قبل بداية العقد (0 إن لم يوجد)', num: true),
        _tf('cm', 'المدة بالشهور (12 أو 15...)', num: true),
        _tf('total', 'المبلغ الإجمالي', num: true),
        if (isNew) ...[
          _h('دفعات الشركة'),
          _date('ميعاد أول دفعة للشركة (فاضي = بداية العقد)', pstart, (v) => setState(() => pstart = v), clear: true),
          _tf('first', 'مبلغ أول دفعة (فاضي = الإجمالي ÷ عدد الدفعات)', num: true),
          CheckboxListTile(value: mo, onChanged: (v) => setState(() => mo = v ?? false), title: const Text('الدفع شهرياً للشركة (دفعة كل شهر)'), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero),
          if (!mo) _tf('n', 'عدد الدفعات على مدة العقد', num: true),
          _tf('paidN', 'كم دفعة تم دفعها حتى الآن؟', num: true),
        ],
        _h('الأثاث'),
        _tf('furn', 'الأثاث: التكلفة', num: true),
        DropdownButtonFormField<String>(value: fso.any((x) => x[0] == fsrc) ? fsrc : '', isExpanded: true, decoration: const InputDecoration(labelText: 'الأثاث: من أين تم دفعه؟', border: OutlineInputBorder()),
          items: [for (final x in fso) DropdownMenuItem(value: x[0], child: Text(x[1], overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => fsrc = v ?? '')),
        if (fsrc == 'mix') ...[const SizedBox(height: 10), _tf('fmx', 'المبلغ من أموالي الخاصة (والباقي من الرصيد النقدي)', num: true)],
        if (paidFromCash) ...[const SizedBox(height: 10), _tf('pmx', 'دفعات الشركة اللي اتدفعت من الرصيد: كام منها كان من أموالي الخاصة؟ (0 = كلها من النقدي)', num: true)],
        if (isNew) ...[
          _h('دفعات الشركة المدفوعة الآن'),
          DropdownButtonFormField<String>(value: src, isExpanded: true, decoration: const InputDecoration(labelText: 'من أين دُفعت؟ (حصتك)', border: OutlineInputBorder()),
            items: const [DropdownMenuItem(value: 'cash', child: Text('من الرصيد النقدي في البرنامج')), DropdownMenuItem(value: 'me', child: Text('من أموالي الخاصة')), DropdownMenuItem(value: 'mix', child: Text('جزء من الرصيد وجزء من أموالي')), DropdownMenuItem(value: '', child: Text('دُفعت سابقاً (دون خصم)'))],
            onChanged: (v) => setState(() => src = v ?? '')),
          if (src == 'mix') ...[const SizedBox(height: 10), _tf('mx', 'المبلغ من أموالي الخاصة (والباقي من الرصيد)', num: true)],
        ],
        const SizedBox(height: 18),
        FilledButton(onPressed: _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('حفظ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        const SizedBox(height: 30),
      ]),
    ));
  }

  double _n(String k) => double.tryParse(c[k]!.text.trim()) ?? 0;
  num _nn(String k) { final v = _n(k); return v == v.roundToDouble() ? v.toInt() : v; }

  Future<void> _save() async {
    final o = <String, dynamic>{'name': c['name']!.text, 'g': g, 'company': c['company']!.text.trim(), 'start': start, 'grace': _nn('grace'), 'cm': _nn('cm'), 'total': _nn('total')};
    if (isNew) { o.addAll({'pstart': pstart, 'first': c['first']!.text.trim().isEmpty ? '' : _nn('first'), 'mo': mo, 'n': _nn('n'), 'paidN': _nn('paidN'), 'src': src, 'mx': _nn('mx')}); }
    o['furn'] = _nn('furn'); o['fsrc'] = fsrc; o['fmx'] = _nn('fmx'); if (paidFromCash) o['pmx'] = c['pmx']!.text.trim();
    final nu = op.save(widget.id, o);
    await Store.I.save(log: isNew ? '🏠 استديو جديد: ${str(nu['name'])}' : '✏️ عدّلت الاستديو: ${str(nu['name'])}');
    if (!mounted) return;
    if (isNew) {
      toast(context, '✅ اتضاف «${str(nu['name'])}» — اكتب عقد المستأجر');
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => LeaseEdit(nu, null)));
    } else { Navigator.pop(context); }
  }

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 8), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)));
  Widget _tf(String k, String l, {bool num = false}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: c[k], keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder())));
  Widget _date(String l, String v, void Function(String) on, {bool clear = false}) => Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(
        onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(v) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2040)); if (d != null) on(iso(d)); },
        child: InputDecorator(decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), suffixIcon: clear && v.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () => on('')) : null), child: Text(v.isEmpty ? '—' : v)),
      ));
}
