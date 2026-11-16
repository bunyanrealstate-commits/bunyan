import 'dart:convert';
import 'dart:io';
import '../lib/core/js.dart';
import '../lib/core/engine.dart';
void main(List<String> a) {
  final S = jsonDecode(File(a[0]).readAsStringSync()) as Map<String, dynamic>; final out = {};
  for (final day in a[1].split(',')) { final p = day.split('-'); fixedToday = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]), 12);
    for (final g in objs(S['groups'])) { out['$day|${g['id']}'] = Engine(S, WS: g['id']).items().map((x) => {'ty': x['ty'], 'id': x['id'], 'd': x['d'], 'label': x['label'], 'amt': (x['amt'] as num).round()}).toList(); } }
  print(jsonOut(out));
}
