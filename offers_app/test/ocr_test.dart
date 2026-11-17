import 'package:flutter_test/flutter_test.dart';
import 'package:offers/core/ocrparse.dart';

/// كلام الصورة زي ما ML Kit بيطلعه (كل كلمة ومكانها) — مبني على أبديتات حقيقية
List<Map> els = [];
void w(String text, double x, double y, {double h = 30, double cw = 16}) {
  var cx = x;
  for (final s in text.split(' ')) { els.add({'s': s, 'x': cx, 'y': y, 'w': s.length * cw, 'h': h}); cx += s.length * cw + cw; }
}

void main() {
  test('Platinum Zone 47 (عناوين على سطرين + الحمامات في Remarks)', () {
    els = [];
    w('PLATINUM TEAM', 40, 120); w('AL RIYADH CITY', 440, 40); w('ZONE 47', 480, 140, h: 50);
    w('TYPE', 100, 300); w('UNIT NO.', 290, 300); w('ONE', 540, 280); w('PAYMENT', 500, 320); w('TWO', 770, 280); w('PAYMENT', 730, 320); w('REMARKS', 1150, 300);
    var y = 390.0;
    for (final r in [['2BHK', '1', '70,000', '73,000', '3 BATHROOMS + PRIVATE ENTRANCE + YARD'], ['1BHK', '2', '50,000', '52,000', '2 BATHROOMS + PRIVATE ENTRANCE + YARD'], ['1BHK', '3', '50,000', '52,000', '2 BATHROOMS + PRIVATE ENTRANCE + YARD'], ['1BHK', '4', '50,000', '52,000', '2 BATHROOMS + PRIVATE ENTRANCE + YARD']]) {
      w(r[0], 90, y); w(r[1], 360, y); w(r[2], 530, y); w(r[3], 760, y); w(r[4], 950, y, cw: 11); y += 84;
    }
    w('CONTRACT FEES : 500 AED PER YEAR', 400, 730); w('SECURITY DEPOSIT : 1 MONTH', 430, 800);
    final r = OcrParse.parse(els)!;
    expect(r.map((x) => x['no']), ['1', '2', '3', '4']);
    expect(r.map((x) => x['type']), ['2bk2b', '1bk2b', '1bk2b', '1bk2b']);
    expect(r[0]['p1'], 70000.0); expect(r[0]['p2'], 73000.0); expect(r[1]['p2'], 52000.0);
    expect(r[0]['villa'], 'ZONE 47'); expect(r[0]['inArea'], true);
    expect(r[0]['terms'], contains('DEPOSIT'));
  });

  test('NA Holding (4 فلل كل واحدة بجدول)', () {
    els = [];
    w('NA Holding', 60, 200, h: 60);
    var yy = 345.0;
    for (final r in [['Villa Al Hammadi 3 – No. 163 – Madinat Al Riyad', '5', '1-BHK', 'First floor', '38000', '40000', '3900', '-'], ['Villa Al Alhami – No. 138 – Madinat Al Riyad', '9', '1-BHK', 'Ground', '48000', '50000', '-', '-'], ['Villa Al Dhaheri – No. 85 – Madinat Al Riyad', '9', '2-BHK', 'Ground', '62000', '65000', '-', '2 bathrooms'], ['Villa Al Hajeri – No. 7 – Madinat Al Riyad', '11', '1-BHK', 'Ground', '35000', '37000', '-', '-']]) {
      w(r[0], 255, yy, cw: 11);
      w('NO', 255, yy + 50, h: 22, cw: 12); w('Description', 335, yy + 50, h: 22, cw: 11); w('Floor', 500, yy + 50, h: 22, cw: 11); w('1 Payment', 615, yy + 50, h: 22, cw: 11); w('2 Payment', 755, yy + 50, h: 22, cw: 11); w('Monthly', 890, yy + 50, h: 22, cw: 11); w('Remarks', 1005, yy + 50, h: 22, cw: 11);
      w(r[1], 265, yy + 98, h: 22, cw: 12); w(r[2], 355, yy + 98, h: 22, cw: 12); w(r[3], 480, yy + 98, h: 22, cw: 12); w(r[4], 630, yy + 98, h: 22, cw: 12); w(r[5], 775, yy + 98, h: 22, cw: 12); w(r[6], 905, yy + 98, h: 22, cw: 12); w(r[7], 1000, yy + 98, h: 22, cw: 10);
      yy += 162;
    }
    final r = OcrParse.parse(els)!;
    expect(r.length, 4);
    expect(r[0]['villa'], contains('No. 163')); expect(r[3]['villa'], contains('No. 7'));
    expect(r[0]['p1'], 38000.0); expect(r[0]['mo'], 3900.0); expect(r[0]['floor'], '1');
    expect(r[2]['type'], '2bk2b'); expect(r[3]['p2'], 37000.0);
  });

  test('MARASI (كذا مدينة + BOOKING + N\\A)', () {
    els = [];
    w('MARASI PROPERTIES', 400, 60, h: 50);
    void sec(String city, String villa, double y, List<String> row, {bool book = false}) {
      if (city.isNotEmpty) w(city, 340, y - 75, h: 45);
      w(villa, 440, y, h: 28, cw: 13);
      w('VILLA', 10, y + 75, h: 24, cw: 12); w('NO', 130, y + 75, h: 24, cw: 12); w('TAYPE', 250, y + 75, h: 24, cw: 12); w('REMARKS', 500, y + 75, h: 24, cw: 12); w('FLOOR', 710, y + 75, h: 24, cw: 12); w('1PAYMENT', 900, y + 75, h: 24, cw: 12); w('2PAYMENT', 1060, y + 75, h: 24, cw: 12); w('3PAYMENT', 1220, y + 75, h: 24, cw: 12); w('MONTHLY', 1390, y + 75, h: 24, cw: 12);
      w(row[0], 40, y + 140, h: 24); w(row[1], 140, y + 140, h: 24); w(row[2], 280, y + 140, h: 24); w('____', 520, y + 140, h: 24); w(row[3], 680, y + 140, h: 20, cw: 10);
      if (book) { w('BOOKING', 1150, y + 140, h: 26); } else { w(row[4], 910, y + 140, h: 24); w(row[5], 1075, y + 140, h: 24); w(row[6], 1230, y + 140, h: 24); w(row[7], 1410, y + 140, h: 24); }
    }
    sec('RIYAD CITY', 'VILLA AL NAQIB NO -58-', 255, ['58', '12', '1BHK', 'EXTENSION - ON THE LEFT', '37,000', '38,000', '39,000', '3,700']);
    sec('SHAMKHA CITY', 'VILLA AL JAZAIRI NO -26-', 535, ['26', '4', '2BHK', 'FIREST FLOOR', '65,000', '66,000', '67,000', 'N\\A']);
    sec('SHAKHBOUT CITY', 'VILLA AL HILAL NO -13-', 815, ['13', '3', '1BHK', 'FIREST FLOOR', '52,000', '53,000', '54,000', 'N\\A']);
    sec('', 'AL MAMARI COMPOUND NO -92-', 1020, ['1', '9', 'STUDIO', 'EXTENSION - ON THE LEFT'], book: true);
    sec('MBZ CITY', 'VILLA AL BAHARNA NO -49-', 1300, ['49', '5', '1BHK', 'FIREST FLOOR', '58,000', '59,000', '60,000', 'N\\A']);
    final r = OcrParse.parse(els)!;
    expect(r.map((x) => x['no']), ['12', '4', '3', '9', '5']);
    expect(r.map((x) => x['inArea']), [true, false, false, false, false]);
    expect(r[0]['p3'], 39000.0); expect(r[0]['mo'], 3700.0); expect(r[1]['mo'], isNull);
    expect(r[3]['booked'], true); expect(r[3]['type'], 'st');
    expect(r[1]['floor'], '1');
  });

  test('صورة عادية → null', () {
    els = [];
    w('Happy birthday Ahmed', 100, 100); w('see you at 8', 100, 200);
    expect(OcrParse.parse(els), isNull);
  });
}
