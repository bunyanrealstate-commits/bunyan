import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'i18n.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import '../core/upd.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';

/// 📢 الأبديت — قايمة الشقق المتاحة + صورة الإعلان + نص الواتساب (نفس ملف القديم upd.json / upd_f.json)
class UpdPage extends StatefulWidget {
  const UpdPage({super.key});
  @override
  State<UpdPage> createState() => _UpdState();
}

class _UpdState extends State<UpdPage> {
  String mode = 'u'; Map<String, dynamic>? d; bool busy = true; String msg = '';
  final key = GlobalKey();
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { setState(() => busy = true); final x = await Upd.pull(mode); if (!mounted) return; setState(() { d = x; busy = false; }); }
  Future<void> _save() async { final ok = await Upd.save(mode, d!); if (mounted) setState(() => msg = ok ? L.t('☁️ اتحفظ واتزامن مع القديم') : L.t('💾 اتحفظ على الموبايل بس — يا مفيش نت، يا فيه نسخة أحدث من القديم (افتح الصفحة تاني)')); }

  @override
  Widget build(BuildContext context) {
    final D = d;
    return Directionality(textDirection: L.dir, child: Scaffold(
      appBar: AppBar(title: Text(L.t('📢 الأبديت')), actions: [IconButton(tooltip: L.t('إعدادات'), icon: const Icon(Icons.tune), onPressed: D == null ? null : _settings)]),
      floatingActionButton: D == null ? null : FloatingActionButton.extended(onPressed: _addVilla, icon: const Icon(Icons.add_home), label: Text(L.t('فيلا'))),
      body: busy || D == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
        SegmentedButton<String>(segments: [ButtonSegment(value: 'u', label: Text(L.t('🏠 الأبديت'))), ButtonSegment(value: 'f', label: Text(L.t('🛋 المفروش')))], selected: {mode}, onSelectionChanged: (s) { mode = s.first; _load(); }),
        if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(msg, style: const TextStyle(color: kMuted, fontSize: 12))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _shareImg, icon: const Icon(Icons.image), label: Text(L.t('ابعت الصورة')))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: () => Share.share(Upd.txt(D)), icon: const Icon(Icons.chat), label: Text(L.t('ابعت كنص')))),
        ]),
        const SizedBox(height: 10),
        for (final v in objs(D['villas'])) _villa(v),
        const SizedBox(height: 12),
        Text(L.t('معاينة الصورة'), style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        FittedBox(child: RepaintBoundary(key: key, child: Poster(D, mode))),
      ]),
    ));
  }

  Widget _villa(Obj v) => Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('🏡 ${str(v['name'])}${truthy(v['area']) ? ' — ${v['area']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editVilla(v)),
          IconButton(icon: const Icon(Icons.add, size: 22), tooltip: L.t('شقة'), onPressed: () => _editUnit(v, null)),
        ]),
        for (final a in objs(v['units'])) ListTile(dense: true, contentPadding: EdgeInsets.zero,
          title: Text('${Upd.lab(Upd.FL, a['floor'], 1)} ${truthy(a['no']) ? '• شقة ${a['no']}' : ''} • ${Upd.typeAr(a)}${truthy(a['furn']) ? ' مفروش' : ''}', style: TextStyle(decoration: truthy(a['booked']) ? TextDecoration.lineThrough : null)),
          subtitle: Text([if (truthy(a['price'])) 'السعر ${Upd.nf(a['price'])}', if (truthy(a['mo'])) 'شهري ${Upd.nf(a['mo'])}', if (truthy(a['note'])) str(a['note'])].join(' • ')),
          trailing: FilterChip(label: Text(truthy(a['booked']) ? 'BOOKED' : L.t('متاح')), selected: truthy(a['booked']), onSelected: (b) { a['booked'] = b; setState(() {}); _save(); }),
          onTap: () => _editUnit(v, a)),
      ])));

  Future<void> _editVilla(Obj? v) async {
    final x = v ?? {};
    final o = await formDlg(context, v == null ? L.t('فيلا جديدة') : L.t('تعديل الفيلا'), [FieldSpec('name', L.t('اسم الفيلا'), v: str(x['name'])), FieldSpec('area', L.t('المنطقة'), v: str(x['area'])), FieldSpec('loc', L.t('لينك اللوكيشن'), v: str(x['loc'])), FieldSpec('note', L.t('ملاحظة'), v: str(x['note']))]);
    if (o == null) return;
    final t = v ?? <String, dynamic>{'id': Upd.uid(), 'units': <dynamic>[]};
    for (final k in ['name', 'area', 'loc', 'note']) { t[k] = o[k] ?? ''; }
    if (v == null) (d!['villas'] as List).add(t);
    setState(() {}); await _save();
  }
  Future<void> _addVilla() => _editVilla(null);

  Future<void> _editUnit(Obj v, Obj? a) async {
    final x = a ?? {'floor': 'G', 'type': 'st', 'furn': mode == 'f'};
    final fl = await pickDlg(context, L.t('الدور'), [for (final f in Upd.FL) [f[0], f[1]]], str(x['floor']).isEmpty ? 'G' : str(x['floor']));
    if (fl == null || !mounted) return;
    final ty = await pickDlg(context, L.t('النوع'), [for (final t in Upd.TY) [t[0], t[1]]], str(x['type']).isEmpty ? 'st' : str(x['type']));
    if (ty == null || !mounted) return;
    final o = await formDlg(context, a == null ? L.t('شقة جديدة') : L.t('تعديل الشقة'), [
      FieldSpec('no', L.t('رقم الشقة'), v: str(x['no'])), if (ty == 'x') FieldSpec('tx', L.t('اكتب النوع'), v: str(x['tx'])),
      FieldSpec('price', L.t('السعر (الدفعات)'), type: 'n', v: str(x['price'])), FieldSpec('mo', L.t('الشهري'), type: 'n', v: str(x['mo'])), FieldSpec('note', L.t('ملاحظة'), v: str(x['note'])),
    ]);
    if (o == null || !mounted) return;
    final furn = await pickDlg(context, L.t('مفروش؟'), [['1', L.t('مفروش')], ['0', L.t('مش مفروش')]], truthy(x['furn']) ? '1' : '0');
    final t = a ?? <String, dynamic>{'id': Upd.uid(), 'at': DateTime.now().millisecondsSinceEpoch, 'booked': false};
    t['floor'] = fl; t['type'] = ty; t['no'] = o['no'] ?? ''; if (ty == 'x') t['tx'] = o['tx'] ?? '';
    final p = double.tryParse(o['price'] ?? '') ?? 0; t['price'] = p == p.roundToDouble() ? p.toInt() : p; t['mo'] = o['mo'] ?? ''; t['note'] = o['note'] ?? ''; t['furn'] = furn == '1';
    if (a == null) ((v['units'] as List?) ?? (v['units'] = <dynamic>[])).add(t);
    setState(() {}); await _save();
  }

  Future<void> _settings() async {
    final D = d!;
    final o = await formDlg(context, L.t('⚙️ إعدادات الأبديت'), [FieldSpec('title', L.t('العنوان'), v: str(D['title'])), FieldSpec('phone', L.t('رقم التواصل'), v: str(D['phone'])), FieldSpec('fee', L.t('رسوم العقد'), type: 'n', v: str(D['fee'])), FieldSpec('dep', L.t('التأمين'), v: str(D['dep'])), FieldSpec('notes', L.t('ملاحظات تحت'), v: str(D['notes']))]);
    if (o == null) return;
    for (final k in ['title', 'phone', 'dep', 'notes']) { D[k] = o[k] ?? ''; }
    final f = double.tryParse(o['fee'] ?? '') ?? 0; D['fee'] = f == f.roundToDouble() ? f.toInt() : f;
    setState(() {}); await _save();
  }

  Future<void> _shareImg() async {
    try {
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 2.5); final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      await Share.shareXFiles([XFile.fromData(bd!.buffer.asUint8List(), mimeType: 'image/png', name: 'update.png')], text: Upd.txt(d!).split('\n').first);
    } catch (e) { if (mounted) toast(context, 'ما قدرتش أطلّع الصورة: $e'); }
  }
}

