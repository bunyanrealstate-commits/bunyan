/// 🤖 المساعد — Gemini المجاني بنفس المفتاح اللي في بنيان القديم (بييجي مع كود الربط)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'js.dart';
import 'engine.dart';
import 'store.dart';

class Ai {
  static const fall = ['gemini-flash-latest', 'gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-flash-lite-latest', 'gemini-2.5-flash-lite', 'gemini-2.0-flash-lite'];
  /// الموديلات المتاحة فعلاً على المفتاح (جوجل بتغيّر الأسامي وبتلغي القديم) — بنسألها وبنختار الأحدث
  static List<String>? _ml; static DateTime? _mt;
  static Future<List<String>> models({bool lite = false}) async {
    if (_ml == null || _mt == null || DateTime.now().difference(_mt!).inHours > 6) {
      try {
        final r = await http.get(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?pageSize=200&key=${key()}')).timeout(const Duration(seconds: 10));
        if (r.statusCode == 200) {
          final L = <String>[];
          for (final m in ((jsonDecode(r.body) as Map)['models'] as List? ?? [])) {
            final n = str(m['name']).replaceFirst('models/', ''); final g = (m['supportedGenerationMethods'] as List?)?.contains('generateContent') == true;
            if (!g || !n.startsWith('gemini') || !n.contains('flash')) continue;
            if (RegExp('image|tts|audio|live|embedding|thinking|computer|robotics|native').hasMatch(n)) continue;
            L.add(n);
          }
          double ver(String n) => double.tryParse(RegExp(r'gemini-(\d+(\.\d+)?)').firstMatch(n)?.group(1) ?? '') ?? (n.contains('latest') ? 99 : 0);
          int rank(String n) => (n.contains('preview') || n.contains('exp') ? 1 : 0) + (RegExp(r'-\d{3}$|\d{2}-\d{2}').hasMatch(n) ? 1 : 0);
          L.sort((a, b) { final v = ver(b).compareTo(ver(a)); return v != 0 ? v : rank(a).compareTo(rank(b)); });
          if (L.isNotEmpty) { _ml = L; _mt = DateTime.now(); }
        }
      } catch (_) {}
    }
    final all = [...(_ml ?? const []), ...fall.where((m) => !(_ml ?? const []).contains(m))];
    final full = all.where((m) => !m.contains('lite')).toList(), lt = all.where((m) => m.contains('lite')).toList();
    return (lite ? [...lt, ...full] : [...full, ...lt]).take(6).toList();
  }

  static String key() {
    final g = Store.I.cfg['g'];
    if (g is Map) return str(g['key']);
    if (g is String && g.isNotEmpty) { try { final o = jsonDecode(g); if (o is Map) return str(o['key']); } catch (_) {} if (g.startsWith('AIza')) return g; }
    return '';
  }
  static bool get on => key().isNotEmpty;

  static String _r(num v) => v.round().toString();

  /// ملخص أرقام البرنامج اللي المساعد بيجاوب منه (محسوب بنفس محرك الحسابات)
  static String context(String ws) {
    final S = Store.I.S; final e = Engine(S, WS: ws); final b = StringBuffer();
    final f = e.fpos(); final an = e.annW();
    b.writeln('تاريخ النهارده: ${iso(today())}');
    b.writeln('الرصيد النقدي: ${_r(e.cashNow())} • صافي الحقوق: ${_r(f['eq'] ?? 0)} • الربح المتوقع على مدة العقود: ${_r(an['p'] as double)} • الإشغال: ${((an['occ'] as double) * 100).round()}%');
    for (final u in e.SU()) {
      final o = e.occ(u);
      b.writeln('\n🏠 ${str(u['name'])} — شركة: ${str(u['company'])} • من ${str(u['start'])} لمدة ${str(u['cm'])} شهر • إجمالي ${_r(truthy(u['total']) ? n(u['total']) : Engine.isumOf(u))} • أثاث ${_r(n0(u['furn']))} • أيام فاضية ${o['vac']}');
      final un = objs(u['inst']).where((i) => !truthy(i['p'])).take(3).map((i) => '${i['d']}: ${_r(n0(i['a']))}').join('، ');
      if (un.isNotEmpty) b.writeln('  دفعات شركة جاية: $un');
      for (final L in objs(u['leases'])) {
        final late = <String>[]; for (var i = 0; i < Engine.months(L); i++) { if (!Engine.rcv(L).contains(i) && !Engine.payD(L, i).isAfter(today())) late.add(iso(Engine.payD(L, i))); }
        b.writeln('  👤 ${str(L['tenant'])} ${str(L['phone'])} • إيجار ${_r(n0(L['rent']))} • من ${str(L['start'])} لـ ${iso(Engine.lend(L))}${truthy(L['exit']) ? ' • خرج ${L['exit']}' : ''} • استلم ${Engine.rcv(L).length} من ${Engine.months(L)}${late.isNotEmpty ? ' • متأخر: ${late.join('، ')}' : ''}');
      }
    }
    final ex = e.SE().toList()..sort((a, b) => str(b['d']).compareTo(str(a['d'])));
    if (ex.isNotEmpty) b.writeln('\nآخر المصاريف: ${ex.take(12).map((x) => '${x['d']} ${x['w']} ${_r(n0(x['a']))}').join(' | ')}');
    final up = e.items().where((x) => !pd(x['d']).isBefore(today()) && pd(x['d']).isBefore(addM(today(), 1))).take(20).map((x) => '${x['d']} ${x['label']} ${_r(x['amt'] as num)}').join(' | ');
    if (up.isNotEmpty) b.writeln('\nالجاي خلال شهر: $up');
    return b.toString();
  }

  static Future<String> ask(String q, List<Map<String, String>> hist, String ws) async {
    final k = key(); if (k.isEmpty) return '⚠️ مفتاح Gemini مش موجود. افتح بنيان القديم مرة (فيه المفتاح) وهيتنقل لوحده مع الربط.';
    final sys = 'إنت مساعد بنيان Furnished لأسامه (تأجير استديوهات مفروشة في الإمارات، العملة درهم). جاوب بالعامية المصرية باختصار وبوضوح، ومن الأرقام دي بس — متخترعش أرقام. لو المعلومة مش موجودة قول كده.\n\n${context(ws)}';
    final contents = [for (final h in hist.take(10)) {'role': h['r'] == 'u' ? 'user' : 'model', 'parts': [{'text': h['t']}]}, {'role': 'user', 'parts': [{'text': q}]}];
    final body = jsonEncode({'systemInstruction': {'parts': [{'text': sys}]}, 'contents': contents, 'generationConfig': {'temperature': 0.3}});
    String err = '';
    for (final m in await models()) {
      try {
        final r = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$k'), headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 40));
        if (r.statusCode == 200) { final o = jsonDecode(utf8.decode(r.bodyBytes)); final t = (((o['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?) ?? []).map((p) => str(p['text'])).join(); if (t.trim().isNotEmpty) return t.trim(); }
        err = 'HTTP ${r.statusCode}'; if (r.statusCode == 400 || r.statusCode == 403) break;
      } catch (e) { err = '$e'; }
    }
    return '⚠️ المساعد مش رادد دلوقتي ($err). جرب تاني بعد شوية.';
  }
}
