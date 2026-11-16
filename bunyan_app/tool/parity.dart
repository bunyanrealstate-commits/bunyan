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
        final an = e.annW(); var uaP = 0.0, uaI = 0.0, pjP = 0.0; for (final u in e.SU()) { final a = e.ua(u); uaP += a['profit']!; uaI += a['inc']!; final q = e.projU(u); if (q != null) pjP += q['p'] as double; }
        final lg = e.ledger(); out['$pm|$day|$ws'] = {'lgN': lg.length, 'lgS': lg.fold<double>(0, (s, x) => s + (x['a'] as double)).round(), 'lgF': lg.isEmpty ? '' : '${lg.first['d']}|${lg.first['w']}', 'anP': (an['p'] as double).round(), 'anO': ((an['occ'] as double) * 1000).round(), 'uaP': uaP.round(), 'uaI': uaI.round(), 'pjP': pjP.round(), 'acP': ac['profit']!.round(), 'acE': ac['earned']!.round(), 'acC': ac['cost']!.round(), 'evN': ev.length, 'evS': ev.fold<double>(0, (s, x) => s + (x['a'] as double)).round(), 'pjMin': (pj['min'] as double).round(), 'pjRows': (pj['rows'] as List).length, 'pjEnd': (pj['rows'] as List).isEmpty ? 0 : ((pj['rows'] as List).last['end'] as double).round(),'cash': e.cashNow().round(), 'profit': r['profit']!.round(), 'rev': r['rev']!.round(), 'cost': r['cost']!.round(), 'eq': f['eq']!.round(), 'A': f['A']!.round(), 'L': f['L']!.round(), 'rcv': f['rcv']!.round(), 'unr': f['unr']!.round(), 'preCo': f['preCo']!.round(), 'accCo': f['accCo']!.round()};
      }
    }
  }
  print(jsonOut(out));
}
