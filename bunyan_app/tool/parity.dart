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
        final sm = e.sim({'fi': 8000, 'total': 40000, 'cm': 12, 'n': 4, 'furn': 7000, 'salv': 1000, 'rent': 5200, 'rm': 11, 'share': 50, 'me': 3000}); out['sim|$day|$pm|$ws|x'] = {'ok': sm['ok'] == true ? 1 : 0, 'up': sm['up'], 'gain': sm['gain'], 'roi': sm['roi'], 'mr': sm['mr'], 'pay': sm['pay'], 'min': (sm['pw'] as Map)['min'], 'bmin': (sm['pb'] as Map)['min'], 'minD': iso((sm['pw'] as Map)['minD'] as DateTime)}; final lg = e.ledger(); for (final u in e.SU()) { final o = e.occ(u); out['occ|${u['id']}|$day|$pm|$ws'] = {'D': o['D'], 'c': o['c'], 'free': o['free'], 'fv': o['freeVal'], 'vac': o['vac'], 'lp': o['lossPast'], 'lf': o['lossFut'], 'g': (o['gaps'] as List).map((x) => '${x['a']}>${x['b']}').join(',')}; } out['$pm|$day|$ws'] = {'lgN': lg.length, 'lgS': lg.fold<double>(0, (s, x) => s + (x['a'] as double)).round(), 'lgF': lg.isEmpty ? '' : '${lg.first['d']}|${lg.first['w']}', 'anP': (an['p'] as double).round(), 'anO': ((an['occ'] as double) * 1000).round(), 'uaP': uaP.round(), 'uaI': uaI.round(), 'pjP': pjP.round(), 'acP': ac['profit']!.round(), 'acE': ac['earned']!.round(), 'acC': ac['cost']!.round(), 'evN': ev.length, 'evS': ev.fold<double>(0, (s, x) => s + (x['a'] as double)).round(), 'pjMin': (pj['min'] as double).round(), 'pjRows': (pj['rows'] as List).length, 'pjEnd': (pj['rows'] as List).isEmpty ? 0 : ((pj['rows'] as List).last['end'] as double).round(),'cash': e.cashNow().round(), 'profit': r['profit']!.round(), 'rev': r['rev']!.round(), 'cost': r['cost']!.round(), 'eq': f['eq']!.round(), 'A': f['A']!.round(), 'L': f['L']!.round(), 'rcv': f['rcv']!.round(), 'unr': f['unr']!.round(), 'preCo': f['preCo']!.round(), 'accCo': f['accCo']!.round()};
      }
    }
  }
  print(jsonOut(out));
}
