import 'dart:convert';
import 'dart:io';
import '../lib/core/hist.dart';
import '../lib/core/js.dart';
void main(List<String> a) {
  final S0 = jsonDecode(File(a[0]).readAsStringSync()) as Map<String, dynamic>;
  final before = jsonOut(S0);
  final S = jsonDecode(before) as Map<String, dynamic>;
  final u = (S['units'] as List)[0] as Map; u['name'] = 'X'; (u['leases'] as List).clear();
  (S['units'] as List).removeAt(1); (S['units'] as List).add({'id': 'zz', 'name': 'new'});
  (S['exp'] as List).add({'id': 'e1', 'a': 5}); S['cash'] = 123;
  final ch = Hist.diff(jsonDecode(before), S);
  final ch2 = jsonDecode(jsonOut(ch)) as List;
  Hist.applyUndo(ch2, S);
  // order of units may differ (removed one re-added at end) — compare as sets like the old app
  String norm(Map m) { final o = Map.of(m); o['units'] = (o['units'] as List).map((x) => jsonOut(x)).toList()..sort(); return jsonOut(o); }
  print(ch.length, );
  print(norm(S) == norm(jsonDecode(before)) ? 'UNDO OK' : 'UNDO FAIL');
}
