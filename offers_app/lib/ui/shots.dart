import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/auto.dart';
import '../core/ai.dart';
import '../core/media.dart';
import '../core/model.dart';
import '../core/store.dart';
import 'theme.dart';
import 'villas.dart';

String _when(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final n = DateTime.now();
  final t = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (d.year == n.year && d.month == n.month && d.day == n.day) return 'النهارده $t';
  final y = n.subtract(const Duration(days: 1));
  if (d.year == y.year && d.month == y.month && d.day == y.day) return 'امبارح $t';
  return '${d.day}/${d.month} $t';
}

/// 📷 صور الأبديت اللي التطبيق لقطها من الجروبات
class ShotsPage extends StatefulWidget {
  const ShotsPage({super.key});
  @override
  State<ShotsPage> createState() => _ShotsState();
}

class _ShotsState extends State<ShotsPage> {
  bool onlyNew = false;
  @override
  void initState() { super.initState(); Media.permImg().then((_) { if (mounted) setState(() {}); }); }

  @override
  Widget build(BuildContext context) {
    final l = AutoUpd.log.where((x) => str(x['img']).isNotEmpty && (!onlyNew || x['same'] != true)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('📷 صور الأبديت')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 40), children: [
        Row(children: [
          Expanded(child: Text('${l.length} صورة اتقرت', style: const TextStyle(fontWeight: FontWeight.w800))),
          FilterChip(label: Text('اللي فيها جديد بس', style: TextStyle(color: onlyNew ? Colors.white : kInk)), selected: onlyNew, showCheckmark: false, onSelected: (b) => setState(() => onlyNew = b)),
        ]),
        if (l.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لسه مفيش صور أبديت اتقرت — أول ما شركة تبعت أبديت في جروب متابَع هتظهر هنا', style: TextStyle(color: kMuted))),
        for (final x in l) _tile(x),
      ]),
    );
  }

  Widget _tile(Obj x) => Card(child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _Full(x))),
        child: Padding(padding: const EdgeInsets.all(8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Img(str(x['img']), w: 96, h: 96),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(str(x['m']), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: x['same'] == true ? kMuted : kInk)),
            const SizedBox(height: 4),
            Text('${str(x['g'])} • ${_when(str(x['at']))}', style: const TextStyle(color: kMuted, fontSize: 12)),
          ])),
        ])),
      ));
}

class _Img extends StatelessWidget {
  final String id; final double w, h;
  const _Img(this.id, {this.w = 96, this.h = 96});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: w, height: h, child: FutureBuilder<Uint8List?>(
        future: Media.thumb(id, s: 260),
        builder: (_, s) => s.data == null ? Container(color: const Color(0xFFE6ECEF), child: Icon(s.connectionState == ConnectionState.done ? Icons.image_not_supported_outlined : Icons.image_outlined, color: kMuted)) : Image.memory(s.data!, fit: BoxFit.cover),
      )));
}

/// الصورة كاملة (تقدر تكبّر بصباعين) وتحتها اللي اتغير
class _Full extends StatelessWidget {
  final Obj x;
  const _Full(this.x);
  @override
  Widget build(BuildContext context) {
    final vid = str(x['vid']);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(str(x['g']), style: const TextStyle(color: Colors.white, fontSize: 16))),
      body: Column(children: [
        Expanded(child: FutureBuilder<Uint8List?>(
          future: Media.big(str(x['img'])),
          builder: (_, s) => s.data == null
              ? Center(child: s.connectionState == ConnectionState.done ? const Text('الصورة اتمسحت من الموبايل', style: TextStyle(color: Colors.white70)) : const CircularProgressIndicator())
              : InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(s.data!))),
        )),
        Container(width: double.infinity, color: Colors.white, padding: const EdgeInsets.all(14), child: SafeArea(top: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(str(x['m']), style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(_when(str(x['at'])), style: const TextStyle(color: kMuted, fontSize: 12)),
          Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 8, runSpacing: 8, children: [
            if (Store.I.villa(vid) != null) FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VillaPage(vid))), icon: const Icon(Icons.villa_outlined), label: const Text('افتح الفيلا')),
            OutlinedButton.icon(onPressed: () => reread(context, x), icon: const Icon(Icons.refresh), label: const Text('اقرا الصورة تاني')),
          ])),
        ]))),
      ]),
    );
  }
}

/// 🔁 يقرا صورة الأبديت تاني ويوزع الشقق على فللها صح — ولو كانت عملت فيلا غلط لوحدها يمسحها (بعد موافقتك)
Future<void> reread(BuildContext context, Obj x) async {
  final img = str(x['img']), g = str(x['g']);
  final bad = AutoUpd.log.where((l) => str(l['img']) == img).map((l) => Store.I.villa(str(l['vid']))).whereType<Obj>().where((v) => v['auto'] == true).toSet().toList();
  final ok = await confirmDlg(context, 'هيقرا الصورة دي تاني بـ Gemini ويحط كل شقة في فيلتها.${bad.isEmpty ? '' : '\n\nوهيمسح الفيلا اللي اتعملت غلط منها: ${bad.map((v) => '${str(v['name'])} ${str(v['no'])}').join('، ')} (${bad.fold<int>(0, (a, v) => a + objs(v['units']).length)} شقة)'}', ok: 'اقرا تاني');
  if (!ok || !context.mounted) return;
  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    final b = await Media.orig(img);
    if (b == null) throw 'الصورة اتمسحت من الموبايل';
    final rows = await Ai.readUpdate(b);
    if (rows.isEmpty) throw 'Gemini مالقاش شقق في الصورة';
    for (final v in bad) { (Store.I.D['villas'] as List).remove(v); }
    (Store.I.D['log'] as List).removeWhere((l) => str((l as Map)['img']) == img);
    final r = AutoUpd.applyRows(g, rows, img: img);
    await Store.I.save();
    if (!context.mounted) return;
    Navigator.pop(context);
    await showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: const Text('✅ اتقرت تاني'), content: SingleChildScrollView(child: Text(r.isEmpty ? 'مفيش تغيير' : r.join('\n\n'))), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))])));
    if (context.mounted) Navigator.pop(context);
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    toast(context, '⚠️ $e');
  }
}
