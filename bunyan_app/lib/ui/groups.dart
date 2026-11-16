import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/actions.dart';
import '../core/js.dart';
import 'theme.dart';
import 'shell.dart';
import 'dialogs.dart';

/// 📂 المجموعات (الشراكات) + 🤝 فلوس الشراكة + طريقة الحساب (للمجموعة / حصتي)
class GroupsPage extends StatefulWidget {
  final bool inTab;
  const GroupsPage({super.key, this.inTab = false});
  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  @override
  void initState() { super.initState(); Store.I.addListener(_r); }
  void _r() { if (mounted) setState(() {}); }
  @override
  void dispose() { Store.I.removeListener(_r); super.dispose(); }

  Map<String, dynamic> get S => Store.I.S;
  List<Obj> get gs => objs(S['groups']);
  List<dynamic> pots(String id) { final gp = (S['gp'] as Map?) ?? (S['gp'] = <String, dynamic>{}); return (gp[id] as List?) ?? (gp[id] = <dynamic>[]); }
  double tot(String id) => pots(id).fold(0.0, (s, x) => s + n0(obj(x)?['a']));
  List<String> names(Obj g) {
    final a = str(g['pn']).split(RegExp(r'[,،\n]+')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    final nn = (truthy(g['n']) ? n(g['n']).toInt() : 2).clamp(2, 99);
    return [for (var i = 0; i < nn; i++) i < a.length ? a[i] : (i == 0 ? Tr.t('أنا') : 'شريك $i')];
  }

  @override
  Widget build(BuildContext context) {
    final mine = S['pmode'] == 'me';
    return Directionality(textDirection: Tr.dir, child: Scaffold(
      appBar: widget.inTab ? null : AppBar(title: Text(Tr.t('📂 المجموعات والشراكة'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Tr.t('🧮 طريقة حساب الأرقام'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          Text(mine ? Tr.t('الأرباح والتوقعات محسوبة بحصتي الشخصية بس.') : Tr.t('الأرباح والتوقعات محسوبة للمجموعة كاملة (كل الشركاء).'), style: const TextStyle(color: kMuted)),
          const SizedBox(height: 8),
          SegmentedButton<String>(segments: [ButtonSegment(value: 'grp', label: Text(Tr.t('👥 للمجموعة كاملة'))), ButtonSegment(value: 'me', label: Text(Tr.t('👤 حصتي بس')))], selected: {mine ? 'me' : 'grp'},
            onSelectionChanged: (v) async { S['pmode'] = v.first; await Store.I.save(); }),
        ]))),
        const SizedBox(height: 6),
        for (final g in gs) _group(g),
        if (objs(S['units']).any((u) => !truthy(u['g']))) Card(child: ListTile(title: Text(Tr.t('بدون مجموعة')), subtitle: Text('${objs(S['units']).where((u) => !truthy(u['g'])).length} استديو يحتاج ينتقل لمجموعة (افتح الاستديو ← ✎ ← اختار المجموعة)'))),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: () => _edit(null), icon: const Icon(Icons.add), label: Text(Tr.t('مجموعة جديدة'))),
        const SizedBox(height: 30),
      ]),
    ));
  }

  Widget _group(Obj g) {
    final id = str(g['id']); final cnt = objs(S['units']).where((u) => u['g'] == id).length;
    final t = tot(id); final nm = names(g); final sh = Engine.shares(g);
    final e = Engine(S, WS: id); final cashAll = e.cashNow(); final cashMine = e.cashBase() + e.mvO(0, true);
    final P = pots(id);
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(str(g['name']), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
        TextButton(onPressed: () { Ws.I.pick(id); Navigator.pop(context); }, child: Text(Tr.t('فتح'))),
        IconButton(onPressed: () => _edit(g), icon: const Icon(Icons.edit_outlined)),
        IconButton(onPressed: () => _del(g), icon: const Icon(Icons.delete_outline, color: kRed)),
      ]),
      Text('$cnt استديو • حصتي ${str(truthy(g['share']) ? g['share'] : 100)}% ${n0(g['n']) > 1 ? '(من ${str(g['n'])} شركاء${truthy(g['custom']) ? '، نسبة مخصصة' : '، بالتساوي'})' : (n0(g['n']) == 1 ? '(وحدك)' : '')}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
      Text('الرصيد النقدي: ${money(cashAll)}${S['pmode'] == 'me' ? ' • نصيبي: ${money(cashMine)}' : ''}', style: const TextStyle(fontSize: 13)),
      const Divider(),
      Text(Tr.t('🤝 فلوس الشراكة'), style: TextStyle(fontWeight: FontWeight.bold)),
      Text(Tr.t('دعم مالي خارجي مشترك بين الشركاء، منفصل عن الرصيد النقدي — بيتدفع منه أول دفعة للشركة وتكلفة الفرش.'), style: TextStyle(color: kMuted, fontSize: 12)),
      const SizedBox(height: 6),
      Text('الإجمالي: ${money(t)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: sign(t))),
      Wrap(spacing: 10, children: [for (var i = 0; i < nm.length; i++) Chip(label: Text('${nm[i]} (${(sh[i] * 100).round() / 100}%): ${money(t * sh[i] / 100)}'))]),
      Wrap(spacing: 8, children: [
        FilledButton(onPressed: () => _pot(id, 1, str(g['name'])), child: Text(Tr.t('➕ دعم مالي'))),
        OutlinedButton(onPressed: () => _pot(id, -1, str(g['name'])), child: Text(Tr.t('➖ سحب / صرف'))),
        OutlinedButton(onPressed: () => _names(g), child: Text(Tr.t('👥 الأسماء'))),
      ]),
      if (P.isNotEmpty) ExpansionTile(tilePadding: EdgeInsets.zero, title: Text('الحركات (${P.length})'), children: [
        for (var i = P.length - 1; i >= 0; i--) Builder(builder: (_) { final x = obj(P[i]) ?? {}; final a = n0(x['a']); return ListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: Text(str(x['w']).isEmpty ? (a > 0 ? Tr.t('دعم مالي') : Tr.t('سحب/صرف')) : str(x['w'])), subtitle: Text(str(x['d'])),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('${a > 0 ? '+' : ''}${money(a)}', style: TextStyle(color: sign(a), fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () async { if (await confirmDlg(context, Tr.t('حذف هذه الحركة؟'))) { P.removeAt(i); await Store.I.save(log: Tr.t('🗑 حذفت حركة من فلوس الشراكة')); } })])); }),
      ]),
    ])));
  }

  Future<void> _pot(String id, int sign, String gname) async {
    final o = await formDlg(context, '${sign > 0 ? '➕ دعم مالي للشراكة — ' : '➖ سحب/صرف من فلوس الشراكة — '}$gname', [FieldSpec('a', Tr.t('المبلغ'), type: 'n'), FieldSpec('w', Tr.t('البيان (مثلاً: دعم من فلان)')), FieldSpec('d', Tr.t('التاريخ'), type: 'd', v: Act.td())]);
    if (o == null) return; final a = (double.tryParse(o['a'] ?? '') ?? 0).abs(); if (a == 0) return;
    final v = sign * a; pots(id).add({'id': Act.uid(), 'd': (o['d'] ?? '').isEmpty ? Act.td() : o['d'], 'a': v == v.roundToDouble() ? v.toInt() : v, 'w': (o['w'] ?? '').trim()});
    await Store.I.save(log: '🤝 ${sign > 0 ? 'دعم مالي' : 'سحب'} ${money(a)} — $gname');
  }

  Future<void> _names(Obj g) async {
    final o = await formDlg(context, '👥 أسماء الشركاء — ${str(g['name'])}', [FieldSpec('pn', Tr.t('الأسماء مفصولة بفاصلة، أولهم أنت (مثلاً: أسامة، عمرو)'), v: truthy(g['pn']) ? str(g['pn']) : names(g).join(Tr.t('، ')))]);
    if (o == null) return; g['pn'] = o['pn'];
    final c = str(o['pn']).split(RegExp(r'[,،\n]+')).map((x) => x.trim()).where((x) => x.isNotEmpty).length;
    if (c >= 2) { g['n'] = c; if (!truthy(g['custom'])) g['share'] = (10000 / c).round() / 100; }
    await Store.I.save(log: '👥 عدّلت أسماء الشركاء — ${str(g['name'])}');
  }

  Future<void> _edit(Obj? g) async {
    final o = await formDlg(context, g == null ? Tr.t('مجموعة جديدة') : Tr.t('تعديل مجموعة'), [
      FieldSpec('name', Tr.t('اسم المجموعة (مثلاً: مع محمد، أو: وحدي)'), v: g?['name'] ?? ''),
      FieldSpec('n', Tr.t('عدد الشركاء بما فيهم أنت (1 = وحدك • 2 = معك شريك)'), type: 'n', v: g == null ? '1' : str(truthy(g['n']) ? g['n'] : (100 / (truthy(g['share']) ? n(g['share']) : 100)).round().clamp(1, 99))),
      FieldSpec('share', Tr.t('حصتي % (فاضي = بالتساوي، أو اكتب نسبة زي 60)'), type: 'n', v: g != null && truthy(g['custom']) ? str(g['share']) : ''),
    ]);
    if (o == null) return;
    final nn = (double.tryParse(o['n'] ?? '') ?? 1).round().clamp(1, 99); final shv = double.tryParse(o['share'] ?? '') ?? 0; final custom = shv > 0;
    final share = custom ? shv.clamp(1, 100) : (10000 / nn).round() / 100;
    final m = {'name': (o['name'] ?? '').trim().isEmpty ? Tr.t('مجموعة') : o['name']!.trim(), 'n': nn, 'share': share == share.roundToDouble() ? share.toInt() : share, 'custom': custom};
    if (g != null) { g.addAll(m); } else { ((S['groups'] as List?) ?? (S['groups'] = <dynamic>[])).add({'id': 'g${Act.uid()}', ...m}); }
    await Store.I.save(log: g == null ? '📂 مجموعة جديدة: ${m['name']}' : '✏️ عدّلت المجموعة: ${m['name']}');
  }

  Future<void> _del(Obj g) async {
    if (!await confirmDlg(context, Tr.t('هل تريد حذف المجموعة؟ ستبقى استديوهاتها وتتحول إلى "بدون مجموعة".'), ok: Tr.t('حذف'))) return;
    final id = g['id'];
    S['groups'] = gs.where((x) => x['id'] != id).toList();
    for (final u in objs(S['units'])) { if (u['g'] == id) u['g'] = ''; }
    final gc = S['gc']; if (gc is Map) gc.remove(id);
    if (Ws.I.value == id) Ws.I.value = '';
    await Store.I.save(log: '🗑 حذفت مجموعة: ${str(g['name'])}');
  }
}
