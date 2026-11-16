import 'dart:convert';
import 'dart:io';
import '../lib/core/js.dart';
import '../lib/core/unit.dart';
void main(List<String> a) {
  final cs = jsonDecode(File(a[0]).readAsStringSync()) as List; final out = [];
  for (final c in cs) {
    final S = <String, dynamic>{'units': [], 'groups': [{'id': 'g1', 'name': 'G', 'share': 50, 'n': 2}], 'pmode': c['pm']};
    var k = 0; final op = UnitOps(S, uid: () => 'id${k++}', now: 111, td: '2026-11-16');
    final u = op.save(null, Map<String, dynamic>.from(c['o']));
    out.add({'u': u, 'tx': S['tx'] ?? [], 'adj': S['adj'] ?? [], 'gp': S['gp'] ?? {}});
  }
  print(jsonOut(out));
}
