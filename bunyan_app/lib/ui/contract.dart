import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/sigimg.dart';
import 'package:printing/printing.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/engine.dart';
import '../core/contract.dart';
import '../core/ct_pdf.dart';
import '../core/js.dart';
import '../core/ai.dart';
import '../core/idocr.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/native.dart';
import 'theme.dart';
import 'dialogs.dart';
import 'shell.dart';
import 'lease_edit.dart';

/// 📝 عقد العميل — نفس تبويب «عقد العميل» في بنيان القديم:
/// مفروش/فاضي • لغة بيانات العميل • املا من صورة الهوية والرقم • تعبئة من عقد قائم • المؤجر/المستأجر/الإيجار
/// • التوقيعات (المؤجر المحفوظة، المستأجر، الشهود) • العقد نفسه • ناقص/راجع • واتساب، PDF، طباعة، عقد جديد، النموذج الأصلي، سجّله عقد مستأجر
class ContractPage extends StatefulWidget {
  final bool inTab;
  const ContractPage({super.key, this.inTab = false});
  @override
  State<ContractPage> createState() => _CtState();
}

class _CtState extends State<ContractPage> {
  Obj get S => Store.I.S;
  Map<String, dynamic> get c => Ct.ct(S);
  Map<String, dynamic> get f => Ct.F(S);
  final Map<String, TextEditingController> tc = {};
  // لو خرجت من الصفحة وانت لسه بتكتب/بتمسح → يتحفظ برضه
  @override
  void dispose() {
    if (_deb?.isActive == true) { _deb!.cancel(); var ch = false; for (final e in tc.entries) { if (e.value.text != str(f[e.key])) { f[e.key] = e.value.text; ch = true; } } if (ch) Store.I.save(); }
    super.dispose();
  }
  int v = 0;
  bool busy = false;

  @override
  void initState() { super.initState(); CtPdf.loader ??= rootBundle.load; if (!truthy(c['d'])) c['d'] = Ct.dmy(); }

  TextEditingController _c(String k) => tc.putIfAbsent(k, () => TextEditingController(text: str(f[k])));
  String? _editing; // الخانة اللي انت بتكتب فيها دلوقتي — مانلمسهاش عشان المؤشر مايتنقلش
  void _sync() {
    for (final e in tc.entries) {
      if (e.key == _editing) continue;
      final v = str(f[e.key]);
      if (e.value.text != v) e.value.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    }
  }

  bool _off(String k) => obj(c['clr'])?[k] == true;
  Timer? _deb;
  Future<void> _save([String? log]) async { await Store.I.save(log: log); if (mounted) setState(() => v++); }

  /// ctUpd: تغيير خانة + الحسابات التلقائية (النهاية، الشيكات، الإجمالي، التأمين)
  Future<void> _set(String k, String val) async {
    if (str(f[k]) == val) return;
    final autoTot = !_off('tot') && (!truthy(f['tot']) || n0(f['tot']).round() == (n0(f['_r']) * n0(f['_m'])).round());
    f[k] = val;
    // مسحت خانة بإيدك → متتملاش لوحدها تاني (لحد ما تكتب فيها)
    final X = (c['clr'] is Map<String, dynamic>) ? c['clr'] as Map<String, dynamic> : (c['clr'] = <String, dynamic>{});
    if (val.trim().isEmpty) { X[k] = true; } else { X.remove(k); }
    if ((k == 'st' || k == 'mo') && str(f['st']).isNotEmpty && str(f['mo']).isNotEmpty && !(k == 'mo' && val.isEmpty)) {
      if (!_off('en') || k == 'st') f['en'] = Ct.endOf(str(f['st']), f['mo']);
      if (!_off('chq') && (!truthy(f['chq']) || RegExp(r'^\d+ شيكات شامل').hasMatch(str(f['chq'])))) f['chq'] = '${(double.tryParse(str(f['mo'])) ?? 0).round()} شيكات شامل شيك تأمين بقيمة شهر';
    }
    if (k == 'st' && str(f['st']).isNotEmpty && c['dueMan'] != true && !_off('due')) { final sd = pd(f['st']).day; f['due'] = '${sd == 1 ? 31 : sd - 1}'; }
    if (k == 'due') c['dueMan'] = true;
    if (k == 'rent' && !truthy(f['cx']) && !_off('cx')) f['cx'] = f['rent'];
    if ((k == 'rent' || k == 'mo') && autoTot && truthy(f['rent']) && truthy(f['mo'])) { f['tot'] = (n0(f['rent']) * n0(f['mo'])).round(); f['_r'] = f['rent']; f['_m'] = f['mo']; }
    if (k == 'rent' && Ct.tpl(S) == 'b' && !truthy(f['dep']) && !_off('dep')) f['dep'] = f['rent'];
    // نهاية العقد اتكتبت بإيدك → عدد الشهور يتحسب منها
    if (k == 'en' && str(f['st']).isNotEmpty && str(f['en']).isNotEmpty) { final sp = Ct.spanMonths(str(f['st']), str(f['en'])); if (sp > 0 && n0(f['mo']).round() != sp) f['mo'] = '$sp'; }
    // العقد الفاضي: الدفعات تتوزع لوحدها على المدة (إلا لو عدّلت دفعة بإيدك)
    if (Ct.rm(S) == 'p' && ['tot', 'pn', 'st', 'en', 'mo', 'rent'].contains(k) && c['paysMan'] != true && (n0(f['tot']) > 0 || n0(f['rent']) > 0)) Ct.autoPays(S);
    _sync(); await _save();
  }

  /* ───────── PDF ───────── */
  Future<Uint8List> _bytes({bool sig = true}) async => Uint8List.fromList(await CtPdf.build(Ct.finalHtml(S, withSig: sig)));
  String get _fname { final nm = str(f['tn']).trim().replaceAll(RegExp(r'\s+'), '-'); return 'contract-${nm.isEmpty ? 'contract' : nm}.pdf'; }
  Future<void> _pdf() async { try { await Printing.sharePdf(bytes: await _bytes(), filename: _fname); } catch (e) { if (mounted) toast(context, '⚠️ $e'); } }
  Future<void> _print() async { try { final b = await _bytes(); await Printing.layoutPdf(onLayout: (_) async => b, name: _fname); } catch (e) { if (mounted) toast(context, '⚠️ $e'); } }

