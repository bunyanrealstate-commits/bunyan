import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/store.dart';
import 'ui/theme.dart';
import 'ui/shell.dart';
import 'ui/lock.dart';
import 'ui/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.I.init();
  runApp(const BunyanApp());
}

class BunyanApp extends StatelessWidget {
  const BunyanApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Store.I, builder: (_, __) => MaterialApp(
        title: 'بنيان',
        debugShowCheckedModeBanner: false,
        theme: bunyanTheme(),
        locale: Locale(Tr.lang),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        // خط الموبايل لو مكبّر من الإعدادات ميبوّظش الشاشات: أقصى تكبير 1.0
        builder: (ctx, child) { final mq = MediaQuery.of(ctx); return MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: .85, maxScaleFactor: 1.0)), child: child!); },
        home: const LockGate(child: Shell()),
      ));
}
