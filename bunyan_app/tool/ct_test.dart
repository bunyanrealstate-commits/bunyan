import 'dart:convert';
import 'dart:io';
import '../lib/core/contract.dart';
void main(List<String> a) {
  final S = jsonDecode(File(a[0]).readAsStringSync()) as Map<String, dynamic>;
  final h = (S['ct'] as Map)['html'] as String;
  final r = Ct.refresh(S, h);
  final re = RegExp(r'data-f="([^"]+)"[^>]*>(.*?)</span>', dotAll: true);
  final A = re.allMatches(h).map((m) => '${m[1]}=${m[2]}').toList(), B = re.allMatches(r).map((m) => '${m[1]}=${m[2]}').toList();
  var bad = 0; for (var i = 0; i < A.length; i++) { if (A[i] != B[i]) { bad++; print('DIFF ${A[i]}  →  ${B[i]}'); } }
  print('spans ${A.length} diffs $bad');
}
