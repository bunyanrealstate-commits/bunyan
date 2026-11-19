import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/store.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// 🔒 قفل التطبيق برقم سري — بيتقفل عند الفتح، ولو خرجت منه أكتر من دقيقتين
class AppLock {
  static bool get pin => obj(Store.I.cfg['pin']) != null;
  /// 👆 البصمة: شغّالة من الأول على الموبايل (تقدر تقفلها من «المزيد ← قفل التطبيق»)
  static bool get bio => !kIsWeb && Store.I.cfg['bio'] != false;
  static bool get on => pin || bio;
  static final _la = LocalAuthentication();
  /// بصمة (أو قفل الشاشة بتاع الموبايل لو البصمة مش راضية) — null = الموبايل مافيهوش قفل خالص
  static Future<bool?> finger([String? why]) async {
    try {
      if (!await _la.isDeviceSupported()) return null;
      return await _la.authenticate(localizedReason: why ?? Tr.t('افتح بنيان بالبصمة'), options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false));
    } catch (_) { return null; }
  }
  static String _h(String p, String s) => sha256.convert(utf8.encode('$s:$p')).toString();
  static bool check(String p) { final c = obj(Store.I.cfg['pin']); return c != null && _h(p, str(c['s'])) == str(c['h']); }
  static Future<void> set(String? p) async {
    if (p == null) { Store.I.cfg.remove('pin'); } else { final s = DateTime.now().microsecondsSinceEpoch.toRadixString(36); Store.I.cfg['pin'] = {'s': s, 'h': _h(p, s)}; }
    await Store.I.saveCfg();
  }
}

class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool locked = AppLock.on; DateTime? _away; final c = TextEditingController(); String err = '';
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); if (locked) _bio(); }
  bool _asking = false;
  Future<void> _bio() async {
    if (!AppLock.bio || _asking) return;
    _asking = true;
    await Future.delayed(const Duration(milliseconds: 350));
    final ok = await AppLock.finger();
    _asking = false;
    if (!mounted) return;
    // البصمة نجحت، أو الموبايل مافيهوش بصمة ولا قفل شاشة (ومفيش رقم سري) → يفتح
    if (ok == true || (ok == null && !AppLock.pin)) setState(() { locked = false; err = ''; });
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _away = DateTime.now();
    if (s == AppLifecycleState.resumed && _away != null && AppLock.on && !_asking && DateTime.now().difference(_away!).inSeconds > 120) { setState(() { locked = true; c.clear(); err = ''; }); _bio(); }
  }
  void _try() { if (AppLock.check(c.text.trim())) { setState(() { locked = false; err = ''; }); } else { setState(() { err = Tr.t('الرقم غلط'); c.clear(); }); } }
  @override
  Widget build(BuildContext context) {
    if (!locked) return widget.child;
    return Directionality(textDirection: Tr.dir, child: Scaffold(backgroundColor: kPaper, body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🔒', style: TextStyle(fontSize: 46)),
      Text(Tr.t('بنيان مقفول'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 16),
      if (AppLock.bio) ...[
        FilledButton.icon(onPressed: _bio, icon: const Icon(Icons.fingerprint, size: 30), label: Text(Tr.t('افتح بالبصمة'), style: const TextStyle(fontSize: 16)), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52))),
        if (AppLock.pin) Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(Tr.t('أو بالرقم السري'), style: const TextStyle(color: kMuted))),
      ],
      if (AppLock.pin) ...[
      TextField(controller: c, autofocus: !AppLock.bio, obscureText: true, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 8),
        decoration: InputDecoration(hintText: Tr.t('الرقم السري'), errorText: err.isEmpty ? null : err, border: const OutlineInputBorder()), onSubmitted: (_) => _try()),
      const SizedBox(height: 12),
      FilledButton(onPressed: _try, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)), child: Text(Tr.t('افتح'))),
      ],
    ])))));
  }
}

/// من «المزيد»: البصمة + الرقم السري
Future<void> lockSettings(BuildContext context) async {
  final opts = <List<String>>[
    if (!kIsWeb) AppLock.bio ? ['bio0', Tr.t('👆 اقفل البصمة (يفتح من غيرها)')] : ['bio1', Tr.t('👆 افتح البرنامج بالبصمة')],
    if (AppLock.pin) ...[['chg', Tr.t('🔢 غيّر الرقم السري')], ['off', Tr.t('🔓 إلغاء الرقم السري')]] else ['set', Tr.t('🔢 ضيف رقم سري كمان')],
  ];
  final v = await pickDlg(context, Tr.t('🔒 قفل التطبيق'), opts, opts.first[0]);
  if (v == null || !context.mounted) return;
  if (v == 'bio1') {
    final ok = await AppLock.finger(Tr.t('أكّد بصمتك'));
    if (!context.mounted) return;
    if (ok == null) { toast(context, Tr.t('الموبايل مافيهوش بصمة ولا قفل شاشة — فعّلهم من إعدادات الموبايل الأول')); return; }
    if (!ok) return;
    Store.I.cfg['bio'] = true; await Store.I.saveCfg(); if (context.mounted) toast(context, Tr.t('👆 تمام — البرنامج هيفتح بالبصمة')); return;
  }
  if (v == 'bio0') {
    final ok = await AppLock.finger(Tr.t('أكّد بصمتك عشان تقفل البصمة'));
    if (ok == false || !context.mounted) return;
    Store.I.cfg['bio'] = false; await Store.I.saveCfg(); if (context.mounted) toast(context, Tr.t('البصمة اتقفلت')); return;
  }
  if (v == 'chg' || v == 'off') {
    final o = await formDlg(context, Tr.t('اكتب الرقم السري الحالي'), [FieldSpec('p', Tr.t('الرقم الحالي'), type: 'n')]);
    if (o == null || !context.mounted) return;
    if (!AppLock.check(o['p'] ?? '')) { toast(context, Tr.t('الرقم غلط')); return; }
    if (v == 'off') { await AppLock.set(null); if (context.mounted) toast(context, Tr.t('اتلغى الرقم السري')); return; }
  }
  final o = await formDlg(context, Tr.t('رقم سري جديد (4 أرقام أو أكتر)'), [FieldSpec('p', Tr.t('الرقم'), type: 'n'), FieldSpec('p2', Tr.t('اكتبه تاني'), type: 'n')]);
  if (o == null || !context.mounted) return;
  final p = (o['p'] ?? '').trim();
  if (p.length < 4) { toast(context, Tr.t('لازم 4 أرقام على الأقل')); return; }
  if (p != (o['p2'] ?? '').trim()) { toast(context, Tr.t('الرقمين مش زي بعض')); return; }
  await AppLock.set(p);
  if (context.mounted) toast(context, Tr.t('🔒 اتفعّل الرقم السري'));
}
