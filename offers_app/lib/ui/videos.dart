import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../core/model.dart';
import '../core/store.dart';
import '../core/media.dart';
import '../core/ai.dart';
import 'theme.dart';
import 'thumb.dart';

/// 🎬 ربط فيديوهات الألبوم بشقق الفيلا: اختار الشقة فوق ودوس على الفيديو بتاعها
class VideosPage extends StatefulWidget {
  final String id;
  const VideosPage(this.id, {super.key});
  @override
  State<VideosPage> createState() => _VideosState();
}

class _VideosState extends State<VideosPage> {
  List<AssetEntity>? vids; String? cur; bool busy = false; String msg = '';
  Obj get v => Store.I.villa(widget.id)!;
  List<Obj> get units => objs(v['units'])..sort((a, b) => '${a['floor']}${a['no']}'.compareTo('${b['floor']}${b['no']}'));
  Obj? ownerOf(String vid) => units.where((u) => ((u['videos'] as List?) ?? []).map(str).contains(vid)).firstOrNull;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    if (str(v['album']).isEmpty) { setState(() => vids = []); return; }
    final a = await Media.album(str(v['album']));
    final l = a == null ? <AssetEntity>[] : await Media.videos(a);
    if (mounted) setState(() { vids = l; cur ??= units.firstOrNull?['id']; });
  }

  Future<void> _chooseAlbum() async {
    final al = await Media.albums();
    if (!mounted) return;
    if (al.isEmpty) { toast(context, 'مالقيتش ألبومات فيها فيديوهات — اسمح للتطبيق يشوف الفيديوهات'); return; }
    final key = '${v['name']} ${v['no']}'.toLowerCase().split(RegExp(r'\s+')).where((x) => x.length > 1).toList();
    int score(AssetPathEntity a) => key.where((k) => a.name.toLowerCase().contains(k)).length;
    al.sort((a, b) => score(b).compareTo(score(a)));
    final opts = <List<String>>[];
    for (final a in al) { opts.add([a.id, '${a.name} (${await a.assetCountAsync} فيديو)']); }
    if (!mounted) return;
    final id = await pickDlg(context, 'ألبوم الفيلا دي', opts, str(v['album']));
    if (id == null) return;
    v['album'] = id; v['albumName'] = al.firstWhere((a) => a.id == id).name; await Store.I.save();
    _load();
  }

  Future<void> _toggle(String vid) async {
    final o = ownerOf(vid);
    if (o != null) { (o['videos'] as List).remove(vid); }
    if (o == null || o['id'] != cur) {
      final u = units.where((u) => u['id'] == cur).firstOrNull;
      if (u == null) { toast(context, 'اختار الشقة الأول من فوق'); return; }
      ((u['videos'] as List?) ?? (u['videos'] = <dynamic>[])).add(vid);
    }
    await Store.I.save(); setState(() {});
  }

  /// 🤖 يقرا رقم الشقة من أول صورة في كل فيديو مش مربوط
  Future<void> _ai() async {
    final free = (vids ?? []).where((a) => ownerOf(a.id) == null).toList();
    if (free.isEmpty) { toast(context, 'كل الفيديوهات مربوطة'); return; }
    setState(() { busy = true; msg = ''; }); var ok = 0;
    for (final a in free) {
      try {
        final t = await Media.thumb(a.id, s: 800); if (t == null) continue;
        final no = await Ai.readUnitNo(t); if (no.isEmpty) continue;
        final u = units.where((u) => str(u['no']).toUpperCase().replaceAll(RegExp(r'^0+'), '') == no.toUpperCase().replaceAll(RegExp(r'^0+'), '')).firstOrNull;
        if (u != null) { ((u['videos'] as List?) ?? (u['videos'] = <dynamic>[])).add(a.id); ok++; }
        if (mounted) setState(() => msg = '🤖 ربطت $ok لحد دلوقتي…');
      } catch (e) { msg = '$e'; break; }
    }
    await Store.I.save();
    if (mounted) setState(() { busy = false; msg = '🤖 ربطت $ok من ${free.length} فيديو${ok < free.length ? ' — الباقي اربطه بإيدك' : ''}'; });
  }

  @override
  Widget build(BuildContext context) {
    final us = units;
    return Scaffold(
      appBar: AppBar(title: Text('🎬 فيديوهات ${str(v['name'])} ${str(v['no'])}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
        Card(child: ListTile(leading: const Icon(Icons.photo_album_outlined, color: kAc), title: Text(str(v['albumName']).isEmpty ? 'اختار ألبوم الفيلا' : str(v['albumName'])), subtitle: Text(str(v['album']).isEmpty ? 'الألبوم اللي فيه فيديوهات الفيلا دي' : '${vids?.length ?? 0} فيديو'), trailing: const Icon(Icons.chevron_left), onTap: _chooseAlbum)),
        if (us.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('ضيف الشقق الأول (من صورة الأبديت أو بإيدك) وبعدين اربط الفيديوهات', textAlign: TextAlign.center)),
        if (us.isNotEmpty && (vids ?? []).isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('1) اختار الشقة  2) دوس على الفيديو بتاعها (دوسة تانية تشيله)', style: TextStyle(color: kMuted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final u in us) ChoiceChip(
              label: Text('${str(u['no']).isEmpty ? typeName(u['type']) : u['no']} (${((u['videos'] as List?) ?? []).length})', style: TextStyle(color: cur == u['id'] ? Colors.white : kInk)),
              selected: cur == u['id'], showCheckmark: false, onSelected: (_) => setState(() => cur = u['id'])),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: busy ? null : _ai, icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome), label: const Text('🤖 اقرا رقم الشقة من الفيديوهات (لو رقم الباب باين)')),
          if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(msg, style: const TextStyle(color: kMuted))),
          const SizedBox(height: 10),
          GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 8, crossAxisSpacing: 8, children: [
            for (final a in vids!) () {
              final o = ownerOf(a.id); final mine = o != null && o['id'] == cur;
              return GestureDetector(onTap: () => _toggle(a.id), child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: mine ? kAc : (o != null ? kOk : Colors.transparent), width: 3)),
                child: Stack(fit: StackFit.expand, children: [
                  Thumb(a.id, w: double.infinity, h: double.infinity),
                  Positioned(bottom: 4, right: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: Text(Media.dur(a.duration), style: const TextStyle(color: Colors.white, fontSize: 11)))),
                  if (o != null) Positioned(top: 4, left: 4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1), decoration: BoxDecoration(color: mine ? kAc : kOk, borderRadius: BorderRadius.circular(8)), child: Text(str(o['no']).isEmpty ? typeName(o['type']) : str(o['no']), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)))),
                ]),
              ));
            }(),
          ]),
        ],
        if (str(v['album']).isNotEmpty && vids != null && vids!.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('الألبوم ده مفيهوش فيديوهات', textAlign: TextAlign.center)),
      ]),
    );
  }
}
