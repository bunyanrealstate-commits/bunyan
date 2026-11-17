import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/model.dart';
import '../core/store.dart';
import '../core/ai.dart';
import '../core/auto.dart';
import 'theme.dart';

String _n(dynamic s) => str(s).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9؀-ۿ]'), '').replaceAll(RegExp(r'^0+'), '');

/// 📷 صورة الأبديت → Gemini يقرا الشقق والأسعار → تراجع وتوافق
class ImportPage extends StatefulWidget {
  final String id;
  const ImportPage(this.id, {super.key});
  @override
  State<ImportPage> createState() => _ImportState();
}

class _ImportState extends State<ImportPage> {
  Uint8List? img; bool busy = false; String err = ''; List<Obj> rows = []; bool missingBooked = true; String vname = '', vcomp = '', vterms = '';

  Obj get v => Store.I.villa(widget.id)!;
  Obj? match(Obj r) => objs(v['units']).where((u) => _n(u['no']).isNotEmpty && _n(u['no']) == _n(r['no'])).firstOrNull;

  Future<void> _pick(ImageSource s) async {
    final f = await ImagePicker().pickImage(source: s, maxWidth: 2200, imageQuality: 88);
    if (f == null) return;
    final b = await f.readAsBytes();
    setState(() { img = b; busy = true; err = ''; rows = []; });
    try {
      final r = await Ai.readUpdate(b);
      final first = r.isNotEmpty ? r.first : <String, dynamic>{};
      vname = str(first['villa']); vcomp = str(first['company']); vterms = str(first['terms']);
      rows = r.where((x) => str(x['no']).isNotEmpty || numOf(x['p1']) > 0 || numOf(x['p3']) > 0 || numOf(x['mo']) > 0).map((x) => {...x, '_on': true}).toList();
      if (rows.isEmpty) err = 'مالقيتش شقق في الصورة دي — جرب صورة أوضح';
    } catch (e) { err = '$e'; }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final seen = rows.where((r) => r['_on'] == true).map((r) => _n(r['no'])).toSet();
    final missing = objs(v['units']).where((u) => u['avail'] != false && !seen.contains(_n(u['no']))).toList();
    return Scaffold(
      appBar: AppBar(title: Text('📷 أبديت ${str(v['name'])} ${str(v['no'])}')),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 100), children: [
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: busy ? null : () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('من الصور'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: busy ? null : () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('صوّر'))),
        ]),
        if (img != null) Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(img!, height: 180, fit: BoxFit.contain))),
        if (busy) const Padding(padding: EdgeInsets.all(24), child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text('🤖 بيقرا الشقق والأسعار…')])),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.all(12), child: Text('⚠️ $err', style: const TextStyle(color: kRed, fontWeight: FontWeight.w700))),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('لقيت ${rows.length} شقة${vname.isNotEmpty ? ' • $vname' : ''}${vcomp.isNotEmpty ? ' • $vcomp' : ''} — راجع وعدّل لو فيه غلط:', style: const TextStyle(fontWeight: FontWeight.w800)),
          for (final r in rows) _row(r),
          if (missing.isNotEmpty) CheckboxListTile(value: missingBooked, onChanged: (b) => setState(() => missingBooked = b ?? true), title: Text('${missing.length} شقة مش موجودة في الأبديت (${missing.map((u) => str(u['no']).isEmpty ? typeName(u['type']) : u['no']).join('، ')}) — اعتبرها محجوزة'), controlAffinity: ListTileControlAffinity.leading),
        ],
      ]),
      floatingActionButton: rows.isEmpty ? null : FloatingActionButton.extended(onPressed: () => _apply(missing), icon: const Icon(Icons.check), label: const Text('حدّث الفيلا')),
    );
  }

  Widget _row(Obj r) {
    final m = match(r);
    String tag;
    if (m == null) { tag = '🆕 جديدة'; } else {
      final ch = <String>[];
      if (numOf(m['p1']) != numOf(r['p1']) && numOf(r['p1']) > 0) ch.add('دفعة واحدة ${money(numOf(m['p1']))}→${money(numOf(r['p1']))}');
      if (numOf(m['p3']) != numOf(r['p3']) && numOf(r['p3']) > 0) ch.add('3 دفعات ${money(numOf(m['p3']))}→${money(numOf(r['p3']))}');
      if (numOf(m['mo']) != numOf(r['mo']) && numOf(r['mo']) > 0) ch.add('شهري ${money(numOf(m['mo']))}→${money(numOf(r['mo']))}');
      if ((m['avail'] != false) == (r['booked'] == true)) ch.add(r['booked'] == true ? 'اتحجزت' : 'رجعت متاحة');
      tag = ch.isEmpty ? '✓ زي ما هي' : '✏️ ${ch.join(' • ')}';
    }
    return Card(child: CheckboxListTile(
      value: r['_on'] == true, onChanged: (b) => setState(() => r['_on'] = b),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text('${str(r['no']).isEmpty ? '—' : r['no']} • ${typeName(r['type'])}${floorName(r['floor']).isNotEmpty ? ' • ${floorName(r['floor'])}' : ''}${r['booked'] == true ? ' • ❌ محجوزة' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${Price.text(r)}\n$tag', style: const TextStyle(fontSize: 12.5)),
      secondary: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () async {
        final o = await formDlg(context, 'تعديل ${str(r['no'])}', [FS('no', 'رقم الشقة', v: r['no']), FS('p1', 'سعر دفعة واحدة', v: numOf(r['p1']) > 0 ? numOf(r['p1']).round() : '', num: true), FS('p3', 'سعر 3 دفعات', v: numOf(r['p3']) > 0 ? numOf(r['p3']).round() : '', num: true), FS('mo', 'الشهري', v: numOf(r['mo']) > 0 ? numOf(r['mo']).round() : '', num: true)]);
        if (o != null) setState(() { r['no'] = o['no']; r['p1'] = numOf(o['p1']); r['p3'] = numOf(o['p3']); r['mo'] = numOf(o['mo']); });
      }),
    ));
  }

  Future<void> _apply(List<Obj> missing) async {
    final r = applyUpdate(v, rows.where((r) => r['_on'] == true).map((r) => Map<String, dynamic>.from(r)..remove('_on')).toList(), missingBooked: missingBooked);
    if (str(v['company']).isEmpty && vcomp.isNotEmpty) v['company'] = vcomp;
    if (vterms.isNotEmpty) v['terms'] = vterms;
    await Store.I.save();
    if (!mounted) return;
    toast(context, '✅ $r');
    Navigator.pop(context);
  }
}
