// يحسب الأرقام الأساسية بالمحرك الجديد علشان نقارنها بالقديم
import 'dart:convert';
import 'dart:io';
import '../lib/core/js.dart';
import '../lib/core/engine.dart';

void main(List<String> a) {
  final S = jsonDecode(File(a[0]).readAsStringSync()) as Map<String, dynamic>;
  final days = a[1].split(',');
  final out = {};
  for (final pm in ['grp', 'me']) {
    S['pmode'] = pm;
    for (final day in days) {
      final p = day.split('-'); fixedToday = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]), 12);
      for (final ws in ['all', '-', ...objs(S['groups']).map((g) => g['id'] as String)]) {
        final e = Engine(S, WS: ws); final r = e.rcvP(); final f = e.fpos();
        out['$pm|$day|$ws'] = {'cash': e.cashNow().round(), 'profit': r['profit']!.round(), 'rev': r['rev']!.round(), 'cost': r['cost']!.round(), 'eq': f['eq']!.round(), 'A': f['A']!.round(), 'L': f['L']!.round(), 'rcv': f['rcv']!.round(), 'unr': f['unr']!.round(), 'preCo': f['preCo']!.round(), 'accCo': f['accCo']!.round()};
      }
    }
  }
  print(jsonOut(out));
}
