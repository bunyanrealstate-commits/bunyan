/// 📖 كارت الحديث الأخضر اللي بيطلع تحت (زي #hdth في القديم) + صفحة «📜 طبقات الصوفية»
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/hq.dart';
import 'theme.dart';
import 'i18n.dart';
import 'dialogs.dart';

class HadithOverlay extends StatefulWidget {
  const HadithOverlay({super.key});
  @override
  State<HadithOverlay> createState() => _HOState();
}

class _HOState extends State<HadithOverlay> {
  DateTime _lt = DateTime(2000);
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<HQItem?>(valueListenable: HQ.cur, builder: (ctx, o, __) {
        final on = o != null;
        final bottom = MediaQuery.of(ctx).padding.bottom + 22;
        return Positioned(
          left: 0, right: 0, bottom: bottom,
          child: IgnorePointer(ignoring: !on, child: AnimatedSlide(
            offset: on ? Offset.zero : const Offset(0, .25), duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic,
            child: AnimatedOpacity(opacity: on ? 1 : 0, duration: const Duration(milliseconds: 450), child: Center(child: o == null ? const SizedBox.shrink() : GestureDetector(
              // المس مرتين ورا بعض للإخفاء (زي القديم)
              onTap: () { final n = DateTime.now(); if (n.difference(_lt).inMilliseconds < 450) { HQ.hide(); } else { _lt = n; } },
              child: Container(
                width: MediaQuery.of(ctx).size.width * .86 > 400 ? 400 : MediaQuery.of(ctx).size.width * .86,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F5132), Color(0xFF1A7F4B)]), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 10))]),
                child: Directionality(textDirection: TextDirection.rtl, child: Material(color: Colors.transparent, child: Stack(children: [
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text(o.k, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 11.5, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 3),
                    ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .38), child: SingleChildScrollView(child: Text(o.t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.7)))),
                    if (o.s.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(o.s, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xDDFFFFFF), fontSize: 11))),
                    const Padding(padding: EdgeInsets.only(top: 3), child: Text('المس مرتين ورا بعض للإخفاء', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 9.5))),
                  ]),
                  Positioned(top: -6, left: -8, child: IconButton(tooltip: 'إخفاء', onPressed: HQ.hide, icon: const Icon(Icons.close_rounded, color: Colors.white, size: 19))),
                  Positioned(top: -6, right: -8, child: IconButton(tooltip: 'نسخ', onPressed: () { Clipboard.setData(ClipboardData(text: '${o.t}${o.s.isEmpty ? '' : '\n— ${o.s}'}')); toast(ctx, '📋 اتنسخ'); }, icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 17))),
                ]))),
              ),
            ))),
          )),
        );
      });
}

/* ───────── 📜 طبقات الصوفية (salafjs) ───────── */
class SalafPage extends StatefulWidget {
  const SalafPage({super.key});
  @override
  State<SalafPage> createState() => _SalafState();
}

class _SalafState extends State<SalafPage> {
  String q = '';
  @override
  void initState() { super.initState(); HQ.start(); _wait(); }
  Future<void> _wait() async { for (var i = 0; i < 60 && HQ.salaf == null; i++) { await Future.delayed(const Duration(seconds: 1)); } if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    final D = HQ.salaf;
    return Directionality(textDirection: Tr.dir, child: Scaffold(
      appBar: AppBar(title: Text('📜 ${D == null ? 'طبقات الصوفية' : D['t']}')),
      body: D == null ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('⏳ بيحمّل الكتاب… (محتاج نت أول مرة بس)', textAlign: TextAlign.center))) : Builder(builder: (_) {
        final P = (D['p'] as List).cast<Map>(); final F = P.where((p) => p['f'] == 1 || p['f'] == true).toList();
        final byN = q.isEmpty ? P : P.where((p) => '${p['n']} ${p['a'] ?? ''}'.contains(q)).toList();
        final hits = <List>[]; if (q.isNotEmpty) { for (final p in P) { for (final x in p['q'] as List) { if (hits.length < 60 && (x[0] as String).contains(q)) hits.add([p, x]); } } }
        return ListView(padding: const EdgeInsets.all(14), children: [
          Text('${D['by']}', style: const TextStyle(color: kMuted)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF2F8F5), borderRadius: BorderRadius.circular(14)), child: Text('«${D['h'][0]}»\n— ${D['h'][1]}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.7))),
          const SizedBox(height: 12),
          if (F.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: [for (final p in F) ActionChip(label: Text('${p['n']}'), onPressed: () => _open(p))]),
          const SizedBox(height: 12),
          TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'دوّر على اسم أو كلمة…', isDense: true), onChanged: (v) => setState(() => q = v.trim())),
          const SizedBox(height: 8),
          Text('كل رجال الكتاب (${P.length})', style: const TextStyle(fontWeight: FontWeight.w900)),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final p in byN) OutlinedButton(onPressed: () => _open(p), child: Text('${p['n']}'))]),
          for (final h in hits) Card(child: Padding(padding: const EdgeInsets.all(12), child: Text('${h[1][0]}\n— ${h[0]['n']} • ${D['s'][h[1][2]]}', style: const TextStyle(height: 1.7)))),
        ]);
      }),
    ));
  }

  void _open(Map p) {
    final D = HQ.salaf!; final G = <int, List>{}; for (final x in p['q'] as List) { (G[x[2] as int] ??= []).add(x); }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Directionality(textDirection: Tr.dir, child: Scaffold(
      appBar: AppBar(title: Text('${p['n']} رحمه الله')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        if (p['a'] != null && '${p['a']}'.isNotEmpty) Text('ويُذكر: ${p['a']}', style: const TextStyle(color: kMuted)),
        for (final b in (p['b'] as List? ?? [])) Card(color: const Color(0xFFF2F8F5), child: Padding(padding: const EdgeInsets.all(12), child: Text('${b[0]}\n— ${D['s'][b[1]]}', style: const TextStyle(height: 1.7)))),
        if (p['x'] != null) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('ℹ️ ${p['x']}', style: const TextStyle(color: kMuted))),
        for (final e in G.entries) ...[
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text('📖 من «${D['s'][e.key]}» (${e.value.length})', style: const TextStyle(fontWeight: FontWeight.w900, color: kNavy))),
          for (final x in e.value) Card(child: InkWell(onLongPress: () { Clipboard.setData(ClipboardData(text: '${x[0]}\n— ${p['n']}')); toast(context, '📋 اتنسخ'); }, child: Padding(padding: const EdgeInsets.all(12), child: Text(x[1] == 1 ? '${x[0]}' : '«${x[0]}»', style: const TextStyle(height: 1.8, fontSize: 15))))),
        ],
      ]),
    ))));
  }
}
