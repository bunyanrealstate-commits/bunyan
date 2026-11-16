import 'package:flutter/material.dart';
import '../core/store.dart';
import '../core/native.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (context, _) {
        final s = Store.I;
        return Scaffold(
          appBar: AppBar(title: const Text('⚙️ الإعدادات')),
          body: ListView(padding: const EdgeInsets.all(14), children: [
            Card(child: ListTile(leading: Icon(s.linked ? Icons.link : Icons.link_off, color: s.linked ? kOk : kGold), title: Text(s.linked ? 'مربوط ببنيان' : 'مش مربوط ببنيان لسه'),
              subtitle: Text(s.linked ? 'الباك أب بيترفع لوحده • ${s.gemKey.isEmpty ? 'مفتاح Gemini مش موجود' : 'Gemini شغال'}${s.backupMsg.isNotEmpty ? '\n${s.backupMsg}' : ''}' : 'افتح بنيان مرة على الموبايل — هيفتح التطبيق ده ويبعتله مفتاح Gemini والباك أب لوحده'))),
            Card(child: ListTile(leading: const Icon(Icons.cloud_upload_outlined, color: kAc), title: const Text('اعمل باك أب دلوقتي'), enabled: s.linked, onTap: () async { await s.backup(); if (context.mounted) toast(context, s.backupMsg); })),
            Card(child: ListTile(leading: const Icon(Icons.cloud_download_outlined, color: kAc), title: const Text('رجّع آخر باك أب'), enabled: s.linked, onTap: () async { if (!await confirmDlg(context, 'ترجع آخر نسخة متحفظة؟ اللي على الموبايل هيتبدل بيها', ok: 'رجّع')) return; final ok = await s.restore(); if (context.mounted) toast(context, ok ? '✅ رجعت' : '⚠️ مالقيتش باك أب'); })),
            Card(child: ListTile(leading: const Icon(Icons.vpn_key_outlined, color: kAc), title: const Text('لزق كود الربط بإيدك'), subtitle: const Text('لو بنيان ما فتحش التطبيق لوحده'), onTap: () async {
              final o = await formDlg(context, 'كود الربط من بنيان', [const FS('c', 'BNYLINK-…')]);
              if (o == null || !context.mounted) return;
              toast(context, s.link(o['c'] ?? '') ? '✅ اتربط' : '⚠️ الكود مش صح');
            })),
            Card(child: ListTile(leading: const Icon(Icons.system_update_outlined, color: kAc), title: const Text('تحديث التطبيق'), subtitle: Text('النسخة ${Native.mine}${Native.latest > Native.mine ? ' • فيه ${Native.latest}' : ''}'), onTap: () => Native.check(force: true))),
          ]),
        );
      });
}
