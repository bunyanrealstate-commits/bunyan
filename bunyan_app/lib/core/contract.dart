/// عقد العميل — نفس disp/ctFill/upd في بنيان القديم: بنحدّث الخانات [data-f] جوه نص العقد المحفوظ (S.ct.html)
import 'dart:math' as math;
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
    if (k == 'chq' && n0(f['cq']) > 0) return chqTxt(f, en);
    if (k == 'pc') { final n = lst(f['pays']).length; return n == 0 ? '' : (en ? (n == 1 ? '1 Payment' : '$n Payments') : (n == 1 ? 'دفعة واحدة' : n == 2 ? 'دفعتين' : n >= 11 ? '$n دفعة' : '$n دفعات')); }
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
  static String endOf(String st, dynamic mo) { final m = (double.tryParse('$mo') ?? 0).round(); if (st.isEmpty || m == 0) return ''; return iso(pd(addMon(st, m)).subtract(const Duration(days: 1))); }

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

  /* ═════════ نفس عقد العميل في القديم بالظبط: مفروش / فاضي، 3 أشكال للفاضي، التوقيعات، المراجعة ═════════ */
  /// طريقة الإيجار: m = شهري، p = دفعات (افتراضي: المفروش وTenant Contract شهري، الفاضي دفعات)
  static String rm(Obj S) { final v = str(F(S)['rm']); if (v == 'm' || v == 'p') return v; return 'm'; }
  /// نص الشيكات من العدد اللي انت حددته (+ شيك تأمين لو مختاره)
  static String chqTxt(Map f, bool en) {
    final n = n0(f['cq']).round(); final d = truthy(f['cqd']);
    if (en) return '${n == 1 ? '1 Cheque' : '$n Cheques'}${d ? ' + 1 Security Deposit Cheque' : ''}';
    return '${n == 1 ? 'شيك واحد' : n == 2 ? 'شيكين' : n >= 11 ? '$n شيك' : '$n شيكات'}${d ? ' + شيك تأمين' : ''}';
  }
  static String tpl(Obj S) => ct(S)['tpl'] == 'b' ? 'b' : 'a';
  static String lay(Obj S) => 'tc'; // العقد الفاضي دايماً صفحة واحدة
  static bool en(Obj S) => ct(S)['lang'] == 'en';
  static String sp(Obj S, String k, Map f) => '<span class="fv" data-f="$k">${esc(disp(S, k, f))}</span>';

  /// لغة العقد: ar = عربي بس، en = English بس، bi = الاتنين جنب بعض
  static String cl(Obj S) { final v = str(ct(S)['cl']); return v == 'ar' || v == 'en' ? v : 'bi'; }
  static const _faEn = ['Family Housing Only', 'The contract includes water, electricity, and maintenance.', 'If the contract is canceled before the end of its term by the tenant, one month will be deducted from it.', 'The tenant must notify the landlord in the event of non-renewal one month before the end of the contract.', 'The security deposit will be refunded if the property is returned in good condition.', 'Any damage or insufficient cleaning will be deducted from the security deposit or paid in cash upon check-out.', 'The tenant must vacate the apartment on the lease end date. A late checkout fee of AED 300 per day will apply for any delay.'];
  static const _faAr = ['السكن عائلي فقط.', 'العقد شامل المياه والكهرباء والصيانة.', 'في حالة إلغاء العقد قبل انتهاء مدته من قبل المستأجر يتم خصم إيجار شهر عليه.', 'يجب على المستأجر إخطار المؤجر في حالة عدم التجديد قبل نهاية العقد بشهر.', 'يسترد المستأجر شيك التأمين في حالة تسليم السكن في حالة جيدة.', 'في حالة وجود أي تلفيات في الفرش أو الأجهزة أو ترك المكان بدون تنظيف تام كما تم تسليمه للعميل، تقدّر التلفيات ويخصم من شيك التأمين أو يدفع كاش في وقت الخروج من المكان.', 'في حالة إخلاء الشقة يتعهد المستأجر بالإخلاء في نفس يوم تاريخ الانتهاء، وفي حالة تأخر الإخلاء عن الموعد المحدد يتحمل المستأجر 300 درهم عن كل يوم غرامة تأخير.'];

  /// ورقة العقد (صفحة واحدة) بلغة العقد المختارة — rows: [English, key, عربي]؛ key = '@dates' لصف التواريخ
  static String _doc(Obj S, Map f, {required String tEn, required String tAr, required List<List<String>> rows, required List<String> termsEn, required List<String> termsAr, required String cls}) {
    final L = cl(S), mode = _mode(S, f);
    final pay = rm(S) == 'p';
    final b = StringBuffer('<div class="fr t2c $cls${L == 'bi' ? '' : ' $L'}" data-m="$mode">');
    if (L == 'bi') {
      b.write('<h1>$tEn<small>$tAr</small></h1><table>');
      for (final r in rows) {
        if (r[1] == '@dates') { b.write('<tr><td class="en" rowspan="2">${r[0]}</td><td class="en" style="width:13%">Start</td><td style="width:24%">${sp(S, 'st', f)}</td><td style="width:14%">بداية العقد</td><td class="ar" rowspan="2">${r[2]}</td></tr><tr><td class="en">End</td><td>${sp(S, 'en', f)}</td><td>نهاية العقد</td></tr>'); continue; }
        b.write('<tr><td class="en">${r[0]}</td><td colspan="3">${sp(S, r[1], f)}</td><td class="ar">${r[2]}</td></tr>');
      }
      b.write('</table>${pay ? _ptbBi(S, f) : ''}<h2>Contract Terms &nbsp; بنود العقد</h2><table class="tc2">');
      for (var i = 0; i < termsEn.length; i++) { b.write('<tr><td class="te">${i + 1}. ${termsEn[i]}</td><td class="ta">${i + 1}. ${termsAr[i]}</td></tr>'); }
      b.write('</table>$_sg</div>');
      return b.toString();
    }
    final e = L == 'en';
    b.write('<h1>${e ? tEn : tAr}</h1><table class="kv">');
    for (final r in rows) {
      if (r[1] == '@dates') { b.write('<tr><td class="k" rowspan="2">${e ? r[0] : r[2]}</td><td class="k2">${e ? 'Start Date' : 'بداية العقد'}</td><td>${sp(S, 'st', f)}</td></tr><tr><td class="k2">${e ? 'End Date' : 'نهاية العقد'}</td><td>${sp(S, 'en', f)}</td></tr>'); continue; }
      b.write('<tr><td class="k">${e ? r[0] : r[2]}</td><td colspan="2">${sp(S, r[1], f)}</td></tr>');
    }
    b.write('</table>');
    if (pay) b.write('<h2>${e ? 'Payments Schedule' : 'جدول الدفعات'}</h2><table class="ptb">${_ptb(S, f, e ? const {'pn': 'Payment No.', 'pa': 'Amount', 'pd': 'Due Date', 'pm': 'Payment Method'} : const {'pn': 'رقم الدفعة', 'pa': 'المبلغ', 'pd': 'تاريخ الاستحقاق', 'pm': 'طريقة الدفع'})}</table>');
    final tl = e ? termsEn : termsAr;
    b.write('<h2>${e ? 'Contract Terms' : 'بنود العقد'}</h2><table class="tc2">');
    for (var i = 0; i < tl.length; i++) { b.write('<tr><td class="${e ? 'te' : 'ta'}">${i + 1}. ${tl[i]}</td></tr>'); }
    b.write('</table><div class="sg">${e ? '<div>Witness</div><div>Witness</div><div>Tenant Signature</div><div>Landlord Signature</div>' : '<div>الشاهد</div><div>الشاهد</div><div>توقيع المستأجر</div><div>توقيع المؤجر</div>'}</div></div>');
    return b.toString();
  }

  static String _mode(Obj S, Map f) => '${rm(S)}|${tpl(S)}|${cl(S)}|${en(S)}|${lst(f['pays']).length}|${truthy(f['dep'])}';
  static List<List<String>> _money(Obj S) => rm(S) == 'p'
      ? const [['Total Rent', 'tot', 'إجمالي الإيجار'], ['Payments', 'pc', 'الدفعات']]
      : const [['Total Rent', 'tot', 'إجمالي الإيجار'], ['Monthly Rent', 'mr', 'الإيجار الشهري']];

  /// 🛋️ عقد مفروش
  static String paperA(Obj S, Map f) => _doc(S, f, tEn: 'Tenancy Contract', tAr: 'عقد إيجار', cls: 'fa', termsEn: _faEn, termsAr: _faAr, rows: [
        ['Landlord Name', 'll', 'اسم المؤجر'], ['Landlord ID', 'lid', 'رقم هوية المؤجر'], ['Tenant Name', 'tn', 'اسم المستأجر'], ['Tenant ID', 'tid', 'رقم هوية المستأجر'], ["Tenant's Nationality", 'nat', 'جنسية المستأجر'], ['Tenant Mobile No.', 'ph', 'رقم موبايل المستأجر'], ['Tenancy Subject', 'sub', 'موضوع الإيجار'],
        ['Contract Period', 'mo', 'مدة العقد'], ['Tenancy Dates', '@dates', 'تاريخ الإيجار'], ..._money(S), ['Cheques', 'chq', 'عدد الشيكات'],
      ]);

  static const _sg = '<div class="sg"><div>Witness<small>الشاهد</small></div><div>Witness<small>الشاهد</small></div><div>Tenant Signature<small>توقيع المستأجر</small></div><div>Landlord Signature<small>توقيع المؤجر</small></div></div>';
  static const _ta = ['السكن عائلي فقط', 'العقد شامل المياة والكهرباء والصيانة', 'في حالة إلغاء العقد قبل انتهاء مدته من قبل المستأجر يتم خصم شهر عليه .', 'يجب علي المستأجر اخطار المؤجر في حالة عدم التجديد قبل نهاية العقد بشهر'];
  static const _tb = ['يسترد المستأجر شيك التأمين في حالة تسليم السكن في حالة جيده', 'في حالة وجود أي تلفيات في الشقة كما تم تسليمها للعميل، تقدر التلفيات ويخصم من شيك التأمين أو يدفع كاش في وقت الخروج من المكان .', 'في حالة إخلاء الشقة يتعهد المستأجر بالإخلاء في نفس يوم تاريخ الانتهاء وفي حالة تأخر الإخلاء عن الموعد المحدد يتحمل المستأجر 300 درهم عن كل يوم غرامة تأخير .'];
  static const _tcEn = ['Family accommodation only.', 'Rent includes water, electricity, and maintenance.', "In case of early termination by the tenant, a penalty equal to one month's rent will be applied.", 'The tenant must notify the landlord at least one month before the contract expiry if not renewing.', 'The security deposit cheque will be returned if the property is handed over in good condition.', 'Any damages will be assessed and deducted from the security deposit or paid in cash upon vacating.', 'The tenant must vacate on the expiry date; a penalty of AED 300 per day applies for any delay.'];
  static String _ptb(Obj S, Map f, Map<String, String> L) {
    final P = lst(f['pays']); var h = '<tr><td>${L['pn']}</td><td>${L['pa']}</td><td>${L['pd']}</td><td>${L['pm']}</td></tr>';
    for (var i = 0; i < (P.isEmpty ? 1 : P.length); i++) { h += '<tr><td>${i + 1}</td><td>${sp(S, 'pay_${i}_a', f)}</td><td>${sp(S, 'pay_${i}_d', f)}</td><td>${sp(S, 'pay_${i}_m', f)}</td></tr>'; }
    return h;
  }
  static String _ptbBi(Obj S, Map f) => '<h2>Payments Schedule &nbsp; جدول الدفعات</h2><table class="ptb">${_ptb(S, f, const {'pn': 'Payment No. / رقم الدفعة', 'pa': 'Amount / المبلغ', 'pd': 'Due Date / تاريخ الاستحقاق', 'pm': 'Payment Method / طريقة الدفع'})}</table>';
  /// 🏠 عقد فاضي — صفحة واحدة (Tenant Contract) بلغة العقد المختارة
  static String paperB(Obj S, Map f) {
    final ar = [..._ta, ..._tb].map((x) => x.replaceAll(RegExp(r'\s*\.$'), '')).toList();
    return _doc(S, f, tEn: 'Tenant Contract', tAr: 'عقد إيجار', cls: 'fb', termsEn: _tcEn, termsAr: ar, rows: [
      ['Landlord', 'll', 'المؤجر'], ['Landlord ID', 'lid', 'رقم هوية المؤجر'], ['Tenant Name', 'tn', 'اسم المستأجر'], ['Tenant ID', 'tid', 'رقم هوية المستأجر'], ['Nationality', 'nat', 'الجنسية'], ['Mobile', 'ph', 'رقم الموبايل'], ['Tenancy Subject', 'sub', 'موضوع الإيجار'],
      ['Contract Period', 'mo', 'مدة العقد'], ['Tenancy Dates', '@dates', 'تاريخ الإيجار'], ..._money(S), ['Cheques', 'chq', 'عدد الشيكات'], if (truthy(f['dep'])) ['Security Deposit', 'dep2', 'التأمين'],
    ]);
  }

  /// الورقة الحالية: المحفوظة (بتعديلاتك من القديم) لو تنفع للشكل ده، وإلا بتتعمل من النموذج
  static String paper(Obj S) {
    final c = ct(S); var h = str(c['html']); final f = F(S);
    final mode = _mode(S, f);
    if (!h.contains('data-m="$mode"')) { h = tpl(S) == 'b' ? paperB(S, f) : paperA(S, f); c['html'] = h; }
    return refresh(S, h);
  }

  /// التبديل بين المفروش والفاضي — كل واحد بيحتفظ بورقته وبياناته ولغته (ctTpl)
  static void switchTpl(Obj S, String t) {
    final c = ct(S); final o = tpl(S); if (t == o) return;
    c['h_$o'] = str(c['html']); c['tpl'] = t; c['html'] = str(c['h_$t']);
    c['f_$o'] = jsonCopy(F(S)); if (c['f_$t'] is Map) c['f'] = jsonCopy(c['f_$t']);
    c['lang_$o'] = c['lang'] ?? 'ar'; if (c['lang_$t'] != null) c['lang'] = c['lang_$t'];
    if (t == 'b') { final f = F(S); if (lst(f['pays']).isEmpty) autoPays(S); if (!truthy(f['dep']) && truthy(f['rent'])) f['dep'] = f['rent']; if (!truthy(f['tot']) && truthy(f['rent']) && truthy(f['mo'])) f['tot'] = (n0(f['rent']) * n0(f['mo'])).round(); }
  }
  static dynamic jsonCopy(dynamic v) => v is Map ? {for (final e in v.entries) '${e.key}': jsonCopy(e.value)} : v is List ? [for (final x in v) jsonCopy(x)] : v;

  /// إضافة شهور من غير ما يفيض لشهر بعده (31 أكتوبر + 4 شهور = 28 فبراير مش 3 مارس)
  static String addMon(String st, int m) { final d = pd(st); final last = DateTime(d.year, d.month + m + 1, 0).day; return iso(DateTime(d.year, d.month + m, math.min(d.day, last))); }
  /// عدد شهور العقد من البداية للنهاية (31/10/2026 ← 30/10/2027 = 12)
  static int spanMonths(String st, String en) {
    if (st.isEmpty || en.isEmpty) return 0; final a = pd(st), b = pd(en).add(const Duration(days: 1));
    var m = (b.year - a.year) * 12 + (b.month - a.month); if (b.day < a.day && DateTime(b.year, b.month + 1, 0).day != b.day) m--; return math.max(1, m);
  }
  /// 🧮 وزّع الإجمالي على عدد الدفعات بالتساوي، والتواريخ على مدة العقد من البداية للنهاية
  static void autoPays(Obj S) {
    final f = F(S); final n = (n0(f['pn']) > 0 ? n0(f['pn']) : (lst(f['pays']).isNotEmpty ? lst(f['pays']).length : 3)).round().clamp(1, 24);
    final st = str(f['st']), sp = spanMonths(st, str(f['en']));
    final mo = sp > 0 ? sp : (n0(f['mo']) > 0 ? n0(f['mo']).round() : 12);
    final T = n0(f['tot']) > 0 ? n0(f['tot']) : n0(f['rent']) * mo;
    final each = (T / n / 100).round() * 100.0; // مقرّب لأقرب 100، والفرق على آخر دفعة
    final old = lst(f['pays']);
    f['pn'] = n;
    f['pays'] = [for (var i = 0; i < n; i++) {
      'a': (i < n - 1 ? each : T - each * (n - 1)).round(),
      'd': st.isEmpty ? '' : addMon(st, (i * mo / n).round()),
      'm': i < old.length && str(obj(old[i])?['m']).isNotEmpty ? str(obj(old[i])?['m']) : (i == 0 ? 'تحويل' : 'شيك'),
    }];
  }

  static const _need = [['tn', 'اسم المستأجر'], ['tid', 'رقم هوية المستأجر'], ['ph', 'موبايل المستأجر'], ['sub', 'موضوع الإيجار'], ['st', 'من تاريخ'], ['en', 'إلى تاريخ'], ['rent', 'قيمة الإيجار'], ['mo', 'عدد الأشهر'], ['ll', 'اسم المؤجر']];
  /// ⚠️ ناقص في العقد
  static List<String> missing(Obj S) {
    final f = F(S); bool emp(String k) => str(f[k]).trim().isEmpty;
    final base = [for (final x in _need) if (!['rent'].contains(x[0]) && emp(x[0])) x[1]];
    if (rm(S) == 'm') return [...base, if (emp('rent')) 'الإيجار الشهري'];
    return [...base, if (emp('tot')) 'إجمالي الإيجار', if (!lst(f['pays']).any((p) => n0(obj(p)?['a']) > 0)) 'جدول الدفعات'];
  }

  static bool _luhn(String s) { final d = s.replaceAll(RegExp(r'\D'), ''); if (d.length < 8) return true; var t = 0; for (var i = 0; i < d.length; i++) { var x = int.parse(d[d.length - 1 - i]); if (i % 2 == 1) { x *= 2; if (x > 9) x -= 9; } t += x; } return t % 10 == 0; }
  /// 🔎 راجع في العقد (ctIssues)
  static List<String> issues(Obj S) {
    final f = F(S); final o = <String>[]; final e = en(S);
    try { if (truthy(f['st']) && truthy(f['mo']) && truthy(f['en'])) { final w = endOf(str(f['st']), f['mo']); if (w != str(f['en'])) o.add('تاريخ النهاية ${f['en']} مش مظبوط مع ${n0(f['mo']).round()} شهر من ${f['st']} — المفروض $w'); } } catch (_) {}
    try { if (truthy(f['st']) && truthy(f['due'])) { final sd = pd(f['st']).day, want = sd == 1 ? 31 : sd - 1; if (n0(f['due']).round() != want) o.add('يوم الدفع ${f['due']} — المفروض يوم ${want == 31 ? 'آخر الشهر' : want} (قبل يوم البداية بيوم)'); } } catch (_) {}
    for (final q in [['tid', 'رقم هوية المستأجر'], ['lid', 'رقم هوية المؤجر']]) { final v = str(f[q[0]]); final dg = v.replaceAll(RegExp(r'\D'), ''); if (dg.startsWith('784') && (dg.length != 15 || !_luhn(dg))) o.add('${q[1]} $v فيه رقم غلط (رقم هوية الإمارات 15 رقم وآخر رقم للتأكيد مش راكب)'); }
    for (final q in [['tn', 'اسم المستأجر'], ['ll', 'اسم المؤجر']]) { final v = str(f[q[0]]).trim(); if (v.isEmpty) continue;
      if (e && RegExp('[؀-ۿ]').hasMatch(v)) o.add('${q[1]} بالعربي والعقد إنجليزي');
      if (!e && q[0] == 'tn' && RegExp(r"^[A-Za-z\s.'-]+$").hasMatch(v)) o.add('${q[1]} بالإنجليزي والعقد عربي'); }
    final ph = str(f['ph']).replaceAll(RegExp(r'\D'), '');
    if (ph.startsWith('971') && ph.length != 12) o.add('موبايل المستأجر ${f['ph']} ناقص أو زيادة (رقم الإمارات 12 رقم مع 971)');
    if (ph.isNotEmpty && ph.length < 8) o.add('موبايل المستأجر قصير');
    return o;
  }

  static String dmy([DateTime? d]) { d ??= DateTime.now(); return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'; }
  /// التوقيعات المحفوظة للمؤجر (S.sigs)
  static List<Obj> sigs(Obj S) { if (S['sigs'] is! List) S['sigs'] = <dynamic>[]; return objs(S['sigs']); }
  static String? landlordSig(Obj S) { final id = str(ct(S)['sig']); if (id.isEmpty) return null; return str(sigs(S).where((x) => x['id'] == id).firstOrNull?['img']).isEmpty ? null : str(sigs(S).where((x) => x['id'] == id).firstOrNull?['img']); }

  /// الورقة النهائية للـ PDF: تاريخ العقد تحت العنوان + التوقيعات في خاناتها
  static String finalHtml(Obj S, {bool withSig = true}) {
    var h = paper(S); final c = ct(S);
    if (!truthy(c['d'])) c['d'] = dmy();
    h = h.replaceAll(RegExp(r'<div class="ctdate">.*?</div>'), ''); // تاريخ العقد اتشال من الورقة (أسامه: «امسح دي»)
    h = h.replaceAll(RegExp(r'<img class="ct[tw]?sig\d?"[^>]*>'), '');
    if (!withSig) return h;
    final W = obj(c['wsig']) ?? {}; final imgs = [str(W['1']), str(W['2']), str(c['tsig']), landlordSig(S) ?? ''];
    final m = RegExp(r'(<div class="sg"[^>]*>)(.*?)</div></div>', dotAll: true).firstMatch(h); if (m == null) return h;
    var i = 0;
    final inner = m[2]!.replaceAllMapped(RegExp(r'<div(\s[^>]*)?>'), (x) { final src = i < 4 ? imgs[i] : ''; i++; return src.isEmpty ? x[0]! : '${x[0]}<img class="ctsig" src="$src">'; });
    return h.replaceRange(m.start, m.end, '${m[1]}$inner</div></div>');
  }

  /// ➕ عقد جديد: بيمسح بيانات العميل ويسيب المؤجر والتوقيع والشكل
  static void newContract(Obj S) {
    final c = ct(S), f = F(S);
    S['ct'] = {'sig': c['sig'] ?? '', 'lang': c['lang'] ?? 'ar', 'tpl': c['tpl'] ?? 'a', 'lay': c['lay'], 'd': dmy(),
      'f': {'ll': f['ll'] ?? '', 'lid': f['lid'] ?? '', 'nat': '', 'tn': '', 'tid': '', 'ph': '', 'sub': f['sub'] ?? '', 'st': '', 'en': '', 'due': '', 'rent': '', 'mo': '', 'chq': '', 'cx': ''}, 'html': ''};
  }
}
