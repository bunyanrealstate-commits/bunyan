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
    expect(Search.run(vs, types: {'2bk2b'}).any((x) => (x['u'] as Obj)['id'] == 'u4'), false);
  });
  test('دفعة واحدة: ميزانية سنوية 72 ألف', () {
    final r = Search.run(vs, pay: '1', budget: 72000, tol: 5);
    expect(r.map((x) => (x['u'] as Obj)['id']).toList(), ['g2', 'g7']);
    expect(Price.text(r.first['u'] as Obj).contains('70,000 درهم في السنة دفعة واحدة'), true);
  });
  test('رسالة قصيرة تحت الفيديو', () {
    final v = vs[2], u = objs(v['units'])[0];
    expect(unitCaption(v, u, '1'), '🏠 غرفتين وصالة وحمامين\n💰 70,000 درهم — دفعة واحدة');
    final v1 = vs[0], u2 = objs(v1['units'])[1]..['videos'] = ['x'];
    expect(unitCaption(v1, u2, 'mo'), '💰 3,500 درهم شهري\n📍 https://maps.google.com/?q=24.3,54.6');
  });
  test('رسالة العميل', () {
    final r = Search.run(vs, types: {'1bk'}, pay: 'mo', budget: 3500);
    final m = clientMsg(r.take(1).toList());
    expect(m.contains('3,500 درهم شهري'), true);
    expect(m.contains('📍 https://maps.google.com'), true);
  });
}
