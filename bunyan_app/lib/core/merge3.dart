/// دمج تلات اتجاهات زي بنيان القديم بالظبط: لو الموبايل والسحابة اتعدلوا الاتنين، بندمج بدل ما نسخة تمسح التانية
import 'js.dart';

String H(dynamic x) {
  final s = jsonOut(x);
  var h = 5381;
  for (final c in s.codeUnits) { h = ((h << 5) + h + c) & 0xFFFFFFFF; }
  return '${h.toRadixString(36)}:${s.length}';
}
bool isIdArr(dynamic v) => v is List && v.isNotEmpty && v.every((x) => x is Map && x['id'] != null);
Map<String, dynamic> sig(Map<String, dynamic> st) {
  final o = <String, dynamic>{};
  st.forEach((k, v) {
    if (isIdArr(v)) { final m = <String, dynamic>{}; for (final x in v as List) { m[str(x['id'])] = H(x); } o[k] = {'__ids': m}; }
    else { o[k] = H(v); }
  });
  return o;
}

class MergeResult { final Map<String, dynamic> s; final int l, r, both; MergeResult(this.s, this.l, this.r, this.both); }

MergeResult? merge3(Map<String, dynamic> L, Map<String, dynamic> R, bool newerL, Map<String, dynamic>? B) {
  if (B == null) return null;
  final out = <String, dynamic>{}; var nl = 0, nr = 0, nb = 0;
  final keys = <String>{...L.keys, ...R.keys};
  for (final k in keys) {
    final l = L[k], r = R[k], b = B[k];
    final bIds = b is Map && b['__ids'] != null;
    if ((isIdArr(l) || isIdArr(r) || bIds) && (l == null || l is List) && (r == null || r is List)) {
      final bi = bIds ? (b['__ids'] as Map) : {};
      final lm = <String, dynamic>{}, rm = <String, dynamic>{};
      for (final x in (l as List? ?? [])) { lm[str(x['id'])] = x; }
      for (final x in (r as List? ?? [])) { rm[str(x['id'])] = x; }
      final res = <dynamic>[]; final seen = <String>{};
      dynamic pick(String id) {
        final x = lm[id], y = rm[id], bh = bi[id];
        if (x != null && y != null) {
          final hx = H(x), hy = H(y);
          if (hx == hy) return y; if (hx == bh) { nr++; return y; } if (hy == bh) { nl++; return x; }
          nb++; return newerL ? x : y;
        }
        if (x != null) { if (bh == null) { nl++; return x; } if (H(x) == bh) { nr++; return null; } nl++; return x; }
        if (y != null) { if (bh == null) { nr++; return y; } if (H(y) == bh) { nl++; return null; } nr++; return y; }
        return null;
      }
      for (final y in (r as List? ?? [])) { final id = str(y['id']); final v = pick(id); seen.add(id); if (v != null) res.add(v); }
      for (final x in (l as List? ?? [])) { final id = str(x['id']); if (seen.contains(id)) continue; final v = pick(id); if (v != null) res.add(v); }
      if (k == 'hist') res.sort((a, c) => n0(c['t']).compareTo(n0(a['t'])));
      out[k] = res; continue;
    }
    // ناقص (undefined في JS) غير null
    final hl = H(L.containsKey(k) ? l : null), hr = H(R.containsKey(k) ? r : null);
    bool useR;
    if (hl == hr) { useR = true; } else if (hl == b) { nr++; useR = true; } else if (hr == b) { nl++; useR = false; } else { nb++; useR = !newerL; }
    if (useR) { if (R.containsKey(k)) out[k] = r; } else { if (L.containsKey(k)) out[k] = l; }
  }
  return MergeResult(out, nl, nr, nb);
}
