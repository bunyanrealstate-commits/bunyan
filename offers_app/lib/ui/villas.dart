import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/store.dart';
import 'theme.dart';
import 'thumb.dart';
import 'import.dart';
import 'videos.dart';

/// 🏡 كل الفلل
class VillasPage extends StatefulWidget {
  const VillasPage({super.key});
  @override
  State<VillasPage> createState() => _VillasState();
}

class _VillasState extends State<VillasPage> {
  String q = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (context, _) {
        final vs = Store.I.villas.where((v) => q.isEmpty || '${v['name']} ${v['no']} ${v['company']} ${v['area']}'.toLowerCase().contains(q.toLowerCase())).toList()
          ..sort((a, b) => '${a['name']} ${a['no']}'.compareTo('${b['name']} ${b['no']}'));
        final all = Store.I.villas; final un = all.expand((v) => objs(v['units'])).toList();
        return Scaffold(
          appBar: AppBar(title: Text('🏡 الفلل (${all.length})')),
          body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 90), children: [
            Text('${un.where((u) => u['avail'] != false).length} شقة متاحة • ${un.where((u) => u['avail'] == false).length} محجوزة • ${un.where((u) => ((u['videos'] as List?) ?? []).isEmpty).length} من غير فيديو', style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'دوّر على فيلا / شركة / منطقة'), onChanged: (v) => setState(() => q = v.trim())),
            const SizedBox(height: 8),
            if (all.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('ضيف أول فيلا من الزرار تحت ⬇️\nوبعدها «📷 من صورة الأبديت» تملا الشقق والأسعار لوحدها', textAlign: TextAlign.center, style: TextStyle(color: kMuted, height: 1.7))),
            for (final v in vs) _card(v),
          ]),
          floatingActionButton: FloatingActionButton.extended(onPressed: () async { final v = await editVilla(context, null); if (v != null && context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => VillaPage(str(v['id'])))); }, icon: const Icon(Icons.add_home_outlined), label: const Text('فيلا')),
        );
      });

  Widget _card(Obj v) {
    final us = objs(v['units']); final av = us.where((u) => u['avail'] != false).length;
    final first = us.expand((u) => ((u['videos'] as List?) ?? []).map(str)).firstOrNull;
    return Card(child: InkWell(borderRadius: BorderRadius.circular(16), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VillaPage(str(v['id'])))), child: Padding(padding: const EdgeInsets.all(10), child: Row(children: [
      VThumb(first, w: 64, h: 64), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${str(v['name'])} ${str(v['no'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
        Text([str(v['company']), str(v['area'])].where((x) => x.isNotEmpty).join(' • '), style: const TextStyle(color: kMuted, fontSize: 12.5)),
        Text('$av متاح من ${us.length}${str(v['upd']).isNotEmpty ? ' • أبديت ${v['upd']}' : ''}', style: TextStyle(color: av > 0 ? kOk : kRed, fontWeight: FontWeight.w700, fontSize: 12.5)),
      ])),
      const Icon(Icons.chevron_left, color: kMuted),
    ]))));
  }
}

Future<Obj?> editVilla(BuildContext context, Obj? v) async {
  final o = await formDlg(context, v == null ? '🏡 فيلا جديدة' : 'تعديل الفيلا', [
    FS('name', 'اسم الفيلا (زي ما في الجروب)', v: v?['name']), FS('no', 'رقمها', v: v?['no']), FS('company', 'الشركة', v: v?['company']), FS('area', 'المنطقة', v: v?['area']), FS('loc', 'لينك اللوكيشن (جوجل ماب)', v: v?['loc']), FS('note', 'ملاحظة (كهربا/مياه/شروط…)', v: v?['note'], multi: true),
  ]);
  if (o == null) return null;
  if ((o['name'] ?? '').isEmpty && (o['no'] ?? '').isEmpty) { if (context.mounted) toast(context, 'اكتب اسم الفيلا أو رقمها'); return null; }
  final t = v ?? <String, dynamic>{'id': uid(), 'units': <dynamic>[]};
  for (final k in ['name', 'no', 'company', 'area', 'loc', 'note']) { t[k] = o[k] ?? ''; }
  if (v == null) (Store.I.D['villas'] as List).add(t);
  await Store.I.save();
  return t;
}

