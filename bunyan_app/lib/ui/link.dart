import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/store.dart';
import 'theme.dart';

/// الربط ببنيان القديم: كود واحد بينقل المفتاح، وكل البيانات بتنزل
class LinkScreen extends StatefulWidget {
  const LinkScreen({super.key});
  @override
  State<LinkScreen> createState() => _LinkScreenState();
}

class _LinkScreenState extends State<LinkScreen> {
  final c = TextEditingController();
  String msg = '';
  bool busy = false;
  @override
  void initState() { super.initState(); _clip(); }
  Future<void> _clip() async {
    final d = await Clipboard.getData('text/plain');
    if ((d?.text ?? '').contains('BNYLINK-')) { c.text = d!.text!; _go(); }
  }
  Future<void> _go() async {
    if (!Store.I.link(c.text)) { setState(() => msg = '⚠️ الكود مش مظبوط'); return; }
    setState(() { busy = true; msg = '⏳ بنزّل كل بياناتك من بنيان…'; });
    final m = await Store.I.sync();
    if (mounted) setState(() { busy = false; msg = m; });
  }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
        body: SafeArea(child: ListView(padding: const EdgeInsets.all(22), children: [
          const SizedBox(height: 30),
          const Text('BUNYAN', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: kGreen, letterSpacing: 4)),
          const Text('Furnished', textAlign: TextAlign.center, style: TextStyle(color: kMuted)),
          const SizedBox(height: 30),
          const Text('انقل بياناتك من بنيان القديم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('1) افتح بنيان القديم ← القايمة ← «ربط جهاز جديد» وانسخ الكود\n2) ارجع هنا — هيتلصق لوحده وكل الوحدات والعقود والحسابات هتنزل', style: TextStyle(height: 1.8)),
          const SizedBox(height: 14),
          TextField(controller: c, maxLines: 4, textDirection: TextDirection.ltr, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'BNYLINK-…')),
          const SizedBox(height: 12),
          FilledButton(onPressed: busy ? null : _go, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('اربط وانقل البيانات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center),
        ])),
      ));
}
