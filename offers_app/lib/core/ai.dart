/// Gemini المجاني: يقرا صورة الأبديت (أرقام الشقق وأسعارها) أو رقم الشقة من أول صورة في الفيديو
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'model.dart';
import 'store.dart';

class Ai {
  static const models = ['gemini-2.5-flash', 'gemini-flash-latest', 'gemini-2.0-flash', 'gemini-2.5-flash-lite'];

  static Future<String> _ask(String prompt, List<Uint8List> imgs, {String mime = 'image/jpeg', bool json = true}) async {
    final k = Store.I.gemKey;
    if (k.isEmpty) throw 'مفتاح Gemini مش موجود — افتح بنيان مرة وهيتنقل لوحده';
    final body = jsonEncode({
      'contents': [{'role': 'user', 'parts': [{'text': prompt}, for (final b in imgs) {'inline_data': {'mime_type': mime, 'data': base64.encode(b)}}]}],
      'generationConfig': {'temperature': 0, if (json) 'responseMimeType': 'application/json'},
    });
    var err = '';
    for (final m in models) {
      try {
        final r = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$k'), headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 90));
        if (r.statusCode == 200) {
          final o = jsonDecode(utf8.decode(r.bodyBytes));
          final t = ((o['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List? ?? []).map((p) => str(p['text'])).join();
          if (t.trim().isNotEmpty) return t;
        }
        err = 'HTTP ${r.statusCode}';
        if (r.statusCode == 400 || r.statusCode == 403) break;
      } catch (e) { err = '$e'; }
    }
    throw 'Gemini مش رادد ($err)';
  }

  /// صورة الأبديت → [{no, floor, type, p3, mo, booked, note}]
  static Future<List<Obj>> readUpdate(Uint8List img, {String mime = 'image/jpeg'}) async {
    const p = '''دي صورة "أبديت" من شركة عقارات في الإمارات فيها شقق فيلا وأسعارها.
طلّع كل الشقق في JSON array بالشكل ده بالظبط:
[{"no":"رقم الشقة/الاستديو","floor":"G أو 1 أو 2 أو 3 أو R أو فاضي","type":"st|1bk|1bk2b|2bk|2bk2b|3bk|x","tx":"اسم النوع لو x","p3":رقم سعر السنة على دفعات أو 0,"mo":رقم الإيجار الشهري أو 0,"booked":true لو مكتوب BOOKED/محجوز/مشطوب,"note":"أي ملاحظة قصيرة"}]
- STUDIO = st • 1BHK / 1 B/R hall = 1bk • 1BHK + 2 bath = 1bk2b • 2BHK = 2bk • 2BHK 2 bath = 2bk2b • 3BHK = 3bk
- لو فيه أكتر من سعر للدفعات (1 / 2 / 3 / 4 cheques) خد سعر الـ 3 دفعات، ولو مش موجود خد أقرب سعر سنوي.
- الأرقام من غير فواصل. ومتخترعش شقق مش في الصورة.
وكمان لو اسم الفيلا أو رقمها أو الشركة مكتوب، رجّعهم في أول عنصر كـ "villa":"...","company":"..."''';
    final t = await _ask(p, [img], mime: mime);
    final j = jsonDecode(t.substring(t.indexOf('['), t.lastIndexOf(']') + 1)) as List;
    return j.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
  }

  /// أول صورة من الفيديو → رقم الشقة (لو باين رقم الباب)
  static Future<String> readUnitNo(Uint8List thumb) async {
    final t = await _ask('دي أول صورة من فيديو لشقة. لو فيه رقم شقة/باب باين اكتبه بس (رقم أو حروف قصيرة). لو مفيش رقم واضح اكتب كلمة none.', [thumb], json: false);
    final s = t.trim().split('\n').first.trim();
    return s.toLowerCase().contains('none') ? '' : s.replaceAll(RegExp(r'[^\w؀-ۿ-]'), '');
  }
}
