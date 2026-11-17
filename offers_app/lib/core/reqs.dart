/// طلبات العملاء: نفهم الطلب من رسالة العميل، نلاقيله الشقق، ونفتكره لو نزلت شقة تناسبه
/// التطبيق مبيبعتش لأي حد لوحده — كل حاجة بتستنى إنك تدوس.
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'model.dart';
import 'native.dart';
import 'store.dart';

String _digits(String s) => s.replaceAllMapped(RegExp('[٠-٩]'), (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}').replaceAllMapped(RegExp('[۰-۹]'), (m) => '${'۰۱۲۳۴۵۶۷۸۹'.indexOf(m[0]!)}');

/// «عايز غرفة وصالة شهري 3500 في الشامخة» → {types, pay, budget, area, lang}
Obj parseRequest(String text, {List<String> areas = const []}) {
  final t = _digits(text).toLowerCase();
  final types = <String>{};
  final two = RegExp(r'2\s*bath|two bath|حمامين|2 حمام').hasMatch(t);
  if (RegExp(r'studio|ستو?ديو|استو?ديو|ستيديو').hasMatch(t)) types.add('st');
  if (RegExp(r'\b1\s*bhk|\b1\s*b/?r|one bed|\b1\s*bed|room\s*(and|&)\s*hall|غرف[ةه]\s*و\s*صال[ةه]|[اأ]وض[ةه]\s*و\s*صال[ةه]|غرف[ةه] صال[ةه]|1 غرف').hasMatch(t)) { types.add('1bk'); types.add('1bk2b'); }
  if (RegExp(r'\b2\s*bhk|\b2\s*b/?r|two bed|\b2\s*bed|غرفتين|[اأ]وضتين|2 غرف').hasMatch(t)) { types.add('2bk'); types.add('2bk2b'); }
  if (RegExp(r'\b3\s*bhk|\b3\s*b/?r|three bed|\b3\s*bed|3 غرف|ثلاث غرف|تلات [اأ]وض|تلت [اأ]وض').hasMatch(t)) types.add('3bk');
  // «يفضل 2 حمام» = الأفضل بحمامين بس العادي ينفع برضه
  final pref = RegExp(r'يفضل|يُفضل|prefer|preferably|if possible|لو ينفع').hasMatch(t);
  if (two && !pref) { if (types.contains('1bk')) types.remove('1bk'); if (types.contains('2bk')) types.remove('2bk'); }
  var pay = 'any';
  if (RegExp(r'month|monthly|شهري|شهريا|بالشهر|في الشهر|الشهر').hasMatch(t)) pay = 'mo';
  if (RegExp(r'2\s*(cheque|chq|payment)|two (cheque|payment)|دفعتين').hasMatch(t)) pay = '2';
  if (RegExp(r'3\s*(cheque|chq|payment|دفع)|ثلاث دفعات|تلات دفعات').hasMatch(t)) pay = '3';
  if (RegExp(r'1\s*(cheque|chq|payment)|one (cheque|payment)|دفع[ةه] واحد[ةه]|كاش|cash|سنوي|yearly|annual|per year|بالسنة|في السنة').hasMatch(t)) pay = '1';
  var budget = 0.0;
  for (final m in RegExp(r'(\d[\d,.]*)\s*(k|الف|ألف|آلاف|الاف)?').allMatches(t)) {
    final raw = m.group(1)!.replaceAll(',', '');
    if (raw.replaceAll('.', '').length > 7) continue; // رقم تليفون
    var n = double.tryParse(raw) ?? 0;
    if (m.group(2) != null) n *= 1000;
    final after = t.substring(m.end).trimLeft();
    if (RegExp(r'^(bhk|b/r|bed|bath|غرف|حمام|cheque|chq|payment|دفع|شخص|person|people|اشخاص|أشخاص|سنين|years)').hasMatch(after)) continue;
    if (n >= 500 && n > budget) budget = n;
  }
  var area = '';
  for (final a in areas) { if (a.trim().length >= 3 && t.contains(a.toLowerCase().trim())) { area = a; break; } }
  final latin = RegExp('[a-z]').allMatches(t).length, ar = RegExp('[؀-ۿ]').allMatches(t).length;
  if (pay == 'any' && budget > 20000) pay = '3'; // الميزانية بالسنة = الشركات بتمشي 3 دفعات
  if (pay == 'any' && budget > 0 && budget <= 20000) pay = 'mo';
  // ميعاد السكن: «December» / «أول ديسمبر» / «Dec 10»
  const months = [['january|jan', 'يناير'], ['february|feb', 'فبراير'], ['march', 'مارس'], ['april|apr', 'ابريل|أبريل'], ['may', 'مايو'], ['june', 'يونيو'], ['july', 'يوليو'], ['august|aug', 'اغسطس|أغسطس'], ['september|sept|sep', 'سبتمبر'], ['october|oct', 'اكتوبر|أكتوبر'], ['november|nov', 'نوفمبر'], ['december|dec', 'ديسمبر']];
  var when = '';
  for (var i = 0; i < 12; i++) {
    final m = RegExp('\\b(${months[i][0]})\\b|${months[i][1]}').firstMatch(t);
    if (m == null || (i == 4 && RegExp(r'\bmay (i|we|you)\b').hasMatch(t))) continue;
    final d = int.tryParse(RegExp(r'(\d{1,2})').firstMatch(t.substring(m.end, math.min(t.length, m.end + 6)))?.group(1) ?? '') ?? 1;
    final now = DateTime.now();
    var dt = DateTime(now.year, i + 1, d.clamp(1, 28));
    if (dt.isBefore(now.subtract(const Duration(days: 20)))) dt = DateTime(now.year + 1, i + 1, d.clamp(1, 28));
    when = dt.toIso8601String().substring(0, 10);
    break;
  }
  bool? fur;
  if (RegExp(r'\bfur|furnished|مفروش|مفروشة|مفروشه').hasMatch(t)) fur = true;
  if (RegExp(r'\bempty|unfur|un-fur|فاضي|فاضى|فاضية|غير مفروش|مش مفروش|بدون فرش').hasMatch(t)) fur = false;
  return {'when': when, 'fur': fur, 'types': types.toList(), 'pay': pay, 'budget': budget, 'area': area, 'lang': latin > ar ? 'en' : 'ar', 'isReq': types.isNotEmpty || (budget > 0 && RegExp(r'rent|ايجار|إيجار|سكن|شق[ةه]|flat|apartment|room|غرف').hasMatch(t))};
}

/// اسم جهة الاتصال زي «Studio Fur 3500 Suzanne» → طلب: استديو مفروش لحد 3500، والاسم Suzanne
Obj? parseContactName(String n) {
  // بس الأسامي اللي بتبدأ بالنوع وفيها ميزانية (زي «Studio Fur 3500 Suzanne» / «1bhk 40 Alvin») — دي عملاء أسامه
  if (!RegExp(r'^\s*(studio|stud|ستو?ديو|استو?ديو|[1-4]\s*bhk|[1-4]\s*b/?r|[1-4]\s*bk|room)', caseSensitive: false).hasMatch(n) || !RegExp(r'[0-9٠-٩]{2,}').hasMatch(n)) return null;
  final p = parseRequest(n);
  if ((p['types'] as List).isEmpty) return null;
  // «1bhk 40 Alvin» = 40 ألف في السنة
  if (numOf(p['budget']) == 0) {
    final m = RegExp(r'(?:^|\s)(\d{2,3})(?:\s|$)').firstMatch(_digits(n));
    if (m != null) { p['budget'] = double.parse(m.group(1)!) * 1000; if (p['pay'] == 'any') p['pay'] = '3'; }
  }
  final name = n.split(RegExp(r'\s+')).where((w) {
    final x = _digits(w).toLowerCase();
    return x.isNotEmpty && !RegExp(r'^(studio|stud|st|ستو?ديو|استو?ديو|\d+\s*bhk|bhk|\d+bk|b/r|fur|furn|furnished|empty|unfur|مفروش[ةه]?|فاض[يى]|room|hall|and|&|غرف[ةه]|غرفتين|و?صال[ةه]|[\d.,]+k?|aed|درهم|monthly|yearly|month|شهري|سنوي|يفضل|يُفضل|prefer|حمام|حمامين|bath|baths|bathroom|jan[a-z]*|feb[a-z]*|mar[a-z]*|apr[a-z]*|may|jun[a-z]*|jul[a-z]*|aug[a-z]*|sep[a-z]*|oct[a-z]*|nov[a-z]*|dec[a-z]*|يناير|فبراير|مارس|ابريل|أبريل|مايو|يونيو|يوليو|اغسطس|أغسطس|سبتمبر|اكتوبر|أكتوبر|نوفمبر|ديسمبر|\W+)$').hasMatch(x);
  }).join(' ').trim();
  return {...p, 'name': name};
}

class Reqs {
  static List<Obj> get all => objs(Store.I.D['reqs']);
  static Obj? byId(String id) => all.where((r) => r['id'] == id).firstOrNull;
  static List<String> get areas => {for (final v in Store.I.villas) if (str(v['area']).isNotEmpty) str(v['area'])}.toList();
  static String key(Obj v, Obj u) => '${v['id']}/${u['id']}';

  static List<Map<String, dynamic>> matches(Obj r) => Search.run(Store.I.villas, types: ((r['types'] as List?) ?? []).map(str).toSet(), pay: str(r['pay']).isEmpty ? 'any' : str(r['pay']), budget: numOf(r['budget']), tol: 10, q: str(r['area']), fur: r['fur'] is bool ? r['fur'] as bool : null);

  /// شقق تناسبه ولسه مبعتهاش ولا شافها
  static List<Map<String, dynamic>> fresh(Obj r) {
    final sent = ((r['sent'] as List?) ?? []).map(str).toSet(), seen = ((r['seen'] as List?) ?? []).map(str).toSet();
    return matches(r).where((x) { final k = key(x['v'] as Obj, x['u'] as Obj); return !sent.contains(k) && !seen.contains(k); }).toList();
  }

  static bool open(Obj r) => r['st'] != 'done';
  static bool dueFollow(Obj r) { final f = DateTime.tryParse(str(r['follow'])); return open(r) && r['st'] == 'sent' && f != null && f.isBefore(DateTime.now()); }

  static Obj add({String name = '', String phone = '', String text = '', String lang = ''}) {
    final p = parseRequest(text, areas: areas);
    final r = <String, dynamic>{'id': uid(), 'n': name, 'p': phone, 'txt': text, 'at': DateTime.now().toIso8601String(), 'st': 'new', 'types': p['types'], 'when': p['when'], 'fur': p['fur'], 'pay': p['pay'], 'budget': p['budget'], 'area': p['area'], 'lang': lang.isNotEmpty ? lang : p['lang'], 'sent': <dynamic>[], 'seen': <dynamic>[]};
    ((Store.I.D['reqs'] as List?) ?? (Store.I.D['reqs'] = <dynamic>[])).insert(0, r);
    return r;
  }

  /// رسايل العملاء اللي اتجمعت من الإشعارات → طلبات (رسايل نفس العميل في يومين = نفس الطلب)
  static Future<int> pullDms() async {
    if (kIsWeb || Store.I.testMode || Store.I.cfg['dm'] != true) return 0;
    List items;
    try { items = jsonDecode(await Native.ch.invokeMethod<String>('dmTake') ?? '[]') as List; } catch (_) { return 0; }
    var n = 0;
    for (final m in items.whereType<Map>()) {
      final txt = str(m['txt']), name = str(m['n']), phone = Native.phone(str(m['p']));
      final ex = all.where((r) => open(r) && ((phone.isNotEmpty && r['p'] == phone) || (phone.isEmpty && r['n'] == name)) && DateTime.now().difference(DateTime.tryParse(str(r['at'])) ?? DateTime(2000)).inDays < 2).firstOrNull;
      if (ex != null) {
        ex['txt'] = '${str(ex['txt'])}\n$txt'.trim();
        final p = parseRequest(str(ex['txt']), areas: areas);
        if ((p['types'] as List).isNotEmpty) ex['types'] = p['types'];
        if (p['pay'] != 'any') ex['pay'] = p['pay'];
        if (numOf(p['budget']) > 0) ex['budget'] = p['budget'];
        if (str(p['area']).isNotEmpty) ex['area'] = p['area'];
        continue;
      }
      if (parseRequest(txt)['isReq'] != true) continue;
      add(name: name, phone: phone, text: txt);
      n++;
    }
    if (items.isNotEmpty) await Store.I.save();
    return n;
  }

  /// 📇 العملاء المتسجلين في جهات الاتصال بأسماء فيها طلبهم (زي «Studio Fur 3500 Suzanne»)
  /// الجديد بس بيتضاف — والشقق المناسبة دلوقتي بتتحسب «اتشافت»، علشان تتنبه بس للي ينزل بعد كده
  static Future<int> importContacts(List<Map<String, String>> contacts) async {
    var n = 0;
    final have = all.map((r) => str(r['p'])).where((p) => p.isNotEmpty).toSet();
    for (final c in contacts) {
      final ph = c['p'] ?? '';
      if (ph.isEmpty || have.contains(ph)) continue;
      final q = parseContactName(c['n'] ?? '');
      if (q == null) continue;
      final r = add(name: str(q['name']), phone: ph, text: c['n'] ?? '');
      for (final k in ['types', 'budget', 'pay', 'fur', 'when']) { r[k] = q[k]; }
      r['cn'] = c['n'] ?? '';
      r['st'] = 'wait'; r['src'] = 'contact';
      r['seen'] = [for (final x in matches(r)) key(x['v'] as Obj, x['u'] as Obj)];
      have.add(ph); n++;
    }
    if (n > 0) await Store.I.save();
    return n;
  }

  /// بعد الأبديت: مين من العملاء نزلتله شقة جديدة تناسبه
  static List<Obj> newFor() => all.where((r) => open(r) && r['st'] != 'new' && fresh(r).isNotEmpty).toList();

  static Future<void> markSent(Obj r, List<Map<String, dynamic>> picks) async {
    final s = ((r['sent'] as List?) ?? (r['sent'] = <dynamic>[]));
    for (final x in picks) { final k = key(x['v'] as Obj, x['u'] as Obj); if (!s.contains(k)) s.add(k); }
    r['st'] = 'sent';
    r['sentAt'] = DateTime.now().toIso8601String();
    r['follow'] = DateTime.now().add(const Duration(days: 1)).toIso8601String();
    await Store.I.save();
  }

  static String followText(Obj r) {
    final n = str(r['n']).split(' ').first;
    return r['lang'] == 'en'
        ? 'Hi${n.isEmpty ? '' : ' $n'} 👋 Did you get a chance to check the apartments I sent? If you liked any, I can book a viewing for you.'
        : 'أهلاً${n.isEmpty ? '' : ' $n'} 👋 شفت الشقق اللي بعتهالك؟ لو عجبتك واحدة أحجزلك معاينة.';
  }

  // ===== المعاينات =====
  static List<Obj> get views => objs(Store.I.D['views']);
  static Future<void> addView(Obj r, DateTime at, String what) async {
    final v = {'id': uid(), 'rid': r['id'], 'n': str(r['n']), 'at': at.toIso8601String(), 'what': what};
    ((Store.I.D['views'] as List?) ?? (Store.I.D['views'] = <dynamic>[])).add(v);
    r['st'] = r['st'] == 'done' ? 'done' : 'view';
    await Store.I.save();
    await alarmFor(v);
  }
  static Future<void> alarmFor(Obj v) async {
    if (kIsWeb || Store.I.testMode) return;
    final at = DateTime.tryParse(str(v['at']));
    if (at == null) return;
    final when = at.subtract(const Duration(hours: 1));
    try { await Native.ch.invokeMethod('alarm', {'id': str(v['id']).hashCode & 0x7fffffff, 'at': when.isAfter(DateTime.now()) ? when.millisecondsSinceEpoch : 0, 'title': '📅 معاينة بعد ساعة: ${str(v['n'])}', 'text': str(v['what'])}); } catch (_) {}
  }

  /// بيانات ملخص الصبح لأندرويد (بيتبعت مع كل فتح للتطبيق)
  static Future<void> pushSummary() async {
    if (kIsWeb || Store.I.testMode) return;
    final j = {
      'follow': [
        for (final r in all.where((r) => open(r) && r['st'] == 'sent')) {'n': str(r['n']), 'at': str(r['follow'])},
        // عميل قال هيسكن في ميعاد معين: نفكرك قبلها بـ 3 أيام
        for (final r in all.where((r) => open(r) && DateTime.tryParse(str(r['when'])) != null)) {'n': str(r['n']).isEmpty ? str(r['cn']) : str(r['n']), 'at': DateTime.parse(str(r['when'])).subtract(const Duration(days: 3)).toIso8601String()},
      ],
      'views': [for (final v in views) if ((DateTime.tryParse(str(v['at'])) ?? DateTime(2000)).isAfter(DateTime.now())) {'n': '${str(v['n'])} (${str(v['what'])})', 'at': str(v['at'])}],
      'newReq': all.where((r) => r['st'] == 'new').length,
    };
    try { await Native.ch.invokeMethod('sum', {'json': jsonEncode(j)}); } catch (_) {}
    for (final v in views) { await alarmFor(v); }
  }
}
