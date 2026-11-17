/// البيانات: فلل ← شقق. كل حاجة JSON بسيط علشان تتحفظ وتترفع باك أب بسهولة
import 'dart:math' as math;

typedef Obj = Map<String, dynamic>;

/// أنواع الشقق
const kTypes = [
  ['st', 'استديو'],
  ['1bk', 'غرفة وصالة'],
  ['1bk2b', 'غرفة وصالة وحمامين'],
  ['2bk', 'غرفتين وصالة'],
  ['2bk2b', 'غرفتين وصالة وحمامين'],
  ['3bk', '3 غرف وصالة'],
  ['x', 'نوع تاني'],
];
const kTypesEn = {'st': 'Studio', '1bk': '1 Bedroom Hall', '1bk2b': '1 Bedroom Hall, 2 Bath', '2bk': '2 Bedroom Hall', '2bk2b': '2 Bedroom Hall, 2 Bath', '3bk': '3 Bedroom Hall', 'x': 'Apartment'};
String typeName(dynamic k) => kTypes.where((t) => t[0] == k).map((t) => t[1]).firstOrNull ?? 'شقة';
const kFloors = [['G', 'أرضي'], ['1', 'أول'], ['2', 'تاني'], ['3', 'تالت'], ['R', 'روف']];
String floorName(dynamic k) => kFloors.where((t) => t[0] == '$k').map((t) => t[1]).firstOrNull ?? '';

double numOf(dynamic v) {
  if (v is num) return v.toDouble();
  final s = '${v ?? ''}'.replaceAll(RegExp(r'[,\s]'), '').replaceAllMapped(RegExp('[٠-٩]'), (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}');
  return double.tryParse(s) ?? 0;
}
String str(dynamic v) => v == null ? '' : '$v';
List<Obj> objs(dynamic v) => v is List ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : <Obj>[];
String uid() { final r = math.Random(); const a = 'abcdefghijklmnopqrstuvwxyz0123456789'; return List.generate(8, (_) => a[r.nextInt(a.length)]).join(); }
String money(num v) { final r = v.round(); return r.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','); }

/// سعر الشقة: p1 = السنة دفعة واحدة، p3 = السنة على 3 دفعات، mo = شهري
class Price {
  static double p1(Obj u) => numOf(u['p1']);
  static double p2(Obj u) => numOf(u['p2']);
  static double p3(Obj u) => numOf(u['p3']);
  static double mo(Obj u) => numOf(u['mo']);
  /// الشهري التقريبي للمقارنة بميزانية العميل
  static double monthlyEq(Obj u, String pay) {
    if (pay == 'mo') return mo(u);
    if (pay == '1') return p1(u) / 12;
    if (pay == '2') return p2(u) / 12;
    if (pay == '3') return (p3(u) > 0 ? p3(u) : (p2(u) > 0 ? p2(u) : p1(u))) / 12; // الشركات بتمشي 3 دفعات — لو مش مكتوب ناخد الأقرب
    if (mo(u) > 0) return mo(u);
    final y = [p1(u), p2(u), p3(u)].where((x) => x > 0);
    return y.isEmpty ? 0 : y.reduce(math.min) / 12;
  }
  /// الميزانية: لو أكبر من 20 ألف يبقى العميل قال رقم السنة → نحوّله لشهري
  static double budgetMonthly(double b) => b > 20000 ? b / 12 : b;
  static String text(Obj u) {
    final o = <String>[];
    if (p1(u) > 0) o.add('${money(p1(u))} درهم في السنة دفعة واحدة');
    if (p2(u) > 0) o.add('${money(p2(u))} درهم على دفعتين');
    if (p3(u) > 0) o.add('${money(p3(u))} درهم على 3 دفعات (≈ ${money(p3(u) / 12)} شهرياً)');
    if (mo(u) > 0) o.add('${money(mo(u))} درهم شهري');
    return o.isEmpty ? 'السعر عند الطلب' : o.join(' • ');
  }
}

