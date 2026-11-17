import 'dart:io' show File;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/auto.dart';
import '../core/ai.dart';
import '../core/media.dart';
import '../core/model.dart';
import '../core/store.dart';
import 'theme.dart';
import 'villas.dart';
import 'groups.dart';
import 'suggest.dart';
import '../core/suggest.dart';

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
  bool onlyNew = false, reading = false;
  String prog = '';
  @override
  void initState() { super.initState(); Media.permImg().then((_) { if (mounted) setState(() {}); }); }

  Future<void> _today() async {
    setState(() { reading = true; prog = ''; });
    var on = true;
    () async { while (on && mounted) { await Future.delayed(const Duration(seconds: 2)); final p = await AutoUpd.progress(); if (mounted && on) setState(() => prog = p); } }();
    final r = await AutoUpd.pullToday();
    on = false;
    if (!mounted) return;
    setState(() { reading = false; prog = ''; });
    await showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: Text(r.isEmpty ? '✓ مفيش جديد' : '📥 ${r.length} تغيير'), content: SingleChildScrollView(child: Text(r.isEmpty ? 'قرا أبديتات النهارده ومفيش حاجة اتغيرت عن اللي عندك.' : r.join('\n\n'))), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))])));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (context, _) {
    final all = AutoUpd.log;
    final l = all.where((x) => shotKey(x).isNotEmpty && (!onlyNew || x['same'] != true)).toList();
    final n = DateTime.now();
    bool isToday(Obj x) { final d = DateTime.tryParse(str(x['at'])); return d != null && d.year == n.year && d.month == n.month && d.day == n.day; }
    final td = all.where(isToday).toList();
    int cnt(String w) => td.fold<int>(0, (a, x) { final m = RegExp('$w: ([^•]+)').firstMatch(str(x['m'])); return a + (m == null ? 0 : m.group(1)!.split('،').where((e) => e.trim().isNotEmpty).length); });
    // مجمّعين باليوم
    final days = <String, List<Obj>>{};
    for (final x in l) { days.putIfAbsent(_when(str(x['at'])).split(' ').first, () => []).add(x); }
    return Scaffold(
      appBar: AppBar(title: const Text('📥 الأبديت'), actions: [
        IconButton(tooltip: 'الجروبات', icon: const Icon(Icons.groups_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupsPage()))),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 40), children: [
        Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(children: [
          _stat('${td.where((x) => shotKey(x).isNotEmpty).map(shotKey).toSet().length}', 'أبديت النهارده', kAc2),
          _stat('${cnt('اتحجزت')}', 'اتحجزت', kRed),
          _stat('${cnt('جديدة')}', 'جديدة', kOk),
          _stat('${cnt('السعر')}', 'سعر اتغير', kGold),
        ]))),
        const SizedBox(height: 6),
        FilledButton.icon(onPressed: reading ? null : _today, icon: reading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.download_for_offline_outlined),
          label: Text(reading ? (prog.isEmpty ? 'بيدوّر على أبديتات النهارده…' : (prog == 'pdf' ? 'بيقرا ملفات الـ PDF…' : 'بيقرا $prog…')) : '📥 اقرا كل أبديتات النهارده')),
        if (reading) const Padding(padding: EdgeInsets.only(top: 4), child: Text('ممكن ياخد كام دقيقة (Gemini المجاني بيقرا صورة كل كام ثانية) — سيبه شغال', textAlign: TextAlign.center, style: TextStyle(color: kMuted, fontSize: 12))),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => readPicked(context), icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('صورة من الموبايل'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuggestPage())), icon: const Icon(Icons.lightbulb_outline), label: Text('اقتراحات${Sug.count() > 0 ? ' (${Sug.count()})' : ''}'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('${l.length} أبديت', style: const TextStyle(fontWeight: FontWeight.w800))),
          FilterChip(label: Text('اللي فيه تغيير بس', style: TextStyle(color: onlyNew ? Colors.white : kInk)), selected: onlyNew, showCheckmark: false, onSelected: (b) => setState(() => onlyNew = b)),
        ]),
        if (l.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('لسه مفيش أبديت اتقرا — دوس «اقرا كل أبديتات النهارده»', style: TextStyle(color: kMuted))),
        for (final e in days.entries) ...[
          Padding(padding: const EdgeInsets.fromLTRB(2, 12, 2, 2), child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800, color: kMuted))),
          for (final x in e.value) _tile(x),
        ],
      ]),
    );
  });

  Widget _stat(String n, String l, Color c) => Expanded(child: Column(children: [Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)), Text(l, style: const TextStyle(fontSize: 11.5, color: kMuted))]));

  Widget _tile(Obj x) => Card(child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _Full(x))),
        child: Padding(padding: const EdgeInsets.all(8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _Img(x, w: 96, h: 96),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (x['how'] != null) Text(x['how'] == 'ocr' ? '🔍 اتقرت على الموبايل' : '✨ اتقرت بـ Gemini', style: const TextStyle(fontSize: 11, color: kMuted)),
            if (shotFiles(x).any((f) => f.contains('/shots/'))) const Text('📄 ملف PDF', style: TextStyle(fontSize: 11.5, color: kAc2, fontWeight: FontWeight.w700)),
            Text(str(x['m']), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: x['same'] == true ? kMuted : kInk)),
            const SizedBox(height: 4),
            Text('${str(x['g'])} • ${_when(str(x['at']))}', style: const TextStyle(color: kMuted, fontSize: 12)),
          ])),
        ])),
      ));
}

