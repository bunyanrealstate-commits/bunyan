/// 🔍 قراءة الأبديت على الموبايل نفسه (من غير Gemini):
/// ML Kit بيدّي كل كلمة ومكانها في الصورة ← هنا بنلاقي صف العناوين (NO / Type / 1 Payment / Monthly …)
/// ونقسم الأعمدة، وكل رقم شقة يبقى صف، وفوق كل جدول بنلاقي اسم الفيلا ورقمها والمنطقة.
/// لو الجدول مش واضح بنرجّع null والتطبيق يسأل Gemini.
import 'dart:math' as math;
import 'model.dart';

class El {
  final String s;
  final double x, y, w, h;
  final List<El> parts;
  El(this.s, this.x, this.y, this.w, this.h, [this.parts = const []]);
  double get cx => x + w / 2;
  double get cy => y + h / 2;
  String get t => s.toLowerCase();
  static El of(Map m) => El('${m['s'] ?? ''}', numOf(m['x']), numOf(m['y']), numOf(m['w']), numOf(m['h']));
}

class _Col {
  final String kind; // no, type, floor, pay, rem, villa
  String pay; // 1, 2, 3, mo
  double cx;
  int n = 1;
  _Col(this.kind, this.cx, [this.pay = '']);
}

class OcrParse {
  static final _kNo = RegExp(r'^(no\.?|unit|flat|apt\.?|apartment#?|#)$');
  static final _kType = RegExp(r'^(type|taype|tayp|description|details|apartment)$');
  static final _kFloor = RegExp(r'^floors?$');
  static final _kPay = RegExp(r'^(\d?payments?|cheques?|chq|monthly|yearly|annual|annually|month|year)$');
  static final _kRem = RegExp(r'^(remarks?|notes?)$');
  static final _cityRx = RegExp(r'riyad|riyadh|reyad|shamkha|shakhb|mbz|khalifa|bani|yas|mussafah|mohammed bin zayed|city');
  static final _villaRx = RegExp(r'villa\s*(no\.?|#)?\s*-?\s*\d|\bno\.?\s*-?\s*\d|zone\s*\d|compound|فيلا');

  static String _kind(String t) {
    t = t.replaceAll(RegExp(r'[^a-z0-9#./]'), '');
    if (_kNo.hasMatch(t)) return 'no';
    if (_kType.hasMatch(t)) return 'type';
    if (_kFloor.hasMatch(t)) return 'floor';
    if (_kPay.hasMatch(t)) return 'pay';
    if (_kRem.hasMatch(t)) return 'rem';
    if (t == 'villa') return 'villa';
    return '';
  }

  /// يقسم الكلام لسطور حسب الارتفاع
  static List<List<El>> _lines(List<El> els, double h) {
    final s = [...els]..sort((a, b) => a.cy.compareTo(b.cy));
    final out = <List<El>>[];
    for (final e in s) {
      if (out.isNotEmpty && (e.cy - out.last.map((x) => x.cy).reduce((a, b) => a + b) / out.last.length).abs() < h * .55) { out.last.add(e); } else { out.add([e]); }
    }
    for (final l in out) { l.sort((a, b) => a.x.compareTo(b.x)); }
    return out;
  }

  /// الكلام اللي جنب بعض على نفس السطر (زي «3 BATHROOMS + PRIVATE ENTRANCE») = خانة واحدة
  static List<El> _chunks(List<El> band, double h) {
    final out = <El>[];
    for (final l in _lines(band, h)) {
      El? cur;
      for (final e in l) {
        if (cur != null && e.x - (cur.x + cur.w) < h * .9) {
          final x0 = math.min(cur.x, e.x), y0 = math.min(cur.y, e.y);
          cur = El('${cur.s} ${e.s}', x0, y0, math.max(cur.x + cur.w, e.x + e.w) - x0, math.max(cur.y + cur.h, e.y + e.h) - y0, [...(cur.parts.isEmpty ? [cur] : cur.parts), e]);
        } else {
          if (cur != null) out.add(cur);
          cur = e;
        }
      }
      if (cur != null) out.add(cur);
    }
    return out;
  }

  static String _txt(Iterable<El> l) => (l.toList()..sort((a, b) { final d = (a.cy - b.cy); return d.abs() > math.min(a.h, b.h) * .6 ? d.sign.toInt() : a.x.compareTo(b.x); })).map((e) => e.s).join(' ');

