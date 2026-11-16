import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/store.dart';
import 'ui/theme.dart';
import 'ui/shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Store.I.init();
  runApp(const OffersApp());
}

class OffersApp extends StatelessWidget {
  const OffersApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'عروض الشقق',
        debugShowCheckedModeBanner: false,
        theme: offersTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        builder: (c, w) => Directionality(textDirection: TextDirection.rtl, child: w!),
        home: const Shell(),
      );
}
