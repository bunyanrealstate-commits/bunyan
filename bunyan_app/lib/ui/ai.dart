import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/ai.dart';
import 'theme.dart';
import 'shell.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});
  @override
  State<AiPage> createState() => _AiState();
}

class _AiState extends State<AiPage> {
  final h = <Map<String, String>>[]; final c = TextEditingController(); bool busy = false; final sc = ScrollController();
  static const sug = ['مين متأخر في الإيجار؟', 'إيه الدفعات اللي عليا الشهر ده؟', 'أكتر استديو بيكسب؟', 'لخّصلي وضعي المالي'];
  Future<void> _send([String? q0]) async {
    final q = (q0 ?? c.text).trim(); if (q.isEmpty || busy) return;
    setState(() { h.add({'r': 'u', 't': q}); busy = true; c.clear(); });
    final a = await Ai.ask(q, h.sublist(0, h.length - 1), Ws.I.resolve());
    if (!mounted) return;
    setState(() { h.add({'r': 'a', 't': a}); busy = false; });
    await Future.delayed(const Duration(milliseconds: 50)); if (sc.hasClients) sc.jumpTo(sc.position.maxScrollExtent);
  }
  @override
  Widget build(BuildContext context) => Directionality(textDirection: L.dir, child: Scaffold(
        appBar: AppBar(title: Text(L.t('🤖 اسأل بنيان'))),
        body: Column(children: [
          if (!Ai.on) Card(color: Color(0xFFFFF7E6), child: Padding(padding: EdgeInsets.all(12), child: Text(L.t('مفتاح Gemini المجاني مش متنقل لسه. افتح بنيان القديم مرة وهيتنقل لوحده مع الربط.')))),
          Expanded(child: ListView(controller: sc, padding: const EdgeInsets.all(12), children: [
            if (h.isEmpty) Wrap(spacing: 6, runSpacing: 6, children: [for (final s in sug) ActionChip(label: Text(s), onPressed: () => _send(s))]),
            for (final m in h) Align(alignment: m['r'] == 'u' ? Alignment.centerRight : Alignment.centerLeft, child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12), constraints: const BoxConstraints(maxWidth: 520),
              decoration: BoxDecoration(color: m['r'] == 'u' ? kGreen : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kSand)),
              child: SelectableText(m['t']!.replaceAll('**', ''), style: TextStyle(color: m['r'] == 'u' ? Colors.white : kInk, height: 1.5)))),
            if (busy) Padding(padding: EdgeInsets.all(12), child: Text(L.t('⏳ بيفكر…'), style: TextStyle(color: kMuted))),
          ])),
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
            Expanded(child: TextField(controller: c, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: InputDecoration(hintText: L.t('اسأل عن أي حاجة في أرقامك…'), border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 6),
            IconButton.filled(onPressed: busy ? null : _send, icon: const Icon(Icons.send)),
          ]))),
        ]),
      ));
}
