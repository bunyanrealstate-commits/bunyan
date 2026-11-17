/// 🔗 صفحة عروض بلينك واحد: العميل يقلّب الشقق ويدوس «عايز دي» ← توصلك على الواتساب
/// بتترفع على GitHub Pages بتاع بنيان (docs/o/…) بتوكن الربط — ومفيش حاجة بتتبعت للعميل غير لما تدوس إرسال
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'media.dart';
import 'model.dart';
import 'store.dart';

class OfferPage {
  static const repo = 'bunyanrealstate-commits/bunyan';
  static const base = 'https://bunyanrealstate-commits.github.io/bunyan/o/';

  static String _e(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  static String priceLines(Obj u, String pay, bool en) {
    final o = <String>[];
    final p1 = Price.p1(u), p2 = Price.p2(u), p3 = Price.p3(u), mo = Price.mo(u);
    void a1() { if (p1 > 0) o.add(en ? 'AED ${money(p1)} / year — 1 payment' : '${money(p1)} درهم في السنة — دفعة واحدة'); }
    void a2() { if (p2 > 0) o.add(en ? 'AED ${money(p2)} / year — 2 payments' : '${money(p2)} درهم في السنة — دفعتين'); }
    void a3() { if (p3 > 0) o.add(en ? 'AED ${money(p3)} / year — 3 payments' : '${money(p3)} درهم في السنة — 3 دفعات'); }
    void am() { if (mo > 0) o.add(en ? 'AED ${money(mo)} / month' : '${money(mo)} درهم شهري'); }
    if (pay == '1') { a1(); } else if (pay == '2') { a2(); } else if (pay == '3') { a3(); } else if (pay == 'mo') { am(); } else { a1(); am(); if (o.isEmpty) a2(); if (o.isEmpty) a3(); }
    return o.join('<br>');
  }

  /// الصفحة نفسها (HTML لوحدها، الصور جواها)
  static Future<String> html(List<Map<String, dynamic>> picks, {required String pay, required bool en, String client = ''}) async {
    final ph = str(Store.I.cfg['myPhone']);
    final cards = StringBuffer();
    var i = 0;
    for (final x in picks) {
      final v = x['v'] as Obj, u = x['u'] as Obj; i++;
      final vid = ((u['videos'] as List?) ?? []).map(str).firstOrNull;
      final img = vid == null ? null : await Media.thumb(vid, s: 700);
      final type = en ? (kTypesEn[str(u['type'])] ?? 'Apartment') : typeName(u['type']);
      final label = '$type${str(u['no']).isNotEmpty ? (en ? ' — Unit ${u['no']}' : ' — شقة ${u['no']}') : ''}';
      final want = Uri.encodeComponent(en ? 'Hi, I want #$i: $label (${str(v['area'])})' : 'أهلاً، عايز رقم $i: $label (${str(v['area'])})');
      final video = Uri.encodeComponent(en ? 'Hi, please send me the video of #$i: $label' : 'أهلاً، ابعتلي فيديو رقم $i: $label');
      cards.write('''<div class="c">${img == null ? '<div class="ph">🏠</div>' : '<img src="data:image/jpeg;base64,${base64.encode(img)}" alt="">'}
<div class="b"><div class="n">$i</div><h2>${_e(label)}</h2>
${str(v['area']).isNotEmpty ? '<p class="a">📍 ${_e(str(v['area']))}</p>' : ''}
<p class="p">💰 ${priceLines(u, pay, en)}</p>
${str(u['note']).isNotEmpty ? '<p class="a">📝 ${_e(str(u['note']))}</p>' : ''}
${str(v['terms']).isNotEmpty ? '<p class="t">📄 ${_e(str(v['terms']))}</p>' : ''}
<div class="btns">${ph.isEmpty ? '' : '<a class="w" href="https://wa.me/$ph?text=$want">${en ? '✅ I want this' : '✅ عايز دي'}</a><a class="o" href="https://wa.me/$ph?text=$video">${en ? '🎥 Send video' : '🎥 ابعتلي الفيديو'}</a>'}${str(v['loc']).isNotEmpty ? '<a class="o" href="${_e(str(v['loc']))}">${en ? '📍 Location' : '📍 اللوكيشن'}</a>' : ''}</div></div></div>''');
    }
    final title = en ? 'Available apartments${client.isEmpty ? '' : ' for ${_e(client)}'}' : 'الشقق المتاحة${client.isEmpty ? '' : ' لـ ${_e(client)}'}';
    return '''<!doctype html><html lang="${en ? 'en' : 'ar'}" dir="${en ? 'ltr' : 'rtl'}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex"><title>$title</title>
<style>body{margin:0;background:#f1f6f6;font-family:system-ui,-apple-system,"Segoe UI",Tahoma,sans-serif;color:#0f1b2d}header{background:#0e7c86;color:#fff;padding:18px 16px}header h1{margin:0;font-size:20px}header p{margin:4px 0 0;opacity:.85;font-size:13px}main{max-width:640px;margin:auto;padding:12px}.c{background:#fff;border-radius:16px;overflow:hidden;margin:12px 0;box-shadow:0 1px 3px #0001}.c img{width:100%;max-height:340px;object-fit:cover;display:block}.ph{height:140px;display:flex;align-items:center;justify-content:center;font-size:48px;background:#e6ecef}.b{padding:12px 14px;position:relative}.n{position:absolute;top:-18px;inset-inline-end:14px;background:#0e7c86;color:#fff;border-radius:99px;width:34px;height:34px;display:flex;align-items:center;justify-content:center;font-weight:700}h2{margin:4px 0;font-size:17px}.a{margin:4px 0;color:#5e6878;font-size:14px}.p{margin:6px 0;color:#15924a;font-weight:700;font-size:15px}.t{margin:6px 0;font-size:12.5px;color:#5e6878}.btns{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}.btns a{text-decoration:none;padding:10px 14px;border-radius:99px;font-weight:700;font-size:14px}.w{background:#25d366;color:#fff}.o{border:1px solid #d8dee4;color:#0f1b2d}</style></head>
<body><header><h1>🏡 $title</h1><p>${picks.length} ${en ? 'options' : 'اختيارات'}${ph.isEmpty ? '' : ' • WhatsApp +$ph'}</p></header><main>$cards</main></body></html>''';
  }

  /// يرفع الصفحة ويرجع اللينك
  static Future<String> publish(List<Map<String, dynamic>> picks, {required String pay, required bool en, String client = ''}) async {
    if (!Store.I.linked) throw 'التطبيق مش مربوط ببنيان — افتح بنيان مرة';
    final id = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${uid()}';
    final h = await html(picks, pay: pay, en: en, client: client);
    final r = await http.put(Uri.parse('https://api.github.com/repos/$repo/contents/docs/o/$id.html'), headers: Store.I.gh, body: jsonEncode({'message': '🔗 offer page', 'content': base64.encode(utf8.encode(h))})).timeout(const Duration(seconds: 60));
    if (r.statusCode != 201 && r.statusCode != 200) throw 'مقدرتش أرفع الصفحة (${r.statusCode}) — التوكن ممكن ميكونش بيكتب في ريبو الصفحات';
    final l = (Store.I.D['pages'] as List?) ?? (Store.I.D['pages'] = <dynamic>[]);
    l.insert(0, {'id': id, 'at': DateTime.now().toIso8601String(), 'n': client, 'k': picks.length});
    while (l.length > 100) { l.removeLast(); }
    await Store.I.save();
    return '$base$id.html';
  }
}