  String _phone() { var p = str(f['ph']).replaceAllMapped(RegExp('[٠-٩]'), (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}').replaceAll(RegExp(r'\D'), ''); if (p.startsWith('00')) p = p.substring(2); if (RegExp(r'^05\d{8}$').hasMatch(p)) p = '971${p.substring(1)}'; return p; }
  /// 📤 ابعت العقد للعميل على واتساب: PDF بالتوقيع أو من غيره
  Future<void> _send() async {
    final ph = _phone(); final hasSig = Ct.landlordSig(S) != null || truthy(c['tsig']) || (obj(c['wsig'])?.values.any((x) => truthy(x)) ?? false);
    final s = await showDialog<String>(context: context, builder: (ctx) => Directionality(textDirection: Tr.dir, child: AlertDialog(
      title: const Text('📤 ابعت العقد للعميل'),
      content: Text(ph.isNotEmpty ? 'هيتبعت PDF على واتساب +$ph' : '⚠️ مفيش رقم موبايل في العقد — هتختار العميل من واتساب'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        OutlinedButton(onPressed: () => Navigator.pop(ctx, '0'), child: const Text('📄 PDF من غير توقيع')),
        FilledButton(onPressed: hasSig ? () => Navigator.pop(ctx, '1') : null, child: Text(hasSig ? '✍️ PDF بالتوقيع' : '✍️ (مفيش توقيع)')),
      ],
    )));
    if (s == null) return;
    final msg = 'مرحبا ${str(f['tn'])} 👋\nعقد إيجار ${str(f['sub'])}\nمن ${str(f['st'])} إلى ${str(f['en'])}\nالإيجار الشهري: ${str(f['rent'])} درهم${truthy(f['mo']) ? ' • ${f['mo']} شهر' : ''}\nهبعتلك نسخة العقد PDF هنا.';
    try {
      final b = await _bytes(sig: s == '1');
      if (ph.isNotEmpty) await Native.openUrl('https://wa.me/$ph?text=${Uri.encodeComponent(msg)}');
      await Printing.sharePdf(bytes: b, filename: _fname, subject: msg);
      if (mounted) toast(context, '📄 ابعتله ملف العقد في شات الواتساب');
    } catch (e) { if (mounted) toast(context, '⚠️ $e'); }
  }

  /* ───────── تعبئة ───────── */
  Future<void> _fill() async {
    final e = Engine(S, WS: Ws.I.resolve()); final ls = Ct.leases(S, e);
    if (ls.isEmpty) { toast(context, Tr.t('مفيش عقود مستأجرين')); return; }
    final p = await pickDlg(context, Tr.t('تعبئة من عقد مستأجر'), [for (var i = 0; i < ls.length; i++) ['$i', '${str((ls[i]['u'] as Obj)['name'])} — ${str((ls[i]['L'] as Obj)['tenant']).isEmpty ? 'مستأجر' : str((ls[i]['L'] as Obj)['tenant'])}']], '0');
    if (p == null) return;
    final x = ls[int.parse(p)]; Ct.fill(S, x['u'] as Obj, x['L'] as Obj); c['subU'] = str((x['u'] as Obj)['name']);
    _sync(); await _save('📝 عقد العميل: ${str((x['L'] as Obj)['tenant'])}');
  }

  /// 📷 Gemini للصور — موديلات سريعة بس ومن غير «تفكير»، وأقصى انتظار 15 ثانية للموديل
  static const _fastImg = ['gemini-2.5-flash-lite', 'gemini-2.0-flash', 'gemini-flash-lite-latest', 'gemini-2.0-flash-lite'];
  Future<Map?> _gem(Uint8List img, String prompt) async {
    final k = Ai.key(); if (k.isEmpty) throw 'محتاج مفتاح Gemini (بيتنقل من بنيان القديم مع الربط)';
    final t0 = DateTime.now();
    for (final m in _fastImg) {
      if (DateTime.now().difference(t0).inSeconds > 25) break;
      try {
        final r = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$k'), headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'contents': [{'parts': [{'text': prompt}, {'inline_data': {'mime_type': 'image/jpeg', 'data': base64Encode(img)}}]}], 'generationConfig': {'temperature': 0, 'responseMimeType': 'application/json', if (m.contains('2.5')) 'thinkingConfig': {'thinkingBudget': 0}}})).timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) continue;
        final j = jsonDecode(utf8.decode(r.bodyBytes)); final t = ((j['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?)?.map((p) => p['text'] ?? '').join() ?? '';
        final mm = RegExp(r'\{[\s\S]*\}').firstMatch(t); if (mm != null) return jsonDecode(mm[0]!);
      } catch (_) {}
    }
    return null;
  }

  Future<XFile?> _pick() async {
    final src = await showModalBottomSheet<ImageSource>(context: context, builder: (ctx) => Directionality(textDirection: Tr.dir, child: SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.photo_camera), title: const Text('📷 صوّر دلوقتي'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
      ListTile(leading: const Icon(Icons.photo_library), title: const Text('🖼 من الصور'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
    ]))));
    if (src == null) return null;
    try { return await ImagePicker().pickImage(source: src, maxWidth: 1400, maxHeight: 1400, imageQuality: 78); } catch (e) { if (mounted) toast(context, '⚠️ مقدرتش أفتح الصور/الكاميرا: $e'); return null; }
  }

  static const _idPrompt = 'This is an ID card or passport (often UAE Emirates ID, which has Arabic and English). Return ONLY JSON {"ar":"full name in Arabic as printed (or transliterate the English name to Arabic if no Arabic)","en":"full name in English as printed","id":"ID or passport number exactly as printed (Emirates ID like 784-XXXX-XXXXXXX-X)","nat_ar":"nationality in Arabic","nat_en":"nationality in English"}. Use "" if not visible.';
  /// بيقرأ الهوية: الموبايل نفسه الأول (أقل من ثانية ومن غير نت)، وGemini بس لو الموبايل ماعرفش أو محتاجين الاسم بالعربي
  Future<Map?> _idFrom(XFile x, {void Function(Map)? later}) async {
    String err = ''; Map<String, String>? dev;
    if (!kIsWeb) {
      try { final o = IdOcr.parse(await IdOcr.text(x.path)); if ((o['en'] ?? '').isNotEmpty || (o['id'] ?? '').isNotEmpty) dev = {'en': o['en'] ?? '', 'ar': '', 'id': o['id'] ?? '', 'nat_en': o['nat_en'] ?? '', 'nat_ar': o['nat_ar'] ?? ''}; } catch (e) { err = '$e'; }
    }
    final hasKey = Ai.key().isNotEmpty;
    if (dev != null && (dev['en'] ?? '').isNotEmpty && (dev['id'] ?? '').isNotEmpty) {
      // الموبايل جاب الاسم والرقم: نملا على طول — والاسم العربي بييجي من Gemini في الخلفية من غير ما تستنى
      if (hasKey && later != null) { x.readAsBytes().then((b) => _gem(b, _idPrompt)).then((o) { if (o != null) later(o); }).catchError((_) {}); }
      return dev;
    }
    if (hasKey) {
      try { final o = await _gem(await x.readAsBytes(), _idPrompt); if (o != null && (str(o['en']).isNotEmpty || str(o['ar']).isNotEmpty || str(o['id']).isNotEmpty)) return {...?dev, ...o.map((k, v) => MapEntry('$k', str(v).isEmpty ? (dev?['$k'] ?? '') : str(v)))}; } catch (e) { err = '$e'; }
    }
    if (dev != null) return dev;
    if (kIsWeb && !hasKey) err = 'في نسخة المتصفح القراية محتاجة مفتاح Gemini — جرّبها من تطبيق الموبايل';
    if (err.isNotEmpty && mounted) toast(context, '⚠️ $err');
    return null;
  }

  Future<void> _readId(bool landlord) async {
    final x = await _pick(); if (x == null || !mounted) return;
    toast(context, landlord ? '⏳ بقرأ هوية المؤجر…' : '⏳ بقرأ هوية المستأجر…'); setState(() => busy = true);
    Future<String> fill(Map o, {bool quiet = false}) async {
      final en = Ct.en(S); final alt = (c['alt'] is Map<String, dynamic>) ? c['alt'] as Map<String, dynamic> : (c['alt'] = <String, dynamic>{});
      String pick(String a, String b) => en ? (str(o[a]).isEmpty ? str(o[b]) : str(o[a])) : (str(o[b]).isEmpty ? str(o[a]) : str(o[b]));
      String keep(Map? m, String k, String v) => v.isNotEmpty ? v : str(m?[k]);
      final nm = pick('en', 'ar');
      if (landlord) { final m = obj(alt['ll']); alt['ll'] = {'ar': keep(m, 'ar', str(o['ar'])), 'en': keep(m, 'en', str(o['en']))}; if (nm.isNotEmpty) f['ll'] = nm; if (str(o['id']).isNotEmpty) f['lid'] = str(o['id']); }
      else {
        final m = obj(alt['tn']), mn = obj(alt['nat']);
        alt['tn'] = {'ar': keep(m, 'ar', str(o['ar'])), 'en': keep(m, 'en', str(o['en']))}; alt['nat'] = {'ar': keep(mn, 'ar', str(o['nat_ar'])), 'en': keep(mn, 'en', str(o['nat_en']))};
        final nat = pick('nat_en', 'nat_ar');
        if (nm.isNotEmpty) f['tn'] = nm; if (str(o['id']).isNotEmpty) f['tid'] = str(o['id']); if (nat.isNotEmpty) f['nat'] = nat;
      }
      _sync(); await _save(quiet ? null : '🪪 ${landlord ? 'هوية المؤجر' : 'هوية المستأجر'} من صورة');
      return nm;
    }
    try {
      final o = await _idFrom(x, later: (g) async { if (!mounted) return; await fill(g, quiet: true); if (mounted && !Ct.en(S) && str(g['ar']).isNotEmpty) toast(context, '✅ الاسم بالعربي: ${g['ar']}'); });
      if (o == null) { if (mounted) toast(context, '⚠️ مقدرتش أقرأ الهوية — صوّرها أوضح وفي نور كويس، والكارت مالي الصورة'); return; }
      final nm = await fill(o);
      if (mounted) toast(context, '✅ ${nm.isEmpty ? '' : nm}${str(o['id']).isNotEmpty ? ' • ${o['id']}' : ''}');
    } catch (e) { if (mounted) toast(context, '⚠️ $e'); } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> _readPhone() async {
    final x = await _pick(); if (x == null || !mounted) return;
    toast(context, '⏳ بدوّر على رقم الموبايل…'); setState(() => busy = true);
    try {
      var p = '';
      if (!kIsWeb) { try { p = IdOcr.phone(await IdOcr.text(x.path)); } catch (_) {} }
      if (p.isEmpty && Ai.key().isNotEmpty) { try { final o = await _gem(await x.readAsBytes(), 'Find the main mobile phone number in this image (contact card, WhatsApp profile, screenshot, business card, or handwriting). Return ONLY JSON {"phone":"number with country code if visible, digits and + only"}.'); p = str(o?['phone']); } catch (_) {} }
      if (p.isEmpty) { if (mounted) toast(context, '⚠️ ملقيتش رقم في الصورة'); return; }
      f['ph'] = p; _sync(); await _save(); if (mounted) toast(context, '✅ الرقم: $p');
    } catch (e) { if (mounted) toast(context, '⚠️ $e'); } finally { if (mounted) setState(() => busy = false); }
  }

  /// لغة العقد: عربي / English / الاتنين — البيانات بتتكتب بالعربي في العقد العربي وبالإنجليزي في الباقي
  Future<void> _lang(String l) async {
    c['cl'] = l; final dl = l == 'ar' ? 'ar' : 'en'; c['lang'] = dl; final alt = obj(c['alt']) ?? {};
    for (final k in ['tn', 'll', 'nat']) { final a = obj(alt[k]); final x = str(a?[dl]); if (x.isNotEmpty) f[k] = x; }
    _sync(); await _save();
    if (mounted) toast(context, l == 'ar' ? 'العقد بالعربي' : l == 'en' ? 'Contract in English' : 'العقد عربي + English');
  }

  /* ───────── ✏️ تعديل العقد: العنوان، الصفوف، البنود ───────── */
  Future<void> _edSave([String? log]) async { Ct.edTouch(S); await _save(log); }

  /// 🌐 ترجمة بـ Gemini المجاني (موديلات سريعة) — للعقود: صياغة قانونية بسيطة
  Future<String?> _tr(String text, {required bool toEn}) async {
    final k = Ai.key(); if (k.isEmpty || text.trim().isEmpty) return null;
    final prompt = toEn
        ? 'Translate this Arabic tenancy-contract text to clear, formal English (UAE rental contract style). Return ONLY the translation, no quotes, no notes.\n\n$text'
        : 'ترجم النص ده من عقد إيجار للعربي الفصحى الرسمي البسيط (أسلوب عقود الإيجار في الإمارات). رجّع الترجمة بس من غير علامات تنصيص ولا ملاحظات.\n\n$text';
    for (final m in _fastImg) {
      try {
        final r = await http.post(Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$m:generateContent?key=$k'), headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'contents': [{'parts': [{'text': prompt}]}], 'generationConfig': {'temperature': 0.1, if (m.contains('2.5')) 'thinkingConfig': {'thinkingBudget': 0}}})).timeout(const Duration(seconds: 12));
        if (r.statusCode != 200) continue;
        final j = jsonDecode(utf8.decode(r.bodyBytes)); final t = ((j['candidates'] as List?)?.firstOrNull?['content']?['parts'] as List?)?.map((p) => p['text'] ?? '').join().trim() ?? '';
        if (t.isNotEmpty) return t.replaceAll(RegExp(r'^["«“]+|["»”]+$'), '').trim();
      } catch (_) {}
    }
    return null;
  }

  /// نافذة بخانتين (English + عربي) وأحياناً قيمة
  Future<Map<String, String>?> _edDlg(String title, {String en = '', String ar = '', String? v, bool multi = false}) async {
    final a = TextEditingController(text: en), b = TextEditingController(text: ar), c0 = v == null ? null : TextEditingController(text: v);
    var auto = true, busyT = false; String? note;
    final r = await showDialog<Map<String, String>>(context: context, builder: (ctx) => Directionality(textDirection: Tr.dir, child: StatefulBuilder(builder: (ctx, ss) {
      Future<void> go(bool toEn) async {
        final src = toEn ? b.text : a.text; if (src.trim().isEmpty) return;
        ss(() { busyT = true; note = null; });
        final t = await _tr(src, toEn: toEn);
        if (!ctx.mounted) return;
        ss(() { busyT = false; if (t != null) { (toEn ? a : b).text = t; } else { note = Ai.key().isEmpty ? 'الترجمة محتاجة مفتاح Gemini' : 'مقدرتش أترجم دلوقتي (النت؟) — اكتبها بإيدك'; } });
      }
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: b, maxLines: multi ? 5 : 1, minLines: 1, decoration: const InputDecoration(labelText: 'بالعربي', border: OutlineInputBorder())),
          Row(children: [
            Expanded(child: InkWell(onTap: () => ss(() => auto = !auto), child: Row(children: [Checkbox(value: auto, visualDensity: VisualDensity.compact, onChanged: (x) => ss(() => auto = x ?? true)), const Flexible(child: Text('ترجم للإنجليزي لوحده', style: TextStyle(fontSize: 12.5)))]))),
            if (busyT) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else ...[
              TextButton(onPressed: () => go(true), child: const Text('عربي ← EN')),
              TextButton(onPressed: () => go(false), child: const Text('EN ← عربي')),
            ],
          ]),
          TextField(controller: a, maxLines: multi ? 5 : 1, minLines: 1, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'English', border: OutlineInputBorder())),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('⚠️ $note', style: const TextStyle(color: kRed, fontSize: 12))),
          if (c0 != null) ...[const SizedBox(height: 10), TextField(controller: c0, decoration: const InputDecoration(labelText: 'القيمة اللي هتتكتب في العقد', border: OutlineInputBorder()))],
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: busyT ? null : () async {
            // عدّلت العربي ولسه الإنجليزي زي ما هو → يترجم لوحده (والعكس)
            final arCh = b.text.trim() != ar.trim(), enCh = a.text.trim() != en.trim();
            if (auto && arCh && !enCh && b.text.trim().isNotEmpty) await go(true);
            else if (auto && enCh && !arCh && a.text.trim().isNotEmpty) await go(false);
            if (note != null && (arCh != enCh)) { ss(() => note = '$note — دوس حفظ تاني لو عايز تحفظ من غير ترجمة'); auto = false; return; } // الترجمة ماشتغلتش: مانقفلش من غير ما تعرف
            if (ctx.mounted) Navigator.pop(ctx, {'en': a.text.trim(), 'ar': b.text.trim(), if (c0 != null) 'v': c0.text.trim()});
          }, child: const Text('حفظ')),
        ],
      );
    })));
    return r;
  }

