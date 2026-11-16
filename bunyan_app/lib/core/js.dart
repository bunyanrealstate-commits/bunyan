/// مساعدات علشان الحسابات تمشي بالظبط زي نسخة JavaScript القديمة (نفس الأرقام بالمليم)
import 'dart:convert';

typedef Obj = Map<String, dynamic>;

/// زي +x في JavaScript
double n(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  if (v is String) { final t = v.trim(); if (t.isEmpty) return 0; return double.tryParse(t) ?? double.nan; }
  return double.nan;
}
/// زي (+x||0)
double n0(dynamic v) { final x = n(v); return x.isNaN ? 0 : x; }
bool truthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0 && !v.isNaN;
  if (v is String) return v.isNotEmpty;
  return true;
}
String str(dynamic v) => v == null ? '' : (v is String ? v : (v is num ? numStr(v) : v.toString()));
Obj? obj(dynamic v) => v is Map ? v.cast<String, dynamic>() : null;
List<dynamic> lst(dynamic v) => v is List ? v : const [];
List<Obj> objs(dynamic v) => lst(v).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
/// x[i] على object أو array (rav/rat/ov مفاتيحهم نصوص "0")
dynamic idx(dynamic m, int i) {
  if (m is Map) return m['$i'];
  if (m is List && i >= 0 && i < m.length) return m[i];
  return null;
}
bool hasIdx(dynamic m, int i) => idx(m, i) != null;
/// JS strict equality بين أرقام
bool same(dynamic a, dynamic b) {
  if (a is num && b is num) return a == b;
  return a == b;
}

/* ───── تواريخ زي JavaScript ───── */
DateTime pd(dynamic v) {
  final s = str(v);
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (m == null) return DateTime.fromMillisecondsSinceEpoch(0); // Invalid Date في JS — مش مفروض يحصل
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}
DateTime addM(DateTime d, num k) => DateTime(d.year, d.month + k.toInt(), d.day, d.hour, d.minute, d.second, d.millisecond);
String iso(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
int ms(DateTime d) => d.millisecondsSinceEpoch;
int mkey(DateTime d) => d.year * 12 + (d.month - 1);

/// اليوم (ممكن يتثبّت في الاختبارات)
DateTime? fixedToday;
DateTime today() { final d = fixedToday ?? DateTime.now(); return DateTime(d.year, d.month, d.day); }

/* ───── JSON بيحافظ على الأرقام زي JS (8350 مش 8350.0) ───── */
String numStr(num v) {
  if (v is int) return v.toString();
  final d = v.toDouble();
  if (d.isNaN || d.isInfinite) return 'null';
  if (d == d.roundToDouble() && d.abs() < 1e21) return d.toInt().toString();
  var t = d.toString();
  if (t.contains('e')) { final p = t.split('e'); final e = int.parse(p[1]); t = '${p[0].replaceAll(RegExp(r'\.0$'), '')}e${e > 0 ? '+' : ''}$e'; }
  return t;
}
String jsonOut(dynamic v) {
  final b = StringBuffer(); _w(b, v); return b.toString();
}
void _w(StringBuffer b, dynamic v) {
  if (v == null) { b.write('null'); }
  else if (v is String) { b.write(jsonEncode(v)); }
  else if (v is bool) { b.write(v); }
  else if (v is num) { b.write(numStr(v)); }
  else if (v is Map) { b.write('{'); var f = true; v.forEach((k, x) { if (!f) b.write(','); f = false; b.write(jsonEncode(k.toString())); b.write(':'); _w(b, x); }); b.write('}'); }
  else if (v is List) { b.write('['); for (var i = 0; i < v.length; i++) { if (i > 0) b.write(','); _w(b, v[i]); } b.write(']'); }
  else { b.write(jsonEncode(v.toString())); }
}