/// صورة الإعلان
class Poster extends StatelessWidget {
  final Map d; final String mode;
  const Poster(this.d, this.mode, {super.key});
  @override
  Widget build(BuildContext context) {
    final f = mode == 'f'; final bg = f ? const Color(0xFF0F3B2E) : const Color(0xFF14213D); const gold = Color(0xFFE2B857);
    final cs = Upd.cols(d); final now = DateTime.now();
    TextStyle w(double s, {FontWeight fw = FontWeight.w700, Color c = Colors.white}) => TextStyle(fontSize: s, fontWeight: fw, color: c, height: 1.25);
    return Directionality(textDirection: TextDirection.ltr, child: Container(width: 720, padding: const EdgeInsets.all(26), color: bg, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('BUNYAN', textAlign: TextAlign.center, style: w(40, fw: FontWeight.w900, c: gold).copyWith(letterSpacing: 8)),
      Text(f ? 'FURNISHED — AVAILABLE NOW' : 'AVAILABLE NOW', textAlign: TextAlign.center, style: w(16, c: Colors.white70)),
      const SizedBox(height: 6),
      Text(str(d['title']), textAlign: TextAlign.center, style: w(26, fw: FontWeight.w900)),
      Text('${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}', textAlign: TextAlign.center, style: w(13, c: Colors.white60)),
      const SizedBox(height: 14),
      for (final v in objs(d['villas'])) if (objs(v['units']).any((a) => Upd.shown(d, a))) ...[
        Container(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(10)), child: Text('${str(v['name'])}${truthy(v['area']) ? ' — ${v['area']}' : ''}', style: w(18, fw: FontWeight.w900, c: bg))),
        const SizedBox(height: 6),
        Table(columnWidths: const {0: FlexColumnWidth(1.1), 1: FlexColumnWidth(0.8), 2: FlexColumnWidth(2)}, defaultVerticalAlignment: TableCellVerticalAlignment.middle, children: [
          TableRow(children: [for (final h in ['FLOOR', 'FLAT', 'TYPE', ...cs.map((c) => str(c['h']))]) Padding(padding: const EdgeInsets.all(6), child: Text(h, style: w(12, c: gold)))]),
          for (final a in objs(v['units']).where((a) => Upd.shown(d, a))) TableRow(decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white24))), children: [
            Padding(padding: const EdgeInsets.all(6), child: Text(Upd.lab(Upd.FL, a['floor'], 2), style: w(14))),
            Padding(padding: const EdgeInsets.all(6), child: Text(str(a['no']), style: w(14))),
            Padding(padding: const EdgeInsets.all(6), child: Text(Upd.typeEn(a), style: w(14, c: const Color(0xFFFFD6D6)))),
            for (final c in cs) Padding(padding: const EdgeInsets.all(6), child: Text(truthy(a['booked']) ? 'BOOKED' : Upd.nf((c['v'] as Function)(a)), style: w(15, fw: FontWeight.w900, c: truthy(a['booked']) ? const Color(0xFFFF8A8A) : Colors.white))),
          ]),
        ]),
        if (truthy(v['loc'])) Text('📍 ${v['loc']}', style: w(11, c: Colors.white60)),
        const SizedBox(height: 14),
      ],
      Text([if (Upd.nf(d['fee']).isNotEmpty) 'Contract fee: ${Upd.nf(d['fee'])} AED', if (str(d['dep']).isNotEmpty) 'Security deposit: ${str(d['dep'])}'].join('   •   '), textAlign: TextAlign.center, style: w(14)),
      if (truthy(d['notes'])) Text(str(d['notes']), textAlign: TextAlign.center, style: w(13, c: Colors.white70)),
      const SizedBox(height: 8),
      Text('📞 ${Upd.phl(d).map((x) => '${x['n']!.isNotEmpty ? '${x['n']}: ' : ''}${x['p']}').join('  /  ')}', textAlign: TextAlign.center, style: w(20, fw: FontWeight.w900, c: gold)),
    ])));
  }
}