  Widget _edBtn(IconData ic, VoidCallback on, {Color c0 = kMuted}) => InkWell(borderRadius: BorderRadius.circular(99), onTap: on, child: Padding(padding: const EdgeInsets.all(5), child: Icon(ic, size: 19, color: c0)));

  Widget _editCard() {
    final E = Ct.ed(S); final hide = {for (final h in lst(E['hide'])) str(h)}; final cr = lst(E['rows']); final T = Ct.terms(S);
    final custom = E['terms'] is List || cr.isNotEmpty || hide.isNotEmpty || truthy(E['tEn']) || truthy(E['tAr']);
    List<Map<String, dynamic>> tl() { if (E['terms'] is! List) E['terms'] = Ct.defTerms(S); return (E['terms'] as List).cast<Map<String, dynamic>>(); }
    Widget head(String t) => Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, color: kNavy, fontSize: 14)));
    return BCard(c: const Color(0xFF7C3AED), title: '✏️ تعديل العقد', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('عدّل أي حاجة في الورقة: العنوان، تخفي أو تضيف صفوف، وتعدّل أو تمسح أو تضيف بنود. التعديلات بتتحفظ لكل نوع عقد (مفروش / فاضي).', style: TextStyle(color: kMuted, fontSize: 12.5, height: 1.5)),
      head('🏷 عنوان العقد'),
      InkWell(onTap: () async { final r = await _edDlg('عنوان العقد', en: str(E['tEn']).isEmpty ? (Ct.tpl(S) == 'b' ? 'Tenant Contract' : 'Tenancy Contract') : str(E['tEn']), ar: str(E['tAr']).isEmpty ? 'عقد إيجار' : str(E['tAr'])); if (r == null) return; E['tEn'] = r['en']; E['tAr'] = r['ar']; await _edSave('✏️ عنوان العقد'); },
        child: InputDecorator(decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, suffixIcon: Icon(Icons.edit, size: 18)), child: Text('${str(E['tAr']).isEmpty ? 'عقد إيجار' : E['tAr']} • ${str(E['tEn']).isEmpty ? (Ct.tpl(S) == 'b' ? 'Tenant Contract' : 'Tenancy Contract') : E['tEn']}', maxLines: 1, overflow: TextOverflow.ellipsis))),
      head('📋 صفوف الجدول'),
      for (final r in Ct.baseRows(S)) Row(children: [
        Expanded(child: Text(r[2], style: TextStyle(fontWeight: FontWeight.w700, color: hide.contains(r[1]) ? kMuted : kInk, decoration: hide.contains(r[1]) ? TextDecoration.lineThrough : null))),
        _edBtn(hide.contains(r[1]) ? Icons.visibility_off_outlined : Icons.visibility_outlined, () async { final H = [...hide]; hide.contains(r[1]) ? H.remove(r[1]) : H.add(r[1]); E['hide'] = H; await _edSave(); }, c0: hide.contains(r[1]) ? kMuted : const Color(0xFF2563EB)),
      ]),
      for (var i = 0; i < cr.length; i++) Row(children: [
        Expanded(child: Text('➕ ${str(obj(cr[i])?['ar']).isEmpty ? str(obj(cr[i])?['en']) : str(obj(cr[i])?['ar'])}: ${str(obj(cr[i])?['v'])}', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)))),
        _edBtn(Icons.edit_outlined, () async { final x = obj(cr[i])!; final r = await _edDlg('تعديل الصف', en: str(x['en']), ar: str(x['ar']), v: str(x['v'])); if (r == null) return; cr[i] = r; await _edSave('✏️ صف في العقد'); }),
        _edBtn(Icons.delete_outline, () async { cr.removeAt(i); await _edSave('🗑 صف من العقد'); }, c0: kRed),
      ]),
      Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: () async { final r = await _edDlg('➕ صف جديد في الجدول', v: ''); if (r == null || (r['en']!.isEmpty && r['ar']!.isEmpty)) return; if (E['rows'] is! List) E['rows'] = []; (E['rows'] as List).add(r); await _edSave('➕ صف في العقد'); }, icon: const Icon(Icons.add), label: const Text('ضيف صف'))),
      head('📜 بنود العقد'),
      for (var i = 0; i < T.length; i++) Container(
        margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
        decoration: BoxDecoration(color: const Color(0xFFF7F8FB), borderRadius: BorderRadius.circular(10), border: Border.all(color: kBd)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w900)),
          Expanded(child: Text(str(T[i]['ar']).isEmpty ? str(T[i]['en']) : str(T[i]['ar']), style: const TextStyle(fontSize: 13, height: 1.45))),
          Column(children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              _edBtn(Icons.edit_outlined, () async { final r = await _edDlg('تعديل البند ${i + 1}', en: str(T[i]['en']), ar: str(T[i]['ar']), multi: true); if (r == null) return; tl()[i] = r; await _edSave('✏️ بند في العقد'); }),
              _edBtn(Icons.delete_outline, () async { if (!await confirmDlg(context, 'تمسح البند ${i + 1}؟', ok: '🗑 امسح')) return; tl().removeAt(i); await _edSave('🗑 بند من العقد'); }, c0: kRed),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (i > 0) _edBtn(Icons.arrow_upward, () async { final L = tl(); final x = L.removeAt(i); L.insert(i - 1, x); await _edSave(); }),
              if (i < T.length - 1) _edBtn(Icons.arrow_downward, () async { final L = tl(); final x = L.removeAt(i); L.insert(i + 1, x); await _edSave(); }),
            ]),
          ]),
        ]),
      ),
      Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: () async { final r = await _edDlg('➕ بند جديد', multi: true); if (r == null || (r['en']!.isEmpty && r['ar']!.isEmpty)) return; tl().add(r); await _edSave('➕ بند في العقد'); }, icon: const Icon(Icons.add), label: const Text('ضيف بند'))),
      if (custom) OutlinedButton(onPressed: () async { if (!await confirmDlg(context, 'ترجّع العقد زي الأصل؟ (العنوان والصفوف والبنود)', ok: '↩️ رجّع')) return; Ct.ct(S).remove('ed_${Ct.tpl(S)}'); Ct.edTouch(S); await _save('↩️ العقد رجع للأصل'); }, child: const Text('↩️ رجّع العقد زي الأصل')),
    ]));
  }

  /* ───────── التوقيعات ───────── */
  /// توقيع: يا ترسمه بصباعك، يا ترفع صورته (من الكاميرا أو الصور) وأنا آخد التوقيع منها وأشيل الورقة
  Future<String?> _pad(String title, {String? hint, String? nameInit, ValueChanged<String>? onName}) async {
    final how = await showModalBottomSheet<String>(context: context, builder: (ctx) => Directionality(textDirection: Tr.dir, child: SafeArea(child: Wrap(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
      ListTile(leading: const Text('✍️', style: TextStyle(fontSize: 20)), title: const Text('أرسم التوقيع بصباعي'), onTap: () => Navigator.pop(ctx, 'draw')),
      ListTile(leading: const Text('📷', style: TextStyle(fontSize: 20)), title: const Text('صوّر التوقيع على ورقة'), subtitle: const Text('وقّع على ورقة بيضا بقلم غامق وصوّرها'), onTap: () => Navigator.pop(ctx, 'cam')),
      ListTile(leading: const Text('🖼', style: TextStyle(fontSize: 20)), title: const Text('صورة التوقيع من الصور'), onTap: () => Navigator.pop(ctx, 'gal')),
      const SizedBox(height: 8),
    ]))));
    if (how == null || !mounted) return null;
    if (how == 'draw') return showDialog<String>(context: context, builder: (_) => _SigPad(title: title, hint: hint, nameInit: nameInit, onName: onName));
    XFile? x;
    try { x = await ImagePicker().pickImage(source: how == 'cam' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 88); } catch (e) { if (mounted) toast(context, '⚠️ مقدرتش أفتح الصور/الكاميرا: $e'); return null; }
    if (x == null || !mounted) return null;
    setState(() => busy = true);
    String? img;
    try { img = await SigImg.extract(await x.readAsBytes()); } catch (_) {} finally { if (mounted) setState(() => busy = false); }
    if (!mounted) return null;
    if (img == null) { toast(context, '⚠️ ملقيتش توقيع واضح في الصورة — وقّع بقلم غامق على ورقة بيضا وصوّرها قريب'); return null; }
    final nm = TextEditingController(text: nameInit ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => Directionality(textDirection: Tr.dir, child: AlertDialog(
      title: const Text('✅ ده التوقيع اللي أخدته من الصورة'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 150, width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBd)), child: Image.memory(base64Decode(img!.split(',').last), fit: BoxFit.contain)),
        if (onName != null) Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: nm, decoration: const InputDecoration(labelText: 'اسم التوقيع', border: OutlineInputBorder()))),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حطه على العقد'))],
    )));
    if (ok != true) return null;
    onName?.call(nm.text);
    return img;
  }

  Future<void> _newSig() async {
    var nm = str(f['ll']).split(' ').take(2).join(' '); if (nm.isEmpty) nm = 'المؤجر';
    final img = await _pad('✍️ اكتب توقيعك', nameInit: nm, onName: (x) => nm = x); if (img == null) return;
    final s = {'id': DateTime.now().microsecondsSinceEpoch.toRadixString(36), 'n': nm.trim().isEmpty ? 'توقيع' : nm.trim(), 'img': img};
    Ct.sigs(S); (S['sigs'] as List).add(s); c['sig'] = s['id']; await _save('✍️ توقيع جديد');
    if (mounted) toast(context, '✅ اتحفظ التوقيع واتحط على العقد');
  }
  Future<void> _delSig(Obj s) async {
    if (!await confirmDlg(context, 'تحذف توقيع «${str(s['n'])}»؟', ok: '🗑 احذف')) return;
    (S['sigs'] as List).removeWhere((x) => x is Map && x['id'] == s['id']); if (c['sig'] == s['id']) c['sig'] = ''; await _save('🗑 حذف توقيع');
  }
  Future<void> _tSign() async { final img = await _pad('✍️ توقيع المستأجر', hint: 'خلي المستأجر يوقّع بصباعه في المربع.'); if (img == null) return; c['tsig'] = img; await _save(); }
  Future<void> _wSign() async {
    final w = await pickDlg(context, '✍️ توقيع الشهود', [['1', 'الشاهد الأول'], ['2', 'الشاهد التاني']], '1'); if (w == null) return;
    final img = await _pad('✍️ توقيع ${w == '1' ? 'الشاهد الأول' : 'الشاهد التاني'}'); if (img == null) return;
    final W = (c['wsig'] is Map<String, dynamic>) ? c['wsig'] as Map<String, dynamic> : (c['wsig'] = <String, dynamic>{}); W[w] = img; await _save();
    if (mounted) toast(context, '✅ توقيع الشاهد ${w == '1' ? 'الأول' : 'التاني'} اتحط على العقد');
  }

  /* ───────── سجّله عقد مستأجر ───────── */
  Future<void> _toLease() async {
    if (!truthy(f['tn']) && !truthy(f['rent'])) { toast(context, 'املا بيانات العقد الأول'); return; }
    final us = objs(S['units']); if (us.isEmpty) { toast(context, 'مفيش استديوهات'); return; }
    String nz(String t) => t.replaceAll(RegExp('[أإآ]'), 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي').replaceAll(RegExp(r'\s+'), ' ').trim();
    var g = us.where((u) => u['name'] == c['subU']).firstOrNull; g ??= us.where((u) => nz(str(f['sub'])).contains(nz(str(u['name'])))).lastOrNull;
    final gs = objs(S['groups']);
    final id = await pickDlg(context, '🏠 العقد ده لأنهي استديو؟', [for (final u in us) [str(u['id']), '${str(u['name'])}${gs.where((x) => x['id'] == u['g']).firstOrNull == null ? '' : ' — ${str(gs.firstWhere((x) => x['id'] == u['g'])['name'])}'}']], str((g ?? us.first)['id']));
    if (id == null || !mounted) return;
    final u = us.firstWhere((x) => str(x['id']) == id);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LeaseEdit(u, null, pre: {'tenant': str(f['tn']), 'phone': str(f['ph']), 'start': str(f['st']), 'rent': n0(f['rent']) > 0 ? n0(f['rent']) : (n0(f['tot']) > 0 && n0(f['mo']) > 0 ? n0(f['tot']) / n0(f['mo']) : 0), 'day': str(f['due']), 'cmo': n0(f['mo']), 'tid': str(f['tid']), 'nat': str(f['nat'])})));
  }

  /* ───────── الشكل ───────── */
  Widget _seg(List<List<String>> o, String cur, ValueChanged<String> on) => Row(children: [
        for (var i = 0; i < o.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: _opt(o[i][1], cur == o[i][0], () => on(o[i][0])))],
      ]);

  /// زرار اختيار واضح (الكلام دايماً باين — أبيض على أزرق أو غامق على أبيض)
  Widget _opt(String t, bool on, VoidCallback tap) => InkWell(
        borderRadius: BorderRadius.circular(14), onTap: tap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7), alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? const Color(0xFF2563EB) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? const Color(0xFF2563EB) : const Color(0xFFC9D2DE), width: 1.2)),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(t, textAlign: TextAlign.center, maxLines: 1, style: TextStyle(color: on ? Colors.white : kInk, fontWeight: FontWeight.w800, fontSize: 13.5))),
        ),
      );
  Widget _mini(String t, bool on, VoidCallback tap) => InkWell(
        borderRadius: BorderRadius.circular(99), onTap: tap,
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5), decoration: BoxDecoration(color: on ? const Color(0xFF2563EB) : const Color(0xFFF1F4F9), borderRadius: BorderRadius.circular(99), border: Border.all(color: on ? const Color(0xFF2563EB) : const Color(0xFFD5DCE6))),
          child: Text(t, style: TextStyle(color: on ? Colors.white : kInk, fontWeight: FontWeight.w800, fontSize: 12.5))),
      );
  Widget _sec(String t) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: kNavy)));

  Widget _fld(String k, {String? label, bool num = false, String? hint}) {
    final lb = label ?? Ct.lb[k] ?? k;
    if (k == 'st' || k == 'en') {
      return Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(str(f[k])) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2040)); if (d != null) _set(k, iso(d)); },
          child: InputDecorator(decoration: InputDecoration(labelText: lb, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), suffixIcon: const Icon(Icons.calendar_month, size: 20), suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 20)), child: Text(str(f[k]).isEmpty ? '—' : Ct.dm(str(f[k]))))),
        if (k == 'st') Align(alignment: AlignmentDirectional.centerStart, child: TextButton(style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 6), tapTargetSize: MaterialTapTargetSize.shrinkWrap), onPressed: () { c['d'] = Ct.dmy(); _set('st', iso(DateTime.now())); toast(context, '📅 تاريخ العقد: ${c['d']}'); }, child: const Text('📅 العقد بتاريخ النهارده'))),
      ]));
    }
    final t = _c(k); final ltr = num || k == 'ph' || k == 'tid' || k == 'lid' || k == 'cq';
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Focus(
      onFocusChange: (on) {
        if (on) { _editing = k; if (t.selection.baseOffset <= 0) t.selection = TextSelection.collapsed(offset: t.text.length); } // المؤشر في آخر الكلام
        else if (_editing == k) { _editing = null; }
      },
      child: TextField(
      controller: t, textDirection: ltr ? TextDirection.ltr : null, textAlign: ltr ? TextAlign.right : TextAlign.start,
      onTap: () { if (t.selection.isCollapsed && t.selection.baseOffset == 0 && t.text.isNotEmpty) t.selection = TextSelection.collapsed(offset: t.text.length); }, keyboardType: num ? const TextInputType.numberWithOptions(decimal: true) : (k == 'ph' ? TextInputType.phone : TextInputType.text),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(labelText: lb, hintText: hint, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          suffixIcon: t.text.isEmpty ? null : IconButton(tooltip: 'امسح', visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18, color: kMuted), onPressed: () { _deb?.cancel(); t.clear(); _set(k, ''); }),
          suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 20)),
      // بيتحفظ وانت بتكتب/بتمسح (من غير ما تحتاج تدوس برّه)
      onChanged: (x) { final had = x.isNotEmpty; _deb?.cancel(); _deb = Timer(const Duration(milliseconds: 700), () => _set(k, t.text)); if (had != (str(f[k]).isNotEmpty)) setState(() {}); },
      onSubmitted: (x) { _deb?.cancel(); _set(k, x); }, onTapOutside: (_) { FocusManager.instance.primaryFocus?.unfocus(); _deb?.cancel(); _set(k, t.text); }, onEditingComplete: () { _deb?.cancel(); _set(k, t.text); },
    )));
  }

  Widget _chip(String t, Color c0, VoidCallback on) => Expanded(child: InkWell(borderRadius: BorderRadius.circular(99), onTap: busy ? null : on, child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6), alignment: Alignment.center,
        decoration: BoxDecoration(color: c0.withOpacity(.08), borderRadius: BorderRadius.circular(99), border: Border.all(color: c0.withOpacity(.45), width: 1.4)),
        child: FittedBox(fit: BoxFit.scaleDown, child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))),
      )));

  Widget _sigTile({Widget? child, required VoidCallback onTap, bool on = false, VoidCallback? onDel}) => Stack(clipBehavior: Clip.none, children: [
        InkWell(borderRadius: BorderRadius.circular(16), onTap: onTap, child: Container(
          height: 76, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? const Color(0xFF2563EB) : const Color(0xFFD6DAE2), width: on ? 3 : 1.5), boxShadow: on ? const [BoxShadow(color: Color(0x332563EB), blurRadius: 10)] : null),
          alignment: Alignment.center, padding: const EdgeInsets.all(6), child: child,
        )),
        if (onDel != null) Positioned(top: -8, left: -8, child: InkWell(onTap: onDel, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE5A0A0))), child: const Icon(Icons.close, color: kRed, size: 18)))),
      ]);

  Widget _b64(String d, {double h = 52}) { try { return Image.memory(base64Decode(d.substring(d.indexOf(',') + 1)), height: h, fit: BoxFit.contain); } catch (_) { return const SizedBox(); } }

  @override
  Widget build(BuildContext context) {
    final t = Ct.tpl(S);
    final miss = Ct.missing(S), iss = Ct.issues(S); final sigs = Ct.sigs(S); final cur = str(c['sig']); final W = obj(c['wsig']) ?? {};
    final body = ListView(padding: const EdgeInsets.fromLTRB(10, 10, 10, 40), children: [
      // ───── 1) البيانات ─────
      BCard(c: const Color(0xFF2563EB), title: '📝 عقد إيجار للعميل', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _seg([['a', '🛋️ عقد مفروش'], ['b', '🏠 عقد فاضي']], t, (x) async { Ct.switchTpl(S, x); tc.clear(); await _save(); if (mounted) toast(context, x == 'b' ? '🏠 عقد فاضي' : '🛋️ عقد مفروش'); }),
        const SizedBox(height: 10),
        const Text('املأ بيانات العميل، والعقد بيتحدّث لوحده. التعديلات تتحفظ تلقائياً.', style: TextStyle(height: 1.6, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF2F5FA), borderRadius: BorderRadius.circular(18)),
          child: Column(children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: Text('🌐 لغة العقد:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF3D5568)))),
            const SizedBox(height: 6),
            _seg([['ar', 'عربي'], ['en', 'English'], ['bi', 'عربي + English']], Ct.cl(S), _lang),
            const SizedBox(height: 10),
            const Text('📷 املا البيانات من صورة (اختياري) — دوس وصوّر:', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3D5568))),
            const SizedBox(height: 8),
            Row(children: [_chip('🪪 هوية المؤجر', const Color(0xFF2563EB), () => _readId(true)), const SizedBox(width: 6), _chip('🪪 هوية المستأجر', kGreen, () => _readId(false)), const SizedBox(width: 6), _chip('📱 موبايل المستأجر', kTerra, _readPhone)]),
            if (busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          ]),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _fill, icon: const Icon(Icons.person_search), label: const Text('— تعبئة من عقد مستأجر قائم (اختياري) —'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40))),
        _sec('👤 المؤجر'), _fld('ll'), _fld('lid'),
        _sec('🧑 المستأجر'), _fld('tn'), _fld('tid'), _fld('nat'), _fld('ph', hint: 'مثال: 0501234567 — عليه هيتبعت العقد'),
        _sec('🏠 الإيجار'), _fld('sub'), _fld('st'), _fld('mo', num: true), _fld('en'),
        // ───── طريقة الإيجار: شهري ولا دفعات ─────
        _sec('💰 طريقة الإيجار'),
        _seg([['m', '📅 إيجار شهري'], ['p', '💵 دفعات']], Ct.rm(S), (x) async { f['rm'] = x; if (x == 'p' && lst(f['pays']).isEmpty && (n0(f['tot']) > 0 || n0(f['rent']) > 0)) Ct.autoPays(S); if (x == 'm') f['pn'] = ''; tc.clear(); await _save(); }),
        const SizedBox(height: 12),
        if (Ct.rm(S) == 'm') ...[
          _fld('rent', num: true), _fld('due', num: true),
          _fld('tot', label: 'إجمالي الإيجار (بيتحسب لوحده = الإيجار × الشهور)', num: true),
        ] else ...[
          _fld('tot', label: 'إجمالي الإيجار', num: true),
          Row(children: [Expanded(child: _fld('pn', label: 'عدد الدفعات', num: true)), const SizedBox(width: 8), Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 8), child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)), onPressed: () async { FocusManager.instance.primaryFocus?.unfocus(); for (final k in ['tot', 'pn']) { f[k] = _c(k).text; } c['paysMan'] = false; Ct.autoPays(S); await _save(); if (mounted) toast(context, '✅ اتوزّع ${money(n0(f['tot']))} على ${lst(f['pays']).length} دفعات من ${Ct.dm(str(f['st']))} لـ ${Ct.dm(str(f['en']))}'); }, child: const Text('🧮 وزّع الإجمالي', style: TextStyle(color: kInk, fontWeight: FontWeight.w800)))))]),
          for (var i = 0; i < lst(f['pays']).length; i++) Builder(builder: (_) {
            final P = obj(lst(f['pays'])[i])!;
            return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
              SizedBox(width: 22, child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w900))),
              Expanded(flex: 3, child: TextFormField(key: ValueKey('pa$i${P['a']}$v'), initialValue: str(P['a']), keyboardType: TextInputType.number, textDirection: TextDirection.ltr, textAlign: TextAlign.right, decoration: const InputDecoration(labelText: 'المبلغ', isDense: true, border: OutlineInputBorder()), onChanged: (x) { P['a'] = double.tryParse(x)?.round() ?? ''; c['paysMan'] = true; }, onTapOutside: (_) { FocusManager.instance.primaryFocus?.unfocus(); _save(); })),
              const SizedBox(width: 6),
              Expanded(flex: 3, child: InkWell(onTap: () async { final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(str(P['d'])) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2040)); if (d != null) { P['d'] = iso(d); c['paysMan'] = true; await _save(); } }, child: InputDecorator(decoration: const InputDecoration(labelText: 'التاريخ', isDense: true, border: OutlineInputBorder()), child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(str(P['d']).isEmpty ? '—' : Ct.dm(str(P['d'])), maxLines: 1, style: const TextStyle(fontSize: 14)))))),
              const SizedBox(width: 6),
              DropdownButton<String>(value: ['تحويل', 'شيك', 'كاش'].contains(P['m']) ? P['m'] : 'شيك', items: [for (final m in ['تحويل', 'شيك', 'كاش']) DropdownMenuItem(value: m, child: Text(m))], onChanged: (m) async { P['m'] = m; await _save(); }),
              IconButton(onPressed: () async { (f['pays'] as List).removeAt(i); f['pn'] = lst(f['pays']).length; c['paysMan'] = true; tc.remove('pn'); await _save(); }, icon: const Icon(Icons.close, color: kRed)),
            ]));
          }),
          Align(alignment: AlignmentDirectional.centerStart, child: OutlinedButton(onPressed: () async { if (f['pays'] is! List) f['pays'] = []; (f['pays'] as List).add({'a': '', 'd': '', 'm': 'شيك'}); f['pn'] = lst(f['pays']).length; c['paysMan'] = true; tc.remove('pn'); await _save(); }, child: const Text('➕ دفعة', style: TextStyle(color: kInk, fontWeight: FontWeight.w800)))),
        ],
        // ───── الشيكات: انت بتحدد عددها ─────
        _sec('🧾 الشيكات'),
        Row(children: [
          Expanded(child: _fld('cq', label: 'عدد الشيكات', num: true, hint: 'مثال: 1')),
          const SizedBox(width: 8),
          Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 8), child: _opt(truthy(f['cqd']) ? '✅ + شيك تأمين' : '+ شيك تأمين', truthy(f['cqd']), () async { f['cqd'] = !truthy(f['cqd']); await _save(); }))),
        ]),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final q in [1, 2, 3, 4, 6, 12]) _mini(q == 1 ? 'شيك واحد' : '$q', n0(f['cq']).round() == q, () async { f['cq'] = '$q'; tc.remove('cq'); await _save(); }),
          if (Ct.rm(S) == 'p' && lst(f['pays']).isNotEmpty) _mini('بعدد الدفعات (${lst(f['pays']).length})', n0(f['cq']).round() == lst(f['pays']).length, () async { f['cq'] = '${lst(f['pays']).length}'; tc.remove('cq'); await _save(); }),
          if (Ct.rm(S) == 'm' && n0(f['mo']) > 0) _mini('شيك كل شهر (${n0(f['mo']).round()})', n0(f['cq']).round() == n0(f['mo']).round(), () async { f['cq'] = '${n0(f['mo']).round()}'; tc.remove('cq'); await _save(); }),
        ]),
        const SizedBox(height: 8),
        if (n0(f['cq']) > 0) Text('في العقد: ${Ct.chqTxt(f, Ct.en(S))}', style: const TextStyle(color: kMuted, fontWeight: FontWeight.w700))
        else _fld('chq', label: 'أو اكتب الشيكات بنفسك (زي ما هتتكتب في العقد)'),
        if (t == 'b') ...[
          _sec('🔐 التأمين'),
          Row(children: [Expanded(child: _fld('dep', label: 'التأمين (مبلغ)', num: true)), const SizedBox(width: 8), Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 8), child: _seg([['chq', 'شيك'], ['cash', 'كاش']], f['depT'] == 'cash' ? 'cash' : 'chq', (x) async { f['depT'] = x; await _save(); })))]),
        ],

      ])),
      const SizedBox(height: 12),
      // ───── 2) التوقيعات ─────
      _editCard(),
      BCard(c: kGreen, title: '✍️ التوقيعات', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('توقيعك كمؤجر: اختاره من تحت أو اعمل جديد. توقيع المستأجر: يوقّع بصباعه على موبايلك.', style: TextStyle(color: kMuted, fontSize: 12.5)),
        const SizedBox(height: 10),
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.75, children: [
          for (final s in sigs) _sigTile(on: s['id'] == cur, onTap: () async { c['sig'] = s['id']; await _save(); }, onDel: () => _delSig(s), child: Column(mainAxisSize: MainAxisSize.min, children: [Flexible(child: _b64(str(s['img']))), Text(str(s['n']), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF555B66)))])),
          _sigTile(onTap: _newSig, child: const Text('➕ توقيع جديد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF1473E6)))),
          if (cur.isNotEmpty) _sigTile(onTap: () async { c['sig'] = ''; await _save(); }, child: const Text('بدون توقيع', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF667080)))),
        ]),
        const SizedBox(height: 12),
        if (truthy(c['tsig'])) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [const Text('توقيع المستأجر: ', style: TextStyle(fontWeight: FontWeight.w800)), _b64(str(c['tsig']), h: 40)])),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(onPressed: _tSign, child: Text(truthy(c['tsig']) ? '✍️ المستأجر يوقّع تاني' : '✍️ توقيع المستأجر')),
          if (truthy(c['tsig'])) OutlinedButton(onPressed: () async { c['tsig'] = ''; await _save(); }, child: const Text('🗑 شيل توقيع المستأجر')),
          OutlinedButton(onPressed: _wSign, child: const Text('✍️ توقيع الشهود')),
          if (cur.isNotEmpty) OutlinedButton(onPressed: () async { c['sig'] = ''; await _save(); }, child: const Text('🗑 شيل توقيع المؤجر')),
          for (final w in ['1', '2']) if (truthy(W[w])) OutlinedButton(onPressed: () async { (c['wsig'] as Map).remove(w); await _save(); }, child: Text('🗑 شيل توقيع الشاهد $w')),
        ]),
      ])),
      const SizedBox(height: 12),
      // ───── 3) العقد نفسه ─────
      CtPaper(key: ValueKey('paper$v'), build: () => _bytes()),
      const SizedBox(height: 12),
      // ───── 4) ناقص / راجع ─────
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: miss.isEmpty ? const Color(0xFFE8F6EF) : const Color(0xFFFFF6E5), borderRadius: BorderRadius.circular(16), border: Border.all(color: miss.isEmpty ? const Color(0xFFBFE3CF) : const Color(0xFFF2D49B))),
        child: Text(miss.isEmpty ? '✅ بيانات العقد كاملة' : '⚠️ ناقص في العقد: ${miss.join('، ')}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: miss.isEmpty ? const Color(0xFF17643F) : const Color(0xFF8A5A00))),
      ),
      if (iss.isNotEmpty) Container(
        margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF5C2C2))),
        child: Text('🔎 راجع في العقد:\n• ${iss.join('\n• ')}', style: const TextStyle(color: Color(0xFF9B1C1C), fontWeight: FontWeight.w700, height: 1.6)),
      ),
      const SizedBox(height: 12),
      // ───── 5) الأزرار ─────
      FilledButton(onPressed: _send, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)), child: const Text('📤 ابعت العقد للعميل على واتساب', style: TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w700))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _pdf, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: const Text('📄 تنزيل PDF'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton(onPressed: _print, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: const Text('🖨 طباعة'))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () async { if (!await confirmDlg(context, 'تبدأ عقد جديد؟ بيانات العميل هتتمسح (المؤجر والتوقيع هيفضلوا).', ok: '➕ عقد جديد')) return; Ct.newContract(S); tc.clear(); await _save('📝 عقد جديد'); }, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: const Text('➕ عقد جديد'))),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton(onPressed: () async { if (!await confirmDlg(context, 'ترجّع نص العقد الأصلي؟ أي تعديل كتبته بإيدك على ورقة العقد هيتمسح (البيانات اللي في الفورم مش هتتمسح).', ok: '↺ رجّعه')) return; c['html'] = ''; await _save(); }, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: const Text('↺ النموذج الأصلي'))),
      ]),
      const SizedBox(height: 10),
      OutlinedButton(onPressed: _toLease, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: const Text('🏠 سجّله عقد مستأجر في الاستديوهات')),
    ]);
    if (widget.inTab) return body;
    return Directionality(textDirection: Tr.dir, child: Scaffold(appBar: AppBar(title: Text(Tr.t('📝 عقد العميل'))), body: body));
  }
}