/// البحث: النوع + طريقة الدفع + الميزانية الشهرية (± نسبة)
class Search {
  static List<Map<String, dynamic>> run(List<Obj> villas, {Set<String> types = const {}, String pay = 'any', double budget = 0, double tol = 10, String q = '', bool onlyAvail = true, bool? fur}) {
    final r = <Map<String, dynamic>>[];
    final qq = q.trim().toLowerCase();
    budget = Price.budgetMonthly(budget);
    for (final v in villas) {
      for (final u in objs(v['units'])) {
        if (onlyAvail && u['avail'] == false) continue;
        // «غرفة وصالة» تشمل كمان اللي بحمامين (وكذلك الغرفتين)
        final ty = str(u['type']), base = ty.endsWith('2b') ? ty.substring(0, ty.length - 2) : ty;
        if (types.isNotEmpty && !types.contains(ty) && !types.contains(base)) continue;
        if (fur == true && u['fur'] != true) continue; // مفروش
        if (fur == false && u['fur'] == true) continue; // فاضي
        if (pay == 'mo' && Price.mo(u) <= 0) continue;
        if (pay == '1' && Price.p1(u) <= 0) continue;
        if (pay == '2' && Price.p2(u) <= 0) continue;
        if (pay == '3' && Price.p3(u) <= 0 && Price.p2(u) <= 0 && Price.p1(u) <= 0) continue;
        final m = Price.monthlyEq(u, pay);
        if (budget > 0) { if (m <= 0) continue; if (m > budget * (1 + tol / 100)) continue; }
        if (qq.isNotEmpty && !'${v['name']} ${v['no']} ${v['company']} ${v['area']} ${u['no']}'.toLowerCase().contains(qq)) continue;
        r.add({'v': v, 'u': u, 'm': m, 'd': budget > 0 ? (budget - m).abs() : m});
      }
    }
    r.sort((a, b) => (a['d'] as double).compareTo(b['d'] as double));
    return r;
  }
}

/// رسالة الواتساب للعميل
String clientMsg(List<Map<String, dynamic>> picks) {
  final b = StringBuffer('أهلاً بيك 👋\nدي الشقق المتاحة اللي تناسب طلبك:\n');
  var i = 0;
  for (final x in picks) {
    final v = x['v'] as Obj, u = x['u'] as Obj; i++;
    b.writeln('\n$i) ${typeName(u['type'])}${str(u['type']) == 'x' && str(u['tx']).isNotEmpty ? ' (${u['tx']})' : ''}${str(u['no']).isNotEmpty ? ' — شقة ${u['no']}' : ''}${floorName(u['floor']).isNotEmpty ? ' • الدور ال${floorName(u['floor'])}' : ''}');
    b.writeln('🏡 ${str(v['name'])}${str(v['no']).isNotEmpty ? ' ${v['no']}' : ''}${str(v['area']).isNotEmpty ? ' — ${v['area']}' : ''}');
    b.writeln('💰 ${Price.text(u)}');
    if (str(u['note']).isNotEmpty) b.writeln('📝 ${u['note']}');
    if (str(v['loc']).isNotEmpty) b.writeln('📍 ${v['loc']}');
  }
  b.write('\nلو حابب تعاين أو تحجز كلمني 🙏');
  return b.toString();
}

/// رسالة قصيرة تحت فيديو كل شقة: السعر حسب طريقة الدفع اللي العميل عايزها + اللوكيشن (عربي أو إنجليزي)
String unitCaption(Obj v, Obj u, String pay, {bool en = false, bool terms = false}) {
  final o = <String>[];
  final p1 = Price.p1(u), p2 = Price.p2(u), p3 = Price.p3(u), mo = Price.mo(u);
  final hasVid = ((u['videos'] as List?) ?? const []).isNotEmpty;
  if (!hasVid) o.add('🏠 ${en ? kTypesEn[str(u['type'])] ?? 'Apartment' : typeName(u['type'])}');
  if (u['fur'] == true) o.add(en ? '🛋️ Furnished' : '🛋️ مفروش');
  void a1() { if (p1 > 0) o.add(en ? '💰 AED ${money(p1)} / year — 1 payment' : '💰 ${money(p1)} درهم — دفعة واحدة'); }
  void a2() { if (p2 > 0) o.add(en ? '💰 AED ${money(p2)} / year — 2 payments' : '💰 ${money(p2)} درهم — دفعتين'); }
  void a3() { if (p3 > 0) o.add(en ? '💰 AED ${money(p3)} / year — 3 payments' : '💰 ${money(p3)} درهم — 3 دفعات'); }
  void am() { if (mo > 0) o.add(en ? '💰 AED ${money(mo)} / month' : '💰 ${money(mo)} درهم شهري'); }
  if (pay == '1') { a1(); } else if (pay == '2') { a2(); } else if (pay == '3') { if (p3 > 0) { a3(); } else if (p2 > 0) { a2(); } else { a1(); } } else if (pay == 'mo') { am(); } else { a1(); am(); if (p1 <= 0 && mo <= 0) { a2(); if (p2 <= 0) a3(); } }
  if (terms && str(v['terms']).isNotEmpty) o.add('📄 ${v['terms']}');
  if (str(v['loc']).isNotEmpty) o.add('📍 ${v['loc']}');
  return o.join('\n');
}
