import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import '../core/ai.dart';
import '../core/media.dart';
import '../core/model.dart';
import '../core/native.dart';
import '../core/store.dart';
import '../core/suggest.dart';
import 'theme.dart';
import 'thumb.dart';

/// 💡 اقتراحات: فيديوهات تتربط، لوكيشن من الجروبات، بوستات انستجرام — مفيش حاجة بتحصل غير لما تدوس
class SuggestPage extends StatefulWidget {
  final int tab;
  const SuggestPage({super.key, this.tab = 0});
  @override
  State<SuggestPage> createState() => _SugState();
}

class _SugState extends State<SuggestPage> {
  List<Map<String, dynamic>>? vids;
  bool reading = false;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    await Sug.pullLocs();
    final l = await Sug.newVideos();
    if (mounted) setState(() => vids = l);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(length: 3, initialIndex: widget.tab, child: ListenableBuilder(listenable: Store.I, builder: (context, _) {
        final locs = Sug.openLocs(), posts = Sug.posts();
        return Scaffold(
          appBar: AppBar(title: const Text('💡 اقتراحات'), bottom: TabBar(tabs: [
            Tab(text: '🎬 فيديوهات (${vids?.length ?? '…'})'), Tab(text: '📍 لوكيشن (${locs.length})'), Tab(text: '📣 بوستات (${posts.length})'),
          ])),
          body: TabBarView(children: [_videos(), _locs(locs), _posts(posts)]),
        );
      }));

