import 'dart:convert';
import 'dart:io';
import '../lib/core/js.dart';
import '../lib/core/lease.dart';
void main(List<String> a) {
  final cases = jsonDecode(File(a[0]).readAsStringSync()) as List;
  final out = [];
  for (final c in cases) {
    final s = pd(c['start']); final p = LeaseB.payDay(c['start'], c['day']);
    out.add({'rows': LeaseB.build(start: c['start'], cmo: n(c['cmo']), rent: n(c['rent']), day: c['day'], m0: n(c['m0'])), 'sug': LeaseB.sugM(s, p), 'end': iso(LeaseB.endOf(s, n(c['cmo'])))});
  }
  print(jsonOut(out));
}
