import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'i18n.dart';
import '../core/ai.dart';
import '../core/agent.dart';
import '../core/js.dart';
import '../core/native.dart';
import '../core/store.dart';
import 'theme.dart';
import 'dialogs.dart';
import 'shell.dart';

/// 🤖 نموذج بنيان — بيجاوب من أرقامك، يكتب واتساب، ينصح، وينفّذ بعد موافقتك، ويتعلم من تصحيحاتك
class AiPage extends StatefulWidget {
  const AiPage({super.key});
  @override
  State<AiPage> createState() => _AiState();
}

class _Msg { final String r; final String t; final List<AgentAct> acts; final List<Map<String, String>> wa; _Msg(this.r, this.t, [this.acts = const [], this.wa = const []]); }

class _AiState extends State<AiPage> {
  final h = <_Msg>[]; final c = TextEditingController(); bool busy = false; final sc = ScrollController();
  static const sug = ['لخّصلي وضعي المالي', 'مين متأخر في الإيجار؟', 'إيه الدفعات اللي عليا الشهر ده؟', 'أفتح استديو جديد ولا أستنى؟', 'اكتب رسالة لعميل عايز استديو مفروش 3500', 'فكّرني بكرة الساعة 10 أكلم الشركة'];

  Future<void> _send([String? q0]) async {
    final q = (q0 ?? c.text).trim(); if (q.isEmpty || busy) return;
    final hist = [for (final m in h) {'r': m.r, 't': m.t.isEmpty && m.acts.isNotEmpty ? m.acts.map((a) => a.desc).join('\n') : m.t}];
    setState(() { h.add(_Msg('u', q)); busy = true; c.clear(); });
    _down();
    final o = await Agent.run(q, hist, Ws.I.resolve());
    if (!mounted) return;
    setState(() { h.add(_Msg('a', o.text, o.acts, o.wa)); busy = false; });
    _down();
  }
  void _down() async { await Future.delayed(const Duration(milliseconds: 60)); if (sc.hasClients) sc.animateTo(sc.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut); }

  Future<void> _do(AgentAct a) async {
    if (a.run == null) return;
    setState(() => a.state = '…');
    try {
      final r = await a.run!();
      if (r == 'open_contract') { if (mounted) { Navigator.of(context).popUntil((x) => x.isFirst); Shell.go(6); } a.state = 'done'; a.result = 'العقد جاهز'; }
      else { a.state = 'done'; a.result = r; }
    } catch (e) { a.state = 'err'; a.result = '$e'; }
    if (mounted) setState(() {});
  }

