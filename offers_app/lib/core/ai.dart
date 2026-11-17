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
  static String get autoPrompt => 'لو الصورة دي مش جدول أو أبديت شقق/استديوهات للإيجار (صورة عادية، شخص، مكان، شات…) رجّع [] بس. ولو فيه أكتر من صورة فهي صفحات من نفس ملف الأبديت.\n\n$updatePrompt\n${areaRule(str(Store.I.cfg['areas']).isEmpty ? kAreas : str(Store.I.cfg['areas']))}';
  static const kAreas = 'مدينة الرياض';
  static String areaRule(String areas) => '- وكمان في كل شقة حط "inArea": true لو فيلتها في المناطق دي: $areas ، و false لو مكتوب إنها في منطقة تانية (زي Shakhbot أو MBZ أو Bani Yas أو Khalifa City)، و null لو المنطقة مش مكتوبة خالص. (مدينة الرياض = Madinat Al Riyadh = Riyad City = Riyadh City = Al Riyadh City في أبوظبي. مدينة الشامخة Shamkha City وشخبوط ومدينة محمد بن زايد MBZ مناطق تانية = false — إلا لو مكتوب Riyadh City جنبها)';

  /// كلام رسالة اللوكيشن ↔ أنهي فيلا (أسماء عربي/إنجليزي) — بيرجع الـ id أو فاضي
  static Future<String> matchVilla(String text, List<String> villas) async {
    final t = await _ask('رسالة في جروب شركة عقارات فيها لينك لوكيشن ومكتوب جنبه:\n"$text"\n\nدي فلل الشركة (id: الاسم):\n${villas.join('\n')}\n\nاللوكيشن ده لأنهي فيلا؟ قارن الأسماء حتى لو واحد عربي والتاني إنجليزي (الظاهري = Al Dhaheri، الهاجري = Al Hajeri) ورقم الفيلا. لو مش متأكد رجّع فاضي. رجّع JSON بس: {"id":"..."}', const [], json: true);
    try { return str((jsonDecode(t.substring(t.indexOf('{'), t.lastIndexOf('}') + 1)) as Map)['id']); } catch (_) { return ''; }
  }

  /// صفحات PDF (صور) → صفوف
  static Future<List<Obj>> readUpdatePages(List<Uint8List> imgs, {bool auto = false}) async => parseRows(await _ask(auto ? autoPrompt : updatePrompt, imgs));

  static const updatePrompt = '''دي صورة "أبديت" من شركة عقارات في الإمارات (أبوظبي) فيها شقق في فلل وأسعارها.
طلّع كل الشقق في JSON array بالشكل ده بالظبط:
[{"no":"رقم الشقة (عمود NO أو Unit No أو Flat)","villa":"اسم الفيلا ورقمها زي ما مكتوب (زي Villa Al Naqib 58 أو Al-Buraiki Villa 22)","area":"المدينة/المنطقة زي Riyadh City أو Shamkha City","floor":"G أو 1 أو 2 أو 3 أو R أو فاضي","type":"st|1bk|1bk2b|2bk|2bk2b|3bk|x","tx":"اسم النوع لو x","p1":سعر السنة دفعة واحدة أو 0,"p2":سعر السنة دفعتين أو 0,"p3":سعر السنة 3 دفعات أو 0,"mo":الإيجار الشهري أو 0,"fur":true لو مكتوب Furnished أو مفروشة (غير كده false),"booked":true لو مكتوب BOOKED أو BOOKING أو Rented أو Occupied أو Not Available أو محجوز أو مشطوب أو ملوّن أحمر,"note":"ميزة قصيرة زي Private entrance + Yard أو Extension on the left"}]
- النوع: STUDIO = st • 1BHK / 1 B/R / 1 Bedroom = 1bk • 1BHK + 2 bathrooms = 1bk2b • 2BHK = 2bk • 2BHK + 2 أو 3 bathrooms = 2bk2b • 3BHK = 3bk. (عدد الحمامات ممكن يكون مكتوب في Remarks)
- الأسعار: 1 Payment / One Payment / 1 Cheque / Yearly = p1 • 2 Payments / Two Payment = p2 • 3 Payments / 3 Cheques = p3 • Monthly = mo. لو الأسعار مكتوبة مختصرة زي 58 و 60 و 62 يبقى بالألف (58000). N/A أو - أو فاضي = 0. الأرقام من غير فواصل.
- الدور من عمود Floor/Remarks: Ground = G • First/1st = 1 • Second/2nd = 2 • 3rd = 3 • Roof/Penthouse = R.
- الفيلا: كل شقة حط فيها فيلتها حتى لو الصورة فيها فيلا واحدة. لو مفيش رقم فيلا خالص ومكتوب Zone/حوض بس، اكتب "villa":"Zone 47". ورقم الشارع RD ورقم الحوض مش رقم الفيلا.
- متخترعش شقق مش في الصورة. والصفوف اللي مكتوب فيها BOOKING/Rented رجّعها كمان بـ "booked":true.
- في أول عنصر كمان: "company":"اسم الشركة"، "kind":"price" لو الصورة إعلان سعر جديد/عرض لشقة أو اتنين (زي New price) مش قايمة المتاح كلها، وإلا "list"، و "terms":"الشروط باختصار بالإنجليزي زي: Deposit 1 month • Contract fee 500 AED" (لو مكتوبة).''';

  /// أول صورة من الفيديو → رقم الشقة (لو باين رقم الباب)
  static Future<String> readUnitNo(Uint8List thumb) async {
    final t = await _ask('دي أول صورة من فيديو لشقة. لو فيه رقم شقة/باب باين اكتبه بس (رقم أو حروف قصيرة). لو مفيش رقم واضح اكتب كلمة none.', [thumb], json: false);
    final s = t.trim().split('\n').first.trim();
    return s.toLowerCase().contains('none') ? '' : s.replaceAll(RegExp(r'[^\w؀-ۿ-]'), '');
  }
}