  static double _num(String s) {
    final t = s.toLowerCase().replaceAll(RegExp(r'aed|dhs?|درهم'), '').trim();
    if (t.isEmpty || RegExp(r'^(-|—|–|n[/\\]?a|\.)+$').hasMatch(t.replaceAll(' ', ''))) return 0;
    final m = RegExp(r'(\d{1,3}(?:[,.]\s?\d{3})+|\d+(?:\.\d+)?)').firstMatch(t);
    if (m == null) return 0;
    final raw = m.group(1)!;
    var v = RegExp(r'[,.]\s?\d{3}').hasMatch(raw) ? double.parse(raw.replaceAll(RegExp(r'[,.\s]'), '')) : double.parse(raw);
    if (v > 0 && v < 1000) v *= 1000; // 58 = 58,000
    return v;
  }

  static String _type(String s) {
    final t = s.toLowerCase();
    final bath = RegExp(r'([2-4])\s*(bath|bathroom|toilet|حمام)').firstMatch(t);
    final two = bath != null || RegExp(r'two bath|حمامين').hasMatch(t);
    if (RegExp(r'studio|ستو?ديو').hasMatch(t)) return 'st';
    final m = RegExp(r'([1-4])\s*[-–]?\s*(bhk|b/?r|bed\s*room|bedroom|bed\b|br\b)').firstMatch(t);
    if (m == null) return '';
    final n = m.group(1)!;
    if (n == '1') return two ? '1bk2b' : '1bk';
    if (n == '2') return two ? '2bk2b' : '2bk';
    return '3bk';
  }

  static String _floor(String s) {
    final t = s.toLowerCase();
    if (RegExp(r'ground|\bg\b|أرضي|ارضي').hasMatch(t)) return 'G';
    if (RegExp(r'first|firest|fisrt|1st|اول|أول').hasMatch(t)) return '1';
    if (RegExp(r'second|2nd|تاني|ثاني').hasMatch(t)) return '2';
    if (RegExp(r'third|3rd|تالت|ثالث').hasMatch(t)) return '3';
    if (RegExp(r'roof|penthouse|روف').hasMatch(t)) return 'R';
    return '';
  }

