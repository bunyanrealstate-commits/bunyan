import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bunyan/core/contract.dart';
import 'package:bunyan/core/ct_pdf.dart';
import 'package:bunyan/core/engine.dart';
import 'package:bunyan/core/js.dart';

/// كل أشكال عقد العميل (مفروش، فاضي بالـ 3 أشكال) بتطلع PDF من غير أخطاء — بالتوقيعات
void main() {
  test('contract templates → PDF', () async {
    CtPdf.loader = (p) async => ByteData.sublistView(File(p).readAsBytesSync());
    final S = jsonDecode(File('test/fixture.json').readAsStringSync()) as Map<String, dynamic>;
    final e = Engine(S, WS: 'all'); final ls = Ct.leases(S, e);
    Ct.fill(S, ls.first['u'] as Obj, ls.first['L'] as Obj);
    const px = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    Ct.sigs(S); (S['sigs'] as List).add({'id': 's1', 'n': 'x', 'img': px}); Ct.ct(S)['sig'] = 's1'; Ct.ct(S)['tsig'] = px; Ct.ct(S)['wsig'] = {'1': px};
    for (final cfg in [['a', 'bi', 'ar'], ['b', 'bi', 'ar'], ['b', 'one', 'ar'], ['b', 'one', 'en'], ['b', 'tc', 'en']]) {
      Ct.switchTpl(S, cfg[0]); Ct.ct(S)['lay'] = cfg[1]; Ct.ct(S)['lang'] = cfg[2]; Ct.ct(S)['html'] = '';
      if (cfg[0] == 'b') Ct.autoPays(S);
      final h = Ct.finalHtml(S);
      expect(h.contains('data-f="tn"'), true, reason: cfg.join('/'));
      expect('ctsig'.allMatches(h).length, 3, reason: 'sigs ${cfg.join('/')}');
      final b = await CtPdf.build(h);
      expect(b.length > 2000, true, reason: cfg.join('/'));
      expect(Ct.missing(S), isA<List<String>>());
      Ct.issues(S);
    }
    Ct.newContract(S); expect(str(Ct.F(S)['tn']), '');
  });
}
