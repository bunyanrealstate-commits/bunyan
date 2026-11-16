import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:bunyan/core/ct_pdf.dart';

void main() {
  test('contract pdf renders', () async {
    CtPdf.loader = (p) async => ByteData.sublistView(File(p).readAsBytesSync());
    final b = await CtPdf.build(File('test/ct_sample.html').readAsStringSync());
    expect(b.length, greaterThan(3000));
    File('build/ct_test.pdf').writeAsBytesSync(b);
  });
}