  // ===== 🎬 =====
  Widget _videos() {
    final l = vids;
    if (l == null) return const Center(child: CircularProgressIndicator());
    if (l.isEmpty) return const _Empty('مفيش فيديوهات جديدة مش مربوطة (آخر 30 يوم). أول ما تصوّر شقة هتظهر هنا ومعاها الفيلا اللي اتصورت فيها.');
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final x in l) { groups.putIfAbsent(x['v'] == null ? '' : str((x['v'] as Obj)['id']), () => []).add(x); }
    final keys = groups.keys.toList()..sort((a, b) => a.isEmpty ? 1 : (b.isEmpty ? -1 : 0));
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 60), children: [
      Card(color: const Color(0xFFE3F4F5), child: ListTile(
        leading: reading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Icon(Icons.smart_toy_outlined, color: kAc),
        title: Text(reading ? 'بيقرا أرقام الشقق من أول الفيديو…' : '🤖 اقرا أرقام الشقق من الفيديوهات', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: const Text('لو صوّرت رقم الباب في أول الفيديو، بيعرف الشقة لوحده'),
        onTap: reading ? null : _readNos,
      )),
      for (final k in keys) ...[
        Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 4), child: Row(children: [
          Expanded(child: Text(k.isEmpty ? '❓ مش عارف اتصورت فين (${groups[k]!.length})' : '🏡 ${str(Store.I.villa(k)?['name'])} ${str(Store.I.villa(k)?['no'])} (${groups[k]!.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          if (k.isNotEmpty && groups[k]!.any((x) => x['u'] != null)) FilledButton(onPressed: () => _linkAll(groups[k]!), child: const Text('اربط الكل')),
        ])),
        for (final x in groups[k]!) _vid(x),
      ],
    ]);
  }

  Widget _vid(Map<String, dynamic> x) {
    final a = x['a'] as AssetEntity, v = x['v'] as Obj?, u = x['u'] as Obj?;
    return Card(child: Padding(padding: const EdgeInsets.all(8), child: Row(children: [
      VThumb(a.id, w: 70, h: 70),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a.createDateTime.day}/${a.createDateTime.month} • ${Media.dur(a.duration)}${x['no'] != null && str(x['no']).isNotEmpty ? ' • 🚪 ${x['no']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        if (v != null && (x['d'] as double) < 100000) Text('📍 على بعد ${(x['d'] as double).round()} متر', style: const TextStyle(color: kMuted, fontSize: 12)),
        TextButton(style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: AlignmentDirectional.centerStart), onPressed: () => _pick(x), child: Text(u == null ? '➕ اختار الشقة' : '✓ ${typeName(u['type'])} ${str(u['no'])}${v == null ? '' : ' — ${str(v['name'])} ${str(v['no'])}'}')),
      ])),
      Column(children: [
        if (u != null && v != null) IconButton(tooltip: 'اربط', icon: const Icon(Icons.link, color: kOk), onPressed: () async { await Sug.link(u, a.id); setState(() => vids!.remove(x)); }),
        IconButton(tooltip: 'مش فيديو شقة', icon: const Icon(Icons.close, color: kMuted), onPressed: () async { await Sug.skip(a.id); setState(() => vids!.remove(x)); }),
      ]),
    ])));
  }

  Future<void> _pick(Map<String, dynamic> x) async {
    var v = x['v'] as Obj?;
    if (v == null) {
      final id = await pickDlg(context, 'الفيديو ده في أنهي فيلا؟', [for (final w in Store.I.villas) [str(w['id']), '${str(w['name'])} ${str(w['no'])}']]);
      if (id == null || !mounted) return;
      v = Store.I.villa(id);
    }
    if (v == null) return;
    final us = objs(v['units']);
    final uid0 = await pickDlg(context, 'أنهي شقة؟', [for (final u in us) [str(u['id']), '${typeName(u['type'])} ${str(u['no'])}${floorName(u['floor']).isNotEmpty ? ' • ${floorName(u['floor'])}' : ''}']]);
    if (uid0 == null) return;
    setState(() { x['v'] = v; x['u'] = us.firstWhere((u) => u['id'] == uid0); });
  }

  Future<void> _readNos() async {
    setState(() => reading = true);
    var n = 0;
    for (final x in vids!.where((x) => x['u'] == null && x['v'] != null).take(25)) {
      try {
        final t = await Media.thumb((x['a'] as AssetEntity).id, s: 900);
        if (t == null) continue;
        final no = await Ai.readUnitNo(t);
        x['no'] = no;
        if (no.isEmpty) continue;
        final u = objs((x['v'] as Obj)['units']).where((u) => str(u['no']).toUpperCase().replaceAll(RegExp(r'^0+'), '') == no.toUpperCase().replaceAll(RegExp(r'^0+'), '')).firstOrNull;
        if (u != null) { x['u'] = u; n++; }
        if (mounted) setState(() {});
      } catch (e) { if (mounted) toast(context, '⚠️ $e'); break; }
    }
    if (!mounted) return;
    setState(() => reading = false);
    toast(context, n == 0 ? 'مقدرش يقرا أرقام — اختار الشقق بإيدك' : '🤖 عرف $n — راجعهم ودوس «اربط الكل»');
  }

  Future<void> _linkAll(List<Map<String, dynamic>> l) async {
    final ok = l.where((x) => x['u'] != null).toList();
    if (!await confirmDlg(context, 'تربط ${ok.length} فيديو بالشقق اللي ظاهرة جنبهم؟', ok: 'اربط')) return;
    for (final x in ok) { await Sug.link(x['u'] as Obj, (x['a'] as AssetEntity).id); }
    setState(() => vids!.removeWhere(ok.contains));
    if (mounted) toast(context, '✅ اتربط ${ok.length} فيديو');
  }

  // ===== 📍 =====
  Widget _locs(List<Obj> l) {
    if (l.isEmpty) return const _Empty('أول ما شركة تبعت لينك لوكيشن في جروبها هيظهر هنا وتحطه للفيلا بدوسة.');
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 60), children: [
      for (final s in l) Builder(builder: (context) {
        final v = Sug.villaFor(s);
        return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('📍 من ${str(s['g'])}', style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(str(s['txt']), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kMuted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            if (v != null) FilledButton(onPressed: () async { await Sug.applyLoc(s, v); if (mounted) toast(context, '✅ اتحط لـ ${str(v['name'])} ${str(v['no'])}'); }, child: Text('حطه لـ ${str(v['name'])} ${str(v['no'])}')),
            OutlinedButton(onPressed: () async {
              final id = await pickDlg(context, 'اللوكيشن ده لأنهي فيلا؟', [for (final w in Store.I.villas) [str(w['id']), '${str(w['name'])} ${str(w['no'])}${str(w['loc']).isEmpty ? ' ⚠️' : ''}']]);
              final w = id == null ? null : Store.I.villa(id);
              if (w != null) await Sug.applyLoc(s, w);
            }, child: Text(v == null ? 'اختار الفيلا' : 'فيلا تانية')),
            TextButton(onPressed: () { s['st'] = 'no'; Store.I.save(); }, child: const Text('تجاهل')),
          ]),
        ])));
      }),
    ]);
  }

  // ===== 📣 =====
  Widget _posts(List<Map<String, dynamic>> l) {
    if (l.isEmpty) return const _Empty('لما أبديت ينزّل شقة جديدة ليها فيديو، هيتعملها بوست جاهز هنا. إنت اللي بتنشر.');
    return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 60), children: [
      if (str(Store.I.cfg['myPhone']).isEmpty) Card(color: const Color(0xFFFFF4E0), child: ListTile(title: const Text('ضيف رقم الواتساب بتاعك يظهر في البوستات'), trailing: const Icon(Icons.edit), onTap: () async {
        final o = await formDlg(context, 'رقم الواتساب للبوستات', [const FS('p', 'زي 0523501023', num: true)]);
        if (o == null) return;
        Store.I.cfg['myPhone'] = Native.phone(o['p'] ?? ''); await Store.I.saveCfg(); Store.I.notify();
      })),
      for (final x in l) Builder(builder: (context) {
        final v = x['v'] as Obj, u = x['u'] as Obj;
        final cap = Sug.caption(v, u);
        final vid = ((u['videos'] as List?) ?? []).map(str).first;
        return Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            VThumb(vid, w: 90, h: 120),
            const SizedBox(width: 10),
            Expanded(child: Text(cap, style: const TextStyle(fontSize: 12.5))),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton.icon(onPressed: () async {
              await Clipboard.setData(ClipboardData(text: cap));
              final uri = await Media.uri(vid);
              if (uri == null) { if (context.mounted) toast(context, '⚠️ الفيديو مش موجود على الموبايل'); return; }
              await Native.ch.invokeMethod('shareIg', {'uri': uri, 'text': cap});
              if (context.mounted) toast(context, '📋 الكلام اتنسخ — الصقه في الكابشن وانشر');
              await Sug.markPost(str(x['k']));
            }, icon: const Icon(Icons.campaign_outlined), label: const Text('انشر')),
            OutlinedButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: cap)); if (context.mounted) toast(context, '📋 اتنسخ'); }, child: const Text('انسخ الكلام')),
            TextButton(onPressed: () => Sug.markPost(str(x['k'])), child: const Text('تخطّى')),
          ]),
        ])));
      }),
    ]);
  }
}

class _Empty extends StatelessWidget {
  final String t;
  const _Empty(this.t);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(24), child: Text(t, style: const TextStyle(color: kMuted)));
}
