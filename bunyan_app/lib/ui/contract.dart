import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'i18n.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/contract.dart';
import '../core/js.dart';
import 'ct_css.dart';
import 'theme.dart';
import 'dialogs.dart';
import 'shell.dart';

/// 📝 عقد العميل — بيستخدم نفس نموذج العقد المحفوظ عندك في بنيان (نفس الشكل بالظبط) ويطلّعه PDF
class ContractPage extends StatefulWidget {
  const ContractPage({super.key});
  @override
  State<ContractPage> createState() => _CtState();
}

class _CtState extends State<ContractPage> {
  Obj get S => Store.I.S;
  late Map<String, TextEditingController> c;
  int v = 0;

  @override
  void initState() { super.initState(); _load(); }
  void _load() { final f = Ct.F(S); c = {for (final k in Ct.keys) k: TextEditingController(text: f[k] == null ? '' : '${f[k]}')}; }

  Future<void> _set(String k, String val) async {
    final f = Ct.F(S); f[k] = val;
    if ((k == 'st' || k == 'mo') && str(f['st']).isNotEmpty && str(f['mo']).isNotEmpty) {
      f['en'] = Ct.endOf(str(f['st']), f['mo']); c['en']!.text = str(f['en']);
      if (!truthy(f['chq']) || RegExp(r'^\d+ شيكات شامل').hasMatch(str(f['chq']))) { f['chq'] = '${(double.tryParse(str(f['mo'])) ?? 0).round()} شيكات شامل شيك تأمين بقيمة شهر'; c['chq']!.text = str(f['chq']); }
    }
    if (k == 'rent' && !truthy(f['cx'])) { f['cx'] = f['rent']; c['cx']!.text = str(f['cx']); }
    final ch = Ct.ct(S); if (Ct.hasPaper(S)) ch['html'] = Ct.refresh(S, str(ch['html']));
    await Store.I.save();
    setState(() => v++);
  }

  String _doc() {
    final ch = Ct.ct(S); final ltr = ch['lang'] == 'en';
    return '<!doctype html><html><head><meta charset="utf-8"><style>:root{--ac:#1f7a55;--bd:#d8dee6;--card:#fff;--mu:#5b6b7a}body{margin:0;background:#fff;font-family:Arial,Tahoma,"Noto Naskh Arabic",sans-serif}#ctpaper{width:794px;margin:0 auto}$ctCss</style></head><body dir="${ltr ? 'ltr' : 'rtl'}"><div id="ctwrap"><div id="ctview"><div id="ctpaper">${str(ch['html'])}</div></div></div></body></html>';
  }

  Future<void> _pdf() async {
    if (!Ct.hasPaper(S)) { toast(context, L.t('مفيش نموذج عقد محفوظ — اعمل النموذج مرة واحدة من بنيان القديم')); return; }
    late final List<int> bytes;
    try { bytes = await Printing.convertHtml(format: PdfPageFormat.a4, html: _doc()); } catch (e) { if (mounted) toast(context, L.t('الـ PDF مش متاح هنا — طلّعه من تطبيق الموبايل')); return; }
    final nm = str(Ct.F(S)['tn']).trim().replaceAll(RegExp(r'\s+'), '-');
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: 'contract-${nm.isEmpty ? 'contract' : nm}.pdf');
  }

  Future<void> _fill() async {
    final e = Engine(S, WS: Ws.I.resolve()); final ls = Ct.leases(S, e);
    if (ls.isEmpty) { toast(context, L.t('مفيش عقود مستأجرين')); return; }
    final p = await pickDlg(context, L.t('تعبئة من عقد مستأجر'), [for (var i = 0; i < ls.length; i++) ['$i', '${str((ls[i]['u'] as Obj)['name'])} — ${str((ls[i]['L'] as Obj)['tenant']).isEmpty ? 'مستأجر' : str((ls[i]['L'] as Obj)['tenant'])}']], '0');
    if (p == null) return;
    final x = ls[int.parse(p)]; Ct.fill(S, x['u'] as Obj, x['L'] as Obj);
    await Store.I.save(log: '📝 عقد العميل: ${str((x['L'] as Obj)['tenant'])}');
    setState(() { _load(); v++; });
  }

  @override
  Widget build(BuildContext context) {
    final has = Ct.hasPaper(S);
    return Directionality(textDirection: L.dir, child: Scaffold(
      appBar: AppBar(title: Text(L.t('📝 عقد العميل')), actions: [IconButton(tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf), onPressed: _pdf)]),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (!has) Card(color: Color(0xFFFFF7E6), child: Padding(padding: EdgeInsets.all(12), child: Text(L.t('⚠️ نموذج العقد لسه ما اتعملش. اعمله مرة واحدة من بنيان القديم (تبويب عقد العميل) وبعدها تقدر تملاه هنا وتطلّعه PDF.')))),
        OutlinedButton.icon(onPressed: _fill, icon: const Icon(Icons.person_search), label: Text(L.t('تعبئة من عقد مستأجر قائم'))),
        const SizedBox(height: 8),
        for (final k in Ct.keys) Padding(padding: const EdgeInsets.only(bottom: 8), child: (k == 'st' || k == 'en')
            ? InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(c[k]!.text) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2040)); if (d != null) { c[k]!.text = iso(d); _set(k, iso(d)); } },
                child: InputDecorator(decoration: InputDecoration(labelText: Ct.lb[k], border: const OutlineInputBorder(), isDense: true), child: Text(c[k]!.text.isEmpty ? '—' : c[k]!.text)))
            : TextField(controller: c[k], keyboardType: ['mo', 'due', 'rent', 'cx', 'tot'].contains(k) ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: Ct.lb[k], border: const OutlineInputBorder(), isDense: true), onSubmitted: (x) => _set(k, x), onTapOutside: (_) { if (str(Ct.F(S)[k]) != c[k]!.text) _set(k, c[k]!.text); })),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _pdf, icon: const Icon(Icons.share), label: Text(L.t('📄 طلّع PDF وابعته')), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50))),
        const SizedBox(height: 12),
        if (has) SizedBox(height: 520, child: PdfPreview(key: ValueKey(v), build: (fmt) => Printing.convertHtml(format: PdfPageFormat.a4, html: _doc()), canChangePageFormat: false, canChangeOrientation: false, canDebug: false, allowPrinting: true, allowSharing: true)),
      ]),
    ));
  }
}
