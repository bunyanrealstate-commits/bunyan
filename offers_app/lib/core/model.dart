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

/// سعر الشقة: p3 = إجمالي السنة على 3 دفعات، mo = شهري
class Price {
  static double p3(Obj u) => numOf(u['p3']);
  static double mo(Obj u) => numOf(u['mo']);
  /// الشهري التقريبي للمقارنة بميزانية العميل
  static double monthlyEq(Obj u, String pay) {
    if (pay == 'mo') return mo(u);
    if (pay == '3') return p3(u) / 12;
    return mo(u) > 0 ? mo(u) : p3(u) / 12;
  }
  static String text(Obj u) {
    final o = <String>[];
    if (p3(u) > 0) o.add('${money(p3(u))} درهم على 3 دفعات (≈ ${money(p3(u) / 12)} شهرياً)');
    if (mo(u) > 0) o.add('${money(mo(u))} درهم شهري');
    return o.isEmpty ? 'السعر عند الطلب' : o.join(' • ');
  }
}

/// البحث: النوع + طريقة الدفع + الميزانية الشهرية (± نسبة)
class Search {
  static List<Map<String, dynamic>> run(List<Obj> villas, {Set<String> types = const {}, String pay = 'any', double budget = 0, double tol = 10, String q = '', bool onlyAvail = true}) {
    final r = <Map<String, dynamic>>[];
    final qq = q.trim().toLowerCase();
    for (final v in villas) {
      for (final u in objs(v['units'])) {
        if (onlyAvail && u['avail'] == false) continue;
        if (types.isNotEmpty && !types.contains(str(u['type']))) continue;
        if (pay == 'mo' && Price.mo(u) <= 0) continue;
        if (pay == '3' && Price.p3(u) <= 0) continue;
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
