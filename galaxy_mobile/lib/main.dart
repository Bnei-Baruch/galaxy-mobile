import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/routes.dart';
import 'package:galaxy_mobile/services/api.dart';
import 'package:galaxy_mobile/services/authService.dart';
import 'package:galaxy_mobile/themes/default.dart';
import 'package:galaxy_mobile/utils/shared_pref.dart';
import 'package:provider/provider.dart';

void main() async {
   WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefs().init();
  runApp(
    /// Providers are above [MyApp] instead of inside it, so that tests
    /// can use [MyApp] while mocking the providers
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<Api>(create: (_) => Api()),
        ChangeNotifierProxyProvider2<AuthService, Api, MainStore>(
          create: (_) => MainStore(),
          update: (_, auth, api, model) => model..update(auth, api)
        ),
      ],
      child: MyApp()
    ),
  );
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appTheme(),
      initialRoute: '/',
      routes: routes,
    );
  }
}
