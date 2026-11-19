import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// بياخد صورة توقيع على ورقة: بيشيل الورقة (الخلفية) وبيسيب الحبر بس، ويقصّ حوالين التوقيع → PNG شفاف
class SigImg {
  static Future<String?> extract(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1100);
    final src = (await codec.getNextFrame()).image;
    final w = src.width, h = src.height;
    final bd = await src.toByteData(format: ui.ImageByteFormat.rawRgba); if (bd == null) return null;
    final px = bd.buffer.asUint8List();
    final lum = Uint8List(w * h);
    for (var i = 0, j = 0; i < lum.length; i++, j += 4) { lum[i] = ((px[j] * 299 + px[j + 1] * 587 + px[j + 2] * 114) ~/ 1000); }
    // لون الورقة: بنحسبه في مربعات صغيرة (عشان الضل والإضاءة مش متساوية)
    const cell = 40; final cw = (w + cell - 1) ~/ cell, ch = (h + cell - 1) ~/ cell; final bg = Uint8List(cw * ch);
    for (var cy = 0; cy < ch; cy++) {
      for (var cx = 0; cx < cw; cx++) {
        final hist = List<int>.filled(256, 0); var n = 0;
        for (var y = cy * cell; y < (cy + 1) * cell && y < h; y += 2) { for (var x = cx * cell; x < (cx + 1) * cell && x < w; x += 2) { hist[lum[y * w + x]]++; n++; } }
        var acc = 0, v = 255; for (var k = 255; k >= 0; k--) { acc += hist[k]; if (acc >= n * .3) { v = k; break; } } // الأفتح 30% = الورقة
        bg[cy * cw + cx] = v;
      }
    }
    int bgAt(int x, int y) => bg[(y ~/ cell).clamp(0, ch - 1) * cw + (x ~/ cell).clamp(0, cw - 1)];
    final out = Uint8List(w * h * 4); var x0 = w, y0 = h, x1 = -1, y1 = -1, ink = 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x; final b = bgAt(x, y); final d = b - lum[i];
        if (d > 38 && lum[i] < 200) {
          final a = ((d - 38) * 4).clamp(90, 255); final o = i * 4;
          out[o] = 0x14; out[o + 1] = 0x24; out[o + 2] = 0x5c; out[o + 3] = a; // حبر أزرق غامق
          ink++; if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
        }
      }
    }
    if (ink < 60 || x1 < 0) return null;
    // نشيل النقط الصغيرة البعيدة عن الطرف: قصّ بهامش
    const pad = 12; x0 = (x0 - pad).clamp(0, w - 1); y0 = (y0 - pad).clamp(0, h - 1); x1 = (x1 + pad).clamp(0, w - 1); y1 = (y1 + pad).clamp(0, h - 1);
    final cwid = x1 - x0 + 1, chei = y1 - y0 + 1; final crop = Uint8List(cwid * chei * 4);
    for (var y = 0; y < chei; y++) { crop.setRange(y * cwid * 4, (y + 1) * cwid * 4, out, ((y + y0) * w + x0) * 4); }
    final img = await _fromPixels(crop, cwid, chei);
    final png = await img.toByteData(format: ui.ImageByteFormat.png); if (png == null) return null;
    return 'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}';
  }

  static Future<ui.Image> _fromPixels(Uint8List p, int w, int h) async {
    final buf = await ui.ImmutableBuffer.fromUint8List(p);
    final d = ui.ImageDescriptor.raw(buf, width: w, height: h, pixelFormat: ui.PixelFormat.rgba8888);
    final c = await d.instantiateCodec(); return (await c.getNextFrame()).image;
  }
}