/// لوحة التوقيع بالصباع — بتقصّ التوقيع وترجّعه صورة PNG (data URL) زي القديم
class _SigPad extends StatefulWidget {
  final String title; final String? hint, nameInit; final ValueChanged<String>? onName;
  const _SigPad({required this.title, this.hint, this.nameInit, this.onName});
  @override
  State<_SigPad> createState() => _SigPadState();
}

class _SigPadState extends State<_SigPad> {
  final strokes = <List<Offset>>[];
  late final nm = TextEditingController(text: widget.nameInit ?? '');
  final _k = GlobalKey();

  Future<String?> _export() async {
    final pts = strokes.expand((s) => s).toList(); if (pts.isEmpty) return null;
    var x0 = pts.first.dx, y0 = pts.first.dy, x1 = x0, y1 = y0;
    for (final p in pts) { if (p.dx < x0) x0 = p.dx; if (p.dx > x1) x1 = p.dx; if (p.dy < y0) y0 = p.dy; if (p.dy > y1) y1 = p.dy; }
    const pad = 8.0, sc = 3.0; final w = (x1 - x0 + pad * 2), h = (y1 - y0 + pad * 2);
    final rec = ui.PictureRecorder(); final cv = Canvas(rec); cv.scale(sc); cv.translate(-x0 + pad, -y0 + pad);
    final pt = Paint()..color = const Color(0xFF0D2A6B)..strokeWidth = 2.6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    for (final s in strokes) { if (s.length == 1) { cv.drawCircle(s.first, 1.3, Paint()..color = const Color(0xFF0D2A6B)); continue; } final p = Path()..moveTo(s.first.dx, s.first.dy); for (final q in s.skip(1)) { p.lineTo(q.dx, q.dy); } cv.drawPath(p, pt); }
    final img = await rec.endRecording().toImage((w * sc).round(), (h * sc).round());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png); if (bd == null) return null;
    return 'data:image/png;base64,${base64Encode(bd.buffer.asUint8List())}';
  }

  @override
  Widget build(BuildContext context) => Directionality(textDirection: Tr.dir, child: AlertDialog(
        title: Text(widget.title),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.hint != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(widget.hint!, style: const TextStyle(color: kMuted))),
          Container(
            key: _k, height: 190, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB8C8D4), width: 2)),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: GestureDetector(
              onPanStart: (d) => setState(() => strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => strokes.last.add(d.localPosition)),
              child: CustomPaint(painter: _Ink(strokes), size: Size.infinite),
            )),
          ),
          if (widget.onName != null) Padding(padding: const EdgeInsets.only(top: 10), child: TextField(controller: nm, decoration: const InputDecoration(labelText: 'اسم التوقيع', isDense: true, border: OutlineInputBorder()))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () => setState(strokes.clear), child: const Text('🧽 امسح')),
          FilledButton(onPressed: () async { final d = await _export(); if (d == null) { toast(context, 'اكتب التوقيع الأول'); return; } widget.onName?.call(nm.text); if (context.mounted) Navigator.pop(context, d); }, child: Text(widget.onName != null ? '💾 احفظ' : '✅ حط التوقيع')),
        ],
      ));
}