  Widget _act(AgentAct a) {
    final done = a.state == 'done', no = a.state == 'no', bad = a.err != null || a.state == 'err';
    final col = bad ? kRed : done ? kOk : no ? kMuted : const Color(0xFF2563EB);
    return Container(
      margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Color.lerp(Colors.white, col, .07), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color.lerp(Colors.white, col, .4)!)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(a.err != null ? '⚠️ ${a.err}' : a.desc, style: TextStyle(fontWeight: FontWeight.w800, height: 1.45, decoration: no ? TextDecoration.lineThrough : null, color: no ? kMuted : kInk)),
        const SizedBox(height: 6),
        if (a.err == null && a.state == 'wait') Row(children: [
          FilledButton.icon(onPressed: () => _do(a), icon: const Icon(Icons.check, size: 18), label: const Text('نفّذ')),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: () => setState(() => a.state = 'no'), child: const Text('لأ')),
        ])
        else if (a.state == '…') const LinearProgressIndicator()
        else if (done) Text('✅ ${a.result ?? 'اتعمل'}', style: const TextStyle(color: kOk, fontWeight: FontWeight.w800))
        else if (no) const Text('اتلغى', style: TextStyle(color: kMuted))
        else if (a.state == 'err') Text('⚠️ ${a.result}', style: const TextStyle(color: kRed)),
      ]),
    );
  }

  Widget _wa(Map<String, String> w) {
    final ph = (w['phone'] ?? '').replaceAll(RegExp(r'[^\d]'), '');
    return Container(
      margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEFFAF2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF9AD8AE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('💬 رسالة واتساب${(w['to'] ?? '').isEmpty ? '' : ' لـ ${w['to']}'}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E7A43))),
        const SizedBox(height: 6),
        SelectableText(w['text'] ?? '', style: const TextStyle(height: 1.55)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)), onPressed: () async {
            final u = 'https://wa.me/${ph.isEmpty ? '' : ph}?text=${Uri.encodeComponent(w['text'] ?? '')}';
            if (!await Native.openUrl(u)) await Share.share(w['text'] ?? '');
          }, icon: const Icon(Icons.send, size: 18), label: Text(ph.isEmpty ? 'افتح واتساب' : 'ابعت على واتساب')),
          OutlinedButton(onPressed: () { Clipboard.setData(ClipboardData(text: w['text'] ?? '')); toast(context, '✅ اتنسخت'); }, child: const Text('انسخ')),
        ]),
      ]),
    );
  }

  Future<void> _memPage() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => Directionality(textDirection: Tr.dir, child: StatefulBuilder(builder: (ctx, ss) {
      final M = objs(Agent.mem);
      return Scaffold(
        appBar: AppBar(title: const Text('🧠 اللي نموذج بنيان اتعلمه')),
        floatingActionButton: FloatingActionButton.extended(onPressed: () async {
          final o = await formDlg(ctx, 'علّمه حاجة جديدة', [FieldSpec('t', 'القاعدة أو المعلومة')]);
          if (o == null || (o['t'] ?? '').trim().isEmpty) return; await Agent.learn(o['t']!); ss(() {});
        }, icon: const Icon(Icons.add), label: const Text('علّمه')),
        body: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
          const Text('كل اللي بتصحّحه أو تقوله «افتكر» بيتحفظ هنا، والنموذج بيمشي عليه في كل رد.', style: TextStyle(color: kMuted)),
          const SizedBox(height: 10),
          if (M.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('لسه ماتعلمش حاجة — صحّحه أو قوله «افتكر إن…»', textAlign: TextAlign.center)),
          for (final x in M) Card(child: ListTile(title: Text(str(x['t'])), subtitle: Text(str(x['at'])), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: kRed), onPressed: () async {
            Agent.mem.removeWhere((y) => y is Map && y['id'] == x['id']); await Store.I.save(log: '🧠 مسحت قاعدة من نموذج بنيان'); ss(() {});
          }))),
        ]),
      );
    }))));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: Tr.dir, child: Scaffold(
        appBar: AppBar(title: const Text('🤖 نموذج بنيان'), actions: [
          IconButton(tooltip: 'اللي اتعلمه', onPressed: _memPage, icon: Badge(isLabelVisible: Agent.mem.isNotEmpty, label: Text('${Agent.mem.length}'), child: const Icon(Icons.psychology_outlined))),
          if (h.isNotEmpty) IconButton(tooltip: 'محادثة جديدة', onPressed: () => setState(h.clear), icon: const Icon(Icons.refresh)),
        ]),
        body: Column(children: [
          if (!Ai.on) const Card(color: Color(0xFFFFF7E6), child: Padding(padding: EdgeInsets.all(12), child: Text('مفتاح Gemini المجاني مش متنقل لسه. افتح بنيان القديم مرة وهيتنقل لوحده مع الربط.'))),
          Expanded(child: ListView(controller: sc, padding: const EdgeInsets.all(12), children: [
            if (h.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFEEF2FF), Color(0xFFF5F3FF)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFD6D3F5))),
                child: const Text('أهلاً يا أسامه 👋\nأنا عارف أرقامك وشغلك. اسألني، أو قولي أعمل حاجة: «فلان دفع الإيجار»، «سجّل مصروف 200 تنضيف»، «فكّرني بكرة»، «اكتب رسالة لعميل»… وأنا أجهّزها وانت توافق.\nولو غلطت صحّحني وأنا هتعلم.', style: TextStyle(height: 1.6)),
              ),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final s in sug) ActionChip(label: Text(s, style: const TextStyle(fontSize: 12.5)), onPressed: () => _send(s))]),
            ],
            for (final m in h) Align(
              alignment: m.r == 'u' ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(11), constraints: const BoxConstraints(maxWidth: 560),
                decoration: BoxDecoration(color: m.r == 'u' ? const Color(0xFF2563EB) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: m.r == 'u' ? const Color(0xFF2563EB) : kBd)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  if (m.t.isNotEmpty) SelectableText(m.t.replaceAll('**', ''), style: TextStyle(color: m.r == 'u' ? Colors.white : kInk, height: 1.55)),
                  for (final a in m.acts) _act(a),
                  for (final w in m.wa) _wa(w),
                ]),
              ),
            ),
            if (busy) const Padding(padding: EdgeInsets.all(12), child: Text('⏳ بيفكر…', style: TextStyle(color: kMuted))),
          ])),
          SafeArea(top: false, child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
            Expanded(child: TextField(controller: c, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) => _send(), decoration: const InputDecoration(hintText: 'اسأل أو قولي أعمل إيه…', border: OutlineInputBorder()))),
            const SizedBox(width: 6),
            IconButton.filled(onPressed: busy ? null : _send, icon: const Icon(Icons.send)),
          ]))),
        ]),
      ));
}
