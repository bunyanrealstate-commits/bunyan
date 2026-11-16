import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/store.dart';
import '../core/media.dart';
import '../core/native.dart';
import 'theme.dart';
import 'thumb.dart';
import 'client.dart';

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
            SegmentedButton<String>(segments: const [ButtonSegment(value: 'mo', label: Text('شهري')), ButtonSegment(value: '1', label: Text('دفعة واحدة')), ButtonSegment(value: '3', label: Text('3 دفعات')), ButtonSegment(value: 'any', label: Text('الكل'))], selected: {pay}, onSelectionChanged: (s) => setState(() => pay = s.first)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: bc, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'ميزانية العميل (شهري أو سنوي)', helperText: _bHint(), prefixIcon: const Icon(Icons.payments_outlined), suffixText: 'درهم'), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              DropdownButton<double>(value: tol, items: [for (final t in [0.0, 5.0, 10.0, 20.0]) DropdownMenuItem(value: t, child: Text(t == 0 ? 'بالظبط' : '± ${t.round()}%'))], onChanged: (v) => setState(() => tol = v ?? 10)),
            ]),
            const SizedBox(height: 8),
            TextField(controller: qc, decoration: const InputDecoration(labelText: 'منطقة / فيلا / شركة (اختياري)', prefixIcon: Icon(Icons.search)), onChanged: (_) => setState(() {})),
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(res.isEmpty ? (Store.I.villas.isEmpty ? 'لسه مفيش فلل — ضيفها من تبويب «الفلل»' : 'مفيش حاجة متاحة بالمواصفات دي — جرّب «± 20%» أو «أي حاجة»') : '${res.length} شقة متاحة — علّم اللي عايز تبعته', style: const TextStyle(fontWeight: FontWeight.w700, color: kMuted))),
            for (final x in res) _row(x),
          ]),
          bottomNavigationBar: _queueBar(),
          floatingActionButton: sel.isEmpty || jobs.isNotEmpty ? null : FloatingActionButton.extended(onPressed: () => _send(sel), backgroundColor: const Color(0xFF25D366), icon: const Icon(Icons.send, color: Colors.white), label: Text('ابعت ${sel.length} للعميل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
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

  /// كل شقة رسالة لوحدها: الفيديو وتحته السعر واللوكيشن — واحدة ورا التانية
  List<Map<String, dynamic>> jobs = [];
  int done = 0;
  Map<String, String> client = {};

  Future<void> _send(List<Map<String, dynamic>> sel) async {
    final c = await pickClient(context);
    if (c == null || !mounted) return;
    final j = <Map<String, dynamic>>[];
    for (final x in sel) {
      final v = x['v'] as Obj, u = x['u'] as Obj;
      final uris = <String>[];
      for (final id in (u['videos'] as List?)?.map(str) ?? const <String>[]) { final r = await Media.uri(id); if (r != null) uris.add(r); }
      j.add({'uris': uris, 'text': unitCaption(v, u, pay, en: c['lang'] == 'en')});
    }
    await rememberClient(c);
    setState(() { jobs = j; done = 0; client = c; picked.clear(); });
    await _next();
  }

  Future<void> _next() async {
    if (done >= jobs.length) return;
    final j = jobs[done];
    final r = await Native.sendWa(phone: client['p'] ?? '', text: j['text'] as String, uris: (j['uris'] as List).cast<String>());
    if (!mounted) return;
    if (r == 'fail') { toast(context, '⚠️ مقدرتش أفتح الواتساب'); return; }
    setState(() => done++);
    if (done >= jobs.length) { toast(context, '✅ خلصت — اتبعت ${jobs.length} شقة'); Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => jobs = []); }); }
  }

  Widget? _queueBar() {
    if (jobs.isEmpty || done >= jobs.length) return null;
    final who = (client['n'] ?? '').isNotEmpty ? client['n']! : ((client['p'] ?? '').isNotEmpty ? '+${client['p']}' : 'العميل');
    return SafeArea(child: Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kBd))),
      child: Row(children: [
        Expanded(child: Text('📤 $who — اتبعت $done من ${jobs.length}\nدوس إرسال في الواتساب وارجع هنا', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        TextButton(onPressed: () => setState(() => jobs = []), child: const Text('إلغاء')),
        FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)), onPressed: _next, icon: const Icon(Icons.send, color: Colors.white), label: Text('ابعت ${done + 1}', style: const TextStyle(color: Colors.white))),
      ]),
    ));
  }
}