List<String> shotFiles(Obj x) => ((x['files'] as List?) ?? []).map(str).toList();
String shotKey(Obj x) => str(x['img']).isNotEmpty ? str(x['img']) : (shotFiles(x).firstOrNull ?? '');
Future<Uint8List?> _fileBytes(String p) async { try { final f = File(p); return await f.exists() ? await f.readAsBytes() : null; } catch (_) { return null; } }

class _Img extends StatelessWidget {
  final Obj x; final double w, h;
  const _Img(this.x, {this.w = 96, this.h = 96});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: w, height: h, child: FutureBuilder<Uint8List?>(
        future: str(x['img']).isNotEmpty ? Media.thumb(str(x['img']), s: 260) : _fileBytes(shotKey(x)),
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
        if (shotFiles(x).isNotEmpty) Expanded(child: PageView(children: [for (final f in shotFiles(x)) InteractiveViewer(maxScale: 6, child: Center(child: Image.file(File(f), errorBuilder: (_, __, ___) => const Text('الملف اتمسح', style: TextStyle(color: Colors.white70)))))]))
        else Expanded(child: FutureBuilder<Uint8List?>(
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
  final img = str(x['img']), g = str(x['g']), key = shotKey(x), files = shotFiles(x);
  final bad = AutoUpd.log.where((l) => shotKey(l) == key).map((l) => Store.I.villa(str(l['vid']))).whereType<Obj>().where((v) => v['auto'] == true).toSet().toList();
  final ok = await confirmDlg(context, 'هيقرا الصورة دي تاني بـ Gemini ويحط كل شقة في فيلتها.${bad.isEmpty ? '' : '\n\nوهيمسح الفيلا اللي اتعملت غلط منها: ${bad.map((v) => '${str(v['name'])} ${str(v['no'])}').join('، ')} (${bad.fold<int>(0, (a, v) => a + objs(v['units']).length)} شقة)'}', ok: 'اقرا تاني');
  if (!ok || !context.mounted) return;
  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    final pages = <Uint8List>[];
    if (files.isNotEmpty) { for (final f in files) { final b = await _fileBytes(f); if (b != null) pages.add(b); } } else { final b = await Media.orig(img); if (b != null) pages.add(b); }
    if (pages.isEmpty) throw 'الصورة اتمسحت من الموبايل';
    final rd = await AutoUpd.smartRead(pages);
    final rows = rd.rows;
    if (rows.isEmpty) throw 'Gemini مالقاش شقق في الصورة';
    for (final v in bad) { (Store.I.D['villas'] as List).remove(v); }
    (Store.I.D['log'] as List).removeWhere((l) => shotKey((l as Map).cast<String, dynamic>()) == key);
    final r = AutoUpd.applyRows(g, rows, img: img, files: files, how: rd.how);
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

/// ➕ صورة أبديت من الموبايل (حتى لو جت من جروب مش متابَع) — بيعرف الشركة والفيلا لوحده
Future<void> readPicked(BuildContext context) async {
  final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2200, imageQuality: 90);
  if (f == null || !context.mounted) return;
  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
  try {
    final b = await f.readAsBytes();
    final rd = await AutoUpd.smartRead([b]);
    final rows = rd.rows;
    if (rows.isEmpty) throw 'مالقيتش شقق في الصورة دي';
    var comp = str(rows.first['company']);
    if (comp.isEmpty) {
      // القراية على الموبايل مش بتعرف الشركة من اللوجو — اختارها
      if (!context.mounted) return;
      Navigator.pop(context);
      final opts = {for (final v in Store.I.villas) if (str(v['company']).isNotEmpty) str(v['company']), ...AutoUpd.groups.values}.toList()..sort();
      final c = await pickDlg(context, 'الأبديت ده تبع أنهي شركة؟', [for (final o in opts) [o, o], ['+', '✏️ اكتب اسمها']]);
      if (c == null || !context.mounted) return;
      if (c == '+') { final o = await formDlg(context, 'اسم الشركة', [const FS('c', 'زي: NA Holding')]); if (o == null || (o['c'] ?? '').isEmpty || !context.mounted) return; comp = o['c']!; } else { comp = c; }
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    }
    final dir = await getApplicationDocumentsDirectory();
    final out = File('${dir.path}/shot-${DateTime.now().millisecondsSinceEpoch}.jpg');
    await out.writeAsBytes(b);
    final r = AutoUpd.applyRows(comp, rows, files: [out.path], how: rd.how);
    await Store.I.save();
    if (!context.mounted) return;
    Navigator.pop(context);
    await showDialog(context: context, builder: (ctx) => Directionality(textDirection: TextDirection.rtl, child: AlertDialog(title: Text('📥 $comp'), content: SingleChildScrollView(child: Text(r.isEmpty ? (AutoUpd.log.isNotEmpty ? str(AutoUpd.log.first['m']) : 'مفيش تغيير') : r.join('\n\n'))), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('تمام'))])));
  } catch (e) {
    if (!context.mounted) return;
    Navigator.pop(context);
    toast(context, '⚠️ $e');
  }
}
