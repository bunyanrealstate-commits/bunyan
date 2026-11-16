import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:offers/core/model.dart';
import 'fixture.dart';

void main() {
  final vs = objs((jsonDecode(jsonEncode(fixture)) as Map)['villas']);
  test('غرفة وصالة شهري بميزانية 3500 ± 10%', () {
    final r = Search.run(vs, types: {'1bk'}, pay: 'mo', budget: 3500, tol: 10);
    expect(r.map((x) => (x['u'] as Obj)['id']).toList(), ['u2', 'u5']);
  });
  test('3 دفعات: الشهري التقريبي = السنة ÷ 12، والمحجوز مش بيظهر', () {
    final r = Search.run(vs, pay: '3', budget: 3500, tol: 0);
    expect(r.map((x) => (x['u'] as Obj)['id']).toList(), ['u3', 'u2', 'u1']);
    expect(Search.run(vs, types: {'2bk2b'}).isEmpty, true);
  });
  test('دفعة واحدة: ميزانية سنوية 72 ألف', () {
    final r = Search.run(vs, pay: '1', budget: 72000, tol: 5);
    expect(r.map((x) => (x['u'] as Obj)['id']).toList(), ['g2', 'g7']);
    expect(Price.text(r.first['u'] as Obj).contains('70,000 درهم في السنة دفعة واحدة'), true);
  });
  test('رسالة العميل', () {
    final r = Search.run(vs, types: {'1bk'}, pay: 'mo', budget: 3500);
    final m = clientMsg(r.take(1).toList());
    expect(m.contains('3,500 درهم شهري'), true);
    expect(m.contains('📍 https://maps.google.com'), true);
  });
}
