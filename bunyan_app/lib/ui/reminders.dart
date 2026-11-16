import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/reminders.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  @override
  void initState() { super.initState(); Store.I.addListener(_r); }
  void _r() { if (mounted) setState(() {}); }
  @override
  void dispose() { Store.I.removeListener(_r); super.dispose(); }

  List<dynamic> get L => (Store.I.S['rem'] as List?) ?? (Store.I.S['rem'] = <dynamic>[]);

  @override
  Widget build(BuildContext context) {
    final rs = objs(L)..sort((a, b) => Rem.nextAt(a).compareTo(Rem.nextAt(b)));
    final now = DateTime.now().millisecondsSinceEpoch;
    return Directionality(textDirection: Tr.dir, child: Scaffold(
      appBar: AppBar(title: Text(Tr.t('⏰ تذكيراتي')), actions: [IconButton(tooltip: Tr.t('جرّب إشعار'), onPressed: () => Rem.test(), icon: const Icon(Icons.notifications_active))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(null), icon: const Icon(Icons.add_alarm), label: Text(Tr.t('تذكير جديد'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
        FutureBuilder<bool>(future: Rem.oldInstalled(), builder: (_, s) => s.data == true ? Card(color: Color(0xFFFFF4E0), child: Padding(padding: EdgeInsets.all(12), child: Text(Tr.t('ℹ️ الإشعارات بتيجي من بنيان القديم دلوقتي علشان متجيش مرتين — لما تمسح القديم، التطبيق ده هو اللي هيرن لوحده.'), style: TextStyle(height: 1.6)))) : const SizedBox()),
        if (rs.isEmpty) Padding(padding: EdgeInsets.all(30), child: Text(Tr.t('مفيش تذكيرات'), textAlign: TextAlign.center)),
        for (final r in rs) Builder(builder: (_) {
          final at = Rem.nextAt(r); final past = r['rp'] == 'once' && at <= now; final d = DateTime.fromMillisecondsSinceEpoch(at);
          return Card(child: ListTile(
            leading: Switch(value: r['on'] != false, onChanged: (v) async { r['on'] = v; await _save('⏰ ${v ? 'شغّلت' : 'وقّفت'} تذكير: ${str(r['t'])}'); }),
            title: Text(str(r['t']), style: TextStyle(fontWeight: FontWeight.bold, decoration: past ? TextDecoration.lineThrough : null)),
            subtitle: Text('${iso(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} • ${Rem.rpl[r['rp']] ?? ''}${str(r['n']).isEmpty ? '' : '\n${str(r['n'])}'}'),
            isThreeLine: str(r['n']).isNotEmpty,
            onTap: () => _edit(r),
            onLongPress: () async { if (await confirmDlg(context, 'مسح التذكير «${str(r['t'])}»؟', ok: Tr.t('مسح'))) { L.remove(r); await _save('🗑 مسحت تذكير: ${str(r['t'])}'); } },
          ));
        }),
        if (rs.any((r) => r['rp'] == 'once' && Rem.nextAt(r) <= now)) TextButton(onPressed: () async { L.removeWhere((r) => r is Map && r['rp'] == 'once' && Rem.nextAt(r.cast<String, dynamic>()) <= DateTime.now().millisecondsSinceEpoch); await _save(Tr.t('🧹 مسحت التذكيرات اللي فاتت')); }, child: Text(Tr.t('🧹 امسح اللي فات'))),
      ]),
    ));
  }

  Future<void> _save(String log) async { await Store.I.save(log: log); Rem.schedule(); }

  Future<void> _edit(Obj? r) async {
    var rp = str(r?['rp']).isEmpty ? 'once' : str(r!['rp']);
    final o = await formDlg(context, r == null ? Tr.t('تذكير جديد') : Tr.t('تعديل تذكير'), [
      FieldSpec('t', Tr.t('التذكير'), v: r?['t'] ?? ''), FieldSpec('n', Tr.t('ملاحظة (اختياري)'), v: r?['n'] ?? ''),
      FieldSpec('d', Tr.t('التاريخ'), type: 'd', v: r?['d'] ?? Act.td()), FieldSpec('tm', Tr.t('الساعة (مثلاً 09:30)'), v: r?['tm'] ?? '09:00'),
    ]);
    if (o == null || !mounted) return;
    final p = await pickDlg(context, Tr.t('بيتكرر؟'), [for (final e in Rem.rpl.entries) [e.key, e.value]], rp);
    if (p != null) rp = p;
    final x = r ?? <String, dynamic>{'id': Act.uid(), 'on': true};
    x['t'] = (o['t'] ?? '').trim(); x['n'] = (o['n'] ?? '').trim(); x['d'] = o['d']; x['tm'] = RegExp(r'^\d{1,2}:\d{2}$').hasMatch(o['tm'] ?? '') ? o['tm'] : '09:00'; x['rp'] = rp; x['last'] = 0;
    x['nx'] = Rem.nextAt(x);
    if (r == null) L.add(x);
    await _save(r == null ? '⏰ تذكير جديد: ${x['t']}' : '✏️ عدّلت تذكير: ${x['t']}');
  }
}
