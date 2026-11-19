import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bunyan/core/sigimg.dart';

void main() {
  testWidgets('توقيع من صورة: بيشيل الورقة ويقصّ', (t) async {
    await t.runAsync(() async {
      final rec = ui.PictureRecorder(); final c = Canvas(rec);
      const w = 900.0, h = 600.0;
      c.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(w, h), [const Color(0xFFF4F1EA), const Color(0xFFB9B4AA)])); // ورقة فيها ضل
      final p = Paint()..color = const Color(0xFF1C2333)..strokeWidth = 7..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
      final path = Path()..moveTo(220, 360)..cubicTo(300, 160, 380, 460, 460, 300)..cubicTo(520, 200, 600, 420, 690, 280);
      c.drawPath(path, p);
      final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
      final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final out = await SigImg.extract(png);
      expect(out, isNotNull);
      final b = base64Decode(out!.split(',').last);
      Directory('build').createSync(recursive: true); File('build/sig.png').writeAsBytesSync(b);
      final r = await (await ui.instantiateImageCodec(b)).getNextFrame();
      expect(r.image.width < 600, true, reason: 'اتقصّ حوالين التوقيع: ${r.image.width}x${r.image.height}');
      expect(r.image.height < 330, true);
      final px = (await r.image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      var clear = 0, ink = 0; for (var i = 3; i < px.length; i += 4) { if (px[i] == 0) clear++; else ink++; }
      expect(clear > ink * 2, true, reason: 'الورقة اتشالت (شفاف $clear / حبر $ink)');
      expect(ink > 500, true);
      // ورقة فاضية → مفيش توقيع
      final rec2 = ui.PictureRecorder(); Canvas(rec2).drawRect(const Rect.fromLTWH(0, 0, 400, 300), Paint()..color = const Color(0xFFF2F2F2));
      final e2 = (await (await rec2.endRecording().toImage(400, 300)).toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      expect(await SigImg.extract(e2), isNull);
    });
  });
}
