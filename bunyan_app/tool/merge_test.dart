import 'dart:convert';
import 'dart:io';
import '../lib/core/js.dart';
import '../lib/core/merge3.dart';
void main(List<String> a) {
  final raw = File(a[0]).readAsStringSync();
  final S = jsonDecode(raw) as Map<String, dynamic>;
  // 1) نفس النص بالظبط بعد القراية والكتابة؟
  final out = jsonOut(S);
  final reparsed = jsonDecode(out);
  print('roundtrip-equal-json: ${jsonEncode(reparsed) == jsonEncode(S)}  len ${raw.length} vs ${out.length}');
  // 2) دمج: موبايل عدّل وحدة، السحابة عدلت مصروف
  final B = sig(S);
  final L = jsonDecode(raw) as Map<String, dynamic>; final R = jsonDecode(raw) as Map<String, dynamic>;
  (L['units'] as List)[0]['name'] = 'تعديل موبايل';
  R['res'] = 999;
  final m = merge3(L, R, true, B)!;
  print('l=${m.l} r=${m.r} both=${m.both} name=${(m.s['units'] as List)[0]['name']} res=${m.s['res']} keys=${m.s.length}/${S.length}');
}
