import 'dart:convert';
import 'dart:io';
import '../lib/core/monitor.dart';
void main(List<String> a) {
  print('selftest: ${Mon.selfTest()}');
  final S = jsonDecode(File(a[0]).readAsStringSync()) as Map<String, dynamic>;
  for (final r in Mon.run(S)) { print('${(r['rule'] as MonRule).id}: ${r['f']}'); }
  print('done');
}
