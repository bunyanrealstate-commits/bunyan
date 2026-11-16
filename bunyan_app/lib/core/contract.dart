/// عقد العميل — نفس disp/ctFill/upd في بنيان القديم: بنحدّث الخانات [data-f] جوه نص العقد المحفوظ (S.ct.html)
import 'js.dart';
import 'engine.dart';

class Ct {
  static const keys = ['ll', 'lid', 'tn', 'tid', 'nat', 'ph', 'sub', 'st', 'mo', 'en', 'due', 'rent', 'tot', 'chq', 'cx'];
  static const lb = {'ll': 'اسم المؤجر', 'lid': 'رقم هوية المؤجر', 'tn': 'اسم المستأجر', 'tid': 'رقم هوية المستأجر', 'nat': 'جنسية المستأجر', 'ph': 'موبايل المستأجر (واتساب)', 'sub': 'موضوع الإيجار (الاستديو والعنوان)', 'st': 'بداية العقد', 'en': 'نهاية العقد', 'due': 'يوم دفع الإيجار من كل شهر', 'rent': 'الإيجار الشهري (درهم)', 'mo': 'مدة العقد (شهور)', 'chq': 'الشيكات (زي ما هتتكتب في العقد)', 'cx': 'غرامة الإلغاء المبكر', 'tot': 'إجمالي الإيجار'};

  static Map<String, dynamic> ct(Obj S) { final c = S['ct']; if (c is Map<String, dynamic>) return c; final m = <String, dynamic>{}; S['ct'] = m; return m; }
  static Map<String, dynamic> F(Obj S) { final c = ct(S); final f = c['f']; if (f is Map<String, dynamic>) return f; final m = <String, dynamic>{'ll': 'عبد الحكيم أحمد عبد الحكيم أحمد الرفاعي', 'lid': '', 'nat': '', 'tn': '', 'tid': '', 'ph': '', 'sub': '', 'st': '', 'en': '', 'due': '', 'rent': '', 'mo': '', 'chq': '', 'cx': ''}; c['f'] = m; return m; }

  static String dm(String v) { final p = v.split('-'); return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : v; }
  static String nf(dynamic v) { final x = double.tryParse('$v') ?? 0; if (x == 0) return v == null ? '' : '$v'; final r = x == x.roundToDouble() ? x.toInt().toString() : x.toString(); final p = r.split('.'); return p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',') + (p.length > 1 ? '.${p[1]}' : ''); }

  static String disp(Obj S, String k, Map f) {
    final en = ct(S)['lang'] == 'en'; final v0 = f[k]; final v = v0 == null ? '' : '$v0';
    if (k == 'st' || k == 'en') return dm(v);
    if (k == 'due') return v.isEmpty || v == '0' ? '' : ((double.tryParse(v) ?? 0) >= 31 ? (en ? 'Last day of every month' : 'آخر يوم من كل شهر') : (en ? 'Day $v of every month' : 'يوم $v من كل شهر'));
    if (k == 'rent' || k == 'tot') return v.isEmpty || v == '0' ? '' : '${nf(v)}${en ? ' AED' : ' درهم'}';
    final pm = RegExp(r'^pay_(\d+)_([adm])$').firstMatch(k);
    if (pm != null) {
      final ps = lst(f['pays']); final i = int.parse(pm[1]!); final P = i < ps.length ? (obj(ps[i]) ?? {}) : <String, dynamic>{}; final w = pm[2];
      if (w == 'a') return truthy(P['a']) ? '${nf(P['a'])}${en ? ' AED' : ' درهم'}' : '';
      if (w == 'd') return truthy(P['d']) ? str(P['d']).replaceAll('-', '/') : '';
      const MM = {'تحويل': 'Transfer', 'شيك': 'Cheque', 'كاش': 'Cash', 'نقدي': 'Cash'};
      return en ? (MM[str(P['m'])] ?? str(P['m'])) : str(P['m']);
    }
    if (k == 'mr') { final dd = n0(f['due']); if (!truthy(f['rent'])) return ''; return en ? '${nf(f['rent'])} AED${dd != 0 ? ' – ${dd >= 31 ? 'Last Day Of Every Month' : 'Day ${dd.round()} Of Every Month'}' : ''}' : '${nf(f['rent'])} درهم${dd != 0 ? ' – ${dd >= 31 ? 'آخر يوم من كل شهر' : 'يوم ${dd.round()} من كل شهر'}' : ''}'; }
    if (k == 'dep2') return en ? '${f['depT'] == 'cash' ? 'Cash' : 'Cheque'}${truthy(f['dep']) ? ' of AED ${nf(f['dep'])}' : ''}' : '${f['depT'] == 'cash' ? 'كاش' : 'شيك'}${truthy(f['dep']) ? ' بقيمة ${nf(f['dep'])} درهم' : ''}';
    if (k == 'mo') { final m = double.tryParse(v) ?? 0; return v.isEmpty ? '' : (en ? (m == 1 ? '1 Month' : '$v Months') : (m == 1 ? 'شهر واحد' : m == 2 ? 'شهرين' : m >= 11 ? '$v شهر' : '$v أشهر')); }
    return v;
  }

  static String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  /// نفس upd(): كل span فيه data-f بياخد القيمة الجديدة
  static String refresh(Obj S, String html) {
    final f = F(S);
    return html.replaceAllMapped(RegExp(r'(<span[^>]*\bdata-f="([^"]+)"[^>]*>)(.*?)(</span>)', dotAll: true), (m) => '${m[1]}${esc(disp(S, m[2]!, f))}${m[4]}');
  }

  /// نهاية العقد (endOf في موديول العقد): بداية + شهور − يوم
  static String endOf(String st, dynamic mo) { final m = (double.tryParse('$mo') ?? 0).round(); if (st.isEmpty || m == 0) return ''; final d = pd(st); return iso(DateTime(d.year, d.month + m, d.day - 1)); }

  /// نفس ctFill: تعبئة من عقد مستأجر قائم
  static void fill(Obj S, Obj u, Obj L) {
    final f = F(S);
    f['tn'] = str(L['tenant']); f['ph'] = str(L['phone']); if (truthy(L['tid'])) f['tid'] = L['tid']; if (truthy(L['nat'])) f['nat'] = L['nat'];
    f['sub'] = 'إيجار استديو مفروش — ${str(u['name'])}'; f['st'] = str(L['start']); f['en'] = truthy(L['end']) ? str(L['end']) : endOf(str(L['start']), L['cmo']);
    f['due'] = L['day'] ?? ''; f['rent'] = L['rent'] ?? ''; f['mo'] = L['cmo'] ?? ''; f['cx'] = L['rent'] ?? '';
    final nc = lst(L['chq']).isNotEmpty ? lst(L['chq']).length : (n0(L['cmo'])).ceil();
    f['chq'] = '$nc شيكات شامل شيك تأمين بقيمة شهر';
    if (truthy(L['rent']) && truthy(L['cmo'])) f['tot'] = (n0(L['rent']) * n0(L['cmo'])).round();
    final ch = ct(S); if (str(ch['html']).isNotEmpty) ch['html'] = refresh(S, str(ch['html']));
  }

  static bool hasPaper(Obj S) => str(ct(S)['html']).contains('data-f=');
  static List<Map<String, dynamic>> leases(Obj S, Engine e) => [for (final u in e.SU()) for (final L in objs(u['leases'])) {'u': u, 'L': L}];
}
