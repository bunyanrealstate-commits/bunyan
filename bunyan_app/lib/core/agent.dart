import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai.dart';
import 'actions.dart';
import 'contract.dart';
import 'engine.dart';
import 'js.dart';
import 'store.dart';
import 'reminders.dart';

/// 🤖 نموذج بنيان: Gemini المجاني + أرقامك الحقيقية + طريقة شغلك + اللي علّمته له
/// بيجاوب، ويكتب واتساب، وينصح، وينفّذ (بعد ما توافق انت على كل حاجة)
class AgentAct {
  final String name; final Map<String, dynamic> args; final String desc; final String? err;
  final Future<String> Function()? run;
  String state = 'wait'; // wait | done | no | err
  String? result;
  AgentAct(this.name, this.args, this.desc, this.run, {this.err});
}

class AgentOut {
  final String text; final List<AgentAct> acts; final List<Map<String, String>> wa;
  AgentOut(this.text, this.acts, this.wa);
}

class Agent {
  static const models = ['gemini-2.5-flash', 'gemini-flash-latest', 'gemini-2.0-flash', 'gemini-2.5-flash-lite'];
  static Map<String, dynamic> get S => Store.I.S;

  /* ───── اللي اتعلمه (تصحيحاتك وقواعدك) ───── */
  static List<dynamic> get mem => (S['aimem'] is List) ? S['aimem'] as List : (S['aimem'] = <dynamic>[]);
  static Future<void> learn(String t) async { mem.add({'id': Act.uid(), 't': t.trim(), 'at': Act.td()}); await Store.I.save(log: '🧠 نموذج بنيان اتعلم: ${t.trim()}'); }

