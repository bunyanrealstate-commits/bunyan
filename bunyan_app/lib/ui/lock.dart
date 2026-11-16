import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/js.dart';
import 'theme.dart';
import 'dialogs.dart';

/// 🔒 قفل التطبيق برقم سري — بيتقفل عند الفتح، ولو خرجت منه أكتر من دقيقتين
class AppLock {
  static bool get on => obj(Store.I.cfg['pin']) != null;
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
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _away = DateTime.now();
    if (s == AppLifecycleState.resumed && _away != null && AppLock.on && DateTime.now().difference(_away!).inSeconds > 120) setState(() { locked = true; c.clear(); err = ''; });
  }
  void _try() { if (AppLock.check(c.text.trim())) { setState(() { locked = false; err = ''; }); } else { setState(() { err = 'الرقم غلط'; c.clear(); }); } }
  @override
  Widget build(BuildContext context) {
    if (!locked) return widget.child;
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(backgroundColor: kPaper, body: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🔒', style: TextStyle(fontSize: 46)),
      const Text('بنيان مقفول', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 16),
      TextField(controller: c, autofocus: true, obscureText: true, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 8),
        decoration: InputDecoration(hintText: 'الرقم السري', errorText: err.isEmpty ? null : err, border: const OutlineInputBorder()), onSubmitted: (_) => _try()),
      const SizedBox(height: 12),
      FilledButton(onPressed: _try, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)), child: const Text('افتح')),
    ])))));
  }
}

/// من «المزيد»: تشغيل/تغيير/إلغاء القفل
Future<void> lockSettings(BuildContext context) async {
  if (AppLock.on) {
    final v = await pickDlg(context, '🔒 قفل التطبيق', [['chg', 'غيّر الرقم السري'], ['off', 'إلغاء القفل']], 'chg');
    if (v == null || !context.mounted) return;
    final o = await formDlg(context, 'اكتب الرقم السري الحالي', [FieldSpec('p', 'الرقم الحالي', type: 'n')]);
    if (o == null || !context.mounted) return;
    if (!AppLock.check(o['p'] ?? '')) { toast(context, 'الرقم غلط'); return; }
    if (v == 'off') { await AppLock.set(null); if (context.mounted) toast(context, 'اتلغى القفل'); return; }
  }
  final o = await formDlg(context, 'رقم سري جديد (4 أرقام أو أكتر)', [FieldSpec('p', 'الرقم', type: 'n'), FieldSpec('p2', 'اكتبه تاني', type: 'n')]);
  if (o == null || !context.mounted) return;
  final p = (o['p'] ?? '').trim();
  if (p.length < 4) { toast(context, 'لازم 4 أرقام على الأقل'); return; }
  if (p != (o['p2'] ?? '').trim()) { toast(context, 'الرقمين مش زي بعض'); return; }
  await AppLock.set(p);
  if (context.mounted) toast(context, '🔒 اتفعّل القفل — هيطلب الرقم كل ما تفتح التطبيق');
}
