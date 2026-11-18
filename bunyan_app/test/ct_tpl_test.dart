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
    for (final cfg in [['a', 'bi', 'ar', 'm'], ['a', 'bi', 'ar', 'p'], ['b', 'bi', 'ar', 'p'], ['b', 'bi', 'ar', 'm'], ['b', 'one', 'ar', 'p'], ['b', 'one', 'en', 'm'], ['b', 'tc', 'en', 'm'], ['b', 'tc', 'en', 'p']]) {
      Ct.switchTpl(S, cfg[0]); Ct.ct(S)['lay'] = cfg[1]; Ct.ct(S)['lang'] = cfg[2]; Ct.ct(S)['cl'] = ['ar', 'en', 'bi'][cfg.join().length % 3]; Ct.ct(S)['html'] = '';
      Ct.F(S)['rm'] = cfg[3]; Ct.F(S)['cq'] = '1'; Ct.F(S)['cqd'] = true; Ct.F(S)['pn'] = '4';
      if (cfg[3] == 'p') Ct.autoPays(S);
      final hh = Ct.paper(S);
      expect(hh.contains('class="ptb"'), cfg[3] == 'p', reason: 'ptb ${cfg.join('/')}');
      expect(hh.contains('Monthly Rent') || hh.contains('الإيجار الشهري'), cfg[3] == 'm', reason: 'mr ${cfg.join('/')}');
      final h = Ct.finalHtml(S);
      expect(h.contains('data-f="tn"'), true, reason: cfg.join('/'));
      expect('ctsig'.allMatches(h).length, 3, reason: 'sigs ${cfg.join('/')}');
      expect(h.contains('class="tc2"'), true, reason: 'terms ${cfg.join('/')}');
      final b = await CtPdf.build(h);
      expect(b.length > 2000, true, reason: cfg.join('/'));
      expect(Ct.missing(S), isA<List<String>>());
      Ct.issues(S);
    }
    expect(Ct.chqTxt({'cq': '1', 'cqd': true}, true), '1 Cheque + 1 Security Deposit Cheque');
    expect(Ct.chqTxt({'cq': '4'}, false), '4 شيكات');
    for (final l in ['ar', 'en', 'bi']) {
      Ct.switchTpl(S, 'b'); Ct.ct(S)['cl'] = l; Ct.ct(S)['lang'] = l == 'ar' ? 'ar' : 'en'; Ct.F(S)['rm'] = 'p'; Ct.F(S)['pn'] = '3'; Ct.autoPays(S);
      File('build/ct_$l.pdf').writeAsBytesSync(await CtPdf.build(Ct.finalHtml(S)));
    }
    Ct.newContract(S); expect(str(Ct.F(S)['tn']), '');
    // 40000 على 6 دفعات من 31/10/2026 لـ 30/10/2027 = كل شهرين
    final f = Ct.F(S); f..['st'] = '2026-10-31'..['en'] = '2027-10-30'..['tot'] = '40000'..['pn'] = '6';
    Ct.autoPays(S); final P = lst(f['pays']);
    expect(P.length, 6);
    expect([for (final x in P) obj(x)!['d']], ['2026-10-31', '2026-12-31', '2027-02-28', '2027-04-30', '2027-06-30', '2027-08-31']);
    expect([for (final x in P) obj(x)!['a']].fold<num>(0, (a, b) => a + (b as num)), 40000);
    expect(Ct.spanMonths('2026-10-31', '2027-10-30'), 12);
    expect(Ct.endOf('2026-10-31', 12), '2027-10-30');
  });
}
