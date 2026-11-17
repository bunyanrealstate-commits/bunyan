import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/store.dart';
import '../core/media.dart';
import '../core/native.dart';
import 'theme.dart';
import 'thumb.dart';
import 'client.dart';
import 'send.dart';

/// 🔎 العميل عايز إيه؟ النوع + الدفع + الميزانية ← المتاح ← ابعته على الواتساب
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchState();
}

class _SearchState extends State<SearchPage> {
  final types = <String>{'1bk'}; String pay = '3'; bool terms = false; bool? fur; final bc = TextEditingController(), qc = TextEditingController(); double tol = 10;
  final picked = <String>{};

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (context, _) {
        final res = Search.run(Store.I.villas, types: types, pay: pay, budget: numOf(bc.text), tol: tol, q: qc.text, fur: fur);
        final sel = res.where((x) => picked.contains('${(x['v'] as Obj)['id']}/${(x['u'] as Obj)['id']}')).toList();
        return Scaffold(
          appBar: AppBar(title: const Text('🔎 العميل عايز إيه؟')),
          body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 100), children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in kTypes.where((t) => t[0] != 'x')) FilterChip(label: Text(t[1], style: TextStyle(color: types.contains(t[0]) ? Colors.white : kInk)), selected: types.contains(t[0]), showCheckmark: false, onSelected: (b) => setState(() { b ? types.add(t[0]) : types.remove(t[0]); })),
            ]),
            const SizedBox(height: 10),
            SegmentedButton<String>(segments: const [ButtonSegment(value: 'f', label: Text('🛋️ مفروش')), ButtonSegment(value: 'e', label: Text('فاضي')), ButtonSegment(value: 'x', label: Text('مش مهم'))], selected: {fur == true ? 'f' : (fur == false ? 'e' : 'x')}, onSelectionChanged: (s) => setState(() => fur = s.first == 'f' ? true : (s.first == 'e' ? false : null))),
            const SizedBox(height: 8),
            SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value: 'mo', label: Text('شهري')), ButtonSegment(value: '1', label: Text('دفعة')), ButtonSegment(value: '2', label: Text('دفعتين')), ButtonSegment(value: '3', label: Text('3 دفعات')), ButtonSegment(value: 'any', label: Text('الكل'))], selected: {pay}, onSelectionChanged: (s) => setState(() => pay = s.first)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: bc, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'ميزانية العميل (شهري أو سنوي)', helperText: _bHint(), prefixIcon: const Icon(Icons.payments_outlined), suffixText: 'درهم'), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              DropdownButton<double>(value: tol, items: [for (final t in [0.0, 5.0, 10.0, 20.0]) DropdownMenuItem(value: t, child: Text(t == 0 ? 'بالظبط' : '± ${t.round()}%'))], onChanged: (v) => setState(() => tol = v ?? 10)),
            ]),
            const SizedBox(height: 8),
            TextField(controller: qc, decoration: const InputDecoration(labelText: 'منطقة / فيلا / شركة (اختياري)', prefixIcon: Icon(Icons.search)), onChanged: (_) => setState(() {})),
            Align(alignment: AlignmentDirectional.centerStart, child: FilterChip(label: Text('📄 ضيف الشروط (تأمين/رسوم) في الرسالة', style: TextStyle(color: terms ? Colors.white : kInk, fontSize: 12.5)), selected: terms, showCheckmark: false, onSelected: (b) => setState(() => terms = b))),
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(res.isEmpty ? (Store.I.villas.isEmpty ? 'لسه مفيش فلل — ضيفها من تبويب «الفلل»' : 'مفيش حاجة متاحة بالمواصفات دي — جرّب «± 20%» أو «أي حاجة»') : '${res.length} شقة متاحة — علّم اللي عايز تبعته', style: const TextStyle(fontWeight: FontWeight.w700, color: kMuted))),
            for (final x in res) _row(x),
          ]),
          floatingActionButton: sel.isEmpty || SendQ.I.active ? null : Row(mainAxisSize: MainAxisSize.min, children: [FloatingActionButton.small(heroTag: 'lnk', tooltip: 'لينك عرض', onPressed: () => _link(sel), child: const Icon(Icons.link)), const SizedBox(width: 8), FloatingActionButton.extended(heroTag: 'snd', onPressed: () => _send(sel), backgroundColor: const Color(0xFF25D366), icon: const Icon(Icons.send, color: Colors.white), label: Text('ابعت ${sel.length} للعميل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))]),
        );
      });

  String? _bHint() {
    final b = numOf(bc.text);
    if (b <= 0) return null;
    return b > 20000 ? 'سنوي = ${money(b)} • يعني ≈ ${money(b / 12)} في الشهر' : 'شهري = ${money(b)} • يعني ≈ ${money(b * 12)} في السنة';
  }

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

  Future<void> _link(List<Map<String, dynamic>> sel) async {
    final c = await pickClient(context);
    if (c == null || !mounted) return;
    await rememberClient(c);
    if (!mounted) return;
    if (await sendOfferLink(context, c, sel, pay)) setState(() => picked.clear());
  }

  Future<void> _send(List<Map<String, dynamic>> sel) async {
    final c = await pickClient(context);
    if (c == null || !mounted) return;
    await rememberClient(c);
    setState(() => picked.clear());
    if (mounted) await SendQ.I.start(context, c, sel, pay, terms: terms);
  }
}
