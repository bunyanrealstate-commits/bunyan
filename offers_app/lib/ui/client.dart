import 'package:flutter/material.dart';
import '../core/native.dart';
import '../core/store.dart';
import 'theme.dart';

/// اختيار العميل: سيرش بالاسم من جهات الاتصال (اللي على الواتساب) أو اكتب الرقم
/// بيرجع {'n': الاسم, 'p': الرقم} أو {'p': ''} لو عايز تختار الشات بنفسك
Future<Map<String, String>?> pickClient(BuildContext context) => showModalBottomSheet<Map<String, String>>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const Directionality(textDirection: TextDirection.rtl, child: _Pick()));

List<Map<String, String>> recentClients() => ((Store.I.cfg['recent'] as List?) ?? const []).whereType<Map>().map((m) => {'n': '${m['n'] ?? ''}', 'p': '${m['p'] ?? ''}'}).toList();

Future<void> rememberClient(Map<String, String> c) async {
  if ((c['p'] ?? '').isEmpty) return;
  final l = recentClients()..removeWhere((x) => x['p'] == c['p']);
  l.insert(0, {'n': c['n'] ?? '', 'p': c['p']!});
  Store.I.cfg['recent'] = l.take(15).toList();
  await Store.I.saveCfg();
}

class _Pick extends StatefulWidget {
  const _Pick();
  @override
  State<_Pick> createState() => _PickState();
}

class _PickState extends State<_Pick> {
  final q = TextEditingController();
  List<Map<String, String>> all = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    Native.contacts().then((l) { if (mounted) setState(() { all = l; loading = false; }); });
  }

  @override
  Widget build(BuildContext context) {
    final t = q.text.trim().toLowerCase(), digits = t.replaceAll(RegExp(r'[^\d]'), '');
    final rec = recentClients();
    final List<Map<String, String>> list;
    if (t.isEmpty) {
      list = [...rec, ...all.where((c) => c['wa'] == '1' && !rec.any((r) => r['p'] == c['p'])).take(60)];
    } else {
      final pool = [...rec, ...all.where((c) => !rec.any((r) => r['p'] == c['p']))];
      list = pool.where((c) => c['n']!.toLowerCase().contains(t) || (digits.length >= 3 && c['p']!.contains(digits.startsWith('0') ? digits.substring(1) : digits))).take(80).toList();
    }
    final typed = Native.phone(q.text);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(height: MediaQuery.of(context).size.height * .8, child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 6), child: TextField(controller: q, autofocus: true, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'اسم العميل أو رقمه', prefixIcon: Icon(Icons.person_search)))),
        if (typed.length >= 9 && RegExp(r'^\d+$').hasMatch(typed))
          ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFF25D366), child: Icon(Icons.dialpad, color: Colors.white)), title: Text('ابعت للرقم +$typed', style: const TextStyle(fontWeight: FontWeight.w800)), onTap: () => Navigator.pop(context, {'n': '', 'p': typed})),
        if (loading) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
        if (!loading && all.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('مش قادر أقرا جهات الاتصال — وافق على الإذن، أو اكتب الرقم', style: TextStyle(color: kMuted))),
        Expanded(child: ListView(children: [
          for (final c in list)
            ListTile(
              leading: CircleAvatar(backgroundColor: rec.any((r) => r['p'] == c['p']) ? kGold : const Color(0xFFD5EEF0), child: Text(c['n']!.isEmpty ? '#' : c['n']!.characters.first, style: const TextStyle(fontWeight: FontWeight.w800, color: kInk))),
              title: Text(c['n']!.isEmpty ? '+${c['p']}' : c['n']!, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('+${c['p']}${rec.any((r) => r['p'] == c['p']) ? ' • بعتله قبل كده' : ''}', textDirection: TextDirection.ltr, textAlign: TextAlign.right),
              onTap: () => Navigator.pop(context, c),
            ),
        ])),
        Padding(padding: const EdgeInsets.all(10), child: TextButton.icon(onPressed: () => Navigator.pop(context, {'n': '', 'p': ''}), icon: const Icon(Icons.chat_outlined), label: const Text('هختار الشات بنفسي من الواتساب'))),
      ])),
    );
  }
}