/// صفحة فيلا: الشقق + الأبديت + الفيديوهات
class VillaPage extends StatelessWidget {
  final String id;
  const VillaPage(this.id, {super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (context, _) {
        final v = Store.I.villa(id);
        if (v == null) return const Scaffold(body: Center(child: Text('الفيلا اتمسحت')));
        final us = objs(v['units'])..sort((a, b) => '${a['floor']}${a['no']}'.compareTo('${b['floor']}${b['no']}'));
        return Scaffold(
          appBar: AppBar(title: Text('${str(v['name'])} ${str(v['no'])}'), actions: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => editVilla(context, v)),
            IconButton(icon: const Icon(Icons.delete_outline, color: kRed), onPressed: () async { if (await confirmDlg(context, 'تمسح الفيلا دي بكل شققها؟ (الفيديوهات في الألبوم مش هتتمسح)', ok: 'امسح')) { (Store.I.D['villas'] as List).remove(v); await Store.I.save(); if (context.mounted) Navigator.pop(context); } }),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 90), children: [
            Text([str(v['company']), str(v['area']), if (str(v['albumName']).isNotEmpty) '🎬 ${v['albumName']}'].where((x) => x.isNotEmpty).join(' • '), style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700)),
            if (str(v['loc']).isNotEmpty) Text('📍 ${v['loc']}', style: const TextStyle(color: kAc2, fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (str(v['note']).isNotEmpty) Text('📝 ${v['note']}', style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ImportPage(id))), icon: const Icon(Icons.document_scanner_outlined), label: const Text('من صورة الأبديت'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideosPage(id))), icon: const Icon(Icons.video_library_outlined), label: const Text('الفيديوهات'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [Text('الشقق (${us.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const Spacer(), TextButton.icon(onPressed: () => editUnit(context, v, null), icon: const Icon(Icons.add), label: const Text('شقة'))]),
            for (final u in us) Card(child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
              leading: VThumb(((u['videos'] as List?) ?? []).map(str).firstOrNull, w: 54, h: 54),
              title: Text('${typeName(u['type'])}${str(u['no']).isNotEmpty ? ' • ${u['no']}' : ''}${floorName(u['floor']).isNotEmpty ? ' • ${floorName(u['floor'])}' : ''}', style: TextStyle(fontWeight: FontWeight.w800, decoration: u['avail'] == false ? TextDecoration.lineThrough : null)),
              subtitle: Text('${Price.text(u)}${str(u['note']).isNotEmpty ? '\n📝 ${u['note']}' : ''}', style: const TextStyle(fontSize: 12.5)),
              trailing: Switch(value: u['avail'] != false, activeColor: kOk, onChanged: (b) { u['avail'] = b; Store.I.save(); }),
              onTap: () => editUnit(context, v, u),
            )),
          ]),
        );
      });
}

Future<void> editUnit(BuildContext context, Obj v, Obj? u) async {
  final ty = await pickDlg(context, 'النوع', kTypes, str(u?['type']).isEmpty ? '1bk' : str(u?['type']));
  if (ty == null || !context.mounted) return;
  final fl = await pickDlg(context, 'الدور', [...kFloors, ['', 'مش مهم']], str(u?['floor']));
  if (fl == null || !context.mounted) return;
  final o = await formDlg(context, u == null ? 'شقة جديدة' : 'تعديل الشقة', [
    FS('no', 'رقم الشقة', v: u?['no']), if (ty == 'x') FS('tx', 'اكتب النوع', v: u?['tx']),
    FS('p1', 'سعر السنة دفعة واحدة (فاضي = مفيش)', v: u?['p1'], num: true),
    FS('p3', 'سعر السنة على 3 دفعات (فاضي = مفيش)', v: u?['p3'], num: true), FS('mo', 'الشهري (فاضي = مفيش)', v: u?['mo'], num: true), FS('note', 'ملاحظة', v: u?['note']),
  ]);
  if (o == null) return;
  final t = u ?? <String, dynamic>{'id': uid(), 'avail': true, 'videos': <dynamic>[]};
  t['type'] = ty; t['floor'] = fl; t['no'] = o['no'] ?? ''; if (ty == 'x') t['tx'] = o['tx'] ?? '';
  t['p1'] = numOf(o['p1']); t['p3'] = numOf(o['p3']); t['mo'] = numOf(o['mo']); t['note'] = o['note'] ?? '';
  if (u == null) ((v['units'] as List?) ?? (v['units'] = <dynamic>[])).add(t);
  await Store.I.save();
}
