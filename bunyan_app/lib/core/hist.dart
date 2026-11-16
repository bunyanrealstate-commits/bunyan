/// diff/applyUndo — نفس بنيان القديم بالظبط
import 'js.dart';

class Hist {
  static const _flat = ['cash', 'res', 'tp'], _arr = ['debts', 'recv', 'exp', 'tx', 'pn', 'groups', 'gc'];
  static List<Map<String, dynamic>> diff(Map a, Map b) {
    final ch = <Map<String, dynamic>>[]; String J(dynamic v) => jsonOut(v);
    for (final k in _flat) { if (J(a[k]) != J(b[k])) ch.add({'k': k, 'b': a[k], 'a': b[k]}); }
    for (final k in _arr) { if (J(a[k]) != J(b[k])) ch.add({'k': k, 'b': a[k] ?? [], 'a': b[k] ?? []}); }
    final ua = {for (final u in objs(a['units'])) str(u['id']): u}, ub = {for (final u in objs(b['units'])) str(u['id']): u};
    for (final id in {...ua.keys, ...ub.keys}) { if (J(ua[id]) != J(ub[id])) ch.add({'k': 'unit', 'id': id, 'b': ua[id], 'a': ub[id]}); }
    return ch;
  }
  static void applyUndo(List ch, Map<String, dynamic> st) {
    for (final c0 in ch) { final c = c0 as Map;
      if (c['k'] == 'unit') { final us = (st['units'] as List?) ?? (st['units'] = <dynamic>[]); final i = us.indexWhere((u) => u is Map && u['id'] == c['id']);
        if (c['b'] != null) { if (i >= 0) { us[i] = c['b']; } else { us.add(c['b']); } } else if (i >= 0) { us.removeAt(i); }
      } else { st[str(c['k'])] = c['b']; }
    }
  }
}
