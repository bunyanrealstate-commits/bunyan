import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/store.dart';
import '../core/media.dart';
import '../core/native.dart';
import 'theme.dart';
import 'thumb.dart';

/// 🔎 العميل عايز إيه؟ النوع + الدفع + الميزانية ← المتاح ← ابعته على الواتساب
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchState();
}

class _SearchState extends State<SearchPage> {
  final types = <String>{'1bk'}; String pay = 'mo'; final bc = TextEditingController(), qc = TextEditingController(); double tol = 10;
  final picked = <String>{};

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (context, _) {
        final res = Search.run(Store.I.villas, types: types, pay: pay, budget: numOf(bc.text), tol: tol, q: qc.text);
        final sel = res.where((x) => picked.contains('${(x['v'] as Obj)['id']}/${(x['u'] as Obj)['id']}')).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('🔎 العميل عايز إيه؟')),
          body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 100), children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in kTypes.where((t) => t[0] != 'x')) FilterChip(label: Text(t[1], style: TextStyle(color: types.contains(t[0]) ? Colors.white : kInk)), selected: types.contains(t[0]), showCheckmark: false, onSelected: (b) => setState(() { b ? types.add(t[0]) : types.remove(t[0]); })),
            ]),
            const SizedBox(height: 10),
            SegmentedButton<String>(segments: const [ButtonSegment(value: 'mo', label: Text('شهري')), ButtonSegment(value: '3', label: Text('3 دفعات')), ButtonSegment(value: 'any', label: Text('أي حاجة'))], selected: {pay}, onSelectionChanged: (s) => setState(() => pay = s.first)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: bc, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ميزانية العميل في الشهر', prefixIcon: Icon(Icons.payments_outlined), suffixText: 'درهم'), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              DropdownButton<double>(value: tol, items: [for (final t in [0.0, 5.0, 10.0, 20.0]) DropdownMenuItem(value: t, child: Text(t == 0 ? 'بالظبط' : '± ${t.round()}%'))], onChanged: (v) => setState(() => tol = v ?? 10)),
            ]),
            const SizedBox(height: 8),
            TextField(controller: qc, decoration: const InputDecoration(labelText: 'منطقة / فيلا / شركة (اختياري)', prefixIcon: Icon(Icons.search)), onChanged: (_) => setState(() {})),
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(res.isEmpty ? (Store.I.villas.isEmpty ? 'لسه مفيش فلل — ضيفها من تبويب «الفلل»' : 'مفيش حاجة متاحة بالمواصفات دي — جرّب «± 20%» أو «أي حاجة»') : '${res.length} شقة متاحة — علّم اللي عايز تبعته', style: const TextStyle(fontWeight: FontWeight.w700, color: kMuted))),
            for (final x in res) _row(x),
          ]),
          floatingActionButton: sel.isEmpty ? null : FloatingActionButton.extended(onPressed: () => _send(sel), backgroundColor: const Color(0xFF25D366), icon: const Icon(Icons.send, color: Colors.white), label: Text('ابعت ${sel.length} للعميل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        );
      });

  Widget _row(Map<String, dynamic> x) {
    final v = x['v'] as Obj, u = x['u'] as Obj; final key = '${v['id']}/${u['id']}'; final on = picked.contains(key);
    final vids = (u['videos'] as List?)?.map(str).toList() ?? [];
    return Card(color: on ? const Color(0xFFE3F4F5) : null, child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => setState(() => on ? picked.remove(key) : picked.add(key)), child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
      VThumb(vids.isEmpty ? null : vids.first, badge: vids.length > 1 ? Container(padding: const EdgeInsets.symmetric(horizontal: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text('${vids.length}', style: const TextStyle(color: Colors.white, fontSize: 12))) : null),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${typeName(u['type'])}${str(u['no']).isNotEmpty ? ' • شقة ${u['no']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        Text('${str(v['name'])} ${str(v['no'])}${str(v['company']).isNotEmpty ? ' • ${v['company']}' : ''}', style: const TextStyle(color: kMuted, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(Price.text(u), style: const TextStyle(color: kOk, fontWeight: FontWeight.w700, fontSize: 13)),
        if (vids.isEmpty) const Text('⚠️ مفيش فيديو مربوط', style: TextStyle(color: kGold, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ])),
      Checkbox(value: on, onChanged: (_) => setState(() => on ? picked.remove(key) : picked.add(key))),
    ]))));
  }

  Future<void> _send(List<Map<String, dynamic>> sel) async {
    final o = await formDlg(context, '📲 رقم العميل', [const FS('p', 'رقم الواتساب (فاضي = تختار الشات بنفسك)', num: true)], ok: 'افتح الواتساب');
    if (o == null || !mounted) return;
    final uris = <String>[];
    for (final x in sel) { for (final id in ((x['u'] as Obj)['videos'] as List?)?.map(str) ?? const <String>[]) { final u = await Media.uri(id); if (u != null) uris.add(u); } }
    final r = await Native.sendWa(phone: o['p'] ?? '', text: clientMsg(sel), uris: uris);
    if (!mounted) return;
    toast(context, r == 'wa' ? '📤 فتحت شات العميل ومعاه ${uris.length} فيديو والرسالة — دوس إرسال' : r == 'fail' ? '⚠️ مقدرتش أفتح الواتساب' : '📤 اختار العميل ودوس إرسال');
    setState(() => picked.clear());
  }
}