  /// بيرجّع نفس شكل Gemini: صفوف {no, villa, area, type, floor, p1, p2, p3, mo, booked, note, inArea}
  /// وأول صف فيه كمان kind / terms. ولو مش واثق: null
  static List<Obj>? parse(List els0) {
    final els = els0.whereType<Map>().map(El.of).where((e) => e.s.trim().isNotEmpty && e.h > 0).toList();
    if (els.length < 8) return null;
    final hs = els.map((e) => e.h).toList()..sort();
    final h = hs[hs.length ~/ 2];
    final lines = _lines(els, h);
    final all = lines.map(_txt).join('\n').toLowerCase();

    // ===== صفوف العناوين (ممكن تبقى على سطرين زي ONE / PAYMENT) =====
    final heads = <({double top, double bot, List<_Col> cols, List<El> els})>[];
    for (var i = 0; i < lines.length; i++) {
      var hl = [...lines[i]];
      bool headish(List<El> l) => l.where((e) => _kind(e.t).isNotEmpty || RegExp(r'^(one|two|three|[1-4]|payments?|no\.?|/|&)$').hasMatch(e.t)).length >= l.length * .6;
      if (i + 1 < lines.length && (lines[i + 1].first.cy - lines[i].first.cy) < h * 2.2 && headish(lines[i]) && headish(lines[i + 1])) hl = [...hl, ...lines[i + 1]];
      final kinds = hl.map((e) => _kind(e.t)).where((k) => k.isNotEmpty).toSet();
      if (kinds.length < 3 || !kinds.contains('pay') || !(kinds.contains('no') || kinds.contains('type'))) continue;
      final cols = <_Col>[];
      for (final e in hl) {
        final k = _kind(e.t);
        if (k.isEmpty) continue;
        var pay = '';
        if (k == 'pay') {
          final tt = e.t.replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (RegExp(r'month').hasMatch(tt)) { pay = 'mo'; } else if (RegExp(r'year|annual').hasMatch(tt)) { pay = '1'; } else {
            final d = RegExp(r'^(\d)').firstMatch(tt)?.group(1);
            if (d != null) { pay = d; } else {
              // الرقم/الكلمة اللي قبل Payment (على نفس السطر شمال، أو فوقها)
              final q = els.where((o) => o != e && ((o.cy - e.cy).abs() < h * .6 && o.x < e.x && e.x - (o.x + o.w) < h * 1.5 || (o.cx - e.cx).abs() < e.w * .8 && o.cy < e.cy && e.cy - o.cy < h * 2.5)).map((o) => o.t).join(' ');
              pay = RegExp(r'\b(one|1)\b').hasMatch(q) ? '1' : RegExp(r'\b(two|2)\b').hasMatch(q) ? '2' : RegExp(r'\b(three|3)\b').hasMatch(q) ? '3' : '1';
            }
          }
        }
        // كلمتين لنفس العمود (UNIT NO. / APARTMENT DETAILS) → عمود واحد
        final same = cols.where((c) => c.kind == k && (k != 'pay' || c.pay == pay) && (c.cx - e.cx).abs() < h * 6).firstOrNull;
        if (same != null) { same.cx = (same.cx * same.n + e.cx) / (same.n + 1); same.n++; } else { cols.add(_Col(k, e.cx, pay)); }
      }
      if (!cols.any((c) => c.kind == 'no')) continue; // من غير عمود رقم الشقة منقدرش نقسم الصفوف
      cols.sort((a, b) => a.cx.compareTo(b.cx));
      final top = hl.map((e) => e.y).reduce(math.min), bot = hl.map((e) => e.y + e.h).reduce(math.max);
      if (heads.isNotEmpty && top < heads.last.bot + h) continue; // نفس العنوان (السطر التاني)
      heads.add((top: top, bot: bot, cols: cols, els: hl));
    }
    if (heads.isEmpty) return null;

    String near(double y, double after, bool Function(String) ok) {
      for (final l in lines.reversed) {
        final ly = l.first.cy;
        if (ly >= y || ly <= after) continue;
        final t = _txt(l);
        if (ok(t.toLowerCase())) return t;
      }
      return '';
    }

    final globalVilla = lines.map(_txt).where((t) => _villaRx.hasMatch(t.toLowerCase())).firstOrNull ?? '';
    final rows = <Obj>[];
    var prevBot = -1.0;
    for (var hi = 0; hi < heads.length; hi++) {
      final hd = heads[hi];
      final end = hi + 1 < heads.length ? heads[hi + 1].top : double.infinity;
      final cols = hd.cols;
      double colEdge(int i, bool left) => i == 0 && left ? -1e9 : (i == cols.length - 1 && !left ? 1e9 : (left ? (cols[i - 1].cx + cols[i].cx) / 2 : (cols[i].cx + cols[i + 1].cx) / 2));
      _Col colOf(El e) { for (var i = 0; i < cols.length; i++) { if (e.cx >= colEdge(i, true) && e.cx < colEdge(i, false)) return cols[i]; } return cols.last; }
      final noCol = cols.firstWhere((c) => c.kind == 'no');
      final region = els.where((e) => e.y > hd.bot - h * .2 && e.cy < end && !hd.els.contains(e)).toList();
      // كل رقم شقة في عمود NO = صف
      final anchors = region.where((e) => colOf(e) == noCol && RegExp(r'^#?0*\d{1,3}[a-z]?$').hasMatch(e.t.replaceAll(RegExp(r'[^a-z0-9#]'), ''))).toList()..sort((a, b) => a.cy.compareTo(b.cy));
      // نسيب الأرقام اللي بعيد أوي عن الجدول (تحت آخر صف بكتير)
      final good = <El>[];
      for (final a in anchors) { if (good.isNotEmpty && a.cy - good.last.cy > h * 9) break; if (good.isEmpty || a.cy - good.last.cy > h * .6) good.add(a); }
      if (good.isEmpty) continue;
      final villaT = near(hd.top, prevBot, (t) => _villaRx.hasMatch(t));
      final villa = villaT.isNotEmpty ? villaT : globalVilla;
      final areaT = near(hd.top, -1, (t) => _cityRx.hasMatch(t));
      final at = '$villa $areaT'.toLowerCase();
      final bool? inArea = RegExp(r'riyad|riyadh|reyad|madinat al riy').hasMatch(at) ? true : (RegExp(r'shamkha|shakhb|mbz|khalifa|bani|yas|mussafah|mohammed bin zayed').hasMatch(at) ? false : null);
      final area = areaT.isEmpty ? '' : (RegExp(r'(madinat al riy\w*|riy\w* city|riyadh|shamkha \w*|shakhb\w* city|mbz city|khalifa city|bani yas)', caseSensitive: false).firstMatch(areaT)?.group(0) ?? areaT);
      for (var i = 0; i < good.length; i++) {
        final a = good[i];
        final y0 = i == 0 ? hd.bot : (good[i - 1].cy + a.cy) / 2, y1 = i + 1 < good.length ? (a.cy + good[i + 1].cy) / 2 : math.min(end, a.cy + h * 3);
        // خانة بتعدي على أكتر من عمود (زي «First floor 38000») ترجع كلمات منفصلة
        final band = _chunks(region.where((e) => e.cy >= y0 && e.cy < y1).toList(), h).expand((c) => c.parts.isNotEmpty && cols.where((k) => k.cx >= c.x && k.cx <= c.x + c.w).length >= 2 ? c.parts : [c]).toList();
        final cells = <_Col, List<El>>{};
        for (final e in band) { cells.putIfAbsent(colOf(e), () => []).add(e); }
        String cell(_Col c) => _txt(cells[c] ?? const <El>[]);
        final rowTxt = _txt(band);
        final r = <String, dynamic>{'no': a.s.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').replaceFirst(RegExp(r'^0+(?=\d)'), ''), 'villa': villa, 'area': area, 'inArea': inArea};
        final tc = cols.where((c) => c.kind == 'type').map(cell).join(' ');
        r['type'] = _type('$tc ${cols.where((c) => c.kind == 'rem').map(cell).join(' ')}');
        if (r['type'] == '') r['type'] = _type(rowTxt);
        r['floor'] = _floor(cols.where((c) => c.kind == 'floor').map(cell).join(' '));
        for (final c in cols.where((c) => c.kind == 'pay')) {
          final k = c.pay == 'mo' ? 'mo' : 'p${c.pay}';
          final v = _num(cell(c));
          if (v > 0 && numOf(r[k]) == 0) r[k] = c.pay == 'mo' && v >= 1000 * 1000 ? v / 1000 : v;
        }
        if (numOf(r['mo']) >= 20000) r['mo'] = 0; // شهري مش منطقي
        r['booked'] = RegExp(r'rented|booked|booking|occupied|not available|sold|محجوز').hasMatch(rowTxt.toLowerCase());
        final note = [cols.where((c) => c.kind == 'rem').map(cell).join(' '), if (r['floor'] == '') cols.where((c) => c.kind == 'floor').map(cell).join(' ')].join(' ').trim();
        if (note.isNotEmpty && !RegExp(r'^[-–—_\s.]+$').hasMatch(note)) r['note'] = note;
        if (RegExp(r'furnished').hasMatch(rowTxt.toLowerCase()) && !RegExp(r'unfurnished').hasMatch(rowTxt.toLowerCase())) r['fur'] = true;
        rows.add(r);
      }
      prevBot = good.last.cy + h;
    }
    if (rows.isEmpty) return null;
    // ثقة: كل صف ليه نوع وسعر (أو محجوز)، وأرقام الشقق مش مكررة في نفس الفيلا
    final ok = rows.where((r) => str(r['type']).isNotEmpty && (r['booked'] == true || ['p1', 'p2', 'p3', 'mo'].any((k) => numOf(r[k]) > 0))).length;
    final keys = rows.map((r) => '${r['villa']}|${r['no']}').toList();
    if (ok < rows.length * .7 || keys.toSet().length < keys.length) return null;
    rows.first['kind'] = RegExp(r'new price|price drop|offer price|price update').hasMatch(all) ? 'price' : 'list';
    final terms = lines.map(_txt).where((t) => RegExp(r'deposit|contract fee|fees|commission', caseSensitive: false).hasMatch(t)).take(3).join(' • ');
    if (terms.isNotEmpty) rows.first['terms'] = terms.length > 160 ? terms.substring(0, 160) : terms;
    return rows;
  }
}