class _Ink extends CustomPainter {
  final List<List<Offset>> s;
  _Ink(this.s);
  @override
  void paint(Canvas c, Size z) {
    final p = Paint()..color = const Color(0xFF0D2A6B)..strokeWidth = 2.6..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;
    for (final st in s) { if (st.length == 1) { c.drawCircle(st.first, 1.3, Paint()..color = const Color(0xFF0D2A6B)); continue; } final path = Path()..moveTo(st.first.dx, st.first.dy); for (final q in st.skip(1)) { path.lineTo(q.dx, q.dy); } c.drawPath(path, p); }
  }
  @override
  bool shouldRepaint(covariant _Ink o) => true;
}


/// 📄 العقد نفسه — زي القديم: بيظهر كامل بعرض الشاشة والصفحة بتسكرول عادي؛
/// كبّر بصباعين أو دوسة مرتين → تقدر تحرّكه بصباع واحد في كل الاتجاهات؛ − ملء العرض + ؛ ⛶ ملء الشاشة
class CtPaper extends StatefulWidget {
  final Future<Uint8List> Function() build;
  final bool full;
  const CtPaper({super.key, required this.build, this.full = false});
  @override
  State<CtPaper> createState() => _CtPaperState();
}

class _CtPaperState extends State<CtPaper> {
  final tc = TransformationController();
  List<Uint8List>? pages; String? err; double z = 1; Uint8List? pdf;
  TapDownDetails? _dt;
  final Map<int, Offset> _ptr = {};

