import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';
import 'shell.dart';

/// الحسابات: الرصيد النقدي، التأمينات، قفل الشهور، الدفتر — نفس accTab في القديم
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});
  @override
  State<AccountsPage> createState() => _AccState();
}

class _AccState extends State<AccountsPage> {
  String q = '';
  static const cl = {'co': '🏢', 'fu': '🛋', 'rn': '💵', 'is': '📶', 'pn': '⚖️', 'ex': '🧾'};

  Map<String, dynamic> get S => Store.I.S;
  String get ws => Ws.I.resolve();

  @override
  Widget build(BuildContext context) {
    final e = Engine(S, WS: ws);
    final lg = e.ledger().where((x) => q.isEmpty || '${x['w']} ${x['u']}'.contains(q)).toList();
    final ids = e.SU().map((u) => u['id']).toSet();
    final deps = objs(S['dep']).where((d) => ws == 'all' || !truthy(d['uid']) || ids.contains(d['uid'])).toList();
    final held = deps.where((d) => str(d['k']) != 'c' && str(d['mode']) != 'chq' && !truthy(d['r'])).fold<double>(0, (s, d) => s + n0(d['a']));
    final cash = e.cashNow();
    final months = <String, double>{};
    for (final x in Engine(S, WS: 'all').ledger()) { final ym = str(x['d']).substring(0, 7); months[ym] = (months[ym] ?? 0) + (x['a'] as double); }
    final locks = lst(S['locks']).map(str).toSet();
    final ymK = months.keys.toList()..sort((a, b) => b.compareTo(a));
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: const Text('الحسابات')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: ListTile(
          leading: const Text('💰', style: TextStyle(fontSize: 24)),
          title: Text('الرصيد النقدي: ${money(cash)}', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('السيولة الصافية بعد التأمينات المحجوزة: ${money(cash - held)}'),
          trailing: const Icon(Icons.edit),
          onTap: _setCash,
        )),
        _h('🔐 التأمينات', action: TextButton.icon(onPressed: () => _dep(null), icon: const Icon(Icons.add), label: const Text('تأمين'))),
        Card(child: Padding(padding: const EdgeInsets.all(10), child: Text('محجوز عندك: ${money(held)}  •  عدد: ${deps.length}'))),
        for (final d in deps) Card(child: ListTile(
          dense: true,
          title: Text('${str(d['w'])} — ${money(n0(d['a']))}'),
          subtitle: Text('${str(d['k']) == 'c' ? 'دفعته أنا' : 'مستلم'} • ${str(d['mode']) == 'chq' ? 'شيك ${str(d['no'])}' : 'كاش'} • ${str(d['d'])}${truthy(d['r']) ? ' • اترد ${str(d['r'])}' : ''}'),
          onTap: () => _dep(d),
          onLongPress: () => _delDep(d),
        )),
        _h('🔒 قفل الشهور'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final ym in ymK.take(18)) FilterChip(
            label: Text('$ym  ${money(months[ym]!)}'), selected: locks.contains(ym),
            avatar: Icon(locks.contains(ym) ? Icons.lock : Icons.lock_open, size: 16),
            onSelected: (_) => _lock(ym, months[ym]!),
          ),
        ]),
        _h('📒 الدفتر (${lg.length})'),
        TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'دوّر', border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() => q = v.trim())),
        const SizedBox(height: 6),
        for (final x in lg.take(400)) ListTile(
          dense: true,
          leading: Text(cl[x['c']] ?? '•', style: const TextStyle(fontSize: 18)),
          title: Text(str(x['w']), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('${x['d']}${str(x['u']).isEmpty ? '' : ' • ${x['u']}'}'),
          trailing: Text(money(x['a'] as double), style: TextStyle(fontWeight: FontWeight.bold, color: (x['a'] as double) < 0 ? kRed : kGreen)),
        ),
      ]),
    ));
  }

  Widget _h(String t, {Widget? action}) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Row(children: [Expanded(child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))), if (action != null) action]));

  Future<void> _setCash() async {
    if (ws == 'all') { toast(context, 'اختر مجموعة أولاً من فوق، وبعدين اكتب رصيدها'); return; }
    final e = Engine(S, WS: ws);
    final r = await formDlg(context, 'الرصيد النقدي الفعلي دلوقتي', [FieldSpec('v', 'الرصيد', type: 'n', v: e.cashNow().round())]);
    if (r == null) return;
    final t = (double.tryParse(r['v'] ?? '') ?? 0) - e.mvO(0);
    final tv = t == t.roundToDouble() ? t.toInt() : t;
    if (ws == '-') { S['cash'] = tv; } else { final gc = S['gc'] is Map<String, dynamic> ? S['gc'] as Map<String, dynamic> : (S['gc'] = <String, dynamic>{}); gc[ws] = tv; }
    await Store.I.save(log: '💰 عدّلت الرصيد النقدي');
    if (mounted) setState(() {});
  }

  Future<void> _lock(String ym, double net) async {
    final l = S['locks'] is List ? S['locks'] as List : (S['locks'] = <dynamic>[]);
    final snap = S['lockSnap'] is Map<String, dynamic> ? S['lockSnap'] as Map<String, dynamic> : (S['lockSnap'] = <String, dynamic>{});
    if (l.contains(ym)) {
      if (!await confirmDlg(context, 'يفتح شهر $ym مرة تانية؟')) return;
      l.remove(ym); snap.remove(ym); await Store.I.save(log: 'فتح شهر $ym');
    } else {
      l.add(ym); snap[ym] = net == net.roundToDouble() ? net.toInt() : net; await Store.I.save(log: 'قفل شهر $ym');
    }
    if (mounted) setState(() {});
  }

  Future<void> _delDep(Obj d) async {
    if (!await confirmDlg(context, 'تمسح تأمين «${str(d['w'])}»؟', ok: 'امسح')) return;
    (S['dep'] as List).remove(d); await Store.I.save(log: '🗑 حذفت تأمين ${str(d['w'])}');
    if (mounted) setState(() {});
  }

  /// نفس mDep: k t|c, mode cash|chq, w, a, d, r
  Future<void> _dep(Obj? d) async {
    final x = d ?? {};
    final k = await pickDlg(context, 'نوع التأمين', [['t', 'مستلم من مستأجر (محجوز عندي)'], ['c', 'دفعته أنا لحد']], truthy(x['k']) ? str(x['k']) : 't');
    if (k == null || !mounted) return;
    final md = await pickDlg(context, 'اتدفع إزاي؟', [['cash', 'كاش'], ['chq', 'شيك']], truthy(x['mode']) ? str(x['mode']) : 'cash');
    if (md == null || !mounted) return;
    final r0 = await formDlg(context, d == null ? 'تأمين جديد' : 'تعديل تأمين', [
      FieldSpec('w', 'الاسم', v: str(x['w'])),
      FieldSpec('a', 'المبلغ', type: 'n', v: truthy(x['a']) ? x['a'] : ''),
      FieldSpec('d', 'التاريخ', type: 'd', v: truthy(x['d']) ? str(x['d']) : Act.td()),
      FieldSpec('r', 'تاريخ الرد (فاضي = لسه)', type: 'd', v: str(x['r'])),
    ]);
    if (r0 == null) return;
    final r = {...r0, 'k': k, 'mode': md};
    final l = S['dep'] is List ? S['dep'] as List : (S['dep'] = <dynamic>[]);
    final mode = r['mode'] == 'chq' ? 'chq' : 'cash'; final wasCash = d != null && str(d['mode']) != 'chq';
    final o = d ?? <String, dynamic>{};
    final a = double.tryParse(r['a'] ?? '') ?? 0;
    o['k'] = r['k'] == 'c' ? 'c' : 't'; o['mode'] = mode; o['w'] = r['w'] ?? ''; o['a'] = a == a.roundToDouble() ? a.toInt() : a; o['d'] = r['d'] ?? Act.td();
    final rr = (r['r'] ?? '').trim();
    o['at'] = mode == 'cash' ? (wasCash && truthy(o['at']) ? o['at'] : Act.now()) : 0;
    o['rat'] = (rr.isNotEmpty && mode == 'cash') ? (truthy(o['rat']) && truthy(o['r']) ? o['rat'] : Act.now()) : 0;
    o['r'] = rr;
    if (d == null) l.add(o);
    await Store.I.save(log: '🔐 ${d == null ? 'تأمين جديد' : 'عدّلت تأمين'}: ${str(o['w'])}');
    if (mounted) setState(() {});
  }
}
