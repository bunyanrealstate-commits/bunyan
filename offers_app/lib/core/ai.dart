/// Gemini المجاني: يقرا صورة الأبديت (أرقام الشقق وأسعارها) أو رقم الشقة من أول صورة في الفيديو
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'model.dart';
import 'store.dart';

class Ai {
  static const _fall = ['gemini-flash-latest', 'gemini-2.5-flash', 'gemini-flash-lite-latest', 'gemini-2.5-flash-lite', 'gemini-2.0-flash'];
  static const _base = 'https://generativelanguage.googleapis.com/v1beta/';
  static List<String>? _models;

  static double _ver(String n) => double.tryParse(RegExp(r'(\d+(?:\.\d+)?)').firstMatch(n)?.group(1) ?? '') ?? 0;

  /// الموديلات المتاحة فعلاً على المفتاح (بدل أسماء ثابتة ممكن جوجل تشيلها → 404)
  static Future<List<String>> _list(String k) async {
    if (_models != null) return _models!;
    try {
      final r = await http.get(Uri.parse('${_base}models?pageSize=200'), headers: {'x-goog-api-key': k}).timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final ms = ((jsonDecode(r.body)['models'] as List?) ?? []).whereType<Map>().where((m) {
          final n = str(m['name']).replaceFirst('models/', '');
          return ((m['supportedGenerationMethods'] as List?) ?? []).contains('generateContent') && n.contains('flash') && !RegExp(r'image|tts|audio|live|embed|exp|8b|thinking|robotics|computer').hasMatch(n);
        }).map((m) => str(m['name']).replaceFirst('models/', '')).toList();
        int rank(String n) => (n.contains('lite') ? 4 : 0) + (n.contains('preview') ? 2 : 0) + (n.contains('latest') ? 0 : 1);
        ms.sort((a, b) { final d = rank(a) - rank(b); return d != 0 ? d : _ver(b).compareTo(_ver(a)); });
        if (ms.isNotEmpty) return _models = [...ms.take(5), ..._fall.where((f) => !ms.contains(f))].take(7).toList();
      }
    } catch (_) {}
    return _fall;
  }

  static Future<String> _ask(String prompt, List<Uint8List> imgs, {String mime = 'image/jpeg', bool json = true}) async {
    final k = Store.I.gemKey;
    if (k.isEmpty) throw 'مفتاح Gemini مش موجود — افتح بنيان مرة وهيتنقل لوحده';
    final body = jsonEncode({
      'contents': [{'role': 'user', 'parts': [{'text': prompt}, for (final b in imgs) {'inline_data': {'mime_type': mime, 'data': base64.encode(b)}}]}],
      'generationConfig': {'temperature': 0, if (json) 'responseMimeType': 'application/json'},
    });
    final errs = <String>[];
    for (final m in await _list(k)) {
      try {
        final r = await http.post(Uri.parse('${_base}models/$m:generateContent'), headers: {'Content-Type': 'application/json', 'x-goog-api-key': k}, body: body).timeout(const Duration(seconds: 90));
        if (r.statusCode == 200) {
          final o = jsonDecode(utf8.decode(r.bodyBytes));
          final t = ((o['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List? ?? []).where((p) => p['thought'] != true).map((p) => str(p['text'])).join();
          if (t.trim().isNotEmpty) return t;
          errs.add('$m: رد فاضي');
          continue;
        }
        var msg = '';
        try { msg = str(jsonDecode(utf8.decode(r.bodyBytes))['error']?['message']); } catch (_) {}
        errs.add('$m: ${r.statusCode}');
        if (r.statusCode == 401 || r.statusCode == 403 || (r.statusCode == 400 && RegExp('API key|API_KEY', caseSensitive: false).hasMatch(msg))) throw 'مفتاح Gemini مش شغال ($msg)';
        if (r.statusCode == 404) _models = null;
      } on String { rethrow; } catch (e) { errs.add('$m: ${e is TimeoutException ? 'اتأخر' : 'مفيش نت'}'); }
    }
    if (errs.every((e) => e.endsWith('429'))) throw 'Gemini مضغوط دلوقتي (الحد المجاني) — استنى دقيقة وجرب تاني';
    throw 'Gemini مش رادد\n${errs.join('\n')}';
  }

  /// صورة الأبديت → [{no, floor, type, p3, mo, booked, note}]
  static Future<List<Obj>> readUpdate(Uint8List img, {String mime = 'image/jpeg'}) async {
    final t = await _ask(updatePrompt, [img], mime: mime);
    return parseRows(t);
  }

  static List<Obj> parseRows(String t) {
    final j = jsonDecode(t.substring(t.indexOf('['), t.lastIndexOf(']') + 1)) as List;
    return j.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// للأبديت التلقائي من الجروبات: أي صورة مش أبديت → []
  static const autoPrompt = 'لو الصورة دي مش جدول أو أبديت شقق/استديوهات للإيجار (صورة عادية، شخص، مكان، شات…) رجّع [] بس.\n\n' + updatePrompt;

  static const updatePrompt = '''دي صورة "أبديت" من شركة عقارات في الإمارات فيها شقق فيلا وأسعارها.
طلّع كل الشقق في JSON array بالشكل ده بالظبط:
[{"no":"رقم الشقة/الاستديو (عمود Flat أو Apt أو Studio No)","floor":"G أو 1 أو 2 أو 3 أو R أو فاضي","type":"st|1bk|1bk2b|2bk|2bk2b|3bk|x","tx":"اسم النوع لو x","p1":سعر السنة دفعة واحدة (1 Payment / 1 Cheque) أو 0,"p3":سعر السنة على 3 دفعات (3 Payments / 3 Cheques) أو 0,"mo":رقم الإيجار الشهري أو 0,"booked":true لو مكتوب BOOKED/محجوز/مشطوب,"note":"أي ملاحظة قصيرة"}]
- STUDIO = st • 1BHK / 1 B/R hall = 1bk • 1BHK + 2 bath = 1bk2b • 2BHK = 2bk • 2BHK 2 bath = 2bk2b • 3BHK = 3bk
- 1 Payment / 1 Cheque = p1. و 3 Payments / 3 Cheques = p3. لو العمود مش واضح عدد دفعاته اعتبره p1. لو فيه 2 أو 4 دفعات بس حطه في p3 واكتب عدد الدفعات في note.
- الدور من عمود Remark/Floor: Ground = G، 1st = 1، 2nd = 2، 3rd = 3، Roof/Penthouse = R. و Balcony وأي ميزة تانية تتكتب في note.
- 2 Bed Room 2/3 Bathroom = 2bk2b • 3 Bed Room = 3bk • 1 Bed Room + 2 Bathroom = 1bk2b.
- اسم الفيلا زي "VILLA 25" ورقم الشارع "RD 66" والمنطقة.
- الأرقام من غير فواصل. ومتخترعش شقق مش في الصورة.
وكمان لو اسم الفيلا أو رقمها أو الشركة مكتوب، رجّعهم في أول عنصر كـ "villa":"...","company":"...","area":"...","terms":"الشروط باختصار بالإنجليزي زي: Security 5% or 2000 • Contract fee 200 AED • Parking" (لو مكتوبة)''';

  /// أول صورة من الفيديو → رقم الشقة (لو باين رقم الباب)
  static Future<String> readUnitNo(Uint8List thumb) async {
    final t = await _ask('دي أول صورة من فيديو لشقة. لو فيه رقم شقة/باب باين اكتبه بس (رقم أو حروف قصيرة). لو مفيش رقم واضح اكتب كلمة none.', [thumb], json: false);
    final s = t.trim().split('\n').first.trim();
    return s.toLowerCase().contains('none') ? '' : s.replaceAll(RegExp(r'[^\w؀-ۿ-]'), '');
  }
}