  @override
  void initState() { super.initState(); _load(); if (widget.full) z = 1.0001; }
  Future<void> _load() async {
    try {
      pdf = await widget.build(); final out = <Uint8List>[];
      await for (final p in Printing.raster(pdf!, dpi: 200)) { out.add(await p.toPng()); }
      if (mounted) setState(() => pages = out);
    } catch (e) { if (mounted) setState(() => err = '$e'); }
  }

  bool get zoomed => z > 1.01 || widget.full;
  void _zoom(double nz, [Offset? at]) {
    nz = nz.clamp(1.0, 4.0);
    if (nz <= 1.01 && !widget.full) { tc.value = Matrix4.identity(); setState(() => z = 1); return; }
    final w = MediaQuery.of(context).size.width; final c = at ?? Offset(w / 2, 0);
    tc.value = Matrix4.identity()..translate(c.dx * (1 - nz), at == null ? 0.0 : c.dy * (1 - nz))..scale(nz);
    setState(() => z = nz);
  }

  Widget _pagesCol(double w) => SizedBox(width: w, child: Column(children: [
        for (final p in pages!) Container(margin: const EdgeInsets.only(bottom: 6), decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 6)]), child: Image.memory(p, width: w, fit: BoxFit.fitWidth, filterQuality: FilterQuality.high, gaplessPlayback: true)),
      ]));

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context); final w = mq.size.width - (widget.full ? 0 : 28);
    Widget body;
    if (err != null) { body = Padding(padding: const EdgeInsets.all(20), child: Text('⚠️ مقدرتش أعرض العقد: $err', textAlign: TextAlign.center)); }
    else if (pages == null) { body = SizedBox(height: widget.full ? mq.size.height - 160 : w * 1.414, child: const Center(child: CircularProgressIndicator())); }
    else if (!zoomed) {
      // ملء العرض: العقد كله جوه الصفحة — السكرول عادي، ودوسة مرتين أو صباعين = تكبير
      body = Listener(
        onPointerDown: (e) { _ptr[e.pointer] = e.localPosition; if (_ptr.length >= 2) { final a = _ptr.values.first, b = _ptr.values.last; _ptr.clear(); _zoom(1.8, Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2)); } },
        onPointerUp: (e) => _ptr.remove(e.pointer), onPointerCancel: (e) => _ptr.remove(e.pointer),
        child: GestureDetector(onDoubleTapDown: (d) => _dt = d, onDoubleTap: () => _zoom(2.2, _dt?.localPosition), child: _pagesCol(w)),
      );
    } else {
      // متكبّر: بتحرّكه بصباع واحد في كل الاتجاهات وتكبّر/تصغّر بصباعين — لو صغّرته لآخره يرجع ملء العرض
      body = SizedBox(height: widget.full ? mq.size.height - 160 : mq.size.height * .72, child: GestureDetector(
        onDoubleTapDown: (d) => _dt = d, onDoubleTap: () => _zoom(widget.full && z < 1.5 ? 2.2 : 1, _dt?.localPosition),
        child: InteractiveViewer(
          transformationController: tc, minScale: widget.full ? 1 : .98, maxScale: 4, constrained: false, boundaryMargin: const EdgeInsets.all(40),
          onInteractionEnd: (_) { final s = tc.value.getMaxScaleOnAxis(); if (s < 1.03 && !widget.full) { _zoom(1); } else { setState(() => z = s); } },
          child: _pagesCol(w),
        ),
      ));
    }
    final bar = Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _rb('−', () => _zoom(z - .5)),
      const SizedBox(width: 8),
      _rb(z > 1.01 ? '${(z * 100).round()}%' : 'ملء العرض', () => _zoom(1), wide: true),
      const SizedBox(width: 8),
      _rb('+', () => _zoom((z < 1.01 ? 1 : z) + .5)),
      if (!widget.full) ...[const SizedBox(width: 8), _rb('⛶', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Directionality(textDirection: Tr.dir, child: Scaffold(appBar: AppBar(title: const Text('📄 العقد')), body: Padding(padding: const EdgeInsets.only(top: 8), child: CtPaper(build: () async => pdf ?? await widget.build(), full: true)))))))],
    ]));
    return Column(children: [
      bar,
      ClipRRect(borderRadius: BorderRadius.circular(widget.full ? 0 : 14), child: Container(color: const Color(0xFFE9ECF1), padding: EdgeInsets.all(widget.full ? 0 : 0), child: body)),
      if (!widget.full) Padding(padding: const EdgeInsets.only(top: 6), child: Text(zoomed ? 'حرّك العقد بصباع واحد • صغّره بصباعين يرجع ملء العرض' : 'كبّر بصباعين أو دوس مرتين على العقد • ⛶ ملء الشاشة', style: const TextStyle(color: kMuted, fontSize: 12))),
    ]);
  }

  Widget _rb(String t, VoidCallback on, {bool wide = false}) => InkWell(
        borderRadius: BorderRadius.circular(99), onTap: on,
        child: Container(height: 36, constraints: BoxConstraints(minWidth: wide ? 100 : 40), padding: const EdgeInsets.symmetric(horizontal: 12), alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: kBd), boxShadow: const [BoxShadow(color: Color(0x1214213D), blurRadius: 8, offset: Offset(0, 3))]),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kInk))),
      );
}
