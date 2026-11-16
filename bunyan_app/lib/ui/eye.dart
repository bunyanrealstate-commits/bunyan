import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';
import '../core/store.dart';
import 'theme.dart';
import 'lock.dart';
import 'dialogs.dart';
import 'i18n.dart';

/// 👁 العين جنب اللوجو: بتخبي الأرقام وأسماء الاستديوهات — ولفتحها تاني بتطلب البصمة (زي القديم)
class EyeBtn extends StatelessWidget {
  const EyeBtn({super.key});
  Future<bool> _auth(BuildContext context) async {
    if (!kIsWeb) {
      try {
        final la = LocalAuthentication();
        if (await la.isDeviceSupported()) {
          return await la.authenticate(localizedReason: Tr.t('افتح الأرقام بالبصمة'), options: const AuthenticationOptions(stickyAuth: true));
        }
      } catch (_) {}
    }
    if (AppLock.on && context.mounted) {
      final o = await formDlg(context, Tr.t('اكتب الرقم السري'), [FieldSpec('p', Tr.t('الرقم السري'), type: 'n')]);
      return o != null && AppLock.check(o['p'] ?? '');
    }
    return true;
  }
  @override
  Widget build(BuildContext context) => Container(
        width: 40, height: 40, margin: const EdgeInsetsDirectional.only(start: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBd)),
        child: IconButton(
          padding: EdgeInsets.zero, tooltip: Priv.on ? Tr.t('إظهار الأرقام') : Tr.t('إخفاء الأرقام'),
          icon: Icon(Priv.on ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: kInk, size: 22),
          onPressed: () async {
            if (Priv.on) { if (!await _auth(context)) { if (context.mounted) toast(context, Tr.t('ما اتفتحش')); return; } }
            Store.I.cfg['hide'] = !Priv.on; await Store.I.saveCfg(); Store.I.notify();
          },
        ),
      );
}
