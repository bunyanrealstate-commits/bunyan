import 'package:flutter/material.dart';
import 'i18n.dart';
import '../core/actions.dart';
import 'theme.dart';

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> confirmDlg(BuildContext c, String msg, {String ok = 'تأكيد'}) async =>
    await showDialog<bool>(context: c, builder: (_) => Directionality(textDirection: Tr.dir, child: AlertDialog(
          content: Text(msg, style: const TextStyle(fontSize: 16, height: 1.6)),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(Tr.t('إلغاء'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok))],
        ))) ?? false;

Future<String?> pickDlg(BuildContext c, String title, List<List<String>> opts, String def) => showDialog<String>(context: c, builder: (_) {
      var v = def;
      return Directionality(textDirection: Tr.dir, child: StatefulBuilder(builder: (ctx, set) => AlertDialog(
            title: Text(title, style: const TextStyle(fontSize: 16)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final o in opts) RadioListTile<String>(value: o[0], groupValue: v, onChanged: (x) => set(() => v = x ?? ''), title: Text(o[1], style: const TextStyle(fontSize: 14))),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(Tr.t('إلغاء'))), FilledButton(onPressed: () => Navigator.pop(c, v), child: Text(Tr.t('تأكيد')))],
          )));
    });

/// الشهور المقفولة 🔒 — نفس سؤال القديم
Future<bool> lockOk(BuildContext c, List<String> ds) async {
  final l = ds.where(Act.isLk).map((d) => d.substring(0, 7)).toSet().toList();
  if (l.isEmpty) return true;
  return confirmDlg(c, 'الشهر ${l.join('، ')} مقفول 🔒 وتم قفل أرقامه. هل أنت متأكد أنك تريد التعديل فيه؟', ok: Tr.t('عدّل على أي حال'));
}

/// فورم بسيط: حقول نص/رقم/تاريخ
class FieldSpec { final String k, label; final String type; final dynamic v; FieldSpec(this.k, this.label, {this.type = 't', this.v}); }

Future<Map<String, String>?> formDlg(BuildContext c, String title, List<FieldSpec> fs) {
  final ctl = {for (final f in fs) f.k: TextEditingController(text: f.v == null ? '' : '${f.v}')};
  return showDialog<Map<String, String>>(context: c, builder: (_) => Directionality(textDirection: Tr.dir, child: AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final f in fs) Padding(padding: const EdgeInsets.only(bottom: 10), child: f.type == 'd'
              ? StatefulBuilder(builder: (ctx, set) => InkWell(
                  onTap: () async {
                    final init = DateTime.tryParse(ctl[f.k]!.text) ?? DateTime.now();
                    final d = await showDatePicker(context: ctx, initialDate: init, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (d != null) set(() => ctl[f.k]!.text = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
                  },
                  child: InputDecorator(decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()), child: Text(ctl[f.k]!.text))))
              : TextField(controller: ctl[f.k], keyboardType: f.type == 'n' ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder()))),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(Tr.t('إلغاء'))), FilledButton(onPressed: () => Navigator.pop(c, {for (final e in ctl.entries) e.key: e.value.text.trim()}), child: Text(Tr.t('حفظ')))],
      )));
}
