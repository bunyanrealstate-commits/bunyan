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
        final ac = e.accr(); final ev = e.events(); final pj = e.project(ev);
        out['$pm|$day|$ws'] = {'acP': ac['profit']!.round(), 'acE': ac['earned']!.round(), 'acC': ac['cost']!.round(), 'evN': ev.length, 'evS': ev.fold<double>(0, (s, x) => s + (x['a'] as double)).round(), 'pjMin': (pj['min'] as double).round(), 'pjRows': (pj['rows'] as List).length, 'pjEnd': (pj['rows'] as List).isEmpty ? 0 : ((pj['rows'] as List).last['end'] as double).round(),'cash': e.cashNow().round(), 'profit': r['profit']!.round(), 'rev': r['rev']!.round(), 'cost': r['cost']!.round(), 'eq': f['eq']!.round(), 'A': f['A']!.round(), 'L': f['L']!.round(), 'rcv': f['rcv']!.round(), 'unr': f['unr']!.round(), 'preCo': f['preCo']!.round(), 'accCo': f['accCo']!.round()};
      }
    }
  }
  print(jsonOut(out));
}
