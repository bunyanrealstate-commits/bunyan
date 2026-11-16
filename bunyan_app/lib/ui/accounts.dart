import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';
import 'shell.dart';

/// الحسابات: الرصيد النقدي، التأمينات، قفل الشهور، الدفتر — نفس accTab في القديم
class AccountsPage extends StatefulWidget {
  final bool inTab;
  const AccountsPage({super.key, this.inTab = false});
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
    return Directionality(textDirection: Tr.dir, child: Scaffold(
      appBar: widget.inTab ? null : AppBar(title: Text(Tr.t('الحسابات'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Card(child: ListTile(
          leading: const Text('💰', style: TextStyle(fontSize: 24)),
          title: Text('الرصيد النقدي: ${money(cash)}', style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text('السيولة الصافية بعد التأمينات المحجوزة: ${money(cash - held)}'),
          trailing: const Icon(Icons.edit),
          onTap: _setCash,
        )),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => _draw(true), child: Text(Tr.t('🙋 سحب لحاجاتي')))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton(onPressed: () => _draw(false), child: Text(Tr.t('🤝 سحب لشريك')))),
        ]),
        Builder(builder: (_) {
          final g = (ws == 'all' || ws == '-') ? '' : ws;
          final ad = objs(S['adj']).where((a) => ws == 'all' || str(a['g']) == g).toList()..sort((a, b) => n0(b['at']).compareTo(n0(a['at'])));
          if (ad.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _h(Tr.t('💸 حركات النقدي (سحب / تمويل / دفعات)')),
            for (final a in ad.take(60)) ListTile(dense: true, title: Text(str(a['w']), maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(iso(DateTime.fromMillisecondsSinceEpoch(n0(a['at']).toInt()))),
              trailing: Text(money(n0(a['a'])), style: TextStyle(fontWeight: FontWeight.bold, color: n0(a['a']) < 0 ? kRed : kGreen)),
              onLongPress: a['k'] == 'draw' ? () => _delAdj(a) : null),
          ]);
        }),
        _h(Tr.t('🔐 التأمينات'), action: TextButton.icon(onPressed: () => _dep(null), icon: const Icon(Icons.add), label: Text(Tr.t('تأمين')))),
        Card(child: Padding(padding: const EdgeInsets.all(10), child: Text('محجوز عندك: ${money(held)}  •  عدد: ${deps.length}'))),
        for (final d in deps) Card(child: ListTile(
          dense: true,
          title: Text('${str(d['w'])} — ${money(n0(d['a']))}'),
          subtitle: Text('${str(d['k']) == 'c' ? 'دفعته أنا' : 'مستلم'} • ${str(d['mode']) == 'chq' ? 'شيك ${str(d['no'])}' : 'كاش'} • ${str(d['d'])}${truthy(d['r']) ? ' • اترد ${str(d['r'])}' : ''}'),
          onTap: () => _dep(d),
          onLongPress: () => _delDep(d),
        )),
        _h(Tr.t('🔒 قفل الشهور')),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final ym in ymK.take(18)) FilterChip(
            label: Text('$ym  ${money(months[ym]!)}'), selected: locks.contains(ym),
            avatar: Icon(locks.contains(ym) ? Icons.lock : Icons.lock_open, size: 16),
            onSelected: (_) => _lock(ym, months[ym]!),
          ),
        ]),
        _h('📒 الدفتر (${lg.length})'),
        TextField(decoration: InputDecoration(prefixIcon: Icon(Icons.search), hintText: Tr.t('دوّر'), border: OutlineInputBorder(), isDense: true), onChanged: (v) => setState(() => q = v.trim())),
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
    if (ws == 'all') { toast(context, Tr.t('اختر مجموعة أولاً من فوق، وبعدين اكتب رصيدها')); return; }
    final e = Engine(S, WS: ws);
    final r = await formDlg(context, Tr.t('الرصيد النقدي الفعلي دلوقتي'), [FieldSpec('v', Tr.t('الرصيد'), type: 'n', v: e.cashNow().round())]);
    if (r == null) return;
    final t = (double.tryParse(r['v'] ?? '') ?? 0) - e.mvO(0);
    final tv = t == t.roundToDouble() ? t.toInt() : t;
    if (ws == '-') { S['cash'] = tv; } else { final gc = S['gc'] is Map<String, dynamic> ? S['gc'] as Map<String, dynamic> : (S['gc'] = <String, dynamic>{}); gc[ws] = tv; }
    await Store.I.save(log: Tr.t('💰 عدّلت الرصيد النقدي'));
    if (mounted) setState(() {});
  }

  /// نفس cmDraw: سحب شخصي أو لشريك — بيتخصم من النقدي ومش بيأثر على الربح
  Future<void> _draw(bool mine) async {
    final g = (ws == 'all' || ws == '-') ? '' : ws;
    final gr = objs(S['groups']).where((x) => x['id'] == g).firstOrNull;
    final nm = str(gr?['name']).replaceFirst(RegExp(r'^\s*مع\s+'), '');
    final ps = <String>['__me', ...nm.isEmpty ? <String>[] : nm.split(RegExp(r'\s+و(?=\S)')).map((x) => x.trim()).where((x) => x.isNotEmpty)];
    for (final a in objs(S['adj'])) { if (truthy(a['p']) && truthy(a['k']) && str(a['g']) == g && !ps.contains(str(a['p']))) ps.add(str(a['p'])); }
    final me = str(Store.I.cfg['u']).isEmpty ? Tr.t('أنا') : str(Store.I.cfg['u']);
    String? p = '__me';
    if (!mine) {
      p = await pickDlg(context, Tr.t('مين اللي سحب؟'), [for (final x in ps.where((x) => x != '__me')) [x, x], ['__other', Tr.t('شخص تاني…')]], ps.length > 1 ? ps[1] : '__other');
      if (p == null || !mounted) return;
    }
    final o = await formDlg(context, mine ? Tr.t('🙋 سحب لحاجاتي الشخصية') : Tr.t('🤝 سحب لشريك'), [
      if (p == '__other') FieldSpec('x', Tr.t('اسمه')),
      FieldSpec('a', Tr.t('المبلغ'), type: 'n'), FieldSpec('d', Tr.t('التاريخ'), type: 'd', v: Act.td()), FieldSpec('w', Tr.t('السبب / ملاحظة')),
    ]);
    if (o == null) return;
    final a = (double.tryParse(o['a'] ?? '') ?? 0).abs();
    if (a == 0) { if (mounted) toast(context, Tr.t('اكتب المبلغ')); return; }
    final who = p == '__other' ? ((o['x'] ?? '').trim().isEmpty ? Tr.t('شخص') : o['x']!.trim()) : p!;
    final d = o['d'] ?? Act.td();
    final at = (d.isNotEmpty && d != Act.td()) ? pd(d).millisecondsSinceEpoch + 12 * 3600000 : Act.now();
    final w = o['w'] ?? '';
    final l = S['adj'] is List ? S['adj'] as List : (S['adj'] = <dynamic>[]);
    l.add({'id': Act.uid(), 'at': at, 'a': -(a == a.roundToDouble() ? a.toInt() : a), 'k': 'draw', 'p': who, 'g': g, 'w': 'سحب ${who == '__me' ? 'شخصي ($me)' : 'لـ $who'}${w.isNotEmpty ? ' — $w' : ''}', 'n': w});
    await Store.I.save(log: '💸 سحب ${money(a)} — ${who == '__me' ? me : who}');
    if (mounted) { setState(() {}); toast(context, 'اتسجل السحب: ${money(a)} — بيتخصم من النقدي ومش بيأثر على الربح'); }
  }

  Future<void> _delAdj(Obj a) async {
    if (!await confirmDlg(context, 'تمسح «${str(a['w'])}»؟', ok: Tr.t('امسح'))) return;
    (S['adj'] as List).remove(a); await Store.I.save(log: '🗑 مسحت ${str(a['w'])}');
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
    if (!await confirmDlg(context, 'تمسح تأمين «${str(d['w'])}»؟', ok: Tr.t('امسح'))) return;
    (S['dep'] as List).remove(d); await Store.I.save(log: '🗑 حذفت تأمين ${str(d['w'])}');
    if (mounted) setState(() {});
  }

  /// نفس mDep: k t|c, mode cash|chq, w, a, d, r
  Future<void> _dep(Obj? d) async {
    final x = d ?? {};
    final k = await pickDlg(context, Tr.t('نوع التأمين'), [['t', Tr.t('مستلم من مستأجر (محجوز عندي)')], ['c', Tr.t('دفعته أنا لحد')]], truthy(x['k']) ? str(x['k']) : 't');
    if (k == null || !mounted) return;
    final md = await pickDlg(context, Tr.t('اتدفع إزاي؟'), [['cash', Tr.t('كاش')], ['chq', Tr.t('شيك')]], truthy(x['mode']) ? str(x['mode']) : 'cash');
    if (md == null || !mounted) return;
    final r0 = await formDlg(context, d == null ? Tr.t('تأمين جديد') : Tr.t('تعديل تأمين'), [
      FieldSpec('w', Tr.t('الاسم'), v: str(x['w'])),
      FieldSpec('a', Tr.t('المبلغ'), type: 'n', v: truthy(x['a']) ? x['a'] : ''),
      FieldSpec('d', Tr.t('التاريخ'), type: 'd', v: truthy(x['d']) ? str(x['d']) : Act.td()),
      FieldSpec('r', Tr.t('تاريخ الرد (فاضي = لسه)'), type: 'd', v: str(x['r'])),
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