  static String _nz(String t) => t.toLowerCase().replaceAll(RegExp('[أإآ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي').replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  static double _sim(String a, String b) {
    a = _nz(a); b = _nz(b); if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1; if (a.contains(b) || b.contains(a)) return .9;
    final wa = a.split(' ').toSet(), wb = b.split(' ').toSet();
    return wa.intersection(wb).length / (wa.length > wb.length ? wa.length : wb.length) * .85;
  }
  static Obj? _unit(String q) {
    Obj? best; var bs = 0.0;
    for (final u in objs(S['units'])) { final s = [_sim(str(u['name']), q), ...objs(u['leases']).map((L) => _sim(str(L['tenant']), q) * .95)].reduce((a, b) => a > b ? a : b); if (s > bs) { bs = s; best = u; } }
    return bs >= .45 ? best : null;
  }
  static int _lease(Obj u, String tenant) {
    final ls = objs(u['leases']); if (ls.isEmpty) return -1;
    if (tenant.trim().isEmpty) { for (var k = ls.length - 1; k >= 0; k--) { if (!truthy(ls[k]['exit'])) return k; } return ls.length - 1; }
    var bk = -1; var bs = 0.0; for (var k = 0; k < ls.length; k++) { final s = _sim(str(ls[k]['tenant']), tenant); if (s > bs) { bs = s; bk = k; } }
    return bs >= .4 ? bk : -1;
  }
  static String _f(num v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

  /* ───── الأدوات اللي يقدر يستخدمها ───── */
  static const _tools = [
    {'name': 'rent_received', 'description': 'سجّل إن مستأجر دفع إيجار (استلام دفعة إيجار). لو مفيش شهر محدد → أقدم شهر مستحق مش مدفوع.', 'parameters': {'type': 'OBJECT', 'properties': {'unit': {'type': 'STRING', 'description': 'اسم الاستديو أو اسم المستأجر'}, 'tenant': {'type': 'STRING'}, 'month_date': {'type': 'STRING', 'description': 'YYYY-MM-DD تاريخ الدفعة لو اتقال (اختياري)'}, 'count': {'type': 'INTEGER', 'description': 'كام شهر دفع (افتراضي 1)'}}, 'required': ['unit']}},
    {'name': 'company_installment_paid', 'description': 'سجّل إن دفعة شركة (قسط الشركة صاحبة الاستديو) اتدفعت.', 'parameters': {'type': 'OBJECT', 'properties': {'unit': {'type': 'STRING'}, 'date': {'type': 'STRING', 'description': 'تاريخ القسط YYYY-MM-DD (اختياري: أقرب قسط مش مدفوع)'}, 'source': {'type': 'STRING', 'description': 'cash = من رصيد البرنامج، gp = من فلوس الشراكة، out = من بره البرنامج'}}, 'required': ['unit']}},
    {'name': 'add_expense', 'description': 'ضيف مصروف.', 'parameters': {'type': 'OBJECT', 'properties': {'what': {'type': 'STRING'}, 'amount': {'type': 'NUMBER'}, 'date': {'type': 'STRING', 'description': 'YYYY-MM-DD (افتراضي النهارده)'}, 'unit': {'type': 'STRING', 'description': 'الاستديو لو المصروف بتاعه (اختياري)'}}, 'required': ['what', 'amount']}},
    {'name': 'add_reminder', 'description': 'اعمل تذكير يرن على الموبايل.', 'parameters': {'type': 'OBJECT', 'properties': {'text': {'type': 'STRING'}, 'date': {'type': 'STRING', 'description': 'YYYY-MM-DD'}, 'time': {'type': 'STRING', 'description': 'HH:MM (افتراضي 09:00)'}, 'repeat': {'type': 'STRING', 'description': 'once / daily / weekly / monthly'}, 'note': {'type': 'STRING'}}, 'required': ['text', 'date']}},
    {'name': 'tenant_left', 'description': 'سجّل إن مستأجر خرج (إنهاء عقده).', 'parameters': {'type': 'OBJECT', 'properties': {'unit': {'type': 'STRING'}, 'tenant': {'type': 'STRING'}, 'exit_date': {'type': 'STRING', 'description': 'YYYY-MM-DD'}, 'penalty': {'type': 'NUMBER', 'description': 'غرامة خروج بدري (اختياري)'}, 'penalty_paid': {'type': 'BOOLEAN'}}, 'required': ['unit', 'exit_date']}},
    {'name': 'prepare_contract', 'description': 'جهّز عقد عميل من بيانات مستأجر موجود وافتح صفحة العقد.', 'parameters': {'type': 'OBJECT', 'properties': {'unit': {'type': 'STRING'}, 'tenant': {'type': 'STRING'}}, 'required': ['unit']}},
    {'name': 'whatsapp_message', 'description': 'اكتب رسالة واتساب جاهزة (لعميل أو مستأجر أو شركة) بأسلوب أسامه. مش بتتبعت لوحدها — أسامه بيدوس ابعت.', 'parameters': {'type': 'OBJECT', 'properties': {'text': {'type': 'STRING'}, 'phone': {'type': 'STRING', 'description': 'رقم الموبايل لو معروف'}, 'to': {'type': 'STRING', 'description': 'اسم المرسل إليه'}}, 'required': ['text']}},
    {'name': 'remember', 'description': 'احفظ قاعدة أو تصحيح أو معلومة عن شغل أسامه عشان تفتكرها دايماً (لما يصحّحك أو يقولك افتكر).', 'parameters': {'type': 'OBJECT', 'properties': {'note': {'type': 'STRING'}}, 'required': ['note']}},
  ];

  static String _sys(String ws) {
    final m = [for (final x in objs(mem)) '- ${str(x['t'])}'].join('\n');
    return '''إنت «نموذج بنيان»: المساعد الشخصي لأسامه في شغله (بيأجّر غرف/استديوهات فاضية من شركات، يفرشها ويأجّرها شهري للمستأجرين في الإمارات — العملة درهم). بتكلمه بالعامية المصرية، باختصار وبوضوح.
- بتجاوب من الأرقام الحقيقية اللي تحت بس — متخترعش أرقام؛ لو حاجة مش موجودة قول كده.
- تقدر تنفّذ حاجات بالأدوات (تسجيل إيجار، دفعة شركة، مصروف، تذكير، خروج مستأجر، تجهيز عقد، رسالة واتساب). أسامه بيوافق على كل تنفيذ قبل ما يحصل، فاستخدم الأداة على طول لما يطلب حاجة، واكتب جملة قصيرة بتقول هتعمل إيه.
- لو طلب رسالة لعميل: استخدم whatsapp_message، بأسلوب محترم ودود، عربي أو إنجليزي حسب العميل.
- لو صحّحك أو قالك «افتكر» أو قاعدة جديدة في شغله: استخدم remember.
- النصيحة (تسحب إمتى، تفتح استديو جديد ولا لأ): قول رأيك بصراحة مع السبب من الأرقام.
- الأسماء: «حكيم» (مش عبد الحكيم).
${m.isEmpty ? '' : '\nقواعد وتصحيحات أسامه (لازم تمشي عليها):\n$m\n'}
الأرقام دلوقتي:
${Ai.context(ws)}''';
  }

  /// سؤال/طلب → رد + حاجات مستنية موافقتك
  static Future<AgentOut> run(String q, List<Map<String, String>> hist, String ws) async {
    final k = Ai.key();
    if (k.isEmpty) return AgentOut('⚠️ مفتاح Gemini المجاني مش موجود. افتح بنيان القديم مرة (فيه المفتاح) وهيتنقل لوحده مع الربط.', [], []);
    final contents = [for (final h in hist.where((h) => (h['t'] ?? '').isNotEmpty).toList().reversed.take(12).toList().reversed) {'role': h['r'] == 'u' ? 'user' : 'model', 'parts': [{'text': h['t']}]}, {'role': 'user', 'parts': [{'text': q}]}];
    final body = jsonEncode({'systemInstruction': {'parts': [{'text': _sys(ws)}]}, 'contents': contents, 'tools': [{'functionDeclarations': _tools}], 'generationConfig': {'temperature': 0.3}});
    String err = '';
    for (final m in models) {
      try {
        final r = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$k'), headers: {'Content-Type': 'application/json'}, body: body).timeout(const Duration(seconds: 40));
        if (r.statusCode != 200) { err = 'HTTP ${r.statusCode}'; if (r.statusCode == 400 || r.statusCode == 403) { if (m == models.last) break; } continue; }
        final o = jsonDecode(utf8.decode(r.bodyBytes));
        final parts = ((o['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?) ?? [];
        final text = StringBuffer(); final acts = <AgentAct>[]; final wa = <Map<String, String>>[];
        for (final p in parts) {
          if (p is! Map) continue;
          if (p['text'] != null && p['thought'] != true) text.write(str(p['text']));
          final fc = p['functionCall'];
          if (fc is Map) {
            final name = str(fc['name']); final args = (fc['args'] is Map) ? Map<String, dynamic>.from(fc['args']) : <String, dynamic>{};
            if (name == 'whatsapp_message') { wa.add({'text': str(args['text']), 'phone': str(args['phone']), 'to': str(args['to'])}); continue; }
            acts.add(_make(name, args, ws));
          }
        }
        final t = text.toString().trim();
        if (t.isEmpty && acts.isEmpty && wa.isEmpty) { err = 'رد فاضي'; continue; }
        return AgentOut(t, acts, wa);
      } catch (e) { err = '$e'; }
    }
    return AgentOut('⚠️ النموذج مش رادد دلوقتي ($err). جرّب تاني بعد شوية.', [], []);
  }

  /// بيحوّل طلب النموذج لحاجة واضحة تتعرض عليك قبل التنفيذ
  static AgentAct _make(String name, Map<String, dynamic> a, String ws) {
    AgentAct bad(String why) => AgentAct(name, a, why, null, err: why);
    switch (name) {
      case 'remember':
        final t = str(a['note']); if (t.isEmpty) return bad('مفيش حاجة أحفظها');
        return AgentAct(name, a, '🧠 أحفظ: «$t»', () async { await learn(t); return 'اتحفظت'; });
      case 'add_expense':
        final amt = n0(a['amount']); if (amt <= 0) return bad('المبلغ مش واضح');
        final u = str(a['unit']).isEmpty ? null : _unit(str(a['unit'])); final d = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str(a['date'])) ? str(a['date']) : Act.td();
        return AgentAct(name, a, '🧾 مصروف: ${str(a['what'])} — ${_f(amt)} درهم • ${Ct.dm(d)}${u != null ? ' • ${str(u['name'])}' : ''}', () async { await Act.addExp(w: str(a['what']), a: amt.toDouble(), d: d, unitId: u == null ? '' : str(u['id']), ws: ws); return 'اتسجل'; });
      case 'add_reminder':
        final d = str(a['date']); if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)) return bad('التاريخ مش واضح');
        final tm = RegExp(r'^\d{1,2}:\d{2}$').hasMatch(str(a['time'])) ? str(a['time']) : '09:00'; final rp = ['once', 'daily', 'weekly', 'monthly'].contains(str(a['repeat'])) ? str(a['repeat']) : 'once';
        const rl = {'once': 'مرة واحدة', 'daily': 'كل يوم', 'weekly': 'كل أسبوع', 'monthly': 'كل شهر'};
        return AgentAct(name, a, '⏰ تذكير: ${str(a['text'])} • ${Ct.dm(d)} $tm • ${rl[rp]}', () async {
          final L = (S['rem'] is List) ? S['rem'] as List : (S['rem'] = <dynamic>[]);
          L.add({'id': Act.uid(), 'on': true, 't': str(a['text']), 'n': str(a['note']), 'd': d, 'tm': tm, 'rp': rp, 'last': 0});
          await Store.I.save(log: '⏰ تذكير جديد (نموذج بنيان): ${str(a['text'])}'); Rem.schedule();
          return 'اتعمل';
        });
      case 'rent_received':
        final u = _unit(str(a['unit']).isEmpty ? str(a['tenant']) : str(a['unit'])); if (u == null) return bad('ملقيتش الاستديو «${str(a['unit'])}»');
        final k = _lease(u, str(a['tenant'])); if (k < 0) return bad('ملقيتش المستأجر في ${str(u['name'])}');
        final L = objs(u['leases'])[k]; final got = Engine.rcv(L).toSet(); final cnt = n0(a['count']).round().clamp(1, 24);
        final ix = <int>[];
        if (RegExp(r'^\d{4}-\d{2}').hasMatch(str(a['month_date']))) { final ym = str(a['month_date']).substring(0, 7); for (var i = 0; i < Engine.months(L); i++) { if (iso(Engine.payD(L, i)).startsWith(ym) && !got.contains(i)) { ix.add(i); break; } } }
        for (var i = 0; i < Engine.months(L) && ix.length < cnt; i++) { if (!got.contains(i) && !ix.contains(i)) ix.add(i); }
        if (ix.isEmpty) return bad('${str(L['tenant'])} دافع كل الشهور');
        final tot = ix.fold<double>(0, (s, i) => s + Engine.la(L, i));
        return AgentAct(name, a, '✅ استلام إيجار من ${str(L['tenant'])} — ${str(u['name'])}: ${ix.map((i) => 'دفعة ${i + 1} (${Ct.dm(iso(Engine.payD(L, i)))})').join('، ')} = ${_f(tot)} درهم', () async { for (final i in ix) { await Act.rentPaid(u, k, i); } return 'اتسجل'; });
      case 'company_installment_paid':
        final u = _unit(str(a['unit'])); if (u == null) return bad('ملقيتش الاستديو «${str(a['unit'])}»');
        final ins = objs(u['inst']); var k = -1;
        if (RegExp(r'^\d{4}-\d{2}').hasMatch(str(a['date']))) { for (var i = 0; i < ins.length; i++) { if (!truthy(ins[i]['p']) && str(ins[i]['d']).startsWith(str(a['date']).substring(0, 7))) { k = i; break; } } }
        if (k < 0) { for (var i = 0; i < ins.length; i++) { if (!truthy(ins[i]['p'])) { k = i; break; } } }
        if (k < 0) return bad('كل دفعات الشركة لـ ${str(u['name'])} مدفوعة');
        final src = {'cash': 'cash', 'gp': 'gp', 'out': ''}[str(a['source'])] ?? 'cash';
        const sl = {'cash': 'من الرصيد', 'gp': 'من فلوس الشراكة', '': 'من بره البرنامج'};
        return AgentAct(name, a, '💳 دفعة شركة ${str(u['company'])} — ${str(u['name'])}: ${_f(n0(ins[k]['a']))} درهم (${Ct.dm(str(ins[k]['d']))}) • ${sl[src]}', () async { await Act.instPay(u, k, src); return 'اتسجلت'; });
      case 'tenant_left':
        final u = _unit(str(a['unit']).isEmpty ? str(a['tenant']) : str(a['unit'])); if (u == null) return bad('ملقيتش الاستديو');
        final k = _lease(u, str(a['tenant'])); if (k < 0) return bad('ملقيتش المستأجر');
        final d = str(a['exit_date']); if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)) return bad('تاريخ الخروج مش واضح');
        final pen = n0(a['penalty']).toDouble(); final L = objs(u['leases'])[k];
        return AgentAct(name, a, '🚪 ${str(L['tenant'])} خرج من ${str(u['name'])} يوم ${Ct.dm(d)}${pen > 0 ? ' • غرامة ${_f(pen)}${a['penalty_paid'] == true ? ' (مدفوعة)' : ''}' : ''}', () async { await Act.stopLease(u, k, d, pen, a['penalty_paid'] == true); return 'اتسجل'; });
      case 'prepare_contract':
        final u = _unit(str(a['unit']).isEmpty ? str(a['tenant']) : str(a['unit'])); if (u == null) return bad('ملقيتش الاستديو');
        final k = _lease(u, str(a['tenant'])); if (k < 0) return bad('ملقيتش المستأجر');
        final L = objs(u['leases'])[k];
        return AgentAct(name, a, '📝 أجهّز عقد ${str(L['tenant'])} — ${str(u['name'])} وأفتح صفحة العقد', () async { Ct.fill(S, u, L); Ct.ct(S)['html'] = ''; await Store.I.save(log: '📝 عقد ${str(L['tenant'])} (نموذج بنيان)'); return 'open_contract'; });
    }
    return bad('حاجة مش معروفة: $name');
  }
}
