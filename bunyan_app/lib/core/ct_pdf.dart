/// عقد العميل → PDF من غير WebView: بيقرا نفس نموذج العقد المحفوظ (S.ct.html) ويرسمه بمكتبة pdf (Dart) بخط بنيان العربي
import 'dart:convert';
import 'dart:typed_data';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as hp;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CtPdf {
  static final _ar = RegExp('[؀-ۿ]');
  static pw.Font? _f, _b;
  /// الخطوط بتتبعت من برّه (rootBundle في التطبيق، ملف في الاختبار)
  static Future<ByteData> Function(String path)? loader;
  static Future<void> _fonts() async {
    _f ??= pw.Font.ttf(await loader!('fonts/PlexArabic-500.ttf'));
    _b ??= pw.Font.ttf(await loader!('fonts/PlexArabic-700.ttf'));
  }
  static String _t(dom.Element e) => e.text.replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  static pw.TextDirection _dir(String s) => _ar.hasMatch(s) && !RegExp(r'[A-Za-z]{3,}').hasMatch(s) ? pw.TextDirection.rtl : (_ar.hasMatch(s) ? pw.TextDirection.rtl : pw.TextDirection.ltr);
  static const ink = PdfColor.fromInt(0xFF1D2733), line = PdfColor.fromInt(0xFF8A8F98), shade = PdfColor.fromInt(0xFFF1F3F6);

  static pw.Widget _txt(String s, {double size = 9.5, bool bold = false, pw.TextAlign? align, PdfColor color = ink}) =>
      pw.Text(s, textDirection: _dir(s), textAlign: align ?? (_dir(s) == pw.TextDirection.rtl ? pw.TextAlign.right : pw.TextAlign.left), style: pw.TextStyle(font: bold ? _b : _f, fontSize: size, color: color));

  static pw.Widget _c(dom.Element? td) {
    final s = td == null ? '' : _t(td); final cls = td?.classes ?? const <String>{};
    final h = cls.contains('en') || cls.contains('ar');
    return pw.Container(
      color: h ? shade : null,
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: _txt(s, bold: h, size: h ? 9 : 10, align: cls.contains('ar') ? pw.TextAlign.right : (cls.contains('en') ? pw.TextAlign.left : pw.TextAlign.center)),
    );
  }
  static pw.Widget _row(List<dom.Element> tds, List<double> w) => pw.Table(
        border: pw.TableBorder.all(color: line, width: .6),
        columnWidths: {for (var j = 0; j < w.length; j++) j: pw.FlexColumnWidth(w[j])},
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
        children: [pw.TableRow(children: [for (final c in tds) _c(c)])]);

  /// جدول البيانات (فيه colspan و rowspan)
  static pw.Widget _infoTable(dom.Element table) {
    final rows = table.querySelectorAll('tr'); final out = <pw.Widget>[]; var i = 0;
    while (i < rows.length) {
      final tds = rows[i].children.where((c) => c.localName == 'td').toList();
      final rs = int.tryParse(tds.isNotEmpty ? (tds.first.attributes['rowspan'] ?? '1') : '1') ?? 1;
      if (rs > 1 && tds.length >= 2) {
        final left = tds.first, right = tds.last; final mids = <List<dom.Element>>[tds.sublist(1, tds.length - 1)];
        for (var k = 1; k < rs && i + k < rows.length; k++) { mids.add(rows[i + k].children.where((c) => c.localName == 'td').toList()); }
        out.add(pw.Table(
          border: pw.TableBorder.all(color: line, width: .6),
          columnWidths: const {0: pw.FlexColumnWidth(2.4), 1: pw.FlexColumnWidth(5.2), 2: pw.FlexColumnWidth(2.4)},
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
          children: [pw.TableRow(children: [
            pw.Container(alignment: pw.Alignment.centerLeft, child: _c(left)),
            pw.Column(children: [for (final m in mids) pw.Table(
              border: const pw.TableBorder(verticalInside: pw.BorderSide(color: line, width: .6), bottom: pw.BorderSide(color: line, width: .3)),
              columnWidths: {for (var j = 0; j < m.length; j++) j: pw.FlexColumnWidth(m.length == 3 ? [1.3, 2.4, 1.5][j] : 1)},
              children: [pw.TableRow(children: [for (final c in m) _c(c)])])]),
            pw.Container(alignment: pw.Alignment.centerRight, child: _c(right)),
          ])],
        ));
        i += rs; continue;
      }
      out.add(tds.length == 3 ? _row(tds, [2.4, 5.2, 2.4]) : _row(tds, [for (final _ in tds) 1.0]));
      i++;
    }
    return pw.Column(children: out);
  }

  /// جدول «لغة واحدة» (العنوان | القيمة) وفيه تاريخ الإيجار بصفين
  static pw.Widget _kvTable(dom.Element table) {
    final rows = table.querySelectorAll('tr'); final out = <pw.Widget>[]; var i = 0;
    while (i < rows.length) {
      final tds = rows[i].children.where((c) => c.localName == 'td').toList();
      final rs = int.tryParse(tds.isNotEmpty ? (tds.first.attributes['rowspan'] ?? '1') : '1') ?? 1;
      final rtl = tds.isNotEmpty && _ar.hasMatch(_t(tds.first));
      List<pw.Widget> o(List<pw.Widget> l) => rtl ? l.reversed.toList() : l;
      if (rs > 1 && tds.length >= 3) {
        final sub = <List<dom.Element>>[tds.sublist(1)]; for (var k = 1; k < rs && i + k < rows.length; k++) { sub.add(rows[i + k].children.where((c) => c.localName == 'td').toList()); }
        out.add(pw.Table(border: pw.TableBorder.all(color: line, width: .6), columnWidths: rtl ? const {0: pw.FlexColumnWidth(7), 1: pw.FlexColumnWidth(3)} : const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(7)}, defaultVerticalAlignment: pw.TableCellVerticalAlignment.full, children: [pw.TableRow(children: o([
          pw.Container(color: shade, alignment: pw.Alignment.center, child: _c(tds.first)),
          pw.Column(children: [for (final m in sub) pw.Table(border: const pw.TableBorder(verticalInside: pw.BorderSide(color: line, width: .6), bottom: pw.BorderSide(color: line, width: .3)), columnWidths: rtl ? const {0: pw.FlexColumnWidth(5), 1: pw.FlexColumnWidth(2)} : const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(5)}, children: [pw.TableRow(children: o([for (final c in m) _c(c)]))])]),
        ]))]));
        i += rs; continue;
      }
      out.add(pw.Table(border: pw.TableBorder.all(color: line, width: .6), columnWidths: rtl ? const {0: pw.FlexColumnWidth(7), 1: pw.FlexColumnWidth(3)} : const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(7)}, children: [pw.TableRow(children: o([pw.Container(color: shade, child: _c(tds.first)), if (tds.length > 1) _c(tds[1])]))]));
      i++;
    }
    return pw.Column(children: out);
  }

  /// جدول الدفعات (أعمدة متساوية، أول صف عناوين)
  static pw.Widget _grid(dom.Element table) {
    final rows = table.querySelectorAll('tr');
    final rtl = rows.isNotEmpty && !RegExp('[A-Za-z]').hasMatch(_t(rows.first)) && _ar.hasMatch(_t(rows.first));
    return pw.Table(border: pw.TableBorder.all(color: line, width: .6), children: [
      for (var r = 0; r < rows.length; r++) pw.TableRow(decoration: r == 0 ? const pw.BoxDecoration(color: shade) : null, children: [
        for (final c in (rtl ? rows[r].children.reversed : rows[r].children).where((c) => c.localName == 'td')) pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4), child: _txt(c.innerHtml.contains('<br') ? c.innerHtml.split(RegExp(r'<br\s*/?>')).map((x) => hp.parseFragment(x).text?.trim() ?? '').join('\n') : _t(c), size: r == 0 ? 8.5 : 9.5, bold: r == 0, align: pw.TextAlign.center)),
      ]),
    ]);
  }

  /// البنود بعمودين (English | عربي) أو عمود واحد
  static pw.Widget _tm(dom.Element tm) {
    final cols = tm.children.where((c) => c.localName == 'div').toList();
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      for (final (j, col) in cols.indexed) ...[if (j > 0) pw.SizedBox(width: 12), pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        for (final (k, li) in col.querySelectorAll('li').indexed) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: _txt('${k + 1}. ${_t(li)}', size: 8.6)),
      ]))],
    ]);
  }

  /// الشروط والأحكام في جدول بحدود (عمود لكل لغة)
  static pw.Widget _terms(dom.Element table) {
    final rows = [for (final tr in table.querySelectorAll('tr')) tr.children.where((c) => c.localName == 'td').toList()];
    final n = rows.isEmpty ? 1 : rows.first.length;
    return pw.Table(border: pw.TableBorder.all(color: line, width: .6), columnWidths: {for (var j = 0; j < n; j++) j: const pw.FlexColumnWidth(1)}, defaultVerticalAlignment: pw.TableCellVerticalAlignment.top, children: [
      for (final tds in rows) pw.TableRow(children: [for (final c in tds) pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4), child: _txt(_t(c), size: 8.8))]),
    ]);
  }

  static pw.Widget _sigs(dom.Element sg) {
    final ds = sg.children.where((c) => c.localName == 'div').toList();
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
      for (final d in ds) pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6), child: pw.Column(children: [
        pw.SizedBox(height: 46, child: () {
          final img = d.querySelector('img'); final src = img?.attributes['src'] ?? '';
          if (src.startsWith('data:image')) { try { return pw.Image(pw.MemoryImage(base64.decode(src.substring(src.indexOf(',') + 1))), fit: pw.BoxFit.contain); } catch (_) {} }
          return pw.SizedBox();
        }()),
        pw.Container(height: .8, color: ink),
        pw.SizedBox(height: 3),
        _txt(d.nodes.whereType<dom.Text>().map((t) => t.text).join(' ').trim(), size: 9, bold: true, align: pw.TextAlign.center),
        if (d.querySelector('small') != null) _txt(_t(d.querySelector('small')!), size: 8.5, align: pw.TextAlign.center),
      ]))),
    ]);
  }

  static Future<Uint8List> build(String html) async {
    await _fonts();
    final doc = hp.parseFragment(html); final root = doc.querySelector('.fr') ?? doc.children.firstOrNull;
    final ws = <pw.Widget>[];
    for (final e in (root?.children ?? <dom.Element>[])) {
      switch (e.localName) {
        case 'h1': {
          final sm = e.querySelector('small'); final main = e.nodes.whereType<dom.Text>().map((t) => t.text).join(' ').trim();
          ws.add(pw.Center(child: _txt(main.isEmpty ? _t(e) : main, size: 20, bold: true, align: pw.TextAlign.center)));
          if (sm != null) ws.add(pw.Center(child: _txt(_t(sm), size: 13, bold: true, align: pw.TextAlign.center)));
          ws.add(pw.SizedBox(height: 4)); break;
        }
        case 'h2': ws.add(pw.SizedBox(height: 10)); ws.add(pw.Center(child: _txt(_t(e), size: 12, bold: true, align: pw.TextAlign.center))); ws.add(pw.SizedBox(height: 4)); break;
        case 'table': ws.add(e.classes.contains('tc2') ? _terms(e) : e.classes.contains('ptb') ? _grid(e) : e.classes.contains('kv') ? _kvTable(e) : _infoTable(e)); break;
        case 'div':
          if (e.classes.contains('sg')) { ws.add(pw.SizedBox(height: 18)); ws.add(_sigs(e)); }
          else if (e.classes.contains('tm')) { ws.add(_tm(e)); }
          else if (e.classes.contains('nl')) { ws.add(pw.SizedBox(height: 6)); ws.add(pw.Container(height: 40, padding: const pw.EdgeInsets.all(4), decoration: pw.BoxDecoration(border: pw.Border.all(color: line, width: .6)), child: _txt(_t(e), size: 9.5, bold: true))); ws.add(pw.SizedBox(height: 6)); }
          else if (e.classes.contains('ctdate')) { ws.add(pw.Align(alignment: _ar.hasMatch(_t(e)) ? pw.Alignment.centerRight : pw.Alignment.centerLeft, child: _txt(_t(e), size: 9))); ws.add(pw.SizedBox(height: 6)); }
          else if (_t(e).isNotEmpty) { ws.add(_txt(_t(e))); }
          break;
        default: if (_t(e).isNotEmpty) ws.add(_txt(_t(e)));
      }
    }
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(26), build: (_) => ws));
    return pdf.save();
  }
}
